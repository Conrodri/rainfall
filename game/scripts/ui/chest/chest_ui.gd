class_name ChestUI
extends CanvasLayer
## Écran d'ouverture de coffre (GDD §6) : le coffre tremble pendant un défilement de rareté (bande horizontale
## qui ralentit et s'arrête sur la rareté tirée), puis les items de cette rareté défilent sur les 2 cartes et
## s'arrêtent sur les items tirés ; choix / relances ensuite. ≈ 1,3 s (commun) à 2 s (légendaire).
## Le tirage est fait à l'ouverture (ChestSession, RunState.rng) : la mise en scène n'est que de la présentation
## (RNG propre, jamais RunState.rng). SKIP : clic / tap / touche / bouton pendant l'animation = résultat final
## immédiat ; cet appui ne choisit jamais de carte (verrou jusqu'au relâcher, SKIP_LOCK_MS minimum).
## Choix d'une carte au RELÂCHER (clic, toucher, Entrée / A) ; glisser hors de la carte annule. Invites de touches
## (KeyPrompt) sous les cartes et sur les boutons de relance, selon le mode d'entrée ; actions chest_pick_1/2 et
## chest_reroll_ad/gold (remappables). Contour de focus de 6 px sur les cartes et boutons ; rareté écrite sur la carte.
## Usage : var ui = preload("res://scenes/ui/chest/chest_ui.tscn").instantiate(); parent.add_child(ui)
##         ui.open(kind, stage, price, chest_node)   # price = 0 pour le coffre boss
## Met l'arbre en pause pendant l'écran (process ALWAYS) puis restaure l'état précédent.

signal finished

const QUALITY_COLORS := {
	&"commun": Color(0.78, 0.78, 0.8),
	&"peu_commun": Color(0.35, 0.82, 0.4),
	&"rare": Color(0.33, 0.6, 1.0),
	&"legendaire": Color(1.0, 0.65, 0.12),
}
const QUALITY_NAMES := {
	&"commun": "Commun", &"peu_commun": "Peu commun", &"rare": "Rare", &"legendaire": "Légendaire",
}
const KIND_NAMES := {
	&"petit": "Petit coffre", &"large": "Grand coffre", &"legendaire": "Coffre légendaire", &"boss": "Coffre du boss", &"guardian": "Reliquaire",
}
## Sprite du coffre (rendu Blender) montré pendant l'intro : fermé, puis ouvert quand la rareté est posée.
const CHEST_FRAMES := {
	&"petit": "res://assets/sprites/chests/chest_small/chest_small.tres",
	&"large": "res://assets/sprites/chests/chest_large/chest_large.tres",
	&"legendaire": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres",
	&"boss": "res://assets/sprites/chests/chest_legendary/chest_legendary.tres",
	&"guardian": "res://assets/sprites/chests/chest_large/chest_large.tres",
}
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const RARITY_FRAME := "res://assets/sprites/icons/frame_%s.png"
const CARD_ICON_PX := 128.0
const CARD_FRONT := "res://assets/sprites/ui/cards/card_front.png" ## cadre de carte DA (384 x 560)
const CARD_BACK := "res://assets/sprites/ui/cards/card_back.png"
## Zones de card_front.png (384 x 560), mesurées dans la texture, en fractions de la carte :
## illustration y 34-288, bandeau du titre y 314-352, zone de texte y 370-525 (x 40-346).
const ZONE_ART := Rect2(0.128, 0.061, 0.784, 0.453)
const ZONE_BAND := Rect2(0.104, 0.561, 0.797, 0.068)
const ZONE_TEXT := Rect2(0.104, 0.661, 0.797, 0.277)
const ZONE_PAD := Vector2(0.02, 0.012) ## marge interne (fraction de la largeur / de la hauteur de la carte)
const BREAK_FLAGS := 1 | 2 | 8 ## TextServer : retour forcé, limite de mot, adaptatif (= AUTOWRAP_WORD_SMART)
const CARD_RATIO := 384.0 / 560.0
const BUTTON_H := 128.0 ## hauteur minimale des boutons de relance (px logiques, paysage 1080 comme portrait)
const BUTTON_H_PORTRAIT := 144.0
const BUTTON_GAP := 48 ## écart entre les deux boutons de relance
const FOCUS_PX := 6 ## épaisseur du contour de focus (cartes et boutons)
const PROMPT_H := 44.0 ## hauteur des invites de touches
const GOLD_COL := Color(1.0, 0.82, 0.3) ## bouton qui dépense de l'or
## Actions propres à l'écran de coffre (créées si absentes ; remappables comme les autres actions via l'InputMap).
const ACTION_DEFAULTS := {
	&"chest_pick_1": {"keys": [KEY_1, KEY_KP_1], "pad": [JOY_BUTTON_LEFT_SHOULDER]},
	&"chest_pick_2": {"keys": [KEY_2, KEY_KP_2], "pad": [JOY_BUTTON_RIGHT_SHOULDER]},
	&"chest_reroll_ad": {"keys": [KEY_R], "pad": [JOY_BUTTON_Y]}, ## relance pub / gratuite (sinon à l'or)
	&"chest_reroll_gold": {"keys": [KEY_G], "pad": [JOY_BUTTON_X]},
	&"chest_items": {"keys": [KEY_TAB], "pad": [JOY_BUTTON_BACK]}, ## consulter ses objets (Audit_Choix P10, lot L6)
}
## Stat d'item -> [libellé, type] pour la ligne d'empilement. Types : pct (+N %), flat (+N), neg (-N %).
const STAT_TEXT := {
	"max_hp_flat": ["PV max", "flat"], "max_hp_pct": ["de PV max", "pct"], "regen_flat": ["PV/s de régénération", "flat"],
	"armor": ["d'armure", "flat"], "dodge": ["de blocage", "pct"], "luck": ["de Chance", "flat"],
	"damage_taken_reduction": ["de dégâts subis", "neg"], "dot_taken_reduction": ["de dégâts de brûlure et poison subis", "neg"],
	"move_speed": ["de vitesse de déplacement", "pct"], "attack_speed": ["de vitesse d'attaque", "pct"],
	"cooldown_mult": ["de temps de recharge", "pct"], "cooldown_haste": ["de hâte de recharge", "pct"], "crit_chance": ["de chance de critique", "pct"],
	"crit_mult_add": ["de dégâts critiques", "pct"], "damage_add": ["de dégâts", "pct"], "damage_mult": ["de dégâts infligés", "pct"],
	"auto_damage_add": ["de dégâts du sort 1", "pct"], "cd_damage_add": ["de dégâts des sorts à recharge", "pct"],
	"zone_damage_add": ["de dégâts de zone", "pct"], "zone_size_add": ["de taille de zone", "pct"],
	"burn_damage_add": ["de dégâts de brûlure", "pct"], "low_hp_damage_add": ["de dégâts à PV bas", "pct"],
	"elite_boss_damage_add": ["de dégâts aux élites et boss", "pct"], "slowed_target_damage_add": ["de dégâts aux ralentis", "pct"],
	"moving_damage_add": ["de dégâts en mouvement", "pct"], "projectile_speed": ["de vitesse de projectile", "pct"],
	"range_add": ["de portée", "pct"], "pierce": ["de perforation", "flat"], "gold_mult": ["d'or gagné", "pct"],
	"xp_mult": ["d'XP gagnée", "pct"],
}

# ---- mise en scène (présentation seule)
const RARITY_DUR := [0.62, 0.72, 0.92, 1.22] ## durée du défilement de rareté selon le rang tiré (tension)
const RARITY_EASE := [2.6, 2.8, 3.2, 3.6] ## exposant de l'ease-out : plus haut = fin plus lente
const RARITY_TILES := [11, 12, 15, 17] ## cases parcourues avant la rareté tirée
const ITEM_GAP := 0.08 ## pause entre la rareté posée et le défilement des items
const ITEM_DUR := [0.42, 0.56] ## défilement des items, carte 0 puis carte 1 (décalées)
const ITEM_STEPS := [9, 12] ## items montrés par carte (le dernier = item tiré)
const END_HOLD := 0.12
const SKIP_LOCK_MS := 220 ## après un skip : aucun choix avant ce délai ni avant le relâcher de l'appui
const SKIP_RELEASE_MAX_MS := 1500 ## filet : relâcher manqué

var session: ChestSession
var skipped := false ## l'animation en cours / dernière a été passée (tests)
var _chest: Node
var _was_paused := false
var _busy := true
var _stage_box: Control
var _icon: TextureRect
var _chest_frames: SpriteFrames
var _reel_panel: PanelContainer ## fenêtre DA du défilement de rareté
var _reel: Control ## bande des raretés (clip)
var _reel_tiles: Array[Control] = []
var _reel_seq: Array[StringName] = []
var _reel_pos := 0.0 ## index (flottant) de la case au centre
var _reel_from := 2.0
var _reel_to := 0.0
var _tile_px := 110.0
## Roues de rareté supplémentaires (objets « +1 Chance » : un jet de plus par exemplaire, on garde le meilleur).
## La roue principale (_reel) porte le meilleur jet ; chaque entrée : panel, reel, tiles, seq, to, pos, rank, dur, landed, last, slot.
const MAX_WHEELS := 3 ## plafond visuel (le tirage, lui, garde tous les jets)
const MULTI_WHEEL_K := 0.7 ## les roues multiples tournent plus vite : la phase de rareté reste courte
var _xr: Array = []
var _main_slot := 0
var _flash: ColorRect
var _card_styles: Array[StyleBoxTexture] = []
var _front_sb: Array[StyleBox] = []
var _back_sb: Array[StyleBox] = []
var _card_boxes: Array[Control] = [] ## conteneur d icône de chaque carte
var _card_art_pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _quality: Label
var _title: Label
var _cards: Array[PanelContainer] = []
var _card_front: Array[Control] = []
var fit_report: Array = [{}, {}] ## par carte : zones et dimensions mesurées du texte (tests)
var _card_back: Array[Label] = []
var _card_icons: Array[TextureRect] = []
var _card_rarity: Array[TextureRect] = []
var _ad_btn: Button
var _gold_btn: Button
var _btn_row: HBoxContainer
var _ad_key: KeyPrompt
var _gold_key: KeyPrompt
var _pick_keys: Array[KeyPrompt] = [] ## invite de touche sous chaque carte
var _items_btn: Button ## « Objets (N) » : liste des objets possédés par-dessus le coffre (lot L6)
var _items_key: KeyPrompt
var _focus_rings: Array[Panel] = [] ## contour de focus de chaque carte (manette / clavier)
var _press_card := -1 ## carte appuyée en attente du relâcher (-1 = aucune)
var _icon_home := Vector2.ZERO
var _main: BoxContainer
var _cards_box: BoxContainer
# état de l'animation
var _pres := RandomNumberGenerator.new() ## RNG de présentation (jamais RunState.rng)
var _animating := false
var _opening := false ## première image après open() (mise en page) : un appui y vaut déjà skip
var _anim_t := 0.0
var _rank := 0
var _rar_dur := 0.0
var _item_dur: Array[float] = [0.0, 0.0] ## ITEM_DUR × GameSettings.chest_reveal_mult()[1]
var _rar_landed := true
var _item_t0 := 0.0
var _item_seq: Array = [[], []]
var _item_step: Array[int] = [-1, -1]
var _item_landed: Array[bool] = [true, true]
var _end_t := 0.0
var _last_tick := -1
var _skip_lock_until := 0
var _skip_wait_release := false
var _tex_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pres.randomize()
	ensure_actions()
	_build()
	Platform.input_mode_changed.connect(_on_input_mode_changed)


func _exit_tree() -> void:
	if Platform.input_mode_changed.is_connected(_on_input_mode_changed):
		Platform.input_mode_changed.disconnect(_on_input_mode_changed)


## Crée les actions du coffre absentes de l'InputMap (une action déjà présente, donc remappée, est laissée telle quelle).
static func ensure_actions() -> void:
	for a in ACTION_DEFAULTS:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.5)
		for k in ACTION_DEFAULTS[a]["keys"]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
		for b in ACTION_DEFAULTS[a]["pad"]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(a, jb)


func _on_input_mode_changed(_mode: int) -> void:
	_refresh_prompts()
	_update_rings()


func _refresh_prompts() -> void:
	for k in _pick_keys:
		k.refresh()
	if _ad_key != null:
		_ad_key.refresh()
		_gold_key.refresh()
	if _items_key != null:
		_items_key.refresh()


## Contour de focus : visible tant qu'une carte a le focus hors mode tactile (manette, clavier).
func _update_rings() -> void:
	for i in _focus_rings.size():
		var on := _cards[i].has_focus() and not Platform.is_touch_mode() and _card_front[i].visible
		_focus_rings[i].visible = on
		if on and session != null:
			var qc: Color = Palette.rarity(session.quality)
			var sb := _focus_rings[i].get_theme_stylebox(&"panel") as StyleBoxFlat
			if sb != null:
				sb.border_color = qc.lerp(Color.WHITE, 0.45)


## Ligne d'empilement d'une carte : effet de l'exemplaire en plus, « ×2 → ×3 : +50 PV max au total ».
## Vide si l'item n'est pas encore possédé.
static func stack_line(id: String, owned: int) -> String:
	if owned <= 0:
		return ""
	var it := ItemDB.get_item(id)
	var head := "×%d → ×%d" % [owned, owned + 1]
	var st := str(it.get("stack", "L"))
	var overrides: Dictionary = it.get("stat_stack", {})
	var stats: Dictionary = it.get("stats", {})
	var parts: Array[String] = []
	var changed := false
	for key in stats:
		var tx: Variant = STAT_TEXT.get(str(key))
		if tx == null:
			continue
		var s := str(overrides.get(key, st))
		var v0 := ItemStats.stat_value(s, stats[key], owned)
		var v1 := ItemStats.stat_value(s, stats[key], owned + 1)
		if Balance.ITEM_BONUS_CAPS.has(str(key)): # plafond affiché comme appliqué (Œil, Cœur de glace…)
			var cap := float(Balance.ITEM_BONUS_CAPS[str(key)])
			v0 = minf(v0, cap)
			v1 = minf(v1, cap)
		if not is_equal_approx(v0, v1):
			changed = true
		if parts.size() < 2:
			parts.append(_fmt_stat(v1, str(tx[0]), str(tx[1])))
	if parts.is_empty():
		for p in it.get("procs", []):
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var ps := str(p.get("stack", st))
			var c0 := ItemStats.proc_chance(ps, float(p.get("chance", 0.0)), owned)
			var c1 := ItemStats.proc_chance(ps, float(p.get("chance", 0.0)), owned + 1)
			if not is_equal_approx(c0, c1):
				changed = true
			parts.append("%d %% de chance de déclenchement" % roundi(c1 * 100.0))
			break
	if parts.is_empty():
		return head + " : l'effet se renforce"
	if not changed:
		return head + " : aucun effet de plus"
	return head + " : " + ", ".join(parts) + " au total"


static func _fmt_stat(v: float, label: String, kind: String) -> String:
	match kind:
		"pct":
			return "%+d %% %s" % [roundi(v * 100.0), label]
		"neg":
			return "-%d %% %s" % [roundi(v * 100.0), label]
	if absf(v - roundf(v)) < 0.05:
		return "%+d %s" % [roundi(v), label]
	return ("%+.1f %s" % [v, label]).replace(".", ",")


func open(kind: StringName, stage: int, price: float, chest: Node = null) -> void:
	_chest = chest
	if not is_node_ready():
		await ready
	_was_paused = get_tree().paused
	get_tree().paused = true
	session = ChestSession.new(kind, stage, price)
	session.start()
	Events.chest_opened.emit(chest, session.quality, session.offered)
	_title.text = String(KIND_NAMES.get(kind, "Coffre")).to_upper()
	var fp: String = CHEST_FRAMES.get(kind, CHEST_FRAMES[&"petit"])
	_chest_frames = load(fp) as SpriteFrames if ResourceLoader.exists(fp) else null
	_set_chest_state(&"closed", Color.WHITE)
	_quality.text = ""
	for i in 2:
		_set_card_hidden(i)
	_busy = true
	_opening = true # un appui dès l'ouverture passe déjà l'animation
	_update_buttons()
	await get_tree().process_frame
	_opening = false
	if is_queued_for_deletion() or session == null:
		return
	_layout_stage()
	_start_reveal(true)
	if skipped: # skip reçu avant la première image : arrivée directe
		_finish_reveal()


## Reprise de sauvegarde : rouvre l'écran sur une session déjà tirée (coffre ouvert, mêmes cartes,
## pas de nouveau tirage ni d'Events.chest_opened), directement sur le résultat, sans animation.
## Le jeu était en cours : la fermeture le relance.
func resume(s: ChestSession) -> void:
	if not is_node_ready():
		await ready
	session = s
	_was_paused = false
	get_tree().paused = true
	_title.text = String(KIND_NAMES.get(s.kind, "Coffre")).to_upper()
	var fp: String = CHEST_FRAMES.get(s.kind, CHEST_FRAMES[&"petit"])
	_chest_frames = load(fp) as SpriteFrames if ResourceLoader.exists(fp) else null
	_rank = maxi(0, LootRoller.quality_rank(s.quality))
	_build_reel()
	_land_rarity(false)
	for i in 2:
		_land_card(i, false)
	_busy = false
	_update_buttons()
	await get_tree().process_frame
	_layout_stage()
	for i in 2:
		_fit_card(i)


## Animation en cours (défilement de rareté ou d'items).
func is_animating() -> bool:
	return _animating or _opening


## &"rarity", &"items" ou &"done" (tests).
func reveal_phase() -> StringName:
	if _opening:
		return &"rarity"
	if not _animating:
		return &"done"
	return &"rarity" if not _rar_landed else &"items"


## Passe l'animation : résultat final immédiat (aucun choix).
func skip() -> void:
	skipped = true
	if _animating:
		_finish_reveal()


# ---------------------------------------------------------------- construction
func _box(c: Color, radius := 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(18)
	return sb


func _label(size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Bouton de relance (style secondaire, jamais PrimaryButton : le choix d'item reste l'action principale).
## `gold` = relance qui dépense de l'or : fond brun, bordure et texte dorés. L'invite de touche est posée à droite.
func _button(text: String, action: StringName, gold := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BUTTON_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_ALL
	var ring := StyleBoxFlat.new() # contour de focus visible (>= 3:1 sur le fond)
	ring.draw_center = false
	ring.set_border_width_all(FOCUS_PX)
	ring.border_color = Color.WHITE
	ring.set_corner_radius_all(20)
	b.add_theme_stylebox_override("focus", ring)
	if gold:
		var variants := {"normal": Color(0.30, 0.19, 0.04), "hover": Color(0.40, 0.26, 0.06),
			"pressed": Color(0.2, 0.12, 0.03), "disabled": Color(0.16, 0.13, 0.09)}
		for k in variants:
			var sb := StyleBoxFlat.new()
			sb.bg_color = variants[k]
			sb.set_corner_radius_all(20)
			sb.set_border_width_all(4)
			sb.border_color = GOLD_COL if k != "disabled" else GOLD_COL.darkened(0.55)
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			b.add_theme_stylebox_override(k, sb)
		b.add_theme_color_override("font_color", GOLD_COL)
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))
		b.add_theme_color_override("font_pressed_color", GOLD_COL)
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.55))
		b.add_theme_color_override("font_disabled_color", GOLD_COL.darkened(0.45))
	var kp := KeyPrompt.new()
	kp.set_height(PROMPT_H)
	kp.set_action(action)
	kp.anchor_left = 1.0
	kp.anchor_right = 1.0
	kp.anchor_top = 0.5
	kp.anchor_bottom = 0.5
	kp.offset_left = -20
	kp.offset_right = -20
	kp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kp.grow_vertical = Control.GROW_DIRECTION_BOTH
	b.add_child(kp)
	if gold:
		_gold_key = kp
	else:
		_ad_key = kp
	return b


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var margin := MarginContainer.new()
	margin.theme = UiTheme.theme() # thème DA commun (boutons, panneaux)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	# Portrait : en-tête au-dessus, corps dessous. Paysage : en-tête à gauche, corps à droite.
	_main = BoxContainer.new()
	_main.vertical = true
	_main.add_theme_constant_override("separation", 24)
	var big := PanelContainer.new() # grand panneau DA derrière l'écran
	big.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(big)
	big.add_child(_main)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header.size_flags_stretch_ratio = 0.8
	_main.add_child(header)

	var banner := PanelContainer.new() # bandeau de titre
	banner.theme_type_variation = &"HeaderPanel"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(banner)
	_title = _label(52, Color(1, 0.92, 0.7))
	_title.add_theme_font_override("font", UiTheme.title_font())
	banner.add_child(_title)

	_stage_box = Control.new()
	_stage_box.custom_minimum_size = Vector2(0, 340)
	_stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	header.add_child(_stage_box)
	_icon = TextureRect.new()
	_icon.size = Vector2(200, 200)
	_icon.pivot_offset = Vector2(100, 100)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage_box.add_child(_icon)
	# défilement de rareté : fenêtre DA (panneau 9-slice du kit UI), bande découpée dedans
	_reel_panel = PanelContainer.new()
	_reel_panel.theme_type_variation = &"SmallPanel"
	_reel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(_reel_panel)
	_reel = Control.new()
	_reel.clip_contents = true
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel_panel.add_child(_reel)
	_reel.resized.connect(_layout_reel)
	_stage_box.resized.connect(_layout_stage)

	_quality = _label(60)
	_quality.set_meta(&"a11y_skip", true) # ajusté à la largeur par _fit_quality
	_quality.custom_minimum_size = Vector2(0, 76)
	_quality.clip_text = true # largeur minimale 0 : la taille de police s'ajuste (_fit_quality), jamais de débordement
	header.add_child(_quality)
	_build_items_button(header) # lot L6 : avant la rangée de relances (_button réaffecte ensuite _ad_key)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_stretch_ratio = 1.2
	_main.add_child(body)

	_cards_box = BoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 32)
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_cards_box)
	for i in 2:
		var col := VBoxContainer.new() # carte + invite de touche dessous
		col.add_theme_constant_override("separation", 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards_box.add_child(col)
		var arc := AspectRatioContainer.new() # la carte garde ses proportions quelle que soit la place
		arc.ratio = CARD_RATIO
		arc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(arc)
		var pk := KeyPrompt.new()
		pk.set_height(PROMPT_H)
		pk.set_action(&"chest_pick_1" if i == 0 else &"chest_pick_2")
		col.add_child(pk)
		_pick_keys.append(pk)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 260)
		var cstyle := _card_style(CARD_FRONT)
		var fsb: StyleBox = cstyle
		if cstyle == null: # repli : cadre plat bordé de la couleur de rareté
			var flat := _box(Color(0.14, 0.15, 0.2), 28)
			flat.set_border_width_all(6)
			fsb = flat
		var bsb: StyleBox = _card_style(CARD_BACK)
		_front_sb.append(fsb)
		_back_sb.append(bsb if bsb != null else fsb)
		card.add_theme_stylebox_override("panel", fsb)
		card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
		arc.add_child(card)
		var back := _label(160, Color(0.5, 0.5, 0.6))
		back.text = "?" if cstyle == null else "" # le dos de carte DA se suffit
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(back)
		var front := Control.new() # contenu positionné à la main sur les zones du cadre (_fit_card)
		front.clip_contents = true
		front.visible = false
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(front)
		# icône d'item (rendu Blender) dans son cadre de rareté
		var icon_box := CenterContainer.new() # icône et cadre de rareté superposés, centrés dans la fenêtre d'illustration
		icon_box.custom_minimum_size = Vector2(CARD_ICON_PX, CARD_ICON_PX)
		icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(icon_box)
		var icon_frame := TextureRect.new()
		var icon := TextureRect.new()
		for tr in [icon, icon_frame]:
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.custom_minimum_size = Vector2(CARD_ICON_PX, CARD_ICON_PX)
			icon_box.add_child(tr)
		_card_boxes.append(icon_box)
		_card_icons.append(icon)
		icon_frame.visible = false # la carte a déjà sa fenêtre d illustration et sa pastille de rareté : pas de cadre carré par-dessus l icône (retour joueur 26/10)
		_card_rarity.append(icon_frame)
		# toute la carte est le bouton de choix (clic, toucher, Entrée / A quand elle a le focus)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(_hover_card.bind(i, true))
		card.mouse_exited.connect(_hover_card.bind(i, false))
		card.focus_entered.connect(_hover_card.bind(i, true))
		card.focus_exited.connect(_hover_card.bind(i, false))
		var sizes := [38, 30, 26, 28]
		for n in 4:
			var l := _label(sizes[n], Color.WHITE)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if n == 1:
				l.size_flags_vertical = Control.SIZE_EXPAND_FILL
			front.add_child(l)
		# nom de la rareté écrit sur la carte (enfant 5), pastille sombre au bas de l'illustration
		var rl := _label(22, Color.WHITE)
		rl.autowrap_mode = TextServer.AUTOWRAP_OFF
		rl.clip_text = true
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0, 0, 0, 0.74)
		rsb.set_corner_radius_all(8)
		rsb.content_margin_left = 8
		rsb.content_margin_right = 8
		rsb.content_margin_top = 0
		rsb.content_margin_bottom = 0
		rl.add_theme_stylebox_override("normal", rsb)
		front.add_child(rl)
		# contour de focus (manette / clavier), au-dessus de tout le reste de la carte
		var ring := Panel.new()
		var rgsb := StyleBoxFlat.new()
		rgsb.draw_center = false
		rgsb.set_border_width_all(FOCUS_PX)
		rgsb.border_color = Color.WHITE
		rgsb.set_corner_radius_all(20)
		ring.add_theme_stylebox_override("panel", rgsb)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		card.add_child(ring)
		_focus_rings.append(ring)
		card.focus_entered.connect(_update_rings)
		card.focus_exited.connect(_update_rings)
		card.resized.connect(_fit_card.bind(i))
		_cards.append(card)
		_card_front.append(front)
		front.set_meta(&"a11y_skip", true) # textes ajustés à la carte par _fit_card (taille de texte appliquée à l'ajustement)
		_card_back.append(back)

	_btn_row = HBoxContainer.new() # relances côte à côte
	_btn_row.add_theme_constant_override("separation", BUTTON_GAP)
	body.add_child(_btn_row)
	_ad_btn = _button("Relancer (pub)", &"chest_reroll_ad")
	_ad_btn.pressed.connect(_on_ad_reroll)
	_btn_row.add_child(_ad_btn)
	_gold_btn = _button("Relancer (or)", &"chest_reroll_gold", true)
	_gold_btn.pressed.connect(_on_gold_reroll)
	_btn_row.add_child(_gold_btn)

	# éclair bref de la couleur de rareté (rare et légendaire), sur le coffre et la bande seulement
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(_flash) # borné au coffre et à la bande (_layout_stage), jamais plein écran

	get_viewport().size_changed.connect(_relayout)
	_relayout()


## S'adapte au ratio : paysage = en-tête à gauche / corps à droite ; cartes côte à côte sauf écran étroit.
func _relayout() -> void:
	var size := get_viewport().get_visible_rect().size
	var landscape := size.x > size.y
	_main.vertical = not landscape
	_cards_box.vertical = (size.x < 640.0) if not landscape else (size.x < 1100.0)
	var bh := BUTTON_H_PORTRAIT if size.y >= 1400.0 else BUTTON_H
	for b in [_ad_btn, _gold_btn]:
		b.custom_minimum_size.y = bh
		b.add_theme_font_size_override("font_size", 34 if size.x >= 900.0 else 26)


## Style de carte DA (texture étirée, marges de contenu ajustées à la taille réelle par _fit_card).
func _card_style(path: String) -> StyleBoxTexture:
	if not ResourceLoader.exists(path):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	_card_styles.append(sb)
	return sb


## Zone (en px, repère de la carte) = fraction mesurée dans la texture, réduite de la marge interne.
func _zone(z: Rect2, sz: Vector2, pad := ZONE_PAD) -> Rect2:
	var r := Rect2(z.position * sz, z.size * sz)
	return r.grow_individual(-pad.x * sz.x, -pad.y * sz.y, -pad.x * sz.x, -pad.y * sz.y)


## Cale le contenu d'une carte sur les zones du cadre : icône dans la fenêtre d'illustration, nom dans le
## bandeau (police réduite s'il est long), description dans la zone de texte (retour à la ligne, police réduite
## jusqu'à ce que tout tienne ; en dernier recours le texte est coupé au bord de la zone).
func _fit_card(i: int) -> void:
	if i >= _card_front.size() or i >= _card_boxes.size():
		return
	var c := _cards[i]
	var sz := c.size
	if sz.x < 20.0 or sz.y < 20.0:
		return
	var sb := c.get_theme_stylebox(&"panel") as StyleBoxTexture
	if sb != null:
		sb.content_margin_left = 0.0
		sb.content_margin_right = 0.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 0.0
	var f := _card_front[i]
	# illustration
	var art := _zone(ZONE_ART, sz)
	var box := _card_boxes[i]
	box.custom_minimum_size = Vector2.ZERO
	box.position = art.position
	box.size = art.size
	_card_art_pos[i] = art.position
	var px := minf(art.size.x, art.size.y) * 0.96
	for tr in [_card_icons[i], _card_rarity[i]]:
		tr.custom_minimum_size = Vector2(px, px)
		tr.size = Vector2(px, px)
	# rareté écrite : pastille au bas de l'illustration
	var rar_l := f.get_child(5) as Label
	var rh := clampf(art.size.y * 0.14, 22.0, 40.0)
	rar_l.position = Vector2(art.position.x + art.size.x * 0.12, art.end.y - rh - 6.0)
	rar_l.size = Vector2(art.size.x * 0.76, rh)
	rar_l.add_theme_font_size_override("font_size", mini(Accessibility.fs(clampi(int(rh * 0.62), 14, 24)), int(rh * 0.9)))
	# nom
	var band := _zone(ZONE_BAND, sz, Vector2(ZONE_PAD.x, 0.004))
	var name_l := f.get_child(1) as Label
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_l.clip_text = true
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = band.position
	name_l.size = band.size
	var font := name_l.get_theme_font(&"font")
	var nfs := mini(Accessibility.fs(clampi(int(band.size.y * 0.8), 12, 34)), int(band.size.y * 0.95))
	while nfs > 11 and font.get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > band.size.x:
		nfs -= 1
	name_l.add_theme_font_size_override("font_size", nfs)
	var name_w := font.get_string_size(name_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
	# description : effet, étiquettes, « Nouveau » / exemplaires possédés
	var tz := _zone(ZONE_TEXT, sz)
	var eff := f.get_child(2) as Label
	var tags := f.get_child(3) as Label
	var own := f.get_child(4) as Label
	var lines: Array[Label] = [eff, tags, own]
	var gap := 3.0
	var fs := Accessibility.fs(clampi(int(tz.size.y * 0.15), 12, 30)) # « Taille du texte » : la boucle ci-dessous réduit jusqu'à ce que ça tienne
	var total := 0.0
	var hs: Array[float] = [0.0, 0.0, 0.0]
	while true:
		total = 0.0
		var shown := 0
		for k in 3:
			var l := lines[k]
			var lf := fs if k == 0 else maxi(fs - 3, 10)
			hs[k] = 0.0 if l.text.is_empty() else font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, tz.size.x, lf, -1, BREAK_FLAGS).y * 1.05
			if hs[k] > 0.0:
				total += hs[k] + (gap if shown > 0 else 0.0)
				shown += 1
		if total <= tz.size.y or fs <= 10:
			break
		fs -= 1
	var y := tz.position.y
	for k in 3:
		var l := lines[k]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.clip_text = true
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.add_theme_constant_override("line_spacing", 0) # la mesure de _fit_card ignore l'interligne du thème
		l.add_theme_font_size_override("font_size", fs if k == 0 else maxi(fs - 3, 10))
		l.position = Vector2(tz.position.x, y)
		l.size = Vector2(tz.size.x, minf(hs[k], tz.end.y - y))
		if hs[k] > 0.0:
			y += hs[k] + gap
	fit_report[i] = {"art": art, "band": band, "text": tz, "text_h": total, "name_w": name_w, "font": fs}


func _layout_stage() -> void:
	var w := _stage_box.size.x
	var h := _stage_box.size.y
	# coffre au-dessus de la fenêtre de rareté, l'ensemble centré verticalement
	var rh := clampf(h * 0.4, 130.0, 220.0)
	var icon_s := clampf(minf(h - rh - 16.0, h * 0.55), 100.0, 280.0)
	var top := maxf(0.0, (h - icon_s - 16.0 - rh) * 0.5)
	_icon.size = Vector2(icon_s, icon_s)
	_icon.pivot_offset = _icon.size * 0.5
	_icon.position = Vector2((w - icon_s) * 0.5, top)
	_icon_home = _icon.position
	var nw := wheel_count()
	var gap := 16.0
	var pw := (w - gap * float(nw - 1)) / float(nw)
	var ry := top + icon_s + 16.0
	_reel_panel.position = Vector2(float(_main_slot) * (pw + gap), ry)
	_reel_panel.size = Vector2(pw, rh)
	for x in _xr:
		(x["panel"] as Control).position = Vector2(float(x["slot"]) * (pw + gap), ry)
		(x["panel"] as Control).size = Vector2(pw, rh)
	if _flash == null:
		return
	_flash.position = Vector2(0.0, top)
	_flash.size = Vector2(w, icon_s + 16.0 + rh)
	_layout_reel()


# ---------------------------------------------------------------- clavier / manette / skip
## Appui qui passe l'animation : clic (hors molette), toucher, touche, bouton de manette.
## Échap / Start sont laissés au menu pause.
func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo and k.keycode != KEY_ESCAPE
	if event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		return j.pressed and j.button_index != JOY_BUTTON_START
	return false


func _is_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return not event.is_pressed()
	if event is InputEventKey:
		return not (event as InputEventKey).pressed
	return false


## Juste après un skip : aucun choix tant que l'appui n'est pas relâché (et SKIP_LOCK_MS au minimum).
func _skip_locked() -> bool:
	var now := Time.get_ticks_msec()
	if now < _skip_lock_until:
		return true
	return _skip_wait_release and now < _skip_lock_until + SKIP_RELEASE_MAX_MS


func _input(event: InputEvent) -> void:
	if session == null and not _animating:
		return
	if items_open(): # consultation des objets par-dessus : le coffre ne lit rien (Retour / Échap / B : menu pause)
		if event.is_action_pressed(&"chest_items"):
			get_viewport().set_input_as_handled()
			var pm := _pause_menu()
			if pm != null and pm.has_method(&"close_items"):
				pm.call(&"close_items")
		return
	if _animating or _opening:
		if _is_press(event):
			get_viewport().set_input_as_handled()
			skip()
		elif not (event is InputEventMouseMotion or event is InputEventScreenDrag):
			if _is_release(event):
				get_viewport().set_input_as_handled() # relâcher du skip : jamais transmis aux cartes / boutons
		return
	if _is_release(event):
		var was := _skip_wait_release
		_skip_wait_release = false
		if was:
			get_viewport().set_input_as_handled()
			return
	if _skip_locked():
		if _is_press(event) or _is_release(event):
			get_viewport().set_input_as_handled()
		return
	if _busy or session == null:
		return
	# raccourcis par actions (remappables) ; ils valident à l'appui, le choix au doigt / à la souris au relâcher
	var idx := -1
	if event.is_action_pressed(&"chest_pick_1"):
		idx = 0
	elif event.is_action_pressed(&"chest_pick_2"):
		idx = 1
	elif event.is_action_pressed(&"chest_reroll_ad"):
		get_viewport().set_input_as_handled()
		if session.can_ad_reroll() and AdHook.is_available():
			_on_ad_reroll()
		elif session.can_gold_reroll():
			_on_gold_reroll()
		return
	elif event.is_action_pressed(&"chest_reroll_gold"):
		get_viewport().set_input_as_handled()
		_on_gold_reroll()
		return
	elif event.is_action_pressed(&"chest_items"):
		get_viewport().set_input_as_handled()
		open_items()
		return
	if idx >= 0:
		get_viewport().set_input_as_handled()
		_on_choose(idx)


# ---------------------------------------------------------------- mise en scène
func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Bande des raretés : cases tirées avec le RNG de présentation, pondérées (racine) par la table du coffre ;
## la case `_reel_to` est la rareté tirée. Haute rareté : la case d'avant est la rareté inférieure
## (la bande semble s'y arrêter puis glisse d'un cran).
func _build_reel() -> void:
	for t in _reel_tiles:
		t.queue_free()
	_reel_tiles.clear()
	_reel_seq.clear()
	var table: Dictionary = Balance.CHEST_QUALITY_TABLE.get(session.kind, {})
	# mélange de toutes les raretés (on sent le tirage), légèrement penché vers la table du coffre
	var qs: Array[StringName] = []
	var ws: Array[float] = []
	for q in LootRoller.ORDER:
		qs.append(q)
		ws.append(2.0 + 0.4 * sqrt(float(table.get(q, 0))))
	var n: int = RARITY_TILES[_rank]
	for k in n + 4:
		_reel_seq.append(qs[_pres.rand_weighted(PackedFloat32Array(ws))])
	_reel_seq[n] = session.quality
	if _rank >= 2:
		_reel_seq[n - 1] = LootRoller.ORDER[_rank - 1]
	_reel_from = 2.0
	_reel_to = float(n)
	_reel_pos = _reel_from
	_last_tick = roundi(_reel_pos)
	for q in _reel_seq:
		_reel_tiles.append(_make_tile(q))
	_build_extra_reels()
	_layout_reel()


## Nombre de roues affichées (1 sans Chance).
func wheel_count() -> int:
	return 1 + _xr.size()


## Roues des jets non retenus (au plus MAX_WHEELS - 1) ; la meilleure reste la roue principale.
func _build_extra_reels() -> void:
	for x in _xr:
		(x["panel"] as Node).queue_free()
	_xr.clear()
	_main_slot = 0
	if session == null or session.rolls.size() <= 1:
		return
	var best_i := 0
	for i in session.rolls.size():
		if int(session.rolls[i]) > int(session.rolls[best_i]):
			best_i = i
	var quals: Array = session.roll_qualities()
	var table: Dictionary = Balance.CHEST_QUALITY_TABLE.get(session.kind, {})
	var slot := 0
	for i in session.rolls.size():
		if i == best_i:
			_main_slot = mini(slot, MAX_WHEELS - 1)
			slot += 1
			continue
		if _xr.size() >= MAX_WHEELS - 1:
			continue
		var q: StringName = quals[i]
		var rk := maxi(0, LootRoller.quality_rank(q))
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"SmallPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_box.add_child(panel)
		var reel := Control.new()
		reel.clip_contents = true
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(reel)
		reel.resized.connect(_layout_reel)
		var qs: Array[StringName] = []
		var ws: Array[float] = []
		for qq in LootRoller.ORDER:
			qs.append(qq)
			ws.append(2.0 + 0.4 * sqrt(float(table.get(qq, 0))))
		var n: int = RARITY_TILES[rk]
		var seq: Array[StringName] = []
		for k in n + 4:
			seq.append(qs[_pres.rand_weighted(PackedFloat32Array(ws))])
		seq[n] = q
		var tiles: Array[Control] = []
		for qq in seq:
			tiles.append(_make_tile(qq, reel))
		_xr.append({"panel": panel, "reel": reel, "tiles": tiles, "seq": seq, "to": float(n), "pos": 2.0,
			"rank": rk, "dur": 0.0, "landed": false, "last": 2, "slot": slot, "q": q})
		slot += 1


## Case de rareté : cadre de rareté (kit d'icônes), fond teinté de la couleur de rareté (repli simple), nom.
func _make_tile(q: StringName, parent: Control = null) -> Control:
	var qc: Color = Palette.rarity(q)
	var tile := Control.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Color(qc.r * 0.35, qc.g * 0.35, qc.b * 0.35, 0.9)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 10
	fill.offset_top = 10
	fill.offset_right = -10
	fill.offset_bottom = -10
	tile.add_child(fill)
	var fr: Control
	if Palette.shapes_on(): # mode daltonien : cadre à la couleur de la palette, forme et épaisseur selon le rang (le PNG garde la teinte d'origine)
		var pf := Panel.new()
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(0, 0, 0, 0)
		fsb.border_color = qc
		fsb.set_border_width_all(Palette.rank_border(q, 4))
		fsb.set_corner_radius_all(Palette.rank_corner(q, 10))
		pf.add_theme_stylebox_override("panel", fsb)
		fr = pf
	else:
		var tr := TextureRect.new()
		tr.texture = _tex(RARITY_FRAME % q)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		fr = tr
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_child(fr)
	var l := _label(22, qc)
	l.text = QUALITY_NAMES.get(q, "")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD # « Peu / commun » sur deux lignes, jamais un mot coupé
	l.offset_left = 8
	l.offset_right = -8
	tile.add_child(l)
	(parent if parent != null else _reel).add_child(tile)
	return tile


## Ajuste la police du nom de rareté à la largeur du bandeau (l'échelle 1,2 x de l'animation compris).
func _fit_quality() -> void:
	var w := _quality.size.x
	if w < 10.0:
		w = _quality.get_parent_control().size.x if _quality.get_parent_control() != null else 0.0
	var fs := Accessibility.fs(60)
	if w >= 10.0:
		var font := _quality.get_theme_font(&"font")
		while fs > HudMetrics.floor_px() and font.get_string_size(_quality.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.2 > w:
			fs -= 2
	_quality.add_theme_font_size_override("font_size", fs)


func _layout_reel() -> void:
	_layout_strip(_reel, _reel_tiles, _reel_pos)
	for x in _xr:
		_layout_strip(x["reel"], x["tiles"], float(x["pos"]))


func _layout_strip(reel: Control, tiles: Array, pos: float) -> void:
	if reel == null or reel.size.x < 10.0:
		return
	var w := reel.size.x
	var h := reel.size.y
	_tile_px = clampf(h - 6.0, 60.0, 150.0)
	var t := _tile_px
	var pitch := t + 16.0
	# police : le mot le plus long (« Légendaire ») tient sur la largeur de la case, jamais coupé
	var fs := clampi(int(t * 0.17), 12, 26)
	if not tiles.is_empty():
		var font := (tiles[0].get_child(2) as Label).get_theme_font(&"font")
		var widest := ["Légendaire", "Peu commun"] # + tous les noms des cases : le plus large (« Peu commun ») fixe la police
		for tl in tiles:
			widest.append((tl.get_child(2) as Label).text)
		while fs > 10 and widest.any(func(s: String) -> bool: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > t - 22.0):
			fs -= 1
	for k in tiles.size():
		var tile: Control = tiles[k]
		var d := float(k) - pos
		var ad := absf(d)
		tile.size = Vector2(t, t)
		tile.pivot_offset = tile.size * 0.5
		tile.position = Vector2(w * 0.5 + d * pitch - t * 0.5, (h - t) * 0.5)
		tile.visible = ad * pitch < w * 0.5 + t
		var dim := clampf(ad / 1.5, 0.0, 1.0)
		tile.modulate = Color(1, 1, 1).lerp(Color(0.38, 0.38, 0.42, 0.85), dim)
		tile.scale = Vector2.ONE * (1.0 + 0.12 * maxf(0.0, 1.0 - ad))
		var lbl := tile.get_child(2) as Label
		lbl.add_theme_font_size_override("font_size", fs)


func _ease_rarity(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), RARITY_EASE[_rank])


func _ease_items(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.4)


## Lance la mise en scène : `with_rarity` = ouverture (rareté puis items) ; sinon relance (items seuls).
func _start_reveal(with_rarity: bool) -> void:
	_cancel_press()
	_busy = true
	_animating = true
	_anim_t = 0.0
	_rank = maxi(0, LootRoller.quality_rank(session.quality))
	# Réglage « Animation des coffres » : Complète ×1, Courte, Instantanée ([0, 0]) = résultat direct.
	var mult: Array = GameSettings.chest_reveal_mult()
	var rar_k := maxf(0.0, float(mult[0]))
	var item_k := maxf(0.0, float(mult[1]))
	for i in 2:
		_item_dur[i] = float(ITEM_DUR[i]) * item_k
	if with_rarity:
		_build_reel()
		_rar_dur = RARITY_DUR[_rank] * rar_k * (MULTI_WHEEL_K if not _xr.is_empty() else 1.0)
		for x in _xr:
			x["dur"] = minf(RARITY_DUR[int(x["rank"])] * rar_k * MULTI_WHEEL_K, _rar_dur)
			x["landed"] = _rar_dur <= 0.0
			x["pos"] = 2.0
			(x["panel"] as Control).modulate = Color.WHITE
		_layout_stage()
		_rar_landed = false
		_item_t0 = _rar_dur + ITEM_GAP
	else:
		_rar_dur = 0.0
		_rar_landed = true
		_item_t0 = 0.0
	var pool: Array = LootRoller.available_ids(session.quality)
	for i in 2:
		_item_step[i] = -1
		_item_landed[i] = i >= session.offered.size()
		var seq: Array = []
		if not _item_landed[i]:
			var target := str(session.offered[i])
			var steps: int = ITEM_STEPS[i]
			for k in steps - 1:
				var id := target
				if pool.size() > 1:
					for _a in 4:
						id = str(pool[_pres.randi_range(0, pool.size() - 1)])
						if id != target and (seq.is_empty() or id != seq[-1]):
							break
				seq.append(id)
			seq.append(target)
		_item_seq[i] = seq
	_end_t = _item_t0 + _item_dur[1] + END_HOLD
	_update_buttons()
	if rar_k <= 0.0 and item_k <= 0.0:
		_instant_reveal(with_rarity)


## Réglage « Instantanée » : résultat affiché tout de suite avec le son de rareté (éclat soumis à flash_scale).
## Ce n'est pas un skip : ni verrou de relâcher ni `skipped`, l'écran est prêt aussitôt.
func _instant_reveal(with_rarity: bool) -> void:
	if with_rarity:
		_land_rarity(true)
	else:
		Audio.play_ui(&"ui.spell_ready", -1.0, 0.8 + 0.12 * _rank)
	for i in 2:
		if not _item_landed[i]:
			_land_card(i, false)
	_end_reveal()


func _process(delta: float) -> void:
	if not _animating or session == null:
		return
	_anim_t += delta
	if not _rar_landed:
		var u := clampf(_anim_t / maxf(_rar_dur, 0.01), 0.0, 1.0)
		_reel_pos = lerpf(_reel_from, _reel_to, _ease_rarity(u))
		_layout_reel()
		# coffre : tremblement qui monte (plus fort pour les hautes raretés)
		var amp := (3.0 + 15.0 * u) * (0.7 + 0.2 * _rank)
		_icon.position = _icon_home + Vector2(_pres.randf_range(-amp, amp), _pres.randf_range(-amp, amp) * 0.5)
		_icon.rotation = deg_to_rad(_pres.randf_range(-amp, amp) * 0.25)
		for x in _xr:
			if x["landed"]:
				continue
			var xu := clampf(_anim_t / maxf(float(x["dur"]), 0.01), 0.0, 1.0)
			x["pos"] = lerpf(2.0, float(x["to"]), 1.0 - pow(1.0 - xu, RARITY_EASE[int(x["rank"])]))
			var xk := roundi(float(x["pos"]))
			if xk != int(x["last"]):
				x["last"] = xk
				Audio.play_ui(&"ui.hover", -14.0 + 4.0 * xu, 0.7 + 0.35 * xu)
			if xu >= 1.0:
				_land_extra(x, true)
		var k := roundi(_reel_pos)
		if k != _last_tick:
			_last_tick = k
			Audio.play_ui(&"ui.hover", -9.0 + 5.0 * u, 0.85 + 0.45 * u + 0.06 * _rank)
		if k >= 0 and k < _reel_seq.size(): # nom de la case au centre, en sourdine
			var cq: StringName = _reel_seq[k]
			_quality.text = QUALITY_NAMES.get(cq, "")
			_fit_quality()
			_quality.add_theme_color_override("font_color", (Palette.rarity(cq) as Color).darkened(0.35))
		if u >= 1.0:
			_land_rarity(true)
	if _rar_landed:
		for i in 2:
			if _item_landed[i]:
				continue
			var ti := _anim_t - _item_t0
			if ti < 0.0:
				continue
			_spin_card(i, clampf(ti / maxf(_item_dur[i], 0.001), 0.0, 1.0))
	if _rar_landed and _item_landed[0] and _item_landed[1] and _anim_t >= _end_t:
		_end_reveal()


## Pose une roue secondaire sur son jet.
func _land_extra(x: Dictionary, fx: bool) -> void:
	if x["landed"] and x["pos"] == x["to"]:
		return
	x["landed"] = true
	x["pos"] = x["to"]
	_layout_reel()
	if fx:
		var tl: Array = x["tiles"]
		var tile: Control = tl[int(x["to"])]
		var tw := create_tween()
		tw.tween_property(tile, "scale", Vector2.ONE * 1.2, 0.08)
		tw.tween_property(tile, "scale", Vector2.ONE * 1.12, 0.12)


## La roue principale est posée : les autres s'arrêtent, se grisent ; la meilleure est mise en valeur.
func _settle_wheels(fx: bool) -> void:
	if _xr.is_empty():
		return
	for x in _xr:
		_land_extra(x, false)
		(x["panel"] as Control).modulate = Color(0.55, 0.55, 0.6, 0.8)
	_reel_panel.modulate = Color.WHITE
	if fx:
		_reel_panel.pivot_offset = _reel_panel.size * 0.5
		var tp := create_tween()
		tp.tween_property(_reel_panel, "scale", Vector2.ONE * 1.06, 0.1)
		tp.tween_property(_reel_panel, "scale", Vector2.ONE * 1.03, 0.14)
	else:
		_reel_panel.scale = Vector2.ONE


## Rareté posée : coffre ouvert, nom en couleur ; `fx` = rebond, flash (rare et plus) et son.
func _land_rarity(fx: bool) -> void:
	_rar_landed = true
	_reel_pos = _reel_to
	_layout_reel()
	_icon.position = _icon_home
	_icon.rotation = 0.0
	var qc: Color = Palette.rarity(session.quality)
	_set_chest_state(&"open", Color.WHITE.lerp(qc, 0.25))
	_quality.text = QUALITY_NAMES.get(session.quality, "")
	_fit_quality()
	_quality.add_theme_color_override("font_color", qc)
	_settle_wheels(fx)
	if session != null and Audio.has_method(&"chest_sequence_land"):
		Audio.chest_sequence_land() # frappe légendaire calée sur l'arrêt réel (ou le skip)
	if not fx:
		return
	Audio.play_ui(&"ui.spell_ready", -1.0, 0.8 + 0.12 * _rank)
	var tile: Control = _reel_tiles[int(_reel_to)] if int(_reel_to) < _reel_tiles.size() else null
	if tile != null:
		var tw := create_tween()
		tw.tween_property(tile, "scale", Vector2.ONE * 1.3, 0.08)
		tw.tween_property(tile, "scale", Vector2.ONE * 1.12, 0.16)
	_quality.pivot_offset = _quality.size * 0.5
	var tq := create_tween()
	tq.tween_property(_quality, "scale", Vector2.ONE * 1.2, 0.08)
	tq.tween_property(_quality, "scale", Vector2.ONE, 0.16)
	if _rank >= 2 and GameSettings.flash_scale() > 0.0:
		_flash.color = Color(qc.r, qc.g, qc.b, 0.0)
		var tf := create_tween()
		tf.tween_property(_flash, "color:a", (0.2 if _rank == 2 else 0.3) * GameSettings.flash_scale(), 0.04)
		tf.tween_property(_flash, "color:a", 0.0, 0.08)


## Un pas du défilement d'items d'une carte : l'icône suivante glisse depuis le haut dans la fenêtre d'illustration.
func _spin_card(i: int, u: float) -> void:
	var seq: Array = _item_seq[i]
	var n := seq.size()
	var f := float(n) * _ease_items(u)
	var k := mini(n - 1, int(f))
	var frac := 1.0 if u >= 1.0 else clampf(f - float(k), 0.0, 1.0)
	if k != _item_step[i]:
		if _item_step[i] < 0:
			_show_front(i)
			_cards[i].scale = Vector2(0.92, 0.92)
			create_tween().tween_property(_cards[i], "scale", Vector2.ONE, 0.12)
		_item_step[i] = k
		var id := str(seq[k])
		var it := ItemDB.get_item(id)
		_card_icons[i].texture = _tex(ITEM_ICON % id)
		var name_l := _card_front[i].get_child(1) as Label
		name_l.text = str(it.get("name", id))
		name_l.add_theme_color_override("font_color", (Palette.rarity(session.quality) as Color).darkened(0.25))
		_fit_card(i)
		Audio.play_ui(&"ui.hover", -12.0 + 4.0 * u, 1.0 + 0.3 * u + 0.1 * i)
	var art_h := _card_boxes[i].size.y
	_card_boxes[i].position = _card_art_pos[i] + Vector2(0.0, -(1.0 - frac) * art_h * 0.4)
	_card_icons[i].modulate.a = 0.3 + 0.7 * frac
	if u >= 1.0:
		_land_card(i, true)


## Face avant d'une carte pendant le défilement : cadre DA, rareté, description vide.
func _show_front(i: int) -> void:
	_cards[i].add_theme_stylebox_override("panel", _front_sb[i])
	_card_front[i].visible = true
	_card_back[i].visible = false
	_card_rarity[i].texture = _tex(RARITY_FRAME % session.quality)
	_set_rarity_label(i, session.quality)
	for c in [2, 3, 4]:
		(_card_front[i].get_child(c) as Label).text = ""


## Carte posée sur l'item tiré (texte complet) ; `fx` = rebond et son.
func _land_card(i: int, fx: bool) -> void:
	_item_landed[i] = true
	if i >= session.offered.size():
		return
	_card_icons[i].modulate.a = 1.0
	_card_front[i].visible = true
	_card_back[i].visible = false
	_fill_card(i)
	if fx:
		Audio.play_ui(&"ui.spell_ready", -5.0, 1.25 + 0.1 * i)
		_cards[i].scale = Vector2.ONE * 1.06
		create_tween().tween_property(_cards[i], "scale", Vector2.ONE, 0.14)
	else:
		_cards[i].scale = Vector2.ONE


func _end_reveal() -> void:
	_animating = false
	_busy = false
	_update_buttons()
	_update_rings()


## Skip : tout se pose immédiatement sur le tirage (aucun choix, verrou jusqu'au relâcher).
func _finish_reveal() -> void:
	if not _animating or session == null:
		return
	skipped = true
	if not _rar_landed:
		_land_rarity(false)
	for i in 2:
		if not _item_landed[i]:
			_land_card(i, false)
	_cards[0].scale = Vector2.ONE
	_cards[1].scale = Vector2.ONE
	_skip_lock_until = Time.get_ticks_msec() + SKIP_LOCK_MS
	_skip_wait_release = true
	Audio.play_ui(&"ui.spell_ready", -4.0, 0.8 + 0.12 * _rank)
	_end_reveal()


func _set_card_hidden(i: int) -> void:
	_card_front[i].visible = false
	_card_back[i].visible = true
	_cards[i].add_theme_stylebox_override("panel", _back_sb[i])
	_cards[i].scale = Vector2.ONE


## Nom de la rareté en capitales sur la carte (la couleur n'est jamais seule à la porter).
func _set_rarity_label(i: int, q: StringName) -> void:
	var l := _card_front[i].get_child(5) as Label
	l.text = String(QUALITY_NAMES.get(q, "")).to_upper() + Palette.rank_suffix(q)
	l.add_theme_color_override("font_color", (Palette.rarity(q) as Color).lerp(Color.WHITE, 0.2))


func _fill_card(i: int) -> void:
	var id: String = session.offered[i]
	var it := ItemDB.get_item(id)
	var f := _card_front[i]
	var qc: Color = Palette.rarity(StringName(str(it.get("quality", session.quality))))
	_card_icons[i].texture = _tex(ITEM_ICON % id)
	var q := str(it.get("quality", session.quality))
	_card_rarity[i].texture = _tex(RARITY_FRAME % q)
	_set_rarity_label(i, StringName(q))
	f.get_child(1).text = str(it.get("name", id))
	f.get_child(1).add_theme_color_override("font_color", qc)
	f.get_child(2).text = str(it.get("effect_text", ""))
	var tag_texts: Array = []
	for t in it.get("tags", []):
		tag_texts.append("[%s]" % str(t))
	f.get_child(3).text = "  ".join(tag_texts)
	f.get_child(3).add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	var owned := RunState.stacks(StringName(id))
	f.get_child(4).text = stack_line(id, owned) if owned > 0 else "Nouveau"
	f.get_child(4).add_theme_color_override("font_color", Color(1, 0.85, 0.4) if owned > 0 else Color(0.5, 1, 0.6))
	var sb := _front_sb[i]
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).border_color = qc
	_cards[i].add_theme_stylebox_override("panel", sb)
	_fit_card(i)


# ---------------------------------------------------------------- boutons
## Libellé du bouton de relance à l'or : « Gratuite » quand le prix est nul (Faveur du marchand), sinon le prix.
static func gold_button_text(price: float) -> String:
	if price <= 0.0:
		return "Relancer (or)\nGratuite"
	return "Relancer (or)\n%d or" % int(ceil(price))


func _update_buttons() -> void:
	if session == null:
		_ad_btn.disabled = true
		_gold_btn.disabled = true
		return
	_ad_btn.visible = AdHook.is_available()
	var left := ChestSession.MAX_AD_REROLLS_PER_RUN - ChestSession.run_ad_rerolls()
	if not session.can_ad_reroll():
		_ad_btn.text = "Relancer (pub)\nlimite atteinte"
	elif AdHook.is_free():
		_ad_btn.text = "Relancer (gratuit)\n%d/%d" % [left, ChestSession.MAX_AD_REROLLS_PER_RUN]
	else:
		_ad_btn.text = "Relancer (pub)\n%d/%d" % [left, ChestSession.MAX_AD_REROLLS_PER_RUN]
	_ad_btn.disabled = _busy or not session.can_ad_reroll()
	_gold_btn.text = gold_button_text(session.gold_reroll_price())
	_gold_btn.disabled = _busy or not session.can_gold_reroll()
	_refresh_items_button()
	if not _busy:
		var fo := get_viewport().gui_get_focus_owner()
		if fo == null or (fo is Button and fo.disabled):
			_cards[0].grab_focus()


# ---------------------------------------------------------------- bouton Objets (lot L6, Audit_Choix P10)
## Bouton « Objets (N) » sous la rareté : consulter son inventaire sans quitter le choix (manette : Select,
## clavier : Tab). Ouvre PauseMenu.open_items() en consultation seule ; masqué s'il n'y a pas de menu pause.
func _build_items_button(parent: Control) -> void:
	_items_btn = _button("Objets", &"chest_items")
	_items_key = _ad_key # _button() range l'invite dans _ad_key ; la vraie relance pub la réaffecte ensuite
	_items_btn.name = "ItemsButton"
	_items_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_items_btn.custom_minimum_size = Vector2(380, BUTTON_H)
	_items_btn.pressed.connect(open_items)
	_items_btn.visible = false
	parent.add_child(_items_btn)


func _refresh_items_button() -> void:
	if _items_btn == null:
		return
	_items_btn.visible = _pause_menu() != null
	_items_btn.text = "Objets (%d)" % RunState.items.size()
	_items_btn.disabled = _busy


func _pause_menu() -> Node:
	if not is_inside_tree():
		return null
	var pm := get_tree().get_first_node_in_group(&"pause_menu")
	return pm if pm != null and pm.has_method(&"open_items") else null


## La liste des objets est ouverte par-dessus l'écran de coffre (tests).
func items_open() -> bool:
	var pm := _pause_menu()
	return pm != null and bool(pm.get(&"items_only"))


## Ouvre la liste des objets possédés (résultat affiché seulement ; jamais pendant l'animation).
func open_items() -> void:
	if _animating or _opening or _busy or session == null or items_open():
		return
	var pm := _pause_menu()
	if pm == null:
		return
	_cancel_press()
	if not pm.is_connected(&"items_closed", _on_items_closed):
		pm.connect(&"items_closed", _on_items_closed, CONNECT_ONE_SHOT)
	pm.call(&"open_items")


func _on_items_closed() -> void:
	if not is_inside_tree() or Platform.is_touch_mode():
		return
	if _items_btn != null and _items_btn.visible:
		_items_btn.grab_focus.call_deferred()


## Coffre affiché dans l'intro : planche « closed » / « open » du SpriteFrames du coffre.
func _set_chest_state(state: StringName, tint: Color) -> void:
	if _chest_frames != null and _chest_frames.has_animation(state) and _chest_frames.get_frame_count(state) > 0:
		_icon.texture = _chest_frames.get_frame_texture(state, 0)
	_icon.modulate = tint


## Choix au relâcher : l'appui enfonce la carte, le relâcher dans la carte valide, glisser hors de la carte annule.
## Entrée / A (ui_accept) suit la même règle ; les raccourcis 1 / 2 / LB / RB valident directement (_input).
func _on_card_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept")
	if pressed:
		if _card_front[i].visible and not _animating and not _busy and not _skip_locked():
			get_viewport().set_input_as_handled()
			_press_card = i
			_set_pressed(i, true)
		return
	if _press_card != i:
		return
	var released: bool = (event is InputEventMouseButton and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed) or event.is_action_released("ui_accept")
	if released:
		get_viewport().set_input_as_handled()
		var inside := true
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			inside = Rect2(Vector2.ZERO, _cards[i].size).has_point(event.position)
		_cancel_press()
		if inside and not _skip_locked():
			_on_choose(i)
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) \
			and not Rect2(Vector2.ZERO, _cards[i].size).has_point(event.position):
		_cancel_press() # le doigt / le curseur a quitté la carte : annulé


func _set_pressed(i: int, on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cards[i], "scale", Vector2.ONE * (0.96 if on else (1.04 if _cards[i].has_focus() else 1.0)), 0.06)
	tw.tween_property(_cards[i], "modulate", Color(0.82, 0.82, 0.82) if on else Color.WHITE, 0.06)


## Annule l'appui en cours (relâché hors de la carte, nouvelle animation, fermeture).
func _cancel_press() -> void:
	var i := _press_card
	_press_card = -1
	if i >= 0 and i < _cards.size() and is_instance_valid(_cards[i]):
		_set_pressed(i, false)


func _hover_card(i: int, on: bool) -> void:
	if _busy or _press_card == i:
		return
	create_tween().tween_property(_cards[i], "scale", Vector2.ONE * (1.04 if on else 1.0), 0.08)


func _on_choose(i: int) -> void:
	if _busy or _animating:
		return
	_busy = true
	session.choose(get_tree(), i)
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()


func _do_reroll(ok: bool) -> void:
	if not ok:
		_busy = false
		_update_buttons()
		return
	skipped = false
	_start_reveal(false)


func _on_ad_reroll() -> void:
	if _busy:
		return
	_busy = true
	_update_buttons()
	_do_reroll(session.do_ad_reroll())


func _on_gold_reroll() -> void:
	if _busy:
		return
	_busy = true
	_update_buttons()
	_do_reroll(session.do_gold_reroll())
