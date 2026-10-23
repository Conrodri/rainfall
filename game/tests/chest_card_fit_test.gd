extends Node
## Écran de coffre : le contenu des cartes tient dans les zones de card_front.png (illustration, bandeau, texte)
## à 1920x1080, 2400x1080 et 1280x720, avec la description et le nom les plus longs de data/items.json.
## godot --headless --path game res://tests/chest_card_fit_test.tscn   (RESULT: OK)

const SIZES := [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720)]

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


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var long_eff := ""
	var long_name := ""
	for it in items:
		if str(it.get("effect_text", "")).length() > long_eff.length():
			long_eff = str(it["effect_text"])
		if str(it.get("name", "")).length() > long_name.length():
			long_name = str(it["name"])
	var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	add_child(ui)
	ui.open(&"large", 2, 0.0)
	var t := 0.0
	while ui._busy and t < 20.0:
		await get_tree().create_timer(0.1, true).timeout
		t += 0.1
	_check(not ui._busy, "écran de coffre prêt")
	for sz in SIZES:
		get_window().size = sz
		await _frames(4)
		for i in 2:
			var f := ui._card_front[i]
			(f.get_child(1) as Label).text = long_name
			(f.get_child(2) as Label).text = long_eff
			(f.get_child(3) as Label).text = "[Zone] [Survie] [Boss]"
			(f.get_child(4) as Label).text = "Vous en avez déjà 12"
			ui._fit_card(i)
			await _frames(2)
			var r: Dictionary = ui.fit_report[i]
			var tag := "%dx%d carte %d" % [sz.x, sz.y, i]
			var card := ui._cards[i]
			var cr := Rect2(Vector2.ZERO, card.size)
			_check(cr.size.x > 100.0 and cr.encloses(r["text"]) and cr.encloses(r["band"]) and cr.encloses(r["art"]), "%s : zones dans la carte" % tag)
			_check(float(r["text_h"]) <= (r["text"] as Rect2).size.y + 0.5, "%s : description tient dans la zone (%.0f <= %.0f, police %d)" % [tag, r["text_h"], (r["text"] as Rect2).size.y, r["font"]])
			_check(float(r["name_w"]) <= (r["band"] as Rect2).size.x + 0.5, "%s : nom tient dans le bandeau (%.0f <= %.0f)" % [tag, r["name_w"], (r["band"] as Rect2).size.x])
			var tz: Rect2 = (r["text"] as Rect2).grow(1.0)
			for k in [2, 3, 4]:
				var l := f.get_child(k) as Label
				_check(tz.encloses(Rect2(l.position, l.size)), "%s : étiquette %d dans la zone de texte" % [tag, k])
				_check(l.get_visible_line_count() >= l.get_line_count(), "%s : étiquette %d entièrement visible (%d/%d lignes)" % [tag, k, l.get_visible_line_count(), l.get_line_count()])
			var box := ui._card_boxes[i]
			_check((r["art"] as Rect2).grow(1.0).encloses(Rect2(box.position, box.size)), "%s : icône dans la zone d'illustration" % tag)
			var icon := ui._card_icons[i]
			_check(icon.size.x <= box.size.x + 0.5 and icon.size.y <= box.size.y + 0.5, "%s : icône sans déborder" % tag)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
