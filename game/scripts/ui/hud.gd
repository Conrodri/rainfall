class_name Hud
extends CanvasLayer
## HUD de jeu : PV, XP/niveau, or, temps actif, jauge de difficulte, 3 boutons de sorts tactiles avec
## recharge, barre des 4 sorts (clavier-souris / manette : icone, recharge, touche du mode courant),
## aide des commandes au demarrage de la premiere partie (8 s), bouton pause (appui long), joystick
## flottant (moitie basse) et menu pause.
## Minimap (haut-droite, a gauche du bouton pause), inventaire des items sous les PV (ItemBar : lignes
## multiples au clavier-souris / manette, rangee defilante en tactile) et barres de boss (haut-centre).
## Vague 3 : difficulté sous la minimap ; taux de régénération « +X/s » (PV dans la barre, ressource dans la jauge) ;
## barres PV + ressource au-dessus de la tête du personnage (OverheadBars, réglage « Barres au-dessus du personnage »).
## Mise en page adaptative (ancrages + conteneurs) : portrait mobile (1080 de large), paysage PC (1080 de haut),
## recalculee a chaque redimensionnement. Controles tactiles masques hors mode tactile (Platform.input_mode).
## Instanciation : scenes/ui/hud.tscn (ou Hud.new()). Le joueur est cherche dans le groupe "player"
## (ou fourni par bind_player()). Signal abandon_requested relaye depuis le menu pause.

signal abandon_requested
signal save_quit_requested ## relaye depuis le menu pause (« Sauvegarder et quitter »)

const TIER_NAMES: Array[StringName] = [&"Calme", &"Tendu", &"Hostile", &"Furieux", &"Cataclysme"]
const TIER_COLORS := {
	&"Calme": Color(0.35, 0.8, 0.45),
	&"Tendu": Color(0.95, 0.85, 0.25),
	&"Hostile": Color(0.98, 0.55, 0.15),
	&"Furieux": Color(0.9, 0.2, 0.2),
	&"Cataclysme": Color(0.75, 0.2, 0.9),
}
const D_MAX := 8.0 ## fin de la jauge (Cataclysme >= 6)
const HELP_DURATION_S := 8.0
const HELP_FADE_S := 1.0
const KEY_HINTS_SHOW_S := 5.0 ## invites de touches sous les sorts : durée affichée en début de partie (réglage « toujours » désactivé)
const KEY_HINTS_FADE_S := 0.8 ## puis fondu
const KEY_HINTS_POLL_S := 0.5 ## relecture du réglage (changé dans les paramètres en cours de partie)

var player: Node
var joystick: FloatingJoystick
var pause_menu: PauseMenu
var spell_buttons: Array[SpellButton] = [] ## boutons tactiles (sorts 2-4)
var bar_buttons: Array[SpellButton] = [] ## barre clavier-souris / manette (sorts 1-4)
var dodge_button: DodgeButton ## bouton tactile Roulade (simule l'action dodge)
var auto_indicator: SpellButton ## tactile : petite icône du sort 1 (automatique, non cliquable)
var bar_dodge: DodgeButton ## recharge de la roulade, à droite de la barre de sorts
var bar_gauge: ResourceGauge ## ressource du kit (KitResource), à gauche de la barre de sorts (clavier-souris / manette)
var touch_gauge: ResourceGauge ## ressource du kit, au-dessus de la grappe de sorts tactiles
var bar_dodge_key: KeyPrompt
var pause_button: PauseButton
var interact_button: InteractButton
var interact_target: Node
var root: Control
var touch_layer: Control ## joystick + boutons de sorts + Interagir (mode tactile seulement)
var reticle: AimReticle
var ui_scale := 1.0

var _hp_bar: ProgressBar
var _badge_label: Label ## niveau, dans le médaillon level_badge
var _portrait: TextureRect = null ## buste du personnage (CharacterCard.portrait_info), absent = pas de nœud
var _name_label: Label ## nom du personnage
var _gold_box: HBoxContainer ## icône + or, en haut à droite
var _time_plate: PanelContainer ## chrono sur timer_plate
var _frames: Array = [] ## [barre, NinePatchRect, Vector4 marges] : cadres DA posés autour des barres
var _hp_label: Label
var _xp_bar: ProgressBar
var _gold_label: Label
var _time_label: Label
var _diff_bar: ProgressBar
var _diff_label: Label
var _diff_caption: Label ## titre « Difficulté » au-dessus de la jauge (sans lui, la barre restait muette pour un nouveau joueur)
var _diff_style: StyleBoxFlat
var _find_timer := 0.0
var _top: MarginContainer
var _left_col: VBoxContainer
var _center_col: VBoxContainer
var _corner: Control
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _was_ready := {} ## slot -> sort prêt à la dernière image (son « sort prêt » à la transition)
var _spell_bar: HBoxContainer
var bar_keys: Array[KeyPrompt] = [] ## invite de touche sous chaque sort de la barre
var key_hints_always := false ## réglage « Afficher les touches sous les sorts » (GameSettings.key_hints)
var _hints_t := 0.0 ## temps écoulé depuis le début de la partie (invites)
var _hints_poll := 0.0
var _hints_alpha := 1.0
var _help_panel: PanelContainer
var _help_grid: GridContainer
var _help_left := 0.0
var minimap: Minimap
var item_bar: ItemBar
var boss_bars: BossBars
var objectives: ObjectivesPanel ## objectifs d'étage (boss, charge, téléporteur), sous la minimap
var spell_hint: SpellHint ## description d'un sort : survol (souris) / appui long (tactile)
var _overlay_tick := 0.0
var overhead: OverheadBars ## PV + ressource au-dessus de la tête du personnage (réglage GameSettings.overhead_bars)
var _diff_box: HBoxContainer ## difficulté (nom du palier + jauge sur une ligne) : sous la minimap, colonne de droite
var _hp_regen: Label ## « +X/s » (Player.regen_per_s) dans la barre de PV
var _regen_tick := 0.0
var _player_plate: Control ## plaque de la fiche joueur (médaillon, nom, PV, XP)
var _map_plate: Panel ## plaque commune minimap + difficulté (H17)
var _hp_low := false
const OFFSCREEN_CUES := preload("res://scripts/ui/offscreen_cues.gd")
var offscreen_cues: Control ## A11y-L9 (scripts/ui/offscreen_cues.gd)


func _ready() -> void:
	layer = 10
	_build()
	offscreen_cues = OFFSCREEN_CUES.new() # A11y-L9 : flèches de menace hors écran, sous les contrôles du HUD
	offscreen_cues.call(&"bind", self)
	root.add_child(offscreen_cues)
	root.move_child(offscreen_cues, 1)
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	Platform.input_mode_changed.connect(_on_mode_changed)
	Platform.safe_area_changed.connect(_apply_layout) # encoche passée de côté sans redimensionnement (A11y-L4, E-04)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.abandon_requested.connect(func() -> void: abandon_requested.emit())
	pause_menu.save_quit_requested.connect(func() -> void: save_quit_requested.emit())
	pause_button.long_pressed.connect(pause_menu.open)
	spell_hint = SpellHint.new()
	spell_hint.name = "SpellHint"
	spell_hint.bind(self)
	add_child(spell_hint)
	_apply_mode()
	RunState.gold_changed.connect(_on_gold)
	RunState.xp_changed.connect(_on_xp)
	RunState.level_up.connect(_on_level)
	RunState.difficulty_changed.connect(_on_difficulty)
	Events.gold_converted.connect(_on_gold_converted)
	_on_gold(RunState.gold)
	_on_xp(RunState.xp, Balance.xp_required(RunState.level))
	_on_level(RunState.level)
	_on_difficulty(RunState.difficulty(), Balance.difficulty_tier_name(RunState.difficulty()))
	_find_player()
	_place_boss_bars()
	if not bool(GameSettings.get_value("gameplay", "help_shown", false)):
		show_controls_help()
		GameSettings.set_value("gameplay", "help_shown", true)


func bind_player(p: Node) -> void:
	player = p
	if overhead != null:
		overhead.bind(p)
	if p != null and p.has_signal("hp_changed"):
		if not p.hp_changed.is_connected(_on_hp):
			p.hp_changed.connect(_on_hp)
		var hp: Variant = p.get("hp")
		var mx: Variant = p.get("max_hp")
		if hp != null and mx != null:
			_on_hp(float(hp), float(mx))


func _find_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		bind_player(p)


func _process(delta: float) -> void:
	_time_label.text = _fmt_time(RunState.active_time_s)
	_update_help(delta)
	_update_key_hints(delta)
	_update_interact()
	_update_reticle()
	_overlay_tick -= delta
	if _overlay_tick <= 0.0:
		_overlay_tick = 0.1
		_place_difficulty() # suit le losange de la minimap (carte liée après le HUD)
		if boss_bars.visible or objectives.visible:
			_place_boss_bars()
			_place_objectives()
	if player == null or not is_instance_valid(player):
		player = null
		_hp_regen.text = ""
		_find_timer -= delta
		if _find_timer <= 0.0:
			_find_timer = 0.5
			_find_player()
		return
	if player.has_method("get_spell_cooldowns"):
		var cds: Array = player.get_spell_cooldowns()
		for cd in cds:
			var sl := int(cd.get("slot", -1))
			var rem := float(cd.get("remaining", 0.0))
			var tot := float(cd.get("total", 0.0))
			var ch: Vector2i = cd.get("charges", Vector2i(-1, 0))
			for b in spell_buttons + bar_buttons + [auto_indicator]:
				if b.slot == sl:
					b.set_spell(StringName(cd.get("id", &"")), str(cd.get("name", "")), bool(cd.get("auto", false)))
					b.set_cooldown(rem, tot)
					b.set_charges(ch.x, ch.y, _accent())
					var cost: Dictionary = cd.get("cost", {})
					b.set_affordable(bool(cd.get("affordable", true)), String(cost.get("lack", "")), String(cost.get("cost", "")))
			var ready := rem <= 0.0
			if sl >= 2 and ready and _was_ready.has(sl) and not _was_ready[sl]:
				Audio.spell_ready(sl)
			_was_ready[sl] = ready
	_regen_tick -= delta
	if _regen_tick <= 0.0:
		_regen_tick = 0.25
		_hp_regen.text = fmt_rate(float(player.regen_per_s())) if player.has_method(&"regen_per_s") else ""
		_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _hp_regen.text != "" else HORIZONTAL_ALIGNMENT_CENTER
	var res := KitResource.of(player)
	bar_gauge.set_state(res)
	touch_gauge.set_state(res)
	if bar_gauge.visible:
		_place_bar_gauge()


static func _fmt_time(s: float) -> String:
	var t := int(s)
	return "%02d:%02d" % [t / 60, t % 60]


## Invites de touches sous les sorts : visibles 5 s au début de chaque partie puis fondu (0,8 s), sauf si le
## réglage les garde toujours affichées. Le HUD est recréé à chaque nouvelle partie : le compteur repart de 0.
func _update_key_hints(delta: float) -> void:
	_hints_t += delta
	_hints_poll -= delta
	if _hints_poll <= 0.0:
		_hints_poll = KEY_HINTS_POLL_S
		key_hints_always = GameSettings.key_hints()
		overhead.enabled = GameSettings.overhead_bars()
	var a := 1.0
	if not key_hints_always:
		a = clampf(1.0 - (_hints_t - KEY_HINTS_SHOW_S) / KEY_HINTS_FADE_S, 0.0, 1.0)
	if is_equal_approx(a, _hints_alpha):
		return
	_hints_alpha = a
	for kp in bar_keys:
		kp.modulate.a = a
	bar_dodge_key.modulate.a = a


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = maxf(max_hp, 1.0)
	_hp_bar.value = clampf(hp, 0.0, max_hp)
	_hp_label.text = "%d / %d" % [int(ceil(hp)), int(ceil(max_hp))]
	_set_hp_low(max_hp > 0.0 and hp / max_hp <= HudMetrics.LOW_HP_FRAC)


## PV du joueur : vert, rouge vif sous 25 % (même règle que OverheadBars). Sans effet si le remplissage est une texture.
func _set_hp_low(low: bool) -> void:
	if low == _hp_low:
		return
	_hp_low = low
	var sb := _hp_bar.get_theme_stylebox("fill")
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = HudMetrics.COL_HP_LOW if low else HudMetrics.COL_HP
	elif sb is StyleBoxTexture: # texture verte livrée : teinte rouge sous 25 %
		(sb as StyleBoxTexture).modulate_color = Color(1.0, 0.45, 0.4) if low else Color.WHITE


func _on_gold(g: float) -> void:
	_gold_label.text = "%d" % int(g)
	_place_gold()
	_progress_gold_changed(g) # Choix-L4 : impulsion du compteur à l'arrivée des pièces


## Or : rangée calée à DROITE contre le bouton pause (grandit vers la gauche quand le nombre s'allonge).
func _place_gold() -> void:
	if _gold_box == null or pause_button == null:
		return
	var s := ui_scale
	_gold_box.reset_size()
	var right := pause_button.get_global_rect().position.x - 20.0 * s
	_gold_box.position = Vector2(right - _gold_box.size.x, pause_button.offset_top + (pause_button.size.y - _gold_box.size.y) * 0.5)


## Zone sûre du bandeau du haut et du bouton pause (A11y-L4, E-04) : Platform.safe_margins() sur mobile (ou encoche
## simulée), rien sur PC (les marges de base du HUD suffisent).
func _hud_safe() -> Dictionary:
	if HudMetrics.is_mobile() or not Platform.safe_override.is_empty():
		return Platform.safe_margins()
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}


func _on_xp(xp: float, required: float) -> void:
	_xp_bar.max_value = maxf(required, 1.0)
	_xp_bar.value = xp


func _on_level(l: int) -> void:
	_badge_label.text = str(l)
	_progress_level_changed(l) # Choix-L4 : médaillon, « Niveau N », éclat de la barre d'XP


func _on_difficulty(D: float, tier_name: StringName) -> void:
	_diff_bar.value = clampf(D, 0.0, D_MAX)
	var col: Color = TIER_COLORS.get(tier_name, Color.WHITE)
	_diff_style.bg_color = col
	_diff_label.text = String(tier_name)
	_diff_label.add_theme_color_override("font_color", col)


# --- Construction : ancrages + conteneurs, dimensions recalculees selon le ratio du viewport
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overhead = OverheadBars.new() # sous tous les contrôles du HUD
	overhead.name = "OverheadBars"
	root.add_child(overhead)

	# Couche tactile (joystick, boutons de sorts, Interagir) : visible seulement en mode tactile.
	touch_layer = Control.new()
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)

	# joystick : moitie basse a gauche, tout en dessous des autres controles
	joystick = FloatingJoystick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.6 ## colonne droite (40 %) reservee aux boutons
	joystick.anchor_top = 0.5
	joystick.anchor_bottom = 1.0
	touch_layer.add_child(joystick)

	# bandeau du haut : colonne PV/XP/or | temps/difficulte | (pause en surimpression a droite)
	_top = MarginContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_top)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(row)

	_left_col = VBoxContainer.new()
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_left_col)
	# bloc haut-gauche (maquette U1) : médaillon de niveau, nom, barre de vie, barre d'XP
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pb := UiTheme.da_box("panel_small_9slice", 0.5)
	if pb != null:
		plate.add_theme_stylebox_override(&"panel", pb)
	_player_plate = plate
	_left_col.add_child(plate)
	var prow := HBoxContainer.new()
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_theme_constant_override("separation", 12)
	plate.add_child(prow)
	# même recherche que les menus (ui/portraits/<id>.png puis characters/<id>/portrait.png) ; buste seulement
	var pinfo := CharacterCard.portrait_info({"id": String(RunState.character)})
	var ptex: Texture2D = pinfo.tex if pinfo.bust else null
	if ptex != null: # portrait livré (Blender) : avant le médaillon ; sinon rien (pas de repli sur le sprite)
		_portrait = TextureRect.new()
		_portrait.texture = ptex
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.name = "Portrait"
		prow.add_child(_portrait)
	var badge := _make_badge()
	prow.add_child(badge)
	var stats := VBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 4)
	prow.add_child(stats)
	_name_label = _make_label(stats)
	_name_label.text = _character_name()
	_hp_bar = _make_bar(stats, HudMetrics.COL_HP, "hp_green") # PV du joueur : VERT partout (le rouge = ennemis)
	_hp_label = _bar_label(_hp_bar)
	_hp_regen = _bar_label(_hp_bar) # régénération « +X/s », à droite dans la barre
	_hp_regen.name = "HpRegen"
	_hp_regen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_regen.add_theme_color_override("font_color", HudMetrics.COL_REGEN)
	for bl in [_hp_label, _hp_regen]: # contour : lisible sur le vert comme sur la traîne blanche
		bl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		bl.add_theme_constant_override("outline_size", HudMetrics.OUTLINE_T3)
	_hp_label.add_theme_constant_override("outline_size", HudMetrics.OUTLINE_T1)
	HpTrail.attach(_hp_bar) # traîne blanche de la portion perdue (scripts/fx/hp_trail.gd)
	_frame_bar(_hp_bar, "bar_frame_hp")
	_xp_bar = _make_bar(stats, HudMetrics.COL_XP, "xp")
	_frame_bar(_xp_bar, "bar_frame_xp")
	# niveau : le médaillon seul (la ligne « NIVEAU n » doublait l'info et grandissait la fiche)
	_gold_label = _make_label(null) # placé en haut à droite (_gold_box)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	item_bar = ItemBar.new()
	item_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left_col.add_child(item_bar)

	_center_col = VBoxContainer.new()
	_center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_center_col)
	_time_plate = PanelContainer.new()
	_time_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb := UiTheme.da_box("timer_plate", 0.5)
	if tb != null:
		_time_plate.add_theme_stylebox_override(&"panel", tb)
	_center_col.add_child(_time_plate)
	_time_label = _make_label(_time_plate)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.text = "00:00"
	# difficulté : sous la minimap (retour joueur vague 3 : en haut au centre elle gênait les barres de boss)
	_map_plate = Panel.new() # plaque commune minimap + difficulté (derrière les deux ; posée par _place_difficulty)
	_map_plate.name = "MapPlate"
	_map_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mpb := StyleBoxFlat.new()
	mpb.bg_color = Color(0.043, 0.035, 0.027, HudMetrics.PLATE_ALPHA)
	mpb.border_color = Color(0.29, 0.26, 0.235, 0.85)
	mpb.set_border_width_all(2)
	mpb.set_corner_radius_all(14)
	_map_plate.add_theme_stylebox_override(&"panel", mpb)
	root.add_child(_map_plate)
	_diff_box = HBoxContainer.new() # une seule ligne : compacte (le panneau d'objectifs dessous reste hors des sorts tactiles)
	_diff_box.name = "Difficulty"
	_diff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_diff_box)
	_diff_caption = _make_label(root)
	_diff_caption.name = "DifficultyCaption"
	_diff_caption.text = "Difficulté"
	_diff_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_caption.add_theme_color_override("font_color", Color(0.91, 0.886, 0.839)) # blanc cassé du HUD (#E8E2D6)
	_diff_label = _make_label(_diff_box)
	_diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_diff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_diff_bar = _make_bar(_diff_box, Color.WHITE)
	_diff_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_diff_bar.max_value = D_MAX
	_diff_style = _diff_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var dbg := StyleBoxFlat.new() # fond fer sombre + liseré (lisible jauge vide sur fond sombre)
	dbg.bg_color = HpBarStyle.COL_BG
	dbg.border_color = HpBarStyle.COL_FRAME
	dbg.set_border_width_all(2)
	dbg.set_corner_radius_all(6)
	_diff_bar.add_theme_stylebox_override("background", dbg)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right_spacer)

	pause_button = PauseButton.new()
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.add_child(pause_button)

	_gold_box = HBoxContainer.new()
	_gold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_box.add_theme_constant_override("separation", 8)
	root.add_child(_gold_box)
	var gi := TextureRect.new()
	gi.name = &"GoldIcon"
	gi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.texture = Minimap.ui_texture("icon_gold.png")
	gi.custom_minimum_size = Vector2(48, 48)
	_gold_box.add_child(gi)
	_gold_box.add_child(_gold_label)

	boss_bars = BossBars.new()
	root.add_child(boss_bars)
	boss_bars.visibility_changed.connect(_place_boss_bars) # début / fin de combat : le chrono change de place
	objectives = ObjectivesPanel.new()
	root.add_child(objectives) # avant la minimap : la minimap plein écran passe dessus
	minimap = Minimap.new()
	root.add_child(minimap)

	# coin bas-droit (ancre de taille nulle) : boutons de sorts + Interagir
	_corner = Control.new()
	_corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.add_child(_corner)
	interact_button = InteractButton.new()
	_corner.add_child(interact_button)
	for i in 3:
		var b := SpellButton.new()
		b.setup(i + 2, 150.0)
		_corner.add_child(b)
		spell_buttons.append(b)
	dodge_button = DodgeButton.new()
	dodge_button.setup(0, 120.0)
	_corner.add_child(dodge_button)
	auto_indicator = SpellButton.new()
	auto_indicator.interactive = false
	auto_indicator.setup(1, 72.0)
	_corner.add_child(auto_indicator)
	touch_gauge = ResourceGauge.new()
	touch_gauge.name = "TouchGauge"
	_corner.add_child(touch_gauge)

	# barre des 4 sorts (clavier-souris / manette) : bas du centre, touche sous chaque sort
	_spell_bar = HBoxContainer.new()
	_spell_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spell_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_spell_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_spell_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_spell_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_spell_bar)
	bar_gauge = ResourceGauge.new() # ressource du kit : à gauche du sort 1, hors de la barre (qui reste centrée)
	bar_gauge.name = "BarGauge"
	root.add_child(bar_gauge)
	for i in 4:
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_END
		_spell_bar.add_child(col)
		var sbtn := SpellButton.new()
		sbtn.interactive = false
		sbtn.setup(i + 1, 110.0)
		sbtn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(sbtn)
		bar_buttons.append(sbtn)
		var key := KeyPrompt.new()
		col.add_child(key)
		bar_keys.append(key)
	# roulade : recharge + touche, à droite des sorts
	var dcol := VBoxContainer.new()
	dcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dcol.alignment = BoxContainer.ALIGNMENT_END
	_spell_bar.add_child(dcol)
	bar_dodge = DodgeButton.new()
	bar_dodge.interactive = false
	bar_dodge.setup(0, 90.0)
	bar_dodge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dcol.add_child(bar_dodge)
	bar_dodge_key = KeyPrompt.new()
	dcol.add_child(bar_dodge_key)

	# invite d'interaction (clavier / manette) : bas du centre
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.75)
	sb.border_color = Color(0.7, 1.0, 0.75)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_prompt_panel.add_theme_stylebox_override("panel", sb)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(_prompt_label)
	_prompt_panel.visible = false
	root.add_child(_prompt_panel)

	# aide des commandes (premiere partie, 8 s ; rappelable depuis le menu pause)
	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(Control.PRESET_CENTER)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hsb := sb.duplicate() as StyleBoxFlat
	hsb.border_color = Color(1.0, 0.78, 0.35)
	hsb.content_margin_left = 36
	hsb.content_margin_right = 36
	hsb.content_margin_top = 24
	hsb.content_margin_bottom = 24
	_help_panel.add_theme_stylebox_override("panel", hsb)
	_help_grid = GridContainer.new()
	_help_grid.columns = 2
	_help_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(_help_grid)
	_help_panel.visible = false
	root.add_child(_help_panel)

	reticle = AimReticle.new()
	root.add_child(reticle)


## Recalcule toutes les dimensions selon la taille du viewport (portrait mobile, paysage PC, fenetre redimensionnee).
func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var mobile := HudMetrics.is_mobile()
	var s := HudMetrics.geometry_scale(vp) # géométrie : fenêtre x réglage joueur (HudMetrics.user_scale)
	ui_scale = s
	var portrait := vp.y >= vp.x
	var tk := HudMetrics.MOBILE_K if mobile else 1.0 # facteur des conteneurs hors table (largeur de barre)

	var hs := _hud_safe() # zone sûre (mobile : encoche, coins, barre de gestes ; PC : aucune) — A11y-L4, E-04
	_top.add_theme_constant_override("margin_left", int(maxf(30 * s, hs["left"])))
	_top.add_theme_constant_override("margin_right", int(maxf(24 * s, hs["right"])))
	_top.add_theme_constant_override("margin_top", int(maxf(36 * s, hs["top"])))
	var hp_px: Vector2 = HudMetrics.pick(HudMetrics.HP_BAR, mobile)
	var xp_px: Vector2 = HudMetrics.pick(HudMetrics.XP_BAR, mobile)
	var bar_w := clampf(vp.x * 0.2 * tk, 180.0, hp_px.x * s) # fiche compacte (retour joueur : elle cachait l'or au sol)
	_hp_bar.custom_minimum_size = Vector2(bar_w, hp_px.y * s) # PV : l'élément le plus haut de la fiche
	_xp_bar.custom_minimum_size = Vector2(bar_w, xp_px.y * s)
	_name_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T4_SMALL, s, mobile))
	_badge_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.BADGE_LEVEL, s, mobile))
	var badge_px: float = HudMetrics.pick(HudMetrics.BADGE_PX, mobile)
	_badge_label.get_parent().custom_minimum_size = Vector2(badge_px, badge_px) * s
	if _portrait != null:
		var portrait_px: float = HudMetrics.pick(HudMetrics.PORTRAIT_PX, mobile)
		_portrait.custom_minimum_size = Vector2(portrait_px, portrait_px) * s
	_center_col.custom_minimum_size.x = 250 * s
	_hp_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T1_HP, s, mobile))
	_gold_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T2_GOLD, s, mobile))
	_time_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T2_TIME, s, mobile))
	_diff_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T4_SMALL, s, mobile))
	_diff_caption.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T4_SMALL, s, mobile))
	_hp_regen.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.T4_SMALL, s, mobile))
	_hp_label.offset_left = 10.0 * s
	_hp_regen.offset_right = -10.0 * s
	overhead.ui_scale = s
	_left_col.add_theme_constant_override("separation", int(8 * s))
	_prompt_label.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.PROMPT, s, mobile))
	var bar_size := HudMetrics.BAR_SPELL_PX * s
	for b in bar_buttons:
		b.setup(b.slot, bar_size)
	for kp in bar_keys:
		kp.set_height(56.0 * s)
		kp.custom_minimum_size.x = bar_size + 24.0 * s
	bar_dodge.setup(0, bar_size * 0.8)
	bar_gauge.apply_scale(s)
	touch_gauge.apply_scale(s)
	bar_dodge_key.set_height(56.0 * s)
	bar_dodge_key.custom_minimum_size.x = bar_size + 24.0 * s
	_spell_bar.add_theme_constant_override("separation", int(22 * s))
	_spell_bar.offset_bottom = -int(24 * s)
	# invite d'interaction : au-dessus de la barre de sorts quand elle est affichée
	_prompt_panel.offset_bottom = -int((70.0 + 180.0) * s) if _spell_bar.visible else -int(70 * s)
	_layout_help(s)

	pause_button.apply_scale(s)
	var pm := maxf(24.0 * s, hs["right"])
	var pt := maxf(30.0 * s, hs["top"])
	pause_button.offset_left = -(pause_button.size.x + pm)
	pause_button.offset_right = -pm
	pause_button.offset_top = pt
	pause_button.offset_bottom = pt + pause_button.size.y

	# Positions (coin supérieur gauche, par rapport au coin bas-droit), unités de base * s.
	# Tactile paysage : grappe au pouce. Roulade = bouton le plus gros, au plus près du coin ; sorts 2 / 3 / 4 en arc
	# autour d'elle (l'ultime, en diagonale, est le plus accessible après la roulade) ; l'icône de l'auto (sort 1) est un
	# petit indicateur non cliquable à gauche de l'arc. Marge de sécurité = zone sûre (encoche, coins arrondis) + 24.
	var safe: Dictionary = Platform.safe_margins()
	var inset := Vector2(float(safe["right"]), float(safe["bottom"])) # px réels (les positions ci-dessous sont mises à l'échelle)
	_corner.offset_left = -inset.x
	_corner.offset_top = -inset.y
	_corner.offset_right = -inset.x
	_corner.offset_bottom = -inset.y
	var poss: Array[Vector2]
	var pos_i: Vector2
	if portrait:
		poss = [Vector2(-420, -360), Vector2(-270, -480), Vector2(-160, -640)]
		pos_i = Vector2(-430, -810)
		for i in spell_buttons.size():
			spell_buttons[i].setup(i + 2, HudMetrics.TOUCH_SPELL_PX * s)
			spell_buttons[i].position = poss[i] * s
		dodge_button.setup(0, 120.0 * s)
		dodge_button.position = Vector2(-200, -190) * s
		auto_indicator.visible = false
		touch_gauge.position = Vector2(-430.0 - _gauge_px().x - 20.0, -300.0) * s # à gauche du sort 2
	else:
		const DODGE_PX := HudMetrics.TOUCH_DODGE_PX
		const SPELL_PX := HudMetrics.TOUCH_SPELL_PX
		const EDGE := 20.0 # jeu entre la roulade et le bord (en plus de la zone sûre) ; 36 -> 20 avec GAP 40 : même emprise qu'avant
		const GAP := 40.0 # écart libre entre deux boutons (audit E-06) : zones de frappe de +16 px sans chevauchement
		const ARC_R := (DODGE_PX + SPELL_PX) * 0.5 + GAP # centre roulade -> centre des sorts 2 et 3
		# ultime en diagonale (u, u) : distance au sort 2 et au sort 3 >= SPELL_PX + GAP
		var diag_r := (ARC_R + sqrt(2.0 * pow(SPELL_PX + GAP, 2.0) - ARC_R * ARC_R)) * 0.5 * sqrt(2.0)
		var dc := Vector2(-(EDGE + DODGE_PX * 0.5), -(EDGE + DODGE_PX * 0.5)) # centre de la roulade
		dodge_button.setup(0, DODGE_PX * s)
		dodge_button.position = (dc - Vector2.ONE * DODGE_PX * 0.5) * s
		# slot 2 à gauche de la roulade, slot 4 (ultime) en diagonale, slot 3 au-dessus
		var angles := [0.0, 90.0, 45.0] # degrés depuis la gauche, vers le haut ; ordre = slots 2, 3, 4
		for i in spell_buttons.size():
			var a := deg_to_rad(float(angles[i]))
			var r := ARC_R if absf(sin(2.0 * a)) < 0.5 else diag_r
			var c := dc + Vector2(-cos(a), -sin(a)) * r
			spell_buttons[i].setup(i + 2, SPELL_PX * s)
			spell_buttons[i].position = (c - Vector2.ONE * SPELL_PX * 0.5) * s
		var ac := dc + Vector2(-ARC_R - SPELL_PX * 0.5 - 56.0, 0.0)
		auto_indicator.visible = true
		var auto_px: float = HudMetrics.pick(HudMetrics.AUTO_PX, true)
		auto_indicator.setup(1, auto_px * s)
		auto_indicator.position = (ac - Vector2.ONE * auto_px * 0.5) * s
		# ressource du kit : au-dessus de l'icône de l'auto, bord droit avant l'ultime (diagonale)
		var g_right := dc.x - diag_r * cos(PI * 0.25) - SPELL_PX * 0.5 - 16.0
		touch_gauge.position = Vector2(g_right - _gauge_px().x, dc.y - DODGE_PX * 0.5 - _gauge_px().y) * s # au-dessus du sort 2
		pos_i = Vector2(-890, -180) # à gauche de la grappe, sur la rangée de la roulade (hors minimap et objectifs)
	interact_button.apply_scale(s)
	interact_button.position = pos_i * s

	joystick.anchor_right = 0.6 if portrait else 0.48
	joystick.apply_safe_area(Platform.safe_margins()) # bord gauche (geste Retour) et barre de gestes (E-03)

	# inventaire : sous les PV, largeur des barres ; rangee defilante en tactile
	var touch_mode: bool = Platform.input_mode == Platform.InputMode.TOUCH
	var text_k := 1.2 if mobile else 1.0 # textes d'infobulle / objectifs : plancher mobile 26 px (22 x 1,2)
	item_bar.configure(not touch_mode, bar_w, (84.0 if mobile else 64.0 if touch_mode else 56.0) * s, s * text_k)
	# minimap : coin haut-droit, a gauche du bouton pause quand il est affiche
	# or : à gauche du bouton pause ; minimap : sous cette rangée, bord droit aligné sur le bouton pause
	var gi := _gold_box.get_node(^"GoldIcon") as Control
	var gold_px: float = HudMetrics.pick(HudMetrics.GOLD_ICON_PX, mobile)
	gi.custom_minimum_size = Vector2(gold_px, gold_px) * s
	_place_gold()
	# tactile : plus petite (boutons de sorts et Interagir à droite), 300 px au lieu de 274 (audit § 4.2)
	var mm: float = (float(HudMetrics.MINIMAP_PX[1]) if touch_mode else Minimap.compact_px()) * s
	var mm_top := pt + pause_button.size.y + 6.0 * s
	minimap.set_compact_rect(Rect2(Vector2(vp.x - pm - mm, mm_top), Vector2(mm, mm)))
	_place_difficulty()
	boss_bars.set_ui_scale(s * (1.25 if mobile else 1.0)) # nom 26 -> 32 px, barre plus haute sur mobile
	_place_boss_bars()
	objectives.set_ui_scale(s * text_k)
	_place_objectives()


func _on_mode_changed(_mode: int) -> void:
	_apply_mode()


## Affiche les controles tactiles seulement en mode tactile ; invite [E] / [A] sinon.
func _apply_mode() -> void:
	var touch: bool = Platform.input_mode == Platform.InputMode.TOUCH
	touch_layer.visible = touch
	_spell_bar.visible = not touch
	for i in bar_keys.size():
		bar_keys[i].set_action(StringName("spell_%d" % (i + 1)), "Auto" if i == 0 else "")
	bar_dodge_key.set_action(&"dodge")
	# bouton pause : tactile et souris ; masque a la manette (bouton Start)
	pause_button.visible = Platform.input_mode != Platform.InputMode.GAMEPAD
	_apply_layout()
	if _help_panel.visible:
		_fill_help()
	if touch:
		_prompt_panel.visible = false
		reticle.hide_reticle()
	else:
		_update_interact()


func _update_reticle() -> void:
	if get_tree().paused or player == null or not is_instance_valid(player):
		reticle.hide_reticle()
		return
	match Platform.input_mode:
		Platform.InputMode.KBM:
			var mp := get_viewport().get_mouse_position()
			if get_viewport().get_visible_rect().has_point(mp):
				reticle.show_at(mp, ui_scale)
			else:
				reticle.hide_reticle()
		Platform.InputMode.GAMEPAD:
			var sp: Variant = player.get("spells")
			if sp != null and (sp as Object).has_method("get_manual_aim_point"):
				var p: Variant = sp.get_manual_aim_point(6.0 * 64.0)
				if p != null:
					reticle.show_at(get_viewport().get_canvas_transform() * (p as Vector2), ui_scale)
					return
			reticle.hide_reticle()
		_:
			reticle.hide_reticle()


func _make_bar(parent: Control, col: Color, kind := "") -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.043, 0.035, 0.027, 0.8) # #0B0907 : fond plus sombre, jauge vide lisible
	bg.set_corner_radius_all(6)
	if kind != "" and ResourceLoader.exists(Minimap.UI_DIR + "bar_fill_%s.png" % kind):
		# remplissage du kit DA ; simple fond sombre sous le cadre
		var ft := StyleBoxTexture.new()
		ft.texture = load(Minimap.UI_DIR + "bar_fill_%s.png" % kind)
		b.add_theme_stylebox_override("fill", ft)
		bg.set_corner_radius_all(0)
		b.add_theme_stylebox_override("background", bg)
	else:
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(6)
		b.add_theme_stylebox_override("background", bg)
		b.add_theme_stylebox_override("fill", fill)
	if parent != null:
		parent.add_child(b)
	return b


## Cadre DA (NinePatchRect) autour d'une barre : la barre est la zone intérieure, le cadre déborde de ses marges.
func _frame_bar(bar: ProgressBar, file: String) -> void:
	var path := Minimap.UI_DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return
	var sb := UiTheme.da_box(file)
	var np := NinePatchRect.new()
	np.texture = load(path)
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.patch_margin_left = int(sb.texture_margin_left)
	np.patch_margin_top = int(sb.texture_margin_top)
	np.patch_margin_right = int(sb.texture_margin_right)
	np.patch_margin_bottom = int(sb.texture_margin_bottom)
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.offset_left = -sb.texture_margin_left
	np.offset_top = -sb.texture_margin_top
	np.offset_right = sb.texture_margin_right
	np.offset_bottom = sb.texture_margin_bottom
	bar.add_child(np) # dernier enfant : par-dessus la traîne, le texte de la barre repasse devant ci-dessous
	for c in bar.get_children():
		if c is Label:
			bar.move_child(c, bar.get_child_count() - 1)
	_frames.append([bar, np, Vector4(sb.texture_margin_left, sb.texture_margin_top, sb.texture_margin_right, sb.texture_margin_bottom)])


## Médaillon de niveau : level_badge + numéro centré.
func _make_badge() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(88, 88)
	var tex := Minimap.ui_texture("level_badge.png")
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tr)
	_badge_label = Label.new()
	_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_badge_label.add_theme_constant_override("outline_size", 6)
	c.add_child(_badge_label)
	return c


## Jauge de ressource (clavier-souris / manette) : à gauche de la barre de sorts, bas aligné sur les icônes
## (au-dessus des invites de touches) ; masquée avec la barre en mode tactile.
func _place_bar_gauge() -> void:
	bar_gauge.visible = _spell_bar.visible
	var br := _spell_bar.get_rect()
	var icons_bottom := br.end.y - (56.0 + 4.0) * ui_scale # invite de touche + séparation du VBox
	bar_gauge.position = Vector2(br.position.x - bar_gauge.size.x - 22.0 * ui_scale, icons_bottom - bar_gauge.size.y)


## Taille de base de la jauge de kit pour la plateforme (ResourceGauge.apply_scale applique le facteur mobile lui-même).
func _gauge_px() -> Vector2:
	return ResourceGauge.MOBILE_SIZE if HudMetrics.is_mobile() else ResourceGauge.BASE_SIZE


## Zones occupées par le HUD, en coordonnées écran (contrat : le monde y évite étiquettes et chiffres).
## Z1 fiche joueur + items, Z2 chrono (+ barres de boss si visibles), Z3 or / pause / plaque carte / objectifs,
## Z4 action (barre de sorts + jauge en clavier-souris / manette ; grappe tactile + Interagir en tactile).
func reserved_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var ctrls: Array = [_player_plate, item_bar, _time_plate, _gold_box, _map_plate, pause_button]
	if boss_bars != null and boss_bars.visible:
		ctrls.append(boss_bars)
	if objectives != null and objectives.visible:
		ctrls.append(objectives)
	if Platform.input_mode == Platform.InputMode.TOUCH:
		ctrls.append_array(spell_buttons)
		ctrls.append_array([dodge_button, auto_indicator, touch_gauge, interact_button])
	else:
		ctrls.append_array([_spell_bar, bar_gauge])
	for c in ctrls:
		var ctl := c as Control
		if ctl != null and is_instance_valid(ctl) and ctl.is_visible_in_tree():
			var r := ctl.get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0:
				out.append(r)
	return out


## Accent du personnage joué (CharacterData.accent_color) : jauge de ressource, pastilles de charges.
func _accent() -> Color:
	var c: Variant = player.get(&"character") if player != null else null
	return (c as CharacterData).accent_color if c is CharacterData else SpellButton.READY_COLOR


## Nom du personnage choisi (data/characters.json), en capitales.
func _character_name() -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	if d is Array:
		for c in d:
			if c is Dictionary and StringName(c.get("id", "")) == RunState.character:
				return String(c.get("name", "")).to_upper()
	return String(RunState.character).to_upper()


func _bar_label(bar: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hauteur de ligne > barre (ex. 32 px dans 36 px sur mobile) : grandir des DEUX côtés pour rester centré sur la
	# barre (sinon le Label ne grandit que vers le bas et « 130 / 130 » est rogné en bas).
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	bar.add_child(l)
	return l


func _make_label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l


## Difficulté : sous la minimap compacte, centrée sur elle, largeur de la minimap (colonne de droite : jamais
## sous les barres de boss empilées du haut-centre, ni sur l'or et le bouton pause, au-dessus de la minimap).
func _place_difficulty() -> void:
	_map_plate.visible = not minimap.expanded
	if minimap.expanded and _diff_box.position != Vector2.ZERO:
		return # minimap plein écran : la difficulté garde sa place (sous la carte compacte)
	var mm := minimap.get_compact_rect()
	var s := ui_scale
	var bottom := mm.end.y
	var mr := minimap.map_rect() if not minimap.expanded else Rect2()
	if mr.size.y > 0.0: # juste sous le losange dessiné (la carte iso n'occupe pas tout son carré)
		bottom = minf(bottom, minimap.global_position.y + mr.end.y)
	_diff_box.add_theme_constant_override("separation", int(10 * s))
	var k := HudMetrics.MOBILE_K if HudMetrics.is_mobile() else 1.0
	_diff_bar.custom_minimum_size = Vector2(70.0 * s * k, 12.0 * s * k)
	_diff_box.custom_minimum_size.x = mm.size.x * 0.9
	_diff_box.reset_size()
	_diff_caption.reset_size()
	_diff_caption.size.x = _diff_box.size.x
	_diff_caption.position = Vector2(mm.get_center().x - _diff_caption.size.x * 0.5, bottom + 2.0 * s)
	_diff_box.position = Vector2(mm.get_center().x - _diff_box.size.x * 0.5, _diff_caption.position.y + _diff_caption.size.y)
	# plaque commune : minimap compacte + titre + difficulté (contraste du libellé garanti sur tout décor, H17)
	var plate := mm.merge(Rect2(_diff_caption.position, _diff_caption.size)).merge(Rect2(_diff_box.position, _diff_box.size)).grow(HudMetrics.PLATE_PAD * s)
	_map_plate.position = plate.position
	_map_plate.size = plate.size


## Taux par seconde lisible : « +1,2/s » (une décimale sous 10, virgule française), « +15/s » au-delà.
static func fmt_rate(r: float) -> String:
	var a := absf(r)
	var num := ("%.1f" % a).replace(".", ",") if a < 9.95 else str(roundi(a))
	return ("-" if r < -0.0001 else "+") + num + "/s"


## Résumé des régénérations du joueur (menu pause) : PV (Player.regen_per_s) et ressource du kit
## (hook KitResource `regen`, rien si le kit ne l'expose pas).
static func regen_summary(p: Object) -> String:
	if p == null or not is_instance_valid(p) or not p.has_method(&"regen_per_s"):
		return ""
	var parts: Array[String] = ["PV %s" % fmt_rate(float(p.call(&"regen_per_s")))]
	var res := KitResource.of(p)
	if res.has("regen"):
		parts.append("%s %s" % [String(res.get("label", "Ressource")), fmt_rate(float(res["regen"]))])
	return "Régénération : " + "  ·  ".join(parts)


## Barres de boss : zone FIXE en haut au centre (la place du chrono hors combat), à gauche de la minimap.
## Pendant un combat de boss, le chrono quitte le haut-centre (top_level) et se range à droite des barres, sur la
## même ligne : il ne pousse ni ne recouvre jamais le nom du boss (retour joueur 23/10). Barres descendues sous la
## colonne de gauche seulement si elles la chevaucheraient (petites fenêtres).
func _place_boss_bars() -> void:
	if boss_bars == null or minimap == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var s := ui_scale
	var cx := vp.x * 0.5
	var lim := minimap.get_compact_rect().position.x - 16.0 * s
	var fight := boss_bars.visible
	var tw := maxf(_time_plate.get_combined_minimum_size().x, _center_col.custom_minimum_size.x) if fight else 0.0 # largeur hors combat
	var w := minf(560.0 * s, 2.0 * (lim - (tw + 16.0 * s if fight else 0.0) - cx))
	var top := float(_top.get_theme_constant(&"margin_top")) # ligne du chrono hors combat (bandeau du haut)
	if _time_plate.top_level != fight:
		_time_plate.top_level = fight
		_center_col.queue_sort()
	if fight: # chrono à droite des barres, sur la ligne du haut (hors de la zone des boss)
		_time_plate.size = Vector2(tw, _time_plate.get_combined_minimum_size().y)
		_time_plate.global_position = Vector2(cx + w * 0.5 + 16.0 * s, top)
	# contenu reel de la colonne de gauche (la colonne elle-meme s'etire sur la moitie du bandeau)
	# (les libelles s'etirent sur toute la colonne : on prend la barre de PV et l'inventaire)
	var lc_right := _hp_bar.get_global_rect().end.x
	var lc_bottom := _gold_label.get_global_rect().end.y
	if item_bar.visible:
		lc_right = maxf(lc_right, item_bar.get_global_rect().end.x)
		lc_bottom = maxf(lc_bottom, item_bar.get_global_rect().end.y)
	if lc_right > cx - w * 0.5:
		top = maxf(top, lc_bottom + 12.0 * s)
	boss_bars.position = Vector2(cx - w * 0.5, top)
	boss_bars.size = Vector2(w, 0.0)
	boss_bars.custom_minimum_size.x = w


## Objectifs : sous la minimap (compacte), bord droit aligné sur elle et dans la zone sûre
## (Platform.safe_margins) ; la colonne des barres de boss reste à gauche de la minimap.
func _place_objectives() -> void:
	if objectives == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s := ui_scale
	var safe: Dictionary = Platform.safe_margins()
	var mm := minimap.get_compact_rect()
	var right := minf(mm.end.x, vp.x - float(safe["right"]))
	var top := maxf(mm.end.y + 14.0 * s, float(safe["top"]))
	if _diff_box != null and _diff_box.visible: # sous la difficulté (elle-même sous le losange de la minimap)
		top = maxf(top, _diff_box.get_global_rect().end.y + 8.0 * s)
	# pas plus large que l'espace à droite des barres de boss quand elles sont affichées
	var max_w := right - float(safe["left"])
	if boss_bars.visible:
		max_w = minf(max_w, right - (boss_bars.position.x + boss_bars.size.x) - 16.0 * s)
	max_w = maxf(max_w, 200.0 * s)
	# tactile : la grappe de sorts (150 px, arc + écarts 40 px) remonte sous la minimap ; le panneau s'arrête au-dessus
	# d'elle (16 px d'écart) et passe en compact (sans titre, deux lignes au plus) si la version complète n'y tient pas.
	var limit := INF
	if touch_layer != null and touch_layer.visible:
		objectives.set_compact(false)
		objectives.place(Vector2(right, top), max_w)
		limit = _touch_cluster_top(objectives.position.x, right) - 16.0 * s
		objectives.set_compact(top + objectives.height_for(false) > limit)
	else:
		objectives.set_compact(false)
	objectives.place(Vector2(right, top), max_w)
	if objectives.get_global_rect().end.y > limit: # dernier recours (très petite fenêtre) : à gauche de la grappe
		var left := _touch_cluster_left(top, top + objectives.size.y) - 16.0 * s
		objectives.place(Vector2(minf(right, left), top), max_w)


## Haut de la grappe tactile (sorts, roulade, auto, jauge, Interagir) sur la bande horizontale [x0, x1], px écran.
func _touch_cluster_top(x0: float, x1: float) -> float:
	var y := INF
	for c in _touch_cluster_controls():
		var r := c.get_global_rect()
		if r.end.x > x0 and r.position.x < x1:
			y = minf(y, r.position.y)
	return y


## Bord gauche de la grappe tactile sur la bande verticale [y0, y1], px écran.
func _touch_cluster_left(y0: float, y1: float) -> float:
	var x := INF
	for c in _touch_cluster_controls():
		var r := c.get_global_rect()
		if r.end.y > y0 and r.position.y < y1:
			x = minf(x, r.position.x)
	return x


func _touch_cluster_controls() -> Array[Control]:
	var out: Array[Control] = []
	var all: Array = [dodge_button, auto_indicator, touch_gauge, interact_button]
	all.append_array(spell_buttons)
	for c in all:
		var ctl := c as Control
		if ctl != null and is_instance_valid(ctl) and (ctl.visible or ctl == interact_button): # Interagir : place fixe
			out.append(ctl)
	return out


## Changement d'étage : « +N XP (or converti) » qui monte depuis la ligne de l'or, avec pièce + XP.
func _on_gold_converted(gold: float, xp: float) -> void:
	var l := _make_label(root)
	l.text = "+%d XP (or converti)" % int(round(xp)) if xp >= 1.0 else "Or perdu : %d" % int(gold)
	l.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.TOAST, ui_scale))
	l.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	l.name = &"GoldConvertedLabel"
	l.reset_size() # calé à droite sur la rangée de l'or, juste dessous : ne passe jamais sur le bouton pause
	var gr := _gold_box.get_global_rect()
	var start := Vector2(gr.end.x - l.size.x, gr.end.y + 4.0 * ui_scale)
	l.position = start
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", start.y - 70.0 * ui_scale, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(1.7)
	tw.tween_callback(l.queue_free)
	Audio.play_coin()
	Audio.play_ui(&"pickup.xp", -6.0)


## REPARTITEUR UNIQUE d'interaction (audit Choix L1). Choisit LA cible de l'invite (groupe "interactable") et,
## sur l'action « interact », appelle interact() sur elle seule : aucun objet ne lit l'entrée.
## Cible : la plus proche ; à ±INTERACT_TIE_PX près, la priorité (interact_priority : coffre 3 > capsule 2 >
## pilier 1 > téléporteur 0) l'emporte. Etat de l'invite : interact_state() -> {visible, enabled, label,
## hold_s} ; sans interact_state, repli sur can_interact() / interact_label(). hold_s > 0 : maintien (anneau).
const INTERACT_TIE_PX := 16.0
var _hold_t := 0.0
var _hold_done := false ## le maintien a abouti : attendre le relâcher avant un nouveau maintien
var _hold_target: Node = null
var _interact_frame := -1
var _hold_ring: InteractButton.Ring = null


func _update_interact() -> void:
	interact_target = null
	var st := {}
	if player != null and is_instance_valid(player) and player is Node2D:
		var pp := (player as Node2D).global_position
		var best := INF
		var best_prio := -1
		for n in get_tree().get_nodes_in_group("interactable"):
			if not (n is Node2D):
				continue
			var s := {}
			if n.has_method("interact_state"):
				s = n.interact_state()
			elif n.has_method("can_interact") and n.can_interact():
				s = {"visible": true, "enabled": true, "hold_s": 0.0}
				if n.has_method("interact_label"):
					s["label"] = str(n.interact_label())
			if not bool(s.get("visible", false)):
				continue
			var d := (n as Node2D).global_position.distance_to(pp)
			var prio: int = int(n.interact_priority()) if n.has_method("interact_priority") else 0
			if interact_target == null or d < best - INTERACT_TIE_PX or (absf(d - best) <= INTERACT_TIE_PX and prio > best_prio):
				best = d
				best_prio = prio
				interact_target = n
				st = s
	var enabled: bool = bool(st.get("enabled", true))
	var hold_s: float = float(st.get("hold_s", 0.0))
	if interact_target != _hold_target:
		_hold_target = interact_target
		_hold_t = 0.0
		_hold_done = false
	# une seule évaluation d'entrée par image (_update_interact est aussi rappelée au changement de mode)
	var frame := Engine.get_process_frames()
	if frame != _interact_frame:
		_interact_frame = frame
		var live: bool = interact_target != null and enabled and not get_tree().paused and interact_target.has_method("interact")
		if not live:
			_hold_t = 0.0
			_hold_done = false
			# l'appui reste dans la file : un appui fait pendant une pause ne se rejoue pas à la reprise
		elif hold_s <= 0.0:
			if Input.is_action_just_pressed("interact"):
				var tgt := interact_target
				tgt.interact()
				if not is_instance_valid(tgt) or tgt.is_queued_for_deletion():
					interact_target = null
		elif not Input.is_action_pressed("interact"):
			_hold_t = 0.0
			_hold_done = false
		elif not _hold_done and (_hold_t > 0.0 or Input.is_action_just_pressed("interact")):
			_hold_t += get_process_delta_time()
			if _hold_t >= hold_s:
				_hold_done = true
				var tgt := interact_target
				tgt.interact()
				if not is_instance_valid(tgt) or tgt.is_queued_for_deletion():
					interact_target = null
	var progress := 1.0 if _hold_done else (clampf(_hold_t / hold_s, 0.0, 1.0) if hold_s > 0.0 else 0.0)
	if interact_target == null:
		interact_button.update_target(null)
	else:
		interact_button.update_target(interact_target, st, progress)
	# clavier / manette : invite texte « [E] Partir » a la place du gros bouton
	var show_prompt: bool = interact_target != null and Platform.input_mode != Platform.InputMode.TOUCH
	if show_prompt:
		var lbl := str(st.get("label", "Interagir"))
		if not enabled:
			_prompt_label.text = lbl # grisée : raison écrite, aucune touche affichée
			_prompt_label.modulate = Color(0.7, 0.7, 0.72)
		else:
			if hold_s > 0.0:
				lbl += " (maintenir)"
			_prompt_label.text = Platform.interact_prompt(lbl)
			_prompt_label.modulate = Color.WHITE
	_prompt_panel.visible = show_prompt
	# anneau de maintien sur l'invite (enfant du libellé, à sa gauche)
	if hold_s > 0.0 and show_prompt and enabled:
		if _hold_ring == null:
			_hold_ring = InteractButton.Ring.new()
			_prompt_label.add_child(_hold_ring)
		var h := maxf(_prompt_label.size.y, 32.0)
		_hold_ring.size = Vector2(h, h)
		_hold_ring.position = Vector2(-h - 10.0, (_prompt_label.size.y - h) * 0.5)
		_hold_ring.visible = true
		_hold_ring.set_progress(progress)
	elif _hold_ring != null:
		_hold_ring.visible = false


# --- Aide des commandes -----------------------------------------------------

## Affiche l'aide des commandes du mode courant pendant duration_s (fondu sur la dernière seconde).
func show_controls_help(duration_s: float = HELP_DURATION_S) -> void:
	_fill_help()
	_help_left = duration_s
	_help_panel.modulate.a = 1.0
	_help_panel.visible = true


func is_help_visible() -> bool:
	return _help_panel.visible


func _fill_help() -> void:
	for c in _help_grid.get_children():
		_help_grid.remove_child(c)
		c.queue_free()
	for row in Platform.controls_help():
		for j in 2:
			var l := Label.new()
			l.text = str(row[j])
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5) if j == 0 else Color.WHITE)
			_help_grid.add_child(l)
	_layout_help(ui_scale)


func _layout_help(s: float) -> void:
	_help_grid.add_theme_constant_override("h_separation", int(40 * s))
	_help_grid.add_theme_constant_override("v_separation", int(12 * s))
	# largeur bornée au viewport (portrait étroit) : colonne des touches repliée sur plusieurs lignes
	var w := get_viewport().get_visible_rect().size.x * 0.9 - 72.0 - 40.0 * s
	var i := 0
	for l in _help_grid.get_children():
		var lb := l as Label
		lb.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.HELP, s))
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.custom_minimum_size.x = minf(w * (0.36 if i % 2 == 0 else 0.64), (260.0 if i % 2 == 0 else 640.0) * s)
		i += 1


func _update_help(delta: float) -> void:
	if not _help_panel.visible:
		return
	_help_left -= delta
	_help_panel.modulate.a = clampf(_help_left / HELP_FADE_S, 0.0, 1.0)
	if _help_left <= 0.0:
		_help_panel.visible = false


# --- Retours de progression (audit Choix L4, P13 / P14) -------------------------------------------------
## Montée de niveau : impulsion du médaillon (1,0 -> 1,35 -> 1,0 en 300 ms), « Niveau N » flottant 1 s au-dessus
## du joueur, éclat de la barre d'XP (200 ms). La vibration est déjà émise par Player._on_level_up (Haptics,
## désactivable). Or : le crédit reste immédiat ; impulsion du compteur (1,0 -> 1,15 en 120 ms) à l'arrivée de la
## première pièce de chaque prime (PickupManager.FLY_TIME), au plus GOLD_PULSE_MAX_PER_S par seconde.
## Accessibilité : « Réduire les mouvements » supprime échelles et montée (éclaircissement bref à la place) ;
## l'intensité des éclats suit GameSettings.flash_scale() (0 = aucun éclat).
## Effets transitoires sans texture (pas d'asset) : rien à faire produire par Codex.
const LEVEL_PULSE_SCALE := 1.35
const LEVEL_PULSE_S := 0.3
const LEVEL_TEXT_S := 1.0
const LEVEL_TEXT_RISE := 40.0 ## px (× ui_scale) de montée, nulle si mouvements réduits
const LEVEL_TEXT_ABOVE := 150.0 ## px (× ui_scale) au-dessus de l'origine du joueur (au-dessus des barres de tête)
const LEVEL_TEXT_COLOR := Color(1.0, 0.88, 0.42)
const XP_FLASH_S := 0.2
const XP_FLASH_ALPHA := 0.85
const GOLD_PULSE_SCALE := 1.15
const GOLD_PULSE_S := 0.12
const GOLD_PULSE_MAX_PER_S := 6
const PROGRESS_BRIGHTEN := 0.6 ## éclaircissement (× flash_scale) remplaçant l'échelle si mouvements réduits

var level_feedbacks := 0 ## montées de niveau signalées (tests)
var gold_pulses := 0 ## impulsions du compteur d'or (tests)
var _shown_level := -1
var _shown_gold := -1.0
var _gold_pulse_due_ms := -1000000
var _level_tween: Tween
var _gold_tween: Tween
var _xp_flash: ColorRect
var _level_text: Label


func _progress_level_changed(l: int) -> void:
	var prev := _shown_level
	_shown_level = l
	if prev < 0 or l <= prev: # affichage initial ou nouvelle run : pas de retour
		return
	level_feedbacks += 1
	_pulse_level_badge()
	_flash_xp_bar()
	_show_level_text(l)


func level_badge() -> Control:
	return _badge_label.get_parent() as Control


## Échelle courante du médaillon. Le médaillon est l'enfant d'un conteneur (qui remet scale à 1 à chaque tri) :
## l'impulsion s'applique donc à SES enfants (texture + numéro), dans un Control simple.
func level_badge_scale() -> float:
	return _badge_label.scale.x


func _set_badge_scale(v: float) -> void:
	for c in level_badge().get_children():
		var cc := c as Control
		if cc != null:
			cc.pivot_offset = cc.size * 0.5
			cc.scale = Vector2.ONE * v


func _pulse_level_badge() -> void:
	var badge := level_badge()
	if _level_tween != null and _level_tween.is_valid():
		_level_tween.kill()
	_set_badge_scale(1.0)
	badge.modulate = Color.WHITE
	_level_tween = badge.create_tween()
	if GameSettings.reduce_motion():
		var k := GameSettings.flash_scale()
		if k <= 0.0:
			_level_tween.kill()
			return
		var b := 1.0 + PROGRESS_BRIGHTEN * k
		badge.modulate = Color(b, b, b)
		_level_tween.tween_property(badge, "modulate", Color.WHITE, LEVEL_PULSE_S)
		return
	var up := LEVEL_PULSE_S / 3.0
	_level_tween.tween_method(_set_badge_scale, 1.0, LEVEL_PULSE_SCALE, up) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_level_tween.tween_method(_set_badge_scale, LEVEL_PULSE_SCALE, 1.0, LEVEL_PULSE_S - up) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _flash_xp_bar() -> void:
	var k := GameSettings.flash_scale()
	if k <= 0.0:
		return
	if _xp_flash == null:
		_xp_flash = ColorRect.new()
		_xp_flash.name = &"XpFlash"
		_xp_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_xp_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_xp_bar.add_child(_xp_flash)
	_xp_flash.color = Color(1.0, 1.0, 1.0, XP_FLASH_ALPHA * k)
	_xp_flash.visible = true
	var tw := _xp_flash.create_tween()
	tw.tween_property(_xp_flash, "color:a", 0.0, XP_FLASH_S)
	tw.tween_callback(func() -> void: _xp_flash.visible = false)


func level_text() -> Label:
	return _level_text if _level_text != null and is_instance_valid(_level_text) else null


func _show_level_text(l: int) -> void:
	if level_text() != null:
		_level_text.queue_free()
	var lb := Label.new()
	lb.name = &"LevelUpLabel"
	lb.text = "Niveau %d" % l
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_theme_font_size_override("font_size", HudMetrics.font(HudMetrics.TOAST, ui_scale))
	lb.add_theme_color_override("font_color", LEVEL_TEXT_COLOR)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("outline_size", HudMetrics.OUTLINE_T1)
	root.add_child(lb)
	lb.reset_size()
	_level_text = lb
	var rise := 0.0 if GameSettings.reduce_motion() else LEVEL_TEXT_RISE * ui_scale
	_place_level_text(0.0, lb, rise)
	var tw := lb.create_tween()
	tw.tween_method(_place_level_text.bind(lb, rise), 0.0, 1.0, LEVEL_TEXT_S)
	tw.parallel().tween_property(lb, "modulate:a", 0.0, LEVEL_TEXT_S * 0.35).set_delay(LEVEL_TEXT_S * 0.65)
	tw.tween_callback(lb.queue_free)


## Suit le joueur (il bouge pendant la seconde d'affichage) ; centre de l'écran sans joueur.
func _place_level_text(t: float, lb: Label, rise: float) -> void:
	if not is_instance_valid(lb):
		return
	var anchor := get_viewport().get_visible_rect().size * Vector2(0.5, 0.4)
	if player != null and is_instance_valid(player) and player is CanvasItem:
		anchor = (player as CanvasItem).get_global_transform_with_canvas().origin
	lb.position = anchor - Vector2(lb.size.x * 0.5, LEVEL_TEXT_ABOVE * ui_scale + lb.size.y + rise * t)


func _progress_gold_changed(g: float) -> void:
	var prev := _shown_gold
	_shown_gold = g
	if prev < 0.0 or g <= prev or not is_inside_tree(): # affichage initial, dépense, conversion
		return
	var delay := PickupManager.FLY_TIME
	var due := Time.get_ticks_msec() + int(delay * 1000.0)
	if due - _gold_pulse_due_ms < 1000 / GOLD_PULSE_MAX_PER_S:
		return # plafond : une impulsion déjà prévue dans la fenêtre
	_gold_pulse_due_ms = due
	get_tree().create_timer(delay, false).timeout.connect(pulse_gold)


## Impulsion du compteur d'or (appelée à l'arrivée des pièces ; publique pour les tests et captures).
func pulse_gold() -> void:
	if _gold_box == null or not is_instance_valid(_gold_box):
		return
	gold_pulses += 1
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	_gold_box.scale = Vector2.ONE
	_gold_box.modulate = Color.WHITE
	_gold_box.pivot_offset = Vector2(_gold_box.size.x, _gold_box.size.y * 0.5) # grandit vers la gauche (bouton pause)
	_gold_tween = _gold_box.create_tween()
	if GameSettings.reduce_motion():
		var k := GameSettings.flash_scale()
		if k <= 0.0:
			_gold_tween.kill()
			return
		var b := 1.0 + PROGRESS_BRIGHTEN * k
		_gold_box.modulate = Color(b, b, b)
		_gold_tween.tween_property(_gold_box, "modulate", Color.WHITE, GOLD_PULSE_S)
		return
	var up := GOLD_PULSE_S / 3.0
	_gold_tween.tween_property(_gold_box, "scale", Vector2.ONE * GOLD_PULSE_SCALE, up) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gold_tween.tween_property(_gold_box, "scale", Vector2.ONE, GOLD_PULSE_S - up)
