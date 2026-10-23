class_name ObjectivesPanel
extends PanelContainer
## Panneau d'objectifs du HUD (style Risk of Rain), sous la minimap.
## Apparaît à l'activation du gros pilier (boss d'étage + zone de charge, voir Pillar / StageManager) :
##   « Tuer le boss »                  coché à la mort du boss d'étage (Pillar.boss_dead) ;
##   « Charger le téléporteur  NN % »  suit la charge réelle (Pillar.charge_ratio, n'avance que dans la zone) ;
## puis, étage terminé (StageManager.floor_cleared) : « Activer le téléporteur » (action interagir).
## Disparaît au démarrage de l'étage suivant. L'état est relu sur le StageManager (groupe `stage_manager`)
## à chaque image : une partie reprise depuis une sauvegarde affiche directement le bon état.
## Placement par le HUD (place()) : sous la minimap, aligné à droite, dans la zone sûre.
## Cases à cocher : placeholders dessinés (_draw), à remplacer par une icône du kit UI Blender.

const COL_TODO := Color(0.93, 0.95, 1.0)
const COL_DONE := Color(0.45, 0.92, 0.5)
const COL_CHARGE := Color(0.4, 0.9, 1.0)
const COL_TELEPORT := Color(0.8, 0.62, 1.0)
const COL_TITLE := Color(1.0, 0.85, 0.35)
const BASE_WIDTH := 460.0
const MIN_WIDTH := 300.0

var stage_manager: StageManager = null ## optionnel (tests) ; sinon cherché dans le groupe `stage_manager`
var ui_scale := 1.0

var _title: Label
var _boss_row: ObjectiveRow
var _charge_row: ObjectiveRow
var _teleport_row: ObjectiveRow
var _style: StyleBoxFlat
var _pulse := 0.0
var _compact := false ## tactile : place comptée au-dessus de la grappe de sorts (voir set_compact)


func _init() -> void:
	name = &"ObjectivesPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.03, 0.05, 0.09, 0.62)
	_style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", _style)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = _label(v)
	_title.text = "OBJECTIFS"
	_title.add_theme_color_override("font_color", COL_TITLE)
	_boss_row = ObjectiveRow.new("Tuer le boss")
	v.add_child(_boss_row)
	_charge_row = ObjectiveRow.new("Charger le téléporteur")
	v.add_child(_charge_row)
	_teleport_row = ObjectiveRow.new("Activer le téléporteur")
	_teleport_row.visible = false # étage pas encore terminé
	v.add_child(_teleport_row)
	set_ui_scale(1.0)


func set_ui_scale(s: float) -> void:
	ui_scale = s
	_style.content_margin_left = 18.0 * s
	_style.content_margin_right = 18.0 * s
	_style.content_margin_top = (6.0 if _compact else 10.0) * s
	_style.content_margin_bottom = (8.0 if _compact else 12.0) * s
	_title.add_theme_font_size_override("font_size", int(22 * s))
	for r in [_boss_row, _charge_row, _teleport_row]:
		(r as ObjectiveRow).set_ui_scale(s)
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", int(6 * s))


## Mode compact (tactile, hauteur bornée par la grappe de sorts) : sans titre « OBJECTIFS », marges serrées, deux
## lignes au plus (étage terminé : seule « Activer le téléporteur » reste, les deux autres étant cochées).
## Taille des textes inchangée (plancher 26 px mobile).
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	set_ui_scale(ui_scale)
	_apply_rows()


func is_compact() -> bool:
	return _compact


## Hauteur du panneau dans un mode donné (sans le changer), pour le placement par le HUD.
func height_for(compact: bool) -> float:
	var was := _compact
	set_compact(compact)
	var h := get_combined_minimum_size().y
	set_compact(was)
	return h


func _apply_rows() -> void:
	_title.visible = not _compact
	var hide_done := _compact and _teleport_row.visible
	_boss_row.visible = not hide_done
	_charge_row.visible = not hide_done


## Coin haut-droit du panneau en `top_right` (px du viewport), largeur bornée par `max_width`.
func place(top_right: Vector2, max_width: float) -> void:
	var w := clampf(BASE_WIDTH * ui_scale, minf(MIN_WIDTH * ui_scale, max_width), max_width)
	custom_minimum_size.x = 0.0
	w = maxf(w, get_combined_minimum_size().x) # jamais de texte tronqué : le contenu impose sa largeur
	custom_minimum_size.x = w
	size = Vector2(w, 0.0)
	position = Vector2(top_right.x - w, top_right.y)


func _process(delta: float) -> void:
	refresh()
	if visible and _teleport_row.visible and not _teleport_row.done:
		_pulse += delta
		_teleport_row.modulate.a = 0.7 + 0.3 * (0.5 + 0.5 * sin(_pulse * 4.0))
	else:
		_teleport_row.modulate.a = 1.0


## Relit l'état du gros pilier et de l'étage (public pour les tests).
func refresh() -> void:
	var mgr := _manager()
	var big := _big_pillar(mgr)
	var shown := big != null and (big.state == Pillar.STATE_ACTIVE or big.state == Pillar.STATE_DONE)
	if mgr != null and mgr.floor_cleared:
		shown = true
	visible = shown
	if not shown:
		return
	var done := big == null or big.state == Pillar.STATE_DONE
	var boss_done := done or big.boss_dead
	var ratio := 1.0 if (done or big.is_charged()) else big.charge_ratio()
	_boss_row.set_state(boss_done, COL_DONE if boss_done else COL_TODO, "")
	var pct := int(floor(ratio * 100.0))
	var charging := big != null and big.player_in_zone and ratio < 1.0
	_charge_row.set_state(ratio >= 1.0, COL_DONE if ratio >= 1.0 else (COL_CHARGE if charging else COL_TODO), "%d %%" % pct)
	_teleport_row.visible = mgr != null and mgr.floor_cleared
	_teleport_row.set_state(false, COL_TELEPORT, "")
	_apply_rows()


func is_boss_done() -> bool:
	return _boss_row.done


func is_charge_done() -> bool:
	return _charge_row.done


func charge_text() -> String:
	return _charge_row.value_text()


func is_teleport_shown() -> bool:
	return visible and _teleport_row.visible


func _manager() -> StageManager:
	if stage_manager != null and is_instance_valid(stage_manager):
		return stage_manager
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"stage_manager") as StageManager


func _big_pillar(mgr: StageManager) -> Pillar:
	if mgr == null:
		return null
	for p in mgr.pillars:
		if is_instance_valid(p) and p.kind == Pillar.Kind.BIG:
			return p
	return null


static func _label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Une ligne d'objectif : case (cochée quand terminé) + texte + valeur à droite (pourcentage).
class ObjectiveRow extends HBoxContainer:
	var done := false
	var _box: CheckMark
	var _text: Label
	var _value: Label

	func _init(text: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box = CheckMark.new()
		add_child(_box)
		_text = ObjectivesPanel._label(self)
		_text.text = text
		_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_value = ObjectivesPanel._label(self)
		_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	func set_ui_scale(s: float) -> void:
		_box.custom_minimum_size = Vector2(26, 26) * s
		_text.add_theme_font_size_override("font_size", int(28 * s))
		_value.add_theme_font_size_override("font_size", int(28 * s))
		_value.custom_minimum_size.x = 84.0 * s
		add_theme_constant_override("separation", int(12 * s))

	func set_state(is_done: bool, col: Color, value: String) -> void:
		done = is_done
		_text.add_theme_color_override("font_color", col)
		_value.add_theme_color_override("font_color", col)
		_value.text = value
		_value.visible = value != ""
		_box.set_state(is_done, col)

	func value_text() -> String:
		return _value.text


## Case à cocher (placeholder dessiné).
class CheckMark extends Control:
	var _done := false
	var _col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_state(is_done: bool, col: Color) -> void:
		if is_done == _done and col == _col:
			return
		_done = is_done
		_col = col
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.5), true)
		draw_rect(r, _col, false, maxf(2.0, size.x * 0.09))
		if _done:
			var w := size.x
			var pts := PackedVector2Array([Vector2(w * 0.2, w * 0.52), Vector2(w * 0.42, w * 0.74), Vector2(w * 0.8, w * 0.26)])
			draw_polyline(pts, _col, maxf(3.0, w * 0.14), true)
