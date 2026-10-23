extends Node
## Retours du joueur (23/10/2026) :
## 1. barre d'items du HUD : 0 / 10 / 30 / 60 items distincts, PC 1920x1080 et mobile 2400x1080 : toutes les icônes
##    dans la zone, aucun chevauchement entre elles ni avec minimap / chrono / or / pause / objectifs, « +N » au-delà
##    du nombre de lignes max, compteur de stacks lisible (>= plancher de police) ;
## 2. récap de fin de run avec 4 variantes débloquées : UN bloc, boutons Rejouer / Continuer dans l'écran, touche du slot.
## godot --headless --path game res://tests/item_bar_endrun_test.tscn  -> « RESULT: OK »

class FakePlayer extends CharacterBody2D:
	signal hp_changed(hp: float, max_hp: float)
	var hp := 100.0
	var max_hp := 100.0
	var dead := false
	var pickup_radius := 200.0
	var kit: Node = null
	func get_spell_cooldowns() -> Array:
		return []
	func regen_per_s() -> float:
		return 1.0

const CFG := "user://item_bar_endrun_test_settings.cfg"
var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var prev_mode: int = Platform.input_mode
	var prev_cfg := GameSettings.cfg_path
	GameSettings.cfg_path = CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	await _bars(Vector2i(1920, 1080), false)
	await _bars(Vector2i(2400, 1080), true)
	await _recap()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = prev_cfg
	Platform.set_input_mode(prev_mode)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _bars(size: Vector2i, touch: bool) -> void:
	for count in [0, 10, 30, 60]:
		RunState.items.clear()
		var sv := SubViewport.new()
		sv.size = size
		add_child(sv)
		var hud: Hud = load("res://scripts/ui/hud.gd").new()
		sv.add_child(hud)
		var player := FakePlayer.new()
		player.add_to_group("player")
		sv.add_child(player)
		Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
		await _frames()
		hud.bind_player(player)
		var ids := ItemDB.all_ids()
		for k in mini(count, ids.size()):
			RunState.add_item(StringName(ids[k]))
		if count > 0:
			RunState.add_item(StringName(ids[0])) # un empilement : badge
		await _frames(4)
		var tag := "%dx%d %s %d items" % [size.x, size.y, "tactile" if touch else "kbm", count]
		var ib := hud.item_bar
		var want := mini(count, ids.size())
		if want == 0:
			_check(not ib.visible and ib.cell_rects().is_empty(), "%s : barre masquée" % tag)
		else:
			var bar := ib.get_global_rect()
			var vp := Rect2(Vector2.ZERO, Vector2(size))
			var cells := ib.cell_rects()
			var limit := (ItemBar.MAX_ROWS_TOUCH if touch else ItemBar.MAX_ROWS)
			_check(ib.visible and ib.slot_count() == want, "%s : %d cases" % [tag, ib.slot_count()])
			var ok_in := true
			for r in cells:
				ok_in = ok_in and bar.grow(1.0).encloses(r) and vp.encloses(r)
			_check(ok_in, "%s : toutes les icônes dans la zone réservée %s" % [tag, bar])
			var ok_ov := true
			for i in cells.size():
				for j in range(i + 1, cells.size()):
					if cells[i].intersects(cells[j]):
						ok_ov = false
			_check(ok_ov, "%s : aucun chevauchement entre icônes (%d)" % [tag, cells.size()])
			var rows := int(round((bar.size.y + ib.gap) / (ib.slot_px + ib.gap)))
			_check(rows <= limit, "%s : %d ligne(s) <= %d" % [tag, rows, limit])
			var cap := (int(floor((ib.max_width + ib.gap) / (ib.slot_px + ib.gap))) * limit)
			_check((ib.overflow_count > 0) == (want > cap), "%s : « +N » %s (cap %d, caché %d)" % [tag, "affiché" if ib.overflow_count > 0 else "absent", cap, ib.overflow_count])
			_check(ib.slot_count() - ib.overflow_count + (1 if ib.overflow_count > 0 else 0) == cells.size(), "%s : cases visibles + « +N » = %d" % [tag, cells.size()])
			var s0 := ib.get_slot(StringName(ids[0])) as ItemBar.ItemSlot
			_check(s0.badge.visible and s0.badge.get_theme_font_size("font_size") >= HudMetrics.floor_px(), "%s : badge de stacks >= %d px" % [tag, HudMetrics.floor_px()])
			_check(s0.get_global_rect().grow(1.0).encloses(s0.badge.get_global_rect()), "%s : badge dans sa case %s / %s" % [tag, s0.get_global_rect(), s0.badge.get_global_rect()])
			var others: Array[Rect2] = [hud._time_plate.get_global_rect(), hud._gold_box.get_global_rect(),
				hud.pause_button.get_global_rect(), hud.minimap.get_compact_rect()]
			if hud.objectives != null and hud.objectives.visible:
				others.append(hud.objectives.get_global_rect())
			var ok_o := true
			for o in others:
				ok_o = ok_o and not bar.intersects(o)
			_check(ok_o, "%s : barre %s hors chrono / or / pause / minimap / objectifs" % [tag, bar])
			if ib.overflow_count > 0:
				var hit := [false]
				ib.overflow_pressed.connect(func() -> void: hit[0] = true)
				ib._more.pressed.emit()
				_check(hit[0], "%s : « +N » émet overflow_pressed (ouvre Objets)" % tag)
		sv.queue_free()
		await _frames(2)
	RunState.items.clear()


func _all(n: Node, out: Array) -> void:
	for c in n.get_children():
		out.append(c)
		_all(c, out)


func _recap() -> void:
	for size in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		for touch in [false, true]:
			Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
			get_tree().paused = true
			var sv := SubViewport.new()
			sv.size = size
			sv.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(sv)
			var info := {"victory": true, "reason": &"victory", "character_name": "Ardent", "mode": &"moyen", "stage": 3,
				"active_time_s": 642.0, "level": 18, "pillars": 7, "kills": 1204, "items": 27, "gold": 980, "rubies": 87,
				"unlocks": [&"mode:difficile", &"spell:roaming_embers", &"spell:flame_pillar", &"spell:meteor_rain", &"spell:pillar_x"],
				"next_objective": {"title": "Rictus", "text": "Tuer 200 monstres à moins de 2 u de soi.", "progress": 0.4}}
			RunState.items.clear()
			var ids := ItemDB.all_ids()
			for k in mini(40, ids.size()): # beaucoup d'objets : le contenu dépasse l'écran
				RunState.items[StringName(ids[k])] = 1
			var s := EndRunScreen.create(info)
			sv.add_child(s)
			await _frames(4)
			var tag := "%dx%d %s" % [size.x, size.y, "tactile" if touch else "kbm"]
			var vp := Rect2(Vector2.ZERO, Vector2(size))
			var all: Array = []
			_all(s, all)
			var lines := 0
			for n in all:
				if n is Label and (n as Label).text.begins_with("Nouvelle variante"):
					lines += 1
			var block := s.find_child("NewVariants", true, false) as Control
			_check(block != null and lines == 0, "%s : UN bloc de variantes, aucune ligne « Nouvelle variante… » (%d)" % [tag, lines])
			var title := s.find_child("VariantsTitle", true, false) as Label
			_check(title != null and title.text == "Nouvelles variantes débloquées", "%s : titre du bloc" % tag)
			_check(s._variant_cells.size() == 4, "%s : 4 icônes de variante (%d)" % [tag, s._variant_cells.size()])
			for b in s._buttons:
				var r := (b as Button).get_global_rect()
				_check(vp.encloses(r) and b.is_visible_in_tree(), "%s : bouton « %s » dans l'écran %s" % [tag, b.text, r])
				_check(r.size.y >= UiTheme.MIN_TOUCH, "%s : bouton « %s » >= 88 px" % [tag, b.text])
			var frame := s._frame.get_global_rect()
			_check(vp.encloses(frame), "%s : panneau dans l'écran %s" % [tag, frame])
			_check(s._scroll.get_global_rect().end.y <= s._btn_row.get_global_rect().position.y + 1.0, "%s : contenu défilant au-dessus des boutons" % tag)
			var caps := ""
			for d in s._variant_caps:
				var h := d.holder as Control
				for c in h.get_children():
					caps += (c.text if c is Label else (c as KeyPrompt).text()) + "|"
			_check(caps.begins_with("Auto|"), "%s : slot 1 = « Auto » (%s)" % [tag, caps])
			_check(touch == caps.contains("Sort 2"), "%s : tactile = « Sort N » seulement en tactile (%s)" % [tag, caps])
			var big: Button = s._variant_cells[0]
			_check(big.tooltip_text != "" and big.get_global_rect().size.x >= UiTheme.MIN_TOUCH, "%s : nom en infobulle, cible >= 88 px %s" % [tag, big.get_global_rect()])
			big.focus_entered.emit()
			_check(s._variant_name.text == big.tooltip_text, "%s : focus -> nom affiché « %s »" % [tag, s._variant_name.text])
			var fs := s._variant_name.get_theme_font_size("font_size")
			_check(fs >= HudMetrics.floor_px(), "%s : nom >= %d px" % [tag, HudMetrics.floor_px()])
			sv.queue_free()
			get_tree().paused = false
			await _frames(2)
	RunState.items.clear()
