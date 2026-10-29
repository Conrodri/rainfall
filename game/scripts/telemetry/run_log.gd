extends Node
## Journal de run LOCAL (autoload `RunLog`, décision du joueur 28/10/2026 : « équilibrage par les données »).
##
## Une run (hors mode test) = un fichier JSON compact `user://run_logs/run_<date>_<graine>.json` (champ `schema`).
## AUCUN réseau : le fichier reste sur l'appareil ; seul le joueur choisit de l'exporter (RunLogExport, menu Réglages)
## puis de le transmettre. Les 50 dernières runs sont gardées (MAX_LOGS).
##
## Sources : bus Events (run_started / run_finished, floor_*, enemy_*, player_*, boss_*, chest_opened, item_chosen,
## pillar_state_changed, gold_converted), RunState (gold_changed, gold_spent, item_added) et les signaux du
## SpellCaster du joueur (spell_cast, spell_hit). Coût : des cumuls dans des dictionnaires réutilisés, aucune
## allocation par image ; un dictionnaire par minute de jeu actif ; écriture disque à la fin de chaque étage
## (fichier « en cours », repris après « Sauvegarder et quitter ») et à la fin de la run.
##
## Schéma 1 (clés courtes, temps = secondes de jeu actif RunState.active_time_s, dégâts arrondis) :
##   {schema, id, game_version, platform, debug, started_at, ended_at (unix), character, skin, loadout {slot: id},
##    mode, seed, plan [{stage, map, variant, biome, boss, minis}], resumes,
##    floors [{stage, map, t_in, t_clear, t_out, d_in, d_out, lvl_in, lvl_out, gold_earned, gold_spent,
##             gold_converted, xp_from_gold, kills, dmg_taken, chests [{t, q, offered, taken}],
##             items [{t, id, src}], pillars [{t, kind, state}]}],
##    fights [{id, cat (mini | etage | raid | final), stage, hp_max, t_spawn, t_hit, t_end, ttk, outcome (kill |
##             death | unfinished), dmg_dealt, dmg_taken, dmg_from_boss, shield_s, enrage_s, player_died}],
##    minutes [{m, dmg {sort: x, other: y}, casts {sort: n}, cd {sort: recharge moyenne s}, taken {source: x},
##              kills [t1, t2, t3, élites], gold (or gagné cumulé), items (nb d'objets), lvl, d,
##              alive {avg, max} (monstres vivants, échantillonnés toutes les ALIVE_SAMPLE_S s),
##              credits {avg, max} (crédits reportés du director : flux continu + vagues)}],
##    end {result (victory | death | abandon), cause, stage, minute, active_s, level, kills, gold_earned,
##         gold_spent, items {id: n}} | null (run en cours ou quittée sans reprise)}
## Sources de dégâts reçus : "boss:<id>", "t1", "t2_tir", "t2_saut", "t3" (+ "_elite"), "env:<script>", "inconnu".
## « other » = dégâts infligés hors coups de sort directs (brûlure / poison, objets, foudre en chaîne…).

const SCHEMA := 1
const DIR := "user://run_logs"
const MAX_LOGS := 50
const CURRENT_FILE := "current.json" ## pointeur {seed, file} de la run en cours (reprise après sauvegarde)
## Build de test : journal activé par défaut. À REVOIR AVANT LA SORTIE (défaut false, ou garder : rien ne quitte
## l'appareil sans action du joueur).
const TEST_BUILD := true
const SETTINGS_SECTION := "telemetry"
const SETTINGS_KEY := "run_log"

## Dossier effectif (tests : dossier injecté). Hors tests, rien n'est écrit en headless (comme GameSettings).
var log_dir := DIR
## Vrai pendant une run journalisée.
var recording := false

var _log: Dictionary = {}
var _file := ""
var _floor: Dictionary = {}
var _fights: Dictionary = {} ## instance_id du boss -> fiche de combat ouverte
var _shield_since: Dictionary = {} ## instance_id du boss -> temps actif de la levée du bouclier
var _caster: Object = null
var _last_gold := 0.0
var _gold_earned := 0.0
var _gold_spent := 0.0
var _last_source := "inconnu"
var _pending_chest: Dictionary = {}
var _last_write_t := -999.0 ## temps actif de la dernière écriture « en cours »
const ALIVE_SAMPLE_S := 2.0 ## période d'échantillonnage des vivants et des crédits du director (temps de jeu actif)
const SAVE_WRITE_EVERY_S := 60.0 ## écriture sur sauvegarde de run (Events.run_saved) au plus une fois par minute

# Minute en cours (dictionnaires réutilisés : vidés, jamais réalloués)
var _m_idx := 0
var _m_dmg := {} ## id de sort (StringName) -> dégâts
var _m_dmg_total := 0.0
var _m_casts := {}
var _m_cd := {} ## id de sort -> somme des recharges lancées
var _m_taken := {} ## clé de source (String) -> dégâts
var _m_kills := PackedInt32Array([0, 0, 0, 0])
var _m_alive_sum := 0.0
var _m_alive_max := 0
var _m_credit_sum := 0.0
var _m_credit_max := 0.0
var _m_samples := 0
var _next_sample_s := 0.0
var _director: Director = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE # le temps actif ne court pas en pause
	Events.run_started.connect(_on_run_started)
	Events.run_finished.connect(_on_run_finished)
	Events.floor_started.connect(_on_floor_started)
	Events.floor_cleared.connect(_on_floor_cleared)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_killed)
	Events.boss_shield_changed.connect(_on_boss_shield)
	Events.chest_opened.connect(_on_chest_opened)
	Events.item_chosen.connect(_on_item_chosen)
	Events.pillar_state_changed.connect(_on_pillar)
	Events.gold_converted.connect(_on_gold_converted)
	Events.run_saved.connect(_on_run_saved)
	RunState.gold_changed.connect(_on_gold_changed)
	RunState.gold_spent.connect(_on_gold_spent)
	RunState.item_added.connect(_on_item_added)


# --- Réglage « Journal de run » -------------------------------------------------------------------

static func enabled() -> bool:
	return bool(GameSettings.get_value(SETTINGS_SECTION, SETTINGS_KEY, TEST_BUILD))


static func set_enabled(on: bool) -> void:
	GameSettings.set_value(SETTINGS_SECTION, SETTINGS_KEY, on)


## Écriture possible : dossier injecté (tests) ou jeu réel (pas en headless ni en capture vidéo).
func can_write() -> bool:
	if log_dir != DIR:
		return true
	return DisplayServer.get_name() != "headless" and Engine.get_write_movie_path() == ""


## Fichiers de journaux présents (noms triés du plus ancien au plus récent ; le pointeur exclu).
func list_logs() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(log_dir):
		return out
	for f in DirAccess.get_files_at(log_dir):
		if f.begins_with("run_") and f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


# --- Cycle de vie ---------------------------------------------------------------------------------

func _on_run_started(resumed: bool) -> void:
	_stop()
	if TestMode.active or not enabled() or not can_write():
		return # mode test / bac à sable : rien n'est journalisé
	DirAccess.make_dir_recursive_absolute(log_dir)
	_log = {}
	if resumed:
		_log = _load_current()
	if _log.is_empty():
		_new_log(resumed)
	else:
		_log["resumes"] = int(_log.get("resumes", 0)) + 1
		var floors: Array = _log["floors"]
		if not floors.is_empty() and int((floors.back() as Dictionary).get("stage", 0)) == RunState.stage:
			floors.pop_back() # l'étage repris recommence (la carte est rejouée depuis la sauvegarde)
		var t := RunState.active_time_s
		_log["minutes"] = (_log["minutes"] as Array).filter(func(m: Dictionary) -> bool: return float(m["m"]) * 60.0 < t)
		_log["fights"] = (_log["fights"] as Array).filter(func(f: Dictionary) -> bool: return float(f["t_spawn"]) < t)
		_gold_earned = float(_log.get("_gold_earned", 0.0))
		_gold_spent = float(_log.get("_gold_spent", 0.0))
		_log.erase("_gold_earned")
		_log.erase("_gold_spent")
	_last_gold = RunState.gold
	_last_source = "inconnu"
	_m_idx = int(RunState.active_time_s / 60.0)
	_clear_minute()
	recording = true
	_write(true)


func _new_log(resumed: bool) -> void:
	var now := Time.get_unix_time_from_system()
	var stamp := Time.get_datetime_string_from_unix_time(int(now)).replace("-", "").replace(":", "").replace("T", "-")
	_file = "run_%s_%08x.json" % [stamp, RunState.run_seed & 0xffffffff]
	var lo := {}
	for k in RunState.loadout:
		lo[str(k)] = String(RunState.loadout[k])
	_log = {
		"schema": SCHEMA, "id": _file.trim_prefix("run_").trim_suffix(".json"),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"platform": OS.get_name(), "debug": OS.is_debug_build(), "started_at": int(now), "ended_at": 0,
		"character": String(RunState.character), "skin": _skin(), "loadout": lo, "mode": String(RunState.mode),
		"seed": RunState.run_seed, "plan": [], "resumes": 1 if resumed else 0, "resumed_without_log": resumed,
		"floors": [], "fights": [], "minutes": [], "end": null,
	}
	_gold_earned = 0.0
	_gold_spent = 0.0


func _skin() -> String:
	var s: Variant = Skins.equipped(RunState.character)
	return str(s) if s != null else ""


func _on_run_finished(victory: bool, reason: StringName) -> void:
	if not recording:
		return
	var t := RunState.active_time_s
	for iid in _fights.keys():
		_close_fight(iid, "death" if reason == &"death" else "unfinished")
	_close_floor()
	_flush_minute()
	_log["ended_at"] = int(Time.get_unix_time_from_system())
	var items := {}
	for k in RunState.items:
		items[String(k)] = int(RunState.items[k])
	_log["end"] = {
		"result": "victory" if victory else String(reason), "cause": _last_source if reason == &"death" else "",
		"stage": RunState.stage, "minute": snappedf(t / 60.0, 0.01), "active_s": snappedf(t, 0.1),
		"level": RunState.level, "kills": RunState.kills, "gold_earned": roundi(_gold_earned),
		"gold_spent": roundi(_gold_spent), "items": items,
	}
	_write(false)
	DirAccess.remove_absolute(log_dir.path_join(CURRENT_FILE))
	rotate()
	_stop()


func _stop() -> void:
	recording = false
	_fights.clear()
	_shield_since.clear()
	_floor = {}
	_pending_chest = {}
	if _caster != null and is_instance_valid(_caster):
		if _caster.is_connected(&"spell_hit", _on_spell_hit):
			_caster.disconnect(&"spell_hit", _on_spell_hit)
		if _caster.is_connected(&"spell_cast", _on_spell_cast):
			_caster.disconnect(&"spell_cast", _on_spell_cast)
	_caster = null


## Garde les MAX_LOGS journaux les plus récents (noms horodatés : l'ordre alphabétique est chronologique).
func rotate() -> void:
	var files := list_logs()
	var extra := files.size() - MAX_LOGS
	for i in maxi(extra, 0):
		DirAccess.remove_absolute(log_dir.path_join(files[i]))


## Sauvegarde de run (autosave 15 s, pause, « Sauvegarder et quitter ») : le journal en cours suit, au plus une fois
## par minute de jeu actif (une reprise retrouve alors presque tout).
func _on_run_saved() -> void:
	if recording and RunState.active_time_s - _last_write_t >= SAVE_WRITE_EVERY_S:
		_write(true)


func _notification(what: int) -> void:
	if not recording:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write(true) # « Sauvegarder et quitter », mise en arrière-plan : la run reprendra ce fichier


# --- Étages ---------------------------------------------------------------------------------------

func _on_floor_started(stage: int) -> void:
	if not recording:
		return
	_close_floor()
	_bind_caster()
	if (_log["plan"] as Array).is_empty():
		_log["plan"] = _plan()
	var sm := get_tree().get_first_node_in_group(&"stage_manager")
	_floor = {
		"stage": stage, "map": str(sm.get(&"map_id")) if sm != null else "", "t_in": _t(), "t_clear": -1.0,
		"t_out": -1.0, "d_in": snappedf(RunState.difficulty(), 0.01), "d_out": 0.0, "lvl_in": RunState.level,
		"lvl_out": 0, "gold_earned": 0.0, "gold_spent": 0.0, "gold_converted": 0.0, "xp_from_gold": 0.0,
		"kills": 0, "dmg_taken": 0.0, "chests": [], "items": [], "pillars": [],
	}
	(_log["floors"] as Array).append(_floor)
	_write(true)


func _on_floor_cleared(_stage: int) -> void:
	if recording and not _floor.is_empty():
		_floor["t_clear"] = _t()
		_write(true)


func _close_floor() -> void:
	if _floor.is_empty():
		return
	for iid in _fights.keys():
		_close_fight(iid, "unfinished")
	_floor["t_out"] = _t()
	# D de fin avec l'étage qui se termine (RunState.stage est déjà incrémenté au changement d'étage)
	_floor["d_out"] = snappedf(Balance.difficulty(RunState.active_time_s, int(_floor["stage"]), Balance.MODES[RunState.mode]), 0.01)
	_floor["lvl_out"] = RunState.level
	for k in ["gold_earned", "gold_spent", "gold_converted", "xp_from_gold", "dmg_taken"]:
		_floor[k] = roundi(float(_floor[k]))
	_floor = {}


func _plan() -> Array:
	var out: Array = []
	var sm := get_tree().get_first_node_in_group(&"stage_manager")
	var plan: Variant = sm.get(&"floor_plan") if sm != null else null
	if plan is Array:
		for e in plan:
			if e is Dictionary:
				out.append({"stage": int(e.get("stage", 0)), "map": str(e.get("map_id", "")),
					"variant": str(e.get("variant", "")), "biome": str(e.get("biome", "")),
					"boss": str(e.get("floor_boss", "")), "minis": (e.get("minis", []) as Array).duplicate()})
	return out


## SpellCaster du joueur (Player.spells) : dégâts et lancers par sort.
func _bind_caster() -> void:
	var p := get_tree().get_first_node_in_group(&"player")
	var c: Variant = p.get(&"spells") if p != null else null
	if c == null or c == _caster or not (c as Object).has_signal(&"spell_hit"):
		return
	_caster = c
	_caster.connect(&"spell_hit", _on_spell_hit)
	_caster.connect(&"spell_cast", _on_spell_cast)


# --- Minutes --------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if recording and int(RunState.active_time_s / 60.0) != _m_idx:
		_flush_minute()
		_m_idx = int(RunState.active_time_s / 60.0)
	if recording and RunState.active_time_s >= _next_sample_s:
		_next_sample_s = RunState.active_time_s + ALIVE_SAMPLE_S
		_sample_director()


## Monstres vivants et crédits reportés du director (équilibrage : saturation de la zone de charge).
func _sample_director() -> void:
	if not is_instance_valid(_director):
		_director = get_tree().get_first_node_in_group(&"director") as Director
		if _director == null:
			return
	var alive := _director.active_count()
	var cr: float = _director.credits + _director.wave_credits
	_m_alive_sum += alive
	_m_alive_max = maxi(_m_alive_max, alive)
	_m_credit_sum += cr
	_m_credit_max = maxf(_m_credit_max, cr)
	_m_samples += 1


func _clear_minute() -> void:
	_m_dmg.clear()
	_m_dmg_total = 0.0
	_m_casts.clear()
	_m_cd.clear()
	_m_taken.clear()
	_m_kills.fill(0)
	_m_alive_sum = 0.0
	_m_alive_max = 0
	_m_credit_sum = 0.0
	_m_credit_max = 0.0
	_m_samples = 0


func _minute_dict() -> Dictionary:
	var dmg := {}
	var spells := 0.0
	for k in _m_dmg:
		dmg[String(k)] = roundi(_m_dmg[k])
		spells += float(_m_dmg[k])
	dmg["other"] = roundi(maxf(_m_dmg_total - spells, 0.0))
	var casts := {}
	var cd := {}
	for k in _m_casts:
		casts[String(k)] = int(_m_casts[k])
		cd[String(k)] = snappedf(float(_m_cd.get(k, 0.0)) / maxf(float(_m_casts[k]), 1.0), 0.01)
	var taken := {}
	for k in _m_taken:
		taken[k] = roundi(_m_taken[k])
	return {"m": _m_idx, "dmg": dmg, "casts": casts, "cd": cd, "taken": taken, "kills": Array(_m_kills),
		"gold": roundi(_gold_earned), "items": _item_count(), "lvl": RunState.level,
		"d": snappedf(RunState.difficulty(), 0.01),
		"alive": {"avg": snappedf(_m_alive_sum / maxf(_m_samples, 1.0), 0.1), "max": _m_alive_max},
		"credits": {"avg": snappedf(_m_credit_sum / maxf(_m_samples, 1.0), 0.1), "max": snappedf(_m_credit_max, 0.1)}}


func _flush_minute() -> void:
	if _m_dmg_total > 0.0 or not _m_casts.is_empty() or not _m_taken.is_empty() or _m_kills.count(0) < 4:
		(_log["minutes"] as Array).append(_minute_dict())
	_clear_minute()


func _item_count() -> int:
	var n := 0
	for k in RunState.items:
		n += int(RunState.items[k])
	return n


# --- Combat ---------------------------------------------------------------------------------------

func _on_spell_hit(spell: Resource, _enemy: Node, amount: float) -> void:
	if recording:
		var id: StringName = spell.get(&"id")
		_m_dmg[id] = float(_m_dmg.get(id, 0.0)) + amount


func _on_spell_cast(spell: Resource) -> void:
	if not recording:
		return
	var id: StringName = spell.get(&"id")
	_m_casts[id] = int(_m_casts.get(id, 0)) + 1
	var totals: Variant = _caster.get(&"_totals") if _caster != null else null
	if totals is Dictionary:
		_m_cd[id] = float(_m_cd.get(id, 0.0)) + float((totals as Dictionary).get(spell.get(&"slot"), 0.0))


func _on_enemy_damaged(enemy: Node2D, amount: float, _crit: bool, _element: StringName) -> void:
	if not recording:
		return
	_m_dmg_total += amount
	if enemy is Enemy and (enemy as Enemy).is_boss:
		var f: Variant = _fights.get(enemy.get_instance_id())
		if f != null:
			if float(f["t_hit"]) < 0.0:
				f["t_hit"] = _t()
			f["dmg_dealt"] = float(f["dmg_dealt"]) + amount


func _on_enemy_killed(_enemy: Node2D, _pos: Vector2, tier: int, is_elite: bool) -> void:
	if not recording:
		return
	_m_kills[clampi(tier, 1, 3) - 1] += 1
	if is_elite:
		_m_kills[3] += 1
	if not _floor.is_empty():
		_floor["kills"] = int(_floor["kills"]) + 1


func _on_player_damaged(amount: float, source: Node) -> void:
	if not recording:
		return
	var key := _source_key(source)
	_last_source = key
	_m_taken[key] = float(_m_taken.get(key, 0.0)) + amount
	if not _floor.is_empty():
		_floor["dmg_taken"] = float(_floor["dmg_taken"]) + amount
	for iid in _fights:
		var f: Dictionary = _fights[iid]
		f["dmg_taken"] = float(f["dmg_taken"]) + amount
		if source != null and is_instance_valid(source) and source.get_instance_id() == iid:
			f["dmg_from_boss"] = float(f["dmg_from_boss"]) + amount


func _on_player_died() -> void:
	if not recording:
		return
	for iid in _fights:
		(_fights[iid] as Dictionary)["player_died"] = true


func _source_key(src: Node) -> String:
	if src == null or not is_instance_valid(src):
		return "inconnu"
	if src is Enemy:
		var e := src as Enemy
		if e.is_boss:
			return "boss:" + _boss_ident(e)
		var k := "t%d" % e.tier
		if e.tier == 2:
			k += "_saut" if e.variant == Enemy.VARIANT_LEAPER else "_tir"
		return k + "_elite" if e.is_elite else k
	var sc: Variant = src.get_script()
	if sc is Script and (sc as Script).resource_path != "":
		return "env:" + (sc as Script).resource_path.get_file().get_basename()
	return "env:" + String(src.name)


func _boss_ident(e: Node) -> String:
	var id := String(e.get_meta(&"boss_id", &""))
	if id == "" and e.has_method(&"boss_id"):
		id = String(e.call(&"boss_id"))
	return id if id != "" else String(e.get(&"boss_kind"))


func _boss_cat(e: Node) -> String:
	if bool(e.get_meta(&"final_boss", false)):
		return "final"
	var kind := String(e.get(&"boss_kind"))
	if kind == "etage" and Enemy.RAID_BRAINS.has(StringName(_boss_ident(e))):
		return "raid"
	return kind if kind != "" else "mini"


func _on_boss_spawned(boss: Node2D, _is_floor_boss: bool) -> void:
	if not recording or boss == null:
		return
	_fights[boss.get_instance_id()] = {
		"id": "", "cat": "", "stage": RunState.stage, "hp_max": 0.0, "t_spawn": _t(), "t_hit": -1.0,
		"t_end": -1.0, "ttk": -1.0, "outcome": "", "dmg_dealt": 0.0, "dmg_taken": 0.0, "dmg_from_boss": 0.0,
		"shield_s": 0.0, "enrage_s": 0.0, "player_died": false, "_node": boss,
	}


func _on_boss_killed(boss: Node2D, _is_floor_boss: bool) -> void:
	if recording and boss != null:
		_close_fight(boss.get_instance_id(), "kill")


func _close_fight(iid: int, outcome: String) -> void:
	var f: Variant = _fights.get(iid)
	if f == null:
		return
	_fights.erase(iid)
	if _shield_since.has(iid):
		f["shield_s"] = float(f["shield_s"]) + _t() - float(_shield_since[iid])
		_shield_since.erase(iid)
	var boss: Variant = f["_node"]
	f.erase("_node")
	if boss != null and is_instance_valid(boss):
		f["id"] = _boss_ident(boss)
		f["cat"] = _boss_cat(boss)
		f["hp_max"] = roundi(float(boss.get(&"max_hp")))
		f["enrage_s"] = snappedf(maxf(float(boss.get(&"fight_time")) - Balance.BOSS_ENRAGE_AFTER_S, 0.0), 0.1)
	f["t_end"] = _t()
	f["outcome"] = outcome
	var start := float(f["t_hit"]) if float(f["t_hit"]) >= 0.0 else float(f["t_spawn"])
	f["ttk"] = snappedf(float(f["t_end"]) - start, 0.1) if outcome == "kill" else -1.0
	for k in ["dmg_dealt", "dmg_taken", "dmg_from_boss"]:
		f[k] = roundi(float(f[k]))
	f["shield_s"] = snappedf(float(f["shield_s"]), 0.1)
	(_log["fights"] as Array).append(f)


func _on_boss_shield(boss: Node2D, active: bool, _kind: StringName) -> void:
	if not recording or boss == null:
		return
	var iid := boss.get_instance_id()
	if active:
		if not _shield_since.has(iid):
			_shield_since[iid] = _t()
	elif _shield_since.has(iid):
		var f: Variant = _fights.get(iid)
		if f != null:
			f["shield_s"] = float(f["shield_s"]) + _t() - float(_shield_since[iid])
		_shield_since.erase(iid)


# --- Économie et objets -----------------------------------------------------------------------------

func _on_gold_changed(gold: float) -> void:
	if not recording:
		_last_gold = gold
		return
	var d := gold - _last_gold
	_last_gold = gold
	if d > 0.0:
		_gold_earned += d
		if not _floor.is_empty():
			_floor["gold_earned"] = float(_floor["gold_earned"]) + d


func _on_gold_spent(amount: float) -> void:
	if not recording:
		return
	_gold_spent += amount
	if not _floor.is_empty():
		_floor["gold_spent"] = float(_floor["gold_spent"]) + amount


func _on_gold_converted(gold: float, xp: float) -> void:
	# Émis par StageManager juste APRÈS floor_started de l'étage suivant : l'or appartient à l'étage précédent.
	if not recording:
		return
	var floors: Array = _log["floors"]
	var target: Dictionary = floors[floors.size() - 2] if floors.size() >= 2 else _floor
	if not target.is_empty():
		target["gold_converted"] = roundi(float(target["gold_converted"]) + gold)
		target["xp_from_gold"] = roundi(float(target["xp_from_gold"]) + xp)


func _on_chest_opened(_chest: Node, quality: StringName, offered: Array) -> void:
	if not recording or _floor.is_empty():
		return
	var ids: Array = []
	for o in offered:
		ids.append(str(o))
	_pending_chest = {"t": _t(), "q": String(quality), "offered": ids, "taken": ""}
	(_floor["chests"] as Array).append(_pending_chest)


func _on_item_added(item_id: StringName, _stacks: int) -> void:
	if recording and not _floor.is_empty():
		(_floor["items"] as Array).append({"t": _t(), "id": String(item_id), "src": "autre"})


func _on_item_chosen(item_id: StringName) -> void:
	# RunState.add_item (item_added) précède item_chosen : l'objet qui vient d'être noté vient du coffre.
	if not recording or _floor.is_empty():
		return
	var items: Array = _floor["items"]
	if not items.is_empty() and items.back()["id"] == String(item_id):
		items.back()["src"] = "coffre:" + String(_pending_chest.get("q", "?"))
	if not _pending_chest.is_empty():
		_pending_chest["taken"] = String(item_id)
		_pending_chest = {}


func _on_pillar(pillar: Node, state: StringName) -> void:
	if not recording or _floor.is_empty() or pillar == null:
		return
	var kind := "final" if bool(pillar.get(&"final_boss")) else ("gros" if int(pillar.get(&"kind")) == Pillar.Kind.BIG else "petit")
	(_floor["pillars"] as Array).append({"t": _t(), "kind": kind, "state": String(state)})


# --- Fichiers -------------------------------------------------------------------------------------

func _t() -> float:
	return snappedf(RunState.active_time_s, 0.1)


## Écrit le journal (en cours : avec la minute partielle et le pointeur de reprise).
func _write(in_progress: bool) -> void:
	if _log.is_empty() or _file == "":
		return
	_last_write_t = RunState.active_time_s
	var out := _log
	if in_progress:
		out = _log.duplicate() # surface : la minute partielle et les cumuls de reprise n'entrent pas dans _log
		out["partial_minute"] = _minute_dict()
		out["_gold_earned"] = _gold_earned
		out["_gold_spent"] = _gold_spent
	var f := FileAccess.open(log_dir.path_join(_file), FileAccess.WRITE)
	if f == null:
		push_warning("RunLog : écriture impossible (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(out, "", false))
	f.close()
	if in_progress:
		var p := FileAccess.open(log_dir.path_join(CURRENT_FILE), FileAccess.WRITE)
		if p != null:
			p.store_string(JSON.stringify({"seed": RunState.run_seed, "file": _file}))
			p.close()


## Journal en cours de la même graine (reprise d'une sauvegarde) ; {} sinon.
func _load_current() -> Dictionary:
	var ptr: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_dir.path_join(CURRENT_FILE)))
	if not (ptr is Dictionary) or int(ptr.get("seed", 0)) != RunState.run_seed:
		return {}
	var name := str(ptr.get("file", ""))
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(log_dir.path_join(name)))
	if not (d is Dictionary) or int(d.get("schema", 0)) != SCHEMA or d.get("end") != null:
		return {}
	d.erase("partial_minute")
	_file = name
	return d
