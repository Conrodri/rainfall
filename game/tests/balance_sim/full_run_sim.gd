extends Node
## Simulation de run complète (headless) pour l'audit d'équilibrage du 31/10/2026.
## Arène vide (sans carte), vrai Director (flux continu + vagues, rampe, plafond), vrai joueur (player.tscn + kit)
## piloté par BotPilot, D qui monte avec le temps actif (RunState.running), étages 1-5 enchaînés.
## Économie fidèle : or et XP de chaque kill par Balance.monster_gold / monster_xp (coût du tier, élite), capsules,
## achats de petits / grands coffres au prix Balance.chest_price (D figé de l'étage), qualité tirée par
## LootRoller.roll_quality, paire tirée par LootRoller.pick_pair (le bot en garde une au hasard), coffre de boss
## après chaque boss d'étage, conversion de l'or restant en XP au changement d'étage (RunState).
## Rythme d'un étage 1-4 (paramétrable) : mini-boss du plan à T_MINI1 et T_MINI2 (zone de crédits « mini » tant
## qu'il vit), boss d'étage à T_BOSS (zone « etage » pendant la charge de 60 s), sortie après la charge + le boss
## + T_AFTER. Étage 5 : boss final (rain_sower, × FINAL_BOSS_HP_MULT) à T_FINAL.
## À lancer avec `--fixed-fps 60` (1 frame = 1/60 s de jeu, sans attente réelle) : voir tests/balance_sim_fullrun.gd.
## Ne modifie aucun fichier du jeu ; aucune sauvegarde (RunLog ignore les runs hors partie).

const BotPilot := preload("res://tests/balance_sim/bot_pilot.gd")
const Sim := preload("res://tests/balance_sim/balance_sim.gd")
const TestTools := preload("res://scripts/testmode/test_tools.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const DIRECTOR_SCENE := "res://scenes/enemies/director.tscn"
const FLOORS_JSON := "res://data/floors.json"
const U := 64.0

## Rythme d'étage (secondes depuis le début de l'étage).
var t_mini1 := 60.0
var t_mini2 := 130.0
var t_boss := 180.0
var t_after := 15.0
var t_final := 30.0
var boss_cap_s := 300.0 ## boss non tué après ça : compté « non tué » et retiré
var mini_cap_s := 150.0
var final_cap_s := 420.0
var stages := 5
## Économie du bot.
var gold_pickup := 1.0 ## part de l'or des kills ramassée
var capsules_per_stage := 6 ## capsules d'argent ramassées par étage (sur 10)
var chest_min_gap_s := 20.0 ## un coffre au plus toutes les N s (trajet jusqu'au coffre)
var chests_max_per_stage := 14
var large_chance := 0.25 ## si l'or le permet, part des achats faits en grand coffre
var mode: StringName = &"moyen"
## Essais d'équilibrage sans toucher Balance : PV des boss rééchelonnés après apparition (1 = valeurs du jeu).
var try_stage_k := 0.0 ## 0 = Balance.BOSS_STAGE_K ; sinon PV × (try_stage_k / BOSS_STAGE_K)^(étage - 1)
var try_final_mult := 0.0 ## 0 = Balance.FINAL_BOSS_HP_MULT
var try_mini_hp := 1.0 ## facteur sur les PV des mini-boss
var try_etage_hp := 1.0 ## facteur sur les PV des boss d'étage (et du final)
var boss_aim_priority := 1.0 ## essai : priorité de ciblage automatique des boss (Enemy.aim_priority, distance ÷ ce facteur)
var charge_zone: StringName = &"etage" ## zone de crédits pendant la charge (&"mini" = ×1,5 au lieu de ×2,33, &"" = aucune)

var seed_value := 1234
## Rencontre ciblée (scénario rapide) : {stage, t, level, items:{id: n}, boss?} ; vide = run complète.
## L'étage `stage` seul est joué, sans mini-boss, boss (ou final) à t_boss_inject s, coffres coupés.
var inject := {}
var t_boss_inject := 5.0
var _inject_mini := false
var cdata: CharacterData
var cid := ""

# --- mesures
var _t_stage := 0.0
var _hits := {} ## instance_id -> {t0, n, dealt, max_hp}
var _ttk := {} ## catégorie -> [ttk...] ; _hk : catégorie -> [coups...]
var _hk := {}
var _maxhp := {} ## catégorie -> [max_hp...]
var _dealt_win := 0.0
var _dealt_stage := 0.0
var _taken_win := 0.0
var _taken_stage := 0.0
var _deaths := 0
var _deaths_stage := 0
var _kills_stage := 0
var _gold_stage := 0.0
var _boss_alive: Node2D = null
var _boss_kind := &""
var _boss_t0 := 0.0
var _boss_deaths0 := 0
var _boss_dealt0 := 0.0
var _bosses: Array = []
var _boss_dealt := 0.0 ## dégâts portés au boss vivant seulement (le reste va aux monstres de la charge)


func _cat(e: Node, tier: int, elite: bool) -> String:
	if e != null and bool(e.get(&"is_boss")):
		if e.has_meta(&"final_boss"):
			return "final"
		return "mini" if StringName(e.get(&"boss_kind")) == &"mini" else "etage"
	var names := {1: "essaim", 2: "tireur", 3: "brute"}
	return str(names.get(tier, "t%d" % tier)) + ("_elite" if elite else "")


func _push(d: Dictionary, k: String, v: float) -> void:
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(v)


func _floor_plan(rng: RandomNumberGenerator) -> Array:
	var f := FileAccess.open(FLOORS_JSON, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var out: Array = []
	for fl in data["floors"]:
		var bosses: Array = fl.get("floor_bosses", [])
		var minis: Array = (fl.get("minis", []) as Array).duplicate()
		var m: Array = []
		for i in 2:
			if minis.is_empty():
				break
			m.append(minis.pop_at(rng.randi_range(0, minis.size() - 1)))
		out.append({"floor": int(fl["floor"]), "boss": bosses[rng.randi_range(0, bosses.size() - 1)], "minis": m,
			"final": bool(fl.get("final", false))})
	return out


func run(character_id: String, data: CharacterData) -> Dictionary:
	cid = character_id
	cdata = data
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var plan := _floor_plan(rng)
	RunState.start_run(mode, seed_value)
	RunState.character = StringName(cid)
	var first_stage := 1
	if not inject.is_empty():
		first_stage = int(inject["stage"])
		stages = first_stage
		RunState.stage = first_stage
		RunState.active_time_s = float(inject["t"])
		RunState.begin_floor()
		while RunState.level < int(inject["level"]):
			RunState.add_xp(Balance.xp_required(RunState.level))
		for k in inject["items"]:
			RunState.items[StringName(k)] = int(inject["items"][k])
		if str(inject.get("kind", "etage")) == "mini": # mini-boss seul (zone « mini »), sans boss d'étage
			plan[first_stage - 1]["minis"] = [inject["boss"]]
			t_mini1 = t_boss_inject
			t_boss = 1.0e9
			_inject_mini = true
		else:
			if inject.has("boss"):
				plan[first_stage - 1]["boss"] = inject["boss"]
			plan[first_stage - 1]["minis"] = []
			t_boss = t_boss_inject
		t_final = t_boss_inject
		chests_max_per_stage = 0
		capsules_per_stage = 0
	seed(seed_value)

	var world := Node2D.new()
	world.name = "SimWorld"
	add_child(world)
	var director: Node = load(DIRECTOR_SCENE).instantiate()
	world.add_child(director)
	var player: Node2D = load(PLAYER_SCENE).instantiate()
	player.character = cdata
	player.auto_cast_spells = true
	world.add_child(player)
	player.global_position = Vector2.ZERO
	if player.spells != null:
		player.spells.manual_aim_enabled = false
		player.spells.rng.seed = seed_value
	player.apply_stats(ItemStats.compute(RunState.items))
	player.hp = player.max_hp
	var bot := BotPilot.new()
	bot.setup(player, seed_value)

	var on_dmg := func(e: Node2D, amount: float, _crit: bool, _el: StringName) -> void:
		if e == null:
			return
		var hp_after := float(e.get(&"hp"))
		var eff := maxf(amount + minf(hp_after, 0.0), 0.0)
		_dealt_win += eff
		_dealt_stage += eff
		if e == _boss_alive:
			_boss_dealt += eff
		var id := e.get_instance_id()
		var h: Dictionary = _hits.get(id, {})
		if h.is_empty():
			h = {"t0": _t_stage, "n": 0, "max_hp": float(e.get(&"max_hp"))}
			_hits[id] = h
		h["n"] = int(h["n"]) + 1
	var on_hit := func(amount: float, _src: Node) -> void:
		_taken_win += amount
		_taken_stage += amount
	var on_kill := func(e: Node2D, _p: Vector2, tier: int, elite: bool) -> void:
		var D := RunState.difficulty()
		if e != null and not bool(e.get(&"is_boss")):
			var g := Balance.monster_gold(D, Balance.monster_cost(tier, elite)) * gold_pickup
			RunState.add_gold(g)
			_gold_stage += g
			RunState.add_xp(Balance.monster_xp(D, Balance.monster_cost(tier, elite)))
			_kills_stage += 1
		_record_kill(e, tier, elite)
	var on_boss_kill := func(b: Node2D, is_floor: bool) -> void:
		var D := RunState.difficulty()
		var kind := &"etage" if is_floor else &"mini"
		var g := Balance.boss_gold(kind, D)
		RunState.add_gold(g)
		_gold_stage += g
		RunState.add_xp(Balance.boss_xp(kind, D))
		_record_kill(b, 0, false)
	Events.enemy_damaged.connect(on_dmg)
	Events.player_damaged.connect(on_hit)
	Events.enemy_killed.connect(on_kill)
	Events.boss_killed.connect(on_boss_kill)
	await get_tree().physics_frame

	var dt := 1.0 / 60.0
	var minutes: Array = []
	var floors_out: Array = []
	var next_min := 60.0
	var t_run := 0.0
	var hp_min := 1.0
	var max_alive := 0
	var alive_sum := 0.0
	var alive_n := 0
	for st in range(first_stage, stages + 1):
		var fp: Dictionary = plan[st - 1]
		if st > first_stage:
			RunState.convert_gold_to_xp()
			RunState.stage = st
			RunState.begin_floor()
			director.despawn_all()
			player.global_position = Vector2.ZERO
		_t_stage = 0.0
		_hits.clear()
		_dealt_stage = 0.0
		_taken_stage = 0.0
		_deaths_stage = 0
		_kills_stage = 0
		_gold_stage = 0.0
		var lvl_in := RunState.level
		var d_in := RunState.difficulty()
		var chests := 0
		var last_chest := -999.0
		var caps_done := 0
		var minis_left: Array = (fp["minis"] as Array).duplicate()
		var mini_times: Array = [t_mini1, t_mini2]
		var boss_spawned := false
		var boss_done := false
		var charge := 0.0
		var leave_at := -1.0
		var is_final: bool = fp["final"]
		var stage_cap := (t_final + final_cap_s + 5.0) if is_final else (t_boss + boss_cap_s + 60.0)
		while _t_stage < stage_cap:
			await get_tree().physics_frame
			_t_stage += dt
			t_run += dt
			var enemies := get_tree().get_nodes_in_group(&"enemies")
			bot.tick(dt, enemies)
			if player.dead:
				_deaths += 1
				_deaths_stage += 1
				player.dead = false
				player.hp = player.max_hp
				player.grant_invulnerability(2.0)
				if player.has_method(&"clear_statuses"):
					player.clear_statuses()
			if player.max_hp > 0.0:
				hp_min = minf(hp_min, player.hp / player.max_hp)
			var alive: int = director.active_count()
			max_alive = maxi(max_alive, alive)
			alive_sum += alive
			alive_n += 1
			# capsules d'argent ramassées en chemin
			if caps_done < capsules_per_stage and _t_stage >= 15.0 + 25.0 * caps_done:
				caps_done += 1
				var cg := Balance.capsule_gold(RunState.difficulty(), st)
				RunState.add_gold(cg)
				_gold_stage += cg
			# coffres
			if not is_final and chests < chests_max_per_stage and _t_stage - last_chest >= chest_min_gap_s:
				if _try_buy_chest(player, st, rng):
					chests += 1
					last_chest = _t_stage
			# boss vivant : délai dépassé ?
			if _boss_alive != null:
				var cap := mini_cap_s if _boss_kind == &"mini" else (final_cap_s if _boss_kind == &"final" else boss_cap_s)
				if not is_instance_valid(_boss_alive) or not bool(_boss_alive.get(&"active")):
					_boss_alive = null
				elif _t_stage - _boss_t0 > cap:
					_finish_boss(false, float(_boss_alive.get(&"hp")) / maxf(float(_boss_alive.get(&"max_hp")), 1.0))
					director.release_enemy(_boss_alive)
					_boss_alive = null
					director.set_zone(1, Vector2.ZERO, 0.0, false)
			if is_final:
				if not boss_spawned and _t_stage >= t_final:
					boss_spawned = true
					_spawn_boss(director, player, StringName(fp["boss"]), &"final", st)
				if boss_spawned and _boss_alive == null:
					break
			else:
				if _inject_mini and minis_left.is_empty() and _boss_alive == null:
					break # rencontre ciblée de mini-boss : fini (tué ou abandonné)
				if _boss_alive == null and not minis_left.is_empty() and not boss_spawned and _t_stage >= float(mini_times[0]):
					mini_times.pop_front()
					_spawn_boss(director, player, StringName(minis_left.pop_front()), &"mini", st)
				if not boss_spawned and _t_stage >= t_boss and _boss_alive == null:
					boss_spawned = true
					_spawn_boss(director, player, StringName(fp["boss"]), &"etage", st)
				if boss_spawned:
					charge += dt
					director.set_zone(2, player.global_position, 4000.0, charge < Balance.PILLAR_CHARGE_S and charge_zone != &"", charge_zone)
					if _boss_alive == null and not boss_done:
						boss_done = true
						_open_chest(player, &"boss", rng) # coffre de boss gratuit
					if boss_done and charge >= Balance.PILLAR_CHARGE_S and leave_at < 0.0:
						leave_at = _t_stage + t_after
					if leave_at >= 0.0 and _t_stage >= leave_at:
						break
			if t_run >= next_min:
				next_min += 60.0
				minutes.append({"min": int(round(t_run / 60.0)), "stage": st, "D": snappedf(RunState.difficulty(), 0.01),
					"mlvl": Balance.monster_level(RunState.difficulty()), "level": RunState.level,
					"items": _item_count(), "dps": snappedf(_dealt_win / 60.0, 0.1), "dtps": snappedf(_taken_win / 60.0, 0.1),
					"hp": snappedf(player.hp / maxf(player.max_hp, 1.0), 0.01), "max_hp": snappedf(player.max_hp, 1.0),
					"alive": alive, "deaths": _deaths, "gold": snappedf(RunState.gold, 1.0)})
				_dealt_win = 0.0
				_taken_win = 0.0
		director.set_zone(2, Vector2.ZERO, 0.0, false)
		floors_out.append({"stage": st, "boss": fp["boss"], "minis": fp["minis"], "dur": snappedf(_t_stage, 0.1),
			"d_in": snappedf(d_in, 0.01), "d_out": snappedf(RunState.difficulty(), 0.01), "lvl_in": lvl_in,
			"lvl_out": RunState.level, "items_out": _item_count(), "chests": chests, "kills": _kills_stage,
			"gold": snappedf(_gold_stage, 1.0), "dps": snappedf(_dealt_stage / maxf(_t_stage, 1.0), 0.1),
			"taken": snappedf(_taken_stage, 1.0), "deaths": _deaths_stage})
		print("STAGE %s %d : %.0fs D %.2f->%.2f niv %d obj %d coffres %d kills %d dps %.0f subi %.0f morts %d" % [cid, st,
			_t_stage, d_in, RunState.difficulty(), RunState.level, _item_count(), chests, _kills_stage,
			_dealt_stage / maxf(_t_stage, 1.0), _taken_stage, _deaths_stage])

	bot.release()
	Events.enemy_damaged.disconnect(on_dmg)
	Events.player_damaged.disconnect(on_hit)
	Events.enemy_killed.disconnect(on_kill)
	Events.boss_killed.disconnect(on_boss_kill)
	var items_final := {}
	for k in RunState.items:
		items_final[String(k)] = RunState.items[k]
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var ttk_out := {}
	for k in _ttk:
		ttk_out[k] = _stats(_ttk[k], _hk.get(k, []), _maxhp.get(k, []))
	return {"char": cid, "seed": seed_value, "run_s": snappedf(t_run, 0.1), "deaths": _deaths, "hp_min": hp_min,
		"max_alive": max_alive, "alive_mean": snappedf(alive_sum / maxf(alive_n, 1), 0.1), "floors": floors_out,
		"minutes": minutes, "bosses": _bosses, "ttk": ttk_out, "items": items_final, "level": RunState.level}


func _item_count() -> int:
	var n := 0
	for k in RunState.items:
		n += int(RunState.items[k])
	return n


func _try_buy_chest(player: Node, st: int, rng: RandomNumberGenerator) -> bool:
	var D := RunState.floor_start_d
	var p_small := Balance.chest_price(&"petit", D, st)
	var p_large := Balance.chest_price(&"large", D, st)
	if RunState.gold >= p_large and rng.randf() < large_chance:
		RunState.spend_gold(p_large)
		_open_chest(player, &"large", rng)
		return true
	if RunState.gold >= p_small:
		RunState.spend_gold(p_small)
		_open_chest(player, &"petit", rng)
		return true
	return false


func _open_chest(player: Node, kind: StringName, rng: RandomNumberGenerator) -> void:
	var q: Dictionary = LootRoller.roll_quality(kind, rng, 0)
	var pair: Array = LootRoller.pick_pair(StringName(q["quality"]), RunState.items, [], rng)
	if pair.is_empty():
		return
	var pick: String = pair[rng.randi_range(0, pair.size() - 1)]
	var frac: float = player.hp / maxf(player.max_hp, 1.0)
	RunState.add_item(StringName(pick))
	player.apply_stats(ItemStats.compute(RunState.items))
	player.hp = frac * player.max_hp


func _spawn_boss(director: Node, player: Node2D, id: StringName, kind: StringName, st: int) -> void:
	var pos := player.global_position + Vector2(0.0, -6.0 * U)
	var b: Node2D = TestTools.spawn_boss(get_tree(), id, kind, pos)
	if b == null:
		print("BOSS absent : %s" % id)
		return
	var f := 1.0
	if try_stage_k > 0.0:
		f *= pow(try_stage_k / Balance.BOSS_STAGE_K, st - 1)
	if kind == &"final" and try_final_mult > 0.0:
		f *= try_final_mult / Balance.FINAL_BOSS_HP_MULT
	f *= try_mini_hp if kind == &"mini" else try_etage_hp
	if f != 1.0:
		b.set(&"max_hp", float(b.get(&"max_hp")) * f)
		b.set(&"hp", float(b.get(&"max_hp")))
	if boss_aim_priority != 1.0 and &"aim_priority" in b:
		b.set(&"aim_priority", boss_aim_priority)
	_boss_alive = b
	_boss_kind = kind
	_boss_t0 = _t_stage
	_boss_deaths0 = _deaths
	_boss_dealt0 = _dealt_stage
	_boss_dealt = 0.0
	if kind == &"mini":
		director.set_zone(1, player.global_position, 4000.0, true, &"mini")
	_bosses.append({"id": String(id), "kind": String(kind), "stage": st, "D": snappedf(RunState.difficulty(), 0.01),
		"level": RunState.level, "items": _item_count(), "max_hp": snappedf(float(b.get(&"max_hp")), 1.0),
		"killed": false, "ttk": -1.0, "deaths": 0, "hp_left": 1.0})


func _finish_boss(killed: bool, hp_left: float) -> void:
	if _bosses.is_empty():
		return
	var r: Dictionary = _bosses[-1]
	r["killed"] = killed
	r["ttk"] = snappedf(_t_stage - _boss_t0, 0.1)
	r["deaths"] = _deaths - _boss_deaths0
	r["hp_left"] = snappedf(hp_left, 0.01)
	r["dps"] = snappedf((_dealt_stage - _boss_dealt0) / maxf(_t_stage - _boss_t0, 0.1), 0.1)
	r["boss_dps"] = snappedf(_boss_dealt / maxf(_t_stage - _boss_t0, 0.1), 0.1)
	r["focus"] = snappedf(_boss_dealt / maxf(_dealt_stage - _boss_dealt0, 1.0), 0.01)
	print("BOSS %s %s (%s ét.%d) : tué=%s %.1fs morts %d PV %.0f" % [cid, r["id"], r["kind"], r["stage"], killed, r["ttk"],
		r["deaths"], r["max_hp"]])


func _record_kill(e: Node, tier: int, elite: bool) -> void:
	if e == null:
		return
	var cat := _cat(e, tier, elite)
	var id := e.get_instance_id()
	var h: Dictionary = _hits.get(id, {})
	_hits.erase(id)
	if e == _boss_alive:
		_finish_boss(true, 0.0)
		_boss_alive = null
		if _boss_kind == &"mini":
			var d := get_tree().get_first_node_in_group(&"director")
			if d != null:
				d.set_zone(1, Vector2.ZERO, 0.0, false)
	if h.is_empty():
		return
	var ttk := _t_stage - float(h["t0"])
	if ttk < 0.0: # coups reçus à l'étage précédent (pool)
		return
	for k in [cat, "s%d:%s" % [RunState.stage, cat]]:
		_push(_ttk, k, ttk)
		_push(_hk, k, float(h["n"]))
		_push(_maxhp, k, float(h["max_hp"]))


static func _stats(ttk: Array, hits: Array, hp: Array) -> Dictionary:
	var s := ttk.duplicate()
	s.sort()
	var hs := hits.duplicate()
	hs.sort()
	var n := s.size()
	var mean := 0.0
	for v in s:
		mean += v
	var one := 0
	for v in hs:
		if v <= 2.0:
			one += 1
	var hpm := 0.0
	for v in hp:
		hpm += v
	return {"n": n, "ttk_mean": snappedf(mean / maxf(n, 1), 0.01), "ttk_med": snappedf(s[n / 2] if n > 0 else 0.0, 0.01),
		"hits_med": hs[n / 2] if n > 0 else 0.0, "le2hits": snappedf(float(one) / maxf(n, 1), 0.01),
		"hp_mean": snappedf(hpm / maxf(hp.size(), 1), 1.0)}
