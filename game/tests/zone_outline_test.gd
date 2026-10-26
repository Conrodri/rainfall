extends Node
## Contour des zones persistantes au sol des joueurs (ZoneOutline) : chaque zone à durée de chaque personnage a un
## contour de la couleur de son sort (champ zone_outline_color, sinon couleur du sort, sinon accent), au rayon réel,
## qui disparaît avec la zone ; pulsation coupée au palier Bas ; rendu partagé avec les flaques ennemies (RecluseFx).
## godot --headless --path game res://tests/zone_outline_test.tscn

const U := 64.0
const DT := 1.0 / 60.0
const CHARS: Array[StringName] = [&"ardent", &"rictus", &"tocsin", &"averse", &"arpenteuse", &"rainette", &"avare", &"bourbe", &"vigie", &"morfil"]

var _fails := 0
var _layer: CanvasLayer = null


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _same_rgb(a: Color, b: Color) -> bool:
	return _near(a.r, b.r, 0.002) and _near(a.g, b.g, 0.002) and _near(a.b, b.b, 0.002)


## Avance tous les contours vivants d'une image.
func _step_outlines(seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		for o in get_tree().get_nodes_in_group(&"zone_outlines"):
			if is_instance_valid(o) and not (o as Node).is_queued_for_deletion():
				(o as ZoneOutline).step(DT)


func _make_player(cid: StringName) -> CharacterBody2D:
	RunState.level = 1
	RunState.character = cid
	RunState.loadout = {}
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	await get_tree().process_frame
	p.set_physics_process(false)
	return p


func _free_player(p: Node) -> void:
	p.queue_free()
	await get_tree().process_frame
	for o in get_tree().get_nodes_in_group(&"zone_outlines"):
		o.queue_free()
	await get_tree().process_frame


func _run() -> void:
	_layer = CanvasLayer.new() # couche des télégraphes simulée (ni éclairée ni étalonnée)
	_layer.add_to_group(AmbianceManager.UNGRADED_GROUP)
	get_tree().root.add_child(_layer)
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)

	print("Composant : cycle de vie, fondus, pulsation")
	var host := Node2D.new()
	get_tree().root.add_child(host)
	host.global_position = Vector2(300, 200)
	var col := Color(0.2, 0.7, 1.0)
	var o := ZoneOutline.attach(host, 128.0, col, 0.0)
	_check("contour posé dans la couche des télégraphes", o != null and o.get_parent() == _layer)
	_check("non éclairé, sous les corps (z -1)", o.light_mask == 0 and o.z_index == -1 and o.material == EnemyTelegraph.unshaded_material())
	_check("même épaisseur que les flaques ennemies (2 px) et même dessin (RecluseFx)", ZoneOutline.WIDTH == 2.0)
	_check("invisible à la pose (fondu d'entrée)", o.alpha_now() == 0.0)
	_step_outlines(ZoneOutline.FADE_IN_S * 0.5)
	_check("fondu d'entrée en cours", o.alpha_now() > 0.0 and o.alpha_now() < 0.9, str(o.alpha_now()))
	_step_outlines(0.5)
	_check("opaque (pulsation incluse) après le fondu", o.alpha_now() >= 1.0 - ZoneOutline.PULSE_AMP - 0.001 and o.alpha_now() <= 1.0)
	var lo := 2.0
	var hi := 0.0
	for i in 120:
		_step_outlines(DT)
		lo = minf(lo, o.alpha_now())
		hi = maxf(hi, o.alpha_now())
	_check("pulsation visible aux paliers Moyen / Haut", hi - lo > 0.05, "%f..%f" % [lo, hi])
	var prev_tier: int = Quality.tier
	Quality.tier = Quality.Tier.LOW
	Quality.quality_changed.emit(Quality.tier)
	lo = 2.0
	hi = 0.0
	for i in 120:
		_step_outlines(DT)
		lo = minf(lo, o.alpha_now())
		hi = maxf(hi, o.alpha_now())
	_check("pulsation coupée au palier Bas (alpha stable)", hi - lo < 0.001 and _near(hi, 1.0, 0.001), "%f..%f" % [lo, hi])
	Quality.tier = prev_tier
	Quality.quality_changed.emit(Quality.tier)
	host.global_position = Vector2(500, 260)
	_step_outlines(DT)
	_check("suit son hôte", o.global_position.distance_to(host.global_position) < 0.01)
	o.set_radius(200.0)
	_check("suit un rayon qui change", _near(o.radius, 200.0))
	# l'hôte part : fondu de sortie puis libération
	host.queue_free()
	await get_tree().process_frame
	_check("hôte libéré : contour en fondu de sortie", is_instance_valid(o) and o.is_releasing())
	_step_outlines(ZoneOutline.FADE_OUT_S + 0.2)
	await get_tree().process_frame
	_check("contour libéré avec la zone", not is_instance_valid(o))
	# durée programmée
	var h2 := Node2D.new()
	get_tree().root.add_child(h2)
	var o2 := ZoneOutline.attach(h2, 64.0, col, 1.0)
	_step_outlines(1.0 - ZoneOutline.FADE_OUT_S + 0.05)
	_check("fondu de sortie programmé avant la fin de vie", o2.is_releasing())
	_step_outlines(ZoneOutline.FADE_OUT_S + 0.1)
	await get_tree().process_frame
	_check("libéré à la fin de vie", not is_instance_valid(o2))
	h2.queue_free()
	# capsule et anneau : tableaux réutilisés
	var h3 := Node2D.new()
	get_tree().root.add_child(h3)
	var mover := Node2D.new()
	get_tree().root.add_child(mover)
	mover.global_position = Vector2(400, 0)
	var oc := ZoneOutline.attach_capsule(h3, 16.0, col, 0.0, mover)
	_step_outlines(DT)
	var n0 := oc._poly.size()
	mover.global_position = Vector2(400, 300)
	_step_outlines(DT)
	_check("capsule : 2×11 points + fermeture, retracée quand l'extrémité bouge", n0 == 23 and oc._poly.size() == 23 and oc._end_local.distance_to(Vector2(400, 300)) < 0.5)
	var ob := ZoneOutline.attach_band(h3, 192.0, 128.0, col, 0.0)
	_check("anneau : rayons extérieur / intérieur", ob != null and _near(ob.radius, 192.0) and _near(ob.inner, 128.0))
	h3.queue_free()
	mover.queue_free()
	await get_tree().process_frame
	_step_outlines(1.0)

	print("Couleur : champ du sort > couleur du sort > accent du personnage")
	var sd := SpellData.new()
	sd.color = Color(0.1, 0.9, 0.3)
	_check("couleur du sort", _same_rgb(ZoneOutline.color_for(sd), sd.color))
	sd.zone_outline_color = Color(1, 0, 1, 1)
	_check("surcharge par sort (zone_outline_color)", _same_rgb(ZoneOutline.color_for(sd), Color(1, 0, 1)))
	sd.zone_outline_color = Color(0, 0, 0, 0)
	sd.color = Color(0, 0, 0, 0)
	var pa := await _make_player(&"vigie")
	_check("sans couleur de sort : accent du personnage", _same_rgb(ZoneOutline.color_for(sd, pa.spells), pa.character.accent_color))
	await _free_player(pa)

	print("Chemin commun : toute zone à durée de chaque personnage (SpellCaster.spawn_zone)")
	var covered := 0
	for cid in CHARS:
		var p := await _make_player(cid)
		for s: SpellData in p.character.spells:
			if s.duration <= 0.0 or s.radius_u <= 0.0 or s.behavior == SpellData.Behavior.ARC:
				continue
			var z: Node2D = p.spells.spawn_zone(s, Vector2(100, 100))
			var ol := ZoneOutline.of(z)
			var want := ZoneOutline.color_for(s, p.spells)
			var rad: float = s.radius_u * U * (1.0 + p.stat(&"zone_size_add"))
			var ok: bool = ol != null and _same_rgb(ol.color, want) and _near(ol.radius, rad, 0.6) and ol.host == z
			_check("%s / %s : contour couleur du sort, rayon réel" % [cid, s.id], ok, "ol=%s" % str(ol))
			covered += 1
			if ol != null:
				_step_outlines(0.3)
				_check("%s / %s : visible" % [cid, s.id], ol.alpha_now() > 0.5)
				# la zone finit : le contour disparaît avec elle
				var t := 0.0
				while is_instance_valid(z) and t < s.duration + 3.0:
					z.step(DT)
					_step_outlines(DT)
					t += DT
				await get_tree().process_frame
				_step_outlines(ZoneOutline.FADE_OUT_S + 0.1)
				await get_tree().process_frame
				_check("%s / %s : contour libéré avec la zone" % [cid, s.id], not is_instance_valid(ol))
		await _free_player(p)
	_check("au moins une zone persistante par chemin (Ardent, Averse, Bourbe, Vigie, Rainette…)", covered >= 6, str(covered))

	print("Zones propres aux kits")
	await _kit_zones()

	print("Coût : 16 contours en parallèle (pas de redessin, pas d'allocation par image)")
	var hs: Array[Node2D] = []
	var os: Array[ZoneOutline] = []
	for i in 16:
		var hh := Node2D.new()
		get_tree().root.add_child(hh)
		hh.global_position = Vector2(i * 40, 0)
		hs.append(hh)
		os.append(ZoneOutline.attach(hh, 192.0, col, 0.0))
	var t0 := Time.get_ticks_usec()
	for f in 600: # 10 s à 60 i/s
		for oo in os:
			oo.step(DT)
	var per_step_us := float(Time.get_ticks_usec() - t0) / (600.0 * 16.0)
	print("  coût mesuré : %.2f us par contour et par image (machine chargée : bruité)" % per_step_us)
	_check("coût par contour et par image < 20 us", per_step_us < 20.0, str(per_step_us))
	for hh in hs:
		hh.queue_free()
	await get_tree().process_frame
	_step_outlines(1.0)

	director.queue_free()
	await get_tree().process_frame
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _kit_zones() -> void:
	# Vigie : fusée, Fanal, chausse-trapes
	var pv := await _make_player(&"vigie")
	var vk: VigieKit = pv.kit
	var fl := vk.plant_flare(Vector2(200, 0)) as VigieFlare
	var of := ZoneOutline.of(fl)
	_check("Vigie / fusée : contour accent, rayon d'exposition", of != null and _same_rgb(of.color, VigieKit.ACCENT) and _near(of.radius, fl.radius, 0.6))
	var ct := vk.plant_caltrops(vk.character().spells[2], Vector2(-200, 0)) as VigieCaltrops
	var oct := ZoneOutline.of(ct)
	_check("Vigie / chausse-trapes : contour au rayon réel", oct != null and _near(oct.radius, ct.radius, 0.6))
	fl.queue_free()
	ct.queue_free()
	await get_tree().process_frame
	_check("Vigie : contours en sortie quand la zone est libérée", of.is_releasing() and oct.is_releasing())
	_step_outlines(1.0)
	await get_tree().process_frame
	_check("Vigie : contours libérés", not is_instance_valid(of) and not is_instance_valid(oct))
	await _free_player(pv)

	# Rainette : flaque de Gluant
	var pr := await _make_player(&"rainette")
	var rk: RainetteKit = pr.kit
	var gs: SpellData = null
	for s: SpellData in pr.character.spells:
		if s.slot == 3:
			gs = s
	rk._spawn_goo(gs, Vector2(150, 0))
	var goo: RainetteGoo = RainetteGoo.live.back()
	var og := ZoneOutline.of(goo)
	_check("Rainette / flaque de Gluant : contour couleur du sort, rayon réel", og != null and _same_rgb(og.color, gs.color) and _near(og.radius, goo.radius, 0.6))
	goo.queue_free()
	await get_tree().process_frame
	_step_outlines(1.0)
	await get_tree().process_frame
	_check("Rainette : contour libéré avec la flaque", not is_instance_valid(og))
	await _free_player(pr)

	# Tocsin : Bras-pilier
	var pt := await _make_player(&"tocsin")
	var tk: TocsinKit = pt.kit
	pt.spells.aim_override = Vector2(7.0 * U, 0)
	pt.spells.cast(2)
	var pil: TocsinLimb = null
	var guard := 0.0
	while guard < 3.0:
		pt.spells._remaining[1] = 99.0
		pt.tick(DT)
		for l in tk.limbs.values():
			if is_instance_valid(l):
				l.set_physics_process(false)
				l.step(DT)
				if l.phase == TocsinLimb.Phase.PILLAR:
					pil = l
		guard += DT
		if pil != null:
			break
	_check("Tocsin : pilier planté", pil != null)
	if pil != null:
		var ot := ZoneOutline.of(pil)
		_check("Tocsin / pilier : contour couleur du sort, rayon de décharge", ot != null and _same_rgb(ot.color, pil.spell.color) and _near(ot.radius, pil.radius_px, 0.6))
		pil.vanish()
		await get_tree().process_frame
		_step_outlines(1.0)
		await get_tree().process_frame
		_check("Tocsin : contour libéré avec le pilier", ot == null or not is_instance_valid(ot))
	await _free_player(pt)

	# Arpenteuse : piquet (ligne), Jalons (ligne), Cerceau (anneau)
	var pa := await _make_player(&"arpenteuse")
	var ak: ArpenteuseKit = pa.kit
	pa.spells.aim_override = Vector2(5 * U, 0)
	pa.spells.cast(3)
	var t := 0.0
	while ak.has_pending() and t < 1.5:
		pa.tick(DT)
		t += DT
	var opeg := ZoneOutline.of(ak._peg_node)
	_check("Arpenteuse / Piquet : contour en capsule sur la ligne du poteau", ak.peg_active() and opeg != null and opeg.shape == ZoneOutline.Shape.CAPSULE and _near(opeg.radius, ArpenteuseKit.CHAIN_HALF_WIDTH_U * U, 0.6))
	ak._end_peg(false)
	await get_tree().process_frame
	_step_outlines(1.0)
	await get_tree().process_frame
	_check("Arpenteuse : contour du piquet libéré", opeg == null or not is_instance_valid(opeg))
	var cs := ArpenteuseKit.variant(4, ArpenteuseKit.V_CERCEAU)
	ak._do_cerceau(cs)
	var orn: ZoneOutline = ak._ring_outline
	_check("Arpenteuse / Cerceau : contour en anneau autour d'elle", orn != null and orn.shape == ZoneOutline.Shape.BAND and orn.radius > orn.inner and orn.inner > 0.0)
	ak._end_ring()
	_step_outlines(1.0)
	await get_tree().process_frame
	_check("Arpenteuse : contour du Cerceau libéré", not is_instance_valid(orn))
	var js := ArpenteuseKit.variant(3, ArpenteuseKit.V_JALONS)
	pa.global_position = Vector2.ZERO
	ak._do_jalon(js, Vector2(3 * U, 0), 1)
	ak._do_jalon(js, Vector2(6 * U, 0), 2)
	var oj: ZoneOutline = ZoneOutline.of(ak._jal_a_node) if ak._jal_a_node != null else null
	_check("Arpenteuse / Jalons : contour en capsule entre A et B", ak.jal_line and oj != null and oj.shape == ZoneOutline.Shape.CAPSULE)
	ak._end_jalons()
	await get_tree().process_frame
	_step_outlines(1.0)
	await get_tree().process_frame
	_check("Arpenteuse : contour des Jalons libéré", oj == null or not is_instance_valid(oj))
	await _free_player(pa)
