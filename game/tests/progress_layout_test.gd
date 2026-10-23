extends Node
## Écran Progression : aucun chevauchement entre la ligne de stats / « Retour », les modes et la grille des
## personnages (7 cartes, avec défilement) à 1920×1080, 2400×1080 et 1280×720. Profil factice : aucune écriture disque.
## godot --headless --path game res://tests/progress_layout_test.tscn  → « RESULT: OK »

class FakeProfile extends RefCounted:
	var rubies := 123456789
	var stats := {"runs": 99999, "victories": 12345, "kills": 9999999, "play_time_s": 3600.0 * 999.0}

## Tailles virtuelles (base 1080 de haut, keep_height) : 1920x1080, 2400x1080, et 1280x720 réel = 1920x1080 virtuel ; 4:3 en plus.
const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1440, 1080)]

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _ready() -> void:
	var host := Control.new()
	add_child(host)
	for vs in SIZES:
		host.size = vs
		var ps := ProgressScreen.new()
		ps.profile = FakeProfile.new()
		host.add_child(ps)
		ps.size = vs
		for i in 4:
			await get_tree().process_frame
		ps._layout()
		await get_tree().process_frame
		var tag := "%dx%d" % [int(vs.x), int(vs.y)]
		_check(ps.char_cards.size() == ps.characters.size() and ps.characters.size() >= 1, "%s : une carte par entrée de characters.json (%d)" % [tag, ps.char_cards.size()])
		var scroll: ScrollContainer = ps._chars_scroll
		var sr := _rect(scroll)
		var stats := _rect(ps.stats_label)
		var back := _rect(ps.back_button)
		var modes := _rect(ps._modes_box)
		var whole := Rect2(Vector2.ZERO, vs)
		_check(not sr.intersects(stats), "%s : grille %s chevauche stats %s" % [tag, sr, stats])
		_check(not sr.intersects(back), "%s : grille chevauche Retour" % tag)
		_check(not modes.intersects(sr), "%s : modes %s chevauchent la grille %s" % [tag, modes, sr])
		_check(not modes.intersects(stats), "%s : modes chevauchent stats" % tag)
		_check(not stats.intersects(back), "%s : stats chevauche Retour" % tag)
		_check(whole.encloses(sr) and whole.encloses(stats) and whole.encloses(back) and whole.encloses(modes), "%s : élément hors écran sr=%s st=%s bk=%s md=%s" % [tag, sr, stats, back, modes])
		_check(stats.size.x + stats.position.x <= vs.x, "%s : stats déborde à droite" % tag)
		# cartes : visibles dans la zone de défilement (dans la largeur) et sans chevauchement entre elles
		var rects: Array[Rect2] = []
		for c in ps.char_cards:
			var r := _rect(c)
			_check(r.position.x >= sr.position.x - 1.0 and r.end.x <= sr.end.x + 1.0, "%s : carte hors largeur %s" % [tag, r])
			for o in rects:
				_check(not o.grow(-1.0).intersects(r.grow(-1.0)), "%s : cartes superposées" % tag)
			rects.append(r)
		# la dernière carte est atteignable par défilement
		var content_h: float = ps._chars_grid.get_combined_minimum_size().y
		_check(content_h <= sr.size.y or scroll.get_v_scroll_bar().max_value >= content_h - 1.0, "%s : grille non défilable" % tag)
		ps.queue_free()
		await get_tree().process_frame
	print("RESULT: ", "OK" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
