class_name ExitTeleporter
extends Area2D
## Téléporteur de sortie, actif une fois l'étage terminé. Utilisation : `interact()` (maintien de 0,6 s géré
## par le HUD) joueur dessus, jamais au contact : le joueur peut rester farmer sans être téléporté.
##
## Coop (plusieurs joueurs) : N'IMPORTE QUEL joueur vivant peut l'activer ; le premier « interagir » lance un compte à rebours
## de Balance.COOP_TELEPORT_COUNTDOWN_S (15 s, visible de tous : `countdown_left`, signaux `countdown_started` /
## `countdown_cancelled`) ; `used` n'est émis qu'à zéro, où que soient les joueurs (le sauvetage des spectateurs se fait au
## début de l'étage suivant, Players.resurrect_all). Solo : `used` immédiat, comme avant.

signal used
signal countdown_started(seconds: float)
signal countdown_cancelled

## Maintien (s) exigé sur l'action « interagir » avant de partir (audit Choix P4). Valeur dans
## Balance.UI_EXIT_HOLD_S ; alias conservé pour les appelants existants.
const EXIT_HOLD_S: float = preload("res://scripts/core/balance.gd").UI_EXIT_HOLD_S

var active := false
var _player_on := false
var _inside: Array = [] ## joueurs sur le téléporteur (coop) ; _player_on en est le reflet
var countdown_left := 0.0 ## > 0 : départ de l'équipe dans ce nombre de secondes (coop)
var _light: LightRig.Handle = null


func _init() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 80.0
	cs.shape = circle
	add_child(cs)
	visible = false


func _ready() -> void:
	add_to_group(&"interactable")
	set_physics_process(false)
	body_entered.connect(func(b: Node) -> void:
		CoopRules.track_enter(_inside, b)
		_player_on = _player_on or not _inside.is_empty())
	body_exited.connect(func(b: Node) -> void:
		CoopRules.track_exit(_inside, b)
		_player_on = not _inside.is_empty())


func set_active(value: bool) -> void:
	if not value:
		cancel_countdown()
	active = value
	visible = value
	if value and _light == null:
		_light = LightRig.attach(self, &"teleporter")
	elif _light != null:
		_light.set_enabled(value)
	queue_redraw()


func use() -> bool:
	if not active:
		return false
	if CoopRules.is_coop():
		if countdown_left > 0.0:
			return false # déjà lancé : le compte court pour tout le monde
		countdown_left = Balance.COOP_TELEPORT_COUNTDOWN_S
		set_physics_process(true)
		countdown_started.emit(countdown_left)
		return true
	used.emit()
	return true


## Annule le compte à rebours (étage quitté, équipe à terre).
func cancel_countdown() -> void:
	if countdown_left > 0.0:
		countdown_left = 0.0
		set_physics_process(false)
		countdown_cancelled.emit()


func _physics_process(delta: float) -> void:
	tick(delta)


## Avance le compte à rebours de la coop (public pour les tests). À zéro : `used`.
func tick(delta: float) -> void:
	if countdown_left <= 0.0:
		return
	if Players.alive_count() == 0: # équipe entière à terre : la défaite passe avant le départ
		cancel_countdown()
		return
	countdown_left -= delta
	if countdown_left <= 0.0:
		countdown_left = 0.0
		set_physics_process(false)
		used.emit()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 80.0, Color(0.5, 0.3, 1.0, 0.35))
	draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 48, Color(0.7, 0.5, 1.0), 5.0)


func can_interact() -> bool:
	return active and _player_on


func interact_label() -> String:
	return "Partir"


## Appelé par le répartiteur unique du HUD, une fois le maintien de EXIT_HOLD_S accompli.
func interact(_who: Node = null) -> bool:
	return use()


## Invite : maintien de 0,6 s (départ irréversible) + coffres encore fermés dans le libellé.
func interact_state() -> Dictionary:
	if countdown_left > 0.0: # compte déjà lancé par un joueur : l'invite l'écrit, plus de maintien
		return {"visible": can_interact(), "enabled": false, "label": "Départ dans %d s" % int(ceil(countdown_left)), "hold_s": 0.0}
	var left := 0
	if is_inside_tree():
		for c in get_tree().get_nodes_in_group(&"chests"):
			if c.has_method(&"is_opened") and not c.is_opened():
				left += 1
	var txt := "Partir"
	if left > 0:
		txt = "Partir — %d coffre%s restant%s" % [left, "s" if left > 1 else "", "s" if left > 1 else ""]
	return {"visible": can_interact(), "enabled": true, "label": txt, "hold_s": EXIT_HOLD_S}


func interact_priority() -> int:
	return 0
