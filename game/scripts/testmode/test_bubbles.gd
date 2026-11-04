class_name TestBubbles
extends CanvasLayer
## Mode test : bulles rondes semi-transparentes posées sur un bord de l'écran, au-dessus du jeu et du HUD, utilisables
## sans ouvrir le panneau. Colonne : VFX (bascule vfx_test), HUD (bascule hide_hud), Poutch (mannequin), puis une bulle par
## sort du personnage (slots 1-4, variantes équipées comprises) qui LANCE le vrai sort. Si un boss est présent, une seconde
## colonne propose ses attaques forcées (TestBossAdapter) et le passage de phase.
## Contrôles : souris et tactile (toucher une bulle ; la poignée du haut se déplace en glissant et replie d'un toucher),
## clavier F2 / manette clic du stick droit (R3) = « mode bulles » : D-pad ou stick gauche pour naviguer, A / Entrée pour
## lancer, R3 / F2 / B pour sortir. Visée des sorts : curseur (PC, dernier point survolé hors bulles), stick droit
## (manette), sinon l'ennemi le plus proche, sinon devant le joueur.
## Attaché à TestOverlay. À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const LAYER_INDEX := 30 ## au-dessus du HUD (10) et du bouton TEST (20), sous le panneau (90)
const PAD_TOGGLE := JOY_BUTTON_RIGHT_STICK
const KEY_TOGGLE := KEY_F2
const POLL_S := 0.3
const MARGIN := 16.0
const COL_ON := Color(1.0, 0.70, 0.28, 0.85)
const COL_OFF := Color(0.08, 0.10, 0.14, 0.58)
const COL_BORDER := Color(0.85, 0.88, 0.95, 0.75)
const COL_BAD := Color(0.5, 0.2, 0.2, 0.4)
const DRAG_PX := 14.0
const AIM_RANGE_U := 8.0
const STICK_MIN := 0.2

## Bulles visibles (option du panneau). Remis à vrai à chaque entrée en mode test.
static var shown := true
static var instance: TestBubbles = null

var hider: TestHudHider
var collapsed := false
var pad_mode := false
var bubble_size := 86.0

var _root: Control
var _wrap: HBoxContainer
var _boss_grid: GridContainer
var _main_col: VBoxContainer
var _content: VBoxContainer
var _handle: Button
var _vfx_btn: Button
var _hud_btn: Button
var _poutch_btn: Button
var _toast: Label
var _toast_token := 0
var _frac := Vector2(1.0, 0.5) ## position de la colonne dans la zone libre (0..1)
var _acc := 0.0
var _sig := ""
var _boss_idx := 0
var _boss_attacks: Array[Dictionary] = []
var _boss: Enemy = null
var _mouse_world := Vector2.ZERO
var _has_mouse := false
var _pressing := false
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_off := Vector2.ZERO
var _suppress_press := false
var _muted_input: TestMutedInput = null
var _muted_id := 0


static func attach(parent: Node) -> TestBubbles:
	shown = true
	var b := TestBubbles.new()
	b.name = "TestBubbles"
	parent.add_child(b)
	return b


## Option du panneau : affiche / masque les bulles.
static func set_shown(on: bool) -> void:
	shown = on
	if instance != null and is_instance_valid(instance):
		instance._apply_shown()


func _ready() -> void:
	instance = self
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	hider = TestHudHider.new()
	hider.name = "HudHider"
	add_child(hider)
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_wrap = HBoxContainer.new()
	_wrap.name = "Wrap"
	_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrap.add_theme_constant_override(&"separation", 10)
	_root.add_child(_wrap)
	_boss_grid = GridContainer.new()
	_boss_grid.name = "BossGrid"
	_boss_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_grid.add_theme_constant_override(&"h_separation", 8)
	_boss_grid.add_theme_constant_override(&"v_separation", 8)
	_wrap.add_child(_boss_grid)
	_main_col = VBoxContainer.new()
	_main_col.name = "MainCol"
	_main_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_col.add_theme_constant_override(&"separation", 8)
	_wrap.add_child(_main_col)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override(&"separation", 8)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.theme = UiTheme.theme()
	_toast.add_theme_font_size_override(&"font_size", 26)
	_toast.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override(&"outline_size", 8)
	_toast.visible = false
	_root.add_child(_toast)
	_wrap.minimum_size_changed.connect(_place_deferred)
	get_viewport().size_changed.connect(_on_viewport_resized)
	Platform.safe_area_changed.connect(_place_deferred)
	TestMode.changed.connect(_on_mode_changed)
	Events.boss_spawned.connect(func(_b: Node2D, _f: bool) -> void: _sig = "")
	Events.boss_killed.connect(func(_b: Node2D, _f: bool) -> void: _sig = "")
	_build_handle()
	_rebuild()
	_apply_shown()


func _exit_tree() -> void:
	if _muted_input != null:
		_mute_player_input(false)
	if instance == self:
		instance = null
	if TestMode.changed.is_connected(_on_mode_changed):
		TestMode.changed.disconnect(_on_mode_changed)


func _apply_shown() -> void:
	visible = shown
	if not shown and pad_mode:
		_set_pad_mode(false)


# --- Mise à jour -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not shown:
		return
	_acc += delta
	if _acc < POLL_S:
		return
	_acc = 0.0
	var s := _signature()
	if s != _sig:
		_rebuild()
	else:
		_refresh_states()


func _on_mode_changed() -> void:
	_refresh_states()


func _on_viewport_resized() -> void:
	_rebuild()


func _signature() -> String:
	var parts: PackedStringArray = [String(RunState.character), str(bubble_size)]
	var sc := _caster()
	if sc != null and sc.character != null:
		for s in sc.character.spells:
			parts.append("%d:%s" % [s.slot, s.id])
	var bosses := TestBossAdapter.bosses(get_tree())
	if not bosses.is_empty():
		parts.append("b%d/%d:%s" % [_boss_idx % bosses.size(), bosses.size(), TestBossAdapter.signature(bosses[_boss_idx % bosses.size()])])
	return "|".join(parts)


func _caster() -> SpellCaster:
	var p := TestTools.player_of(get_tree())
	if p == null:
		return null
	var sc: Variant = p.get(&"spells")
	return sc as SpellCaster


# --- Construction ------------------------------------------------------------------------

func _compute_size() -> void:
	var vp := get_viewport().get_visible_rect().size
	bubble_size = clampf(snappedf(vp.y * 0.08, 2.0), 64.0, 96.0)
	if Platform.input_mode == Platform.InputMode.TOUCH:
		bubble_size = maxf(bubble_size, UiTheme.MIN_TOUCH)


func _build_handle() -> void:
	_handle = _bubble("≡", "Glisser pour déplacer, toucher pour replier (F2 / R3 : mode bulles)", _on_handle_pressed)
	_handle.name = "Handle"
	_handle.gui_input.connect(_on_handle_input)
	_main_col.add_child(_handle)
	_main_col.add_child(_content)


func _rebuild() -> void:
	_compute_size()
	_sig = _signature()
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	for c in _boss_grid.get_children():
		_boss_grid.remove_child(c)
		c.queue_free()
	_style(_handle, false)
	_handle.custom_minimum_size = Vector2(bubble_size, bubble_size)
	_handle.add_theme_font_size_override(&"font_size", int(bubble_size * 0.4))
	_vfx_btn = _bubble("VFX", "VFX pixelfx sur les vrais sorts (bascule)", func() -> void: TestMode.set_flag(&"vfx_test", not TestMode.vfx_test))
	_vfx_btn.name = "Bubble_vfx"
	_content.add_child(_vfx_btn)
	_hud_btn = _bubble("HUD", "Masquer le HUD (bascule ; le joystick tactile reste)", func() -> void: TestMode.set_flag(&"hide_hud", not TestMode.hide_hud))
	_hud_btn.name = "Bubble_hud"
	_content.add_child(_hud_btn)
	_poutch_btn = _bubble("Poutch", "Mannequin d'entraînement devant le joueur (rappuyer le retire)", _on_poutch_pressed)
	_poutch_btn.name = "Bubble_poutch"
	_content.add_child(_poutch_btn)
	var sc := _caster()
	if sc != null and sc.character != null:
		for s in sc.character.spells:
			var sd: SpellData = s
			var icon := ArdentKit.spell_icon(sd.id)
			var tip := "%d · %s%s" % [sd.slot, sd.display_name if sd.display_name != "" else String(sd.id), " (auto)" if sd.is_auto else ""]
			var slot := sd.slot
			var b := _bubble("" if icon != null else (sd.display_name if sd.display_name != "" else String(sd.id)).substr(0, 2), tip, func() -> void: _cast_slot(slot), icon)
			b.name = "Bubble_spell_%d" % slot
			b.set_meta(&"slot", slot)
			_content.add_child(b)
	_rebuild_boss()
	_refresh_states()
	_set_focusable(pad_mode)
	_apply_collapsed()
	_place_deferred()


func _rebuild_boss() -> void:
	_boss = null
	_boss_attacks.clear()
	var bosses := TestBossAdapter.bosses(get_tree())
	if bosses.is_empty():
		_boss_grid.visible = false
		return
	_boss = bosses[_boss_idx % bosses.size()]
	_boss_attacks = TestBossAdapter.attacks(_boss)
	var head := _bubble(TestBossAdapter.title(_boss).substr(0, 4), "%s : toucher pour passer au boss suivant (%d)" % [TestBossAdapter.title(_boss), bosses.size()], func() -> void:
		_boss_idx += 1
		_sig = "")
	head.name = "Boss_head"
	_boss_grid.add_child(head)
	for a in _boss_attacks:
		var atk: Dictionary = a
		var b := _bubble(String(atk.label), String(atk.tip), func() -> void: _fire_boss(atk))
		b.name = "Boss_%s" % String(atk.id).replace(":", "_")
		b.disabled = not bool(atk.ok)
		_boss_grid.add_child(b)
	var n := _boss_grid.get_child_count()
	_boss_grid.columns = 1 if n <= 6 else (2 if n <= 12 else 3)
	_boss_grid.visible = not collapsed


func _bubble(text: String, tip: String, cb: Callable, icon: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(bubble_size, bubble_size)
	b.add_theme_font_size_override(&"font_size", int(bubble_size * (0.34 if text.length() <= 3 else 0.24)))
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_outline_color", Color.BLACK)
	b.add_theme_constant_override(&"outline_size", 6)
	if icon != null:
		b.icon = icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override(&"icon_max_width", int(bubble_size * 0.62))
	b.pressed.connect(cb)
	_style(b, false)
	return b


func _style(b: Button, on: bool) -> void:
	var r := int(bubble_size * 0.5)
	var bg := COL_ON if on else COL_OFF
	for st in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(r)
		sb.set_border_width_all(3 if st != &"focus" else 6)
		sb.border_color = COL_BORDER if st != &"focus" else Color(1.0, 1.0, 1.0, 0.95)
		match st:
			&"hover":
				sb.bg_color = bg.lightened(0.18)
			&"pressed":
				sb.bg_color = bg.lightened(0.32)
			&"disabled":
				sb.bg_color = COL_BAD
				sb.border_color = Color(0.6, 0.6, 0.6, 0.4)
		if st == &"focus":
			sb.bg_color = Color(0, 0, 0, 0)
			sb.draw_center = false
		b.add_theme_stylebox_override(st, sb)


## Allumage des bulles à bascule (VFX, HUD, Poutch) et de la poignée (mode bulles).
func _refresh_states() -> void:
	if _vfx_btn != null:
		_style(_vfx_btn, TestMode.vfx_test)
	if _hud_btn != null:
		_style(_hud_btn, TestMode.hide_hud)
	if _poutch_btn != null:
		_style(_poutch_btn, not TestTools.poutchs(get_tree()).is_empty())
	if _handle != null:
		_style(_handle, pad_mode)


# --- Position, repli, glisser ------------------------------------------------------------

func _place_deferred() -> void:
	if is_inside_tree():
		_place.call_deferred()


func _place() -> void:
	if _wrap == null:
		return
	_wrap.size = _wrap.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
	var safe := Platform.safe_margins()
	var lo := Vector2(float(safe.get("left", 0.0)) + MARGIN, float(safe.get("top", 0.0)) + MARGIN)
	var hi := vp - Vector2(float(safe.get("right", 0.0)) + MARGIN, float(safe.get("bottom", 0.0)) + MARGIN) - _wrap.size
	hi = Vector2(maxf(hi.x, lo.x), maxf(hi.y, lo.y))
	_wrap.position = lo + (hi - lo) * Vector2(clampf(_frac.x, 0.0, 1.0), clampf(_frac.y, 0.0, 1.0))
	if _toast != null:
		_toast.position = Vector2(vp.x * 0.5 - 360.0, vp.y * 0.86)
		_toast.size = Vector2(720.0, 40.0)
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _set_pos(p: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := Platform.safe_margins()
	var lo := Vector2(float(safe.get("left", 0.0)) + MARGIN, float(safe.get("top", 0.0)) + MARGIN)
	var hi := vp - Vector2(float(safe.get("right", 0.0)) + MARGIN, float(safe.get("bottom", 0.0)) + MARGIN) - _wrap.size
	hi = Vector2(maxf(hi.x, lo.x + 1.0), maxf(hi.y, lo.y + 1.0))
	_frac = Vector2(clampf((p.x - lo.x) / (hi.x - lo.x), 0.0, 1.0), clampf((p.y - lo.y) / (hi.y - lo.y), 0.0, 1.0))
	_place()


func _on_handle_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			_pressing = true
			_dragging = false
			_drag_start = mb.global_position
			_drag_off = _wrap.position - mb.global_position
		else:
			_suppress_press = _dragging
			_pressing = false
			_dragging = false
	elif ev is InputEventMouseMotion and _pressing:
		var mm := ev as InputEventMouseMotion
		if not _dragging and mm.global_position.distance_to(_drag_start) > DRAG_PX:
			_dragging = true
		if _dragging:
			_set_pos(mm.global_position + _drag_off)


func _on_handle_pressed() -> void:
	if _suppress_press:
		_suppress_press = false
		return
	collapsed = not collapsed
	_apply_collapsed()


func _apply_collapsed() -> void:
	_content.visible = not collapsed
	_boss_grid.visible = not collapsed and _boss_grid.get_child_count() > 0
	_place_deferred()


# --- Actions -----------------------------------------------------------------------------

func say(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	_toast_token += 1
	var tok := _toast_token
	get_tree().create_timer(2.6, true).timeout.connect(func() -> void:
		if tok == _toast_token and is_instance_valid(_toast):
			_toast.visible = false)


## Point au sol qu'un sort visé doit prendre : curseur (PC), stick droit (manette), ennemi le plus proche, devant le joueur.
func aim_point(sc: SpellCaster, player: Node2D) -> Vector2:
	match Platform.input_mode:
		Platform.InputMode.KBM:
			if _has_mouse:
				return _mouse_world
		Platform.InputMode.GAMEPAD:
			var v := sc.input_source().aim_vector()
			if v.length() >= STICK_MIN:
				return player.global_position + Iso.screen_to_logical_dir(v) * Balance.UNIT_PX * AIM_RANGE_U
	var near := sc.nearest_enemy(TestMode.INF_RANGE_PX)
	if near != null:
		return near.global_position
	return front_of(player, 6.0)


func front_of(player: Node2D, units: float) -> Vector2:
	var f: Variant = player.get(&"facing")
	var d := Vector2.RIGHT
	if f is Vector2 and (f as Vector2).length_squared() > 0.01:
		d = Iso.screen_to_logical_dir(f as Vector2)
	return player.global_position + d.normalized() * Balance.UNIT_PX * units


## Lance le vrai sort du slot (recharge remise à zéro, jauge pleine). Retourne ce que renvoie SpellCaster.cast.
func cast_slot(slot: int) -> bool:
	var p := TestTools.player_of(get_tree())
	var sc := _caster()
	if p == null or sc == null or not sc.has_slot(slot):
		return false
	sc.refill_kit_resource()
	sc.set_cooldown(slot, 0.0, 1.0)
	sc.aim_override = aim_point(sc, p)
	var ok := sc.cast(slot)
	sc.aim_override = null
	if get_tree().paused:
		sc.flush_pending()
	return ok


func _cast_slot(slot: int) -> void:
	if not cast_slot(slot):
		say("Sort %d : pas lancé (cible hors portée ? bulle Poutch)." % slot)


func _on_poutch_pressed() -> void:
	toggle_poutch()


## Apparition d'un mannequin devant le joueur, ou retrait s'il y en a déjà. Retourne vrai s'il y en a un ensuite.
func toggle_poutch() -> bool:
	var tree := get_tree()
	if not TestTools.poutchs(tree).is_empty():
		TestTools.clear_poutchs(tree)
		_refresh_states()
		return false
	var p := TestTools.player_of(tree)
	if p == null:
		return false
	var t := TestTools.spawn_poutch(tree, &"normal", front_of(p, 5.0))
	_refresh_states()
	return t != null


func _fire_boss(atk: Dictionary) -> void:
	if _boss == null or not is_instance_valid(_boss):
		say("Boss disparu.")
		_sig = ""
		return
	if TestMode.freeze_ai and atk.get("kind", &"") != &"phase":
		say("IA figée : l'attaque ne se jouera pas (Triches > IA figée).")
	var p := TestTools.player_of(get_tree())
	if not TestBossAdapter.fire(_boss, atk, p.global_position if p != null else _boss.global_position):
		say("Attaque non lancée (boss en intro ou non supporté).")
	_sig = "" # la phase peut avoir changé : liste reconstruite au prochain passage


# --- Manette / clavier : mode bulles -----------------------------------------------------

func _input(event: InputEvent) -> void:
	if not shown:
		return
	if event is InputEventMouseMotion and Platform.input_mode == Platform.InputMode.KBM:
		var p := TestTools.player_of(get_tree())
		if p != null and not _wrap.get_global_rect().grow(8.0).has_point((event as InputEventMouseMotion).position):
			_mouse_world = p.get_global_mouse_position()
			_has_mouse = true
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TOGGLE:
		_set_pad_mode(not pad_mode)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == PAD_TOGGLE:
		_set_pad_mode(not pad_mode)
		get_viewport().set_input_as_handled()
	elif pad_mode and event.is_action_pressed(&"ui_cancel"):
		_set_pad_mode(false)
		get_viewport().set_input_as_handled()


func _set_pad_mode(on: bool) -> void:
	pad_mode = on
	_mute_player_input(on)
	_set_focusable(on)
	if on:
		collapsed = false
		_apply_collapsed()
		if _vfx_btn != null:
			_vfx_btn.grab_focus()
		say("Mode bulles : D-pad / stick naviguent, A lance, R3 / F2 / B sortent.")
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and _wrap.is_ancestor_of(f):
			f.release_focus()
	_refresh_states()


## Pendant le mode bulles, le joueur ne bouge pas et ne lance rien au clavier / à la manette : sa source d'entrée est
## enveloppée par TestMutedInput (déplacement nul, aucune action). Tactile non touché ; restituée à la sortie.
func _mute_player_input(on: bool) -> void:
	var p := TestTools.player_of(get_tree())
	if p == null:
		return
	var pid := PlayerRef.id_of(p)
	var cur: InputSource = Players.input_of(pid)
	if on:
		if _muted_input != null or cur == null or cur.kind == InputSource.Kind.TOUCH:
			return
		_muted_input = TestMutedInput.new(cur)
		_muted_id = pid
		_set_player_input(pid, _muted_input)
	elif _muted_input != null:
		if cur == _muted_input:
			_set_player_input(_muted_id, _muted_input.inner)
		_muted_input = null


func _set_player_input(pid: int, src: InputSource) -> void:
	if Players.entry(pid) != null:
		Players.set_input(pid, src)
	else:
		Players.set(&"_implicit_input", src) # solo sans inscription : source implicite


func _set_focusable(on: bool) -> void:
	var mode := Control.FOCUS_ALL if on else Control.FOCUS_NONE
	for root in [_main_col, _boss_grid]:
		for b in (root as Node).find_children("*", "Button", true, false):
			(b as Button).focus_mode = mode
