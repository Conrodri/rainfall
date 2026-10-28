class_name Achievements
extends RefCounted
## Succès locaux : définitions (data/achievements.json), conditions et progression. Logique pure (sans écouteur) :
## les événements sont écoutés par MetaTracker, qui appelle `evaluate`. Aucune dépendance réseau.
## Contexte `ctx` d'une évaluation : {stage, victory, mode, time_s, quality, run_end} (clés absentes = non pertinentes).

const PATH := "res://data/achievements.json"
const FLOORS_PATH := "res://data/floors.json"

static var _cache: Array = []
static var _floors: Array = []


static func all() -> Array:
	if _cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if parsed is Dictionary and (parsed as Dictionary).get("achievements") is Array:
			for a in parsed["achievements"]:
				if a is Dictionary and str(a.get("id", "")) != "" and a.get("cond") is Dictionary:
					_cache.append(a)
	return _cache


static func reset_cache() -> void:
	_cache = []
	_floors = []


static func def_of(id: String) -> Dictionary:
	for a in all():
		if str(a["id"]) == id:
			return a
	return {}


static func unlocked_count(profile: Object) -> int:
	var n := 0
	for a in all():
		if _unlocked(profile, str(a["id"])):
			n += 1
	return n


static func _unlocked(profile: Object, id: String) -> bool:
	return bool(profile.call(&"is_achievement_unlocked", id))


## Boss d'étage de l'étage `floor_n` (data/floors.json), limités à ceux dont le sprite est livré.
## Si aucun n'est livré, tous (le succès reste atteignable une fois les sprites livrés).
static func floor_bosses(floor_n: int) -> Array:
	if _floors.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOORS_PATH)) if FileAccess.file_exists(FLOORS_PATH) else null
		if parsed is Dictionary and (parsed as Dictionary).get("floors") is Array:
			_floors = parsed["floors"]
	for f in _floors:
		if f is Dictionary and int(f.get("floor", 0)) == floor_n:
			var all_ids: Array = f.get("floor_bosses", [])
			var out: Array = []
			for b in all_ids:
				if EnemyVisual.boss_available(StringName(str(b))):
					out.append(str(b))
			return out if not out.is_empty() else all_ids.duplicate()
	return []


static func all_floor_bosses() -> Array:
	var out: Array = []
	for n in range(1, 8):
		out.append_array(floor_bosses(n))
	return out


## Personnages à avoir gagnés pour « chaque personnage » : jouables et non cachés (comme le défi du jour).
static func win_roster() -> Array:
	var out: Array = []
	for c in DailyChallenge.roster():
		out.append(str(c.get("id", "")))
	return out


static func _wins_with(profile: Object) -> int:
	var br: Variant = profile.get("best_runs")
	if not (br is Dictionary):
		return 0
	var n := 0
	for cid in br:
		if br[cid] is Dictionary and not (br[cid] as Dictionary).is_empty():
			n += 1
	return n


static func _has_won_with(profile: Object, cid: String) -> bool:
	var br: Variant = profile.get("best_runs")
	return br is Dictionary and (br as Dictionary).get(cid) is Dictionary and not (br[cid] as Dictionary).is_empty()


static func _boss_kill_total(profile: Object) -> int:
	var n := 0
	var bk: Variant = profile.get("boss_kills")
	if bk is Dictionary:
		for k in bk:
			n += int(bk[k])
	return n


static func _has_killed(profile: Object, ids: Array) -> bool:
	if ids.is_empty():
		return false
	var bk: Variant = profile.get("boss_kills")
	if not (bk is Dictionary):
		return false
	for id in ids:
		if int((bk as Dictionary).get(str(id), 0)) <= 0:
			return false
	return true


static func _run_items_total() -> int:
	var n := 0
	for k in RunState.items:
		n += int(RunState.items[k])
	return n


static func _run_stack_max() -> int:
	var m := 0
	for k in RunState.items:
		m = maxi(m, int(RunState.items[k]))
	return m


## Valeur d'un compteur à vie, y compris la part de la run en cours pour les kills (ajoutés au profil en fin de run).
static func stat_value(profile: Object, key: String, live := true) -> float:
	var v := float(profile.call(&"stat", key))
	if live and key == "kills" and RunState.running:
		v += float(RunState.kills)
	return v


## {cur, max} de la progression affichable, ou {} si le succès n'a pas de compteur (oui/non).
static func progress(profile: Object, def: Dictionary, live := true) -> Dictionary:
	var c: Dictionary = def["cond"]
	match str(c.get("type", "")):
		"stat":
			return {"cur": minf(stat_value(profile, str(c["key"]), live), float(c["value"])), "max": float(c["value"])}
		"boss_count":
			return {"cur": minf(float(_boss_kill_total(profile)), float(c["value"])), "max": float(c["value"])}
		"boss_floor_set", "boss_all":
			var ids: Array = all_floor_bosses() if str(c["type"]) == "boss_all" else floor_bosses(int(c.get("floor", 0)))
			var got := 0
			var bk: Variant = profile.get("boss_kills")
			for id in ids:
				if bk is Dictionary and int((bk as Dictionary).get(str(id), 0)) > 0:
					got += 1
			return {"cur": float(got), "max": float(maxi(ids.size(), 1))}
		"win_characters":
			var need := win_roster().size() if str(c.get("value")) == "all" else int(c["value"])
			return {"cur": minf(float(_wins_with(profile)), float(need)), "max": float(maxi(need, 1))}
		"daily_completed":
			return {"cur": minf(float(_daily_int(profile, "completed")), float(c["value"])), "max": float(c["value"])}
		"daily_streak":
			return {"cur": minf(float(_daily_int(profile, "best_streak")), float(c["value"])), "max": float(c["value"])}
	return {}


static func _daily_int(profile: Object, key: String) -> int:
	var d: Variant = profile.get("daily")
	return int((d as Dictionary).get(key, 0)) if d is Dictionary else 0


## La condition est-elle remplie dans ce contexte ?
static func met(profile: Object, def: Dictionary, ctx: Dictionary) -> bool:
	var c: Dictionary = def["cond"]
	match str(c.get("type", "")):
		"stat":
			return stat_value(profile, str(c["key"])) >= float(c["value"])
		"floor_cleared":
			return int(ctx.get("stage", 0)) >= int(c["value"])
		"run_victory":
			if not bool(ctx.get("run_end", false)) or not bool(ctx.get("victory", false)):
				return false
			if c.has("mode") and str(ctx.get("mode", "")) != str(c["mode"]):
				return false
			if c.has("max_time_s") and float(ctx.get("time_s", INF)) > float(c["max_time_s"]):
				return false
			return true
		"run_time":
			return bool(ctx.get("run_end", false)) and float(ctx.get("time_s", 0.0)) >= float(c["value"])
		"boss_count":
			return _boss_kill_total(profile) >= int(c["value"])
		"boss_floor_set":
			return _has_killed(profile, floor_bosses(int(c.get("floor", 0))))
		"boss_all":
			return _has_killed(profile, all_floor_bosses())
		"win_characters":
			if str(c.get("value")) == "all":
				var r := win_roster()
				if r.is_empty():
					return false
				for cid in r:
					if not _has_won_with(profile, str(cid)):
						return false
				return true
			return _wins_with(profile) >= int(c["value"])
		"chest_quality":
			return str(ctx.get("quality", "")) == str(c["value"])
		"run_items":
			return RunState.running and _run_items_total() >= int(c["value"])
		"run_stacks":
			return RunState.running and _run_stack_max() >= int(c["value"])
		"run_level":
			return RunState.running and RunState.level >= int(c["value"])
		"daily_completed":
			return _daily_int(profile, "completed") >= int(c["value"])
		"daily_streak":
			return _daily_int(profile, "best_streak") >= int(c["value"])
	return false


## Évalue tous les succès non débloqués ; débloque ceux dont la condition est remplie. Retourne les définitions débloquées.
static func evaluate(profile: Object, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	for a in all():
		var id := str(a["id"])
		if _unlocked(profile, id):
			continue
		if met(profile, a, ctx) and bool(profile.call(&"unlock_achievement", id)):
			out.append(a)
	return out


## Icône d'un succès : `icon` (chemin) ou `icon_char` (portrait du personnage) ; null si introuvable.
static func icon_of(def: Dictionary) -> Texture2D:
	var p := str(def.get("icon", ""))
	if p != "" and ResourceLoader.exists(p):
		return load(p) as Texture2D
	var cid := str(def.get("icon_char", ""))
	if cid != "":
		for c in CharacterCard.load_characters():
			if str(c.get("id", "")) == cid:
				return CharacterCard.portrait_texture(c)
	return null
