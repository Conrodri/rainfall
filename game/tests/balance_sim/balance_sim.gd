extends Node
## Simulateur d'équilibrage des personnages (headless). Un combat = une arène vide (sans carte), un Director
## sans flux ni vagues, le vrai joueur (player.tscn + kit) piloté par BotPilot, des monstres posés selon un
## scénario standard. Mesures : dégâts infligés (effectifs, sans overkill), DPS, temps pour tout tuer,
## dégâts subis, morts (le joueur est relevé et la mort comptée), kills/min, lancers par slot, ressource.
## Utilisé par tests/balance_sim_run.tscn (rapport complet) et tests/balance_sim_test.tscn (fumée).
## Ne modifie aucun fichier du jeu ; RunState est réinitialisé à chaque combat (jamais de sauvegarde).

const BotPilot := preload("res://tests/balance_sim/bot_pilot.gd")
const TestTools := preload("res://scripts/testmode/test_tools.gd")
const FLOORS_JSON := "res://data/floors.json"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const DIRECTOR_SCENE := "res://scenes/enemies/director.tscn"
const CHARACTERS_JSON := "res://data/characters.json"
const U := 64.0
## Accélération : K ticks physiques de 1/60 s par 1/60 s réelle (delta inchangé, déterministe).
var speed_k := 12
var seed_base := 1234
var loadout := {} ## variantes de sorts à tester : {slot: id} (--loadout=1:id,2:id du lanceur)
var disabled_slots: Array = [] ## ablation : slots retirés du kit (--noslot=4), pour mesurer la part de DPS d'un sort
## Objets ajoutés à ceux de la configuration (--items=id:n,id:n du lanceur) : sondes de synergies objets × persos.
var extra_items := {}
## Index de la graine en cours (0, 1, ...) : le scénario « floorboss » s'en sert pour varier le boss du pool.
var seed_index := 0
## Boss d'étage exclus du duel « floorboss » : raids (cloches, boucliers à garde-fou) et Anguille (lac absent de
## l'arène vide). Leur TTK se mesure en rencontre avec adds (balance_sim_fullrun --inject) ou en mode test.
const DUEL_EXCLUDED: Array[StringName] = [&"drowned_idol", &"flood_gunner", &"salt_king", &"deep_eel"]

## Scénarios standard. waves : [{t, packs:[{tier, n, elite, variant, affixes}]}] ; boss : &"mini".
const SCENARIOS := {
	"swarm": {"label": "Essaim T1", "cap_s": 60.0, "single": false, "waves": [
		{"t": 0.0, "packs": [{"tier": 1, "n": 8}, {"tier": 1, "n": 8}, {"tier": 1, "n": 8}, {"tier": 1, "n": 8}]},
		{"t": 5.0, "packs": [{"tier": 1, "n": 8}, {"tier": 1, "n": 8}, {"tier": 1, "n": 8}, {"tier": 1, "n": 8}]}]},
	"mixed": {"label": "Mixte + tireurs", "cap_s": 75.0, "single": false, "waves": [
		{"t": 0.0, "packs": [{"tier": 1, "n": 6}, {"tier": 2, "n": 3, "variant": 0}, {"tier": 2, "n": 1, "variant": 1}]},
		{"t": 6.0, "packs": [{"tier": 1, "n": 6}, {"tier": 3, "n": 1}, {"tier": 2, "n": 1, "variant": 1}]},
		{"t": 14.0, "packs": [{"tier": 2, "n": 3, "variant": 0}, {"tier": 1, "n": 4}]}]},
	"elite": {"label": "Élite T3", "cap_s": 90.0, "single": true, "waves": [
		{"t": 0.0, "packs": [{"tier": 3, "n": 1, "elite": true, "affixes": ["burn"]}]}]},
	"miniboss": {"label": "Mini-boss (frost_bear)", "cap_s": 120.0, "single": true, "boss": "mini", "waves": []},
	## Boss d'étage de l'étage de la configuration, en duel (sans monstres de la charge) : boss du pool de
	## data/floors.json hors DUEL_EXCLUDED, choisi par l'index de graine (graine 0 = premier du pool) ; étage 5 = boss
	## final (× FINAL_BOSS_HP_MULT, comme TestTools). Sans adds, 100 % des dégâts vont au boss : le TTK mesuré est
	## donc ≈ BOSS_FOCUS_HP_MULT × le TTK en jeu ; il sert aux écarts entre personnages (ratios), les durées absolues
	## se lisent en rencontre avec adds (balance_sim_fullrun --inject, tools/roster_balance.py).
	"floorboss": {"label": "Boss d'étage (duel, sans adds)", "cap_s": 300.0, "single": true, "boss": "floor", "waves": []},
}

## Configurations (niveau joueur, mode, étage, temps actif -> D, or de poche, objets neutres sans proc).
const CONFIGS := {
	"L1": {"label": "Niv 1, Moyen 0 min", "level": 1, "mode": "moyen", "stage": 1, "t": 0.0, "gold": 0.0, "items": {}},
	"L6": {"label": "Niv 6, Moyen 6 min", "level": 6, "mode": "moyen", "stage": 1, "t": 360.0, "gold": 150.0,
		"items": {"pierre_a_aiguiser": 1, "sifflet_de_chasse": 1, "bague_de_vigueur": 1, "amulette_de_cuir": 1,
			"sablier_fele": 1, "lentille_aiguisee": 1}},
	"L9": {"label": "Niv 9, Moyen ét.2 10 min", "level": 9, "mode": "moyen", "stage": 2, "t": 600.0, "gold": 300.0,
		"items": {"pierre_a_aiguiser": 3, "sifflet_de_chasse": 2, "bague_de_vigueur": 3, "amulette_de_cuir": 2,
			"sablier_fele": 2, "lentille_aiguisee": 2, "rune_de_portee": 1, "horloge_arcanique": 1}},
	"L12": {"label": "Niv 12, Difficile ét.3 4 min", "level": 12, "mode": "difficile", "stage": 3, "t": 240.0, "gold": 400.0,
		"items": {"pierre_a_aiguiser": 2, "sifflet_de_chasse": 2, "bague_de_vigueur": 2, "amulette_de_cuir": 2,
			"sablier_fele": 2, "lentille_aiguisee": 2, "rune_de_portee": 1, "horloge_arcanique": 1, "tonique_vital": 1}},
	## Vraie run Moyen vers l'étage 4 (D ≈ 4,9, niveau ambiant 12, ≈ 30 objets) ; L12 ci-dessus est à D ≈ 2,5 seulement.
	"L12m": {"label": "Niv 12, Moyen ét.4 14,5 min (D≈4,9)", "level": 12, "mode": "moyen", "stage": 4, "t": 870.0, "gold": 800.0,
		"items": {"pierre_a_aiguiser": 5, "sifflet_de_chasse": 3, "bague_de_vigueur": 5, "amulette_de_cuir": 3,
			"sablier_fele": 3, "lentille_aiguisee": 4, "rune_de_portee": 2, "horloge_arcanique": 2, "tonique_vital": 3}},
	## Fin de run / début du sans fin (audit roster 11/11/2026) : niveau 18, étage 5, 20 min (D ≈ 7,1, niveau ambiant 19),
	## ≈ 45 objets neutres de la même famille que L6 / L12m (sans proc), pour prolonger la courbe L1-L6-L12m.
	"L18": {"label": "Niv 18, Moyen ét.5 20 min (D≈7,1)", "level": 18, "mode": "moyen", "stage": 5, "t": 1200.0, "gold": 1500.0,
		"items": {"pierre_a_aiguiser": 7, "sifflet_de_chasse": 4, "bague_de_vigueur": 7, "amulette_de_cuir": 4,
			"sablier_fele": 4, "lentille_aiguisee": 5, "rune_de_portee": 3, "horloge_arcanique": 3, "tonique_vital": 4,
			"botte_rapiecee": 2, "coeur_de_mousse": 2}},
	## Moments des boss d'étage au rythme visé de 19 min (docs/Audit_Runs_Completes_2026-10-31.md §1) : boss d'étage
	## à 150 s de l'étage N (t = 240 (N-1) + 150), boss final à 990 s ; niveau et nombre d'objets moyens mesurés à ces
	## minutes dans les runs complètes (niveau 4 / 8 / 10 / 11 / 12 ; 5 / 13 / 21 / 29 / 33 objets). Inventaire
	## « moyen réaliste » identique pour tous les personnages : communs surtout, quelques procs (Étincelle, Flocon,
	## Fiole, Éclair en bouteille), un rare à partir de l'étage 4. Or de poche ≈ 1 prix de petit coffre (Avare).
	"E1": {"label": "Boss ét.1 : niv 4, 2:30 (D≈1,38)", "level": 4, "mode": "moyen", "stage": 1, "t": 150.0, "gold": 75.0,
		"items": {"pierre_a_aiguiser": 1, "sifflet_de_chasse": 1, "bague_de_vigueur": 1, "etincelle": 1, "sablier_fele": 1}},
	"E2": {"label": "Boss ét.2 : niv 8, 6:30 (D≈2,29)", "level": 8, "mode": "moyen", "stage": 2, "t": 390.0, "gold": 150.0,
		"items": {"pierre_a_aiguiser": 2, "sifflet_de_chasse": 1, "bague_de_vigueur": 2, "amulette_de_cuir": 1,
			"sablier_fele": 1, "lentille_aiguisee": 1, "etincelle": 1, "flocon": 1, "coeur_de_mousse": 1,
			"horloge_arcanique": 1, "eclair_en_bouteille": 1}},
	"E3": {"label": "Boss ét.3 : niv 10, 10:30 (D≈3,43)", "level": 10, "mode": "moyen", "stage": 3, "t": 630.0, "gold": 250.0,
		"items": {"pierre_a_aiguiser": 3, "sifflet_de_chasse": 2, "bague_de_vigueur": 2, "amulette_de_cuir": 2,
			"sablier_fele": 2, "lentille_aiguisee": 2, "etincelle": 1, "flocon": 1, "coeur_de_mousse": 1, "botte_rapiecee": 1,
			"horloge_arcanique": 1, "eclair_en_bouteille": 1, "rune_de_portee": 1, "tonique_vital": 1}},
	"E4": {"label": "Boss ét.4 : niv 11, 14:30 (D≈4,87)", "level": 11, "mode": "moyen", "stage": 4, "t": 870.0, "gold": 400.0,
		"items": {"pierre_a_aiguiser": 4, "sifflet_de_chasse": 3, "bague_de_vigueur": 3, "amulette_de_cuir": 2,
			"sablier_fele": 2, "lentille_aiguisee": 2, "etincelle": 2, "flocon": 1, "fiole_verte": 1, "coeur_de_mousse": 1,
			"botte_rapiecee": 1, "horloge_arcanique": 1, "eclair_en_bouteille": 1, "rune_de_portee": 1, "tonique_vital": 1,
			"marque_du_chasseur": 1, "lame_jumelle": 1, "oeil_du_predateur": 1}},
	"E5": {"label": "Boss final : niv 12, 16:30 (D≈6,13)", "level": 12, "mode": "moyen", "stage": 5, "t": 990.0, "gold": 550.0,
		"items": {"pierre_a_aiguiser": 5, "sifflet_de_chasse": 3, "bague_de_vigueur": 4, "amulette_de_cuir": 3,
			"sablier_fele": 2, "lentille_aiguisee": 2, "etincelle": 2, "flocon": 1, "fiole_verte": 1, "coeur_de_mousse": 1,
			"botte_rapiecee": 1, "horloge_arcanique": 1, "eclair_en_bouteille": 1, "rune_de_portee": 1, "tonique_vital": 2,
			"marque_du_chasseur": 1, "lame_jumelle": 1, "oeil_du_predateur": 1}},
}

## Erreurs captées (Logger) pendant le combat en cours.
class ErrLog extends Logger:
	var entries: Array = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var where := "%s:%d" % [file, line]
		if not file.begins_with("res://"): # erreur du moteur : on situe l'appel GDScript
			for bt in script_backtraces:
				if bt != null and bt.get_frame_count() > 0:
					where = "%s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
					break
		mutex.lock()
		if entries.size() < 200:
			entries.append({"type": error_type, "where": where, "msg": (rationale if rationale != "" else code).left(200),
				"func": function})
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array:
		mutex.lock()
		var out := entries.duplicate()
		entries.clear()
		mutex.unlock()
		return out


var errlog := ErrLog.new()
var _dealt := 0.0
var _dealt_single := 0.0
var _taken := 0.0
var _hits_taken := 0
var _kills := 0
var _last_kill_t := 0.0
var _t := 0.0


func _ready() -> void:
	OS.add_logger(errlog)


func _exit_tree() -> void:
	OS.remove_logger(errlog)
	_set_speed(1)


func _set_speed(k: int) -> void:
	Engine.physics_ticks_per_second = 60 * k
	Engine.max_physics_steps_per_frame = maxi(8, k * 2)
	Engine.time_scale = float(k)


## Personnages jouables de data/characters.json : [{id, name, playable}].
static func roster() -> Array:
	var f := FileAccess.open(CHARACTERS_JSON, FileAccess.READ)
	if f == null:
		return [{"id": "ardent", "name": "Ardent"}]
	var data: Variant = JSON.parse_string(f.get_as_text())
	var out: Array = []
	if data is Array:
		for c in data:
			if c is Dictionary and c.get("playable", true):
				out.append({"id": str(c.get("id", "")), "name": str(c.get("name", c.get("id", "")))})
	return out


## Charge le kit : {ok, data: CharacterData, note, errors}. Kit absent ou incomplet : ok = false (sauté).
func load_character(cid: String) -> Dictionary:
	errlog.take()
	if cid != "ardent" and not ResourceLoader.exists(CharacterData.KIT_PATH % cid):
		return {"ok": false, "skip": true, "note": "kit absent (%s)" % (CharacterData.KIT_PATH % cid), "errors": []}
	var c: CharacterData = null
	if cid == "ardent":
		c = ArdentKit.variant_a()
	else:
		var scr: Variant = load(CharacterData.KIT_PATH % cid)
		if scr == null or not (scr is Script) or not (scr as Script).can_instantiate():
			return {"ok": false, "skip": false, "note": "kit illisible (erreur de parse ?)", "errors": errlog.take()}
		if not _has_static(scr as Script, &"character"):
			return {"ok": false, "skip": true, "note": "kit sans static func character()", "errors": errlog.take()}
		var v: Variant = scr.character()
		c = v as CharacterData
	if c != null and not loadout.is_empty():
		CharacterData.apply_loadout(c, StringName(cid), loadout)
	if c != null and not disabled_slots.is_empty():
		var kept: Array[SpellData] = []
		for s in c.spells:
			if not disabled_slots.has(s.slot):
				kept.append(s)
		c.spells = kept
	var errs := errlog.take()
	if c == null:
		return {"ok": false, "skip": false, "note": "character() n'a pas rendu de CharacterData", "errors": errs}
	var slots := {}
	for s in c.spells:
		if s != null:
			slots[s.slot] = true
	if not slots.has(1):
		return {"ok": false, "skip": true, "note": "kit incomplet : pas de sort 1 (%d sorts)" % c.spells.size(), "errors": errs}
	return {"ok": true, "data": c, "note": "" if slots.size() >= 4 else "kit partiel : %d/4 sorts" % slots.size(),
		"errors": errs}


static func _has_static(scr: Script, m: StringName) -> bool:
	for d in scr.get_script_method_list():
		if StringName(d.get("name", "")) == m:
			return true
	return false


func _reset_run(cid: String, cfg: Dictionary) -> void:
	RunState.start_run(StringName(cfg["mode"]), seed_base)
	RunState.running = false # D figé : le temps actif ne bouge pas pendant le combat
	RunState.stage = int(cfg["stage"])
	RunState.active_time_s = float(cfg["t"])
	RunState.level = int(cfg["level"])
	RunState.character = StringName(cid)
	RunState.gold = float(cfg.get("gold", 0.0)) # or de poche typique (Avare s'en sert)
	RunState.items.clear()
	for k in cfg["items"]:
		RunState.items[StringName(k)] = int(cfg["items"][k])
	for k in extra_items:
		RunState.items[StringName(k)] = int(RunState.items.get(StringName(k), 0)) + int(extra_items[k])


## Un combat. cap_scale raccourcit la durée maximale (test de fumée).
func run_fight(cid: String, cdata: CharacterData, scen_id: String, cfg_id: String, cap_scale := 1.0) -> Dictionary:
	var scen: Dictionary = SCENARIOS[scen_id]
	var cfg: Dictionary = CONFIGS[cfg_id]
	errlog.take()
	_reset_run(cid, cfg)
	seed(seed_base)
	_dealt = 0.0
	_dealt_single = 0.0
	_taken = 0.0
	_hits_taken = 0
	_kills = 0
	_last_kill_t = 0.0
	_t = 0.0

	var world := Node2D.new()
	world.name = "SimWorld"
	add_child(world)
	var director: Node = load(DIRECTOR_SCENE).instantiate()
	director.spawning_enabled = false
	director.waves_enabled = false
	director.enemy_pool_size = 80
	world.add_child(director)
	var player: Node2D = load(PLAYER_SCENE).instantiate()
	player.character = cdata
	player.auto_cast_spells = true
	world.add_child(player)
	player.global_position = Vector2.ZERO
	if player.spells != null:
		player.spells.manual_aim_enabled = false
		player.spells.rng.seed = seed_base
	player.apply_stats(ItemStats.compute(RunState.items))
	player.hp = player.max_hp
	var bot := BotPilot.new()
	bot.setup(player, seed_base)
	var casts := {}
	# lancers : signal SpellCaster.spell_cast (charges des kits comprises), sinon remontée de la recharge
	var cast_sig: bool = player.spells != null and player.spells.has_signal(&"spell_cast")
	if cast_sig:
		player.spells.spell_cast.connect(func(sp: SpellData) -> void: casts[sp.slot] = int(casts.get(sp.slot, 0)) + 1)

	var by_slot := {} # dégâts par slot de sort (spell_hit), pour lire d'où vient la courbe
	if player.spells != null and player.spells.has_signal(&"spell_hit"):
		player.spells.spell_hit.connect(func(sp: SpellData, _e: Node, amount: float) -> void:
			by_slot[sp.slot] = float(by_slot.get(sp.slot, 0.0)) + amount)
	var on_dmg := func(e: Node2D, amount: float, _crit: bool, _el: StringName) -> void:
		var hp_after: float = float(e.get(&"hp")) if e != null else 0.0
		var eff := amount + minf(hp_after, 0.0) # sans overkill
		_dealt += maxf(eff, 0.0)
	var on_hit := func(amount: float, _src: Node) -> void:
		_taken += amount
		_hits_taken += 1
	var on_kill := func(_e: Node2D, _p: Vector2, _tier: int, _el: bool) -> void:
		_kills += 1
		_last_kill_t = _t
	var on_boss_kill := func(_b: Node2D, _floor: bool) -> void:
		_kills += 1
		_last_kill_t = _t
	Events.enemy_damaged.connect(on_dmg)
	Events.player_damaged.connect(on_hit)
	Events.enemy_killed.connect(on_kill)
	Events.boss_killed.connect(on_boss_kill)

	_set_speed(speed_k)
	await get_tree().physics_frame

	var waves: Array = (scen["waves"] as Array).duplicate(true)
	var total := 0
	for w in waves:
		for p in w["packs"]:
			total += int(p["n"])
	var boss_id := ""
	var boss_hp := 0.0
	if scen.has("boss"):
		total += 1
		var b: Node2D = null
		if str(scen["boss"]) == "floor":
			var fb := floor_boss_for(RunState.stage, seed_index)
			boss_id = String(fb["id"])
			if boss_id != "":
				b = TestTools.spawn_boss(get_tree(), fb["id"], fb["kind"], Vector2(6.0 * U, 0.0))
		else:
			EnemyVisual._mini_count = 3 # pool par défaut : 4e mini-boss = frost_bear (visuel seulement)
			b = director.spawn_boss(StringName(scen["boss"]), Vector2(6.0 * U, 0.0))
		if b == null:
			total -= 1
		else:
			boss_hp = float(b.get(&"max_hp"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base
	var cap: float = float(scen["cap_s"]) * cap_scale
	var deaths := 0
	var death_t := -1.0
	var hp_min_frac := 1.0
	var prev_cd := {}
	var res_sum := 0.0
	var res_up := 0.0
	var res_n := 0
	var res_name := ""
	var spawned := 0
	var dt := 1.0 / 60.0
	var cleared := false
	while _t < cap:
		# vagues
		while not waves.is_empty() and float(waves[0]["t"]) <= _t:
			var w: Dictionary = waves.pop_front()
			var a0 := rng.randf() * TAU # paquets d'une vague répartis autour du joueur
			var np: int = (w["packs"] as Array).size()
			for i in np:
				spawned += _spawn_pack(director, player.global_position, w["packs"][i], rng, a0 + TAU * i / np)
		await get_tree().physics_frame
		if Engine.time_scale != float(speed_k): # le hitstop des gros coups remet 1,0 : on réimpose K
			Engine.time_scale = float(speed_k)
		_t += dt
		var enemies := get_tree().get_nodes_in_group(&"enemies")
		bot.tick(dt, enemies)
		if player.dead:
			deaths += 1
			if death_t < 0.0:
				death_t = _t
			player.dead = false
			player.hp = player.max_hp
			player.grant_invulnerability(2.0)
			if player.has_method(&"clear_statuses"):
				player.clear_statuses()
		if player.max_hp > 0.0:
			hp_min_frac = minf(hp_min_frac, player.hp / player.max_hp)
		# lancers : la recharge d'un slot remonte
		for c in player.get_spell_cooldowns():
			var slot := int(c.get("slot", 0))
			var rem := float(c.get("remaining", 0.0))
			if not cast_sig and rem > float(prev_cd.get(slot, 0.0)) + 0.05:
				casts[slot] = int(casts.get(slot, 0)) + 1
			prev_cd[slot] = rem
		var r := _resource(player)
		if not r.is_empty():
			res_name = r["name"]
			res_sum += r["v"]
			res_n += 1
			if r["v"] >= 0.5:
				res_up += 1.0
		if waves.is_empty() and enemies.is_empty() and _t > 0.5:
			cleared = true
			break
	_set_speed(1)
	bot.release()
	Events.enemy_damaged.disconnect(on_dmg)
	Events.player_damaged.disconnect(on_hit)
	Events.enemy_killed.disconnect(on_kill)
	Events.boss_killed.disconnect(on_boss_kill)
	var errs := errlog.take()
	var max_hp_end: float = player.max_hp
	var armor_end: float = player.armor() if player.has_method(&"armor") else 0.0
	var regen_end: float = player.regen_per_s() if player.has_method(&"regen_per_s") else 0.0
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var dur := maxf(_t, 0.001)
	return {
		"char": cid, "scenario": scen_id, "config": cfg_id, "duration": dur, "cleared": cleared,
		"boss_id": boss_id, "boss_hp": boss_hp,
		"ttk": (_last_kill_t if cleared else -1.0), "spawned": spawned + (1 if scen.has("boss") else 0), "total": total,
		"kills": _kills, "kpm": _kills / dur * 60.0, "dealt": _dealt, "dps": _dealt / dur,
		"taken": _taken, "dtps": _taken / dur, "hits_taken": _hits_taken, "deaths": deaths, "first_death_t": death_t,
		"hp_min": hp_min_frac, "max_hp": max_hp_end, "armor": armor_end, "regen": regen_end,
		"casts": casts, "by_slot": by_slot, "dodges": bot.dodges, "pref_u": bot.base_pref_u,
		"resource": res_name, "res_mean": (res_sum / res_n if res_n > 0 else -1.0),
		"res_uptime": (res_up / res_n if res_n > 0 else -1.0),
		"errors": errs,
	}


## Boss d'étage du duel « floorboss » pour un étage : {id, kind}. Pool de data/floors.json sans DUEL_EXCLUDED, choisi par
## l'index de graine ; étage final = boss final (kind &"final"). Étage inconnu ou pool vide : id vide (combat sauté).
static func floor_boss_for(stage: int, index: int) -> Dictionary:
	var f := FileAccess.open(FLOORS_JSON, FileAccess.READ)
	if f == null:
		return {"id": &"", "kind": &"etage"}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return {"id": &"", "kind": &"etage"}
	for fl in data.get("floors", []):
		if int(fl.get("floor", 0)) != stage:
			continue
		var pool: Array = []
		for bid in fl.get("floor_bosses", []):
			if not (StringName(bid) in DUEL_EXCLUDED):
				pool.append(StringName(bid))
		if pool.is_empty():
			return {"id": &"", "kind": &"etage"}
		return {"id": pool[posmod(index, pool.size())], "kind": &"final" if bool(fl.get("final", false)) else &"etage"}
	return {"id": &"", "kind": &"etage"}


func _spawn_pack(director: Node, center: Vector2, p: Dictionary, rng: RandomNumberGenerator, a: float) -> int:
	var n := int(p["n"])
	var c := center + Vector2.from_angle(a) * 7.0 * U
	var aff: Array[StringName] = []
	for x in p.get("affixes", []):
		aff.append(StringName(x))
	var count := 0
	for i in n:
		var pos := c + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * U
		var e: Node = director.spawn_enemy(int(p["tier"]), pos, bool(p.get("elite", false)), aff, int(p.get("variant", -1)))
		if e != null:
			count += 1
	return count


## Ressource du personnage (contrat KitResource : kit.resource_state()), normalisée 0-1. {} = aucune.
func _resource(player: Node) -> Dictionary:
	var d := KitResource.of(player)
	if d.is_empty():
		return {}
	return {"name": String(d["id"]), "v": KitResource.level(d)}


## Combats d'un personnage. scen_ids / cfg_ids : listes. Retourne {char, ok, note, fights:[...]}.
func run_character(cid: String, scen_ids: Array, cfg_ids: Array, cap_scale := 1.0, seeds := 1) -> Dictionary:
	var lc := load_character(cid)
	var out := {"char": cid, "ok": lc["ok"], "skip": lc.get("skip", false), "note": lc["note"],
		"load_errors": lc.get("errors", []), "fights": []}
	if not lc["ok"]:
		return out
	for cfg_id in cfg_ids:
		for scen_id in scen_ids:
			for si in seeds:
				seed_base = 1234 + 1000 * si
				seed_index = si
				var fresh := load_character(cid) # kit neuf à chaque combat (un kit peut modifier ses SpellData)
				var f: Dictionary = await run_fight(cid, fresh.get("data", lc["data"]), scen_id, cfg_id, cap_scale)
				f["seed"] = seed_base
				out["fights"].append(f)
				print("SIM %s %s %s%s : %.1fs clear=%s dps=%.1f kills=%d taken=%.0f deaths=%d err=%d" % [cid, cfg_id, scen_id,
					(" (%s)" % f["boss_id"]) if f["boss_id"] != "" else "", f["duration"], f["cleared"], f["dps"], f["kills"],
					f["taken"], f["deaths"], (f["errors"] as Array).size()])
	return out
