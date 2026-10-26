class_name SpellButton
extends Control
## Case de sort : icône (ou initiale du sort si l'icône n'est pas livrée), recharge circulaire avec
## secondes restantes, anneau « prêt ». Deux usages :
##   - bouton tactile (interactive = true) : un tap court simule l'action spell_N (Input.action_press au
##     relâcher, release 2 images plus tard) ; un appui long (LONG_PRESS_S) n'en lance pas et ouvre la
##     description du sort (SpellHint, is_long_pressed()) ;
##   - barre de sorts clavier-souris / manette (interactive = false) : affichage seul, la souris passe à
##     travers (les clics servent à viser).
## Le HUD appelle set_spell() puis set_cooldown() avec les données de player.get_spell_cooldowns().

const READY_COLOR := Color(1.0, 0.78, 0.35)
const COOLDOWN_RING := Color(0.5, 0.5, 0.6)
## Cadres rendus dans Blender (160 px, centre transparent) et anneau de recharge (TextureProgressBar radiale).
const FRAME_READY := "res://assets/sprites/ui/spell_frame.png"
const FRAME_PRESSED := "res://assets/sprites/ui/spell_frame_pressed.png"
const FRAME_COOLDOWN := "res://assets/sprites/ui/spell_frame_cooldown.png"
const RING := "res://assets/sprites/ui/spell_cooldown_ring.png"
const RING_TINT := Color(1.0, 0.7, 0.3, 0.95)
const ICON_FRACTION := 0.72 ## côté de l'icône / côté du cadre (ouverture centrale du cadre)
## Sous-couche claire derrière l'icône (audit HUD H10 : icônes sombres, contraste icône/fond >= 3:1) ; le liseré
## clair rendu dans les icônes par Codex (art/tools/night/_uxhud_icons.txt) la complète, elle reste en filet de sécurité.
const ICON_UNDERLAY := Color(0.91, 0.886, 0.839, 0.18)
## Normalisation de la lisibilité des icônes : luminance moyenne visée (0-1, pixels opaques, Rec.709) ; une icône plus
## sombre est éclaircie par un gain (plafonné) au dessin. Les icônes de Vigie (rouge sombre sur fond noir) étaient
## quasi invisibles à côté de celles d'Ardent ; valable pour tous les personnages.
const ICON_TARGET_LUMA := 0.18
const ICON_MAX_GAIN := 1.9
const FONT_MIN_PC := 18 ## aucun texte de jeu sous 18 px PC / 26 px mobile (contrat 23:30)
const FONT_MIN_MOBILE := 26
## Zone de frappe tactile invisible autour du bouton (audit E-06, lot A11y-L4) : disque de rayon côté / 2 + HIT_PAD
## (réduit proportionnellement sous 150 px). Le HUD garde >= 40 px entre deux boutons : les zones ne se chevauchent pas.
const HIT_PAD := 16.0

static var _tex_cache := {}
static var _gain_cache := {}

var slot := 2
var action := &"spell_2"
var remaining := 0.0
var total := 0.0
var interactive := true
var icon: Texture2D = null
var caption := "" ## nom du sort : initiale de repli si l'icône manque (jamais affiché en entier)
var is_auto := false ## sort 1 : pas de voile de recharge (cadence d'attaque)
var _spell_id: StringName = &""
var _held := false
var _touch := -1
var _flash := 0.0 ## halo bref quand le sort redevient prêt
var _ring: TextureProgressBar = null
## Tactile : un tap court lance le sort au relâcher ; un appui tenu LONG_PRESS_S ouvre la description (SpellHint)
## sans lancer le sort.
const LONG_PRESS_S := 0.6 ## audit E-08 : 0,6 s, et seulement si le doigt reste immobile
const LONG_DRIFT_PX := 12.0 ## glissement max (px écran) pour qu'un appui reste « long » ; au-delà, lancer au relâcher
var _press_pos := Vector2.ZERO
var _drifted := false
var _press_t := 0.0
var _long := false
var _tap_frame := -1 ## image physique du tap simulé (action relâchée 2 images plus tard), -1 = aucun
var _tap_pframe := -1
var charges := -1 ## charges disponibles (-1 : sort sans charges)
var max_charges := 0
var charge_color := READY_COLOR
var affordable := true ## faux : ressource du kit insuffisante (voile gris + lack_text)
var lack_text := ""
var cost_text := "" ## coût du sort (« 20 d'eau »), affiché par SpellHint au lieu de la recharge


## Marge de frappe effective (px logiques) : 0 pour un affichage seul.
func hit_pad() -> float:
	if not interactive:
		return 0.0
	return HIT_PAD * clampf(minf(size.x, size.y) / 150.0, 0.6, 1.0)


## Rayon de la zone de frappe (centre = centre du bouton).
func hit_radius() -> float:
	return minf(size.x, size.y) * 0.5 + hit_pad()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= hit_radius()


static func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## Luminance moyenne (0-1) des pixels opaques d'une icône (échantillonnée en 32 x 32).
static func icon_luma(tex: Texture2D) -> float:
	if tex == null:
		return ICON_TARGET_LUMA
	var img := tex.get_image()
	if img == null:
		return ICON_TARGET_LUMA
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
	var sum := 0.0
	var n := 0
	for y in 32:
		for x in 32:
			var px := img.get_pixel(x, y)
			if px.a > 0.2:
				sum += 0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b
				n += 1
	return sum / n if n > 0 else ICON_TARGET_LUMA


## Gain de luminosité appliqué à l'icône au dessin (1 = inchangée) : ICON_TARGET_LUMA / luminance, plafonné.
static func icon_gain(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var key := tex.resource_path
	if key == "" or not _gain_cache.has(key):
		var g := clampf(ICON_TARGET_LUMA / maxf(icon_luma(tex), 0.01), 1.0, ICON_MAX_GAIN)
		if key == "":
			return g
		_gain_cache[key] = g
	return _gain_cache[key]


func setup(spell_slot: int, size_px: float = 150.0) -> void:
	slot = spell_slot
	action = StringName("spell_%d" % spell_slot)
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if _ring == null and _tex(RING) != null:
		_ring = TextureProgressBar.new()
		_ring.texture_progress = _tex(RING)
		_ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		_ring.nine_patch_stretch = true
		_ring.tint_progress = RING_TINT
		_ring.max_value = 1.0
		_ring.step = 0.0
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_ring)
	_sync_ring()
	queue_redraw()


## Anneau radial : part restante de la recharge (se vide dans le sens horaire).
func _sync_ring() -> void:
	if _ring == null:
		return
	var cooling := not is_auto and remaining > 0.0 and total > 0.0
	_ring.visible = cooling
	if cooling:
		_ring.value = clampf(remaining / total, 0.0, 1.0)


## Sort affiché (id SpellData, nom). Ne recharge l'icône que si l'id change.
func set_spell(sid: StringName, display_name: String, auto := false) -> void:
	if sid == _spell_id:
		return
	_spell_id = sid
	icon = ArdentKit.spell_icon(sid)
	caption = display_name
	is_auto = auto
	queue_redraw()


## Ressource du kit (SpellCaster.slot_affordable / slot_cost_info, Averse : eau) : faux = bouton grisé avec
## `lack_text` (« pas assez d'eau ») au lieu d'un camembert ; `cost_text` = coût lu par la bulle (SpellHint).
func set_affordable(ok: bool, lack: String = "", cost: String = "") -> void:
	cost_text = cost
	if ok != affordable or lack != lack_text:
		if ok and not affordable and not is_auto and remaining <= 0.0:
			_flash = 0.35
		affordable = ok
		lack_text = lack
		queue_redraw()


func set_cooldown(rem: float, tot: float) -> void:
	# comparaison exacte : is_equal_approx(0.0, 1e-6) est vrai et figeait l'affichage à « 0.0 » en recharge
	if rem != remaining or tot != total:
		if rem <= 0.0 and remaining > 0.0 and not is_auto:
			_flash = 0.35
		remaining = rem
		total = tot
		_sync_ring()
		queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()
	if _touch != -1 and not _long and not _drifted:
		_press_t += delta
		if _press_t >= LONG_PRESS_S:
			_long = true # appui long : description, pas de sort
	# tap : l'action reste pressée 2 images (process et physique) pour être vue par is_action_just_pressed
	if _tap_frame >= 0 and Engine.get_physics_frames() >= _tap_frame + 2 and Engine.get_process_frames() >= _tap_pframe + 2:
		_release_tap()


func is_held() -> bool:
	return _held


## Id SpellData du sort affiché (description : SpellHint).
func spell_id() -> StringName:
	return _spell_id


## Doigt posé depuis au moins LONG_PRESS_S (description affichée, le sort ne partira pas).
func is_long_pressed() -> bool:
	return _long and _touch != -1


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch:
		if not _drifted and (event as InputEventScreenDrag).position.distance_to(_press_pos) >= LONG_DRIFT_PX:
			_drifted = true # le doigt glisse : plus un appui long, le sort partira au relâcher
			_long = false
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_press_t = 0.0
			_press_pos = t.position
			_drifted = false
			_long = false
			_held = true
			queue_redraw()
			accept_event()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			_held = false
			if not _long:
				_tap()
			_long = false
			queue_redraw()
			accept_event()


## Tap court : simule l'action (relâchée 2 images plus tard par _process).
func _tap() -> void:
	if not InputMap.has_action(action):
		return
	Input.action_press(action)
	_tap_frame = Engine.get_physics_frames()
	_tap_pframe = Engine.get_process_frames()


func _release_tap() -> void:
	_tap_frame = -1
	if InputMap.has_action(action):
		Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		# appui annulé (pause, bouton masqué) : aucun sort lancé
		if _held or _touch != -1:
			_touch = -1
			_held = false
			_long = false
			queue_redraw()
		if _tap_frame >= 0:
			_release_tap()


## Plancher de taille de texte (px) selon la plateforme.
static func _font_floor() -> int:
	return FONT_MIN_MOBILE if Platform.is_mobile() else FONT_MIN_PC


## Initiale du libellé (repli d'icône manquante) : première lettre, jamais le nom entier.
func initial() -> String:
	var t := caption.strip_edges()
	return t.substr(0, 1).to_upper() if t != "" else str(slot)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var k := size.x / 150.0
	var cooling := not is_auto and remaining > 0.0 and total > 0.0
	var broke := not is_auto and not affordable and not cooling ## ressource du kit insuffisante
	var font := ThemeDB.fallback_font
	var frame := _tex(FRAME_COOLDOWN if cooling or broke else (FRAME_PRESSED if _held else FRAME_READY))
	draw_circle(c, r * (0.8 if frame != null else 1.0), Color(0.08, 0.09, 0.13, 0.85 if not _held else 0.95))
	# sous-couche claire derrière l'icône ou l'initiale (contraste >= 3:1)
	if not (broke and lack_text != ""):
		draw_circle(c, r * (0.8 if frame != null else 1.0), ICON_UNDERLAY)
	# icône (carrée, dans l'ouverture du cadre) ou repli : initiale du sort (jamais le nom complet)
	if icon != null:
		var side := size.x * ICON_FRACTION if frame != null else r * 1.62
		var g := icon_gain(icon)
		var mod := Color(g, g, g, 1) if not (cooling or broke) else Color(0.55, 0.55, 0.6, 1)
		draw_texture_rect(icon, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)), false, mod)
	elif not (broke and lack_text != ""): # le message de manque remplace l'initiale
		# en recharge l'initiale s'efface (alpha 0,22) : le chiffre des secondes prime
		var fi := maxi(int(64 * k), _font_floor())
		var ia := 0.5 if broke else 0.95
		if cooling:
			ia = 0.22
		var ip := c + Vector2(-r, fi * 0.36)
		draw_string_outline(font, ip, initial(), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fi, int(8 * k), Color(0, 0, 0, 0.9 * ia))
		draw_string(font, ip, initial(), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fi, Color(1, 1, 1, ia))
	if cooling:
		var f := clampf(remaining / total, 0.0, 1.0)
		_draw_pie(c, r, f, Color(0, 0, 0, 0.55))
		if frame != null:
			draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
		var txt := "%.1f" % remaining if remaining < 10.0 else str(int(ceil(remaining)))
		var fs := int(46 * k)
		draw_string_outline(font, c + Vector2(-r, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, int(8 * k), Color(0, 0, 0, 0.9))
		draw_string(font, c + Vector2(-r, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
		if frame == null:
			draw_arc(c, r, 0.0, TAU, 48, COOLDOWN_RING, 4.0 * maxf(k, 0.5))
		if _ring == null: # progression : arc clair qui se referme
			draw_arc(c, r, -PI * 0.5 + TAU * f, PI * 1.5, 48, Color(1, 1, 1, 0.8), 4.0 * maxf(k, 0.5))
	elif broke: # voile gris plein + « pas assez d'eau » (aucun camembert : ce n'est pas une recharge)
		draw_circle(c, r * (0.8 if frame != null else 1.0), Color(0.05, 0.05, 0.07, 0.6))
		if frame != null:
			draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
		else:
			draw_arc(c, r, 0.0, TAU, 48, COOLDOWN_RING, 4.0 * maxf(k, 0.5))
		if lack_text != "":
			var fl := maxi(int(22 * k), _font_floor())
			var pos := c + Vector2(-r * 0.8, -fl * 0.35)
			draw_multiline_string_outline(font, pos, lack_text, HORIZONTAL_ALIGNMENT_CENTER, r * 1.6, fl, 2, int(6 * k), Color(0, 0, 0, 0.95))
			draw_multiline_string(font, pos, lack_text, HORIZONTAL_ALIGNMENT_CENTER, r * 1.6, fl, 2, Color(0.82, 0.84, 0.88))
	else:
		if frame != null:
			draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
		else:
			draw_arc(c, r, 0.0, TAU, 48, READY_COLOR, 6.0 * maxf(k, 0.5))
		if _flash > 0.0:
			draw_arc(c, r + 6.0 * k, 0.0, TAU, 48, Color(1, 0.9, 0.6, _flash / 0.35), 8.0 * maxf(k, 0.5))
	_draw_charges(c, r, k)
	if is_auto:
		var ar := _auto_rect()
		var fa := _auto_font_px()
		var ap := Vector2(ar.position.x, ar.position.y + font.get_ascent(fa))
		draw_string_outline(font, ap, "AUTO", HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, fa, int(6 * k), Color(0, 0, 0, 0.9))
		draw_string(font, ap, "AUTO", HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, fa, READY_COLOR)


func _auto_font_px() -> int:
	return maxi(int(24 * size.x / 150.0), _font_floor())


## Boîte du libellé « AUTO » (locale) : SOUS le cadre du bouton, jamais dessus (au plancher, 26 px mobile, il est plus
## large que le petit rond de 72 px : la boîte s'élargit au besoin, centrée, au lieu de couper en « AUT »).
func _auto_rect() -> Rect2:
	var k := size.x / 150.0
	var font := ThemeDB.fallback_font
	var fa := _auto_font_px()
	var aw := maxf(size.x, font.get_string_size("AUTO", HORIZONTAL_ALIGNMENT_LEFT, -1, fa).x + 2.0 * maxf(6.0 * k, 2.0))
	return Rect2(Vector2((size.x - aw) * 0.5, size.y + UiTheme.ink_pad(fa) + 2.0 * maxf(k, 0.5)), Vector2(aw, font.get_height(fa)))


## Textes dessinés en `_draw` (rects globaux), pour text_overflow_test : {text, rect, size, within?, avoid?}.
func text_rects() -> Array:
	var out: Array = []
	var g := get_global_rect().position
	var font := ThemeDB.fallback_font
	var k := size.x / 150.0
	var cooling := not is_auto and remaining > 0.0 and total > 0.0
	if cooling:
		var txt := "%.1f" % remaining if remaining < 10.0 else str(int(ceil(remaining)))
		var fs := int(46 * k)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var h := font.get_height(fs)
		out.append({"text": txt, "size": fs, "rect": Rect2(g + (size - Vector2(w, h)) * 0.5, Vector2(w, h)), "within": get_global_rect()})
	if is_auto:
		var ar := _auto_rect()
		var fa := _auto_font_px()
		var aw := font.get_string_size("AUTO", HORIZONTAL_ALIGNMENT_LEFT, -1, fa).x
		out.append({"text": "AUTO", "size": fa, "rect": Rect2(g + ar.position + Vector2((ar.size.x - aw) * 0.5, 0.0), Vector2(aw, ar.size.y)),
			"avoid": [get_global_rect()]})
	return out


## Voile de recharge en camembert (fraction f du disque, depuis midi, sens horaire). Une part plus fine
## qu'un pixel d'arc n'est pas dessinée : ses sommets se confondent (reste flottant d'une recharge, ex.
## 1e-7 s après reduce_cooldown) et la triangulation échoue (« Invalid polygon data »). f ≈ 1 = disque plein.
func _draw_pie(c: Vector2, r: float, f: float, col: Color) -> void:
	if f >= 0.999:
		draw_circle(c, r, col)
		return
	if f * TAU * r < 1.0:
		return
	var pts := PackedVector2Array([c])
	var steps := maxi(int(48.0 * f), 2)
	for i in steps + 1:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * f * float(i) / steps) * r)
	draw_colored_polygon(pts, col)


## Charges (Tocsin : membres, Bourbe : mottes) : pastilles sous l'icône ; -1 = sort sans charges.
func set_charges(n: int, max_n: int, col: Color) -> void:
	if n != charges or max_n != max_charges or col != charge_color:
		charges = n
		max_charges = max_n
		charge_color = col
		queue_redraw()


func _draw_charges(c: Vector2, r: float, k: float) -> void:
	if charges < 0 or max_charges <= 0:
		return
	var pr := maxf(5.0 * k, 3.0)
	var gap := pr * 2.6
	var y := c.y + r * 0.62
	var x0 := c.x - gap * (max_charges - 1) * 0.5
	for i in max_charges:
		var p := Vector2(x0 + gap * i, y)
		draw_circle(p, pr + 1.5 * k, Color(0, 0, 0, 0.85))
		if i < charges:
			draw_circle(p, pr, Color(charge_color.r * 1.4, charge_color.g * 1.4, charge_color.b * 1.4))
		else:
			draw_arc(p, pr * 0.8, 0.0, TAU, 12, Color(charge_color, 0.6), maxf(1.5 * k, 1.0))
