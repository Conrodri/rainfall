class_name CoopLobbyScreen
extends Control
## Écran de jonction de la coop locale PC (étape 4, docs/multi/Design_Coop.md §6.1-6.2, docs/multi/Archi_Reseau.md §3).
## Ouvert par le bouton « Coop locale » du titre (PC seulement). 1 à 4 joueurs sur le même écran :
## - REJOINDRE : A ou Start sur une manette, Entrée ou Espace au clavier. Le clavier-souris est toujours le joueur 1
##   (inséré en tête, les manettes se décalent) ; une manette = un joueur, jamais deux ;
## - RÉGLER sa carte (avant « Prêt ») : gauche / droite = personnage (débloqués seulement), haut / bas = skin (Base +
##   skins débloqués et livrés) ; LB / RB (ou Tab au clavier) = mode de la partie, pour tous ;
## - PRÊT : A / Start / Entrée de nouveau ; B / Échap annule le « Prêt », puis retire le joueur ;
## - Échap au clavier (clavier non inscrit), B d'une manette non inscrite ou le bouton « Retour » : retour au titre ;
## - LANCEMENT : quand tous les inscrits sont prêts, compte de LAUNCH_S secondes (annulé si quelqu'un rejoint, part
##   ou annule son « Prêt ») ; bouton « Lancer » à la souris pour partir tout de suite.
## Une manette débranchée pendant la jonction libère sa place.
## Variantes de sorts : celles mémorisées au profil pour le personnage (CharacterSheet.resolve_loadout), comme le solo.
## Doublons de personnage autorisés ; le second prend un autre skin débloqué s'il en existe un.
## Rien n'est écrit au profil. Config émise : {character, mode, spells, party: [{kind, device, character, spells, skin}]}
## (App.party_setup_from en fait Main.party_setup).

signal start_requested(config: Dictionary)
signal back_requested

const LAUNCH_S := 2.0
const AXIS_ON := 0.6
const AXIS_OFF := 0.3
const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}
const KBM_KEY := "kbm"
const CARD_W_MIN := 280.0 ## largeur d'une carte (px logiques) : clamp((W - 120 - 3 x 24) / 4, 280, 420), sinon grille 2 x 2
const CARD_W_MAX := 420.0
const CARD_GAP := 24.0
const SIDE_MARGIN := 60.0
const ICON_CHECK := "res://assets/sprites/ui/menu/icon_check.png"

## Joueurs inscrits, ordre = emplacement : {key, kind ("kbm" | "pad"), device, char, skin, ready}.
var slots: Array[Dictionary] = []
var characters: Array = [] ## personnages jouables et débloqués (dictionnaires de characters.json)
var mode: StringName = &"moyen"
var profile: Object = null
var countdown := -1.0 ## secondes avant le lancement (< 0 : pas de compte)
var launched := false

var _cards: Array[PanelContainer] = []
var _card_labels: Array[Dictionary] = [] ## {title, device, char, skin, state, keys (KeyPrompt), check (TextureRect)}
var _card_styles: Array[StyleBoxFlat] = []
var _grid: GridContainer ## 4 colonnes, ou 2 x 2 si 4 cartes de CARD_W_MIN ne tiennent pas (4:3, 5:4)
var _cmd_row: KeyPrompt ## commandes de la manette avec les invites existantes (pad_a, pad_b, pad_lb, pad_rb)
var _mode_label: Label
var _hint: Label
var _count_label: Label
var _start_button: Button
var _axis_latch := {} ## "device:axe" -> -1 / 0 / 1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if profile == null:
		profile = CharacterCard.default_profile()
	if characters.is_empty():
		for c in CharacterCard.load_characters():
			if c is Dictionary and not CharacterCard.is_character_locked(profile, c):
				characters.append(c)
	if characters.is_empty():
		characters.append({"id": "ardent", "name": "Ardent"})
	var lm: Variant = CharacterCard.pget(profile, "last_mode", &"moyen")
	if MODES.has(StringName(str(lm))) and CharacterCard.is_mode_unlocked(profile, StringName(str(lm))):
		mode = StringName(str(lm))
	_build()
	_refresh()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_layout_cards):
		get_viewport().size_changed.disconnect(_layout_cards)


# --- Construction ----------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.025, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 50
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 24)
	add_child(col)
	var title := Label.new()
	title.text = "Coop locale"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	col.add_child(title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.text = "Clavier : Entrée rejoint et valide, Échap annule, Tab change de mode · ◀ ▶ personnage · ▲ ▼ skin"
	# Commandes de la manette avec les invites livrées (le texte ne porte plus les lettres A / B / LB / RB)
	_cmd_row = KeyPrompt.new()
	_cmd_row.set_height(40.0)
	_cmd_row.add_pad_button("pad_a", "A")
	_cmd_row.add_text("Rejoindre, prêt")
	_cmd_row.add_text("·")
	_cmd_row.add_pad_button("pad_b", "B")
	_cmd_row.add_text("Annuler, partir")
	_cmd_row.add_text("·")
	_cmd_row.add_pad_button("pad_lb", "LB")
	_cmd_row.add_pad_button("pad_rb", "RB")
	_cmd_row.add_text("Mode")
	col.add_child(_cmd_row)
	col.move_child(_cmd_row, _hint.get_index())
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	_grid = GridContainer.new()
	_grid.columns = Balance.MULTI_MAX_PLAYERS
	_grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	holder.add_child(_grid)
	for i in Balance.MULTI_MAX_PLAYERS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(CARD_W_MAX, 420)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.055, 0.05, 0.85)
		sb.border_color = Palette.team_color(i)
		sb.set_border_width_all(3)
		sb.set_content_margin_all(18)
		card.add_theme_stylebox_override(&"panel", sb)
		_card_styles.append(sb)
		_grid.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		card.add_child(v)
		var labels := {}
		for key in ["title", "device", "char", "skin"]:
			var l := Label.new()
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 40 if key == "title" else 30 if key == "char" else 24)
			if key == "title":
				l.add_theme_color_override("font_color", Palette.team_color(i))
			v.add_child(l)
			labels[key] = l
		# état : coche (prêt) + texte + invites des boutons à presser
		var st := HBoxContainer.new()
		st.add_theme_constant_override("separation", 10)
		v.add_child(st)
		var chk := TextureRect.new()
		chk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chk.custom_minimum_size = Vector2(44, 44)
		chk.visible = false
		if ResourceLoader.exists(ICON_CHECK):
			chk.texture = load(ICON_CHECK) as Texture2D
		st.add_child(chk)
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", 28)
		st.add_child(sl)
		var keys := KeyPrompt.new()
		keys.set_height(36.0)
		st.add_child(keys)
		labels["state"] = sl
		labels["check"] = chk
		labels["keys"] = keys
		_cards.append(card)
		_card_labels.append(labels)
	_layout_cards()
	get_viewport().size_changed.connect(_layout_cards)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 30)
	col.add_child(bottom)
	var back := Button.new()
	back.text = "Retour"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(220, 64)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func() -> void: back_requested.emit())
	bottom.add_child(back)
	var mode_prev := Button.new()
	mode_prev.text = "◀"
	mode_prev.focus_mode = Control.FOCUS_NONE
	mode_prev.custom_minimum_size = Vector2(64, 64)
	mode_prev.pressed.connect(func() -> void: cycle_mode(-1))
	bottom.add_child(mode_prev)
	_mode_label = Label.new()
	_mode_label.custom_minimum_size = Vector2(300, 0)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 30)
	bottom.add_child(_mode_label)
	var mode_next := Button.new()
	mode_next.text = "▶"
	mode_next.focus_mode = Control.FOCUS_NONE
	mode_next.custom_minimum_size = Vector2(64, 64)
	mode_next.pressed.connect(func() -> void: cycle_mode(1))
	bottom.add_child(mode_next)
	_start_button = Button.new()
	_start_button.text = "Lancer"
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.custom_minimum_size = Vector2(260, 64)
	_start_button.add_theme_font_size_override("font_size", 30)
	_start_button.pressed.connect(launch)
	bottom.add_child(_start_button)
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 30)
	col.add_child(_count_label)


# --- Mise en page ------------------------------------------------------------------------

## Largeur d'une carte pour un écran de largeur `w` : clamp((w - 2 x 60 - 3 x 24) / 4, 280, 420).
static func card_width(w: float) -> float:
	return clampf((w - 2.0 * SIDE_MARGIN - 3.0 * CARD_GAP) / float(Balance.MULTI_MAX_PLAYERS), CARD_W_MIN, CARD_W_MAX)


## 2 x 2 quand les quatre cartes, même à CARD_W_MIN, débordent de la place disponible.
static func uses_two_by_two(w: float) -> bool:
	return float(Balance.MULTI_MAX_PLAYERS) * CARD_W_MIN + 3.0 * CARD_GAP > w - 2.0 * SIDE_MARGIN


func _layout_cards() -> void:
	if _grid == null:
		return
	var w := get_viewport_rect().size.x
	var two := uses_two_by_two(w)
	_grid.columns = 2 if two else Balance.MULTI_MAX_PLAYERS
	var cw := card_width(w) if not two else clampf((w - 2.0 * SIDE_MARGIN - CARD_GAP) / 2.0, CARD_W_MIN, CARD_W_MAX)
	for c in _cards:
		c.custom_minimum_size = Vector2(cw, 300.0 if two else 420.0)


## Colonnes de la grille de cartes (tests).
func grid_columns() -> int:
	return _grid.columns if _grid != null else 0


# --- Lecture ---------------------------------------------------------------------------

static func pad_key(device: int) -> String:
	return "pad:%d" % device


func slot_of_key(key: String) -> int:
	for i in slots.size():
		if str(slots[i]["key"]) == key:
			return i
	return -1


func all_ready() -> bool:
	if slots.is_empty():
		return false
	for s in slots:
		if not bool(s["ready"]):
			return false
	return true


func character_id(slot: int) -> StringName:
	var c: Dictionary = characters[int(slots[slot]["char"]) % characters.size()]
	return StringName(str(c.get("id", "ardent")))


## Skins proposés pour un personnage : « default » (Base) puis les skins débloqués dont les assets sont livrés.
func skin_options(cid: StringName) -> Array[String]:
	var out: Array[String] = ["default"]
	for s in Skins.skins_of(cid):
		var sid := str(s.get("id", ""))
		if sid != "" and Skins.is_unlocked(profile, sid) and Skins.has_assets(cid, sid):
			out.append(sid)
	return out


func skin_name(cid: StringName, sid: String) -> String:
	if sid == "default" or sid == "":
		return "Base"
	for s in Skins.skins_of(cid):
		if str(s.get("id", "")) == sid:
			return str(s.get("name", sid))
	return sid


# --- Entrées -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if launched:
		return
	if handle_event(event):
		get_viewport().set_input_as_handled()


## Traite un événement de manette ou de clavier ; vrai s'il est consommé. Public pour les tests (événements simulés).
func handle_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if not jb.pressed:
			return false
		return _pad_button(jb.device, int(jb.button_index))
	if event is InputEventJoypadMotion:
		return _pad_axis(event as InputEventJoypadMotion)
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return false
		return _key(k)
	return false


func _pad_button(device: int, b: int) -> bool:
	var key := pad_key(device)
	var i := slot_of_key(key)
	match b:
		JOY_BUTTON_A, JOY_BUTTON_START:
			if i < 0:
				join(key, "pad", device)
			else:
				set_ready(i, not bool(slots[i]["ready"]))
			return true
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			if i < 0:
				if b == JOY_BUTTON_B and slots.is_empty():
					back_requested.emit()
				return true
			cancel(i)
			return true
		JOY_BUTTON_DPAD_LEFT:
			return _change_char(i, -1)
		JOY_BUTTON_DPAD_RIGHT:
			return _change_char(i, 1)
		JOY_BUTTON_DPAD_UP:
			return _change_skin(i, -1)
		JOY_BUTTON_DPAD_DOWN:
			return _change_skin(i, 1)
		JOY_BUTTON_LEFT_SHOULDER:
			if i >= 0:
				cycle_mode(-1)
			return true
		JOY_BUTTON_RIGHT_SHOULDER:
			if i >= 0:
				cycle_mode(1)
			return true
	return false


func _pad_axis(m: InputEventJoypadMotion) -> bool:
	if m.axis != JOY_AXIS_LEFT_X and m.axis != JOY_AXIS_LEFT_Y:
		return false
	var lk := "%d:%d" % [m.device, m.axis]
	var prev := int(_axis_latch.get(lk, 0))
	var v := m.axis_value
	if absf(v) < AXIS_OFF:
		_axis_latch[lk] = 0
		return false
	if prev != 0 or absf(v) < AXIS_ON:
		return false
	var dir := 1 if v > 0.0 else -1
	_axis_latch[lk] = dir
	var i := slot_of_key(pad_key(m.device))
	return _change_char(i, dir) if m.axis == JOY_AXIS_LEFT_X else _change_skin(i, dir)


func _key(k: InputEventKey) -> bool:
	var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	var i := slot_of_key(KBM_KEY)
	match code:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if i < 0:
				join(KBM_KEY, "kbm", -1)
			else:
				set_ready(i, not bool(slots[i]["ready"]))
			return true
		KEY_ESCAPE, KEY_BACKSPACE:
			if i < 0:
				back_requested.emit()
			else:
				cancel(i)
			return true
		KEY_A, KEY_LEFT:
			return _change_char(i, -1)
		KEY_D, KEY_RIGHT:
			return _change_char(i, 1)
		KEY_W, KEY_UP:
			return _change_skin(i, -1)
		KEY_S, KEY_DOWN:
			return _change_skin(i, 1)
		KEY_TAB:
			if i >= 0:
				cycle_mode(-1 if k.shift_pressed else 1)
			return true
	return false


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	var i := slot_of_key(pad_key(device))
	if i >= 0:
		leave(i)


# --- Actions -----------------------------------------------------------------------------

## Inscrit un appareil (clavier-souris : toujours en tête). Rend l'emplacement, -1 si plein ou déjà inscrit.
func join(key: String, kind: String, device: int) -> int:
	if slot_of_key(key) >= 0 or slots.size() >= Balance.MULTI_MAX_PLAYERS:
		return -1
	var s := {"key": key, "kind": kind, "device": device, "char": _default_char(), "skin": "", "ready": false}
	var at := 0 if kind == "kbm" else slots.size()
	slots.insert(at, s)
	_pick_skin(at)
	_cancel_countdown()
	_refresh()
	return at


## Retire un joueur (place libérée, les suivants remontent).
func leave(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	slots.remove_at(i)
	_cancel_countdown()
	_refresh()


## B / Échap : annule le « Prêt », sinon retire le joueur.
func cancel(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	if bool(slots[i]["ready"]):
		set_ready(i, false)
	else:
		leave(i)


func set_ready(i: int, on: bool) -> void:
	if i < 0 or i >= slots.size():
		return
	slots[i]["ready"] = on
	if all_ready():
		countdown = LAUNCH_S
	else:
		_cancel_countdown()
	_refresh()


func cycle_mode(dir: int) -> void:
	var idx := MODES.find(mode)
	for k in MODES.size():
		idx = (idx + dir + MODES.size()) % MODES.size()
		if CharacterCard.is_mode_unlocked(profile, MODES[idx]):
			mode = MODES[idx]
			break
	_refresh()


func _change_char(i: int, dir: int) -> bool:
	if i < 0:
		return false
	if bool(slots[i]["ready"]):
		return true
	slots[i]["char"] = (int(slots[i]["char"]) + dir + characters.size()) % characters.size()
	slots[i]["skin"] = ""
	_pick_skin(i)
	_refresh()
	return true


func _change_skin(i: int, dir: int) -> bool:
	if i < 0:
		return false
	if bool(slots[i]["ready"]):
		return true
	var opts := skin_options(character_id(i))
	var cur := opts.find(str(slots[i]["skin"]))
	slots[i]["skin"] = opts[(maxi(cur, 0) + dir + opts.size()) % opts.size()]
	_refresh()
	return true


## Personnage proposé à un nouvel inscrit : le dernier joué (profil), sinon le premier de la liste.
func _default_char() -> int:
	var last := str(CharacterCard.pget(profile, "last_character", ""))
	for i in characters.size():
		if str(characters[i].get("id", "")) == last:
			return i
	return 0


## Skin par défaut : celui équipé au profil ; si un autre joueur a déjà ce personnage avec ce skin, le suivant
## disponible (doublons distingués, Design_Coop §1.1).
func _pick_skin(i: int) -> void:
	var cid := character_id(i)
	var opts := skin_options(cid)
	var eq := Skins.equipped(cid, profile)
	var want := eq if eq != "" and opts.has(eq) else "default"
	var start := maxi(opts.find(want), 0)
	for k in opts.size():
		var cand: String = opts[(start + k) % opts.size()]
		var taken := false
		for j in slots.size():
			if j != i and character_id(j) == cid and str(slots[j]["skin"]) == cand:
				taken = true
				break
		if not taken:
			slots[i]["skin"] = cand
			return
	slots[i]["skin"] = want


## Cadre de la carte `i` : épaisseur et opacité de la teinte d'équipe (inscrit : 60 %, prêt : 100 % et plus épais).
func _set_border(i: int, width: int, alpha: float) -> void:
	if i >= _card_styles.size():
		return
	var sb := _card_styles[i]
	sb.set_border_width_all(width)
	sb.border_color = Color(Palette.team_color(i), alpha)


func _cancel_countdown() -> void:
	countdown = -1.0


func _process(delta: float) -> void:
	if launched or countdown < 0.0:
		return
	countdown -= delta
	if countdown <= 0.0:
		launch()
	else:
		_count_label.text = "Lancement dans %d…" % ceili(countdown)


## Config de lancement (App.start_run) : joueur 1 = premier inscrit.
func party_config() -> Dictionary:
	var party: Array = []
	for i in slots.size():
		var cid := character_id(i)
		var c: Dictionary = characters[int(slots[i]["char"]) % characters.size()]
		party.append({"kind": str(slots[i]["kind"]), "device": int(slots[i]["device"]), "character": cid,
			"spells": CharacterSheet.resolve_loadout(profile, c), "skin": str(slots[i]["skin"])})
	var first: Dictionary = party[0] if not party.is_empty() else {"character": &"ardent", "spells": {}}
	return {"character": first["character"], "mode": mode, "spells": first["spells"], "party": party}


func launch() -> void:
	if launched or slots.is_empty():
		return
	launched = true
	countdown = -1.0
	start_requested.emit(party_config())


# --- Affichage ---------------------------------------------------------------------------

func _refresh() -> void:
	if _cards.is_empty():
		return
	for i in _cards.size():
		var l: Dictionary = _card_labels[i]
		(l["title"] as Label).text = "Joueur %s" % Palette.team_glyph(i)
		var st_keys := l["keys"] as KeyPrompt
		var st_check := l["check"] as TextureRect
		st_keys.clear_row()
		st_check.visible = false
		_set_border(i, 3, 0.6)
		if i >= slots.size():
			(l["device"] as Label).text = "Entrée : clavier-souris" if slot_of_key(KBM_KEY) < 0 else ""
			(l["char"] as Label).text = "Libre"
			(l["skin"] as Label).text = ""
			(l["state"] as Label).text = "Rejoindre"
			st_keys.add_pad_button("pad_a", "A")
			st_keys.add_text("/")
			st_keys.add_pad_button("pad_start", "Start", "Start")
			_cards[i].modulate = Color(1, 1, 1, 0.55)
			continue
		var s: Dictionary = slots[i]
		var cid := character_id(i)
		var c: Dictionary = characters[int(s["char"]) % characters.size()]
		(l["device"] as Label).text = "Clavier-souris" if str(s["kind"]) == "kbm" else "Manette %d" % (int(s["device"]) + 1)
		var is_ready := bool(s["ready"])
		(l["char"] as Label).text = ("%s" if is_ready else "◀  %s  ▶") % str(c.get("name", cid))
		(l["skin"] as Label).text = "Skin : %s" % skin_name(cid, str(s["skin"]))
		(l["state"] as Label).text = "PRÊT" if is_ready else "Prêt"
		(l["state"] as Label).add_theme_color_override("font_color", Palette.team_color(i) if is_ready else Color(0.95, 0.93, 0.88))
		if is_ready: # cadre épais plein, coche, invite d'annulation
			st_check.visible = st_check.texture != null
			_set_border(i, 6, 1.0)
			if str(s["kind"]) == "pad":
				st_keys.add_pad_button("pad_b", "B")
			else:
				st_keys.add_key_button("Échap")
			st_keys.add_text("annuler")
		elif str(s["kind"]) == "pad":
			st_keys.add_pad_button("pad_a", "A")
		else:
			st_keys.add_key_button("Entrée")
		_cards[i].modulate = Color.WHITE
	_mode_label.text = "Mode : %s" % MODE_NAMES.get(mode, String(mode))
	_start_button.disabled = slots.is_empty()
	if countdown < 0.0:
		_count_label.text = "En attente des joueurs" if slots.is_empty() else ("Tout le monde est prêt" if all_ready() else "Chacun appuie sur A / Entrée quand il est prêt")
