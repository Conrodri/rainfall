extends Node
## VfxTestPlayer : hiérarchie par projection (UNSQUASH ou non), rotation, flip, halo, lumière, particules, libération.
## godot --headless --path game res://tests/vfx_test_player_test.tscn  -> RESULT: OK

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _run() -> void:
	var cat := VfxTestPlayer.catalog()
	_check("catalogue non vide", not cat.is_empty())
	var keys: Array[String] = []
	for o in cat:
		for s in cat[o]:
			keys.append("%s/%s" % [o, s])
	print("  info ", keys.size(), " effets, ", cat.size(), " propriétaires")
	# un sort au corps non bouclé, un en boucle
	var oneshot := ""
	var looped := ""
	for k in keys:
		var m := VfxTestPlayer.load_meta(k)
		if m.is_empty():
			continue
		if oneshot == "" and not bool(m.get("loop", false)) and int(m.get("frames", 99)) <= 40:
			oneshot = k
		if looped == "" and bool(m.get("loop", false)):
			looped = k
	if oneshot == "" and not keys.is_empty():
		oneshot = keys[0]
	if looped == "" and not keys.is_empty():
		looped = keys[0]
	_check("one-shot trouvé", oneshot != "")
	if oneshot == "":
		_finish()
		return
	# classes synthétiques (iso_classes.json peut manquer)
	VfxTestPlayer._classes_loaded = true
	VfxTestPlayer._classes = {
		oneshot: {"projection": "billboard", "particles": "burst", "size_u": 3.0},
		"zz/alias": {"alias": oneshot, "projection": "ground"},
	}
	var host := Node2D.new()
	add_child(host)

	# --- billboard
	var b := VfxTestPlayer.spawn(host, oneshot, Vector2(100, 50), Vector2.LEFT, {}) as VfxTestPlayer
	_check("billboard créé", b != null)
	_check("billboard : UNSQUASH", b.space.scale.is_equal_approx(Iso.UNSQUASH))
	_check("billboard : sans rotation, miroir si dir.x < 0", is_zero_approx(b.rot.rotation) and b.rot.scale.x < 0.0)
	_check("billboard : position au pied", b.position.is_equal_approx(Vector2(100, 50)))
	_check("billboard : corps filtre nearest", b.body.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var fs: Array = b.meta.get("frame_size", [128, 128])
	_check("billboard : largeur = size_u × 64", absf(float(fs[0]) * b.node_scale - 3.0 * 64.0) < 1.0, str(b.node_scale))
	_check("billboard : halo additif", b.halo != null and b.halo.material is CanvasItemMaterial and (b.halo.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	_check("billboard : lumière LightRig", b.light != null)
	_check("billboard : particules burst, carrés sans texture", b.particles != null and b.particles.texture == null and b.part_space.scale.is_equal_approx(Iso.UNSQUASH))
	_check("particules plafonnées", b.particles.amount <= 26)
	var b2 := VfxTestPlayer.spawn(host, oneshot, Vector2.ZERO, Vector2.RIGHT, {"halo": false, "light": false, "particles": false}) as VfxTestPlayer
	_check("options coupées : ni halo ni lumière ni particules", b2.halo == null and b2.light == null and b2.particles == null)
	b2.stop()

	# --- ground, ground_dir, projectile, alias
	VfxTestPlayer._classes[oneshot] = {"projection": "ground", "particles": "none", "size_u": 2.0}
	var g := VfxTestPlayer.spawn(host, oneshot, Vector2.ZERO, Vector2.RIGHT, {}) as VfxTestPlayer
	_check("ground : pas d'UNSQUASH", g.space.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(g.rot.rotation))
	_check("ground : particules none", g.particles == null)
	VfxTestPlayer._classes[oneshot] = {"projection": "ground_dir", "particles": "embers", "size_u": 4.0}
	var dir := Vector2(0, 1).rotated(0.6)
	var gd := VfxTestPlayer.spawn(host, oneshot, Vector2.ZERO, dir, {}) as VfxTestPlayer
	_check("ground_dir : repère logique tourné de dir.angle()", gd.space.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(gd.rot.rotation, dir.angle()))
	_check("ground_dir : braises", gd.particles != null and gd.particles.emitting and gd.particles_kind == "embers")
	VfxTestPlayer._classes[oneshot] = {"projection": "projectile", "particles": "trail", "size_u": 1.0}
	var pdir := Vector2(1, 1).normalized()
	var pr := VfxTestPlayer.spawn(host, oneshot, Vector2.ZERO, pdir, {"always": false, "range_u": 2.0, "speed_u": 20.0}) as VfxTestPlayer
	_check("projectile : UNSQUASH + rotation Iso.screen_angle", pr.space.scale.is_equal_approx(Iso.UNSQUASH) and is_equal_approx(pr.rot.rotation, Iso.screen_angle(pdir)))
	_check("projectile : traînée", pr.particles != null and pr.particles.emitting and not pr.particles.local_coords)
	var al := VfxTestPlayer.spawn(host, "zz/alias", Vector2.ZERO, Vector2.RIGHT, {}) as VfxTestPlayer
	_check("alias suit l'asset du sort cible", al != null and al.projection == "ground")
	var miss := VfxTestPlayer.spawn(host, "zz/inexistant", Vector2.ZERO, Vector2.RIGHT, {})
	_check("sort absent : null sans erreur", miss == null)

	# --- progression et libération
	var p0 := pr.position
	for i in 6:
		await get_tree().process_frame
	_check("projectile avance le long de dir", (pr.position - p0).dot(pdir) > 0.0)
	var lights := LightRig.request_count()
	_check("demandes de lumière enregistrées", lights >= 1)
	if looped != "":
		VfxTestPlayer._classes[looped] = {"projection": "billboard", "particles": "embers"}
		var lp := VfxTestPlayer.spawn(host, looped, Vector2.ZERO, Vector2.RIGHT, {"duration": 0.2}) as VfxTestPlayer
		var fin := [false]
		lp.finished.connect(func(_x): fin[0] = true)
		for i in 40:
			await get_tree().process_frame
			if fin[0]:
				break
		_check("boucle : libérée après opts.duration", fin[0])
	# fin d'un one-shot : accélère via _t
	var os_ := VfxTestPlayer.spawn(host, oneshot, Vector2.ZERO, Vector2.RIGHT, {}) as VfxTestPlayer
	os_.finished.connect(func(_x): print("  info one-shot fini"))
	os_._t = os_._end_t
	await get_tree().process_frame
	await get_tree().process_frame
	_check("one-shot libéré en fin", not is_instance_valid(os_))
	for n in [b, g, gd, pr, al]:
		if is_instance_valid(n):
			n.stop()
	await _test_usages(host)
	await get_tree().process_frame
	_check("tout libéré", host.get_child_count() == 0 or host.get_children().all(func(c): return c.is_queued_for_deletion()))
	# --- galerie dans le panneau
	var panel := TestPanel.new()
	add_child(panel)
	panel._select_tab(&"vfx")
	await get_tree().process_frame
	_check("onglet Galerie VFX construit", panel.vfx_gallery != null and panel.vfx_gallery.find_child("VfxPlayAll", true, false) != null)
	_check("boutons de sorts listés", panel.vfx_gallery.find_children("Spell_*", "Button", true, false).size() > 0)
	_check("boutons de propriétaires listés", panel.vfx_gallery.find_children("Owner_*", "Button", true, false).size() == cat.size())
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Champ meta `usage` (lignes tuilées ou étirées, rayons, largeurs), perspective des projectiles, fin sur place d'un
## one-shot dont l'hôte disparaît, effets masqués avec leur hôte, ajustement à l'échelle de l'hôte, course propre.
func _test_usages(host: Node2D) -> void:
	VfxTestPlayer.reload_classes() # vraies classes (iso_classes.json)
	const U := 64.0
	# --- disposition des tuiles : ni trou ni chevauchement, dernier segment mis à l'échelle
	_check("tuiles 8 u / 2 u : 4 pleines", VfxTestPlayer.tile_layout(8.0 * U, 2.0 * U).is_equal_approx(Vector2(4, 1)))
	_check("tuiles 7 u / 2 u : 3 pleines + une demie", VfxTestPlayer.tile_layout(7.0 * U, 2.0 * U).is_equal_approx(Vector2(4, 0.5)))
	_check("tuiles 6,5 u / 2 u : dernière étirée ×1,25", VfxTestPlayer.tile_layout(6.5 * U, 2.0 * U).is_equal_approx(Vector2(3, 1.25)))
	_check("tuiles 1 u / 2 u : une demie", VfxTestPlayer.tile_layout(1.0 * U, 2.0 * U).is_equal_approx(Vector2(1, 0.5)))
	# --- lecture de usage_note
	if VfxTestPlayer.available("recluse/bell_wave"):
		_check("usage_note : anneau de 1 à 8 u -> rayon 8", is_equal_approx(VfxTestPlayer.note_radius_u(VfxTestPlayer.load_meta("recluse/bell_wave")), 8.0))
	if VfxTestPlayer.available("eclusier/wave"):
		_check("usage_note : crête de 4 u de large", is_equal_approx(VfxTestPlayer.note_width_u(VfxTestPlayer.load_meta("eclusier/wave")), 4.0))
	_check("usage_note : « 1,5 u de large »", is_equal_approx(VfxTestPlayer.note_width_u({"usage_note": "vers +x sur 16 u, 1,5 u de large ; boucle"}), 1.5))
	_check("usage_note : « (2 u de large) »", is_equal_approx(VfxTestPlayer.note_width_u({"usage_note": "sur 12 u (2 u de large) puis"}), 2.0))
	_check("usage_note : champ meta width_u prioritaire", is_equal_approx(VfxTestPlayer.note_width_u({"width_u": 0.7, "usage_note": "1 u de large"}), 0.7))
	# --- projectile : longueur raccourcie par la perspective, épaisseur inchangée
	var pk := "flood_gunner/rivet"
	if VfxTestPlayer.available(pk):
		var exp := {Vector2.RIGHT: 1.0, Vector2.UP: 0.5, Vector2.DOWN: 0.5, Vector2(1, 1).normalized(): Vector2(0.7071068, 0.3535534).length()}
		for d in exp:
			var p := VfxTestPlayer.spawn(host, pk, Vector2.ZERO, d, {"always": false}) as VfxTestPlayer
			_check("projectile %s : longueur × %.2f, épaisseur × 1" % [d, exp[d]], is_equal_approx(p.rot.scale.x, exp[d]) and is_equal_approx(p.rot.scale.y, 1.0) and is_equal_approx(p.rot.rotation, Iso.screen_angle(d)), "%s" % p.rot.scale)
			p.stop()
	# --- tile_along_line : fil de la Tisseuse sur 7 u
	var tk := "weaver/thread"
	if VfxTestPlayer.available(tk):
		var dir := Vector2(0.6, -0.8)
		var t := VfxTestPlayer.spawn(host, tk, Vector2(10, 20), dir, {"line_px": 7.0 * U}) as VfxTestPlayer
		_check("fil : usage tile_along_line, segment 2 u", t.usage == "tile_along_line" and is_equal_approx(t.segment_px, 2.0 * U))
		_check("fil : 4 tuiles (3 + une demie)", t.tiles.size() == 4 and (t.halo == null or t.tile_halos.size() == 4), "%d" % t.tiles.size())
		var covered := 0.0
		var ok := true
		for i in t.tiles.size():
			var tile := t.tiles[i]
			ok = ok and is_equal_approx(tile.position.x, covered) and is_zero_approx(tile.position.y)
			covered += t._fw * tile.scale.x
		_check("fil : tuiles bout à bout sans trou, 7 u couverts", ok and absf(covered - 7.0 * U) < 0.5, "%.1f px" % covered)
		_check("fil : couché au sol le long de la ligne", t.space.scale == Vector2.ONE and is_equal_approx(t.rot.rotation, dir.angle()))
		t.set_line(dir, 3.0 * U)
		await get_tree().process_frame
		_check("fil raccourci à 3 u : 2 tuiles (1 + une demie)", t.tiles.size() == 2 and is_equal_approx(t.tiles[1].scale.x, t.tiles[0].scale.x * 0.5))
		t.stop()
	# --- line_from_pivot : racines du Cèdre (dessinées sur 8 u) affichées à 2,2 u (gerbe)
	var rk := "hermit_cedar/root_spike"
	if VfxTestPlayer.available(rk):
		var r := VfxTestPlayer.spawn(host, rk, Vector2.ZERO, Vector2.DOWN, {"line_px": 2.2 * U}) as VfxTestPlayer
		_check("racines : longueur dessinée 8 u (usage_note)", is_equal_approx(r.native_line_px, 8.0 * U))
		_check("racines : étirées à 2,2 u, épaisseur inchangée", is_equal_approx(r.body.scale.x, r.node_scale * 2.2 / 8.0) and is_equal_approx(r.body.scale.y, r.node_scale))
		_check("racines : ligne couchée vers le bas", is_equal_approx(r.rot.rotation, Vector2.DOWN.angle()))
		r.stop()
		# largeur gameplay 0,6 u (dessinée 1 u) : épaisseur seule, la longueur reste 2,2 u
		var rw := VfxTestPlayer.spawn(host, rk, Vector2.ZERO, Vector2.DOWN, {"line_px": 2.2 * U, "width_u": 0.6}) as VfxTestPlayer
		_check("racines : largeur dessinée 1 u (usage_note)", is_equal_approx(VfxTestPlayer.note_width_u(VfxTestPlayer.load_meta(rk)), 1.0))
		_check("racines : épaisseur × 0,6, longueur 2,2 u inchangée", is_equal_approx(rw.body.scale.y, rw.node_scale * 0.6) and is_equal_approx(rw.body.scale.x, rw.node_scale * 2.2 / 8.0), "%s / %.3f" % [rw.body.scale, rw.node_scale])
		rw.stop()
	# --- rayon gameplay (zone au sol)
	var zk := "bourbe/bourbier"
	if VfxTestPlayer.available(zk):
		var z0 := VfxTestPlayer.spawn(host, zk, Vector2.ZERO, Vector2.RIGHT, {}) as VfxTestPlayer
		var z1 := VfxTestPlayer.spawn(host, zk, Vector2.ZERO, Vector2.RIGHT, {"radius_u": 2.5}) as VfxTestPlayer
		_check("bourbier : rayon 2,5 u = moitié du rayon dessiné (5 u)", is_equal_approx(z1.node_scale, z0.node_scale * 0.5) and z1.projection == "ground")
		z0.stop()
		z1.stop()
	# --- one-shot dont l'hôte disparaît : finit son animation sur place
	if VfxTestPlayer.available(rk):
		var hp := Node2D.new()
		host.add_child(hp)
		var h := Node2D.new()
		hp.add_child(h)
		h.position = Vector2(300, 40)
		var o := VfxTestPlayer.spawn(h, rk, Vector2.ZERO, Vector2.RIGHT, {"follow": h, "always": false}) as VfxTestPlayer
		_check("one-shot suivi : posé à côté de l'hôte (pas dessous)", o.get_parent() == hp and o.top_level)
		await _frames(3)
		h.queue_free()
		await _frames(3)
		_check("one-shot : survit à la libération de l'hôte, reste sur place", is_instance_valid(o) and not o.finished_flag and o.detached and o.global_position.is_equal_approx(Vector2(300, 40)))
		var fin := [false]
		o.finished.connect(func(_x): fin[0] = true)
		o._t = o._end_t - 0.01
		await _frames(3)
		_check("one-shot détaché : libéré à la fin de son animation", fin[0])
		hp.queue_free()
	# --- effet en boucle masqué avec son hôte (hide_with_host) ou libéré (défaut)
	var lk := "weaver/web_ring"
	if VfxTestPlayer.available(lk):
		var h1 := Node2D.new()
		host.add_child(h1)
		var a := VfxTestPlayer.spawn(h1, lk, Vector2.ZERO, Vector2.RIGHT, {"follow": h1, "hide_with_host": true}) as VfxTestPlayer
		var b := VfxTestPlayer.spawn(h1, lk, Vector2.ZERO, Vector2.RIGHT, {"follow": h1}) as VfxTestPlayer
		await _frames(2)
		h1.visible = false
		await _frames(2)
		_check("boucle hide_with_host : masquée, pas libérée", is_instance_valid(a) and not a.finished_flag and not a.space.visible)
		_check("boucle par défaut : libérée quand l'hôte est masqué", not is_instance_valid(b) or b.finished_flag)
		h1.visible = true
		await _frames(2)
		_check("boucle hide_with_host : rendue avec l'hôte", is_instance_valid(a) and a.space.visible)
		h1.queue_free()
	# --- ajustement à l'échelle de l'hôte (disque de crue) + étirement vertical
	var pk2 := "jar_bearer/puddle"
	if VfxTestPlayer.available(pk2):
		var h2 := Node2D.new()
		host.add_child(h2)
		h2.scale = Vector2.ONE * (2.0 * 3.0 * U / 896.0)
		var f := VfxTestPlayer.spawn(h2, pk2, Vector2.ZERO, Vector2.RIGHT, {"follow": h2, "fit_host_px": 896.0, "aspect_y": 1.6}) as VfxTestPlayer
		await _frames(2)
		_check("crue : largeur = diamètre de l'hôte (6 u)", absf(f._fw * f.body.scale.x - 6.0 * U) < 1.0 and is_equal_approx(f.body.scale.y, f.body.scale.x * 1.6))
		h2.scale = Vector2.ONE * (2.0 * 5.0 * U / 896.0)
		await _frames(2)
		_check("crue : suit la croissance de l'hôte (10 u)", absf(f._fw * f.body.scale.x - 10.0 * U) < 1.0)
		h2.queue_free()
	# --- course propre hors projectile (crête d'un bras de croix)
	var ck := "eclusier/wave"
	if VfxTestPlayer.available(ck):
		var c := VfxTestPlayer.spawn(host, ck, Vector2.ZERO, Vector2.UP, {"always": false, "move_speed_u": 60.0, "move_range_u": 2.0, "width_u": 3.0}) as VfxTestPlayer
		await _frames(30)
		_check("crête : file de 2 u le long de sa direction puis s'arrête", is_instance_valid(c) and c.position.is_equal_approx(Vector2(0.0, -2.0 * U)), "%s" % (c.position if is_instance_valid(c) else Vector2.INF))
		if is_instance_valid(c):
			_check("crête : largeur 3 u sur 4 u dessinés", is_equal_approx(c.node_scale, float(VfxTestPlayer.resolve(ck)["size_u"]) * U / c._fw * 0.75))
			c.stop()
	await get_tree().process_frame


func _finish() -> void:
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
