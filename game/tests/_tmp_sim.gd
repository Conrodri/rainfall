extends Node
## Simulateur d'équilibrage des personnages (headless). Un combat = une arène vide (sans carte), un Director
## sans flux ni vagues, le vrai joueur (player.tscn + kit) piloté par BotPilot, des monstres posés selon un
## scénario standard. Mesures : dégâts infligés (effectifs, sans overkill), DPS, temps pour tout tuer,
## dégâts subis, morts (le joueur est relevé et la mort comptée), kills/min, lancers par slot, ressource.
## Utilisé par tests/balance_sim_run.tscn (rapport complet) et tests/balance_sim_test.tscn (fumée).
## Ne modifie aucun fichier du jeu ; RunState est réinitialisé à chaque combat (jamais de sauvegarde).

const BotPilot := preload("res://tests/balance_sim/bot_pilot.gd")
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const DIRECTOR_SCENE := "res://scenes/enemies/director.tscn"
const CHARACTERS_JSON := "res://data/characters.json"
const U := 64.0
## Accélération : K ticks physiques de 1/60 s par 1/60 s réelle (delta inchangé, déterministe).
var speed_k := 12
var seed_base := 1234
var boss_hp_mult := 1.0

## Scénarios standard. waves : [{t, packs:[{tier, n, elite, variant, affixes}]}] ; boss : &"mini".
const SCENARIOS := {
	"horde": {"label": "Horde continue saturée 120 s", "cap_s": 120.0, "single": false, "waves": [
		{"t": 0.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 3.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 6.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 9.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 12.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 15.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 18.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 21.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 24.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 27.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 30.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 33.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 36.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 39.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 42.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 45.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 48.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 51.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 54.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 57.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 60.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 63.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 66.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 69.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 72.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 75.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 78.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 81.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 84.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 87.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 90.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 93.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 96.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 99.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 102.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 105.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 108.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 111.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 114.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 117.0, "packs": [{"tier": 1, "n": 8}, {"tier": 2, "n": 4, "variant": 0}, {"tier": 1, "n": 8}, {"tier": 3, "n": 1}]},
		{"t": 118.0, "packs": [{"tier": 3, "n": 1, "elite": true}]}]},
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
}

## Configurations (niveau joueur, mode, étage, temps actif -> D, or de poche, objets neutres sans proc).
const CONFIGS := {
	"L1": {"label": "Niv 1, Moyen 0 min", "level": 1, "mode": "moyen", "stage": 1, "t": 0.0, "gold": 0.0, "items": {}},
	"L6": {"label": "Niv 6, Moyen 6 min", "level": 6, "mode": "moyen", "stage": 1, "t": 360.0, "gold": 150.0,
		"items": {"pierre_a_aiguiser": 1, "sifflet_de_chasse": 1, "bague_de_vigueur": 1, "amulette_de_cuir": 1,
			"sablier_fele": 1, "lentille_aiguisee": 1}},
	"L12": {"label": "Niv 12, Difficile ét.3 4 min", "level": 12, "mode": "difficile", "stage": 3, "t": 240.0, "gold": 400.0,
		"items": {"pierre_a_aiguiser": 2, "sifflet_de_chasse": 2, "bague_de_vigueur": 2, "amulette_de_cuir": 2,
			"sablier_fele": 2, "lentille_aiguisee": 2, "rune_de_portee": 1, "horloge_arcanique": 1, "tonique_vital": 1}},
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
	if scen.has("boss"):
		total += 1
		EnemyVisual._mini_count = 3 # pool par défaut : 4e mini-boss = frost_bear (visuel seulement)
		var b: Node2D = director.spawn_boss(StringName(scen["boss"]), Vector2(6.0 * U, 0.0))
		if b == null:
			total -= 1
		elif boss_hp_mult != 1.0:
			b.max_hp *= boss_hp_mult
			b.hp *= boss_hp_mult
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
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var dur := maxf(_t, 0.001)
	return {
		"char": cid, "scenario": scen_id, "config": cfg_id, "duration": dur, "cleared": cleared,
		"ttk": (_last_kill_t if cleared else -1.0), "spawned": spawned + (1 if scen.has("boss") else 0), "total": total,
		"kills": _kills, "kpm": _kills / dur * 60.0, "dealt": _dealt, "dps": _dealt / dur,
		"taken": _taken, "dtps": _taken / dur, "hits_taken": _hits_taken, "deaths": deaths, "first_death_t": death_t,
		"hp_min": hp_min_frac, "max_hp": max_hp_end,
		"casts": casts, "dodges": bot.dodges, "pref_u": bot.base_pref_u,
		"resource": res_name, "res_mean": (res_sum / res_n if res_n > 0 else -1.0),
		"res_uptime": (res_up / res_n if res_n > 0 else -1.0),
		"errors": errs,
	}


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
				var fresh := load_character(cid) # kit neuf à chaque combat (un kit peut modifier ses SpellData)
				var f: Dictionary = await run_fight(cid, fresh.get("data", lc["data"]), scen_id, cfg_id, cap_scale)
				f["seed"] = seed_base
				out["fights"].append(f)
				print("SIM %s %s %s : %.1fs clear=%s dps=%.1f kills=%d taken=%.0f deaths=%d err=%d" % [cid, cfg_id, scen_id,
					f["duration"], f["cleared"], f["dps"], f["kills"], f["taken"], f["deaths"], (f["errors"] as Array).size()])
	return out
