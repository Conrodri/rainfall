extends Node
## Capture de l'aperçu de sorts de la fiche (SANS --headless).
## godot --path game res://tests/_preview_capture.tscn -- --out=<dossier> --tag=avant --chars=vigie,ardent
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
	func is_unlocked(_key: StringName) -> bool:
		return true

var _out := ""
var _tag := "x"
var _chars: Array = ["vigie"]

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--tag="): _tag = a.substr(6)
		elif a.begins_with("--chars="): _chars = a.substr(8).split(",")
	get_window().size = Vector2i(1920, 1080)
	await _f(3)
	for id in _chars:
		var s := NewRunScreen.new()
		if not OS.get_cmdline_user_args().has("--real"): s.profile = FakeProfile.new()
		add_child(s)
		await _f(20)
		var idx := -1
		for i in s.characters.size():
			if String((s.characters[i] as Dictionary).get("id", "")) == id: idx = i
		if idx < 0: print("absent ", id); s.queue_free(); continue
		s.cards[idx].pressed.emit()
		await _f(40)
		var ar: SpellPreview = s.sheet.arena
		print(id, " arena=", ar != null, " ready=", ar != null and ar.ready_to_cast)
		for slot in [1, 2, 3, 4]:
			var nbtn: int = (s.sheet.focus_rows()[slot - 1] as Array).size()
			for bi in (1 if OS.get_cmdline_user_args().has("--base") else nbtn):
				await _shoot(s, ar, id, slot, bi)
		for slot in []:
			var row: Array = s.sheet.focus_rows()[slot - 1] if s.sheet.focus_rows().size() >= slot else []
			if row.is_empty(): continue
			(row[0] as Button).pressed.emit()
			for k in 3:
				await _f(22)
				CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s_s%d_%d.png" % [_out, _tag, id, slot, k])
			print(id, " slot ", slot, " ok=", ar.casts_ok if ar else -1, " fail=", ar.casts_failed if ar else -1, " dmg=", ar.damage_total if ar else -1)
		s.queue_free()
		await _f(10)
	get_tree().quit()


func _shoot(s: NewRunScreen, ar: SpellPreview, id: String, slot: int, bi: int) -> void:
	var row: Array = s.sheet.focus_rows()[slot - 1]
	var b := row[bi] as Button
	print(id, " slot ", slot, " btn ", bi, " ", b.name, " disabled=", b.disabled)
	b.pressed.emit()
	for k in 3:
		await _f(24)
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s_s%d_b%d_%d.png" % [_out, _tag, id, slot, bi, k])
	print("   ok=", ar.casts_ok, " fail=", ar.casts_failed, " dmg=", snappedf(ar.damage_total, 0.1), " loadout=", ar._loadout, " chosen=", s.sheet.chosen)
