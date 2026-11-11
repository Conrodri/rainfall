class_name PlatformServices
extends RefCounted
## Abstraction des services de jeu de la plateforme (Steam sur PC ; Google Play Jeux, Game Center plus tard). Cette
## classe est l'interface VIDE (repli) : aucun réseau, aucune permission Internet, aucune collecte. Un backend est une
## sous-classe qui remplace ces méthodes ; `install(host)` (appelé une fois par App au démarrage) choisit le backend de
## la plateforme et le pose dans `PlatformServices.current`, sinon l'interface vide reste en place.
## Backends : SteamServices (scripts/meta/steam/, PC avec l'extension GodotSteam et le client Steam lancé ;
## docs/Integration_Steam.md). MetaTracker appelle `report_achievement` à chaque déblocage et `submit_daily_score` à
## chaque défi du jour compté ; rien d'autre ne change côté jeu.

## Instance active (par défaut : l'interface vide).
static var current: PlatformServices = PlatformServices.new()


## Choisit et installe le backend de la plateforme. `host` : nœud permanent (App). Sans service disponible (extension
## absente, Steam fermé, mobile, headless), ne fait rien : `current` reste l'interface vide, sans erreur.
static func install(host: Node, profile: Object) -> void:
	if current.is_available():
		return
	SteamServices.try_install(host, profile)


## Ce service est-il réellement branché ? Faux pour l'interface vide.
func is_available() -> bool:
	return false


## Un succès local vient d'être débloqué (id de data/achievements.json).
func report_achievement(_id: String) -> void:
	pass


## Résultat du défi du jour compté : clé AAAAMMJJ et résultat {victory, stage, kills, time_s, ...}.
func submit_daily_score(_key: int, _result: Dictionary) -> void:
	pass
