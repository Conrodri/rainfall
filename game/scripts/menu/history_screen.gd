class_name HistoryScreen
extends Control
## Écran « Historique » : toutes les runs terminées (Profile.history, plafond Profile.HISTORY_MAX), en cartes compactes
## (personnage, résultat, date, temps, monstres tués, objets). Tri : plus récentes (défaut), victoire la plus rapide
## (runs avec le boss de l'étage 5 tué : speedruns), plus d'objets, partie la plus longue / la plus courte. Filtre par
## personnage. Clic / toucher / A sur une carte = détail complet (stats, déblocages, objets avec icônes).
## Quatre onglets (ex-écran Progression supprimé) : « Parties » (cet historique, défaut), « Records » (meilleur temps par
## personnage et par mode, clic = BestRunsPanel), « Objets » (catalogue et déblocages), « Skins » (équiper / retirer) : voir
## CollectionView. Lecture seule hors équipement de skin. Aucune position codée en dur : marges de la zone sûre, cartes pleine largeur.

signal back_requested

const SORT_RECENT := &"recent"
const SORT_FASTEST := &"fastest_win"
const SORT_ITEMS := &"items"
const SORT_LONGEST := &"longest"
const SORT_SHORTEST := &"shortest"
const SORTS: Array[StringName] = [SORT_RECENT, SORT_FASTEST, SORT_ITEMS, SORT_LONGEST, SORT_SHORTEST]
const SORT_NAMES := {
	SORT_RECENT: "Plus récentes", SORT_FASTEST: "Victoire la plus rapide", SORT_ITEMS: "Plus d'objets",
	SORT_LONGEST: "Partie la plus longue", SORT_SHORTEST: "Partie la plus courte",
}
const SORT_HINTS := {
	SORT_RECENT: "", SORT_FASTEST: "Speedruns : seules les runs où le boss de l'étage 5 est tué, classées par temps d'abattage.",
	SORT_ITEMS: "", SORT_LONGEST: "Temps de jeu actif, du plus long au plus court.", SORT_SHORTEST: "Temps de jeu actif, du plus court au plus long.",
}
const TAB_RUNS := 0
const TAB_RECORDS := 1
const TAB_ITEMS := 2
const TAB_SKINS := 3
const TAB_NAMES: Array[String] = ["Parties", "Records", "Objets", "Skins"]
const MODE_NAMES := {"facile": "Facile", "moyen": "Moyen", "difficile": "Difficile"}
const CARD_H := 132.0
const GAP := 12.0
const ICON := 64.0
const PORTRAIT := 104.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_WIN := Color("#FFE9A8")
const COL_LOSS := Color("#FF8A70")

## Profil (autoload par défaut ; un objet factice portant `history` peut être injecté avant _ready).
var profile: Object
var back_button: Button
var count_label: Label
var filter_button: Button
var sort_buttons: Array[Button] = []
var cards: Array[Button] = []
var sort_id: StringName = SORT_RECENT
var character_filter := "" ## "" = tous
var tab := TAB_RUNS
var tab_buttons: Array[Button] = []
var views: Array[CollectionView] = [] ## indexées par onglet - 1 (Records, Objets, Skins)
var best_panel: BestRunsPanel = null ## panneau « Meilleures runs » ouvert (onglet Records)
var detail: Control = null ## feuille de détail ouverte (null sinon)

var _banner: PanelContainer
var _hint: Label
var _empty: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _bar: HBoxContainer
var _tabs_bar: HBoxContainer
var _names := {} ## id perso -> nom
var _chars := {} ## id perso -> dictionnaire characters.json


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = Profile
	for c in CharacterCard.load_characters():
		if c is Dictionary:
			_chars[str(c.get("id", ""))] = c
			_names[str(c.get("id", ""))] = str(c.get("name", "?"))
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Historique")
	_banner = bn.banner
	add_child(_banner)
	count_label = CharacterCard.make_label("", 34, UiTheme.COL_PRIMARY_TEXT, 6)
	count_label.name = "Count"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(count_label)
	_tabs_bar = HBoxContainer.new()
	_tabs_bar.name = "Tabs"
	_tabs_bar.add_theme_constant_override(&"separation", 12)
	add_child(_tabs_bar)
	for i in TAB_NAMES.size():
		var tb := Button.new()
		tb.name = "Tab" + TAB_NAMES[i]
		tb.text = TAB_NAMES[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(210, 64)
		tb.add_theme_font_size_override(&"font_size", 28)
		tb.pressed.connect(show_tab.bind(i))
		_tabs_bar.add_child(tb)
		tab_buttons.append(tb)
	_bar = HBoxContainer.new()
	_bar.name = "SortBar"
	_bar.add_theme_constant_override(&"separation", 10)
	add_child(_bar)
	for sid in SORTS:
		var b := Button.new()
		b.name = "Sort_" + String(sid)
		b.text = SORT_NAMES[sid]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override(&"font_size", 26)
		b.pressed.connect(set_sort.bind(sid))
		_bar.add_child(b)
		sort_buttons.append(b)
	filter_button = Button.new()
	filter_button.name = "Filter"
	filter_button.custom_minimum_size = Vector2(0, 72)
	filter_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_button.clip_text = true
	filter_button.add_theme_font_size_override(&"font_size", 26)
	filter_button.pressed.connect(cycle_filter)
	_bar.add_child(filter_button)
	_hint = CharacterCard.make_label("", 22, COL_DIM, 4)
	_hint.name = "Hint"
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", int(GAP))
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = CharacterCard.make_label("Aucune run enregistrée pour l'instant.", 36, COL_DIM, 5)
	_empty.name = "Empty"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	var chars_sorted: Array = CharacterCard.sorted_by_difficulty(CharacterCard.load_characters())
	for k in [CollectionView.Kind.RECORDS, CollectionView.Kind.ITEMS, CollectionView.Kind.SKINS]:
		var cv := CollectionView.create(k, profile, chars_sorted)
		cv.visible = false
		if k == CollectionView.Kind.RECORDS:
			cv.character_chosen.connect(open_best_runs)
		add_child(cv)
		views.append(cv)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	back_button.size = back_button.custom_minimum_size
	back_button.add_theme_font_size_override(&"font_size", 40)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	UiTheme.mark_back(back_button)
	add_child(back_button)
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	refresh()
	if profile.has_signal(&"changed"):
		profile.connect(&"changed", refresh)
	if not Platform.is_touch_mode():
		(cards[0] if not cards.is_empty() else back_button).grab_focus.call_deferred()


# --- Données et tris (statiques : testables sans interface) --------------------------------------------------------

## Entrées du profil, de la plus récente à la plus ancienne.
static func entries_of(p: Object) -> Array:
	var h: Variant = p.get("history") if p != null else []
	return h if h is Array else []


## Entrées triées / filtrées. Renvoie des références (jamais de copie) sur les dictionnaires de l'historique.
## `fastest_win` ne garde que les runs où le boss de l'étage 5 est tué ; égalités départagées par la plus récente.
static func sorted_entries(history: Array, sort: StringName, cid := "") -> Array:
	var rows: Array = []
	for i in history.size():
		var e: Variant = history[i]
		if not (e is Dictionary):
			continue
		if cid != "" and str(e.get("character", "")) != cid:
			continue
		if sort == SORT_FASTEST and not (bool(e.get("final_boss_killed", false)) and float(e.get("win_time_s", 0.0)) > 0.0):
			continue
		rows.append([e, i])
	rows.sort_custom(func(a, b) -> bool:
		var ea: Dictionary = a[0]
		var eb: Dictionary = b[0]
		var ka := 0.0
		var kb := 0.0
		match sort:
			SORT_FASTEST:
				ka = float(ea.get("win_time_s", 0.0))
				kb = float(eb.get("win_time_s", 0.0))
			SORT_ITEMS:
				ka = -float(ea.get("n_items", 0))
				kb = -float(eb.get("n_items", 0))
			SORT_LONGEST:
				ka = -float(ea.get("time_s", 0.0))
				kb = -float(eb.get("time_s", 0.0))
			SORT_SHORTEST:
				ka = float(ea.get("time_s", 0.0))
				kb = float(eb.get("time_s", 0.0))
			_:
				ka = -float(a[1])
				kb = -float(b[1])
		if not is_equal_approx(ka, kb):
			return ka < kb
		return int(a[1]) > int(b[1]))
	var out: Array = []
	for r in rows:
		out.append(r[0])
	return out


## Personnages présents dans l'historique (ordre de première apparition, du plus récent au plus ancien).
static func characters_in(history: Array) -> Array[String]:
	var out: Array[String] = []
	for i in range(history.size() - 1, -1, -1):
		var cid := str((history[i] as Dictionary).get("character", "")) if history[i] is Dictionary else ""
		if cid != "" and not out.has(cid):
			out.append(cid)
	return out


static func time_text(sec: float) -> String:
	var t := int(sec)
	if t >= 3600:
		return "%d:%02d:%02d" % [t / 3600, (t % 3600) / 60, t % 60]
	return "%02d:%02d" % [t / 60, t % 60]


static func date_text(iso: String) -> String:
	var d := BestRunsPanel.date_text(iso)
	if d == "":
		return "Date inconnue"
	return d + ((" " + iso.substr(11, 5)) if iso.length() >= 16 else "")


static func result_text(e: Dictionary) -> String:
	var stage := int(e.get("stage", 1))
	if bool(e.get("victory", false)):
		return "Victoire" + (" (étage %d)" % stage if stage > 5 else "")
	if str(e.get("reason", "")) == "abandon":
		return "Abandon — étage %d" % stage
	return "Défaite — étage %d" % stage


# --- Interface -------------------------------------------------------------------------------------------------------

func set_sort(sid: StringName) -> void:
	sort_id = sid
	refresh()


## Passe au personnage suivant du filtre (puis « Tous »).
func cycle_filter() -> void:
	var chars := characters_in(entries_of(profile))
	if character_filter == "":
		character_filter = chars[0] if not chars.is_empty() else ""
	else:
		var i := chars.find(character_filter)
		character_filter = chars[i + 1] if i >= 0 and i + 1 < chars.size() else ""
	refresh()


## Relit le profil et reconstruit la liste.
func show_tab(t: int) -> void:
	tab = clampi(t, 0, TAB_NAMES.size() - 1)
	refresh()


## Ouvre le panneau « Meilleures runs » du personnage (modal ; Échap / B / Fermer le referme).
func open_best_runs(c: Dictionary) -> void:
	if best_panel != null and is_instance_valid(best_panel):
		return
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	best_panel = BestRunsPanel.create(c, profile)
	var from_id := "Record_" + str(c.get("id", ""))
	best_panel.closed.connect(func() -> void:
		best_panel = null
		for cell in views[0].cells:
			if cell.name == from_id and is_inside_tree():
				cell.grab_focus.call_deferred())
	add_child(best_panel)


func refresh() -> void:
	for i in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i == tab)
	for i in views.size():
		views[i].visible = tab == i + 1
		if tab == i + 1:
			views[i].refresh()
	var on_runs := tab == TAB_RUNS
	_bar.visible = on_runs
	_hint.visible = on_runs
	_scroll.visible = on_runs
	if not on_runs:
		_empty.visible = false
		count_label.text = views[tab - 1].count_text
		_layout()
		return
	var hist := entries_of(profile)
	if character_filter != "" and not characters_in(hist).has(character_filter):
		character_filter = ""
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	cards.clear()
	for i in sort_buttons.size():
		sort_buttons[i].set_pressed_no_signal(SORTS[i] == sort_id)
	filter_button.text = "Tous les personnages" if character_filter == "" else str(_names.get(character_filter, character_filter))
	var rows := sorted_entries(hist, sort_id, character_filter)
	count_label.text = "%d run%s" % [rows.size(), "s" if rows.size() > 1 else ""]
	_hint.text = str(SORT_HINTS[sort_id])
	_empty.visible = rows.is_empty()
	_empty.text = "Aucune run enregistrée pour l'instant." if hist.is_empty() else (
		"Aucune victoire sur le boss de l'étage 5 pour l'instant." if sort_id == SORT_FASTEST else "Aucune run pour ce filtre.")
	var rank := 0
	for e in rows:
		rank += 1
		var card := _make_card(e, rank)
		_list.add_child(card)
		cards.append(card)
	_scroll.scroll_vertical = 0
	_layout()


func _make_card(e: Dictionary, rank: int) -> Button:
	var win := bool(e.get("victory", false))
	var b := Button.new()
	b.name = "Run_%d" % rank
	b.set_meta(&"entry", e)
	b.custom_minimum_size = Vector2(0, CARD_H)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := CharacterCard.panel_box(Color("#3a3220") if win else Color("#2B3340"),
		CharacterCard.COL_FOCUS if win else CharacterCard.COL_BORDER, 2, 0.9)
	for st in [&"normal", &"hover", &"pressed", &"disabled"]:
		b.add_theme_stylebox_override(st, box)
	b.add_theme_stylebox_override(&"focus", CharacterCard.focus_box())
	b.pressed.connect(open_detail.bind(e))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.add_theme_constant_override(&"separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if sort_id == SORT_FASTEST:
		var rk := CharacterCard.make_label("#%d" % rank, 40, COL_WIN, 6)
		rk.name = "Rank"
		rk.custom_minimum_size.x = 84
		rk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(rk)
	h.add_child(_portrait(e, PORTRAIT))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override(&"separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var cid := str(e.get("character", ""))
	var nm := CharacterCard.make_label(str(_names.get(cid, cid.capitalize())), 32, COL_WIN, 5)
	nm.name = "Name"
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var rs := CharacterCard.make_label(result_text(e), 26, COL_WIN if win else COL_LOSS, 4)
	rs.name = "Result"
	v.add_child(rs)
	var meta := CharacterCard.make_label("%s · %s" % [MODE_NAMES.get(str(e.get("mode", "")), str(e.get("mode", "")).capitalize()), date_text(str(e.get("date", "")))], 21, COL_DIM, 3)
	meta.name = "Meta"
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(meta)
	var r := VBoxContainer.new()
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_theme_constant_override(&"separation", 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(r)
	var show_win := sort_id == SORT_FASTEST and float(e.get("win_time_s", 0.0)) > 0.0
	var tl := CharacterCard.make_label(time_text(float(e.get("win_time_s", 0.0)) if show_win else float(e.get("time_s", 0.0))), 44, COL_WIN, 6)
	tl.name = "Time"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(tl)
	var sub := ("Boss final tué · run %s" % time_text(float(e.get("time_s", 0.0)))) if show_win else (
		"Boss final tué en %s" % time_text(float(e.get("win_time_s", 0.0))) if bool(e.get("final_boss_killed", false)) else "")
	if sub != "":
		var sl := CharacterCard.make_label(sub, 19, CharacterCard.COL_FOCUS, 3)
		sl.name = "WinTime"
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(sl)
	var st := CharacterCard.make_label("%s monstres · %d objets · niv. %d" % [BestRunsPanel.group_thousands(int(e.get("kills", 0))),
		int(e.get("n_items", 0)), int(e.get("level", 0))], 21, COL_BODY, 3)
	st.name = "Stats"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(st)
	return b


func _portrait(e: Dictionary, px: float) -> Control:
	var tr := TextureRect.new()
	tr.name = "Portrait"
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c: Dictionary = _chars.get(str(e.get("character", "")), {})
	if not c.is_empty():
		var sk := str(e.get("skin", ""))
		tr.texture = CharacterCard.portrait_info(c, sk if sk != "" else "-").tex
	return tr


# --- Détail d'une run ------------------------------------------------------------------------------------------------

func open_detail(e: Dictionary) -> void:
	close_detail()
	var root := Control.new()
	root.name = "Detail"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 20
	add_child(root)
	detail = root
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed or ev is InputEventScreenTouch and ev.pressed:
			close_detail())
	root.add_child(dim)
	var sheet := PanelContainer.new()
	sheet.name = "Sheet"
	sheet.add_theme_stylebox_override("panel", CharacterCard.panel_box())
	root.add_child(sheet)
	var vs := size if size.x > 0 else get_viewport_rect().size
	var w := minf(vs.x - 96.0, 1500.0)
	var hh := minf(vs.y - 64.0, 940.0)
	sheet.custom_minimum_size = Vector2(w, hh)
	sheet.size = Vector2(w, hh)
	sheet.position = ((vs - sheet.size) * 0.5).floor()
	var mg := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 28)
	sheet.add_child(mg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	mg.add_child(col)
	# En-tête : portrait, nom, résultat.
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 18)
	col.add_child(head)
	head.add_child(_portrait(e, 112))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	var cid := str(e.get("character", ""))
	var win := bool(e.get("victory", false))
	hv.add_child(CharacterCard.make_label(str(_names.get(cid, cid.capitalize())), 46))
	var rl := CharacterCard.make_label("%s · %s · %s" % [result_text(e), MODE_NAMES.get(str(e.get("mode", "")), str(e.get("mode", ""))),
		date_text(str(e.get("date", "")))], 26, COL_WIN if win else COL_LOSS, 4)
	rl.name = "Result"
	rl.clip_text = true
	rl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hv.add_child(rl)
	# Corps défilant : stats, déblocages, objets.
	var sc := ScrollContainer.new()
	sc.name = "Body"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 14)
	sc.add_child(body)
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 4)
	body.add_child(grid)
	var rows: Array = [
		["Temps de jeu", time_text(float(e.get("time_s", 0.0)))],
		["Boss final", ("tué en " + time_text(float(e.get("win_time_s", 0.0)))) if bool(e.get("final_boss_killed", false)) else "non tué"],
		["Étage atteint", str(int(e.get("stage", 1)))],
		["Difficulté finale", "D %s" % CharacterCard.fmt_num(float(e.get("difficulty", 0.0)))],
		["Monstres tués", BestRunsPanel.group_thousands(int(e.get("kills", 0)))],
		["Niveau", str(int(e.get("level", 0)))],
		["Or restant", BestRunsPanel.group_thousands(int(e.get("gold", 0)))],
		["Rubis gagnés", BestRunsPanel.group_thousands(int(e.get("rubies", 0)))],
	]
	for r in rows:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 0)
		cell.add_child(CharacterCard.make_label(r[0], 20, COL_DIM, 3))
		cell.add_child(CharacterCard.make_label(r[1], 32, COL_BODY, 5))
		grid.add_child(cell)
	body.add_child(CharacterCard.make_label("Déblocages", 28, CharacterCard.COL_FOCUS, 4))
	var unl: Array = e.get("unlocks", []) if e.get("unlocks") is Array else []
	if unl.is_empty():
		body.add_child(CharacterCard.make_label("Aucun", 24, COL_DIM, 4))
	for u in unl:
		var row := HBoxContainer.new()
		row.name = "Unlock"
		row.add_theme_constant_override(&"separation", 12)
		var ip := EndRunScreen.unlock_icon_path(StringName(str(u)))
		if ip != "" and ResourceLoader.exists(ip):
			var ic := TextureRect.new()
			ic.texture = load(ip) as Texture2D
			ic.custom_minimum_size = Vector2(56, 56)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			row.add_child(ic)
		row.add_child(CharacterCard.make_label(EndRunScreen.unlock_text(StringName(str(u))), 28, COL_WIN, 4))
		body.add_child(row)
	var omens: Dictionary = e.get("omens", {}) if e.get("omens") is Dictionary else {}
	if not omens.is_empty(): # champ optionnel : absent des runs d'avant les présages
		body.add_child(CharacterCard.make_label("Présages", 28, CharacterCard.COL_FOCUS, 4))
		var stages: Array = omens.keys()
		stages.sort_custom(func(a: Variant, b: Variant) -> bool: return int(str(a)) < int(str(b)))
		for st in stages:
			var oid := StringName(str(omens[st]))
			var orow := HBoxContainer.new()
			orow.name = "Omen_%s" % str(st)
			orow.add_theme_constant_override(&"separation", 12)
			var otex: Texture2D = Omens.icon_of(oid)
			if otex != null:
				var oic := TextureRect.new()
				oic.texture = otex
				oic.custom_minimum_size = Vector2(56, 56)
				oic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				oic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				oic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				orow.add_child(oic)
			var oname := Omens.omen_name(oid)
			orow.add_child(CharacterCard.make_label("Étage %d : %s" % [int(str(st)), oname if oname != "" else str(oid)], 28, COL_BODY, 4))
			body.add_child(orow)
	body.add_child(CharacterCard.make_label("Objets (%d)" % int(e.get("n_items", 0)), 28, CharacterCard.COL_FOCUS, 4))
	var flow := HFlowContainer.new()
	flow.name = "Items"
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(flow)
	var items: Dictionary = e.get("items", {}) if e.get("items") is Dictionary else {}
	if items.is_empty():
		flow.add_child(CharacterCard.make_label("Aucun", 24, COL_DIM, 4))
	for id in items:
		flow.add_child(_item_cell(str(id), int(items[id])))
	var close := Button.new()
	close.name = "Close"
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(300, 80)
	close.add_theme_font_size_override(&"font_size", 38)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_detail)
	UiTheme.mark_back(close)
	for side in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
		close.set(side, NodePath("."))
	col.add_child(close)
	UiTheme.apply(root)
	UiTheme.hook_sounds(root)
	close.grab_focus.call_deferred()


func close_detail() -> void:
	if detail != null and is_instance_valid(detail):
		var d := detail
		detail = null
		remove_child(d)
		d.queue_free()
		if not cards.is_empty() and not Platform.is_touch_mode():
			cards[0].grab_focus.call_deferred()


func _item_cell(id: String, stacks: int) -> Control:
	var it := ItemDB.get_item(id)
	var cell := Control.new()
	cell.name = "Item_" + id
	cell.custom_minimum_size = Vector2(ICON, ICON)
	cell.tooltip_text = "%s%s" % [str(it.get("name", id)), (" ×%d" % stacks) if stacks > 1 else ""]
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_child(ItemBar.quality_backing(it.get("quality", "commun"), 6))
	var path: String = ItemBar.ITEM_ICON % id
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
	else:
		var f := CharacterCard.make_label(str(it.get("name", id)).left(2), 22, COL_BODY, 4)
		f.set_anchors_preset(Control.PRESET_FULL_RECT)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(f)
	if stacks > 1:
		var n := CharacterCard.make_label("×%d" % stacks, 20, COL_WIN, 5)
		n.name = "Stacks"
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cell.add_child(n)
	return cell


# --- Disposition et focus --------------------------------------------------------------------------------------------

func _wire_focus() -> void:
	if back_button == null:
		return
	var tab_btn: Button = tab_buttons[tab]
	for i in tab_buttons.size():
		var tb := tab_buttons[i]
		tb.focus_neighbor_left = tb.get_path_to(tab_buttons[i - 1] if i > 0 else tb)
		tb.focus_neighbor_right = tb.get_path_to(tab_buttons[i + 1] if i + 1 < tab_buttons.size() else tb)
		tb.focus_neighbor_top = tb.get_path_to(tb)
	if tab != TAB_RUNS:
		var vc := views[tab - 1]
		var cols := maxi(vc.columns, 1)
		var cl := vc.cells
		for i in cl.size():
			var c := cl[i]
			c.focus_neighbor_left = c.get_path_to(cl[i - 1] if i % cols != 0 else c)
			c.focus_neighbor_right = c.get_path_to(cl[i + 1] if i % cols != cols - 1 and i + 1 < cl.size() else c)
			c.focus_neighbor_top = c.get_path_to(cl[i - cols] if i - cols >= 0 else tab_btn)
			c.focus_neighbor_bottom = c.get_path_to(cl[i + cols] if i + cols < cl.size() else back_button)
		for tb in tab_buttons:
			tb.focus_neighbor_bottom = tb.get_path_to(cl[0] if not cl.is_empty() else back_button)
		back_button.focus_neighbor_top = back_button.get_path_to(cl[cl.size() - 1] if not cl.is_empty() else tab_btn)
		back_button.focus_neighbor_left = back_button.get_path_to(back_button)
		back_button.focus_neighbor_right = back_button.get_path_to(back_button)
		back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
		return
	for tb in tab_buttons:
		tb.focus_neighbor_bottom = tb.get_path_to(sort_buttons[0])
	var bar: Array[Button] = sort_buttons.duplicate()
	bar.append(filter_button)
	for i in bar.size():
		var b := bar[i]
		b.focus_neighbor_left = b.get_path_to(bar[i - 1] if i > 0 else b)
		b.focus_neighbor_right = b.get_path_to(bar[i + 1] if i + 1 < bar.size() else b)
		b.focus_neighbor_top = b.get_path_to(tab_btn)
		b.focus_neighbor_bottom = b.get_path_to(cards[0] if not cards.is_empty() else back_button)
	for i in cards.size():
		var c := cards[i]
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)
		c.focus_neighbor_top = c.get_path_to(cards[i - 1] if i > 0 else sort_buttons[0])
		c.focus_neighbor_bottom = c.get_path_to(cards[i + 1] if i + 1 < cards.size() else back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(cards[cards.size() - 1] if not cards.is_empty() else sort_buttons[0])
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)


func _layout() -> void:
	if _banner == null:
		return
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}
	var d: Dictionary = Platform.safe_margins()
	for k in m:
		m[k] = clampf(float(d.get(k, m[k])), m[k], 160.0)
	var w: float = vs.x - float(m.left) - float(m.right)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, maxf(92.0, _banner.get_combined_minimum_size().y))
	count_label.size = Vector2(560, 56)
	count_label.position = Vector2(vs.x - m.right - count_label.size.x, 24 + (_banner.size.y - count_label.size.y) * 0.5)
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	var y: float = _banner.position.y + _banner.size.y + 14.0
	_tabs_bar.position = Vector2(m.left, y)
	_tabs_bar.size = Vector2(w, 64)
	y += 64.0 + 10.0
	for v in views:
		v.position = Vector2(m.left, y)
		v.size = Vector2(w, back_button.position.y - 16.0 - y)
	_bar.position = Vector2(m.left, y)
	_bar.size = Vector2(w, 72)
	y += 72.0 + 6.0
	_hint.position = Vector2(m.left, y)
	_hint.size = Vector2(w, 32)
	y += 34.0
	_scroll.position = Vector2(m.left, y)
	_scroll.size = Vector2(w, back_button.position.y - 16.0 - y)
	_list.custom_minimum_size.x = w - 8.0
	_empty.position = _scroll.position
	_empty.size = _scroll.size
	_wire_focus()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if detail != null:
			close_detail()
		elif best_panel != null and is_instance_valid(best_panel):
			pass # le panneau gère lui-même sa fermeture
		else:
			back_requested.emit()
