class_name SteamServices
extends PlatformServices
## Backend Steam des services de plateforme (succès Steam + sauvegarde du profil dans Steam Cloud), via l'extension
## GodotSteam (GDExtension). Procédure d'installation et configuration Steamworks : docs/Integration_Steam.md.
##
## Repli : sans Steam (extension absente, client Steam fermé, Android, iOS, headless), `try_install` ne crée rien et
## `PlatformServices.current` reste l'interface vide ; le jeu marche exactement comme avant, sans erreur.
##
## Ce fichier est le SEUL endroit qui parle à Steam. Il n'écrit jamais l'identifiant global de la classe Steam (le script
## doit se charger même sans l'extension) : le singleton est obtenu par `Engine.get_singleton(SINGLETON)` et chaque
## appel passe par `_call(méthode, args)`, qui vérifie `has_method` (tolère une version de GodotSteam sans la méthode).
## Les tests injectent un faux singleton (tests/steam_fake.gd) par `create_with`.
##
## Succès : l'API name Steam = id local de data/achievements.json en majuscules (docs/Fiche_Steam.md §9).
## `report_achievement` appelle setAchievement puis storeStats ; à l'installation, rattrapage de tous les succès locaux
## déjà débloqués (setAchievement est idempotent). Un setAchievement refusé (statistiques pas encore reçues sur une
## ancienne version du SDK) reste en attente et est retenté au prochain envoi.

const SINGLETON := "Steam"
## AppID de test Valve (Spacewar), utilisé seulement en build de debug (éditeur, export debug).
const DEBUG_APP_ID := 480
## AppID réel de Rainfall, à renseigner après réservation sur Steamworks (docs/Integration_Steam.md §4).
## 0 = laisser le client Steam fournir l'AppID au lancement (jeu lancé depuis Steam).
const RELEASE_APP_ID := 0
## Variable d'environnement qui remplace l'AppID (tests sur un autre AppID, debug ou release).
const APP_ID_ENV := "RAINFALL_STEAM_APPID"
## Argument utilisateur qui coupe Steam (`-- --no-steam`) : repli forcé, pour comparer avec / sans Steam.
const NO_STEAM_ARG := "--no-steam"
## steamInitEx : statut k_ESteamAPIInitResult_OK.
const INIT_OK := 0

var _api: Object = null
var _profile: Object = null
var _pending: Array = [] ## API names en attente (setAchievement refusé)
var cloud: SteamCloudSync = null
var host: SteamServicesHost = null
var app_id := 0
var reported: Array = [] ## API names envoyés avec succès pendant la session (diagnostic, tests)


## Installe le backend Steam si tout est réuni, sinon ne fait rien (repli). Renvoie le backend installé ou null.
## `host` : nœud permanent (App) qui portera le minuteur d'envoi au cloud et la fermeture propre de Steam.
static func try_install(host_node: Node, profile: Object) -> SteamServices:
	if not _platform_allows():
		return null
	var api: Object = singleton()
	if api == null:
		return null
	var svc := create_with(api, profile, resolve_app_id())
	if svc == null:
		return null
	svc.attach(host_node)
	PlatformServices.current = svc
	if OS.is_debug_build(): # repère pour le protocole de vérification (docs/Integration_Steam.md §8)
		print("Steam : connecté (AppID %d), cloud : %s, succès envoyés : %d" % [svc.app_id, svc.cloud.last_result, svc.reported.size()])
	return svc


## Singleton GodotSteam, ou null si l'extension n'est pas chargée (aucune erreur dans ce cas).
static func singleton() -> Object:
	if not Engine.has_singleton(SINGLETON):
		return null
	return Engine.get_singleton(SINGLETON)


## Steam n'est tenté que sur PC (Windows, Linux, macOS), hors headless, sans `--no-steam`.
static func _platform_allows() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not OS.get_cmdline_user_args().has(NO_STEAM_ARG)


## AppID passé à steamInitEx : variable d'environnement > 480 en debug > RELEASE_APP_ID en release.
static func resolve_app_id() -> int:
	var env := OS.get_environment(APP_ID_ENV)
	if env.is_valid_int() and int(env) > 0:
		return int(env)
	return DEBUG_APP_ID if OS.is_debug_build() else RELEASE_APP_ID


## API name Steam d'un succès local : id en majuscules (docs/Fiche_Steam.md §9). "" si l'id est vide.
static func api_name(local_id: String) -> String:
	return local_id.strip_edges().to_upper()


## Crée le backend sur un singleton donné (vrai Steam ou faux des tests) et initialise Steam.
## null si l'initialisation échoue (client Steam fermé, AppID refusé…) : on reste alors sur le repli.
static func create_with(api: Object, profile: Object, wanted_app_id := 0) -> SteamServices:
	if api == null or not _init_steam(api, wanted_app_id):
		return null
	var svc := SteamServices.new()
	svc._api = api
	svc._profile = profile
	svc.app_id = wanted_app_id
	svc.cloud = SteamCloudSync.new(api, profile)
	# Ancienne API (SDK < 1.61) : les statistiques doivent être demandées avant setAchievement.
	if api.has_method(&"requestCurrentStats"):
		api.call(&"requestCurrentStats")
	if api.has_signal(&"current_stats_received"):
		api.connect(&"current_stats_received", svc._on_stats_received)
	svc.cloud.sync_at_start()
	svc.catch_up()
	return svc


## steamInitEx(app_id, embed_callbacks = true) : les callbacks sont pompés par l'extension elle-même, aucun
## run_callbacks à appeler. Si Steam a déjà été initialisé (réglage « initialize_on_startup » de GodotSteam), on le garde.
static func _init_steam(api: Object, wanted_app_id: int) -> bool:
	if api.has_method(&"get_steam_init_result"):
		var prev: Variant = api.call(&"get_steam_init_result")
		if prev is Dictionary and int((prev as Dictionary).get("status", -1)) == INIT_OK:
			return true
	if api.has_method(&"steamInitEx"):
		var r: Variant = api.call(&"steamInitEx", wanted_app_id, true)
		return r is Dictionary and int((r as Dictionary).get("status", -1)) == INIT_OK
	if api.has_method(&"steamInit"):
		var ok: Variant = api.call(&"steamInit", wanted_app_id, true)
		return ok is bool and ok
	return false


## Accroche le nœud hôte (minuteur d'envoi au cloud, fermeture) sous `host_node`.
func attach(host_node: Node) -> void:
	if host_node == null or host != null:
		return
	host = SteamServicesHost.new()
	host.name = "SteamServicesHost"
	host.services = self
	host_node.add_child(host)


func is_available() -> bool:
	return _api != null


## Un succès local vient d'être débloqué : setAchievement(API name) puis storeStats.
func report_achievement(id: String) -> void:
	var n := api_name(id)
	if n == "" or _api == null:
		return
	if not _pending.has(n):
		_pending.append(n)
	_flush_achievements()


## Pas de classement Steam pour l'instant : le défi du jour reste local.
func submit_daily_score(_key: int, _result: Dictionary) -> void:
	pass


## Rattrapage : envoie tous les succès locaux déjà débloqués (profil local, éventuellement venu du cloud).
func catch_up() -> void:
	if _api == null or _profile == null:
		return
	var ach: Variant = _profile.get(&"achievements")
	if not (ach is Dictionary):
		return
	for id in (ach as Dictionary).keys():
		var n := api_name(str(id))
		if n != "" and not _pending.has(n):
			_pending.append(n)
	_flush_achievements()


## Succès en attente de confirmation par Steam (diagnostic, tests).
func pending() -> Array:
	return _pending.duplicate()


func _flush_achievements() -> void:
	if _pending.is_empty():
		return
	var sent := 0
	var still: Array = []
	for n in _pending:
		if bool(_call(&"setAchievement", [n], false)):
			sent += 1
			if not reported.has(n):
				reported.append(n)
		else:
			still.append(n)
	_pending = still
	if sent > 0:
		_call(&"storeStats", [], false)


func _on_stats_received(_a = null, _b = null, _c = null) -> void:
	_flush_achievements()


## Appel protégé : la méthode absente (version de GodotSteam différente) renvoie `fallback` sans erreur.
func _call(method: StringName, args: Array, fallback: Variant) -> Variant:
	if _api == null or not _api.has_method(method):
		return fallback
	return _api.callv(method, args)


## Fin de session : dernier envoi du profil au cloud puis arrêt de Steam (appelé par l'hôte en sortie d'arbre).
func shutdown() -> void:
	if _api == null:
		return
	if cloud != null:
		cloud.push()
	_flush_achievements()
	_call(&"steamShutdown", [], null)
	if _api.has_signal(&"current_stats_received") and _api.is_connected(&"current_stats_received", _on_stats_received):
		_api.disconnect(&"current_stats_received", _on_stats_received)
	_api = null
	cloud = null
	if PlatformServices.current == self:
		PlatformServices.current = PlatformServices.new()
