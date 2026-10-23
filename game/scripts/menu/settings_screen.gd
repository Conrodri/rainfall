class_name SettingsScreen
extends Control
## Enveloppe plein écran du panneau de réglages pour l'écran titre (docs/Design_Menus.md §3.4) :
## voile assombri à 70 % sur le fond animé (posé par App), SettingsPanel centré, sous-panneau Commandes.
## Lot F branche `back_requested`.

signal back_requested

var panel: SettingsPanel
var controls: ControlsPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = SettingsPanel.new()
	controls = ControlsPanel.new()
	var frame := PanelContainer.new() # panneau DA derrière les réglages / commandes
	frame.theme = UiTheme.theme()
	center.add_child(frame)
	frame.add_child(panel)
	frame.add_child(controls)
	controls.visible = false
	panel.back_requested.connect(func() -> void: back_requested.emit())
	panel.controls_requested.connect(func() -> void: _show(controls))
	controls.back_requested.connect(func() -> void: _show(panel))
	panel.focus_first.call_deferred()


func _show(p: Control) -> void:
	panel.visible = (p == panel)
	controls.visible = (p == controls)
