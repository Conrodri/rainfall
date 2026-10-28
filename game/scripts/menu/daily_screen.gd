class_name DailyScreen
extends Control
## Écran « Défi du jour » : personnage imposé, mode Moyen, même plan de run pour tous aujourd'hui (graine = date locale).
## Montre l'état du jour (essai compté ou non, meilleur résultat) et la série. Hors ligne : aucun classement.
## « Lancer » émet `start_requested(config)` (format App.start_run, avec `seed` et `daily`). Règles : DailyChallenge.

signal start_requested(config: Dictionary)
signal back_requested

const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const PANEL_W := 1280.0
const PORTRAIT_PX := 360.0
const TEXT_MIN_W := 700.0

## Profil (autoload par défaut ; un objet factice peut être injecté avant _ready).
var profile: Object
var key := 0 ## jour affiché (AAAAMMJJ) ; 0 = aujourd'hui
var config: Dictionary = {}
var start_button: Button
var back_button: Button
var status_label: Label
var best_label: Label
var streak_label: Label
var reward_label: Label
var rules_label: Label
var char_label: Label
var portrait: TextureRect

var _banner: PanelContainer
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = Profile
	if key == 0:
		key = DailyChallenge.today_key()
	config = DailyChallenge.config_for(key)
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Défi du jour")
	_banner = bn.banner
	add_child(_banner)
	_build_panel()
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	back_button.size = back_button.custom_minimum_size
	back_button.add_theme_font_size_override(&"font_size", 40)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	UiTheme.mark_back(back_button)
	add_child(back_button)
	start_button = Button.new()
	start_button.name = "Start"
	start_button.custom_minimum_size = Vector2(600, 96)
	start_button.size = start_button.custom_minimum_size
	start_button.add_theme_font_size_override(&"font_size", 40)
	start_button.pressed.connect(_on_start)
	add_child(start_button)
	UiTheme.apply(self)
	UiTheme.primary(start_button)
	UiTheme.mark_confirm(start_button)
	UiTheme.hook_sounds(self)
	start_button.focus_neighbor_left = start_button.get_path_to(back_button)
	start_button.focus_neighbor_right = start_button.get_path_to(start_button)
	back_button.focus_neighbor_right = back_button.get_path_to(start_button)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	for b in [start_button, back_button]:
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
	resized.connect(_layout)
	refresh()
	if profile.has_signal(&"changed"):
		profile.connect(&"changed", refresh)
	if not Platform.is_touch_mode():
		start_button.grab_focus.call_deferred()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override(&"panel", CharacterCard.panel_box(Color("#2B3340"), CharacterCard.COL_BORDER, 2, 0.9))
	add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 40)
	_panel.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 8)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(left)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	left.add_child(portrait)
	char_label = CharacterCard.make_label("", 40, UiTheme.COL_PRIMARY_TEXT, 6)
	char_label.name = "Character"
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(char_label)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override(&"separation", 14)
	h.add_child(v)
	rules_label = _line(v, 26, COL_BODY, "Rules")
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label = _line(v, 32, UiTheme.COL_PRIMARY_TEXT, "Status")
	best_label = _line(v, 28, COL_BODY, "Best")
	streak_label = _line(v, 28, COL_BODY, "Streak")
	reward_label = _line(v, 26, CharacterCard.COL_FOCUS, "Reward")
	for l in [status_label, best_label, streak_label, reward_label]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _line(parent: Control, size_px: int, col: Color, nm: String) -> Label:
	var l := CharacterCard.make_label("", size_px, col, 5)
	l.name = nm
	l.custom_minimum_size.x = TEXT_MIN_W # largeur plancher : sans elle, le retour à la ligne calcule une hauteur énorme
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


## Relit le profil et met les textes à jour.
func refresh() -> void:
	var cid := str(config.get("character", "ardent"))
	for c in CharacterCard.load_characters():
		if str(c.get("id", "")) == cid:
			portrait.texture = CharacterCard.portrait_texture(c)
			char_label.text = str(c.get("name", cid))
	rules_label.text = "%s · Moyen · sorts de base. Même personnage, mêmes étages et mêmes boss pour tous aujourd'hui." % DailyChallenge.key_text(key)
	var tries := DailyChallenge.tries(profile, key)
	var counted := DailyChallenge.is_counted(profile, key)
	status_label.text = "Essai du jour : fait (%d essai%s)" % [tries, "s" if tries > 1 else ""] if counted else "Essai du jour : à faire"
	var best := DailyChallenge.best_of_day(profile, key)
	best_label.text = "Meilleur résultat : %s" % DailyChallenge.result_text(best) if not best.is_empty() else "Meilleur résultat : aucun"
	var streak := DailyChallenge.current_streak(profile, key)
	var rec := DailyChallenge.best_streak(profile)
	streak_label.text = "Série : %d jour%s consécutif%s · record %d" % [streak, "s" if streak > 1 else "", "s" if streak > 1 else "", rec]
	if counted:
		reward_label.text = "Récompense du jour déjà reçue. Rejouer ne compte plus, mais garde votre meilleur résultat."
		start_button.text = "Rejouer sans compter"
	else:
		var next_streak := DailyChallenge.current_streak(profile, key) + 1
		reward_label.text = "Récompense du premier essai : %d à %d rubis (série %d)" % [Balance.daily_rubies(next_streak, false), Balance.daily_rubies(next_streak, true), next_streak]
		start_button.text = "Lancer le défi"
	if is_inside_tree():
		_layout()


func _on_start() -> void:
	start_requested.emit(config.duplicate(true))


func _layout() -> void:
	if _banner == null:
		return
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}
	var d: Dictionary = Platform.safe_margins()
	for k in m:
		m[k] = clampf(float(d.get(k, m[k])), m[k], 160.0)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, maxf(92.0, _banner.get_combined_minimum_size().y))
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	start_button.position = Vector2(vs.x - m.right - start_button.size.x, vs.y - m.bottom - start_button.size.y)
	var top: float = _banner.position.y + _banner.size.y + 24.0
	var w: float = minf(PANEL_W, vs.x - float(m.left) - float(m.right))
	var h: float = start_button.position.y - 24.0 - top
	_panel.size = Vector2(w, h)
	_panel.position = Vector2((vs.x - w) * 0.5, top)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
