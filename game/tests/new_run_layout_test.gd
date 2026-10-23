extends Node
## Écran Nouvelle run (cartes verticales DA + panneau latéral) : aucun chevauchement entre la grille de cartes,
## le panneau du personnage, le bandeau de titre et la barre du bas (Retour / modes / Commencer), à 1920x1080,
## 2400x1080 et en 4:3 (1440x1080) ; toutes les cartes (une par entrée de data/characters.json) sont visibles, dans l'écran, au ratio du cadre, et la fiche
## ouverte (4 sorts) reste dans le panneau. Profil factice : aucune écriture disque.
## godot --headless --path game res://tests/new_run_layout_test.tscn  → « RESULT: OK »

class FakeProfile extends RefCounted:
	var rubies := 10
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {}

	func is_unlocked(_key: StringName) -> bool:
		return false

## Tailles virtuelles (base 1080 de haut, keep_height) : 1280x720 réel = 1920x1080 virtuel.
const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1440, 1080)]

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Rectangle de la carte sans l'effet de sélection (échelle autour du centre).
func _base_rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _ready() -> void:
	var host := Control.new()
	add_child(host)
	for vs in SIZES:
		host.size = vs
		var s := NewRunScreen.new()
		s.profile = FakeProfile.new()
		host.add_child(s)
		s.size = vs
		await _frames(4)
		s._layout()
		var tag := "%dx%d" % [int(vs.x), int(vs.y)]
		var expected: int = (JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")) as Array).size()
		_check(s.cards.size() == expected, "%s : %d cartes (%d)" % [tag, expected, s.cards.size()])
		s.cards[0].pressed.emit() # ouvre la fiche d'Ardent
		await _frames(14)
		var whole := Rect2(Vector2.ZERO, vs)
		var panel := Rect2(s.side_panel.global_position, s.side_panel.size)
		var banner := Rect2(s._banner.global_position, s._banner.size)
		var back := Rect2(s.back_button.global_position, s.back_button.size)
		var start := Rect2(s.start_button.global_position, s.start_button.size)
		var bar: Array[Rect2] = [back, start]
		for m in s.mode_buttons.values():
			bar.append(Rect2(m.global_position, m.size))
		_check(s.sheet.visible, "%s : fiche ouverte" % tag)
		var sheet_r := Rect2(s.sheet.global_position, s.sheet.size)
		_check(panel.encloses(sheet_r.grow(-1.0)), "%s : fiche %s hors du panneau %s" % [tag, sheet_r, panel])
		_check(whole.encloses(panel) and whole.encloses(banner), "%s : panneau ou bandeau hors écran" % tag)
		for b in bar:
			_check(whole.encloses(b), "%s : élément de la barre du bas hors écran %s" % [tag, b])
			_check(not b.intersects(panel), "%s : barre du bas %s chevauche le panneau %s" % [tag, b, panel])
		var rects: Array[Rect2] = []
		for c in s.cards:
			var r := _base_rect(c)
			_check(whole.encloses(r), "%s : carte hors écran %s" % [tag, r])
			_check(absf(r.size.x / r.size.y - 384.0 / 560.0) < 0.01, "%s : ratio de carte %s" % [tag, r.size])
			_check(not r.intersects(panel), "%s : carte %s chevauche le panneau" % [tag, r])
			_check(not r.intersects(banner), "%s : carte %s chevauche le bandeau" % [tag, r])
			for b in bar:
				_check(not r.intersects(b), "%s : carte %s chevauche la barre du bas %s" % [tag, r, b])
			for o in rects:
				_check(not o.intersects(r), "%s : cartes superposées" % tag)
			rects.append(r)
		# la carte sélectionnée grossit (×1,08) : son agrandissement reste dans l'écran et hors du panneau
		var sel: Control = s.cards[s.selected_index]
		var grown := Rect2(sel.global_position - sel.size * 0.04, sel.size * 1.08)
		_check(not grown.intersects(panel), "%s : carte sélectionnée agrandie chevauche le panneau" % tag)
		_check(grown.position.x >= 0.0 and grown.position.y >= 0.0, "%s : carte sélectionnée agrandie hors écran" % tag)
		# les 4 sorts de la fiche tiennent dans le panneau (défilement possible, pas de débordement latéral)
		_check(s.sheet.focus_rows().size() == 4, "%s : 4 sorts dans la fiche" % tag)
		for row in s.sheet.focus_rows():
			var br: Rect2 = Rect2(row[0].global_position, row[0].size)
			_check(br.position.x >= panel.position.x and br.end.x <= panel.end.x, "%s : icône de sort hors du panneau" % tag)
		# libellé « Verrou » sous l'icône de la variante, sans la recouvrir et dans le bouton
		for row in s.sheet.focus_rows():
			for vb in row:
				var lk: Control = vb.get_node_or_null("Lock")
				if lk == null or not (lk is Label):
					continue
				var icon: Control = vb.get_child(0)
				var ir := Rect2(icon.global_position, icon.size)
				var lr := Rect2(lk.global_position, lk.size)
				_check(not ir.intersects(lr), "%s : libellé Verrou %s recouvre l'icône %s" % [tag, lr, ir])
				_check(Rect2(vb.global_position, vb.size).encloses(lr.grow(-0.5)), "%s : libellé Verrou hors du bouton" % tag)
		s.queue_free()
		await _frames(2)
	print("RESULT: ", "OK" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
