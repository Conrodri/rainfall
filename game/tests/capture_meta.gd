extends Node
## Captures de la méta hors ligne : titre (bouton Défi du jour + Succès), écran des succès, écran du défi du jour,
## bulle de didacticiel, notification de succès. Profil en mémoire seulement (jamais écrit).
## Fenêtre réelle : godot --path game res://tests/capture_meta.tscn -- --out=<dossier>

const TITLE := preload("res://scenes/menu/title.tscn")
const ACH := preload("res://scenes/menu/achievements.tscn")
const DAILY := preload("res://scenes/menu/daily.tscn")
const HINTS := preload("res://scripts/ui/onboarding_hints.gd")

var _out := ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await _frames(6)
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/%s.png" % [_out, name_])
	print("shot ", name_, " ", get_viewport().get_visible_rect().size)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Profile.write_enabled = false
	Profile.reset()
	Profile.stats["kills"] = 340
	Profile.stats["runs"] = 4
	Profile.unlock_achievement("first_blood")
	Profile.unlock_achievement("floor_1")
	Profile.unlock_achievement("floor_2")
	Profile.unlock_achievement("win_run")
	Profile.add_boss_kill("eclusier")
	Profile.add_boss_kill("cerf")
	Profile.set_daily({"streak": 3, "best_streak": 5, "last_key": DailyChallenge.today_key(), "completed": 6, "wins": 1,
		"days": {str(DailyChallenge.today_key()): {"tries": 2, "counted": true,
			"best": {"victory": false, "stage": 4, "kills": 612, "time_s": 842.0, "level": 12, "character": "ardent"}}}})
	Platform.set_input_mode(Platform.InputMode.KBM)

	var t := TITLE.instantiate() as TitleScreen
	t.summary_provider = func() -> Dictionary: return {}
	add_child(t)
	await _frames(20)
	await _shot("title")
	t.queue_free()
	await _frames(3)

	var a := ACH.instantiate() as AchievementsScreen
	add_child(a)
	await _frames(10)
	await _shot("achievements")
	a.queue_free()
	await _frames(3)

	var d := DAILY.instantiate() as DailyScreen
	add_child(d)
	await _frames(10)
	await _shot("daily")
	d.queue_free()
	await _frames(3)

	# bulle de didacticiel + notification, sur un fond uni
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgl := CanvasLayer.new()
	bgl.layer = -1
	bgl.add_child(bg)
	add_child(bgl)
	RunState.running = true
	var h: CanvasLayer = HINTS.new()
	add_child(h)
	await _frames(3)
	h.call("_end")
	await _frames(20)
	h.call("trigger", "aim")
	await _frames(60)
	await _shot("hint_aim")
	var tracker := MetaTracker.new()
	add_child(tracker)
	await _frames(2)
	tracker.toast.push("Succès débloqué", "Averse de lames", Achievements.icon_of(Achievements.def_of("kills_1000")))
	await _frames(40)
	await _shot("toast")
	RunState.running = false
	Profile.reset()
	get_tree().quit()
