class_name DailyChallenge
extends RefCounted
## Défi du jour (hors ligne). Graine = date locale AAAAMMJJ : personnage imposé, plan de run (cartes, boss d'étage,
## mini-boss) identique pour tous ce jour-là, mode Moyen, sorts de base.
##
## Règles :
## - Une run est « du jour » si sa graine de run vaut `seed_for(clé)` pour aujourd'hui ou les 2 jours d'avant (une run
##   commencée avant minuit et finie après reste comptée pour son jour). Aucun champ de plus dans la sauvegarde de run.
## - Le premier essai terminé du jour est l'essai COMPTÉ : récompense en rubis (Balance.daily_rubies) et série.
##   Les suivants se rejouent sans compter ; le meilleur résultat du jour reste le meilleur de tous les essais.
## - Essai terminé = mort, victoire, ou abandon après Balance.DAILY_MIN_ABANDON_S de jeu actif.
## - Série = jours consécutifs avec au moins un essai compté ; un jour sauté la remet à 1.
## - Aucun réseau, aucun classement en ligne.
## État persistant : Profile.daily (voir profile.gd).

const MODE := &"moyen"

## Tests : date imposée {"year","month","day"} ; vide = date locale du système.
static var date_override := {}


static func today_key() -> int:
	var d: Dictionary = date_override if not date_override.is_empty() else Time.get_date_dict_from_system(false)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


## Clé du jour précédent (AAAAMMJJ), calendrier grégorien.
static func previous_key(key: int) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": key / 10000, "month": (key / 100) % 100, "day": key % 100,
		"hour": 12, "minute": 0, "second": 0})
	var d := Time.get_date_dict_from_unix_time(unix - 86400)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])


static func seed_for(key: int) -> int:
	var s := int((key * 1103515245 + 12345) % 2147483647)
	return s if s != 0 else 1


## Clé du jour dont `run_seed` est la graine (aujourd'hui, hier, avant-hier), 0 sinon.
static func key_of_seed(run_seed: int) -> int:
	if run_seed == 0:
		return 0
	var k := today_key()
	for _i in 3:
		if seed_for(k) == run_seed:
			return k
		k = previous_key(k)
	return 0


## Personnages candidats : jouables et non cachés (data/characters.json), dans l'ordre du fichier.
static func roster() -> Array:
	var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	var out: Array = []
	if parsed is Array:
		for c in parsed:
			if c is Dictionary and bool(c.get("playable", true)) and not bool(c.get("hidden", false)):
				out.append(c)
	return out


## Personnage imposé du jour : {id, name}.
static func character_for(key: int, chars: Array = []) -> Dictionary:
	var pool := chars if not chars.is_empty() else roster()
	if pool.is_empty():
		return {"id": "ardent", "name": "Ardent"}
	var c: Dictionary = pool[(seed_for(key) / 7) % pool.size()]
	return {"id": str(c.get("id", "ardent")), "name": str(c.get("name", c.get("id", "")))}


## Config de run (format App.start_run) du défi du jour.
static func config_for(key: int, chars: Array = []) -> Dictionary:
	var c := character_for(key, chars)
	return {"character": StringName(c["id"]), "mode": MODE, "spells": {}, "seed": seed_for(key), "daily": key,
		"label": "%s · Moyen" % c["name"]}


static func key_text(key: int) -> String:
	return "%02d/%02d/%04d" % [key % 100, (key / 100) % 100, key / 10000]


# --- État du profil -------------------------------------------------------------------------------

static func _state(profile: Object) -> Dictionary:
	var d: Variant = profile.get("daily")
	return d if d is Dictionary else {}


static func day_entry(profile: Object, key: int) -> Dictionary:
	var days: Variant = _state(profile).get("days", {})
	var e: Variant = (days as Dictionary).get(str(key), {}) if days is Dictionary else {}
	return e if e is Dictionary else {}


## Essais terminés aujourd'hui (0 = pas encore joué).
static func tries(profile: Object, key: int) -> int:
	return int(day_entry(profile, key).get("tries", 0))


static func is_counted(profile: Object, key: int) -> bool:
	return bool(day_entry(profile, key).get("counted", false))


static func best_of_day(profile: Object, key: int) -> Dictionary:
	var b: Variant = day_entry(profile, key).get("best", {})
	return b if b is Dictionary else {}


## Série en cours telle qu'affichée au titre : 0 si le dernier jour compté est avant hier.
static func current_streak(profile: Object, key: int) -> int:
	var st := _state(profile)
	var last := int(st.get("last_key", 0))
	if last == key or last == previous_key(key):
		return int(st.get("streak", 0))
	return 0


static func best_streak(profile: Object) -> int:
	return int(_state(profile).get("best_streak", 0))


## Vrai si `a` bat `b` : victoire > défaite ; entre victoires le temps le plus court ; sinon l'étage le plus haut, puis les kills.
static func better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return not a.is_empty()
	var av := bool(a.get("victory", false))
	var bv := bool(b.get("victory", false))
	if av != bv:
		return av
	if av:
		return float(a.get("time_s", INF)) < float(b.get("time_s", INF))
	if int(a.get("stage", 0)) != int(b.get("stage", 0)):
		return int(a.get("stage", 0)) > int(b.get("stage", 0))
	return int(a.get("kills", 0)) > int(b.get("kills", 0))


static func result_text(r: Dictionary) -> String:
	if r.is_empty():
		return ""
	var t := int(float(r.get("time_s", 0.0)))
	var head := "Victoire" if bool(r.get("victory", false)) else "Étage %d" % int(r.get("stage", 0))
	return "%s · %02d:%02d · %d monstres" % [head, t / 60, t % 60, int(r.get("kills", 0))]


## Enregistre la fin d'un essai du jour `key`. `r` = {victory, stage, kills, time_s, level, character, reason}.
## Retourne {counted, rubies, streak, new_best} ; counted = premier essai du jour (récompense versée une fois).
## Rien n'est écrit si l'abandon est trop court. Les rubis sont crédités ici (Profile.add_rubies).
static func record(profile: Object, key: int, r: Dictionary) -> Dictionary:
	var out := {"counted": false, "rubies": 0, "streak": current_streak(profile, key), "new_best": false, "ignored": false}
	if String(r.get("reason", "")) == "abandon" and float(r.get("time_s", 0.0)) < Balance.DAILY_MIN_ABANDON_S:
		out["ignored"] = true
		return out
	var st: Dictionary = _state(profile).duplicate(true)
	if st.is_empty():
		st = {"streak": 0, "best_streak": 0, "last_key": 0, "completed": 0, "wins": 0, "days": {}}
	var days: Dictionary = st["days"]
	var e: Dictionary = (days.get(str(key), {}) as Dictionary).duplicate(true) if days.get(str(key)) is Dictionary else {}
	var first := not bool(e.get("counted", false))
	e["tries"] = int(e.get("tries", 0)) + 1
	var cur: Dictionary = e.get("best", {}) if e.get("best") is Dictionary else {}
	var res := {"victory": bool(r.get("victory", false)), "stage": int(r.get("stage", 0)), "kills": int(r.get("kills", 0)),
		"time_s": float(r.get("time_s", 0.0)), "level": int(r.get("level", 0)), "character": str(r.get("character", ""))}
	if better(res, cur):
		e["best"] = res
		out["new_best"] = true
	if first:
		e["counted"] = true
		var last := int(st.get("last_key", 0))
		var streak := int(st.get("streak", 0))
		if last == key:
			pass # déjà compté ce jour (cas anormal)
		elif last == previous_key(key):
			streak += 1
		else:
			streak = 1
		st["streak"] = streak
		st["best_streak"] = maxi(int(st.get("best_streak", 0)), streak)
		st["last_key"] = key
		st["completed"] = int(st.get("completed", 0)) + 1
		if res["victory"]:
			st["wins"] = int(st.get("wins", 0)) + 1
		out["counted"] = true
		out["streak"] = streak
		out["rubies"] = Balance.daily_rubies(streak, bool(res["victory"]))
	days[str(key)] = e
	_prune(days, key)
	st["days"] = days
	if out["rubies"] > 0:
		profile.call(&"add_rubies", int(out["rubies"]))
	profile.call(&"set_daily", st)
	return out


## Garde les 40 derniers jours (le profil ne grossit pas).
static func _prune(days: Dictionary, key: int) -> void:
	if days.size() <= 40:
		return
	var keys: Array = days.keys()
	keys.sort()
	while days.size() > 40 and not keys.is_empty():
		var k: String = keys.pop_front()
		if int(k) != key:
			days.erase(k)
