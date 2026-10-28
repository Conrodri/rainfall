class_name PlatformServices
extends RefCounted
## Abstraction des services de jeu de la plateforme (Google Play Jeux, Game Center). Interface VIDE pour l'instant :
## aucun réseau, aucune permission Internet, aucune collecte. Pour brancher un service plus tard, créer une sous-classe
## (ex. PlayGamesServices) qui remplace ces méthodes et l'installer avec `PlatformServices.current = MaSousClasse.new()`
## au démarrage (App). MetaTracker appelle `report_achievement` à chaque déblocage et `submit_daily_score` à chaque
## défi du jour compté ; rien d'autre ne change côté jeu.

## Instance active (par défaut : l'interface vide).
static var current: PlatformServices = PlatformServices.new()


## Ce service est-il réellement branché ? Faux pour l'interface vide.
func is_available() -> bool:
	return false


## Un succès local vient d'être débloqué (id de data/achievements.json).
func report_achievement(_id: String) -> void:
	pass


## Résultat du défi du jour compté : clé AAAAMMJJ et résultat {victory, stage, kills, time_s, ...}.
func submit_daily_score(_key: int, _result: Dictionary) -> void:
	pass
