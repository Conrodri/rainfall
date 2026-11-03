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


func _finish() -> void:
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
