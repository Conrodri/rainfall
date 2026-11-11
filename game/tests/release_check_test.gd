extends Node
## Contrôle de sortie (docs/Checklist_Sortie.md, « Vérification automatique proposée »). Il ne modifie rien : il lit les
## vraies sources (data/characters.json, profile.gd, export_presets.cfg, project.godot, autoloads, sources .gd) et liste
## chaque point non prêt pour la sortie, avec le numéro de contrôle de la checklist.
##
## Deux modes :
##   (défaut)   informatif : liste les écarts et finit par `RESULT: OK` (ne casse pas la suite pendant le développement) ;
##   `-- --strict` : `RESULT: FAIL (n)` s'il reste n écarts, `RESULT: OK` seulement si zéro.
## godot --headless --path game res://tests/release_check_test.tscn [-- --strict]
##
## Chaque écart = une ligne `GAP [n°] source : valeur actuelle -> attendue`. Fin : `RELEASE: <n> écarts` + détail par contrôle.

const STRICT_ARG := "--strict"
## Contrôle 1 : id -> [unlocked attendu, hidden attendu] à la sortie (11 personnages de data/characters.json au 11/11/2026 ;
## la liste codée ici attrape l'ajout accidentel d'un personnage de test).
const EXPECTED_CHARACTERS := {
	&"ardent": [true, false], &"tocsin": [true, false],
	&"rictus": [false, true], &"rainette": [false, true], &"avare": [false, true],
	&"averse": [false, false], &"arpenteuse": [false, false], &"bourbe": [false, false],
	&"vigie": [false, false], &"morfil": [false, false], &"gresille": [false, false],
}
## Contrôle 2 : règles de déblocage validées (06/11 et 09/11/2026) : clé -> [seuil, personnage, table].
const EXPECTED_RULES := {
	"close_kills": [200.0, &"rictus", "UNLOCK_ON_OBJECTIVE"],
	"zone_kills": [300.0, &"arpenteuse", "UNLOCK_ON_OBJECTIVE"],
	"familiar_elite_kills": [3.0, &"bourbe", "UNLOCK_ON_OBJECTIVE"],
	"lightning_kills": [100.0, &"gresille", "UNLOCK_ON_OBJECTIVE"],
	"water_s": [60.0, &"averse", "UNLOCK_ON_RUN"],
	"far_kills": [100.0, &"vigie", "UNLOCK_ON_RUN"],
	"clean_floors": [1.0, &"rainette", "UNLOCK_ON_RUN"],
	"light_boss_kills": [1.0, &"morfil", "UNLOCK_ON_RUN"],
	"purse_over": [1.0, &"avare", "UNLOCK_ON_RUN"],
}
const EXPECTED_AVARE_PURSE_P := 4.0
## Contrôle 8 : version/code Android de la dernière release publiée (le code du build de sortie doit la dépasser).
const LAST_RELEASE_ANDROID_CODE := 3
## Contrôle 10 : motifs d'argent réel. « rewarded » seul est trop large (variable `rewarded` du bouclier de boss) :
## on cherche les formes publicitaires (rewarded_ad, rewarded_video, rewardedad, rewarded_interstitial).
const MONEY_PATTERN := "(?i)\\b(admob|iap|in_app)\\b|rewarded_?(ad|video|interstitial)"
const PRESET_NAMES := ["Windows Desktop", "Android", "iOS"] ## presets de sortie ; le preset Web n'est pas concerné

var _strict := false
var _gaps: Array = [] ## {n: int, text: String}
var _scripts_cache: Dictionary = {} ## chemin -> texte (lu une fois)


func _ready() -> void:
	_strict = OS.get_cmdline_user_args().has(STRICT_ARG)
	await get_tree().process_frame # autoloads prêts
	_check_characters()
	_check_unlock_rules()
	_check_variants_switch()
	_check_test_mode()
	_check_vfx_test()
	_check_run_log()
	_check_ios_quit()
	_check_versions()
	_check_flags()
	_check_no_real_money()
	_check_tips()
	_check_steam_app_id()
	_report()


func _gap(n: int, text: String) -> void:
	_gaps.append({"n": n, "text": text})


# --- 1. Personnages -----------------------------------------------------------------------------

func _check_characters() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	if not (data is Array):
		_gap(1, "data/characters.json : illisible -> tableau de personnages")
		return
	var seen: Array[StringName] = []
	for c in data as Array:
		var id := StringName(String(c.get("id", "")))
		seen.append(id)
		if not EXPECTED_CHARACTERS.has(id):
			_gap(1, "data/characters.json : personnage inattendu « %s » -> absent de la liste de sortie" % id)
			continue
		var want: Array = EXPECTED_CHARACTERS[id]
		var unlocked := bool(c.get("unlocked", false))
		var hidden := bool(c.get("hidden", false))
		if unlocked != want[0]:
			_gap(1, "data/characters.json : %s unlocked %s -> %s" % [id, unlocked, want[0]])
		if hidden != want[1]:
			_gap(1, "data/characters.json : %s hidden %s -> %s" % [id, hidden, want[1]])
	for id: StringName in EXPECTED_CHARACTERS:
		if not seen.has(id):
			_gap(1, "data/characters.json : personnage « %s » absent -> présent" % id)


# --- 2. Règles de déblocage ---------------------------------------------------------------------

func _check_unlock_rules() -> void:
	var tables := {"UNLOCK_ON_OBJECTIVE": Profile.UNLOCK_ON_OBJECTIVE, "UNLOCK_ON_RUN": Profile.UNLOCK_ON_RUN}
	for key: String in EXPECTED_RULES:
		var want: Array = EXPECTED_RULES[key]
		var table: Dictionary = tables[want[2]]
		if not table.has(key):
			_gap(2, "profile.gd %s : clé « %s » absente -> [%s, character:%s]" % [want[2], key, want[0], want[1]])
			continue
		var rule: Array = table[key]
		var seuil := float(rule[0])
		var target := String(rule[1])
		if not is_equal_approx(seuil, float(want[0])):
			_gap(2, "profile.gd %s[%s] : seuil %s -> %s" % [want[2], key, seuil, want[0]])
		if target != "character:%s" % want[1]:
			_gap(2, "profile.gd %s[%s] : cible %s -> character:%s" % [want[2], key, target, want[1]])
	if not is_equal_approx(Profile.AVARE_PURSE_P, EXPECTED_AVARE_PURSE_P):
		_gap(2, "profile.gd AVARE_PURSE_P : %s -> %s" % [Profile.AVARE_PURSE_P, EXPECTED_AVARE_PURSE_P])


# --- 3. Interrupteur de variantes ---------------------------------------------------------------

func _check_variants_switch() -> void:
	# Le profil lit l'environnement à sa construction : on le recrée avec la variable posée, puis on la retire.
	OS.set_environment(Profile.UNLOCK_ALL_VARIANTS_ENV, "1")
	var forced: bool = Profile._detect_unlock_all_variants()
	OS.unset_environment(Profile.UNLOCK_ALL_VARIANTS_ENV)
	if forced:
		_gap(3, "profile.gd unlock_all_variants : RAINFALL_UNLOCK_ALL_VARIANTS=1 l'active -> toujours faux")
	if Profile.unlock_all_variants:
		_gap(3, "Profile.unlock_all_variants : vrai dans ce lancement -> faux")
	var hits := _grep_scripts("UNLOCK_ALL_VARIANTS|--unlock-variants")
	if not hits.is_empty():
		_gap(3, "scripts : %d occurrence(s) de UNLOCK_ALL_VARIANTS / --unlock-variants (%s) -> 0" % [hits.size(), _first(hits)])


# --- 4. Mode test -------------------------------------------------------------------------------

func _check_test_mode() -> void:
	var autoload: Variant = ProjectSettings.get_setting("autoload/TestMode", "")
	if String(autoload) != "":
		_gap(4, "project.godot [autoload] TestMode : présent (%s) -> absent ou masqué" % autoload)
	if TestMode.requested_by_arg():
		_gap(4, "TestMode.requested_by_arg() : vrai dans ce lancement -> faux")
	if FileAccess.file_exists("res://data/maps/test_arena.json"):
		_gap(4, "data/maps/test_arena.json : présent -> absent (carte test_only)")
	var maps := 0
	var dir := DirAccess.open("res://data/maps")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json") and FileAccess.get_file_as_string("res://data/maps/" + f).contains("\"test_only\": true"):
				maps += 1
	if maps > 0:
		_gap(4, "data/maps : %d carte(s) test_only -> 0 dans la version vendue" % maps)
	var title := FileAccess.get_file_as_string("res://scripts/menu/title_screen.gd")
	if title.contains("TestMode.enter") or title.contains("Mode test"):
		_gap(4, "scripts/menu/title_screen.gd : bouton « Mode test » présent -> masqué")


# --- 5. VFX de test -----------------------------------------------------------------------------

func _check_vfx_test() -> void:
	if not DirAccess.dir_exists_absolute("res://assets/sprites/vfx_test"):
		return
	if _strict:
		_gap(5, "assets/sprites/vfx_test/ : présent -> absent (mode strict)")
		return
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		_gap(5, "export_presets.cfg : illisible -> lisible")
		return
	for sec in cfg.get_sections():
		if not sec.begins_with("preset.") or sec.ends_with(".options"):
			continue
		var pname := String(cfg.get_value(sec, "name", ""))
		if not PRESET_NAMES.has(pname):
			continue
		if not String(cfg.get_value(sec, "exclude_filter", "")).contains("assets/sprites/vfx_test/"):
			_gap(5, "export_presets.cfg [%s] : exclude_filter sans vfx_test -> assets/sprites/vfx_test/*" % pname)


# --- 6. Journal ---------------------------------------------------------------------------------

func _check_run_log() -> void:
	if not RunLog.TEST_BUILD:
		_gap(6, "RunLog.TEST_BUILD : faux -> vrai (journal actif par défaut, décision du 06/11)")
	var panel := FileAccess.get_file_as_string("res://scripts/ui/settings_panel.gd")
	if not (panel.contains("_advanced_button") and panel.contains("\"Avancé\"")):
		_gap(6, "scripts/ui/settings_panel.gd : rangée « Avancé » introuvable -> export des journaux dans « Avancé »")


# --- 7. iOS -------------------------------------------------------------------------------------

func _check_ios_quit() -> void:
	var platform := FileAccess.get_file_as_string("res://scripts/core/platform.gd")
	if not platform.contains("func can_quit() -> bool:\n\treturn not is_ios()"):
		_gap(7, "scripts/core/platform.gd can_quit() : n'exclut plus iOS -> `return not is_ios()`")
	for path in ["res://scripts/menu/title_screen.gd", "res://scripts/ui/pause_menu.gd"]:
		if not FileAccess.get_file_as_string(path).contains("Platform.can_quit()"):
			_gap(7, "%s : bouton Quitter sans garde Platform.can_quit() -> gardé" % path.trim_prefix("res://"))


# --- 8. Versions --------------------------------------------------------------------------------

func _check_versions() -> void:
	var project := String(ProjectSettings.get_setting("application/config/version", ""))
	if project == "":
		_gap(8, "project.godot config/version : vide -> renseignée")
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		_gap(8, "export_presets.cfg : illisible -> lisible")
		return
	for sec in cfg.get_sections():
		if not sec.begins_with("preset.") or not sec.ends_with(".options"):
			continue
		var base := sec.trim_suffix(".options")
		var pname := String(cfg.get_value(base, "name", ""))
		var ver := ""
		match pname:
			"Android":
				ver = String(cfg.get_value(sec, "version/name", ""))
				var code := int(cfg.get_value(sec, "version/code", 0))
				if code <= LAST_RELEASE_ANDROID_CODE:
					_gap(8, "export_presets.cfg [Android] version/code : %d -> > %d (dernière release)" % [code, LAST_RELEASE_ANDROID_CODE])
			"iOS":
				ver = String(cfg.get_value(sec, "application/short_version", ""))
			"Windows Desktop":
				ver = String(cfg.get_value(sec, "application/product_version", cfg.get_value(sec, "application/file_version", project)))
			_:
				continue
		if ver == "":
			_gap(8, "export_presets.cfg [%s] : version vide -> %s" % [pname, project])
		elif ver != project:
			_gap(8, "export_presets.cfg [%s] : version %s -> %s (config/version)" % [pname, ver, project])


# --- 9. Drapeaux --------------------------------------------------------------------------------

func _check_flags() -> void:
	if not Balance.EPREUVES_ENABLED:
		_gap(9, "Balance.EPREUVES_ENABLED : faux -> vrai")
	var prints: Array = []
	for path in _script_paths("res://scripts/core"):
		var n := 0
		for line in _text(path).split("\n"):
			var t := line.strip_edges()
			if t.begins_with("print(") or t.begins_with("print_debug(") or (t.begins_with("push_warning(") and t.to_lower().contains("debug")):
				n += 1
		if n > 0:
			prints.append("%s ×%d" % [path.trim_prefix("res://"), n])
	if not prints.is_empty():
		_gap(9, "scripts/core : print / push_warning de debug (%s) -> aucun" % ", ".join(prints))


# --- 10. Pas d'argent réel ----------------------------------------------------------------------

func _check_no_real_money() -> void:
	var hits := _grep_scripts(MONEY_PATTERN)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var re := RegEx.create_from_string(MONEY_PATTERN)
	if re.search(presets) != null:
		hits.append("export_presets.cfg")
	if not hits.is_empty():
		_gap(10, "%d occurrence(s) publicité / achat intégré (%s) -> 0" % [hits.size(), _first(hits)])


# --- 11. Conseils -------------------------------------------------------------------------------

func _check_tips() -> void:
	var tips: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tips.json"))
	if not (tips is Array) or (tips as Array).is_empty():
		_gap(11, "data/tips.json : pas un tableau non vide -> tableau de chaînes")
		return
	var seen := {}
	for t in tips as Array:
		if not (t is String) or String(t).strip_edges() == "":
			_gap(11, "data/tips.json : entrée vide ou non textuelle -> chaîne non vide")
		elif seen.has(t):
			_gap(11, "data/tips.json : doublon « %s » -> unique" % String(t).left(40))
		seen[t] = true


# --- 31. AppID Steam ----------------------------------------------------------------------------

## RELEASE_APP_ID = 0 tant que l'AppID Steam n'est pas attribué (contrôle 31). Compté en mode strict seulement.
func _check_steam_app_id() -> void:
	if not _strict:
		return
	var text := FileAccess.get_file_as_string("res://scripts/meta/steam/steam_services.gd")
	var re := RegEx.create_from_string("(?m)^const RELEASE_APP_ID\\s*(?::=|=)\\s*(\\d+)")
	var m := re.search(text)
	if m == null:
		_gap(31, "scripts/meta/steam/steam_services.gd RELEASE_APP_ID : constante introuvable -> AppID Steam de release")
	elif int(m.get_string(1)) == 0:
		_gap(31, "scripts/meta/steam/steam_services.gd RELEASE_APP_ID : 0 -> AppID Steam de release (≠ 0)")


# --- Outils -------------------------------------------------------------------------------------

func _script_paths(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for d in dir.get_directories():
		out.append_array(_script_paths(root.path_join(d)))
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root.path_join(f))
	return out


func _text(path: String) -> String:
	if not _scripts_cache.has(path):
		_scripts_cache[path] = FileAccess.get_file_as_string(path)
	return _scripts_cache[path]


## Chemins de res://scripts dont une ligne (hors commentaires pleine ligne) correspond au motif regex.
func _grep_scripts(pattern: String) -> Array:
	var re := RegEx.create_from_string(pattern)
	var out: Array = []
	for path in _script_paths("res://scripts"):
		for line in _text(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			if re.search(line) != null:
				out.append(path.trim_prefix("res://"))
				break
	return out


func _first(hits: Array) -> String:
	return String(hits[0]) + (" ..." if hits.size() > 1 else "")


# --- Bilan --------------------------------------------------------------------------------------

func _report() -> void:
	var per := {}
	for g in _gaps:
		per[g["n"]] = int(per.get(g["n"], 0)) + 1
		print("GAP [%d] %s" % [g["n"], g["text"]])
	var keys := per.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("#%d : %d" % [k, per[k]])
	print("RELEASE: %d écarts (%s)" % [_gaps.size(), ", ".join(parts) if not parts.is_empty() else "aucun"])
	if _strict and not _gaps.is_empty():
		print("RESULT: FAIL (%d)" % _gaps.size())
		get_tree().quit(1)
		return
	if not _strict and not _gaps.is_empty():
		print("(informatif : relancer avec `-- --strict` pour échouer sur les écarts)")
	print("RESULT: OK")
	get_tree().quit(0)
