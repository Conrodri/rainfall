extends "res://tests/floor1_boss_base.gd"
## Boss d'étage 1 : l'Éclusier (EclusierBrain, sprites C7a) sur les Terrasses noyées.
## godot --headless --path game res://tests/eclusier_boss_test.tscn  -> RESULT: OK
## Vérifie : IA dédiée branchée (plus l'IA générique), anims directionnelles et extras C7a ; phase 1 : coup de
## vanne, lâcher d'eau (vague qui touche au passage du front et pousse le joueur), geysers (4 cercles disjoints,
## le premier sur le joueur) ; phase 2 : nappe d'eau, 2 geysers permanents qui jaillissent, lâcher d'eau double ;
## phase 3 : ancré (immobile, pose `anchored`), croix de la roue qui alterne + / × et touche ; mort : la nappe et
## les geysers permanents restent pendant la charge, puis tout est libéré.

var _geysers_ok := true
var _geysers_seen := 0
var _double_seen := false
var _angles := {}
var _anchored_seen := false


func _init() -> void:
	ID = &"eclusier"
	PREFIX = "Eclusier"
	SAVE = "user://test_eclusier_boss.json"
	AIM_KINDS = [&"gate", &"wave"]


func _b() -> EclusierBrain:
	return brain() as EclusierBrain


func _on_spawned() -> void:
	_check("IA EclusierBrain branchée", _boss.brain is EclusierBrain)
	var sf: SpriteFrames = EnemyVisual.boss_frames(ID)
	_check("sprites C7a livrés", _has_art and sf != null)
	if sf != null:
		var missing: Array = []
		for base in ["auto", "spell_a", "spell_b", "walk_p1", "walk_p3"]:
			for d in ["e", "s", "w", "n"]:
				if not sf.has_animation(StringName("%s_%s" % [base, d])):
					missing.append("%s_%s" % [base, d])
		for x in ["wave", "ground_wave", "geyser", "ground_geyser", "ground_water", "wheel", "anchored_s", "trans_p2_s", "trans_p3_s"]:
			if not sf.has_animation(StringName(x)):
				missing.append(x)
		_check("anims et extras de l'éclusier", missing.is_empty(), str(missing))
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(ID, &"wave"), 1.6)
		and is_equal_approx(Balance.boss_attack_coef(ID, &"geyser"), 1.4) and is_equal_approx(Balance.boss_attack_coef(ID, &"cross"), 1.2))


func _tick_phase(p: int) -> void:
	var b := _b()
	if b == null:
		return
	if b.state == EclusierBrain.S.GEYSERS and float(b.get(&"_t")) < 0.05:
		var g: Array = b.get(&"_geysers")
		_geysers_seen += 1
		if g.size() < 3 or (g[0]["pos"] as Vector2).distance_to(_player().global_position) > 40.0:
			_geysers_ok = false
		for i in g.size():
			for j in range(i + 1, g.size()):
				if (g[i]["pos"] as Vector2).distance_to(g[j]["pos"]) < (2.0 * EclusierBrain.GEYSER_R_U + EclusierBrain.GEYSER_GAP_U) * 64.0 - 0.5:
					_geysers_ok = false
	if p == 2 and b.wave_count() >= 2:
		_double_seen = true
	if p == 3:
		if String(_boss.visual.call(&"current_anim")) == "anchored_s":
			_anchored_seen = true
		if _t > 0.3 and _t < 0.4:
			_anchor = _boss.position


func _end_p1() -> void:
	_check("phase 1 : coup de vanne", int(_kinds.get(&"gate", 0)) >= 2, str(_kinds))
	_check("phase 1 : lâcher d'eau", int(_kinds.get(&"wave", 0)) >= 1, str(_kinds))
	_check("lâcher d'eau : la vague touche au passage du front", int(_kinds.get(&"wave_hit", 0)) >= 1, str(_kinds))
	_check("lâcher d'eau : le joueur est poussé", _b().pushes >= 1, str(_b().pushes))
	_check("phase 1 : geysers qui touchent", int(_kinds.get(&"geysers", 0)) >= 1 and int(_kinds.get(&"geyser_hit", 0)) >= 1, str(_kinds))
	_check("geysers : cercles disjoints, le premier sur le joueur", _geysers_seen >= 1 and _geysers_ok, "vus=%d" % _geysers_seen)
	_check("phase 1 : ni nappe ni croix", _b().hazards().count(&"spring") == 0 and int(_kinds.get(&"cross", 0)) == 0)


func _end_p2() -> void:
	var hz := _b().hazards()
	_check("phase 2 : nappe d'eau sur la zone", hz.count(&"water") == 1)
	_check("phase 2 : 2 geysers permanents", hz.count(&"spring") == 2, str(hz.count(&"spring")))
	_check("phase 2 : les geysers permanents jaillissent (/ 4 s)", hz.pulses >= 4, str(hz.pulses))
	_check("phase 2 : lâcher d'eau double (±30°)", _double_seen)


func _end_p3() -> void:
	var b := _b()
	_check("phase 3 : ancré (immobile)", _boss.position.distance_to(_anchor) < 4.0, "%.1f px" % _boss.position.distance_to(_anchor))
	_check("phase 3 : pose « anchored »", _anchored_seen or not _has_art)
	_check("phase 3 : roue (extra wheel) qui tourne", b.get(&"_wheel") != null or not _has_art)
	_check("phase 3 : croix toutes les 3 s", b.crosses >= 3, str(b.crosses))
	for i in range(_ev_i):
		var ev: Dictionary = b.events[i]
		if ev["kind"] == &"cross":
			_angles[snappedf(float(ev["angle"]), 0.01)] = true
	_check("SURPRISE : la croix alterne + et ×", _angles.size() == 2, str(_angles.keys()))
	_check("phase 3 : la croix touche", int(_kinds.get(&"cross_hit", 0)) >= 1, str(_kinds))
	_check("phase 3 : geysers continuent", int(_kinds.get(&"geysers", 0)) >= 1, str(_kinds))


func _trace_ok(h: Node) -> bool:
	var hz := h as Floor1Hazards
	print("  trace : %d geysers permanents, %d jaillissements" % [hz.count(&"spring"), hz.pulses])
	return hz.trace and hz.count(&"spring") == 2 and hz.count(&"water") == 1


func _shot_key() -> String:
	var b := _b()
	match b.state:
		EclusierBrain.S.WAVE_WIND:
			return "wave_wind" if float(b.get(&"_t")) > 0.8 else ""
		EclusierBrain.S.GEYSERS:
			return "geysers" if float(b.get(&"_t")) > 0.6 else ""
		EclusierBrain.S.GATE:
			return "gate"
		EclusierBrain.S.STAGGER:
			return "trans" if float(b.get(&"_t")) > 0.4 else ""
	if b.wave_count() > 0:
		return "wave_run"
	if bool(b.get(&"_cross_shown")):
		return "cross_warn"
	return ""
