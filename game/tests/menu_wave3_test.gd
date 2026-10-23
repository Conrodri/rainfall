extends Node
## Vague 3 (retours du joueur sur les menus) :
## - récap de fin de run : aucun id brut « type:id », pas de faux déblocage d'un perso déjà ouvert (characters.json) ;
## - Nouvelle run : la fiche du personnage présélectionné est visible dès l'arrivée (souris et tactile) ;
## - aucun texte de sort hors de son encart, pour TOUS les personnages, en 1920x1080, 2400x1080 (mobile 20:9) et 1440x1080 ;
## - difficulté affichée (fiche + carte) ; icônes des sorts d'Averse et de Bourbe trouvées.
## godot --headless --path game res://tests/menu_wave3_test.tscn  → « RESULT: OK »

class FakeProfile extends RefCounted:
	var rubies := 10
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = []
	var last_mode := "moyen"
	var last_character := "tocsin"
	var stats := {}

	func is_unlocked(_key: StringName) -> bool:
		return false

const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1440, 1080)]
const RAW_KEY := "(character|spell|mode):"

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_test_profile_unlocks()
	await _test_end_run()
	await _test_sheet_on_arrival(false)
	await _test_sheet_on_arrival(true)
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _test_spell_text_fits()
	_test_difficulty_data()
	_test_icons()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_profile_unlocks() -> void:
	var prof: Node = load("res://scripts/save/profile.gd").new()
	prof.write_enabled = false
	prof.path = "user://menu_wave3_profile.json"
	var u: Array = prof.add_run_result({"mode": &"moyen", "close_kills": 250})
	var rictus_open := false
	for c in CharacterCard.load_characters():
		if str(c.get("id", "")) == "rictus":
			rictus_open = bool(c.get("unlocked", false))
	if rictus_open:
		_check(not u.has(&"character:rictus"), "Rictus déjà ouvert (characters.json) : pas annoncé comme déblocage (%s)" % str(u))
	var prof2: Node = load("res://scripts/save/profile.gd").new()
	prof2.write_enabled = false
	prof2.path = "user://menu_wave3_profile.json"
	prof2.open_characters = []
	var u2: Array = prof2.add_run_result({"mode": &"moyen", "close_kills": 250})
	_check(u2.has(&"character:rictus"), "configuration de sortie : Rictus annoncé à 200 tués au contact (%s)" % str(u2))
	var u3: Array = prof2.add_run_result({"mode": &"moyen", "close_kills": 250})
	_check(not u3.has(&"character:rictus"), "pas d'annonce une seconde fois")
	prof.free()
	prof2.free()


func _test_end_run() -> void:
	var keys: Array[StringName] = [&"character:rictus", &"spell:roaming_embers", &"mode:difficile", &"character:inconnu_x"]
	var re := RegEx.create_from_string(RAW_KEY)
	for k in keys:
		var t := EndRunScreen.unlock_text(k)
		_check(re.search(t) == null and not t.contains("_"), "texte de déblocage lisible pour %s : « %s »" % [k, t])
	_check(EndRunScreen.unlock_text(&"character:rictus").contains("Rictus"), "nom lisible de Rictus")
	_check(EndRunScreen.unlock_text(&"spell:roaming_embers").contains("Braises errantes"), "nom lisible de la variante")
	_check(EndRunScreen.unlock_icon_path(&"character:rictus") != "", "portrait de Rictus pour le déblocage")
	var e := EndRunScreen.create({"victory": true, "character_name": "Rictus", "mode": "moyen", "stage": 5,
		"active_time_s": 900.0, "level": 20, "kills": 1000, "rubies": 50, "unlocks": keys})
	add_child(e)
	await _frames(3)
	for t in e.texts():
		_check(re.search(str(t)) == null, "récap sans id brut : « %s »" % str(t))
	e.queue_free()
	await _frames(1)


func _spawn(vs: Vector2, host: Control) -> NewRunScreen:
	host.size = vs
	var s := NewRunScreen.new()
	s.profile = FakeProfile.new()
	host.add_child(s)
	s.size = vs
	return s


func _test_sheet_on_arrival(touch: bool) -> void:
	Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
	var host := Control.new()
	add_child(host)
	var s := _spawn(Vector2(1920, 1080), host)
	await _frames(2)
	var tag := "tactile" if touch else "souris"
	_check(s.is_sheet_open(), "%s : fiche ouverte à l'arrivée sans clic" % tag)
	_check(String(s.sheet.character.get("id", "")) == "tocsin", "%s : fiche du perso présélectionné (dernier choix)" % tag)
	_check(not s.hint.visible, "%s : invite « Choisissez un personnage » masquée" % tag)
	_check(s.sheet.focus_rows().size() == 4, "%s : sorts listés" % tag)
	host.queue_free()
	await _frames(1)


func _test_spell_text_fits() -> void:
	var host := Control.new()
	add_child(host)
	for vs in SIZES:
		var s := _spawn(vs, host)
		await _frames(4)
		s._layout()
		var tag := "%dx%d" % [int(vs.x), int(vs.y)]
		for i in s.characters.size():
			if s.cards[i].locked:
				continue
			s.cards[i].pressed.emit()
			await _frames(16)
			var cid := String(s.characters[i].get("id", ""))
			var sh := s.sheet
			var scroll: ScrollContainer = sh._scroll
			var sheet_r := Rect2(sh.global_position, sh.size)
			_check(sh._content.size.x <= scroll.size.x + 1.0, "%s %s : contenu pas plus large que le panneau (%.0f > %.0f)" % [tag, cid, sh._content.size.x, scroll.size.x])
			for r in sh._rows:
				var box: Node = (r.name as Control).get_parent()
				while box != null and not (box is PanelContainer):
					box = box.get_parent()
				var box_r := Rect2((box as Control).global_position, (box as Control).size)
				for key in ["name", "role", "desc", "stats"]:
					var l: Label = r[key]
					if not l.visible or l.text == "":
						continue
					var lr := Rect2(l.global_position, l.size)
					_check(lr.position.x >= box_r.position.x - 1.0 and lr.end.x <= box_r.end.x + 1.0,
						"%s %s %s : « %s » dans son encart horizontalement" % [tag, cid, key, l.text.left(24)])
					_check(lr.end.x <= sheet_r.end.x + 1.0, "%s %s %s : dans le panneau" % [tag, cid, key])
					_check(l.get_minimum_size().y <= l.size.y + 1.0, "%s %s %s : texte non tronqué (%.0f > %.0f)" % [tag, cid, key, l.get_minimum_size().y, l.size.y])
					_check(l.get_theme_font_size(&"font_size") >= 12, "%s %s %s : police lisible" % [tag, cid, key])
			if sh.needs_scroll():
				_check(scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "%s %s : défilement possible" % [tag, cid])
				print("  %s %s : défilement (échelle de texte %.2f)" % [tag, cid, sh.text_scale])
			# Difficulté sur la fiche (et la carte).
			if CharacterCard.difficulty_of(s.characters[i]) > 0:
				_check(sh.find_child("DifficultyRow", true, false) != null, "%s %s : difficulté sur la fiche" % [tag, cid])
				_check(s.cards[i].find_child("Difficulty", true, false) != null, "%s %s : difficulté sur la carte" % [tag, cid])
		s.queue_free()
		await _frames(1)
	host.queue_free()


func _test_difficulty_data() -> void:
	var want := {"rainette": 3, "tocsin": 3, "arpenteuse": 3, "ardent": 1}
	for c in CharacterCard.load_characters():
		var id := str(c.get("id", ""))
		var d := CharacterCard.difficulty_of(c)
		if want.has(id):
			_check(d == want[id], "difficulté de %s = %d (%d)" % [id, want[id], d])
		if bool(c.get("playable", false)):
			_check(d >= 1 and d <= 3, "difficulté renseignée pour %s" % id)


func _test_icons() -> void:
	for c in CharacterCard.load_characters():
		var id := str(c.get("id", ""))
		for sp in c.get("spells", []):
			var sid := StringName(str(sp.get("id", "")))
			var ok := ArdentKit.spell_icon(sid) != null
			if id in ["averse", "bourbe", "ardent", "rictus", "tocsin", "arpenteuse", "rainette", "avare"]:
				_check(ok, "icône du sort %s (%s)" % [sid, id])
			elif not ok:
				print("  (info) icône absente : %s (%s)" % [sid, id])
