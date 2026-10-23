extends Node
## godot --headless --path game res://tests/interact_dispatch_test.tscn
## Lot L1 (audit Choix) : répartiteur d'interaction unique du HUD. Un appui n'agit que sur la cible de
## l'invite ; maintien de 0,6 s du téléporteur ; pilier verrouillé grisé avec raison ; refus d'achat écrit.

class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var pickup_radius := 200.0
	func get_spell_cooldowns() -> Array:
		return []


class Fake extends Node2D:
	var prio := 0
	var hold := 0.0
	var is_enabled := true
	var label := "Fake"
	var calls := 0
	func can_interact() -> bool:
		return true
	func interact_label() -> String:
		return label
	func interact_state() -> Dictionary:
		return {"visible": true, "enabled": is_enabled, "label": label, "hold_s": hold}
	func interact_priority() -> int:
		return prio
	func interact() -> bool:
		calls += 1
		return true


var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


## Appui d'une image (pattern : press dans l'image N, le HUD le voit dans la même image).
func _tap() -> void:
	await get_tree().process_frame
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().process_frame


func _hold_for(seconds: float) -> void:
	await get_tree().process_frame
	Input.action_press("interact")
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("interact")
	await get_tree().process_frame


func _ready() -> void:
	Platform.input_mode = Platform.InputMode.KBM
	var player := FakePlayer.new()
	player.add_to_group("player")
	add_child(player)
	var hud = load("res://scripts/ui/hud.gd").new()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 1. Deux interactables qui se chevauchent : un seul agit (celui de l'invite)
	var a := Fake.new()
	a.prio = 3
	a.label = "Coffre"
	a.position = Vector2(50, 0)
	a.add_to_group("interactable")
	add_child(a)
	var b := Fake.new()
	b.prio = 0
	b.hold = 0.6
	b.label = "Partir"
	b.position = Vector2(60, 0)
	b.add_to_group("interactable")
	add_child(b)
	await get_tree().process_frame
	_check(hud.interact_target == a, "cible = le coffre (priorité à ±16 px)")
	await _tap()
	_check(a.calls == 1 and b.calls == 0, "un appui = un seul objet (a=%d b=%d)" % [a.calls, b.calls])

	# la plus proche gagne hors égalité
	a.position = Vector2(300, 0)
	await get_tree().process_frame
	_check(hud.interact_target == b, "plus proche à > 16 px : le téléporteur")

	# --- 2. Maintien de 0,6 s
	await _tap()
	_check(b.calls == 0, "appui bref : le téléporteur ne part pas")
	await _hold_for(0.25)
	_check(b.calls == 0, "maintien 0,25 s : pas encore")
	await _hold_for(0.9)
	_check(b.calls == 1, "maintien > 0,6 s : un départ exactement (b=%d)" % b.calls)
	_check(hud.interact_button.hold_s > 0.5, "bouton : anneau de maintien actif")

	# --- 3. Désactivé : grisé, raison écrite, rien ne se passe
	b.is_enabled = false
	b.label = "Verrouillé — petits piliers 1/2"
	await get_tree().process_frame
	await _tap()
	_check(b.calls == 1, "désactivé : interact() jamais appelé")
	_check(not hud.interact_button.enabled, "bouton grisé")
	_check(hud._prompt_label.text.begins_with("Verrouillé"), "invite : raison écrite (%s)" % hud._prompt_label.text)
	a.queue_free()
	b.queue_free()
	await get_tree().process_frame

	# --- 4. Vrais objets
	var pil := Pillar.new()
	pil.setup(Pillar.Kind.BIG, 3, true)
	pil._player_touching = true
	var ps: Dictionary = pil.interact_state()
	_check(bool(ps["visible"]) and not bool(ps["enabled"]), "pilier verrouillé : visible et grisé")
	_check(str(ps["label"]).begins_with("Verrouillé"), "pilier verrouillé : raison")
	_check(not pil.interact(), "pilier verrouillé : interact() sans effet")
	pil.free()

	var tp := ExitTeleporter.new()
	add_child(tp)
	tp.set_active(true)
	tp._player_on = true
	var ts: Dictionary = tp.interact_state()
	_check(is_equal_approx(float(ts["hold_s"]), 0.6), "téléporteur : maintien 0,6 s")
	tp.queue_free()

	var chest := (load("res://scenes/chests/chest.tscn") as PackedScene).instantiate() as Chest
	chest.setup(&"petit", 1)
	add_child(chest)
	chest._player_inside = true
	RunState.gold = 0.0
	var cs: Dictionary = chest.interact_state()
	_check(str(cs["label"]).begins_with("Il manque"), "refus d'achat écrit : " + str(cs["label"]))
	_check(chest._label.text.contains("(-") and chest._label.get_line_count() == 1, "prix du coffre : manque chiffré sur une ligne (%s)" % chest._label.text)
	_check(not chest.interact(), "coffre trop cher : interact() refuse")
	chest.queue_free()

	# --- 5. Plus aucun objet ne lit l'entrée lui-même
	for p in ["res://scripts/loot/chest.gd", "res://scripts/loot/gold_capsule.gd", "res://scripts/stage/exit_teleporter.gd", "res://scripts/stage/pillar.gd"]:
		var src := FileAccess.get_file_as_string(p)
		_check(not src.contains("is_action_just_pressed"), p + " ne lit plus l'entrée")
	_check(StageManager.TELEPORTER_OFFSET.length() >= 300.0, "TELEPORTER_OFFSET >= 300 px")

	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
