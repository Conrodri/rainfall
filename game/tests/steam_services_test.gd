extends Node
## Backend Steam des services de plateforme (scripts/meta/steam/, docs/Integration_Steam.md) :
## - repli sans l'extension GodotSteam : aucun singleton, interface vide, aucun appel, succès locaux inchangés ;
## - traduction id local -> API name Steam (majuscules) et concordance avec la table de docs/Fiche_Steam.md §9 ;
## - faux singleton injecté : initialisation, rattrapage, setAchievement + storeStats, attente puis reprise ;
## - Steam Cloud (Remote Storage) : envoi, identique, rapatriement du plus récent, copie de l'ancien, fichiers corrompus,
##   bac à sable ; fermeture propre (steamShutdown, retour à l'interface vide).
## godot --headless --path game res://tests/steam_services_test.tscn
## Le profil de test vit dans user://test_steam_profile.json (le vrai profil n'est ni lu ni écrit).

const SteamFake := preload("res://tests/steam_fake.gd")
const TEST_PROFILE := "user://test_steam_profile.json"
const TEST_BACKUPS := "user://test_steam_backups"

var _fails := 0
var _saved_path := ""
var _saved_write := false


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_saved_path = Profile.path
	_saved_write = Profile.write_enabled
	Profile.write_enabled = false
	Profile.reset()
	RunState.running = false
	TestMode.active = false
	PlatformServices.current = PlatformServices.new()

	_test_fallback()
	_test_api_names()
	await _test_fake_achievements()
	_test_cloud()
	await _test_host_shutdown()

	_cleanup()
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


# --- Repli sans extension -------------------------------------------------------------------

func _test_fallback() -> void:
	Profile.unlock_achievement("first_blood")
	var before: Dictionary = Profile.achievements.duplicate()
	_check(not Engine.has_singleton(SteamServices.SINGLETON), "sans extension : aucun singleton Steam")
	_check(SteamServices.singleton() == null, "singleton() = null sans erreur")
	_check(not SteamServices._platform_allows(), "headless : Steam jamais tenté")
	var host := Node.new()
	add_child(host)
	PlatformServices.install(host, Profile)
	_check(not PlatformServices.current.is_available(), "install : interface vide gardée")
	_check(not (PlatformServices.current is SteamServices), "install : aucun backend Steam")
	_check(host.get_child_count() == 0, "install : aucun nœud hôte créé")
	_check(SteamServices.try_install(host, Profile) == null, "try_install : null (repli)")
	PlatformServices.current.report_achievement("floor_1") # interface vide : sans effet
	PlatformServices.current.submit_daily_score(20261111, {})
	_check(Profile.achievements == before, "succès locaux inchangés par le repli")
	_check(SteamServices.create_with(null, Profile) == null, "create_with(null) : null")
	host.queue_free()
	Profile.reset()


# --- id local -> API name -------------------------------------------------------------------

func _test_api_names() -> void:
	_check(SteamServices.api_name("first_blood") == "FIRST_BLOOD", "api_name first_blood -> FIRST_BLOOD")
	_check(SteamServices.api_name("kills_10000") == "KILLS_10000", "api_name kills_10000 -> KILLS_10000")
	_check(SteamServices.api_name(" boss_floor_4 ") == "BOSS_FLOOR_4", "api_name rogne les espaces")
	_check(SteamServices.api_name("") == "", "api_name vide -> vide")
	var re := RegEx.create_from_string("^[A-Z0-9_]+$")
	var ids: Array = []
	var bad: Array = []
	for a in Achievements.all():
		var id := str(a["id"])
		ids.append(id)
		if re.search(SteamServices.api_name(id)) == null:
			bad.append(id)
	_check(ids.size() >= 30, "achievements.json : %d succès" % ids.size())
	_check(bad.is_empty(), "API names valides Steamworks [A-Z0-9_] (%s)" % ", ".join(bad))
	# Table de la fiche Steam : chaque ligne « | API | id | ... » doit valoir id.to_upper(), et couvrir tous les ids.
	var fiche := ProjectSettings.globalize_path("res://").path_join("../docs/Fiche_Steam.md")
	if not FileAccess.file_exists(fiche):
		print("info : docs/Fiche_Steam.md absent, concordance de la table non vérifiée")
		return
	var table := {}
	for line in FileAccess.get_file_as_string(fiche).split("\n"):
		var cols := line.split("|")
		if cols.size() >= 7:
			var api := cols[1].strip_edges()
			var lid := cols[2].strip_edges()
			if re.search(api) != null and lid == lid.to_lower() and lid != "":
				table[lid] = api
	var mismatch: Array = []
	for id in ids:
		if not table.has(id) or table[id] != SteamServices.api_name(id):
			mismatch.append(id)
	_check(mismatch.is_empty(), "Fiche_Steam §9 : %d lignes, concordance id -> API name (%s)" % [table.size(), ", ".join(mismatch)])


# --- Faux singleton : succès ----------------------------------------------------------------

func _test_fake_achievements() -> void:
	# Échec d'initialisation (client Steam fermé) : aucun backend, aucun setAchievement.
	var off = SteamFake.new()
	off.init_status = 2
	_check(SteamServices.create_with(off, Profile, 480) == null, "steamInitEx en échec : pas de backend")
	_check(off.count("setAchievement") == 0 and off.count("fileWrite") == 0, "échec : aucun appel de succès ni de cloud")

	# Initialisation réussie : rattrapage des succès locaux déjà débloqués.
	Profile.reset()
	Profile.unlock_achievement("first_blood")
	Profile.unlock_achievement("floor_1")
	var fake = SteamFake.new()
	fake.cloud_account = false # cloud coupé ici (testé plus bas)
	var svc := SteamServices.create_with(fake, Profile, 480)
	_check(svc != null and svc.is_available(), "steamInitEx OK : backend disponible")
	if svc == null:
		return
	_check(fake.calls[0] == ["steamInitEx", 480, true], "steamInitEx(480, embed_callbacks = true)")
	_check(fake.achieved.has("FIRST_BLOOD") and fake.achieved.has("FLOOR_1"), "rattrapage : FIRST_BLOOD et FLOOR_1 envoyés")
	_check(fake.count("storeStats") == 1, "rattrapage : un seul storeStats")
	_check(svc.cloud.last_result == "off", "cloud coupé pour le compte : rien d'envoyé")
	_check(fake.count("fileWrite") == 0, "cloud coupé : aucun fileWrite")

	# Déblocage en jeu par MetaTracker : succès local -> setAchievement(API name) + storeStats.
	PlatformServices.current = svc
	var tracker := MetaTracker.new()
	add_child(tracker)
	await _frames(1)
	var stores := fake.count("storeStats")
	Events.floor_cleared.emit(2)
	await _frames(2)
	_check(Profile.is_achievement_unlocked("floor_2"), "MetaTracker : floor_2 débloqué localement")
	_check(fake.achieved.has("FLOOR_2"), "MetaTracker -> setAchievement(\"FLOOR_2\")")
	_check(fake.count("storeStats") > stores, "MetaTracker -> storeStats")
	tracker.queue_free()

	# Refus (statistiques pas encore reçues) : en attente, renvoyé à current_stats_received.
	fake.set_ok = false
	svc.report_achievement("win_run")
	_check(svc.pending() == ["WIN_RUN"], "setAchievement refusé : WIN_RUN en attente")
	fake.set_ok = true
	fake.current_stats_received.emit(480, 1, 0)
	_check(svc.pending().is_empty() and fake.achieved.has("WIN_RUN"), "current_stats_received : attente vidée")
	svc.report_achievement("")
	_check(fake.count("setAchievement") == fake.achieved.size() + 1, "id vide ignoré (seul le refus compte en plus)")
	svc.shutdown()
	_check(not PlatformServices.current.is_available(), "shutdown : retour à l'interface vide")
	Profile.reset()


# --- Steam Cloud ----------------------------------------------------------------------------

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _backups(origin: String) -> Array:
	var out: Array = []
	if DirAccess.dir_exists_absolute(TEST_BACKUPS):
		for f in DirAccess.get_files_at(TEST_BACKUPS):
			if f.contains("_" + origin):
				out.append(TEST_BACKUPS.path_join(f))
	return out


func _clear_backups() -> void:
	if DirAccess.dir_exists_absolute(TEST_BACKUPS):
		for f in DirAccess.get_files_at(TEST_BACKUPS):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BACKUPS.path_join(f)))


func _test_cloud() -> void:
	Profile.path = TEST_PROFILE
	Profile.write_enabled = true
	Profile.reset()
	_clear_backups()
	if FileAccess.file_exists(TEST_PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	var fake = SteamFake.new()
	var cloud := SteamCloudSync.new(fake, Profile)
	cloud.backup_dir = TEST_BACKUPS

	# Cloud coupé pour le jeu : rien.
	fake.cloud_app = false
	_check(not cloud.available() and cloud.sync_at_start() == "off", "cloud coupé pour le jeu : off")
	fake.cloud_app = true

	# Ni local ni distant : rien.
	_check(cloud.sync_at_start() == "empty", "aucun profil : empty")

	# Local seul : envoyé.
	Profile.rubies = 12 # _touch -> save() sur le profil de test
	var local_text := FileAccess.get_file_as_string(TEST_PROFILE)
	_check(local_text.contains("\"rubies\": 12"), "profil de test écrit (rubis 12)")
	_check(cloud.sync_at_start() == "pushed" and fake.text_of(SteamCloudSync.REMOTE_FILE) == local_text, "local seul : envoyé au cloud")
	_check(cloud.sync_at_start() == "same", "contenus identiques : same")
	_check(not cloud.push(), "push sans changement : rien")

	# Distant plus récent et différent : rapatrié, ancien local copié.
	var remote := local_text.replace("\"rubies\": 12", "\"rubies\": 77")
	fake.put(SteamCloudSync.REMOTE_FILE, remote, int(Time.get_unix_time_from_system()) + 3600)
	var changed := [0]
	var cb := func() -> void: changed[0] += 1
	Profile.changed.connect(cb)
	_check(cloud.sync_at_start() == "pulled", "distant plus récent : pulled")
	Profile.changed.disconnect(cb)
	_check(FileAccess.get_file_as_string(TEST_PROFILE) == remote, "profil local = version du cloud")
	_check(Profile.rubies == 77, "profil rechargé (rubis 77)")
	_check(changed[0] >= 1, "Profile.changed émis après le rapatriement")
	var lb := _backups("local")
	_check(lb.size() == 1 and FileAccess.get_file_as_string(lb[0]) == local_text, "ancien profil local copié (backup local)")

	# Local plus récent : envoyé, ancien distant copié.
	Profile.rubies = 90
	var newer := FileAccess.get_file_as_string(TEST_PROFILE)
	var stale := newer.replace("\"rubies\": 90", "\"rubies\": 5")
	fake.put(SteamCloudSync.REMOTE_FILE, stale, 1000)
	_check(cloud.sync_at_start() == "pushed" and fake.text_of(SteamCloudSync.REMOTE_FILE) == newer, "local plus récent : envoyé")
	var cbk := _backups("cloud")
	_check(cbk.size() == 1 and FileAccess.get_file_as_string(cbk[0]) == stale, "ancien profil du cloud copié (backup cloud)")

	# Distant corrompu : le local gagne, la copie corrompue est gardée.
	fake.put(SteamCloudSync.REMOTE_FILE, "{{ pas du json", int(Time.get_unix_time_from_system()) + 3600)
	_check(cloud.sync_at_start() == "pushed" and fake.text_of(SteamCloudSync.REMOTE_FILE) == newer, "distant corrompu : local envoyé")
	_check(_backups("cloud").size() == 2, "distant corrompu copié")

	# Local corrompu : le distant gagne.
	_write(TEST_PROFILE, "corrompu")
	_check(cloud.sync_at_start() == "pulled" and Profile.rubies == 90, "local corrompu : version du cloud rapatriée")

	# En cours de partie : push seulement si le fichier a changé ; jamais en bac à sable.
	Profile.rubies = 91
	_check(cloud.push(), "push après sauvegarde modifiée : envoyé")
	_check(fake.text_of(SteamCloudSync.REMOTE_FILE).contains("\"rubies\": 91"), "cloud à jour (rubis 91)")
	Profile.begin_sandbox()
	Profile.rubies = 500
	_check(not cloud.available() and not cloud.push(), "bac à sable (mode test) : aucun envoi")
	Profile.end_sandbox()
	Profile.write_enabled = false
	_check(not cloud.available(), "écriture du profil coupée (headless) : cloud indisponible")
	Profile.write_enabled = true

	# Plafond des copies.
	for i in SteamCloudSync.BACKUP_KEEP + 3:
		cloud.backup("{}", "local")
	_check(DirAccess.get_files_at(TEST_BACKUPS).size() == SteamCloudSync.BACKUP_KEEP, "copies plafonnées à %d" % SteamCloudSync.BACKUP_KEEP)

	# Backend complet : rattrapage + cloud au démarrage.
	var fake2 = SteamFake.new()
	var svc := SteamServices.create_with(fake2, Profile, 480)
	_check(svc != null and svc.cloud.last_result == "pushed" and fake2.count("fileWrite") == 1, "backend : profil envoyé au démarrage")
	if svc != null:
		svc.shutdown()
	Profile.write_enabled = false
	Profile.path = _saved_path
	Profile.reset()


# --- Hôte : fermeture propre ----------------------------------------------------------------

func _test_host_shutdown() -> void:
	var fake = SteamFake.new()
	fake.cloud_account = false
	var svc := SteamServices.create_with(fake, Profile, 480)
	PlatformServices.current = svc
	var host := Node.new()
	add_child(host)
	svc.attach(host)
	await _frames(1)
	_check(host.get_node_or_null("SteamServicesHost") != null, "hôte attaché sous App")
	host.queue_free()
	await _frames(1)
	_check(fake.count("steamShutdown") == 1, "sortie de l'arbre : steamShutdown appelé une fois")
	_check(not svc.is_available() and not PlatformServices.current.is_available(), "après fermeture : interface vide")
	svc.report_achievement("win_run")
	_check(fake.count("setAchievement") == 0, "après fermeture : plus aucun appel")


func _cleanup() -> void:
	_clear_backups()
	if DirAccess.dir_exists_absolute(TEST_BACKUPS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BACKUPS))
	for p in [TEST_PROFILE, TEST_PROFILE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	Profile.path = _saved_path
	Profile.write_enabled = _saved_write
	Profile.reset()
	PlatformServices.current = PlatformServices.new()
