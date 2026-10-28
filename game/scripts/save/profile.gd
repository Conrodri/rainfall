extends Node
## Autoload `Profile` : méta-progression persistante (docs/Design_Menus.md §6.2).
## Fichier `user://profile.json` : rubis, modes / personnages / sorts débloqués, dernier choix,
## stats. Chargé dans _ready ; jamais écrit en headless (sauf `write_enabled` forcé par un test
## avec un `path` de test). Écriture atomique (`.tmp` puis renommage), immédiate à chaque changement.
##
## Clés de déblocage (`is_unlocked`) : "mode:<id>", "character:<id>", "spell:<id>", "item:<id>", "skin:<id>".
## Variantes de sorts (game/CONTRACTS.md « Variantes de sorts ») : `loadout` mémorise par personnage le sort choisi
## par emplacement ; `unlock_rule` des variantes (characters.json) évaluées en fin de run par VariantUnlocks ;
## compteurs génériques `stats[<clé>]` via `add_stat(key, n)`.

signal changed

const PATH := "user://profile.json"
## Version 2 (26/10) : + unlocked_skins, selected_skin, best_runs. Un fichier v1 se charge tel quel (champs absents = défauts).
## Version 3 (28/10) : + achievements, daily, boss_kills, tutorial_replay (méta hors ligne, scripts/meta/). Un fichier v1/v2 se
## charge tel quel : les champs absents prennent leur défaut, rien n'est perdu.
const VERSION := 3
const DEFAULT_MODES: Array = [&"facile", &"moyen"]
const DEFAULT_CHARACTERS: Array = [&"ardent"]
## Mode débloqué par une victoire dans un mode donné.
const UNLOCK_ON_VICTORY := {&"moyen": &"difficile"}
## Objectifs cumulés sur toutes les runs : clé du résultat de run -> [seuil, clé débloquée].
## Rictus (caché) : 200 monstres tués à moins de 2 u de soi (Player.close_kills).
const UNLOCK_ON_OBJECTIVE := {"close_kills": [200.0, &"character:rictus"]}
const VariantUnlocks := preload("res://scripts/save/variant_unlocks.gd")
## TEMPORAIRE (à retirer avant la sortie) : toutes les variantes de sorts débloquées, sans rien écrire au profil.
## Variable d'environnement `RAINFALL_UNLOCK_ALL_VARIANTS=1` ou argument utilisateur `-- --unlock-variants`.
const UNLOCK_ALL_VARIANTS_ENV := "RAINFALL_UNLOCK_ALL_VARIANTS"
const UNLOCK_ALL_VARIANTS_ARG := "--unlock-variants"

var path := PATH
var write_enabled := DisplayServer.get_name() != "headless"

var rubies := 0:
	set(v):
		rubies = maxi(v, 0)
		_touch()
var unlocked_modes: Array = DEFAULT_MODES.duplicate() ## StringName
var unlocked_characters: Array = DEFAULT_CHARACTERS.duplicate() ## StringName
var unlocked_spells: Array = [] ## StringName (ids de variantes de sorts)
var unlocked_items: Array = [] ## StringName (ids d'objets à débloquer, ItemUnlocks)
var unlocked_skins: Array = [] ## StringName (ids de skins, Skins)
var last_mode: StringName = &"moyen":
	set(v):
		last_mode = StringName(v)
		_touch()
var last_character: StringName = &"ardent":
	set(v):
		last_character = StringName(v)
		_touch()
## runs, victories, kills, play_time_s, best_time_s {mode: s} (temps de la run victorieuse la plus courte)
var stats := _default_stats()
var objectives := {} ## id -> progression (float)
## Mémoire des boss (docs/Design_Etages.md §2.2, §6.2) : étage (clé texte "1".."5") -> id du boss d'étage vu à cet
## étage lors de la run la plus récente. Au tirage du plan (FloorPlan), ce boss pèse × Balance.BOSS_MEMORY_WEIGHT.
var last_floor_boss := {}
## Invites d'onboarding déjà montrées (docs/ux/Audit_Menus.md §3.1, lot M-A) : ids texte (OnboardingHints.SEQUENCE).
var seen_hints: Array = []
## Sorts choisis par personnage (fiche Nouvelle run) : id perso (texte) -> {"<slot>": "<id du sort>"} (base ou variante).
var loadout := {}
## Skin équipé par personnage : id perso (texte) -> id du skin ("" ou absent = apparence par défaut).
var selected_skin := {}
## Meilleure run (victoire la plus courte) par personnage et par mode :
## id perso -> mode -> {time_s, date (ISO, locale), level, kills, items {id: stacks}, variants {slot: id}, stage}.
var best_runs := {}
## Succès locaux (data/achievements.json) : id -> date ISO du déblocage (scripts/meta/achievements.gd).
var achievements := {}
## Boss d'étage tués au total : id du boss -> nombre (succès « tuer chaque boss »).
var boss_kills := {}
## Défi du jour (scripts/meta/daily_challenge.gd) : {streak, best_streak, last_key (AAAAMMJJ du dernier jour compté),
## completed (jours comptés au total), wins, days: {"AAAAMMJJ": {tries, counted, best: {...}}}}. {} = jamais joué.
var daily := {}
## « Revoir le didacticiel » : vrai = les invites de 1re run reviennent à la prochaine run (OnboardingHints).
var tutorial_replay := false
## TEMPORAIRE (test) : vrai = toutes les variantes passent pour débloquées (lu une fois au démarrage, injectable).
var unlock_all_variants := _detect_unlock_all_variants()
## Roster lu par le moteur de déblocage des variantes (null = data/characters.json ; tests : liste injectée).
var characters_override: Variant = null

var _loading := false
## Mode test (TestMode) : bac à sable. Pas d'écriture sur disque ; l'état d'avant est rendu à la sortie.
var sandbox := false
var _sandbox_snapshot: Dictionary = {}


func _ready() -> void:
	load_profile()
	Events.boss_spawned.connect(_on_boss_spawned)


func _default_stats() -> Dictionary:
	return {"runs": 0, "victories": 0, "kills": 0, "play_time_s": 0.0, "best_time_s": {}}


## Remet les valeurs par défaut (sans écrire).
func reset() -> void:
	_loading = true
	rubies = 0
	unlocked_modes = DEFAULT_MODES.duplicate()
	unlocked_characters = DEFAULT_CHARACTERS.duplicate()
	unlocked_spells = []
	unlocked_items = []
	unlocked_skins = []
	selected_skin = {}
	best_runs = {}
	last_mode = &"moyen"
	last_character = &"ardent"
	stats = _default_stats()
	objectives = {}
	last_floor_boss = {}
	seen_hints = []
	loadout = {}
	achievements = {}
	boss_kills = {}
	daily = {}
	tutorial_replay = false
	_loading = false


## Relit le profil depuis `path` (absent ou illisible : valeurs par défaut).
func load_profile() -> void:
	reset()
	if not FileAccess.file_exists(path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		push_warning("Profil illisible (%s) : valeurs par défaut" % path)
		return
	_apply_dict(d)


## Applique un profil lu (disque ou instantané du bac à sable) sur l'état courant (déjà remis à zéro).
func _apply_dict(d: Dictionary) -> void:
	_loading = true
	rubies = int(d.get("rubies", 0))
	unlocked_modes = _names(d.get("unlocked_modes", []), DEFAULT_MODES)
	unlocked_characters = _names(d.get("unlocked_characters", []), DEFAULT_CHARACTERS)
	unlocked_spells = _names(d.get("unlocked_spells", []), [])
	unlocked_items = _names(d.get("unlocked_items", []), [])
	unlocked_skins = _names(d.get("unlocked_skins", []), [])
	last_mode = StringName(str(d.get("last_mode", "moyen")))
	last_character = StringName(str(d.get("last_character", "ardent")))
	var s: Variant = d.get("stats", {})
	if s is Dictionary:
		for k in stats:
			if s.has(k):
				stats[k] = s[k]
		stats["runs"] = int(stats["runs"])
		stats["victories"] = int(stats["victories"])
		stats["kills"] = int(stats["kills"])
		stats["play_time_s"] = float(stats["play_time_s"])
		if not (stats["best_time_s"] is Dictionary):
			stats["best_time_s"] = {}
		for k in s: # compteurs génériques (add_stat) : toute clé numérique inconnue est gardée
			if not stats.has(k) and (s[k] is float or s[k] is int):
				stats[str(k)] = float(s[k])
	var o: Variant = d.get("objectives", {})
	objectives = o if o is Dictionary else {}
	var lb: Variant = d.get("last_floor_boss", {})
	last_floor_boss = {}
	if lb is Dictionary:
		for k in lb:
			last_floor_boss[str(k)] = str(lb[k])
	var sh: Variant = d.get("seen_hints", [])
	seen_hints = []
	if sh is Array:
		for v in sh:
			if not seen_hints.has(str(v)):
				seen_hints.append(str(v))
	var lo: Variant = d.get("loadout", {})
	loadout = {}
	if lo is Dictionary:
		for cid in lo:
			if lo[cid] is Dictionary:
				var m := {}
				for slot in lo[cid]:
					m[str(int(str(slot)))] = str(lo[cid][slot])
				loadout[str(cid)] = m
	var sk: Variant = d.get("selected_skin", {})
	selected_skin = {}
	if sk is Dictionary:
		for cid in sk:
			selected_skin[str(cid)] = str(sk[cid])
	best_runs = _clean_best_runs(d.get("best_runs", {}))
	achievements = {}
	var ac: Variant = d.get("achievements", {})
	if ac is Dictionary:
		for k in ac:
			achievements[str(k)] = str(ac[k])
	boss_kills = {}
	var bk: Variant = d.get("boss_kills", {})
	if bk is Dictionary:
		for k in bk:
			if bk[k] is float or bk[k] is int:
				boss_kills[str(k)] = int(bk[k])
	daily = _clean_daily(d.get("daily", {}))
	tutorial_replay = bool(d.get("tutorial_replay", false))
	_loading = false
	changed.emit()


## Normalise `daily` lu du disque (types sûrs ; illisible = {}).
static func _clean_daily(src: Variant) -> Dictionary:
	if not (src is Dictionary) or (src as Dictionary).is_empty():
		return {}
	var out := {
		"streak": int(src.get("streak", 0)), "best_streak": int(src.get("best_streak", 0)),
		"last_key": int(src.get("last_key", 0)), "completed": int(src.get("completed", 0)), "wins": int(src.get("wins", 0)),
		"days": {},
	}
	var days: Variant = src.get("days", {})
	if days is Dictionary:
		for k in days:
			var e: Variant = days[k]
			if not (e is Dictionary):
				continue
			var best := {}
			if e.get("best") is Dictionary:
				var b: Dictionary = e["best"]
				best = {"victory": bool(b.get("victory", false)), "stage": int(b.get("stage", 0)), "kills": int(b.get("kills", 0)),
					"time_s": float(b.get("time_s", 0.0)), "level": int(b.get("level", 0)), "character": str(b.get("character", ""))}
			out["days"][str(k)] = {"tries": int(e.get("tries", 0)), "counted": bool(e.get("counted", false)), "best": best}
	return out


## Normalise `best_runs` lu du disque (types sûrs, entrées illisibles ignorées).
static func _clean_best_runs(src: Variant) -> Dictionary:
	var out := {}
	if not (src is Dictionary):
		return out
	for cid in src:
		if not (src[cid] is Dictionary):
			continue
		var per := {}
		for mode in src[cid]:
			var r: Variant = src[cid][mode]
			if not (r is Dictionary) or not (r.get("time_s") is float or r.get("time_s") is int):
				continue
			var items := {}
			if r.get("items") is Dictionary:
				for iid in r["items"]:
					items[str(iid)] = int(r["items"][iid])
			var variants := {}
			if r.get("variants") is Dictionary:
				for slot in r["variants"]:
					variants[str(int(str(slot)))] = str(r["variants"][slot])
			per[str(mode)] = {
				"time_s": float(r["time_s"]), "date": str(r.get("date", "")), "level": int(r.get("level", 0)),
				"kills": int(r.get("kills", 0)), "items": items, "variants": variants, "stage": int(r.get("stage", 0)),
			}
		if not per.is_empty():
			out[str(cid)] = per
	return out


func _names(src: Variant, defaults: Array) -> Array:
	var out: Array = defaults.duplicate()
	if src is Array:
		for v in src:
			var n := StringName(str(v))
			if not out.has(n):
				out.append(n)
	return out


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "rubies": rubies,
		"unlocked_modes": unlocked_modes.map(func(v): return String(v)),
		"unlocked_characters": unlocked_characters.map(func(v): return String(v)),
		"unlocked_spells": unlocked_spells.map(func(v): return String(v)),
		"unlocked_items": unlocked_items.map(func(v): return String(v)),
		"unlocked_skins": unlocked_skins.map(func(v): return String(v)),
		"last_mode": String(last_mode), "last_character": String(last_character),
		"stats": stats, "objectives": objectives, "last_floor_boss": last_floor_boss,
		"seen_hints": seen_hints, "loadout": loadout, "selected_skin": selected_skin, "best_runs": best_runs,
		"achievements": achievements, "boss_kills": boss_kills, "daily": daily, "tutorial_replay": tutorial_replay,
	}


## Écriture atomique immédiate. false si désactivée (headless) ou en échec.
func save() -> bool:
	if not write_enabled or sandbox:
		return false
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Profil : écriture impossible (%s)" % tmp)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.flush()
	f.close()
	var abs_p := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_p)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_p) == OK


## Mode test : fige l'écriture et garde un instantané. Tout ce qui change ensuite (stats, objectifs, mémoire des boss,
## déblocages) reste en mémoire seulement et disparaît à end_sandbox().
func begin_sandbox() -> void:
	if sandbox:
		return
	_sandbox_snapshot = (JSON.parse_string(JSON.stringify(to_dict())) as Dictionary) # copie profonde, types JSON
	sandbox = true


## Rend le profil d'avant begin_sandbox() (rien n'a été écrit sur disque entre-temps).
func end_sandbox() -> void:
	if not sandbox:
		return
	sandbox = false
	reset()
	_apply_dict(_sandbox_snapshot)
	_sandbox_snapshot = {}


func _touch() -> void:
	if _loading:
		return
	save()
	changed.emit()


# --- Déblocages ---------------------------------------------------------------

## "mode:<id>" | "character:<id>" | "spell:<id>" (un id seul = personnage).
func is_unlocked(key: StringName) -> bool:
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := StringName(s.substr(i + 1) if i >= 0 else s)
	match kind:
		"mode":
			return unlocked_modes.has(id)
		"character":
			return unlocked_characters.has(id)
		"spell":
			return unlock_all_variants or unlocked_spells.has(id)
		"item":
			return unlock_all_variants or unlocked_items.has(id)
		"skin":
			return unlock_all_variants or unlocked_skins.has(id)
	return false


## Débloque une clé ; true si c'est nouveau.
func unlock(key: StringName) -> bool:
	var s := String(key)
	var i := s.find(":")
	var kind := s.substr(0, i) if i >= 0 else "character"
	var id := StringName(s.substr(i + 1) if i >= 0 else s)
	# Possession réelle (le mode test « toutes les variantes » n'empêche pas d'enregistrer un vrai déblocage).
	var owned_real := (kind == "spell" and unlocked_spells.has(id)) or (kind == "item" and unlocked_items.has(id)) \
		or (kind == "skin" and unlocked_skins.has(id))
	if owned_real or (kind != "spell" and kind != "item" and kind != "skin" and is_unlocked(key)):
		return false
	match kind:
		"mode":
			unlocked_modes.append(id)
		"character":
			unlocked_characters.append(id)
		"spell":
			unlocked_spells.append(id)
		"item":
			unlocked_items.append(id)
		"skin":
			unlocked_skins.append(id)
		_:
			return false
	_touch()
	return true


func is_mode_unlocked(mode: StringName) -> bool:
	return unlocked_modes.has(StringName(mode))


func is_character_unlocked(id: StringName) -> bool:
	return unlocked_characters.has(StringName(id))


## Personnages déjà jouables sans le profil (`"unlocked": true` dans data/characters.json, ex. ouverts pour les
## tests). Lu une fois ; un test peut injecter une liste (ex. [] pour simuler la configuration de sortie).
var open_characters: Variant = null


## Vrai si le personnage est déjà jouable (profil OU characters.json) : son déblocage n'est alors pas « nouveau ».
func is_character_available(id: StringName) -> bool:
	if is_character_unlocked(id):
		return true
	if open_characters == null:
		var arr: Array = []
		var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Array:
			for c in parsed:
				if c is Dictionary and bool(c.get("unlocked", false)):
					arr.append(StringName(str(c.get("id", ""))))
		open_characters = arr
	return (open_characters as Array).has(StringName(id))


func add_rubies(n: int) -> void:
	if n != 0:
		rubies += n


func objective_progress(id: StringName) -> float:
	return float(objectives.get(String(id), 0.0))


func set_objective_progress(id: StringName, value: float) -> void:
	objectives[String(id)] = value
	_touch()


## Résultat d'une run terminée : {victory, mode, character, active_time_s, kills, rubies}.
## Crédite les rubis, met à jour les stats, applique les déblocages ; une seule écriture.
## Retourne les déblocages obtenus (ex. [&"mode:difficile"]).
func add_run_result(r: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var mode := StringName(str(r.get("mode", "moyen")))
	var victory := bool(r.get("victory", false))
	var t := float(r.get("active_time_s", 0.0))
	_loading = true
	rubies += int(r.get("rubies", 0))
	stats["runs"] = int(stats["runs"]) + 1
	stats["kills"] = int(stats["kills"]) + int(r.get("kills", 0))
	stats["play_time_s"] = float(stats["play_time_s"]) + t
	if victory:
		stats["victories"] = int(stats["victories"]) + 1
		var best: Dictionary = stats["best_time_s"]
		var k := String(mode)
		if not best.has(k) or t < float(best[k]):
			best[k] = t
		_record_best_run(r, mode, t)
		if UNLOCK_ON_VICTORY.has(mode):
			var key := StringName("mode:" + String(UNLOCK_ON_VICTORY[mode]))
			if not is_unlocked(key):
				unlocked_modes.append(UNLOCK_ON_VICTORY[mode])
				out.append(key)
	for obj: String in UNLOCK_ON_OBJECTIVE:
		if not r.has(obj):
			continue
		var v := float(objectives.get(obj, 0.0)) + float(r[obj])
		objectives[obj] = v
		var rule: Array = UNLOCK_ON_OBJECTIVE[obj]
		var ukey := StringName(rule[1])
		if v >= float(rule[0]) and not is_unlocked(ukey):
			# Annoncé seulement si c'est nouveau pour le joueur (pas un perso déjà ouvert par characters.json).
			var us := String(ukey)
			var known := us.begins_with("character:") and is_character_available(StringName(us.substr(10)))
			unlock(ukey)
			if not known:
				out.append(ukey)
	# Compteurs génériques de la run (RunState.counters -> clé "counters") : cumulés dans stats[<clé>].
	var cn: Variant = r.get("counters", {})
	if cn is Dictionary:
		for ck in cn:
			add_stat(str(ck), float(cn[ck]))
	# Variantes de sorts : règles `unlock_rule` de characters.json (VariantUnlocks).
	for vkey: StringName in VariantUnlocks.evaluate(self, _roster(), r):
		if not unlocked_spells.has(StringName(String(vkey).substr(6))):
			unlocked_spells.append(StringName(String(vkey).substr(6)))
			out.append(vkey)
	# Skins : règle `unlock_rule` de characters.json (type victory), après les compteurs.
	for skey: StringName in Skins.evaluate(self, _roster(), r):
		var sid := StringName(String(skey).substr(5))
		if not unlocked_skins.has(sid):
			unlocked_skins.append(sid)
			out.append(skey)
	# Objets débloquables : règles `unlock` de items.json (ItemUnlocks), après les compteurs ci-dessus.
	for ikey: StringName in ItemUnlocks.evaluate(self, r):
		var iid := StringName(String(ikey).substr(5))
		if not unlocked_items.has(iid):
			unlocked_items.append(iid)
			out.append(ikey)
	_loading = false
	_touch()
	return out


## Meilleure run (victoire la plus courte) du personnage dans ce mode ; {} si aucune victoire.
func best_run(cid: StringName, mode: StringName) -> Dictionary:
	var per: Variant = best_runs.get(String(cid), {})
	var r: Variant = (per as Dictionary).get(String(mode), {}) if per is Dictionary else {}
	return r if r is Dictionary else {}


## Enregistre la victoire `r` si elle bat le record du personnage dans ce mode (temps strictement plus court).
## Le temps est celui de l'abattage du boss final (`boss_time_s`) s'il est connu, sinon le temps actif de la run.
func _record_best_run(r: Dictionary, mode: StringName, run_time_s: float) -> void:
	var cid := str(r.get("character", ""))
	if cid == "":
		return
	var bt := float(r.get("boss_time_s", 0.0))
	var t := bt if bt > 0.0 else run_time_s
	var old := best_run(StringName(cid), mode)
	if not old.is_empty() and t >= float(old.get("time_s", INF)):
		return
	var items := {}
	var src: Variant = r.get("items", {})
	if src is Dictionary:
		for iid in src:
			items[str(iid)] = int(src[iid])
	var rec := {
		"time_s": t, "date": Time.get_datetime_string_from_system(false, true), "level": int(r.get("level", 0)),
		"kills": int(r.get("kills", 0)), "items": items, "variants": _variants_used(StringName(cid), r.get("loadout", {})),
		"stage": int(r.get("stage", 0)),
	}
	if not best_runs.has(cid) or not (best_runs[cid] is Dictionary):
		best_runs[cid] = {}
	best_runs[cid][String(mode)] = rec


## Variantes de sorts réellement utilisées : {slot: id} pour chaque emplacement du loadout dont le sort n'est pas le sort de base.
func _variants_used(cid: StringName, lo: Variant) -> Dictionary:
	var out := {}
	if not (lo is Dictionary):
		return out
	var spells: Array = []
	for c in _roster():
		if c is Dictionary and str(c.get("id", "")) == String(cid):
			spells = c.get("spells", []) if c.get("spells") is Array else []
			break
	for k in lo:
		var slot := int(str(k))
		var id := str(lo[k])
		if id == "" or slot < 1:
			continue
		var base := str((spells[slot - 1] as Dictionary).get("id", "")) if slot <= spells.size() and spells[slot - 1] is Dictionary else ""
		if id != base:
			out[str(slot)] = id
	return out


func _skin_id_of(cid: StringName) -> String:
	for c in _roster():
		if c is Dictionary and str(c.get("id", "")) == String(cid):
			return str(Skins.skin_of_dict(c).get("id", ""))
	return ""


## Équipe un skin (id valide et débloqué) ou "" pour l'apparence par défaut. true si appliqué.
func set_selected_skin(cid: StringName, skin_id: String) -> bool:
	if skin_id != "":
		if _skin_id_of(cid) != skin_id or not is_unlocked(StringName("skin:" + skin_id)):
			return false
	if str(selected_skin.get(String(cid), "")) == skin_id:
		return true
	if skin_id == "":
		selected_skin.erase(String(cid))
	else:
		selected_skin[String(cid)] = skin_id
	_touch()
	return true


# --- Compteurs et variantes de sorts ------------------------------------------------------

## Ajoute `n` au compteur générique `stats[key]` (créé à 0). Écrit le profil (sauf pendant add_run_result).
func add_stat(key: String, n: float = 1.0) -> void:
	if key == "" or n == 0.0:
		return
	if key in ["runs", "victories", "kills"]:
		stats[key] = int(stats.get(key, 0)) + int(n)
	elif stats.get(key) is Dictionary:
		push_warning("Profile.add_stat : clé réservée « %s »" % key)
		return
	else:
		stats[key] = float(stats.get(key, 0.0)) + n
	_touch()


## Valeur d'un compteur générique (0 si absent).
func stat(key: String) -> float:
	var v: Variant = stats.get(key, 0.0)
	return float(v) if (v is float or v is int) else 0.0


## Sorts mémorisés pour un personnage : {slot (int) -> id du sort (StringName)} ; {} si rien.
func get_loadout(cid: StringName) -> Dictionary:
	var out := {}
	var m: Variant = loadout.get(String(cid), {})
	if m is Dictionary:
		for k in m:
			out[int(str(k))] = StringName(str(m[k]))
	return out


## Mémorise les sorts choisis {slot -> id} d'un personnage (écrit seulement si ça change).
func set_loadout(cid: StringName, spells: Dictionary) -> void:
	if String(cid) == "":
		return
	var m := {}
	for k in spells:
		var id := str(spells[k])
		if id != "":
			m[str(int(str(k)))] = id
	if loadout.get(String(cid), {}) == m:
		return
	loadout[String(cid)] = m
	_touch()


func _roster() -> Array:
	if characters_override is Array:
		return characters_override
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	return parsed if parsed is Array else []


static func _detect_unlock_all_variants() -> bool:
	var e := OS.get_environment(UNLOCK_ALL_VARIANTS_ENV)
	if e != "" and e != "0" and e.to_lower() != "false":
		return true
	return OS.get_cmdline_user_args().has(UNLOCK_ALL_VARIANTS_ARG)


# --- Mémoire des boss -----------------------------------------------------------------

## Boss d'étage vu à l'étage `floor_n` lors de la run la plus récente (&"" si aucun).
func last_boss_of_floor(floor_n: int) -> StringName:
	return StringName(str(last_floor_boss.get(str(floor_n), "")))


## Poids du boss `id` au tirage de l'étage `floor_n` : Balance.BOSS_MEMORY_WEIGHT s'il y a été vu la dernière fois.
func floor_boss_weight(floor_n: int, id: StringName) -> float:
	return Balance.BOSS_MEMORY_WEIGHT if id != &"" and last_boss_of_floor(floor_n) == id else 1.0


## Note le boss d'étage vu à l'étage `floor_n` (écrit seulement s'il change).
func record_floor_boss(floor_n: int, id: StringName) -> void:
	if floor_n <= 0 or id == &"" or last_boss_of_floor(floor_n) == id:
		return
	last_floor_boss[str(floor_n)] = String(id)
	_touch()


## Apparition d'un boss d'étage : mémorisé pour l'étage de la boucle courante (FloorPlan.floor_of_stage).
func _on_boss_spawned(boss: Node2D, is_floor_boss: bool) -> void:
	if not is_floor_boss or boss == null or not boss.has_method(&"boss_id"):
		return
	record_floor_boss(FloorPlan.floor_of_stage(int(RunState.stage)), boss.boss_id())


# --- Onboarding (lot M-A) ------------------------------------------------------

func has_seen_hint(id: String) -> bool:
	return seen_hints.has(id)


## Note une invite comme vue (écrit le profil). Sans effet si déjà vue.
func mark_hint_seen(id: String) -> void:
	if id == "" or seen_hints.has(id):
		return
	seen_hints.append(id)
	_touch()


# --- Méta hors ligne : succès, boss tués, défi du jour, didacticiel ----------------------

func is_achievement_unlocked(id: String) -> bool:
	return achievements.has(id)


## Débloque un succès (date locale ISO). true si c'est nouveau. Rien n'est écrit en mode test (bac à sable).
func unlock_achievement(id: String) -> bool:
	if id == "" or achievements.has(id):
		return false
	achievements[id] = Time.get_datetime_string_from_system(false, true)
	_touch()
	return true


## Un boss d'étage de plus tué (id = Enemy.boss_id()).
func add_boss_kill(boss_id: String) -> void:
	if boss_id == "":
		return
	boss_kills[boss_id] = int(boss_kills.get(boss_id, 0)) + 1
	_touch()


## Remplace l'état du défi du jour (DailyChallenge) et écrit.
func set_daily(d: Dictionary) -> void:
	daily = d
	_touch()


## « Revoir le didacticiel » : oublie les invites vues et les relance à la prochaine run, même après la 1re.
func request_tutorial_replay() -> void:
	seen_hints = []
	tutorial_replay = true
	_touch()


## Consommé quand la run du didacticiel est lancée.
func clear_tutorial_replay() -> void:
	if tutorial_replay:
		tutorial_replay = false
		_touch()
