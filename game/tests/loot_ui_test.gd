extends Node
## Test d'intégration coffre + UI (scène : autoloads requis).
## godot --headless --path game res://tests/loot_ui_test.tscn   (RESULT: OK)

class FakePlayer extends Node2D:
	var got := {}
	func apply_stats(s: Dictionary) -> void:
		got = s

var _fails := 0


func _check(label: String, cond: bool) -> void:
	if cond:
		print("ok   ", label)
	else:
		_fails += 1
		print("FAIL ", label)


func _ready() -> void:
	ItemDB.reload()
	RunState.start_run(&"moyen", 777)
	ChestSession.reset_run_counters()
	var player := FakePlayer.new()
	player.add_to_group("player")
	add_child(player)
	var chest: Chest = load("res://scenes/chests/chest.tscn").instantiate()
	add_child(chest)
	chest.setup(&"petit", 1)
	await get_tree().process_frame
	_check("groupes chests+interactable", chest.is_in_group("chests") and chest.is_in_group("interactable"))
	_check("label d interaction", chest.interact_label().begins_with("Ouvrir"))
	_check("prix > 0 affiché", chest.get_node("PriceLabel").text.contains(" or"))
	_check("or insuffisant : refus", not chest.try_open())
	var boss: Chest = load("res://scenes/chests/chest.tscn").instantiate()
	add_child(boss)
	boss.setup(&"boss", 1)
	await get_tree().process_frame
	_check("boss gratuit", boss.get_node("PriceLabel").text == "GRATUIT")
	boss.queue_free()
	RunState.add_gold(5000.0)
	var gold0 := RunState.gold
	var opened_signal := [false]
	Events.chest_opened.connect(func(_c, _q, _o): opened_signal[0] = true)
	_check("ouverture avec or", chest.try_open())
	_check("or dépensé", RunState.gold < gold0)
	await get_tree().process_frame
	_check("arbre en pause", get_tree().paused)
	var ui: ChestUI = null
	for c in get_tree().current_scene.get_children():
		if c is ChestUI:
			ui = c
	_check("UI présente", ui != null)
	var t := 0.0
	while ui._busy and t < 15.0:
		await get_tree().create_timer(0.1, true).timeout
		t += 0.1
	_check("animation terminée", not ui._busy)
	_check("événement chest_opened", opened_signal[0])
	_check("2 cartes remplies", ui.session.offered.size() == 2)
	_check("cartes visibles", ui._card_front[0].visible and ui._card_front[1].visible)
	_check("boutons >= 48 dp (150 px)", ui._gold_btn.custom_minimum_size.y >= 96.0)
	ui._on_gold_reroll()
	t = 0.0
	while ui._busy and t < 10.0:
		await get_tree().create_timer(0.1, true).timeout
		t += 0.1
	_check("relance or terminée", not ui._busy and ui._card_front[0].visible)
	var chosen: String = ui.session.offered[1]
	var chosen_sig := [""]
	Events.item_chosen.connect(func(id): chosen_sig[0] = str(id))
	ui._on_choose(1)
	await get_tree().process_frame
	_check("item ajouté", RunState.stacks(StringName(chosen)) == 1)
	_check("item_chosen émis", chosen_sig[0] == chosen)
	_check("apply_stats appelé", player.got.has("procs"))
	_check("arbre repris", not get_tree().paused)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("coffre libéré", not is_instance_valid(chest))
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
