extends Node
## Repère au sol (GroundMarker) : présent sous un membre de Tocsin, une pièce d'Avare, un couteau générique,
## une doublure (Decoy) et une motte de Bourbe ; disparaît au ramassage / à la mort.
## godot --headless --path game res://tests/ground_marker_test.tscn

const DT := 1.0 / 60.0
const U := 64.0

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _marker_ok(host: Node, pulse: bool) -> bool:
	var m := GroundMarker.of(host)
	if m == null:
		return false
	return m.glow != null and m.ring != null and m.pulse == pulse and m.is_visible_in_tree() \
			and not m.ring.z_as_relative and m.ring.z_index == GroundMarker.Z_RING \
			and m.glow.z_index == GroundMarker.Z_GLOW and m.ring.z_index < 0


func _make_player(character: StringName) -> CharacterBody2D:
	RunState.level = 1
	RunState.character = character
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(p)
	await get_tree().process_frame
	p.set_physics_process(false)
	return p


func _run() -> void:
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)

	print("Textures (rendus Blender d'ambiance)")
	_check("halo_soft_256 livré", AmbianceTextures.is_real(GroundMarker.GLOW_TEX))
	_check("aura_ring_128 livré", AmbianceTextures.is_real(GroundMarker.RING_TEX))

	print("Grammaire des formes au sol (GroundShapes)")
	var shapes := {}
	for sense in GroundShapes.GRAMMAR:
		shapes[GroundShapes.shape_of(sense)] = true
	_check("une forme distincte par sens (%d sens, %d formes)" % [GroundShapes.GRAMMAR.size(), shapes.size()], shapes.size() == GroundShapes.GRAMMAR.size())
	var t_loot := GroundShapes.texture(GroundMarker.SHAPE_LOOT)
	var t_summon := GroundShapes.texture(GroundMarker.SHAPE_SUMMON)
	_check("textures de forme 128², distinctes, non vides", t_loot != t_summon and t_loot.get_width() == 128 and t_summon.get_height() == 128
			and t_loot.get_image().get_pixel(64 + 51, 64).a >= 0.0 and not t_loot.get_image().is_invisible() and not t_summon.get_image().is_invisible())
	var himg := t_summon.get_image()
	_check("hexagone plein : sommet allumé, centre vide", himg.get_pixel(64 + 51, 64).a > 0.5 and himg.get_pixel(64, 64).a < 0.1)
	var dimg := t_loot.get_image()
	_check("losange à tirets : trou au sommet, tiret sur le côté", dimg.get_pixel(64 + 51, 64).a < 0.2 and dimg.get_pixel(64 + 38, 64 - 13).a > 0.5)
	_check("butin et invocation de couleurs différentes", GroundShapes.color_of(&"loot").is_equal_approx(GroundShapes.color_of(&"summon")) == false)

	print("GroundPickup générique (couteau de Rictus)")
	var holder := Node2D.new()
	add_child(holder)
	var g := GroundPickup.spawn(holder, Vector2(100, 100), null, Callable(), 10.0, 0.6, "")
	_check("repère présent, pulsé", _marker_ok(g, true))
	var m := GroundMarker.of(g)
	_check("taille par défaut", is_equal_approx(m.radius_px, GroundPickup.MARKER_U * U))
	_check("butin : losange à tirets (pas un cercle)", m.shape_id() == GroundMarker.SHAPE_LOOT and m.ring.texture == t_loot)
	_check("matériaux partagés (lots)", m.ring.material == GroundMarker.of(GroundPickup.spawn(holder, Vector2.ZERO, null, Callable())).ring.material)
	g.collect()
	await get_tree().process_frame
	_check("ramassé : repère libéré", not is_instance_valid(m))

	print("Pièce d'Avare")
	var pa := await _make_player(&"avare")
	var akit := pa.kit as AvareKit
	var coin := akit.drop_coin(pa.global_position + Vector2(5 * U, 0), 2.0, 30.0)
	_check("pièce posée", coin != null)
	_check("repère sous la pièce", coin != null and _marker_ok(coin, true))
	var cm := GroundMarker.of(coin)
	_check("taille pièce 0,28 u", cm != null and is_equal_approx(cm.radius_px, 0.28 * U))
	_check("plus petit qu'un membre", cm != null and cm.radius_px < 0.55 * U)
	pa.global_position = coin.global_position
	coin.step(DT)
	await get_tree().process_frame
	_check("ramassée : repère libéré", not is_instance_valid(cm))
	pa.queue_free()
	await get_tree().process_frame

	print("Membre de Tocsin (bras au sol)")
	var pt := await _make_player(&"tocsin")
	var tkit := pt.kit as TocsinKit
	pt.spells.aim_override = Vector2(10 * U, 0)
	_check("bras lancé", pt.spells.cast(2))
	for i in int(6.8 / DT):
		pt.spells._remaining[1] = 99.0
		pt.tick(DT)
		for l in tkit.limbs.values():
			if is_instance_valid(l):
				l.set_physics_process(false)
				l.step(DT)
	var leg: TocsinLimb = tkit.limbs.get(&"arm_l")
	_check("bras au sol", leg != null and is_instance_valid(leg) and leg.phase == TocsinLimb.Phase.GROUND and leg.pickup != null)
	if leg != null and is_instance_valid(leg) and leg.pickup != null:
		var lp := leg.pickup
		_check("pickup visible (repère affiché même avec le sprite du membre)", lp.visible)
		_check("repère sous le membre", _marker_ok(lp, true))
		var lm := GroundMarker.of(lp)
		_check("taille membre 0,55 u", lm != null and is_equal_approx(lm.radius_px, 0.55 * U))
		pt.global_position = lp.global_position
		lp.set(&"_t", TocsinKit.PICKUP_DELAY_S)
		lp.step(DT)
		await get_tree().process_frame
		_check("membre ramassé : repère libéré", not is_instance_valid(lm))
	pt.spells.aim_override = null

	print("Invocations")
	var d := Decoy.new()
	add_child(d)
	d.global_position = Vector2(200, 0)
	_check("doublure : repère fixe", _marker_ok(d, false))
	var dm := GroundMarker.of(d)
	d.explode(null)
	await get_tree().process_frame
	_check("doublure explosée : repère libéré", not is_instance_valid(dm))
	var mo := BourbeMotte.new()
	add_child(mo)
	mo.global_position = Vector2(-200, 0)
	_check("motte : repère fixe", _marker_ok(mo, false))
	var mm := GroundMarker.of(mo)
	mo.leave() # mort / recollage : la motte joue son anim de fin, le repère s'éteint tout de suite
	await get_tree().process_frame
	_check("motte partie : repère caché", not is_instance_valid(mm) or not mm.visible)
	mo.queue_free()
	await get_tree().process_frame
	_check("motte libérée : repère libéré", not is_instance_valid(mm))

	pt.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
