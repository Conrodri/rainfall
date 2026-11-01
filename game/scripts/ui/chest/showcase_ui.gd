class_name ShowcaseUI
extends CanvasLayer
## Écran « vitrine » : des objets visibles, tous montrés d'emblée, sans d100 ni roue (docs/Boucle_Etage_Design.md §2.5).
## Deux modes, un seul écran :
##  - PICK (coffre à vitrine) : 3 objets déjà payés (prix x1,2 débité à l'ouverture), on en choisit UN, l'écran se ferme ;
##  - SHOP (marchand de l'étage 3) : 1 objet par rareté, chacun avec son prix (recalculé à chaque image : remise ou
##    présage compris), acheté une seule fois, l'écran reste ouvert jusqu'à « Fermer ».
## Met l'arbre en pause pendant l'écran (process ALWAYS) puis restaure l'état précédent. Entrées : souris, tactile,
## manette (focus + ui_accept) et touches 1-4 ; PICK ne peut pas être annulé (l'or est déjà dépensé).

signal finished
signal item_taken(index: int, item_id: StringName) ## objet pris (choix PICK ou achat SHOP)

enum Mode { PICK, SHOP }

const CARD_SIZE := Vector2(400.0, 640.0)
const ICON_PX := 128.0
const INPUT_LOCK_S := 0.3 ## aucun choix juste après l'ouverture (l'appui qui a ouvert l'écran ne doit rien valider)

var mode: Mode = Mode.PICK
var session: ChestSession = null ## PICK : session de coffre (offered = les 3 ids) pour choose() et la sauvegarde
var quality: StringName = &"commun"
var offered: Array = []
var sold: Array[bool] = [] ## SHOP : achat fait
var price_fn: Callable = Callable() ## SHOP : Callable(quality: StringName) -> float, relu à chaque image
var _was_paused := false
var _paused_by_me := true ## faux en coop : l'arbre n'a pas été mis en pause
var _lock := true
var _closed := false
var _cards: Array[PanelContainer] = []
var _buttons: Array[Button] = []
var _price_labels: Array[Label] = []
var _gold_label: Label = null
var _shake := {}
var _tex_cache := {}


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


## Coffre à vitrine : `offer` = 3 ids déjà tirés, `price` = prix payé (référence des relances, inutilisé ici).
func open_pick(stage: int, price: float, offer: Array, p_quality: StringName, chest: Node = null) -> void:
	mode = Mode.PICK
	quality = p_quality
	offered = offer.duplicate()
	session = ChestSession.new(&"petit", stage, price)
	session.quality = p_quality
	session.offered = offered.duplicate()
	session.shown = offered.duplicate()
	_build("COFFRE À VITRINE", "Choisissez un objet : il est à vous.")
	Events.chest_opened.emit(chest, p_quality, offered)


## Reprise de sauvegarde d'un coffre à vitrine ouvert (même offre, aucun nouveau tirage ni signal).
func resume_pick(s: ChestSession) -> void:
	mode = Mode.PICK
	session = s
	quality = s.quality
	offered = s.offered.duplicate()
	_build("COFFRE À VITRINE", "Choisissez un objet : il est à vous.")


## Marchand : `entries` = [{id, quality, sold}], `fn` = Callable(quality) -> prix courant.
func open_shop(entries: Array, fn: Callable, title: String = "MARCHAND") -> void:
	mode = Mode.SHOP
	price_fn = fn
	offered = []
	sold = []
	for e: Dictionary in entries:
		offered.append(String(e["id"]))
		sold.append(bool(e.get("sold", false)))
	_build(title, "Un exemplaire de chaque, une seule fois.")


func _ready() -> void:
	_was_paused = get_tree().paused
	_paused_by_me = ChestSession.is_blocking() # coop : jamais de pause
	if _paused_by_me:
		get_tree().paused = true
	else:
		OverlayMode.enter()
	get_tree().create_timer(INPUT_LOCK_S, true, false, true).timeout.connect(func() -> void:
		_lock = false
		if not _buttons.is_empty() and is_instance_valid(_buttons[0]):
			_focus_first())


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _label(size: int, color := Color.WHITE, wrap := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _build(title: String, subtitle: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)
	var t := _label(52, Color(1, 0.92, 0.7))
	t.text = title
	col.add_child(t)
	var st := _label(30, Color(0.85, 0.85, 0.9))
	st.text = subtitle
	col.add_child(st)
	if mode == Mode.SHOP:
		_gold_label = _label(34, Color(1, 0.9, 0.4))
		col.add_child(_gold_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in offered.size():
		var card := _make_card(i)
		row.add_child(card)
	if mode == Mode.SHOP:
		var close := Button.new()
		close.text = "Fermer"
		close.custom_minimum_size = Vector2(0, 110)
		close.add_theme_font_size_override("font_size", 36)
		close.focus_mode = Control.FOCUS_ALL
		close.pressed.connect(_close)
		col.add_child(close)
		_buttons.append(close)
	_refresh()
	_focus_first.call_deferred()


func _focus_first() -> void:
	for b in _buttons:
		if is_instance_valid(b) and not b.disabled:
			b.grab_focus()
			return


func _make_card(i: int) -> PanelContainer:
	var id: String = offered[i]
	var it := ItemDB.get_item(id)
	var q := StringName(str(it.get("quality", quality)))
	var qc: Color = Palette.rarity(q)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.96)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(6)
	sb.border_color = qc
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var rar := _label(28, qc)
	rar.text = "%d. %s" % [i + 1, String(ChestUI.QUALITY_NAMES.get(q, q))]
	v.add_child(rar)
	var icon := TextureRect.new()
	icon.texture = _tex(ChestUI.ITEM_ICON % id)
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var nm := _label(36, qc, true)
	nm.text = str(it.get("name", id))
	v.add_child(nm)
	var eff := _label(26, Color(0.92, 0.92, 0.95), true)
	eff.text = str(it.get("effect_text", ""))
	eff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(eff)
	var tags: Array[String] = []
	for tg in it.get("tags", []):
		tags.append("[%s]" % str(tg))
	var tl := _label(24, Color(0.6, 0.8, 1.0))
	tl.text = "  ".join(tags)
	v.add_child(tl)
	var owned := _owner().stacks(StringName(id))
	var ol := _label(26, Color(1, 0.85, 0.4) if owned > 0 else Color(0.5, 1, 0.6), true)
	ol.text = ChestUI.stack_line(id, owned) if owned > 0 else "Nouveau"
	v.add_child(ol)
	var pl := _label(32, Color(1, 0.9, 0.4))
	v.add_child(pl)
	_price_labels.append(pl)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_ALL
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(6)
	ring.border_color = Color.WHITE
	ring.set_corner_radius_all(20)
	b.add_theme_stylebox_override("focus", ring)
	b.pressed.connect(_on_pressed.bind(i))
	v.add_child(b)
	_buttons.append(b)
	_cards.append(card)
	return card


func _process(_delta: float) -> void:
	_refresh()


## Prix courant du `i`-ème objet (SHOP), 0 en PICK.
func price_of(i: int) -> float:
	if mode != Mode.SHOP or not price_fn.is_valid():
		return 0.0
	var q := StringName(str(ItemDB.get_item(offered[i]).get("quality", "commun")))
	return float(price_fn.call(q))


func _refresh() -> void:
	if _gold_label != null:
		_gold_label.text = "Or : %d" % int(_owner().gold)
	for i in _cards.size():
		var b := _buttons[i]
		var pl := _price_labels[i]
		if mode == Mode.PICK:
			pl.text = ""
			b.text = "Choisir"
			continue
		if bool(sold[i]):
			pl.text = "Vendu"
			pl.modulate = Color(0.7, 0.7, 0.7)
			b.text = "Vendu"
			b.disabled = true
			continue
		var p := price_of(i)
		var missing := maxi(int(ceil(p - _owner().gold)), 0)
		pl.text = "%d or" % int(ceil(p)) if missing <= 0 else "%d or (il manque %d)" % [int(ceil(p)), missing]
		pl.modulate = Color(1, 0.9, 0.4) if missing <= 0 else Color(1, 0.45, 0.4)
		b.text = "Acheter"


func _on_pressed(i: int) -> void:
	if _lock or _closed:
		return
	if mode == Mode.PICK:
		take(i)
	else:
		buy(i)


## PICK : prend l'objet `i` (déjà payé) et ferme l'écran.
func take(i: int) -> void:
	if mode != Mode.PICK or _closed or session == null or offered.is_empty():
		return
	var idx := clampi(i, 0, offered.size() - 1)
	session.choose(get_tree(), idx)
	item_taken.emit(idx, StringName(offered[idx]))
	_close()


## SHOP : achète l'objet `i` au prix courant. Faux si déjà vendu ou or insuffisant (l'écran reste ouvert).
func buy(i: int) -> bool:
	if mode != Mode.SHOP or _closed or i < 0 or i >= offered.size() or bool(sold[i]):
		return false
	var p := price_of(i)
	var st := _owner()
	if not st.spend_gold(p):
		_refuse(i)
		return false
	sold[i] = true
	var id := StringName(offered[i])
	st.add_item(id)
	Events.emit_item_chosen(id, st.slot)
	var player := Players.by_id(st.slot) if is_inside_tree() else null
	if player != null and player.has_method("apply_stats"):
		player.apply_stats(ItemStats.compute(st.items))
	item_taken.emit(i, id)
	_refresh()
	return true


## PlayerState du propriétaire de l'écran (acheteur du marchand / bénéficiaire de la vitrine) : session.state, sinon la méta
## `owner_slot` posée par Chest.try_open / le marchand, sinon le joueur local.
func _owner() -> PlayerState:
	if session != null and session.state != null:
		return session.state
	if has_meta(&"owner_slot"):
		var st := Players.state_of(int(get_meta(&"owner_slot")))
		if st != null:
			return st
	return LocalState.state()


func _refuse(i: int) -> void:
	if i < 0 or i >= _cards.size():
		return
	var card := _cards[i]
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(card, "modulate", Color(1.0, 0.55, 0.55), 0.06)
	tw.tween_property(card, "modulate", Color.WHITE, 0.2)


func is_closed() -> bool:
	return _closed


func _close() -> void:
	if _closed:
		return
	_closed = true
	if _paused_by_me:
		get_tree().paused = _was_paused
	else:
		OverlayMode.leave()
	finished.emit()
	queue_free()


## Fermeture du marchand (Échap / Retour / bouton) ; sans effet en PICK (l'or est déjà dépensé).
func close_shop() -> void:
	if mode == Mode.SHOP:
		_close()


func _input(event: InputEvent) -> void:
	if _closed or _lock:
		return
	if event.is_action_pressed(&"ui_cancel") and mode == Mode.SHOP:
		get_viewport().set_input_as_handled()
		_close()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		var n := k - KEY_1 if k >= KEY_1 and k <= KEY_4 else (k - KEY_KP_1 if k >= KEY_KP_1 and k <= KEY_KP_4 else -1)
		if n >= 0 and n < offered.size():
			get_viewport().set_input_as_handled()
			_on_pressed(n)
