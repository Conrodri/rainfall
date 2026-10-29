extends Node
## Capture (SANS --headless) des télégraphes de boss en arène de test : zone lourde proche de l'impact
## ("heavy") et coup léger armé sans zone ("light"). Un cliché max de chaque par boss.
## godot --path game res://tests/capture_telegraphs.tscn -- --out=<dossier> --bosses=sonneur,eclusier [--strong]
## --strong : réglage « Télégraphes renforcés » (ancien affichage complet, tous les coups).

var _out := ""
var _bosses: PackedStringArray = ["sonneur"]
var _strong := false
var _tag := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--bosses="):
			_bosses = a.substr(9).split(",")
		elif a == "--strong":
			_strong = true
	_tag = "strong" if _strong else "lite"
	EnemyTelegraph.strong_override = 1 if _strong else 0
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	TestMode.begin()
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	add_child(m)
	await m.game_ready
	await _f(30)
	TestMode.set_difficulty(4.0)
	TestMode.set_flag(&"god", true)
	var player := m.get(&"player") as Node2D
	for id in _bosses:
		TestTools.clean(get_tree())
		await _f(10)
		var b := TestTools.spawn_boss(get_tree(), StringName(id), &"etage", player.global_position + Vector2(4.0, 0.0) * 64.0)
		if b == null:
			print("boss introuvable ", id)
			continue
		var got_heavy := 0
		var got_light := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 30000 and (got_heavy < 2 or got_light < 1):
			await get_tree().process_frame
			if not is_instance_valid(b):
				break
			var showing: Array[EnemyTelegraph] = []
			for n in get_tree().get_nodes_in_group(&"enemy_telegraphs"):
				var t := n as EnemyTelegraph
				if t != null and t.is_showing():
					showing.append(t)
			var vis: Variant = b.get(&"visual")
			var attacking: bool = vis != null and vis.call(&"is_attacking")
			if not showing.is_empty() and got_heavy < 2:
				var k: float = (showing[0]._fill.scale.x)
				if k >= 0.78:
					got_heavy += 1
					await _shot("%s_%s_heavy%d" % [id, _tag, got_heavy])
					await get_tree().create_timer(2.5).timeout
			elif showing.is_empty() and attacking and got_light < 1 and vis.call(&"strike_lag") > -0.12:
				got_light += 1
				await _shot("%s_%s_light" % [id, _tag])
	TestTools.clean(get_tree())
	get_tree().quit()


func _shot(name: String) -> void:
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/%s.png" % [_out, name])
		print("shot ", name)
