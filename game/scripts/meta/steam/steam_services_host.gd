class_name SteamServicesHost
extends Node
## Nœud permanent (enfant d'App) du backend Steam : envoie le profil au cloud quand il a changé (au plus une fois
## toutes les PUSH_INTERVAL_S secondes, et à chaque fin de run), puis ferme Steam proprement à la sortie du jeu.
## Aucun travail par image : un Timer à intervalle fixe, arrêté tant que rien n'a changé.

const PUSH_INTERVAL_S := 20.0

var services: SteamServices
var _dirty := false
var _timer: Timer
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_timer = Timer.new()
	_timer.wait_time = PUSH_INTERVAL_S
	_timer.one_shot = true
	_timer.timeout.connect(_flush)
	add_child(_timer)
	var prof: Object = services._profile if services != null else null
	if prof != null and prof.has_signal(&"changed"):
		prof.connect(&"changed", _on_profile_changed)
	Events.run_finished.connect(_on_run_finished)


func _on_profile_changed() -> void:
	_dirty = true
	if _timer.is_stopped():
		_timer.start()


func _on_run_finished(_victory: bool, _reason: StringName) -> void:
	# Profil écrit juste après l'événement (Main.end_run) et par MetaTracker en différé : envoi deux images plus tard.
	_dirty = true
	_flush_soon.call_deferred()


func _flush_soon() -> void:
	await get_tree().process_frame
	_flush()


func _flush() -> void:
	if not _dirty or services == null or services.cloud == null:
		return
	_dirty = false
	services.cloud.push()


func _notification(what: int) -> void:
	# Demande de fermeture : on envoie le profil tout de suite (la fermeture peut encore être annulée ailleurs, Steam
	# n'est arrêté qu'à la sortie de l'arbre).
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_dirty = true
		_flush()


func _exit_tree() -> void:
	_close()


func _close() -> void:
	if _closed or services == null:
		return
	_closed = true
	services.shutdown()
