class_name BossBars
extends VBoxContainer
## Barres de boss en haut de l'écran : nom + PV de chaque boss vivant (groupe `bosses`).
## Boss d'étage : nom de son id (data/floors.json, boss_names), sinon celui de la carte (data/maps/<id>.json,
## floor_boss_name) ; mini-boss : nom de data/minibosses.json, sinon « Gardien du pilier ».
## Suit Events.boss_spawned / boss_killed ; PV relus chaque image (au plus 3 boss).
## Élément fonctionnel provisoire (rectangles), à habiller par un asset d'UI Blender plus tard.

const MINI_NAME := "Gardien du pilier"
const FLOOR_FALLBACK := "Boss d'étage"
const COL_FLOOR := Color(0.85, 0.15, 0.2)
const COL_MINI := Color(0.8, 0.3, 0.9)
const PLATE_ALPHA := 0.35 ## discrète : ne cache pas le boss (audit H15)
const PLATE_ALPHA_TOP := 0.2 ## boss dans le tiers haut de l'écran
const PLATE_H := 84.0 ## hauteur mini de la plaque à ui_scale 1 (nom 26 + barre + marges)
const TOP_THIRD := 1.0 / 3.0

var ui_scale := 1.0
var _entries: Array = [] ## [{boss, box, label, bar}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	Events.boss_spawned.connect(_on_spawned)
	Events.boss_killed.connect(_on_killed)
	for b in get_tree().get_nodes_in_group(&"bosses"):
		if b is Node2D and bool(b.get(&"active")):
			_on_spawned(b, b.get(&"boss_kind") == &"etage")
	visible = not _entries.is_empty()


func _exit_tree() -> void:
	if Events.boss_spawned.is_connected(_on_spawned):
		Events.boss_spawned.disconnect(_on_spawned)
	if Events.boss_killed.is_connected(_on_killed):
		Events.boss_killed.disconnect(_on_killed)


func count() -> int:
	return _entries.size()


func names() -> Array:
	var out: Array = []
	for e in _entries:
		out.append((e["label"] as Label).text)
	return out


static func boss_name(boss: Node, is_floor: bool, tree: SceneTree) -> String:
	if not is_floor:
		return mini_name(boss)
	# Plusieurs boss par étage (tirés parmi 3) : le nom suit le boss, pas la carte.
	var bid := str(boss.call(&"boss_id")) if boss != null and boss.has_method(&"boss_id") else ""
	var by_id := str((FloorPlan.data().get("boss_names", {}) as Dictionary).get(bid, "")) if bid != "" else ""
	if not by_id.is_empty():
		return by_id
	var sm := tree.get_first_node_in_group(&"stage_manager")
	if sm != null:
		var d := Minimap.map_json(str(sm.get(&"map_id")))
		var n := str(d.get("floor_boss_name", ""))
		if not n.is_empty():
			return n
	return FLOOR_FALLBACK


## Vrai nom d'un mini-boss : data/minibosses.json `minis.<id>.name`, id = celui de son MiniBossBrain
## (`mini_id`), sinon MiniBossBrain.resolve_id ; repli MINI_NAME si absent.
static func mini_name(boss: Node) -> String:
	var en := boss as Enemy
	if en == null:
		return MINI_NAME
	var id: StringName = &""
	if en.brain != null and en.brain is MiniBossBrain:
		id = (en.brain as MiniBossBrain).mini_id
	if id == &"":
		id = MiniBossBrain.resolve_id(en)
	var n := str(MiniBossBrain.config(id).get("name", "")) if id != &"" else ""
	return n if not n.is_empty() else MINI_NAME


func _on_spawned(boss: Node2D, is_floor: bool) -> void:
	for e in _entries:
		if e["boss"] == boss:
			return
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = boss_name(boss, is_floor, get_tree())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	box.add_child(l)
	var bar := BossHealthBar.new() # encoches de phase, ghost, statuts (scripts/ui/boss_health_bar.gd)
	bar.ui_scale = ui_scale
	if boss is Enemy:
		bar.setup(boss as Enemy, is_floor)
	box.add_child(bar)
	# plaque translucide noire derrière nom + barre (contraste sur les VFX clairs : colonne de pluie du Semeur)
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, PLATE_ALPHA)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	plate.add_theme_stylebox_override("panel", sb)
	plate.add_child(box)
	if is_floor:
		add_child(plate)
		move_child(plate, 0) # le boss d'étage en premier
	else:
		add_child(plate)
	_entries.append({"boss": boss, "box": plate, "label": l, "bar": bar, "plate": sb})
	_apply_sizes()
	visible = true


func _on_killed(boss: Node2D, _is_floor: bool) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i]["boss"] == boss:
			_remove(i)


func _remove(i: int) -> void:
	(_entries[i]["box"] as Node).queue_free()
	_entries.remove_at(i)
	visible = not _entries.is_empty()


func set_ui_scale(s: float) -> void:
	ui_scale = s
	_apply_sizes()


func _apply_sizes() -> void:
	add_theme_constant_override("separation", int(10 * ui_scale))
	for e in _entries:
		(e["label"] as Label).add_theme_font_size_override("font_size", maxi(int(26 * ui_scale), HudMetrics.floor_px())) # plancher 18 / 26 px
		(e["bar"] as BossHealthBar).set_ui_scale(ui_scale)
		var sb := e["plate"] as StyleBoxFlat
		sb.content_margin_left = 10.0 * ui_scale
		sb.content_margin_right = 10.0 * ui_scale
		var nfs := maxi(int(26 * ui_scale), HudMetrics.floor_px())
		sb.content_margin_top = maxf(2.0 * ui_scale, UiTheme.v_margin(sb, nfs))
		sb.content_margin_bottom = sb.content_margin_top
		(e["box"] as Control).custom_minimum_size.y = PLATE_H * ui_scale


func _process(_delta: float) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		var b: Variant = _entries[i]["boss"]
		if not is_instance_valid(b) or not bool((b as Node).get(&"active")):
			_remove(i)
			continue
		# PV, encoches, statuts : relus par BossHealthBar._process
		_update_plate_alpha(_entries[i], b as Node)


## Barre riche du boss `boss` (tests), null si absente.
func bar_for(boss: Node) -> BossHealthBar:
	for e in _entries:
		if e["boss"] == boss:
			return e["bar"] as BossHealthBar
	return null


## Alpha de la plaque : PLATE_ALPHA, ou PLATE_ALPHA_TOP si le boss est dans le tiers haut de l'écran
## (sa plaque le recouvrirait). Transition douce.
func _update_plate_alpha(e: Dictionary, boss: Node) -> void:
	var sb := e["plate"] as StyleBoxFlat
	var want := PLATE_ALPHA
	if boss is Node2D and is_inside_tree():
		var y := (boss as Node2D).get_global_transform_with_canvas().origin.y
		if y < get_viewport_rect().size.y * TOP_THIRD:
			want = PLATE_ALPHA_TOP
	sb.bg_color.a = move_toward(sb.bg_color.a, want, 1.0 * get_process_delta_time())
