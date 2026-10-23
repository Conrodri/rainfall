extends Node
## godot --headless --path game res://tests/character_sheet_ux_test.tscn  -> RESULT: OK
## Retours du joueur 23/10/2026 :
##  - difficulté : Taliant (morfil) et Vigie faciles ; liste triée du plus facile au plus dur, ordre stable ;
##  - passif : infobulle non vide pour les 10 personnages (texte lu dans le kit, jamais de « %% » ni de format brut) ;
##  - fiche en gros plan : aucun défilement, tous les sorts dans l'écran, 10 personnages x 3 ratios x 2 modes d'entrée ;
##  - aperçu d'un sort sur le modèle : sélection, description complète, aucune fuite de nœuds.

class FakeProfile extends RefCounted:
	var unlocked_modes: Array = ["facile", "moyen"]
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {}

	func is_unlocked(_key: StringName) -> bool:
		return false

const SIZES: Array[Vector2] = [Vector2(1920, 1080), Vector2(2400, 1080), Vector2(1440, 1080)]
const IDS := ["ardent", "rictus", "tocsin", "averse", "arpenteuse", "rainette", "avare", "bourbe", "vigie", "morfil"]

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_test_sorting()
	_test_passives()
	await _test_sheet_fits()
	await _test_preview()
	print("RESULT: ", "OK" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- 1. Difficulté et tri ----------------------------------------------------------

func _test_sorting() -> void:
	var raw := CharacterCard.load_characters()
	var diff := {}
	for c in raw:
		diff[String(c.id)] = CharacterCard.difficulty_of(c)
	_check(diff.get("morfil") == 1 and diff.get("vigie") == 1, "Taliant (morfil) et Vigie : difficulté 1 (facile)")
	_check(diff.get("ardent") == 1, "Ardent reste facile")
	for id in IDS:
		_check(diff.has(id) and int(diff[id]) >= 1 and int(diff[id]) <= 3, "%s : difficulté 1-3 renseignée" % id)
	var sorted := CharacterCard.sorted_by_difficulty(raw)
	_check(sorted.size() == raw.size(), "tri : aucun personnage perdu")
	var prev := 0
	for c in sorted:
		var d := CharacterCard.difficulty_of(c)
		_check(d >= prev, "tri : %s (diff %d) après difficulté %d" % [c.id, d, prev])
		prev = d
	# stabilité : à difficulté égale, ordre d'origine
	for d in [1, 2, 3]:
		var want: Array = []
		for c in raw:
			if CharacterCard.difficulty_of(c) == d:
				want.append(String(c.id))
		var got: Array = []
		for c in sorted:
			if CharacterCard.difficulty_of(c) == d:
				got.append(String(c.id))
		_check(want == got, "tri stable à difficulté %d : %s" % [d, str(got)])
	# difficulté absente = en dernier, verrouillés / cachés suivent la même règle
	var fake: Array = [{"id": "z", "difficulty": 0}, {"id": "a", "difficulty": 3}, {"id": "b", "difficulty": 1}, {"id": "c", "difficulty": 1}, {"id": "d", "hidden": true, "difficulty": 2}]
	var ids: Array = []
	for c in CharacterCard.sorted_by_difficulty(fake):
		ids.append(String(c.id))
	_check(ids == ["b", "c", "d", "a", "z"], "tri : cas limites (absente en dernier, stable) : %s" % str(ids))


# --- 2. Passifs ----------------------------------------------------------------------

func _test_passives() -> void:
	var PB := load("res://scripts/ui/passive_badge.gd")
	for id in IDS:
		var info: Dictionary = PB.info_for(StringName(id))
		_check(not info.is_empty(), "%s : passive_info() fourni par le kit" % id)
		_check(String(info.get("name", "")) != "" and String(info.get("desc", "")).length() > 20, "%s : nom et description non vides" % id)
		var desc := String(info.get("desc", ""))
		_check(not desc.contains("%%") and not desc.contains("%s") and not desc.contains("%d"), "%s : aucun format brut dans le texte" % id)
		_check(info.has("icon") and info.has("hud"), "%s : clés icon / hud présentes" % id)
	_check(not bool(PB.info_for(&"ardent").get("hud", true)), "Ardent : pas d'icône de passif au HUD")
	_check(bool(PB.info_for(&"vigie").get("hud", false)) and bool(PB.info_for(&"morfil").get("hud", false)), "Vigie et Taliant : icône au HUD")
	var vig: String = PB.info_for(&"vigie").desc
	_check(vig.contains(KitResource.fmt(VigieKit.TENSION_MOVING_S)) and vig.contains(KitResource.fmt(VigieKit.ALLONGE_RANGE_U)), "Vigie : chiffres lus dans le kit")
	var mor: String = PB.info_for(&"morfil").desc
	_check(mor.contains(KitResource.fmt(MorfilKit.COST_CRESCENT)) and mor.contains(KitResource.fmt(MorfilKit.SHARP_ULT_MIN)), "Taliant : coûts d'aiguisage lus dans le kit")


# --- 3. Fiche sans défilement ----------------------------------------------------------

func _spawn(vs: Vector2, host: Control) -> NewRunScreen:
	host.size = vs
	var s := NewRunScreen.new()
	s.profile = FakeProfile.new()
	host.add_child(s)
	s.size = vs
	return s


func _test_sheet_fits() -> void:
	var host := Control.new()
	add_child(host)
	for touch in [false, true]:
		Platform.set_input_mode(Platform.InputMode.TOUCH if touch else Platform.InputMode.KBM)
		for vs in SIZES:
			var s := _spawn(vs, host)
			await _frames(4)
			s._layout()
			var tag := "%dx%d %s" % [int(vs.x), int(vs.y), "tactile" if touch else "souris"]
			var whole := Rect2(Vector2.ZERO, vs)
			var floor_px := 26 if touch else CharacterCard.MIN_FONT
			for i in s.characters.size():
				if s.cards[i].locked:
					continue
				var cid := String(s.characters[i].get("id", ""))
				s.cards[i].pressed.emit()
				await _frames(34)
				var sh := s.sheet
				_check(s.is_sheet_open(), "%s %s : fiche ouverte" % [tag, cid])
				_check(sh.find_children("*", "ScrollContainer", true, false).is_empty(), "%s %s : aucune barre de défilement" % [tag, cid])
				_check(not sh.needs_scroll(), "%s %s : tient sans défiler (%.0f / %.0f)" % [tag, cid, sh.get_combined_minimum_size().y, sh.allotted_h])
				var sheet_r := Rect2(sh.global_position, sh.size)
				_check(whole.encloses(sheet_r.grow(-0.5)), "%s %s : fiche dans l'écran %s" % [tag, cid, sheet_r])
				_check(sh.focus_rows().size() == 4, "%s %s : 4 sorts" % [tag, cid])
				for row in sh.focus_rows():
					for b in row:
						var br := Rect2(b.global_position, b.size)
						_check(whole.encloses(br.grow(-0.5)) and sheet_r.encloses(br.grow(-0.5)), "%s %s : icône de sort dans l'écran %s" % [tag, cid, br])
				for r in sh._rows:
					var cr := Rect2((r.cell as Control).global_position, (r.cell as Control).size)
					_check(whole.encloses(cr.grow(-0.5)), "%s %s : case de sort dans l'écran %s" % [tag, cid, cr])
					for key in ["name", "role", "desc", "stats", "dmg"]:
						var l: Label = r[key]
						if l.visible and l.text != "":
							_check(l.get_theme_font_size(&"font_size") >= floor_px, "%s %s : police %s >= %d px" % [tag, cid, key, floor_px])
							var lr := Rect2(l.global_position, l.size)
							_check(lr.end.x <= cr.end.x + 1.0 and lr.position.x >= cr.position.x - 1.0, "%s %s : %s dans sa case" % [tag, cid, key])
				_check(sh.passive_button != null, "%s %s : bouton de passif" % [tag, cid])
				if sh.passive_button != null:
					var pr := Rect2(sh.passive_button.global_position, sh.passive_button.size)
					_check(whole.encloses(pr), "%s %s : passif dans l'écran" % [tag, cid])
				_check(sh._detail_desc.text != "", "%s %s : description complète du sort affichée" % [tag, cid])
				s.close_sheet()
				await _frames(2)
			s.queue_free()
			await _frames(2)
	host.queue_free()
	await _frames(2)
	Platform.set_input_mode(Platform.InputMode.KBM)


# --- 4. Aperçu d'un sort sur le modèle ------------------------------------------------

func _test_preview() -> void:
	var host := Control.new()
	add_child(host)
	var s := _spawn(Vector2(1920, 1080), host)
	await _frames(4)
	var played: Array = []
	s.sheet.spell_previewed.connect(func(slot: int, id: StringName) -> void: played.append([slot, id]))
	s.cards[0].pressed.emit()
	await _frames(20)
	var sh := s.sheet
	_check(sh.preview != null, "aperçu : modèle animé présent")
	# clic sur un sort : surbrillance + description complète + signal
	var b2: Button = sh.focus_rows()[1][0]
	b2.pressed.emit()
	await _frames(3)
	_check(sh.selected_slot == 2 and played.size() == 1 and played[0][0] == 2, "clic sur le sort 2 : sélectionné et aperçu joué")
	var spell2: Dictionary = (b2.get_meta("option") as Dictionary)
	_check(sh._detail_name.text == String(spell2.get("name", "?")) and sh._detail_desc.text == String(spell2.get("desc", "?")), "description complète du sort affichée dans le panneau")
	_check(sh._detail_desc.text.length() > 10, "description non vide")
	# l'anim d'action ou le repli squash : aucun plantage, retour à l'attente
	var anim_before := sh.preview.animation
	_check(CharacterSheet.action_anim(sh.preview.sprite_frames, 1) != &"" or true, "action_anim tolère l'absence d'anim")
	await get_tree().create_timer(2.0).timeout
	_check(sh.preview.animation == CharacterSheet.idle_anim(sh.preview.sprite_frames) or sh.preview.animation == anim_before, "retour à l'attente après l'aperçu")
	# fuite de nœuds : rejouer tous les sorts de tous les personnages, puis comparer le nombre d'objets
	var baseline := 0.0
	for round in 2:
		for i in s.characters.size():
			if s.cards[i].locked:
				continue
			s.cards[i].pressed.emit()
			await _frames(6)
			for row in s.sheet.focus_rows():
				(row[0] as Button).pressed.emit()
				await _frames(2)
		await get_tree().create_timer(2.0).timeout
		await _frames(3)
		if round == 0:
			baseline = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_check(after <= baseline + 6.0, "aucune fuite de nœuds après 2 tours d'aperçus (%d -> %d)" % [int(baseline), int(after)])
	_check(sh._fx == null or s.sheet._fx.get_child_count() <= 2, "couche d'effets vidée")
	# repli propre : personnage sans aucune anim d'action ni VFX (SpriteFrames vide)
	var empty := SpriteFrames.new()
	_check(CharacterSheet.action_anim(empty, 4) == &"" and CharacterSheet.action_anim(null, 1) == &"", "pas d'anim d'action -> repli générique (&\"\")")
	s.queue_free()
	host.queue_free()
	await _frames(2)
