extends "res://tests/floor1_boss_base.gd"
## Boss d'étage 1 : le Bouvier (OxHerderBrain) sur les Terrasses noyées.
## godot --headless --path game res://tests/ox_herder_boss_test.tscn  -> RESULT: OK
## Vérifie : IA dédiée ; sans sprites, silhouette provisoire (OxHerder_body) et chemin attendu dans fauna.json ;
## phase 1 : cornes, charge (ruée qui touche, sillon d'eau qui ralentit), piétinement en anneau ; phase 2 :
## double charge en V ; phase 3 : s'embourbe (ancré, dégâts reçus ×1,3), vagues de boue tournantes qui touchent,
## s'arrache d'un piétinement puis charge ; mort : sillons et mare restent pendant la charge, puis libérés.

var _bog_mult := 0.0
var _furrows_max := 0


func _init() -> void:
	ID = &"ox_herder"
	PREFIX = "OxHerder"
	SAVE = "user://test_ox_herder_boss.json"
	AIM_KINDS = [&"horns", &"charge"]


func _b() -> OxHerderBrain:
	return brain() as OxHerderBrain


func _on_spawned() -> void:
	_check("IA OxHerderBrain branchée", _boss.brain is OxHerderBrain)
	if not _has_art:
		_check("sans sprite : silhouette provisoire dessinée", _boss.get_node_or_null(^"OxHerder_body") != null)
	var cfg := EnemyVisual.boss_cfg(ID)
	_check("fauna.json : IA, brief et extras attendus enregistrés", String(cfg.get("brain", "")).ends_with("ox_herder_brain.gd")
		and (cfg.get("extras", []) as Array).has("furrow"), str(cfg.keys()))
	_check("coefficients dans Balance", is_equal_approx(Balance.boss_attack_coef(ID, &"charge"), 1.8)
		and is_equal_approx(Balance.boss_attack_coef(ID, &"stomp"), 1.4) and is_equal_approx(Balance.boss_attack_coef(ID, &"mud"), 0.4))


func _tick_phase(p: int) -> void:
	var b := _b()
	if b != null:
		_furrows_max = maxi(_furrows_max, b.furrow_count())
	if b != null and p == 3 and b.state == OxHerderBrain.S.BOGGED:
		_bog_mult = maxf(_bog_mult, b.damage_taken_mult())


func _end_p1() -> void:
	var b := _b()
	_check("phase 1 : cornes", int(_kinds.get(&"horns", 0)) >= 2, str(_kinds))
	_check("phase 1 : charge", int(_kinds.get(&"charge", 0)) >= 1 and b.dashes >= 1, str(_kinds))
	_check("charge : la ruée touche", int(_kinds.get(&"charge_hit", 0)) >= 1, str(_kinds))
	_check("charge : sillon d'eau laissé", _furrows_max >= 1, str(_furrows_max))
	_check("sillon : ralentit le joueur", b.hazards().slowed >= 1, str(b.hazards().slowed))
	_check("phase 1 : piétinement en anneau qui touche", int(_kinds.get(&"stomp", 0)) >= 1 and int(_kinds.get(&"stomp_hit", 0)) >= 1, str(_kinds))
	_check("phase 1 : pas de V ni d'enlisement", int(_kinds.get(&"chain", 0)) == 0 and b.bogs == 0)


func _end_p2() -> void:
	_check("phase 2 : double charge en V", int(_kinds.get(&"chain", 0)) >= 1, str(_kinds))


func _end_p3() -> void:
	var b := _b()
	_check("phase 3 : s'embourbe", b.bogs >= 1, str(b.bogs))
	_check("embourbé : fenêtre de burst (dégâts reçus ×1,3)", is_equal_approx(_bog_mult, 1.3), str(_bog_mult))
	_check("embourbé : vagues de boue qui touchent", int(_kinds.get(&"mud", 0)) >= 1, str(_kinds))
	_check("SURPRISE : s'arrache d'un piétinement puis charge", b.tears >= 1 and int(_kinds.get(&"tear", 0)) >= 1, "tears=%d %s" % [b.tears, str(_kinds)])
	_check("mare de boue (ralentit)", b.hazards().count(&"pool") >= 1)


func _trace_ok(h: Node) -> bool:
	var hz := h as Floor1Hazards
	print("  trace : %d sillons, %d mares" % [hz.count(&"furrow"), hz.count(&"pool")])
	return hz.trace and hz.count(&"furrow") + hz.count(&"pool") >= 1


func _shot_key() -> String:
	var b := _b()
	match b.state:
		OxHerderBrain.S.CHARGE_WIND:
			return "charge_wind" if float(b.get(&"_t")) > 0.6 else ""
		OxHerderBrain.S.CHARGE_DASH:
			return "dash"
		OxHerderBrain.S.STOMP_WIND:
			return "stomp" if float(b.get(&"_t")) > 0.6 else ""
		OxHerderBrain.S.BOGGED:
			return "bogged" if float(b.get(&"_t")) > 2.0 else ""
		OxHerderBrain.S.STAGGER:
			return "trans" if float(b.get(&"_t")) > 0.4 else ""
	if b.furrow_count() >= 2:
		return "furrows"
	return ""
