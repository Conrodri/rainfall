class_name ProgressScreen
extends Control
## Écran « Progression » (docs/Design_Menus.md §3.3) : rubis, modes, personnages, statistiques.
## Lecture seule ; seul « Retour » est focusable. Données : `Profile` (§6.2), lues avec repli
## tant que le lot B n'expose pas toutes les propriétés.

signal back_requested

const RUBY_ICON := "res://assets/sprites/ui/menu/ruby_large.png"
const RUBY_ICON_FALLBACK := "res://assets/sprites/ui/hud/icon_ruby.png"
const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}
const CARD_RATIO := 384.0 / 560.0 ## ratio du cadre DA des cartes (card_front.png)
const GAP := 24.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)

var profile: Object
var characters: Array = []
var back_button: Button
var rubies_label: Label
var stats_label: Label
var next_label: Label ## « Prochain déblocage : … » (1 ligne sous le titre)
var char_cards: Array[Control] = []
var _card_size := CharacterCard.CARD_SIZE

var _title: Label
var _banner: PanelContainer
var _ruby_box: HBoxContainer
var _modes_box: VBoxContainer
var _chars_header: Label
var _chars_grid: GridContainer
var _chars_scroll: ScrollContainer ## la grille défile s'il y a trop de cartes pour la hauteur disponible


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = CharacterCard.default_profile()
	if characters.is_empty(): # une liste peut être injectée avant _ready (tests)
		characters = CharacterCard.load_characters()
	_build()
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	_layout()
	if profile != null and profile.has_signal("changed"):
		profile.connect("changed", refresh)
	var plat := get_node_or_null("/root/Platform")
	if plat == null or not bool(plat.call("is_touch_mode")):
		back_button.grab_focus.call_deferred()
	CharacterCard.play_ui(&"ui.hover", -4.0, 1.15)


func _build() -> void:
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Progression")
	_banner = bn.banner
	_title = bn.label
	add_child(_banner)
	_ruby_box = HBoxContainer.new()
	_ruby_box.add_theme_constant_override("separation", 12)
	_ruby_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ruby_box)
	var icon_path := RUBY_ICON if ResourceLoader.exists(RUBY_ICON) else RUBY_ICON_FALLBACK
	if ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture = load(icon_path)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(96, 96)
		_ruby_box.add_child(ic)
	rubies_label = CharacterCard.make_label("0", 64, UiTheme.COL_PRIMARY_TEXT, 8) # or, comme au titre et au récap
	_ruby_box.add_child(rubies_label)
	next_label = CharacterCard.make_label("", 28, CharacterCard.COL_FOCUS, 5)
	next_label.name = "NextUnlock"
	next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(next_label)

	_modes_box = VBoxContainer.new()
	_modes_box.add_theme_constant_override("separation", 16)
	add_child(_modes_box)

	_chars_header = CharacterCard.make_label("Personnages", 40)
	add_child(_chars_header)
	_chars_grid = GridContainer.new()
	_chars_grid.columns = 3
	_chars_grid.add_theme_constant_override("h_separation", int(GAP))
	_chars_grid.add_theme_constant_override("v_separation", int(GAP))
	_chars_scroll = ScrollContainer.new()
	_chars_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chars_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chars_scroll)
	_chars_scroll.add_child(_chars_grid)

	stats_label = CharacterCard.make_label("", 26, COL_BODY)
	add_child(stats_label)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	back_button.size = back_button.custom_minimum_size
	back_button.add_theme_font_size_override("font_size", 40)
	back_button.pressed.connect(_on_back)
	UiTheme.mark_back(back_button)
	back_button.focus_neighbor_left = NodePath(".")
	back_button.focus_neighbor_right = NodePath(".")
	back_button.focus_neighbor_top = NodePath(".")
	back_button.focus_neighbor_bottom = NodePath(".")
	add_child(back_button)
	refresh()


## Relit le profil et reconstruit les blocs.
func refresh() -> void:
	rubies_label.text = group_thousands(int(CharacterCard.pget(profile, "rubies", 0)))
	var stats: Dictionary = _stats()
	var nxt := EndRunScreen.next_objective(profile, characters)
	next_label.visible = not nxt.is_empty()
	if not nxt.is_empty():
		var line := "Prochain déblocage : %s" % str(nxt.get("title", ""))
		if str(nxt.get("text", "")) != "":
			line += " — %s" % str(nxt["text"])
		if float(nxt.get("progress", -1.0)) > 0.0:
			line += " (%d %%)" % int(round(float(nxt["progress"]) * 100.0))
		next_label.text = line
	for ch in _modes_box.get_children():
		ch.queue_free()
	_modes_box.add_child(CharacterCard.make_label("Modes", 40))
	var best: Dictionary = stats.get("best_time_s", {}) if stats.get("best_time_s", {}) is Dictionary else {}
	var wins: Dictionary = stats.get("victories_by_mode", {}) if stats.get("victories_by_mode", {}) is Dictionary else {}
	for m in MODES:
		_modes_box.add_child(_mode_row(m, best, wins))
	for ch in _chars_grid.get_children():
		ch.queue_free()
	char_cards.clear()
	for c in characters:
		var card := _char_card(c)
		_chars_grid.add_child(card)
		char_cards.append(card)
	if is_inside_tree():
		_layout()
	var parts: Array[String] = [
		"Runs : %s" % group_thousands(int(stats.get("runs", 0))),
		"Victoires : %s" % group_thousands(int(stats.get("victories", 0))),
		"Monstres tués : %s" % group_thousands(int(stats.get("kills", 0))),
		"Temps de jeu : %s" % play_time_text(float(stats.get("play_time_s", 0.0))),
	]
	stats_label.text = " · ".join(parts)


func _stats() -> Dictionary:
	var s: Variant = CharacterCard.pget(profile, "stats", {})
	return s if s is Dictionary else {}


func _mode_row(m: StringName, best: Dictionary, wins: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 88)
	p.add_theme_stylebox_override("panel", CharacterCard.panel_box())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	p.add_child(h)
	var unlocked := CharacterCard.is_mode_unlocked(profile, m)
	var nm := CharacterCard.make_label(MODE_NAMES[m], 36, CharacterCard.COL_TEXT if unlocked else COL_DIM)
	nm.custom_minimum_size = Vector2(180, 0)
	h.add_child(nm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(CharacterCard.make_label("Débloqué" if unlocked else "Terminez Moyen", 26, Color("#9BE29B") if unlocked else CharacterCard.COL_FOCUS, 4))
	var bt: Variant = best.get(String(m), best.get(m, null))
	var info := "Meilleur temps : %s" % (time_text(float(bt)) if bt != null else "—")
	var w: Variant = wins.get(String(m), wins.get(m, null))
	if w != null:
		info += " · Victoires : %d" % int(w)
	v.add_child(CharacterCard.make_label(info, 24, COL_BODY, 4))
	return p


## Carte de personnage : même carte DA que l'écran Nouvelle run (portrait, accent, titre), inerte ;
## verrouillé à objectif visible : texte de l'objectif + barre de progression à l'accent du personnage.
func _char_card(c: Dictionary) -> Control:
	var card := CharacterCard.new()
	var locked := CharacterCard.is_character_locked(profile, c)
	card.setup(c, locked)
	card.make_display_only()
	if locked and not bool(c.get("hidden", false)) and not bool(c.get("unlocked", false)):
		card.set_objective_progress(_objective(String(c.get("id", ""))))
	card.set_card_size(_card_size)
	return card


func _objective(id: String) -> float:
	if profile != null and profile.has_method("objective_progress"):
		return clampf(float(profile.call("objective_progress", StringName(id))), 0.0, 1.0)
	return 0.0


func _layout() -> void:
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}
	var plat := get_node_or_null("/root/Platform")
	if plat != null and plat.has_method("safe_margins"):
		var d: Dictionary = plat.call("safe_margins")
		for k in m:
			m[k] = clampf(float(d.get(k, m[k])), m[k], 160.0) # borné (aperçu mobile multi-écran)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, 92)
	_ruby_box.reset_size()
	var nx: float = m.left + 48
	next_label.position = Vector2(nx, 124)
	next_label.custom_minimum_size.x = vs.x - m.right - nx - 24.0
	next_label.size.x = next_label.custom_minimum_size.x
	_ruby_box.position = Vector2(vs.x - m.right - _ruby_box.get_combined_minimum_size().x, 24)
	var mx: float = m.left + 48
	# Modes : 600 px, réduits (≥ 480) si la zone sûre est étroite pour que la grille tienne.
	var modes_w := clampf(vs.x - m.right - mx - 48 - (3 * 340.0 + 2 * GAP), 480.0, 600.0)
	var gx: float = mx + modes_w + 48
	var grid_w: float = vs.x - m.right - gx
	_chars_header.position = Vector2(gx, 170)
	_chars_scroll.position = Vector2(gx, 230)
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	stats_label.position = Vector2(m.left + 48, back_button.position.y - stats_label.get_combined_minimum_size().y - 16.0)
	var scroll_h := maxf(stats_label.position.y - 16.0 - _chars_scroll.position.y, 160.0)
	# Grille : nombre de colonnes qui donne les plus grandes cartes tenant sans défilement
	# (16 px réservés à la barre) ; au-delà (roster très grand), hauteur plancher et défilement.
	var n := maxi(char_cards.size(), 1)
	var inner_w := grid_w - 16.0
	var best_h := 0.0
	var cols := 1
	for k in range(1, n + 1):
		var rows := ceili(float(n) / k)
		var h := minf((scroll_h - (rows - 1) * GAP) / rows, (inner_w - (k - 1) * GAP) / k / CARD_RATIO)
		if h > best_h + 0.5:
			best_h = h
			cols = k
	var ch := clampf(best_h, 200.0, 420.0)
	_chars_grid.columns = cols
	_card_size = Vector2(floorf(ch * CARD_RATIO), floorf(ch) - 1.0)
	for c in char_cards:
		(c as CharacterCard).set_card_size(_card_size)
	# Grille centrée dans sa colonne (16 px gardés pour la barre de défilement si elle sert).
	var used_w := cols * _card_size.x + (cols - 1) * GAP
	gx += maxf((inner_w - used_w) * 0.5, 0.0)
	grid_w = minf(grid_w, used_w + 16.0)
	_chars_scroll.position.x = gx
	_chars_header.position.x = gx
	_modes_box.position = Vector2(mx, 170)
	_modes_box.custom_minimum_size = Vector2(modes_w, 0)
	_modes_box.size = Vector2(modes_w, 0)
	# ligne de stats juste au-dessus du bouton Retour ; la grille des personnages s'arrête au-dessus d'elle
	_chars_scroll.size = Vector2(grid_w, scroll_h)
	_chars_grid.custom_minimum_size.x = grid_w - 16.0


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		CharacterCard.play_ui(&"ui.click", -6.0, 0.85)
		_on_back()


static func group_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func time_text(sec: float) -> String:
	var t := int(sec)
	return "%02d:%02d" % [t / 60, t % 60]


static func play_time_text(sec: float) -> String:
	var mins := int(sec) / 60
	return "%d h %02d" % [mins / 60, mins % 60] if mins >= 60 else "%d min" % mins
