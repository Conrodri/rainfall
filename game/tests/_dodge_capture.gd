extends Node
## Captures des esquives en fenêtre réelle (SANS --headless) : mode test, un personnage après l'autre, 2 clichés
## par esquive (en cours, puis juste après). Vérification visuelle (marques, traces, fantômes).
## godot --path game res://tests/_dodge_capture.tscn -- --out=<dossier>

const SHOTS := [
	[&"ardent", "eclat", 4, 14],
	[&"averse", "glissade", 20, 40],
	[&"vigie", "repli", 3, 9],
	[&"bourbe", "coulee", 10, 24],
	[&"avare", "rafle", 8, 18],
	[&"tocsin", "vapeur", 6, 16],
]

var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	TestMode.begin()
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	add_child(m)
	await m.game_ready
	await _f(30)
	TestMode.set_flag(&"cdr_full", true)
	TestMode.set_flag(&"full_resource", true)
	var player: CharacterBody2D = m.get(&"player")
	var home: Vector2 = player.global_position
	for s in SHOTS:
		TestTools.switch_character(get_tree(), s[0])
		await _f(10)
		player.global_position = home
		player.facing = Vector2.RIGHT
		await _f(4)
		var dir := Vector2(1, 0.5).normalized() if s[0] != &"vigie" else Vector2.LEFT
		if s[0] == &"averse":
			Input.action_press(&"dodge") # maintien
		else:
			player.dodge(dir)
		await _f(int(s[2]))
		if s[0] == &"vigie":
			player.dodge(Vector2(0, 1))
			await _f(2)
			player.dodge(Vector2(1, 0))
		print("%s dodging=%s invuln=%s pos=%s" % [s[0], player.is_dodging(), player.is_invulnerable(), player.global_position])
		if _out != "":
			CaptureUtil.save_viewport(get_viewport(), "%s/dodge_%s_a.png" % [_out, s[1]])
		await _f(int(s[3]))
		if s[0] == &"averse":
			Input.action_release(&"dodge")
			await _f(6)
		if _out != "":
			CaptureUtil.save_viewport(get_viewport(), "%s/dodge_%s_b.png" % [_out, s[1]])
		print("%s end pos=%s" % [s[0], player.global_position])
		await _f(40)
	get_tree().quit()
