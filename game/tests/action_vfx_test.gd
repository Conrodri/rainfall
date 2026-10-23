extends Node
## Test headless des anims d'action et des VFX de sorts (retour joueur : « aucune animation de lancer,
## aucun VFX, un petit cercle c'est ridicule ») :
## - Ardent : nova / cendres / brasier instancient le SpriteFrames rendu, calé sur le rayon réel (zone_size_add
##   compris) ; repli dessiné si l'asset manque ; auto et sorts déclenchent attack / cast / cast_ult (ou le repli
##   procédural) puis reviennent à idle/run.
## - Rictus : slash_<dir> joué en entier à chaque demi-lune ; Doublures : summon_<dir>, doublures posées à la
##   frame d'impact.
## godot --headless --path game res://tests/action_vfx_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends Node2D:
	var taken: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false


const U := 64.0
const ZoneEffect := preload("res://scripts/spells/zone_effect.gd")

var _fails := 0
var _junk: Array = []


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


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _clear_fakes() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()


func _spawn_player(cid: StringName) -> CharacterBody2D:
	RunState.level = 1
	RunState.character = cid
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody2D
	get_tree().root.add_child(p)
	await get_tree().process_frame
	p.set_physics_process(false) # boucle pilotée par le test
	p.apply_stats({"crit_chance": -0.05})
	return p


## Dernière zone (ZoneEffect) créée sous SpellFX.
func _last_zone(p: Node) -> Node2D:
	var fx := p.get_node("SpellFX")
	for i in range(fx.get_child_count() - 1, -1, -1):
		var c := fx.get_child(i)
		if c.get_script() == ZoneEffect and not c.is_queued_for_deletion():
			return c
	return null


func _spell(p: Node, slot: int) -> SpellData:
	for s in p.character.spells:
		if s.slot == slot:
			return s
	return null


## Avance le joueur (logique + visuel) de `t` secondes par pas de `dt`.
func _advance(p: Node, t: float, dt := 0.01) -> void:
	var n := roundi(t / dt)
	for i in n:
		p.tick(dt)
		p._update_visual(dt)


func _run() -> void:
	await _ardent()
	await _rictus()
	RunState.character = &"ardent"
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _ardent() -> void:
	print("Ardent : VFX de zone rendus")
	var p: CharacterBody2D = await _spawn_player(&"ardent")
	var vis := p.get_node("Visual") as AnimatedSprite2D
	var base_scale := vis.scale
	_fake(Vector2(100, 0))

	# Nova : SpriteFrames rendu, empreinte calée sur 3,5 u
	var nova := _spell(p, 2)
	_check("nova : vfx_frames renseigné", nova.vfx_frames.ends_with("ardent_nova.tres"), nova.vfx_frames)
	_check("nova lancée", p.spells.cast(2))
	_check("nova : effet différé à la frame d'impact", _last_zone(p) == null and p.spells.has_pending())
	var imp: float = p._action_impact_left
	_check("nova : impact cast frame 3 (0,25 s)", _near(imp, 3.0 / 12.0, 0.02), str(imp))
	p._action_step(imp * 0.5)
	_check("nova : rien avant l'impact", _last_zone(p) == null)
	p._action_step(imp * 0.5 + 0.001)
	_check("nova : zone posée à l'impact", _last_zone(p) != null and not p.spells.has_pending())
	var z := _last_zone(p)
	_check("nova : VFX rendu instancié", z != null and z.vfx != null)
	if z != null and z.vfx != null:
		var k := 3.5 * U / nova.vfx_radius_px
		_check("nova : échelle au rayon (3,5 u)", _near(z.vfx_scale().x, k, 0.001), str(z.vfx_scale()))
		_check("nova : empreinte au sol iso (k / aspect)", _near(z.vfx_scale().y, k / nova.vfx_floor_aspect, 0.001), str(z.vfx_scale()))
		_check("nova : gerbe jouée", z.vfx.is_playing() and z.vfx.animation == &"default")
		_check("nova : passe _e additive", z.vfx.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) != null)
		_check("nova : la zone vit jusqu'à la fin de la gerbe", z._anim >= z.anim_length(z.vfx.sprite_frames, &"default") - 0.001)
		z.step(z._anim + 0.01)
		_check("nova : libérée après la gerbe", z.is_queued_for_deletion())

	# Brasier avec Rune de portée : rayon × 1,5
	p.apply_stats({"crit_chance": -0.05, "zone_size_add": 0.5})
	var bra := _spell(p, 4)
	_check("brasier lancé", p.spells.cast(4))
	imp = p._action_impact_left
	_check("brasier : impact cast_ult frame 4 (0,36 s)", _near(imp, 4.0 / 11.0, 0.02), str(imp))
	p._action_step(imp + 0.001)
	z = _last_zone(p)
	_check("brasier : VFX rendu", z != null and z.vfx != null and bra.vfx_frames.ends_with("ardent_brasier.tres"))
	if z != null and z.vfx != null:
		_check("brasier : échelle avec zone_size_add", _near(z.vfx_scale().x, 6.0 * U * 1.5 / bra.vfx_radius_px, 0.001), str(z.vfx_scale()))
		_check("brasier : rayon de gameplay 9 u", _near(z.radius, 9.0 * U, 0.01), str(z.radius))

	# Cendres : zone persistante qui boucle puis s'éteint
	p.apply_stats({"crit_chance": -0.05})
	var ash := _spell(p, 3)
	p.spells.aim_override = Vector2(200, 0)
	_check("cendres lancées", p.spells.cast(3))
	p._action_step(p._action_impact_left + 0.001)
	z = _last_zone(p)
	_check("cendres : VFX rendu", z != null and z.vfx != null and ash.vfx_frames.ends_with("ardent_ashes.tres"))
	if z != null and z.vfx != null:
		_check("cendres : échelle au rayon (2,5 u)", _near(z.vfx_scale().x, 2.5 * U / ash.vfx_radius_px, 0.001))
		_check("cendres : boucle", z.vfx.sprite_frames.get_animation_loop(&"default"))
		z.step(0.05)
		_check("cendres : apparition en fondu", z.vfx.modulate.a > 0.0 and z.vfx.modulate.a < 1.0, str(z.vfx.modulate.a))
		z.step(2.0)
		_check("cendres : pleine intensité", _near(z.vfx.modulate.a, 1.0), str(z.vfx.modulate.a))
		z.step(ash.duration - 2.05 - 0.2)
		var has_end: bool = z.vfx.sprite_frames.has_animation(&"end")
		_check("cendres : s'éteint (fondu ou anim end)", has_end or z.vfx.modulate.a < 0.9, str(z.vfx.modulate.a))
		z.step(0.25)
		if has_end:
			_check("cendres : anim end jouée", z.vfx.animation == &"end")
			z.step(2.0)
		_check("cendres : zone libérée à la fin", z.is_queued_for_deletion())
	p.spells.aim_override = null

	# Repli : asset absent -> contour dessiné, aucun VFX
	var fake_spell := nova.duplicate() as SpellData
	fake_spell.vfx_frames = "res://assets/sprites/vfx/__absent__/__absent__.tres"
	var zf: Node2D = p.spells.spawn_zone(fake_spell, Vector2.ZERO)
	_check("repli : pas de VFX sans asset", zf.vfx == null)
	zf.queue_free()

	print("Ardent : anims d'action")
	_clear_fakes()
	for k in p.spells._remaining:
		p.spells._remaining[k] = 0.0
	_advance(p, 0.5)
	_check("au repos : idle", String(vis.animation).begins_with("idle_"), String(vis.animation))
	_fake(Vector2(100, 0))
	_check("cast(1) auto", p.spells.cast(1))
	_check("auto : action attack", p.action_base() == &"attack", String(p.action_base()))
	var sf := vis.sprite_frames
	var has_attack := sf.has_animation(StringName("attack_" + p._dir_name()))
	var a2 := true
	for d in ["e", "se", "s", "sw", "w", "nw", "n", "ne"]:
		for b: Array in [["attack", 5], ["cast", 6], ["cast_ult", 8]]:
			var an := StringName("%s_%s" % [b[0], d])
			a2 = a2 and sf.has_animation(an) and sf.get_frame_count(an) == b[1] and not sf.get_animation_loop(an)
	_check("A2 : attack 5 / cast 6 / cast_ult 8 frames × 8 dirs, sans boucle", a2)
	_check("A2 : impacts 2 / 3 / 4", p.character.action_impact_frames == {&"attack": 2, &"cast": 3, &"cast_ult": 4}, str(p.character.action_impact_frames))
	_check("auto : tir différé (frame 2)", p.spells.has_pending() and _near(p._action_impact_left, 2.0 / 12.0, 0.02), str(p._action_impact_left))
	p._update_visual(0.0)
	_advance(p, 0.05)
	if has_attack:
		_check("auto : attack_<dir> jouée", String(vis.animation).begins_with("attack_"), String(vis.animation))
	else:
		_check("auto : repli procédural visible (squash/flash)", not vis.scale.is_equal_approx(base_scale)
			or not vis.self_modulate.is_equal_approx(Color.WHITE), "%s %s" % [vis.scale, vis.self_modulate])
	_advance(p, p.action_left() + 0.02)
	_check("auto : retour à idle", p.action_base() == &"" and String(vis.animation).begins_with("idle_"), String(vis.animation))
	_check("repli : échelle et teinte restaurées", vis.scale.is_equal_approx(base_scale) and vis.self_modulate.is_equal_approx(Color.WHITE))
	for k in p.spells._remaining:
		p.spells._remaining[k] = 0.0
	p.spells._remaining[1] = 99.0 # pas d'auto pendant la suite : l'attaque A2 (0,42 s) masquerait le retour à run
	_check("cast(2) nova", p.spells.cast(2))
	_check("nova : action cast", p.action_base() == &"cast")
	_advance(p, p.action_left() + 0.02)
	_check("cast(4) brasier", p.spells.cast(4))
	_check("brasier : action cast_ult", p.action_base() == &"cast_ult")
	var ult_anim: StringName = p.action_anim()
	_check("cast_ult : anim cast_ult, repli cast ou procédural", ult_anim == &"" or String(ult_anim).begins_with("cast"), String(ult_anim))
	p.is_moving = true
	_advance(p, p.action_left() + 0.02)
	_check("après le sort : run en mouvement", String(vis.animation).begins_with("run_"), String(vis.animation))
	p.is_moving = false
	_clear_fakes()
	p.queue_free()
	await get_tree().process_frame


func _rictus() -> void:
	print("Rictus : demi-lune et Doublures")
	var p: CharacterBody2D = await _spawn_player(&"rictus")
	var kit: RictusKit = p.kit
	var vis := p.get_node("Visual") as AnimatedSprite2D
	var sf := vis.sprite_frames
	var front := _fake(Vector2(80, 0))
	_check("demi-lune lancée", p.spells.cast(1))
	_check("action slash", p.action_base() == &"slash")
	_check("slash_e choisie", p.action_anim() == &"slash_e", String(p.action_anim()))
	var full := ZoneEffect.anim_length(sf, &"slash_e")
	_check("durée = anim complète (pas 0,2 s tronquée)", _near(p.action_left(), full, 0.001) and full > 0.2, "%s / %s" % [p.action_left(), full])
	var z := _last_zone(p)
	_check("zone ARC (dagues) créée", z != null and z.arc_half < PI)
	if z != null:
		var asset_ok := ResourceLoader.exists(RictusKit.DAGGER_ARC_FRAMES)
		_check("dagger_arc : VFX si livré, sinon croissant dessiné", (z.vfx != null) == asset_ok)
		if z.vfx != null:
			_check("dagger_arc : tourné vers la cible", _near(z.vfx.rotation, 0.0, 0.01))
	p._update_visual(0.0)
	_check("slash_e jouée depuis la frame 0", vis.animation == &"slash_e" and vis.frame == 0, "%s %d" % [vis.animation, vis.frame])
	_advance(p, full - 0.03)
	_check("slash toujours affichée avant la fin", vis.animation == &"slash_e", String(vis.animation))
	_advance(p, 0.05)
	_check("retour à idle après slash", String(vis.animation).begins_with("idle_"), String(vis.animation))
	# Deuxième demi-lune : l'anim repart à chaque auto
	p.spells._remaining[1] = 0.0
	_check("deuxième demi-lune", p.spells.cast(1))
	p._update_visual(0.0)
	_check("slash rejouée à chaque auto", vis.animation == &"slash_e" and vis.frame == 0)
	# Auto enchaînée avant la fin de l'anim (vitesse d'attaque) : repart de la frame 0
	vis.set_frame_and_progress(2, 0.0)
	p.spells._remaining[1] = 0.0
	p.spells.cast(1)
	p._update_visual(0.0)
	_check("slash relancée en cours d'anim : frame 0", vis.frame == 0, str(vis.frame))
	_clear_fakes()
	_advance(p, full + 0.02)

	print("Rictus : Doublures à la frame d'impact")
	Decoy.clear_all()
	p.spells._remaining[4] = 0.0
	p.spells.aim_override = Vector2(500, 0)
	_check("doublures lancées", p.spells.cast(4))
	_check("aucune doublure avant l'impact", Decoy.live.is_empty() and kit.decoys_pending())
	var ult: StringName = kit.ult_action() # throw_ult (M2b) si livrée, sinon summon
	_check("action %s" % ult, p.action_base() == ult and String(p.action_anim()).begins_with(String(ult) + "_"), String(p.action_anim()))
	var anim: StringName = p.action_anim()
	var fps := sf.get_animation_speed(anim)
	var impact_t := 0.0
	for i in RictusKit.ACTION_IMPACT_FRAMES[ult]:
		impact_t += sf.get_frame_duration(anim, i)
	impact_t /= fps
	var t := 0.0
	while Decoy.live.is_empty() and t < 2.0:
		p.tick(0.01)
		p._update_visual(0.01)
		t += 0.01
	_check("6 doublures posées", Decoy.live.size() == 6, str(Decoy.live.size()))
	_check("posées à la frame d'impact (%.3f s)" % impact_t, _near(t, impact_t, 0.015), str(t))
	_check("anim d'ultime à l'écran pendant l'impact", vis.animation == anim, String(vis.animation))
	var d0: Decoy = Decoy.live[0]
	_check("apparition : pop d'échelle", d0._sprite != null and d0._sprite.scale.x < vis.scale.x, "%s %s" % [d0._sprite.scale if d0._sprite else Vector2.ZERO, vis.scale])
	Decoy.clear_all()
	# Changement d'étage avant l'impact : rien n'apparaît
	p.spells._remaining[4] = 0.0
	p.spells.cast(4)
	Events.floor_started.emit(2)
	_advance(p, 0.6)
	_check("étage changé avant l'impact : aucune doublure", Decoy.live.is_empty())
	p.spells.aim_override = null
	p.queue_free()
	await get_tree().process_frame

