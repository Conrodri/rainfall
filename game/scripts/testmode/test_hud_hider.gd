class_name TestHudHider
extends Node
## Mode test : masque le HUD (TestMode.hide_hud) pour voir les sorts. Tout le HUD est caché (barres, minimap, objets,
## sorts, boutons tactiles) SAUF le joystick flottant, indispensable au déplacement tactile. Le HUD est retrouvé par le
## groupe « hud » ; chaque nœud caché est mémorisé puis rétabli à la remise à zéro (ou à la sortie du mode test).
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

var _hidden := {} ## nœud -> visibilité d'origine


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TestMode.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	if TestMode.changed.is_connected(_sync):
		TestMode.changed.disconnect(_sync)
	_restore()


func _process(_delta: float) -> void:
	if TestMode.hide_hud:
		_hide_all() # le HUD rétablit parfois lui-même des éléments (minimap plein écran, bandeaux) : on les recache


func is_hidden() -> bool:
	return not _hidden.is_empty()


func _sync() -> void:
	if TestMode.hide_hud:
		_hide_all()
	else:
		_restore()


func _hud() -> Node:
	return get_tree().get_first_node_in_group(&"hud") if is_inside_tree() else null


func _hide_all() -> void:
	var hud := _hud()
	if hud == null:
		return
	var root: Variant = hud.get(&"root")
	if not (root is Control):
		return
	var keep: Variant = hud.get(&"joystick")
	var touch: Variant = hud.get(&"touch_layer")
	for c in (root as Control).get_children():
		if c == touch:
			continue
		_hide(c)
	if touch is Control:
		for c in (touch as Control).get_children():
			if c != keep:
				_hide(c)


func _hide(n: Node) -> void:
	if not (n is CanvasItem):
		return
	var ci := n as CanvasItem
	if not _hidden.has(ci):
		_hidden[ci] = ci.visible
	ci.visible = false


func _restore() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as CanvasItem).visible = bool(_hidden[n])
	_hidden.clear()
