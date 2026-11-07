class_name CoopLocal
extends Node
## Coop locale PC en cours de run (étape 4, docs/multi/Archi_Reseau.md §3) : manettes des joueurs, créé par Main.
##
## Déconnexion d'une manette (décision d'implémentation, la plus simple et robuste en canapé) :
## - le joueur concerné devient ABSENT : source d'entrée muette (InputSourceIdle : immobile, aucun sort manuel ni
##   esquive), invulnérable tant qu'il est absent (protection renouvelée), plaque « Manette déconnectée » ;
## - le jeu se met en PAUSE (menu pause, « Manette du joueur N déconnectée ») ; on peut reprendre sans lui ;
## - reprise du contrôle : la manette rebranchée (même index ou non) est rendue au premier joueur absent ; ou
##   n'importe quelle manette LIBRE (non attribuée) qui appuie sur A ou Start le reprend. Aucune autre règle.
## Pause par n'importe quel joueur : Start de toute manette est relayé par PauseMenu (liaison fixe).
##
## Mode test (À RETIRER OU MASQUER AVANT LA SORTIE) : `arm_join()` (bouton « Ajouter un joueur (manette) » du panneau)
## attend qu'une manette libre appuie sur A ou Start, puis Main.add_local_player l'ajoute en cours de run.

signal pad_lost(slot: int)
signal pad_restored(slot: int, device: int)
signal join_armed_changed(armed: bool)
signal player_joined(slot: int)

const ABSENT_PROTECT_S := 1.0 ## invulnérabilité renouvelée toutes les 0,5 s tant que le joueur est absent
const JOIN_BUTTONS: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_START]

var main: Node
## Mode test : la prochaine manette libre qui appuie sur A / Start rejoint la partie.
var join_armed := false
var _protect_acc := 0.0


func _init() -> void:
	name = "CoopLocal"
	process_mode = Node.PROCESS_MODE_ALWAYS # la reconnexion se fait souvent pendant la pause


func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


# --- Lecture --------------------------------------------------------------------------

## Emplacement qui pilote la manette `device`, sinon -1.
static func slot_of_device(device: int) -> int:
	for e in Players.entries():
		if e.input != null and e.input.kind == InputSource.Kind.PAD and not (e.input is InputSourceIdle) and e.input.device == device:
			return e.id
	return -1


## Vrai si le joueur `slot` a perdu sa manette.
static func is_absent(slot: int) -> bool:
	var src := Players.input_of(slot)
	return src is InputSourceIdle


## Premier joueur absent (manette perdue), de préférence celui qui avait `device` ; -1 si aucun.
static func orphan_for(device: int) -> int:
	var first := -1
	for e in Players.entries():
		if e.input is InputSourceIdle:
			if (e.input as InputSourceIdle).lost_device == device:
				return e.id
			if first < 0:
				first = e.id
	return first


## Manettes connectées qui ne pilotent aucun joueur.
static func free_pads() -> Array[int]:
	var out: Array[int] = []
	for d in Input.get_connected_joypads():
		if slot_of_device(d) < 0:
			out.append(d)
	return out


# --- Déconnexion / reconnexion --------------------------------------------------------

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		var slot := orphan_for(device)
		if slot >= 0:
			restore(slot, device)
	else:
		var slot := slot_of_device(device)
		if slot >= 0:
			lose(slot)


## Le joueur `slot` perd sa manette : source muette, protection, pause du jeu.
func lose(slot: int) -> void:
	var src := Players.input_of(slot)
	if src == null or src is InputSourceIdle:
		return
	Players.set_input(slot, InputSourceIdle.new(src.device))
	_protect(slot)
	var pm := _pause_menu()
	if pm != null and pm.has_method(&"notify_pad_lost"):
		pm.notify_pad_lost(slot)
	pad_lost.emit(slot)


## Rend une manette au joueur absent `slot`.
func restore(slot: int, device: int) -> void:
	if not is_absent(slot) or slot_of_device(device) >= 0:
		return
	Players.set_input(slot, InputSource.pad_source(device))
	Players.note_activity(slot)
	Input.start_joy_vibration(device, 0.5, 0.5, 0.2) # retour tactile : la manette rendue vibre 200 ms
	var pm := _pause_menu()
	if pm != null and pm.has_method(&"notify_pad_restored"):
		pm.notify_pad_restored(slot) # bandeau de pause : « Manette du joueur N reconnectée » + coche
	pad_restored.emit(slot, device)


func _process(delta: float) -> void:
	_protect_acc += delta
	if _protect_acc < 0.5:
		return
	_protect_acc = 0.0
	for e in Players.entries():
		if e.input is InputSourceIdle:
			_protect(e.id)


func _protect(slot: int) -> void:
	var p := Players.by_id(slot)
	if p != null and p.has_method(&"grant_invulnerability"):
		p.grant_invulnerability(ABSENT_PROTECT_S)


# --- Manettes libres : reprise d'un absent, jonction du mode test ----------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var jb := event as InputEventJoypadButton
	if not jb.pressed or not JOIN_BUTTONS.has(int(jb.button_index)):
		return
	handle_free_pad_press(jb.device)


## Une manette appuie sur A / Start : si elle est libre, reprend un absent ou (mode test armé) rejoint la partie.
## Rend vrai si l'appui est consommé. Public pour les tests.
func handle_free_pad_press(device: int) -> bool:
	if device < 0 or slot_of_device(device) >= 0:
		return false
	var orphan := orphan_for(device)
	if orphan >= 0:
		restore(orphan, device)
		_consume()
		return true
	if join_armed and main != null and main.has_method(&"add_local_player"):
		var slot: int = main.add_local_player(InputSource.pad_source(device))
		if slot >= 0:
			set_join_armed(false)
			player_joined.emit(slot)
			_consume()
			return true
	return false


func set_join_armed(on: bool) -> void:
	if join_armed == on:
		return
	join_armed = on
	join_armed_changed.emit(on)


func arm_join() -> void:
	set_join_armed(true)


func _consume() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _pause_menu() -> Node:
	var hud: Variant = main.get(&"hud") if main != null else null
	return (hud as Node).get(&"pause_menu") if hud is Node else null
