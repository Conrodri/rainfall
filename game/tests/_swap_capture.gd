extends Node
## Capture de l'échange d'icônes base/variante (SANS --headless) : variante « Tir double » débloquée et choisie,
## autres variantes verrouillées (infobulle de l'une d'elles).
## godot --path game res://tests/_swap_capture.tscn -- --out=<dossier> --tag=apres
class FakeProfile extends RefCounted:
	var rubies := 100
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "vigie"
	var stats := {"runs": 1, "victories": 0, "kills": 0, "play_time_s": 0.0, "best_time_s": {}}
	var unlocked_skins: Array = []
	var selected_skin := {}
	var best_runs := {}
	func is_unlocked(key: StringName) -> bool:
		return String(key).contains("tir_double")

var _out := ""
var _tag := "x"

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--tag="): _tag = a.substr(6)
	for w in [1920, 2400]:
		get_window().size = Vector2i(w, 1080)
		await _f(4)
		var s := NewRunScreen.new()
		s.profile = FakeProfile.new()
		add_child(s)
		await _f(20)
		for i in s.characters.size():
			if String((s.characters[i] as Dictionary).get("id", "")) == "vigie":
				s.cards[i].pressed.emit()
		await _f(40)
		var rows: Array = s.sheet.focus_rows()
		print("variant 1 locked=", (rows[0][1] as Button).get_meta("locked", false))
		(rows[0][1] as Button).pressed.emit()
		await _f(30)
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%d_swap.png" % [_out, _tag, w])
		(rows[2][1] as Button).grab_focus()
		await _f(30)
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%d_lock_tip.png" % [_out, _tag, w])
		(rows[0][0] as Button).pressed.emit() # re-clic sur la base (petite) : revient en grand
		await _f(30)
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%d_back.png" % [_out, _tag, w])
		print("base big=", (rows[0][0] as Button).get_meta("big"), " chosen=", s.sheet.chosen)
		s.queue_free()
		await _f(6)
	get_tree().quit()
