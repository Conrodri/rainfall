extends Node
## Lot M-D (docs/ux/Audit_Menus.md M4, M14, M15) : menu pause.
## - tous les boutons dans le cadre (PC 1920x1080, mobile 2400x1080 tactile, 1440x1080), même avec 2 lignes d'info ;
## - ordre : Reprendre (pleine largeur) puis Objets, Réglages, Commandes, Sauvegarder et quitter, Abandonner, [Quitter le jeu] ;
## - Objets en grille de cases 96 px triée par qualité, détail au focus, navigation manette câblée ;
## - compte à rebours : 3 s si danger proche (monstre < 6 u, projectile < 8 u, boss actif), 1 s sinon.
## godot --headless --path game res://tests/pause_menu_test.tscn  -> « RESULT: OK »

const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1440, 1080)]
const ORDER := ["Objets", "Réglages", "Commandes", "Sauvegarder et quitter", "Abandonner", "Quitter le jeu"]

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var saved_items: Dictionary = RunState.items.duplicate()
	var saved_mode := Platform.input_mode
	for mode in [Platform.InputMode.TOUCH, Platform.InputMode.KBM]:
		Platform.set_input_mode(mode)
		for vs in SIZES:
			await _test_layout(vs, mode)
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	await _test_items(Vector2(2400, 1080))
	await _test_items(Vector2(1920, 1080))
	_test_danger()
	RunState.items = saved_items
	Platform.set_input_mode(saved_mode)
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _spawn(vs: Vector2) -> Array:
	var svp := SubViewport.new()
	svp.size = Vector2i(vs)
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(svp)
	var pm := PauseMenu.new()
	svp.add_child(pm)
	return [svp, pm]


func _close_all(svp: SubViewport, pm: PauseMenu) -> void:
	if pm.is_open:
		pm._close()
	svp.queue_free()


func _test_layout(vs: Vector2, mode: int) -> void:
	var tag := "%dx%d %s" % [int(vs.x), int(vs.y), "tactile" if mode == Platform.InputMode.TOUCH else "souris"]
	var made := _spawn(vs)
	var svp: SubViewport = made[0]
	var pm: PauseMenu = made[1]
	await _frames(2)
	pm.open()
	pm._info.text += "\nPV +1,5/s  ·  Eau +3,5/s" # pire cas : 2e ligne de régénération
	pm._apply_layout()
	await _frames(4)
	var frame := Rect2(pm._holder.global_position, pm._holder.size)
	_check(frame.size.x > 100.0 and frame.size.y > 100.0, "%s : cadre non vide" % tag)
	_check(Rect2(Vector2.ZERO, vs).encloses(frame), "%s : cadre dans l'écran (%s)" % [tag, str(frame)])
	var names: Array[String] = []
	var all: Array[Button] = [pm._resume_button]
	for c in pm._grid.get_children():
		all.append(c as Button)
	for b in all:
		var r := Rect2(b.global_position, b.size)
		_check(frame.grow(1.0).encloses(r), "%s : « %s » dans le cadre (%s / %s)" % [tag, b.text, str(r), str(frame)])
		if b != pm._resume_button:
			names.append(b.text.split(" (")[0])
	var want: Array = ORDER.duplicate()
	if not Platform.can_quit():
		want.erase("Quitter le jeu")
	_check(names == want, "%s : ordre des boutons %s" % [tag, str(names)])
	_check((pm._quit_button != null) == Platform.can_quit(), "%s : Quitter le jeu absent sur iOS seulement" % tag)
	var grid_w: float = pm._grid.size.x
	_check(absf(pm._resume_button.size.x - grid_w) < 2.0, "%s : Reprendre pleine largeur (%.0f / %.0f)" % [tag, pm._resume_button.size.x, grid_w])
	_check(pm._resume_button.get_global_rect().end.y <= pm._grid.get_global_rect().position.y + 1.0, "%s : Reprendre au-dessus de la grille" % tag)
	_check(pm._hint.visible == (mode != Platform.InputMode.TOUCH), "%s : aide masquée au tactile" % tag)
	_close_all(svp, pm)
	await _frames(1)


func _test_items(vs: Vector2) -> void:
	var tag := "objets %dx%d manette" % [int(vs.x), int(vs.y)]
	var ids: Array = ItemDB.all_ids()
	RunState.items = {}
	for i in mini(ids.size(), 14):
		RunState.items[ids[i]] = 3 if i == 0 else 1
	var made := _spawn(vs)
	var svp: SubViewport = made[0]
	var pm: PauseMenu = made[1]
	await _frames(2)
	pm.open()
	pm._fill_items()
	pm._show_only(pm._panel_items)
	await _frames(6)
	var n: int = RunState.items.size()
	var cells: Array[Button] = pm._item_cells
	_check(n >= 4 and cells.size() == n, "%s : une case par objet (%d / %d)" % [tag, cells.size(), n])
	_check(pm.items_texts().size() == n, "%s : items_texts() = %d lignes" % [tag, pm.items_texts().size()])
	var cols: int = pm._items_box.columns
	_check(cols >= PauseMenu.ITEM_COLS_MIN and cols <= PauseMenu.ITEM_COLS_MAX, "%s : %d colonnes" % [tag, cols])
	if n > cols:
		_check(is_equal_approx(cells[0].global_position.y, cells[cols - 1].global_position.y) and cells[cols].global_position.y > cells[0].global_position.y, "%s : cases en grille (lignes de %d)" % [tag, cols])
	var s: float = pm._scale()
	for c in cells:
		_check(c.size.x >= PauseMenu.ITEM_CELL_PX * s - 1.0 and c.size.y >= PauseMenu.ITEM_CELL_PX * s - 1.0, "%s : case >= 96 px mise à l'échelle" % tag)
	var last_rank := -1
	var sorted_ok := true
	for i in n:
		cells[i].focus_entered.emit() # met à jour le détail : on y lit l'objet de la case
		var name_txt: String = pm._detail_name.text
		var rank := -1
		for id in RunState.items:
			if name_txt.begins_with(str(ItemDB.get_item(id).get("name", id))):
				rank = pm._quality_rank(id)
				break
		if rank < last_rank:
			sorted_ok = false
		last_rank = maxi(rank, last_rank)
	_check(sorted_ok, "%s : tri par qualité (légendaire en tête)" % tag)
	cells[1].grab_focus()
	await _frames(2)
	_check(svp.gui_get_focus_owner() == cells[1], "%s : focus sur la case 1" % tag)
	var has_word := false
	for w in ["Commun", "Peu commun", "Rare", "Légendaire"]:
		has_word = has_word or pm._detail_name.text.contains(w)
	_check(pm._detail_name.text != "" and has_word, "%s : détail = nom + rareté (« %s »)" % [tag, pm._detail_name.text])
	_check(pm._detail_effect.text != "", "%s : détail = effet" % tag)
	var fs: StyleBox = cells[0].get_theme_stylebox(&"focus")
	_check(fs is StyleBoxFlat and (fs as StyleBoxFlat).border_width_left >= 3, "%s : cadre de focus visible (>= 3 px)" % tag)
	_check(cells[0].get_node(cells[0].focus_neighbor_right) == cells[1], "%s : droite de 0 = 1" % tag)
	if n > cols:
		_check(cells[0].get_node(cells[0].focus_neighbor_bottom) == cells[cols], "%s : bas de 0 = case %d" % [tag, cols])
	_check(cells[n - 1].get_node(cells[n - 1].focus_neighbor_bottom) == pm._items_back, "%s : bas de la dernière case = Retour" % tag)
	_check(pm._items_back.get_node(pm._items_back.focus_neighbor_top) == cells[n - 1], "%s : haut de Retour = dernière case" % tag)
	var frame := Rect2(pm._holder.global_position, pm._holder.size)
	for c in [pm._items_scroll, pm._detail_effect, pm._items_back]:
		_check(frame.grow(1.0).encloses((c as Control).get_global_rect()), "%s : %s dans le cadre" % [tag, (c as Control).name])
	RunState.items = {}
	pm._fill_items()
	_check(pm.items_texts() == ["Aucun objet pour l'instant."], "%s : liste vide" % tag)
	_close_all(svp, pm)
	await _frames(1)


func _test_danger() -> void:
	var made := _spawn(Vector2(1920, 1080))
	var svp: SubViewport = made[0]
	var pm: PauseMenu = made[1]
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var calm := Balance.RESUME_COUNTDOWN_CALM_S
	var danger := Balance.RESUME_COUNTDOWN_DANGER_S
	_check(is_equal_approx(calm, 1.0) and is_equal_approx(danger, 3.0), "durées 1 s / 3 s")
	_check(is_equal_approx(pm.resume_duration(), calm), "rien autour : 1 s")
	var m := Node2D.new()
	m.add_to_group(&"enemies")
	add_child(m)
	m.global_position = Vector2(Balance.RESUME_DANGER_MONSTER_U * Balance.UNIT_PX * 0.8, 0)
	_check(is_equal_approx(pm.resume_duration(), danger), "monstre à < 6 u : 3 s")
	m.global_position = Vector2(Balance.RESUME_DANGER_MONSTER_U * Balance.UNIT_PX * 1.2, 0)
	_check(is_equal_approx(pm.resume_duration(), calm), "monstre à > 6 u : 1 s")
	var boss := Node2D.new()
	boss.add_to_group(&"bosses")
	add_child(boss)
	boss.global_position = Vector2(5000, 0)
	_check(is_equal_approx(pm.resume_duration(), danger), "boss actif (même loin) : 3 s")
	boss.remove_from_group(&"bosses")
	boss.queue_free()
	var pool := EnemyProjectilePool.new()
	pool.name = &"EnemyProjectiles"
	add_child(pool)
	pool.prewarm(4)
	var far := Balance.RESUME_DANGER_PROJECTILE_U * Balance.UNIT_PX * 1.3
	var near := Balance.RESUME_DANGER_PROJECTILE_U * Balance.UNIT_PX * 0.7
	var p := pool.fire(null, Vector2(far, 0), Vector2.ZERO, 1.0)
	_check(is_equal_approx(pm.resume_duration(), calm), "projectile à > 8 u : 1 s")
	p.position = Vector2(near, 0)
	_check(is_equal_approx(pm.resume_duration(), danger), "projectile à < 8 u : 3 s")
	pool.clear_all()
	_check(is_equal_approx(pm.resume_duration(), calm), "projectile libéré : 1 s")
	pm._on_resume()
	_check(is_equal_approx(pm._count, calm) and pm.counting_down, "_on_resume : compte à rebours de 1 s")
	pm.counting_down = false
	m.remove_from_group(&"enemies")
	m.queue_free()
	player.queue_free()
	pool.queue_free()
	svp.queue_free()
