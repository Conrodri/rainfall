extends Node
## Test headless du lot D (Nouvelle run + Progression), docs/Design_Menus.md §8 lot D.
## godot --headless --path game res://tests/new_run_test.tscn  → « RESULT: OK »

const NEW_RUN := preload("res://scenes/menu/new_run.tscn")
const PROGRESS := preload("res://scenes/menu/progress.tscn")


## Profil factice (aucune écriture disque) ; le vrai `Profile` n'est pas touché.
class FakeProfile:
	extends RefCounted
	var rubies := 1234
	var unlocked_modes: Array = ["facile", "moyen"]
	var unlocked_spells: Array = ["spell:meteor_rain"]
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {"runs": 12, "victories": 3, "kills": 8412, "play_time_s": 6720.0, "best_time_s": {"moyen": 1234.0}}

	func is_unlocked(key: StringName) -> bool:
		return String(key) in unlocked_spells


## Personnage verrouillé injecté par le test (le roster de characters.json est ouvert pendant les tests de jeu).
const TEST_LOCKED := {"id": "test_verrou", "name": "Verrou", "title": "Test", "style": "Test", "config": "4 sorts",
	"unlocked": false, "unlock_text": "Objectif de test.", "hidden": false, "playable": true, "spells": []}

var _fails: Array[String] = []
var _json: Array = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		print("ÉCHEC : ", what)


func _ready() -> void:
	var plat := get_node_or_null("/root/Platform")
	if plat != null:
		plat.set_input_mode(1) # clavier/souris : focus visible
	_json = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	await _test_cards_and_lock()
	await _test_navigation_and_start()
	await _test_sheet_and_variants()
	await _test_mb_lisible()
	await _test_touch_long_press()
	await _test_progress()
	await _test_ratios()
	await _test_preview_framing()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _spawn(profile: Object, chars: Array = []) -> NewRunScreen:
	var s: NewRunScreen = NEW_RUN.instantiate()
	s.profile = profile
	s.characters = chars
	add_child(s)
	return s


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)
	await _frames(1)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_viewport().push_input(up)
	await _frames(1)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Index de la première entrée verrouillée d'après characters.json (sinon -1).
func _locked_index(s: NewRunScreen) -> int:
	for i in s.cards.size():
		if s.cards[i].locked:
			return i
	return -1


func _test_cards_and_lock() -> void:
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	_check(s.cards.size() == _json.size(), "%d cartes = entrées de characters.json, cachées comprises (obtenu %d)" % [_json.size(), s.cards.size()])
	var playable := 0
	for c in s.cards:
		if not c.locked:
			playable += 1
	# jouables d'office = entrées "unlocked" et "playable" de characters.json (roster ouvert pendant les tests de jeu)
	var expected := 0
	for c in _json:
		if c.get("unlocked", false) and c.get("playable", false):
			expected += 1
	_check(playable == expected, "%d personnage(s) jouable(s) d'office (obtenu %d)" % [expected, playable])
	_check(not s.start_button.disabled, "Commencer actif avec Ardent")
	_check(not CharacterCard.is_mode_unlocked(s.profile, &"difficile"), "Difficile verrouillé sans 'difficile' au profil")
	_check(s.mode == &"moyen", "mode par défaut = Moyen")
	# Chaque carte a un portrait (buste ou frame) ou le « ? » de repli, et l'accent de son personnage.
	for c in s.cards:
		_check(c.accent == CharacterCard.accent_color(c.data), "accent de %s" % c.data.get("id"))
	s.queue_free()
	await _frames(2)
	# Verrouillé : entrée verrouillée de characters.json si elle existe, sinon entrée injectée par le test.
	var chars: Array = _json.duplicate(true)
	var has_locked := false
	for c in chars:
		if CharacterCard.is_character_locked(FakeProfile.new(), c):
			has_locked = true
	if not has_locked:
		chars.append(TEST_LOCKED.duplicate(true))
	s = _spawn(FakeProfile.new(), chars)
	await _frames(3)
	var li := _locked_index(s)
	_check(li >= 0, "au moins une carte verrouillée")
	if li >= 0:
		s.cards[li].pressed.emit()
		await _frames(2)
		_check(s.start_button.disabled, "Commencer désactivé sur un perso verrouillé")
		_check(s.start_reason.text == "Personnage verrouillé", "libellé « Personnage verrouillé »")
		_check(s.is_sheet_open(), "fiche ouverte au clic sur un portrait")
		_check(s.sheet.focus_rows().is_empty(), "fiche verrouillée : pas de kit")
		var got: Array = []
		s.start_requested.connect(func(cfg: Dictionary) -> void: got.append(cfg))
		s._on_start()
		_check(got.is_empty(), "pas de départ avec un perso verrouillé")
	# Mode verrouillé : appui = infobulle, mode inchangé.
	s.mode_buttons[&"difficile"].pressed.emit()
	await _frames(1)
	_check(s.mode == &"moyen", "Difficile verrouillé non sélectionnable")
	_check(s.tooltip.visible, "infobulle sur le mode verrouillé")
	s.queue_free()
	await _frames(2)


func _is_mode_button(s: NewRunScreen, c: Control) -> bool:
	return c != null and s.mode_buttons.values().has(c)


func _test_navigation_and_start() -> void:
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	var n := s.cards.size()
	var cols := s.grid_cols
	var rows := ceili(float(n) / cols)
	_check(cols >= 2 and cols <= n, "grille : %d colonnes pour %d cartes" % [cols, n])
	# Toutes les cartes tiennent dans l'écran (aucune ne déborde sous la barre des modes).
	var vr := s.get_viewport_rect()
	for c in s.cards:
		_check(vr.encloses(c.get_rect()) and c.get_rect().end.y < s.mode_buttons[&"moyen"].position.y, "carte %s visible au-dessus des modes" % c.name)
	_check(_focus() == s.cards[0], "focus initial sur Ardent (obtenu %s)" % _focus())
	await _action(&"ui_right")
	await _action(&"ui_right")
	_check(_focus() == s.cards[mini(2, n - 1)], "ui_right ×2 → 3e portrait")
	# Droite au bout d'une rangée → première carte de la rangée suivante.
	s.cards[cols - 1].grab_focus()
	await _frames(1)
	await _action(&"ui_right")
	_check(_focus() == s.cards[cols % n], "ui_right en fin de rangée → rangée suivante (obtenu %s)" % _focus())
	# Bas / haut entre rangées, colonne conservée.
	s.cards[2].grab_focus()
	await _frames(1)
	if rows > 1:
		await _action(&"ui_down")
		var below := mini(2 + cols, n - 1)
		_check(_focus() == s.cards[below], "ui_down → carte de la rangée du dessous (obtenu %s)" % _focus())
		if below == 2 + cols:
			await _action(&"ui_up")
			_check(_focus() == s.cards[2], "ui_up → carte de la rangée du dessus (obtenu %s)" % _focus())
			await _action(&"ui_down")
	# Depuis la dernière rangée, bas → fiche (ouverte dès l'arrivée, vague 3) puis barre des modes.
	for k in rows + 6:
		if _is_mode_button(s, _focus()):
			break
		await _action(&"ui_down")
	_check(_is_mode_button(s, _focus()), "ui_down depuis la dernière rangée → fiche puis modes (obtenu %s)" % _focus())
	for k in 2:
		if _focus() != s.mode_buttons[&"facile"]:
			await _action(&"ui_left")
	_check(_focus() == s.mode_buttons[&"facile"], "ui_left → Facile")
	# Le focus sélectionne : les cartes parcourues ont changé le perso ; on revient à Ardent avant de lancer.
	s.cards[0].pressed.emit()
	await _frames(2)
	_check(s.selected_index == 0 and not s.start_button.disabled, "retour à Ardent avant le départ")
	var got: Array = []
	s.start_requested.connect(func(cfg: Dictionary) -> void: got.append(cfg))
	await _action(&"ui_accept") # choisit Facile, focus → Commencer
	_check(s.mode == &"facile", "Facile choisi")
	_check(_focus() == s.start_button, "focus sur Commencer après le choix du mode")
	await _action(&"ui_accept")
	_check(got.size() == 1, "start_requested émis une fois")
	if got.size() == 1:
		_check(got[0].get("character") == &"ardent", "config.character = ardent")
		_check(got[0].get("mode") == &"facile", "config.mode = facile")
		var sp: Dictionary = got[0].get("spells", {})
		_check(sp.get(1) == &"eclat_de_braise" and sp.get(4) == &"brasier", "sorts de base par défaut")
	_check(String(s.profile.last_mode) == "facile", "Profile.last_mode mis à jour")
	s.queue_free()
	await _frames(2)
	# Chaque personnage ouvert du roster peut lancer une run (le dernier, par exemple).
	s = _spawn(FakeProfile.new())
	await _frames(3)
	var last := n - 1
	while last > 0 and s.cards[last].locked:
		last -= 1
	s.cards[last].pressed.emit()
	await _frames(2)
	var got2: Array = []
	s.start_requested.connect(func(cfg: Dictionary) -> void: got2.append(cfg))
	s.start_button.pressed.emit()
	_check(got2.size() == 1 and String(got2[0].character) == String(_json[last].id), "départ avec %s" % _json[last].id)
	s.queue_free()
	await _frames(2)


func _variant_button(s: NewRunScreen, vid: String) -> Button:
	for row in s.sheet.focus_rows():
		for b in row:
			if b.name == "Variant_" + vid:
				return b
	return null


func _test_sheet_and_variants() -> void:
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	_check(s.is_sheet_open() and String(s.sheet.character.get("id", "")) == String(s.characters[s.selected_index].get("id", "")), "fiche du perso présélectionné ouverte dès l'arrivée (vague 3)")
	s.cards[0].pressed.emit()
	await _frames(12)
	_check(s.is_sheet_open(), "fiche d'Ardent ouverte")
	_check(s.sheet.preview != null and s.sheet.preview.animation == &"idle_s" and s.sheet.preview.is_playing(), "aperçu animé idle_s")
	var rows := s.sheet.focus_rows()
	_check(rows.size() == 4, "4 sorts dans la fiche")
	_check(s.sheet._rows.size() == 4 and s.sheet._rows[1].stats.text.contains("Recharge 6 s"), "chiffres de Nova lus dans SpellData : '%s'" % (s.sheet._rows[1].stats.text if s.sheet._rows.size() > 1 else ""))
	var locked_b := _variant_button(s, "roaming_embers")
	_check(locked_b != null and bool(locked_b.get_meta("locked")), "Braises errantes verrouillée")
	# Focus clavier/manette → infobulle de quête.
	locked_b.grab_focus()
	await _frames(3)
	_check(s.tooltip.visible and s.tooltip.text_content().contains("Quête de déblocage"), "infobulle de quête au focus")
	_check(s.tooltip.text_content().contains("Tuer 500 monstres"), "texte de quête affiché")
	# Survol souris.
	s.tooltip.hide_tip()
	locked_b.mouse_entered.emit()
	await _frames(2)
	_check(s.tooltip.visible, "infobulle au survol souris")
	# Appui sur verrouillée : sélection inchangée.
	locked_b.pressed.emit()
	await _frames(1)
	_check(s.sheet.chosen.get(1) == &"eclat_de_braise", "variante verrouillée non sélectionnable")
	# Variante débloquée (profil factice) : sélection pour la run.
	var meteor := _variant_button(s, "meteor_rain")
	_check(meteor != null and not bool(meteor.get_meta("locked")), "Pluie de météores débloquée via Profile.is_unlocked")
	meteor.pressed.emit()
	await _frames(1)
	_check(s.sheet.chosen.get(3) == &"meteor_rain", "variante débloquée choisie")
	var got: Array = []
	s.start_requested.connect(func(cfg: Dictionary) -> void: got.append(cfg))
	s.start_button.pressed.emit()
	_check(got.size() == 1 and got[0].spells.get(3) == &"meteor_rain", "config.spells porte la variante")
	# Navigation fiche : bas depuis un portrait → première option de la fiche.
	# Le focus sélectionne le personnage (M-B) : la fiche est reconstruite pour le portrait focalisé,
	# ses lignes (et boutons de variantes) précédentes sont libérées -> on relit la fiche.
	s.cards[((s.cards.size() - 1) / s.grid_cols) * s.grid_cols].grab_focus() # dernière rangée de la grille
	await _frames(6)
	rows = s.sheet.focus_rows()
	await _action(&"ui_down")
	_check(not rows.is_empty() and _focus() == rows[0][0], "ui_down depuis un portrait (dernière rangée) → fiche")
	# ui_cancel : ferme d'abord l'infobulle, puis retour (retour sur Ardent pour sa variante verrouillée).
	s.cards[0].grab_focus()
	await _frames(6)
	locked_b = _variant_button(s, "roaming_embers")
	_check(locked_b != null, "fiche d'Ardent reconstruite au retour du focus")
	if locked_b == null:
		s.queue_free()
		return
	var back := [0]
	s.back_requested.connect(func() -> void: back[0] += 1)
	locked_b.grab_focus()
	await _frames(2)
	await _action(&"ui_cancel")
	_check(not s.tooltip.visible and back[0] == 0, "ui_cancel ferme l'infobulle")
	await _action(&"ui_cancel")
	_check(back[0] == 1, "ui_cancel → back_requested")
	s.queue_free()
	await _frames(2)


## Lot M-B (audit M2, M3, M7, M8) : focus = sélection, mode lisible, textes >= 18 px, variantes masquées.
func _test_mb_lisible() -> void:
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	# M2 : le focus sélectionne ; jamais deux cartes « choisies » (liseré braise, échelle).
	s.cards[2].grab_focus()
	await _frames(3)
	var chosen := 0
	for c in s.cards:
		if c._ember.visible:
			chosen += 1
	_check(chosen == 1 and s.selected_index == 2 and s.cards[2]._ember.visible, "focus sur la carte 3 : une seule carte choisie (obtenu %d)" % chosen)
	_check(String(s.sheet.character.get("id", "")) == String(s.characters[2].get("id", "")), "la fiche suit le focus")
	# Retour sur la même carte depuis la fiche : les choix de variantes ne sont pas réinitialisés.
	var sheet_before := s.sheet.chosen.duplicate()
	s.cards[2].grab_focus()
	await _frames(2)
	_check(s.sheet.chosen == sheet_before, "refocaliser la carte ne reconstruit pas la fiche")
	# M3 : mode choisi = fond braise opaque ; verrouillé = cadenas ; plus de jargon « Scaling ».
	var sel_box := s.mode_buttons[&"moyen"].get_theme_stylebox("normal") as StyleBoxFlat
	_check(sel_box != null and sel_box.bg_color == Color("#C23B12") and sel_box.bg_color.a == 1.0, "mode choisi : fond braise #C23B12 opaque")
	_check(s.mode_buttons[&"moyen"].get_node_or_null("StateIcon") != null, "mode choisi : coche")
	_check(s.mode_buttons[&"difficile"].get_node_or_null("StateIcon") != null, "Difficile verrouillé : cadenas")
	_check(s.mode_buttons[&"facile"].get_node_or_null("StateIcon") == null, "mode libre non choisi : pas d'icône")
	for m in s.MODES:
		_check(not s.mode_labels[m].text.contains("Scaling") and not s.mode_labels[m].text.contains("×"), "légende de %s sans jargon : '%s'" % [m, s.mode_labels[m].text])
	_check(s.mode_labels[&"facile"].text == "Plus doux · rubis −20 %", "légende Facile : '%s'" % s.mode_labels[&"facile"].text)
	_check(s.mode_labels[&"moyen"].text == "Normal", "légende Moyen : '%s'" % s.mode_labels[&"moyen"].text)
	# M7 / M8 : tout texte visible fait au moins 18 px (cartes, fiche, barre du bas).
	s.cards[0].grab_focus()
	await _frames(14)
	var small: Array[String] = []
	_collect_small_texts(s, small)
	_check(small.is_empty(), "textes visibles >= 18 px (trop petits : %s)" % ", ".join(small))
	# M8 : aucune variante débloquée -> colonne masquée + une note.
	var fp := FakeProfile.new()
	fp.unlocked_spells = []
	var s2 := _spawn(fp)
	await _frames(12)
	var variant_btns := 0
	for row in s2.sheet.focus_rows():
		variant_btns += row.size() - 1
	_check(variant_btns == 0, "aucune variante débloquée : aucun bouton de variante (obtenu %d)" % variant_btns)
	_check(s2.sheet.find_child("VariantsNote", true, false) != null, "note « variantes à débloquer »")
	_check(s.sheet.show_variants, "une variante débloquée : variantes affichées")
	s.queue_free()
	s2.queue_free()
	await _frames(2)


func _collect_small_texts(n: Node, out: Array[String]) -> void:
	if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.strip_edges() != "":
		var l := n as Label
		var fs := l.get_theme_font_size(&"font_size")
		if fs < CharacterCard.MIN_FONT:
			out.append("%s=%d" % [l.text.left(18), fs])
	elif n is Button and (n as Button).is_visible_in_tree() and (n as Button).text.strip_edges() != "":
		var b := n as Button
		if b.get_theme_font_size(&"font_size") < CharacterCard.MIN_FONT:
			out.append("%s=%d" % [b.text.left(18), b.get_theme_font_size(&"font_size")])
	for c in n.get_children():
		_collect_small_texts(c, out)


func _test_touch_long_press() -> void:
	var plat := get_node_or_null("/root/Platform")
	if plat != null:
		plat.set_input_mode(0)
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	_check(_focus() == null or not s.is_ancestor_of(_focus()), "aucun focus en tactile")
	s.cards[0].pressed.emit()
	await _frames(12)
	var b := _variant_button(s, "phoenix")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = b.get_global_rect().get_center()
	b.gui_input.emit(t)
	await _frames(2)
	_check(not s.tooltip.visible, "pas d'infobulle avant l'appui long")
	await get_tree().create_timer(0.6).timeout
	_check(s.tooltip.visible and s.tooltip.text_content().contains("Vaincre le boss"), "infobulle de quête à l'appui long")
	var r := InputEventScreenTouch.new()
	r.pressed = false
	b.gui_input.emit(r)
	await _frames(1)
	_check(s.tooltip.visible, "infobulle maintenue après relâchement (tactile)")
	s.queue_free()
	if plat != null:
		plat.set_input_mode(1)
	await _frames(2)


## Cadrage générique de l'aperçu de la fiche : pour chaque personnage doté d'un SpriteFrames, la boîte opaque
## de la frame idle tient dans le disque (carré), remplit 65-90 % de sa hauteur, est centrée en x et les pieds
## restent au-dessus du bord bas (marge).
func _test_preview_framing() -> void:
	var s := _spawn(FakeProfile.new())
	await _frames(3)
	var framed := 0
	for i in s.characters.size():
		var c: Dictionary = s.characters[i]
		var id := String(c.get("id", "?"))
		s.open_sheet_for(i, false)
		await _frames(2)
		var sh := s.sheet
		var sf_path := String(c.get("sprite_frames", ""))
		var has_sf := sf_path != "" and ResourceLoader.exists(sf_path) and CharacterSheet.idle_anim(load(sf_path)) != &""
		_check(sh.preview_stage != null, "%s : disque d'aperçu absent" % id)
		if sh.preview_stage == null:
			continue
		var box := sh.preview_stage.size
		_check(absf(box.x - box.y) < 1.0, "%s : disque d'aperçu non carré (%s)" % [id, box])
		if not has_sf:
			_check(sh.preview == null, "%s : aperçu sans sprite" % id)
			continue
		_check(sh.preview != null, "%s : aperçu animé absent" % id)
		if sh.preview == null:
			continue
		var r := sh.preview_content_rect()
		var fill := r.size.y / box.y
		_check(Rect2(Vector2.ZERO, box).grow(0.5).encloses(r), "%s : sprite hors du cadre %s dans %s" % [id, r, box])
		_check(fill >= 0.65 and fill <= 0.9, "%s : remplissage %.2f hors 0,65-0,90" % [id, fill])
		_check(absf(r.get_center().x - box.x * 0.5) < 1.0, "%s : sprite décentré (x %.1f / %.1f)" % [id, r.get_center().x, box.x * 0.5])
		_check(r.end.y < box.y - 2.0, "%s : pieds sans marge (%.1f / %.1f)" % [id, r.end.y, box.y])
		framed += 1
	_check(framed >= 1, "aucun aperçu cadré (Ardent attendu)")
	print("cadrage aperçu : %d personnage(s) vérifié(s)" % framed)
	s.queue_free()
	await _frames(2)


func _test_progress() -> void:
	var p: ProgressScreen = PROGRESS.instantiate()
	p.profile = FakeProfile.new()
	add_child(p)
	await _frames(3)
	_check(p.char_cards.size() == _json.size(), "Progression : %d cartes (obtenu %d)" % [_json.size(), p.char_cards.size()])
	var vr := p.get_viewport_rect()
	for c in p.char_cards:
		_check(c.focus_mode == Control.FOCUS_NONE, "Progression : carte %s non focusable" % c.name)
		_check(vr.encloses(c.get_global_rect()), "Progression : carte %s visible sans défilement" % c.name)
	_check(p.rubies_label.text == "1 234", "Progression : rubis '%s'" % p.rubies_label.text)
	_check(p.stats_label.text.contains("Monstres tués : 8 412") and p.stats_label.text.contains("1 h 52"), "Progression : stats '%s'" % p.stats_label.text)
	_check(_focus() == p.back_button, "Progression : focus sur Retour")
	var back := [0]
	p.back_requested.connect(func() -> void: back[0] += 1)
	await _action(&"ui_cancel")
	_check(back[0] == 1, "Progression : ui_cancel → back_requested")
	p.queue_free()
	await _frames(2)
	# Personnage verrouillé à objectif visible : barre de progression de l'objectif sur sa carte.
	var chars: Array = _json.duplicate(true)
	chars.append(TEST_LOCKED.duplicate(true))
	p = PROGRESS.instantiate()
	p.profile = FakeProfile.new()
	p.characters = chars
	add_child(p)
	await _frames(3)
	var lc: Control = p.char_cards.back()
	_check(lc.get_node_or_null("Objective") is ProgressBar, "Progression : barre d'objectif sur le perso verrouillé")
	_check(p.char_cards[0].get_node_or_null("Objective") == null, "Progression : pas de barre sur un perso ouvert")
	p.queue_free()
	await _frames(2)


## Ratios : téléphone 20:9 (largeur logique 2400) et 4:3 (1440) : toutes les cartes dans l'écran,
## au-dessus de la barre des modes, sans chevauchement.
func _test_ratios() -> void:
	for w in [2400.0, 1440.0]:
		var s := _spawn(FakeProfile.new())
		s.set_anchors_preset(Control.PRESET_TOP_LEFT)
		s.size = Vector2(w, 1080.0)
		await _frames(3)
		var area := Rect2(Vector2.ZERO, s.size)
		var modes_y: float = s.mode_buttons[&"facile"].position.y
		for i in s.cards.size():
			var r := s.cards[i].get_rect()
			_check(area.encloses(r) and r.end.y < modes_y, "%d px : carte %d dans l'écran (%s)" % [int(w), i, r])
			_check(r.end.x < s.side_panel.position.x, "%d px : carte %d à gauche de la fiche" % [int(w), i])
			if i > 0:
				_check(not r.intersects(s.cards[i - 1].get_rect()), "%d px : cartes %d/%d sans chevauchement" % [int(w), i - 1, i])
		s.queue_free()
		await _frames(2)
