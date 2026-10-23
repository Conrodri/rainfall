class_name RunSave
extends RefCounted
## Sauvegarde de run, un seul emplacement (docs/Design_Menus.md §6.1).
## Fichier : { "version": 2, "hash": sha256(data canonique), "saved_at": unix, "data": {...} }.
## Écriture atomique : `<chemin>.tmp` puis `DirAccess.rename_absolute`. Toutes les fonctions
## acceptent un chemin optionnel (tests : `user://test_...`) ; vide = `PATH`.
##
## `data` (construit par main.gd) : character, mode, seed, rng_state, map_id, run (RunState.to_dict()
## + pillars_done), stage (StageManager.to_dict()), player {pos, hp, cooldowns, statuses},
## pending_chest {kind, stage, price, quality, die, offered, shown, gold_rerolls, ad_rerolls} | null.
##
## Lecture invalide (version ou empreinte) : `load()` renvoie {ok=false, reason, rubies} où rubies =
## Balance.run_rubies(..., victory=false) de la run perdue ; ces rubis sont crédités au Profil et le
## fichier supprimé (une seule fois, quel que soit l'appelant). Le titre affiche le toast.

const PATH := "user://run_save.json"
const VERSION := 2
const CHARACTERS_JSON := "res://data/characters.json"


static func _p(path: String) -> String:
	return path if path != "" else PATH


static func exists(path := "") -> bool:
	return FileAccess.file_exists(_p(path))


## Texte canonique (clés triées, pleine précision) : base de l'empreinte, stable après relecture.
static func _canonical(data: Variant) -> String:
	return JSON.stringify(data, "", true, true)


## Écrit `data` (Dictionary sérialisable JSON). true si le fichier final est en place.
static func save(data: Dictionary, path := "") -> bool:
	var p := _p(path)
	var canon: Variant = JSON.parse_string(_canonical(data)) # normalise (StringName -> String, etc.)
	if not (canon is Dictionary):
		push_warning("RunSave : données non sérialisables")
		return false
	var doc := {
		"version": VERSION, "hash": _canonical(canon).sha256_text(),
		"saved_at": int(Time.get_unix_time_from_system()), "data": canon,
	}
	var tmp := p + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("RunSave : écriture impossible (%s)" % tmp)
		return false
	f.store_string(JSON.stringify(doc, "\t", true, true))
	f.flush()
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_p := ProjectSettings.globalize_path(p)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(abs_p) # rename_absolute n'écrase pas toujours sous Windows
	var err := DirAccess.rename_absolute(abs_tmp, abs_p)
	if err != OK:
		push_warning("RunSave : renommage impossible (%s)" % error_string(err))
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true


## Document brut validé : {ok, reason, data, saved_at} (sans effet de bord).
static func _read(path: String) -> Dictionary:
	var p := _p(path)
	if not FileAccess.file_exists(p):
		return {"ok": false, "reason": "missing"}
	var json := JSON.new() # parse() d'instance : pas d'erreur imprimée pour un fichier abîmé
	var doc: Variant = json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null
	if not (doc is Dictionary):
		return {"ok": false, "reason": "corrupt"}
	var data: Variant = doc.get("data")
	if int(doc.get("version", 0)) != VERSION:
		return {"ok": false, "reason": "version", "data": data if data is Dictionary else {}}
	if not (data is Dictionary) or str(doc.get("hash", "")) != _canonical(data).sha256_text():
		return {"ok": false, "reason": "corrupt", "data": data if data is Dictionary else {}}
	return {"ok": true, "reason": "", "data": data, "saved_at": int(doc.get("saved_at", 0))}


## Charge la sauvegarde. Succès : {ok=true, data, saved_at}. Échec : {ok=false, reason
## ("missing"|"version"|"corrupt"), rubies} ; si le fichier existait, il est converti en rubis
## (crédités au Profil) puis supprimé.
static func load(path := "") -> Dictionary:
	var r := _read(path)
	if r["ok"] or r["reason"] == "missing":
		if not r["ok"]:
			r["rubies"] = 0
		return r
	var rubies := salvage_rubies(r.get("data", {}))
	r["rubies"] = rubies
	r.erase("data")
	var prof := _profile()
	if prof != null and rubies > 0:
		prof.call(&"add_rubies", rubies)
	delete(path)
	return r


## Rubis d'une run perdue (version incompatible ou fichier altéré) : Balance.run_rubies sans victoire,
## à partir de ce qui reste lisible ; 0 si rien n'est lisible.
static func salvage_rubies(data: Variant) -> int:
	if not (data is Dictionary):
		return 0
	var run: Dictionary = data.get("run", {}) if data.get("run") is Dictionary else {}
	var mode := StringName(str(run.get("mode", data.get("mode", "moyen"))))
	if not Balance.RUBY_MODE_MULT.has(mode):
		mode = &"moyen"
	var minutes := maxf(float(run.get("active_time_s", 0.0)), 0.0) / 60.0
	var gold := maxf(float(run.get("gold", 0.0)), 0.0)
	return maxi(Balance.run_rubies(minutes, mode, maxi(int(run.get("pillars_done", 0)), 0), false, gold), 0)


## Résumé léger pour le titre : {character, character_name, mode, stage, active_time_s, map_id,
## saved_at} ; {} si absente ou invalide.
static func summary(path := "") -> Dictionary:
	var r := _read(path)
	if not r["ok"]:
		return {}
	var data: Dictionary = r["data"]
	var run: Dictionary = data.get("run", {}) if data.get("run") is Dictionary else {}
	var ch := str(data.get("character", run.get("character", "ardent")))
	return {
		"character": StringName(ch), "character_name": character_name(ch),
		"mode": StringName(str(data.get("mode", run.get("mode", "moyen")))),
		"stage": int(run.get("stage", 1)), "active_time_s": float(run.get("active_time_s", 0.0)),
		"map_id": str(data.get("map_id", "")), "saved_at": int(r.get("saved_at", 0)),
	}


static func delete(path := "") -> void:
	var p := _p(path)
	for f in [p, p + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## Nom affiché d'un personnage (data/characters.json, sinon l'id capitalisé).
static func character_name(id: String) -> String:
	if FileAccess.file_exists(CHARACTERS_JSON):
		var arr: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_JSON))
		if arr is Array:
			for c in arr:
				if c is Dictionary and str(c.get("id", "")) == id:
					return str(c.get("name", id.capitalize()))
	return id.capitalize()


## Nom affiché d'un mode.
static func mode_name(mode: StringName) -> String:
	return {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}.get(mode, String(mode).capitalize())


static func _profile() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"Profile") if tree != null else null
