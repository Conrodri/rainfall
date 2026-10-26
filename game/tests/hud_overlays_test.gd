extends Node
## HUD : minimap, inventaire des items, barres de vie des monstres, barre de boss, liste du menu pause.
## godot --headless --path game res://tests/hud_overlays_test.tscn
## Sur la vraie scène de jeu (scenes/main.tscn), clavier-souris puis tactile.

var _fails := 0


class FakeCapsule extends Area2D:
	var ok := true
	func can_interact() -> bool:
		return ok

var _main: Node


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


## Couleurs RGBA8 : quantification à 1/255.
static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 777)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	await _wait(0.3)
	var hud: Hud = _main.hud
	var stage: StageManager = _main.stage
	var director: Director = _main.director
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)
	director.spawning_enabled = false
	director.despawn_all()

	# --- Minimap : une image par étage, aux dimensions de la grille
	# or : un gros montant reste à gauche du bouton pause (rangée calée à droite)
	var gold0: float = RunState.gold
	RunState.gold = 1234567.0
	RunState.gold_changed.emit(RunState.gold)
	await _frames(2)
	_check(hud._gold_box.get_global_rect().end.x <= hud.pause_button.get_global_rect().position.x, "or (7 chiffres) à gauche du bouton pause")
	RunState.gold = gold0
	RunState.gold_changed.emit(gold0)
	var mm := hud.minimap
	var grid: Array = Minimap.map_json(stage.map_id).get("grid", [])
	_check(mm.visible and mm.map_texture != null, "minimap visible avec sa texture")
	_check(mm.build_count == 1, "image construite une fois (%d)" % mm.build_count)
	_check(mm.map_texture != null and mm.map_texture.get_height() == grid.size() * Minimap.IMG_K, "image = grille × %d px" % Minimap.IMG_K)
	var img := mm.map_image
	var wall_px := 0
	var water_px := 0
	for y in grid.size():
		for x in String(grid[y]).length():
			var c := img.get_pixel(x * Minimap.IMG_K + Minimap.IMG_K / 2, y * Minimap.IMG_K + Minimap.IMG_K / 2)
			var ch := String(grid[y])[x]
			if ch == "#" and _near(c, Minimap.COL_WALL):
				wall_px += 1
			if ch == "~" and _near(c, Minimap.COL_DEEP):
				water_px += 1
	_check(wall_px > 20 and water_px > 0, "murs clairs et eau bleue dans l'image (%d, %d)" % [wall_px, water_px])
	await _wait(0.5)
	_check(mm.build_count == 1, "aucune reconstruction en jeu")
	_check(mm._chests.size() == stage.chests.size(), "marqueurs de coffres (%d)" % mm._chests.size())
	_check(mm._pillars.size() == stage.pillars.size(), "marqueurs de piliers (%d)" % mm._pillars.size())
	_check(mm._has_player and Rect2(0, 0, 1, 1).has_point(mm._player_pos), "marqueur du joueur dans la carte %s" % mm._player_pos)
	# capsules d'or (groupe gold_capsules) : affichées tant que can_interact()
	var cap := FakeCapsule.new()
	cap.add_to_group(&"gold_capsules")
	stage.map.add_child(cap)
	await _wait(0.25)
	_check(mm._gold.size() == 1, "capsule d'or sur la minimap")
	cap.ok = false
	await _wait(0.25)
	_check(mm._gold.size() == 0, "capsule d'or retirée quand can_interact() est faux")
	cap.queue_free()
	var vp := hud.get_viewport().get_visible_rect()
	var mr := mm.get_global_rect()
	_check(vp.encloses(mr), "minimap dans l'écran %s" % mr)
	_check(not mr.intersects(hud.pause_button.get_global_rect()), "minimap ne chevauche pas le bouton pause")
	_check(absf(mr.size.x - Minimap.compact_px() * hud.ui_scale) < 1.0, "taille minimap (%.0f)" % mr.size.x)
	# agrandissement / fermeture
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mm._gui_input(click)
	_check(mm.expanded and mm.size == vp.size, "clic : minimap plein écran")
	mm._gui_input(click)
	_check(not mm.expanded and mm.get_global_rect() == mr, "second clic : minimap refermée")

	# --- Inventaire
	var ib := hud.item_bar
	_check(not ib.visible and ib.slot_count() == 0, "inventaire vide masqué")
	var ids := ItemDB.all_ids()
	RunState.add_item(StringName(ids[0]))
	RunState.add_item(StringName(ids[0]))
	RunState.add_item(StringName(ids[0]))
	RunState.add_item(StringName(ids[1]))
	await _frames(3)
	_check(ib.visible and ib.slot_count() == 2, "deux cases après item_added")
	var s0 := ib.get_slot(StringName(ids[0])) as ItemBar.ItemSlot
	_check(s0 != null and s0.badge.visible and s0.badge.text == "×3", "badge ×3")
	_check(s0.icon.texture != null and s0.frame.texture != null, "icône et cadre de qualité")
	for k in 20:
		RunState.add_item(StringName(ids[2 + k]))
	await _frames(3)
	var ir := ib.get_global_rect()
	_check(ir.size.y > ib.slot_px * 1.5, "PC : plusieurs lignes (%.0f px)" % ir.size.y)
	_check(ir.position.y >= hud._hp_bar.get_global_rect().end.y, "inventaire sous les PV")
	_check(not ir.intersects(mr), "inventaire / minimap sans chevauchement")
	ib._hover(s0, true)
	await _frames(2)
	_check(ib.tooltip.visible and ib._tip_count.text.ends_with("3") and ib._tip_name.text != "", "infobulle au survol : « %s »" % ib._tip_name.text)
	_check(vp.encloses(ib.tooltip.get_global_rect()), "infobulle dans l'écran")
	ib._hover(s0, false)
	_check(not ib.tooltip.visible, "infobulle masquée en sortie")

	# --- Menu pause : liste des items
	hud.pause_menu.open()
	await _frames(2)
	hud.pause_menu._fill_items()
	hud.pause_menu._show_only(hud.pause_menu._panel_items)
	await _frames(2)
	var rows: Array = hud.pause_menu.items_texts()
	_check(rows.size() == 22 and str(rows[0]).contains("×3") and str(rows[0]).contains(str(ItemDB.get_item(ids[0]).get("effect_text"))), "menu pause : %d items avec effets" % rows.size())
	hud.pause_menu._close()
	await _frames(2)

	# --- Barres de vie des monstres
	var hb: EnemyHealthBars = _main.health_bars
	_check(hb != null and hb.get_parent() == AmbianceManager.telegraph_layer(get_tree()), "barres de vie sous la couche des télégraphes")
	player.process_mode = Node.PROCESS_MODE_DISABLED # pas de sort automatique pendant la mesure
	var pp := player.global_position
	var e1 := director.spawn_enemy(1, pp + Vector2(300, 0))
	var e2 := director.spawn_enemy(2, pp + Vector2(-300, 0))
	await _frames(2)
	_check(hb.visible_count() == 0, "aucune barre sans dégâts")
	e1.take_damage(e1.max_hp * 0.3)
	await _frames(2)
	_check(hb.visible_count() == 1, "barre après un coup (1)")
	await _wait(3.3)
	_check(hb.visible_count() == 0, "barre masquée 3 s après le dernier coup")
	e2.take_damage(e2.max_hp * 0.2)
	await _frames(2)
	e2.hp = e2.max_hp
	await _frames(10) # soins relus 1 image sur 8 (perf EnemyHealthBars) : > 8 images
	_check(hb.visible_count() == 0, "pleins PV : pas de barre")

	# --- Barre de boss
	var boss := director.spawn_boss(&"etage", pp + Vector2(0, -400))
	await _frames(3)
	var bb := hud.boss_bars
	var expected := str((FloorPlan.data().get("boss_names", {}) as Dictionary).get(String(boss.call(&"boss_id")), ""))
	_check(bb.visible and bb.count() == 1 and bb.names()[0] == expected, "barre de boss : « %s »" % str(bb.names()))
	_check(vp.encloses(bb.get_global_rect()) and not bb.get_global_rect().intersects(mr), "barre de boss à l'écran, hors minimap")
	await _wait(0.2)
	_check(mm._bosses.size() == 1, "boss sur la minimap")
	boss.take_damage(10.0)
	await _frames(2)
	_check(hb.visible_count() == 0, "boss d'étage : pas de barre au-dessus de la tête")
	boss.take_damage(boss.max_hp * 2.0)
	await _frames(3)
	_check(bb.count() == 0 and not bb.visible, "barre de boss retirée à sa mort")

	# --- Tactile (mobile paysage) : grille de 2 lignes max (« +N » au-delà), pas de chevauchement des contrôles
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(4)
	ir = ib.get_global_rect()
	mr = mm.get_global_rect()
	_check(ir.size.y <= ItemBar.MAX_ROWS_TOUCH * (ib.slot_px + ib.gap) and ib.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "tactile : grille de %d lignes max, sans défilement" % ItemBar.MAX_ROWS_TOUCH)
	var joy := hud.joystick.get_global_rect()
	_check(ir.end.y < joy.position.y and mr.end.y < joy.position.y, "tactile : au-dessus de la zone du joystick")
	for b in hud.spell_buttons:
		_check(not b.get_global_rect().intersects(mr) and not b.get_global_rect().intersects(ir), "tactile : bouton de sort %d dégagé" % b.slot)
	_check(not mr.intersects(hud.pause_button.get_global_rect()), "tactile : minimap / bouton pause")
	# appui long -> infobulle
	ib.show_tooltip(s0.item_id)
	await _frames(2)
	_check(ib.tooltip.visible, "tactile : infobulle (appui long) affichable")
	ib.hide_tooltip()
	Platform.set_input_mode(Platform.InputMode.KBM)

	RunState.items.clear()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
