class_name PlayerInteract
extends RefCounted
## Interaction d'UN joueur (coop 1-4) : choix de la cible (groupe "interactable") et lecture de l'action « interact »
## sur la source d'entrée du joueur, appui simple ou maintien. Reprend la logique du répartiteur unique du HUD
## (hud.gd _update_interact, audit Choix L1) pour qu'elle vive côté joueur : chaque joueur interagit avec sa propre
## cible, avec sa propre manette.
##
## Branchement (lot UI) : le HUD pose `player.interaction.enabled = true` (sinon rien n'est lu ni appelé : pas de
## double interaction tant que le HUD garde son répartiteur), puis n'affiche plus que l'état exposé : `target`,
## `state` ({visible, enabled, label, hold_s} de la cible), `hold_s`, `progress` (0-1 du maintien, 1 = abouti).
## Le signal `target_changed` prévient d'un changement de cible. Le joueur appelle update() une fois par image de
## physique (Player._physics_process).
##
## Appel de la cible : interact(player) si sa méthode prend un argument (interaction attribuée au joueur, coffres
## et stations par joueur), sinon interact() comme avant ; idem interact_state(player) / interact_state().

signal target_changed(target: Node)

## Égalité de distance (px) à laquelle la priorité de la cible départage (coffre 3 > capsule 2 > pilier 1 > téléporteur 0).
const TIE_PX := 16.0

var player: Node2D
## Opt-in : faux tant que le HUD garde son propre répartiteur (voir l'en-tête).
var enabled := false
var target: Node = null
var state: Dictionary = {}
var hold_s := 0.0
var progress := 0.0
var _hold_t := 0.0
var _hold_done := false
var _hold_target: Node = null


func _init(p: Node2D = null) -> void:
	player = p


## Cible la plus proche (priorité à égalité) puis entrée de la source `src`. `delta` : temps du maintien.
func update(delta: float, src: InputSource) -> void:
	if not enabled or player == null or not player.is_inside_tree():
		return
	_pick_target()
	var enabled_target: bool = bool(state.get("enabled", true))
	hold_s = float(state.get("hold_s", 0.0))
	if target != _hold_target:
		_hold_target = target
		_hold_t = 0.0
		_hold_done = false
		target_changed.emit(target)
	var live: bool = target != null and enabled_target and not player.get_tree().paused and target.has_method(&"interact")
	if not live or src == null:
		_hold_t = 0.0
		_hold_done = false
	elif hold_s <= 0.0:
		if src.just_pressed(&"interact"):
			_fire()
	elif not src.is_pressed(&"interact"):
		_hold_t = 0.0
		_hold_done = false
	elif not _hold_done and (_hold_t > 0.0 or src.just_pressed(&"interact")):
		_hold_t += delta
		if _hold_t >= hold_s:
			_hold_done = true
			_fire()
	progress = 1.0 if _hold_done else (clampf(_hold_t / hold_s, 0.0, 1.0) if hold_s > 0.0 else 0.0)


## Oublie la cible (mort, changement d'étage).
func reset() -> void:
	if target != null:
		target = null
		target_changed.emit(null)
	state = {}
	hold_s = 0.0
	progress = 0.0
	_hold_t = 0.0
	_hold_done = false
	_hold_target = null


func _pick_target() -> void:
	target = null
	state = {}
	var pp := player.global_position
	var best := INF
	var best_prio := -1
	for n in player.get_tree().get_nodes_in_group(&"interactable"):
		if not (n is Node2D):
			continue
		var s := {}
		if n.has_method(&"interact_state"):
			s = n.interact_state(player) if n.get_method_argument_count(&"interact_state") >= 1 else n.interact_state()
		elif n.has_method(&"can_interact") and n.can_interact():
			s = {"visible": true, "enabled": true, "hold_s": 0.0}
			if n.has_method(&"interact_label"):
				s["label"] = str(n.interact_label())
		if not bool(s.get("visible", false)):
			continue
		var d := (n as Node2D).global_position.distance_to(pp)
		var prio: int = int(n.interact_priority()) if n.has_method(&"interact_priority") else 0
		if target == null or d < best - TIE_PX or (absf(d - best) <= TIE_PX and prio > best_prio):
			best = d
			best_prio = prio
			target = n
			state = s


func _fire() -> void:
	var tgt := target
	if player.has_method(&"interact_with"):
		player.interact_with(tgt)
	elif tgt.get_method_argument_count(&"interact") >= 1:
		tgt.interact(player)
	else:
		tgt.interact()
	if not is_instance_valid(tgt) or tgt.is_queued_for_deletion():
		target = null
