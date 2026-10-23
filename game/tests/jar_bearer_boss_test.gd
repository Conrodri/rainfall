extends "res://tests/floor1_boss_base.gd"
## Boss d'étage 1 : la Porteuse de jarres (JarBearerBrain) sur les Terrasses noyées.
## godot --headless --path game res://tests/jar_bearer_boss_test.tscn  -> RESULT: OK
## Vérifie : IA dédiée ; sans sprites, silhouette provisoire (JarBearer_body) et chemin attendu dans fauna.json ;
## phase 1 : jet de jarre (point de chute marqué, éclate et touche), pluie de jarres (5 cercles disjoints, le
## premier sur le joueur, allumés l'un après l'autre), jarre-mère (cassable par les sorts : cassée, elle s'éteint ;
## sinon anneau qui touche) ; phase 2 : flaques de vase qui ralentissent ; phase 3 : 4 jarres en orbite qui
## touchent, orbite qui respire et change de sens ; mort : flaques restent pendant la charge, puis libérées.

var _rain_ok := true
var _rain_seen := 0
var _broke_one := false
var _r_min := 1.0e9
var _r_max := 0.0


func _init() -> void:
	ID = &"jar_bearer"
	PREFIX = "JarBearer"
	SAVE = "user://test_jar_bearer_boss.json"
	AIM_KINDS = [&"throw", &"mother"]


func _b() -> JarBearerBrain:
	return brain() as JarBearerBrain


func _on_spawned() -> void:
	_check("IA JarBearerBrain branchée", _boss.brain is JarBearerBrain)
	if not _has_art:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"JarBearer_body") != null)
	var cfg := EnemyVisual.boss_cfg(ID)
	_check("fauna.json : IA, brief et extras attendus enregistrés", String(cfg.get("brain", "")).ends_with("jar_bearer_brain.gd")
		and (cfg.get("extras", []) as Array).has("mother_jar"), str(cfg.keys()))
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(ID, &"rain"), 1.3)
		and is_equal_approx(Balance.boss_attack_coef(ID, &"mother"), 1.5) and is_equal_approx(Balance.boss_attack_coef(ID, &"orbit"), 0.6))


func _tick_phase(p: int) -> void:
	var b := _b()
	if b == null:
		return
	var r: Array = b.get(&"_rain")
	if b.state == JarBearerBrain.S.RAIN and not r.is_empty() and float(b.get(&"_t")) < 0.05:
		_rain_seen += 1
		if r.size() < 4 or (r[0]["pos"] as Vector2).distance_to(_player().global_position) > 40.0:
			_rain_ok = false
		for i in r.size():
			for j in range(i + 1, r.size()):
				if (r[i]["pos"] as Vector2).distance_to(r[j]["pos"]) < (2.0 * JarBearerBrain.RAIN_R_U + JarBearerBrain.RAIN_GAP_U) * 64.0 - 0.5:
					_rain_ok = false
			if i > 0 and float(r[i]["t0"]) >= float(r[i - 1]["t0"]):
				_rain_ok = false
	# la première jarre-mère est cassée comme par un sort du joueur (groupe enemies + take_damage), les autres explosent
	if p == 1 and not _broke_one:
		for body in b.mothers():
			var j := body as JarBearerJar
			if j.is_in_group(&"enemies") and j.collision_layer == JarBearerJar.LAYER_ENEMIES:
				_broke_one = true
				j.take_damage(j.max_hp * 0.6)
				j.take_damage(j.max_hp * 0.6)
				break
	if p == 3 and b.orbit_count() > 0:
		_r_min = minf(_r_min, b.orbit_radius())
		_r_max = maxf(_r_max, b.orbit_radius())


func _end_p1() -> void:
	var b := _b()
	_check("phase 1 : jets de jarre qui touchent", int(_kinds.get(&"throw", 0)) >= 2 and int(_kinds.get(&"jar_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : pluie de jarres qui touche", int(_kinds.get(&"rain", 0)) >= 1 and int(_kinds.get(&"rain_hit", 0)) >= 1, str(_kinds))
	_check("pluie : cercles disjoints, le premier sur le joueur, en séquence", _rain_seen >= 1 and _rain_ok, "vus=%d" % _rain_seen)
	_check("jarre-mère : cassée par un coup, elle s'éteint sans exploser", _broke_one and b.mothers_broken >= 1, "broken=%d" % b.mothers_broken)
	_cov("jarre-mère : sinon explose en anneau qui touche", b.mothers_blown >= 1 and int(_kinds.get(&"mother_hit", 0)) >= 1, "blown=%d %s" % [b.mothers_blown, str(_kinds)])
	_check("phase 1 : pas de flaque de vase", b.hazards().count(&"puddle") == 0)


func _end_p2() -> void:
	var hz := _b().hazards()
	_check("phase 2 : flaques de vase", hz.count(&"puddle") >= 1, str(hz.count(&"puddle")))
	_check("phase 2 : la vase ralentit le joueur", hz.slowed >= 1, str(hz.slowed))


func _end_p3() -> void:
	var b := _b()
	_check("phase 3 : 4 jarres en orbite", b.orbit_count() == 4, str(b.orbit_count()))
	_check("phase 3 : l'orbite touche", int(_kinds.get(&"orbit_hit", 0)) >= 1, str(_kinds))
	_check("SURPRISE : l'orbite respire (2,5 -> 4,5 u)", _r_max - _r_min > 1.5 * 64.0, "%.0f..%.0f px" % [_r_min, _r_max])
	_check("SURPRISE : l'orbite change de sens", b.orbit_flips >= 1, str(b.orbit_flips))


func _trace_ok(h: Node) -> bool:
	var hz := h as Floor1Hazards
	print("  trace : %d flaques" % hz.count(&"puddle"))
	return hz.trace and hz.count(&"puddle") >= 1


func _shot_key() -> String:
	var b := _b()
	match b.state:
		JarBearerBrain.S.RAIN:
			return "rain" if float(b.get(&"_t")) > 0.7 else ""
		JarBearerBrain.S.THROW:
			return "throw"
		JarBearerBrain.S.STAGGER:
			return "trans" if float(b.get(&"_t")) > 0.4 else ""
	if b.mother_count() > 0:
		return "mother"
	if b.orbit_count() > 0:
		return "orbit"
	return ""
