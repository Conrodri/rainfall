extends Node
## Didacticiel de 1re run (extension de OnboardingHints) : nouvelles invites (or, visée des sorts, charge du pilier),
## textes par plateforme, disparition au geste, « Revoir le didacticiel » (Profile.tutorial_replay).
## godot --headless --path game res://tests/tutorial_test.tscn
## Profil = autoload en mémoire (jamais écrit en headless) ; réglages : fichier injecté.

const HINTS := preload("res://scripts/ui/onboarding_hints.gd")
const CFG := "user://tutorial_test_settings.cfg"

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


class FakePillar extends Node2D:
	var kind := 1 # Pillar.Kind.BIG


func _ready() -> void:
	var old_cfg := GameSettings.cfg_path
	Profile.write_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = CFG
	Platform.set_input_mode(Platform.InputMode.KBM)
	Profile.reset()

	# --- séquence et textes ---
	for id in ["move", "auto_fire", "gold", "aim", "interact", "pillar", "charge", "teleporter", "dodge"]:
		_check(HINTS.SEQUENCE.has(id), "séquence contient %s" % id)
	var modes := [Platform.InputMode.TOUCH, Platform.InputMode.KBM, Platform.InputMode.GAMEPAD]
	var texts_ok := true
	for id in HINTS.SEQUENCE:
		for m in modes:
			var c: Array = HINTS.content(id, m)
			if String(c[1]) == "" or String(c[1]).length() > 90:
				texts_ok = false
				print("  texte absent ou trop long : ", id, " mode ", m)
	_check(texts_ok, "chaque invite a un texte court dans les 3 modes d'entrée")
	var aim_touch := String(HINTS.content("aim", Platform.InputMode.TOUCH)[1])
	var aim_pc := String(HINTS.content("aim", Platform.InputMode.KBM)[1])
	var aim_pad := String(HINTS.content("aim", Platform.InputMode.GAMEPAD)[1])
	_check(aim_touch != aim_pc and aim_pc != aim_pad and aim_pc.contains("curseur") and aim_pad.contains("stick droit") and aim_touch.contains("tout seuls"),
		"visée : curseur (PC), stick droit (manette), auto (tactile)")
	_check(String(HINTS.content("move", Platform.InputMode.TOUCH)[1]).contains("doigt") and String(HINTS.content("move", Platform.InputMode.KBM)[1]).contains("ZQSD")
		and String(HINTS.content("move", Platform.InputMode.GAMEPAD)[1]).contains("Stick"), "déplacement : doigt / ZQSD / stick")
	_check(String(HINTS.content("aim", Platform.InputMode.KBM)[0]) == "spell_2", "invite de touche (sort 2) affichée au clavier-souris")

	# --- activation et rejeu ---
	_check(HINTS.should_run(), "profil vierge : actif")
	Profile.stats["runs"] = 3
	_check(not HINTS.should_run(), "après des runs : inactif")
	HINTS.request_replay()
	_check(Profile.tutorial_replay and HINTS.should_run(), "« Revoir le didacticiel » : actif même après des runs")
	Profile.seen_hints = ["move", "gold"]
	HINTS.request_replay()
	_check(Profile.seen_hints.is_empty(), "le rejeu oublie les invites vues")
	GameSettings.set_value("gameplay", "hints", false)
	_check(HINTS.should_run(), "le rejeu passe outre le réglage « Astuces de jeu »")
	GameSettings.set_value("gameplay", "hints", true)
	var holder := Node.new()
	add_child(holder)
	var h: CanvasLayer = HINTS.attach(holder, null)
	_check(h != null and not Profile.tutorial_replay and not HINTS.should_run(), "branchement : un seul rejeu consommé")
	h.queue_free()
	holder.queue_free()
	await _frames(2)
	var old_json := JSON.stringify(Profile.to_dict())
	var snap: Dictionary = JSON.parse_string(old_json)
	Profile.reset()
	Profile._apply_dict(snap)
	_check(not Profile.tutorial_replay, "drapeau de rejeu sauvegardé (faux après consommation)")
	Profile.request_tutorial_replay()
	snap = JSON.parse_string(JSON.stringify(Profile.to_dict()))
	Profile.reset()
	Profile._apply_dict(snap)
	_check(Profile.tutorial_replay, "drapeau de rejeu rechargé du profil")

	# --- comportement des invites (nœud seul, sans scène de jeu) ---
	Profile.reset()
	RunState.running = true
	var n: CanvasLayer = HINTS.new()
	add_child(n)
	await _frames(3)
	# « move » est déjà affichée à t = 0 : on la consomme
	n.call("_end")
	await _frames(2)
	# or : 1er kill -> gold en file ; geste = ramasser
	n.call("trigger", "gold")
	await _frames(3)
	_check(n.get("current") == "gold" and (n.get("bubble") as Control).visible, "invite or affichée")
	Events.pickup_collected.emit(&"gold", 3.0)
	_check(n.get("current") == "" and Profile.has_seen_hint("gold"), "invite or disparaît au 1er ramassage")
	# or ramassé avant l'affichage : jamais montrée
	Profile.seen_hints.erase("gold")
	n.call("trigger", "gold")
	Events.pickup_collected.emit(&"gold", 1.0)
	await _frames(3)
	_check(n.get("current") == "" and Profile.has_seen_hint("gold"), "or déjà ramassé : l'invite est consommée sans s'afficher")
	# visée : s'affiche, disparaît au 1er lancer de sort
	n.call("trigger", "aim")
	await _frames(3)
	_check(n.get("current") == "aim", "invite visée affichée")
	Input.action_press(&"spell_2")
	await _frames(2)
	Input.action_release(&"spell_2")
	_check(n.get("current") != "aim" and Profile.has_seen_hint("aim"), "invite visée disparaît au lancer d'un sort")
	# charge : gros pilier activé, bloquée par aucun boss, finie quand la charge démarre
	var boss := Node2D.new()
	boss.add_to_group(&"bosses")
	add_child(boss)
	var pil := FakePillar.new()
	add_child(pil)
	Events.pillar_state_changed.emit(pil, &"active")
	await _frames(3)
	_check(n.get("current") == "charge", "invite charge affichée malgré le boss qui apparaît")
	Events.pillar_charge_progress.emit(pil, 0.01)
	_check(n.get("current") == "charge", "charge à 1 % : encore là")
	Events.pillar_charge_progress.emit(pil, 0.2)
	_check(n.get("current") == "" and Profile.has_seen_hint("charge"), "invite charge disparaît quand la charge avance")
	# petit pilier : pas d'invite de charge
	Profile.seen_hints.erase("charge")
	pil.kind = 0
	Events.pillar_state_changed.emit(pil, &"active")
	await _frames(3)
	_check(n.get("current") != "charge", "petit pilier : pas de charge")
	boss.queue_free()
	pil.queue_free()
	n.queue_free()

	RunState.running = false
	GameSettings.cfg_path = old_cfg
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	Profile.reset()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
