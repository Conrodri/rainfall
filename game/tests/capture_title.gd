extends Node
## Capture de l'écran titre à t = 1 s et t = 6 s (la caméra du fond a bougé) + crédits à t = 8 s.
## PC     : godot --path game --write-movie <dossier>/mv/title.png --fixed-fps 30 res://tests/capture_title.tscn -- --out=<dossier> --tag=pc
## Mobile : idem avec `-- --mobile --out=<dossier> --tag=mobile` (fenêtre forcée à 20:9, 2400×1080 logiques).
## Option : --map=foret_brume|cite_rouille|terrasses_noyees, --nosave.

const TITLE := preload("res://scenes/menu/title.tscn")
const CREDITS := preload("res://scenes/menu/credits.tscn")

var _t := 0.0
var _out := ""
var _tag := "pc"
var _map := "terrasses_noyees"
var _nosave := false
var _title: TitleScreen
var _credits: CreditsScreen
var _shots := {1.0: false, 6.0: false, 8.5: false}


func _fake_save() -> Dictionary:
	return {"character": "ardent", "character_name": "Ardent", "mode": "moyen", "stage": 2, "active_time_s": 252.0,
		"map_id": _map, "saved_at": 0}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--map="):
			_map = a.substr(6)
		elif a == "--touch":
			Platform.set_input_mode(Platform.InputMode.TOUCH)
		elif a == "--nosave":
			_nosave = true
	if _tag.begins_with("mobile"):
		get_window().size = Vector2i(2400, 1080)
	_title = TITLE.instantiate() as TitleScreen
	if not _nosave:
		_title.summary_provider = _fake_save
	else:
		_title.summary_provider = func(): return {}
	add_child(_title)


func _process(delta: float) -> void:
	_t += delta
	for k in _shots.keys():
		if _t >= k and not _shots[k]:
			_shots[k] = true
			_save("%s_t%d" % [_tag, int(k)])
	if _t >= 7.0 and _credits == null:
		_title.queue_free()
		_credits = CREDITS.instantiate() as CreditsScreen
		add_child(_credits)
	if _t >= 9.0:
		get_tree().quit()


func _save(name_: String) -> void:
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/%s.png" % [_out, name_])
	print("shot ", name_, " ", get_viewport().get_visible_rect().size)
	if _title != null and is_instance_valid(_title) and _title.root != null:
		print("  root=", _title.root.size, " main=", _title.main_button.global_position, _title.main_button.size, " logo=", _title._logo.global_position, " vis=", _title.main_button.is_visible_in_tree(), " vp=", get_viewport().get_visible_rect().size, " margins=", Platform.safe_margins())
		for c in _title.root.get_children():
			print("   ", c.name, " vis=", c.is_visible_in_tree(), " mod=", (c as CanvasItem).modulate, " rect=", (c as Control).get_global_rect(), " scale=", (c as Control).scale)
		print("   tier=", Quality.tier, " touch=", Platform.is_touch_mode(), " canvas_xf=", _title.root.get_global_transform_with_canvas())
