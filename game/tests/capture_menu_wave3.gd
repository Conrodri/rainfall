extends Node
## Captures vague 3 (menus) : écran Nouvelle run à l'arrivée (fiche du perso présélectionné), puis la fiche de
## chaque personnage ; récap de fin de run avec un déblocage de personnage.
## PC     : godot --path game --write-movie <dossier>/mv/x.png --fixed-fps 30 res://tests/capture_menu_wave3.tscn -- --out=<dossier>
## Mobile : idem avec `-- --mobile --out=<dossier>` (tactile, fenêtre 2400x1080 logiques).

class FakeProfile extends RefCounted:
	var rubies := 10
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "averse"
	var stats := {}

	func is_unlocked(_key: StringName) -> bool:
		return false

var _out := ""
var _tag := "pc"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--mobile":
			_tag = "mobile"
			Platform.set_input_mode(Platform.InputMode.TOUCH)
	if _tag == "mobile":
		get_window().size = Vector2i(2400, 1080)
	await _frames(3)
	var s := NewRunScreen.new()
	s.profile = FakeProfile.new()
	add_child(s)
	await _frames(20)
	_save("%s_newrun_open" % _tag)
	for i in s.characters.size():
		s.cards[i].pressed.emit()
		await _frames(14)
		_save("%s_sheet_%s" % [_tag, String(s.characters[i].get("id", i))])
	s.queue_free()
	await _frames(2)
	var e := EndRunScreen.create({"victory": false, "reason": "death", "character_name": "Averse", "mode": "moyen",
		"stage": 3, "active_time_s": 642.0, "level": 17, "pillars": 4, "kills": 1204, "items": 9, "gold": 230,
		"rubies": 87, "unlocks": [&"character:rictus", &"spell:roaming_embers", &"mode:difficile"]})
	add_child(e)
	await _frames(60)
	_save("%s_endrun_unlocks" % _tag)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name_: String) -> void:
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/%s.png" % [_out, name_])
	print("shot ", name_)
