extends Node
## Invites de 1re run (lot M-A, docs/ux/Audit_Menus.md §3.1) : profil vierge -> 1re invite visible ; runs >= 1 -> aucune.
## godot --headless --path game res://tests/onboarding_test.tscn
## Profil : autoload en mémoire (jamais écrit en headless), relu à la fin. Réglages : fichier injecté.

const HINTS := preload("res://scripts/ui/onboarding_hints.gd")
const CFG := "user://onboarding_test_settings.cfg"

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _new_main() -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 4242)
	add_child(m)
	await m.game_ready
	return m


func _overlaps(h: Node, hud: Hud) -> bool:
	var r: Rect2 = h.bubble_rect()
	for rr in hud.reserved_rects():
		if r.intersects(rr):
			return true
	return false


func _ready() -> void:
	var old_cfg := GameSettings.cfg_path
	Profile.write_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = CFG
	GameSettings.set_value("gameplay", "help_shown", true) # pas d'aide centrale de 8 s : l'invite « move » sort tout de suite
	Platform.set_input_mode(Platform.InputMode.KBM)

	# --- unitaire : activation ---
	Profile.reset()
	_check(HINTS.should_run(), "profil vierge + réglage par défaut -> invites actives")
	GameSettings.set_value("gameplay", "hints", false)
	_check(not HINTS.should_run(), "réglage « Astuces de jeu » coupé -> inactives")
	GameSettings.set_value("gameplay", "hints", true)
	Profile.stats["runs"] = 1
	_check(not HINTS.should_run(), "runs >= 1 -> inactives")
	Profile.reset()
	# placement : jamais sur une zone réservée, toujours dans l'écran
	var vp := Vector2(1920, 1080)
	var sz := Vector2(700, 90)
	var res: Array = [Rect2(560, 300, 800, 200)]
	var p: Vector2 = HINTS.place(Vector2(610, 350), sz, vp, res)
	_check(not Rect2(p, sz).intersects(res[0]) and Rect2(Vector2.ZERO, vp).encloses(Rect2(p, sz)), "place() évite la zone réservée (%s)" % p)
	p = HINTS.place(Vector2(-200, -50), sz, vp, [])
	_check(p.x >= 16.0 and p.y >= 16.0, "place() reste à 16 px du bord")
	for id in HINTS.SEQUENCE:
		for mode in [Platform.InputMode.TOUCH, Platform.InputMode.KBM, Platform.InputMode.GAMEPAD]:
			if String(HINTS.content(id, mode)[1]) == "":
				_check(false, "texte de %s (mode %d)" % [id, mode])

	# --- partie réelle, profil vierge ---
	var main := await _new_main()
	await _wait(0.4)
	var h: Node = main.get_node_or_null(HINTS.NODE_NAME)
	_check(h != null, "nœud OnboardingHints posé par Main")
	if h != null:
		var hud: Hud = main.hud
		_check(h.current == "move" and h.bubble.visible, "1re invite visible : déplacement (%s)" % h.current)
		_check(String(h.label.text).contains("ZQSD"), "texte clavier : %s" % h.label.text)
		_check(h.font_px() >= HudMetrics.FLOOR_PC and h.font_px() >= 32, "police %d px >= 32 (plancher 18)" % h.font_px())
		_check(not _overlaps(h, hud), "bulle hors des zones du HUD")
		_check(h.layer > hud.layer and h.layer < 100, "couche entre HUD et pause")
		var pl: Node2D = main.player
		pl.global_position += Vector2(MOVE_PX(), 0)
		await _wait(0.2)
		_check(h.current == "" and Profile.has_seen_hint("move"), "invite déplacement finie après 2 u")
		h.trigger("move")
		_check(h._queue.is_empty(), "invite vue : jamais remontrée")
		h.trigger("auto_fire")
		await _wait(0.6)
		_check(h.current == "auto_fire", "1er kill -> invite sort automatique")
		_check(String(h.detail.text).contains("sort 1"), "ligne d'astuce issue de tips.json : %s" % h.detail.text)
		_check(h.detail_font_px() >= HudMetrics.FLOOR_PC, "astuce >= 18 px")
		await _wait(HINTS.MAX_S + 0.3)
		_check(h.current == "", "invite retirée après 6 s max")
		# boss présent : invite suspendue
		var fake := Node.new()
		fake.add_to_group(&"bosses")
		add_child(fake)
		h.trigger("dodge")
		await _wait(0.5)
		_check(h.current == "" and h.blocked(), "pas d'invite pendant un combat de boss")
		fake.queue_free()
		await _wait(0.5)
		_check(h.current == "dodge" and h.prompt.visible and h.prompt.text() != "", "roulade après le boss, invite de touche %s" % h.prompt.text())
		# mobile : plancher 26 px et texte tactile
		Platform.mobile_preview = true
		Platform.set_input_mode(Platform.InputMode.TOUCH)
		await _wait(0.3)
		_check(h.font_px() >= HudMetrics.FLOOR_MOBILE and h.detail_font_px() >= HudMetrics.FLOOR_MOBILE, "mobile : %d / %d px >= 26" % [h.font_px(), h.detail_font_px()])
		_check(String(h.label.text).contains("Bouton Roulade") and not h.prompt.visible, "texte tactile : %s" % h.label.text)
		_check(not _overlaps(h, hud), "mobile : bulle hors des zones du HUD")
		Platform.mobile_preview = false
		Platform.set_input_mode(Platform.InputMode.KBM)
		Events.floor_cleared.emit(1)
		_check(h._queue.any(func(q: Array) -> bool: return q[0] == "teleporter"), "étage nettoyé -> invite téléporteur en file")
	main.queue_free()
	await _wait(0.3)

	# --- profil runs >= 1 : aucune invite ---
	Profile.reset()
	Profile.stats["runs"] = 1
	main = await _new_main()
	await _wait(0.3)
	_check(main.get_node_or_null(HINTS.NODE_NAME) == null, "runs >= 1 : aucune invite")
	main.queue_free()
	await _wait(0.2)

	GameSettings.cfg_path = old_cfg
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	Profile.load_profile()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func MOVE_PX() -> float:
	return (HINTS.MOVE_DONE_U + 0.5) * Balance.UNIT_PX
