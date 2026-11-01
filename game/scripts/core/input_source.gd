class_name InputSource
extends RefCounted
## Source d'entrée d'un joueur (coop 1-4, docs/multi/Archi_Reseau.md §2 ligne 4). Le joueur, son SpellCaster et
## son esquive liront leur source au lieu d'appeler Input directement (migration : étape 2).
##
## Cette classe de base est la source GLOBALE : elle lit les actions de l'InputMap de tous les appareils à la fois
## (Input.get_vector, Input.is_action_pressed…) et le mode d'entrée courant de Platform. C'est EXACTEMENT le
## comportement actuel du jeu solo ; le joueur 1 la garde tant qu'il est seul. Variantes :
## - InputSourcePad (scripts/core/input_source_pad.gd) : une manette précise (coop locale) ;
## - InputSourceKbm (scripts/core/input_source_kbm.gd) : clavier-souris seul (coop locale, joueur au clavier) ;
## - tactile : source globale de genre TOUCH (joystick flottant et boutons injectent déjà les actions) ;
## - réseau (NetSource) : étape « en ligne », à venir.
## Aucune allocation par image : les lectures rendent des Vector2 / bool.

enum Kind { GLOBAL, KBM, PAD, TOUCH, NET }

const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const AIM_ACTIONS: Array[StringName] = [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]

var kind: int = Kind.GLOBAL
## Manette (Kind.PAD) : index d'appareil Godot ; -1 sinon.
var device := -1


static func global_source() -> InputSource:
	return InputSource.new()


static func touch_source() -> InputSource:
	var s := InputSource.new()
	s.kind = Kind.TOUCH
	return s


static func pad_source(pad_device: int) -> InputSource:
	return load("res://scripts/core/input_source_pad.gd").new(pad_device)


static func kbm_source() -> InputSource:
	return load("res://scripts/core/input_source_kbm.gd").new()


## Mode d'entrée (Platform.InputMode) : visée à la souris (KBM), au stick droit (GAMEPAD) ou automatique (TOUCH).
func mode() -> int:
	if kind == Kind.TOUCH:
		return Platform.InputMode.TOUCH
	return Platform.input_mode


## Déplacement voulu (longueur <= 1, zone morte appliquée), repère écran comme Input.get_vector.
func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Stick droit (visée manette), Vector2.ZERO au repos.
func aim_vector() -> Vector2:
	return Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")


func is_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)


## Point du monde sous le pointeur (souris) vu depuis `canvas`, ou null si la source n'a pas de pointeur actif.
func pointer_world(canvas: CanvasItem) -> Variant:
	if mode() == Platform.InputMode.KBM and canvas != null and canvas.is_inside_tree():
		return canvas.get_global_mouse_position()
	return null


## Vrai si l'événement vient de cette source (activité du joueur, absence > Balance.MULTI_AFK_S).
func owns_event(_event: InputEvent) -> bool:
	return true


## Lecture d'une image (sources par appareil : état « juste pressé ») ; appelée par Players une fois par image de
## physique. Sans effet pour la source globale (Input le fait déjà).
func poll() -> void:
	pass


## Libellé court (journal, écran de jonction).
func describe() -> String:
	match kind:
		Kind.TOUCH:
			return "tactile"
		Kind.KBM:
			return "clavier-souris"
		Kind.PAD:
			return "manette %d" % device
		Kind.NET:
			return "réseau"
	return "global"
