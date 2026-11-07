class_name CoopPlates
extends Control
## HUD de la coop locale PC (étape 4, avis ux-designer du 07/11/2026, docs/multi/Design_Coop.md §4.1) : une plaque
## compacte par joueur, rangée du bas, ordre 1 → 4 de gauche à droite (ordre de l'écran de jonction) ; joueurs 1-2
## au coin bas-gauche, 3-4 au coin bas-droit, le bas-centre reste libre (invite d'interaction du joueur 1). Écran trop
## étroit (plaque < MIN_W) : 2 × 2 empilées dans les deux coins.
## Contenu d'une plaque : pastille à la teinte d'équipe + chiffre (Palette.team_color / team_glyph : la couleur ne
## porte jamais seule le sens), appareil, nom, niveau, or individuel ; barre de PV + « PV / max » ; sorts 1-4 (icône,
## voile et secondes de recharge). États : spectateur (plaque gardée, alpha 0,6, « Spectateur · retour à l'étage
## suivant ») ; manette déconnectée (bord gris, « Manette déconnectée »).
## Invites d'interaction des joueurs 2-4 : petite bulle « 2 · A Ouvrir » au-dessus de leur tête (le joueur 1 garde
## l'invite du HUD au bas-centre).
## Visible seulement en coop locale (Hud.is_local_coop()) ; solo : rien n'est créé, HUD inchangé.
## Une seule passe de _draw, redessinée à UPDATE_HZ ; caches d'icônes par sort ; au plus 4 joueurs.

const W := 400.0 ## px à ui_scale 1 (1920×1080)
const H := 132.0
const MIN_W := 340.0
const GAP := 16.0
const EDGE := 20.0 ## marge au bord de l'écran (en plus de la zone sûre)
const CENTER_FREE := 240.0 ## bas-centre gardé libre entre les deux groupes
const ICON := 52.0
const PAD := 8.0
const STRIPE := 6.0 ## liseré à la teinte d'équipe, bord gauche
const UPDATE_HZ := 10.0
const COL_BG := Color(0.035, 0.03, 0.028, 0.72)
const COL_TEXT := Color(0.95, 0.93, 0.88)
const COL_DIM := Color(0.62, 0.6, 0.56)
const COL_ABSENT := Color(0.55, 0.55, 0.55)
const COL_GOLD := Color(1.0, 0.82, 0.38)
const CORE_ICON := "res://assets/sprites/icons/storm_core.png"
const COL_VEIL := Color(0.0, 0.0, 0.0, 0.62)

var ui_scale := 1.0
## Plaques posées au dernier dessin (tests) : [{slot, rect, spectator, absent}].
var plates: Array[Dictionary] = []

var _font: Font = ThemeDB.fallback_font
var _icons := {} ## spell id -> Texture2D (ou null)
var _gold_tex: Texture2D = null
var _core_tex: Texture2D = null
## Compteur de noyaux d'orage dessiné par joueur (id -> Rect2) ; absent à 0 noyau (tests).
var core_rects := {}
var _acc := 0.0


func _init() -> void:
	name = "CoopPlates"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var f := get_theme_font(&"font", &"Label")
	if f != null:
		_font = f
	if ResourceLoader.exists(Minimap.UI_DIR + "icon_gold.png"):
		_gold_tex = Minimap.ui_texture("icon_gold.png")
	if ResourceLoader.exists(CORE_ICON):
		_core_tex = load(CORE_ICON) as Texture2D


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < 1.0 / UPDATE_HZ:
		return
	_acc = 0.0
	queue_redraw()


# --- Disposition ----------------------------------------------------------------------

## Rectangles des plaques (px écran) pour `n` joueurs dans un écran `vp`, à l'échelle `s` ; zone sûre `safe`.
static func layout(n: int, vp: Vector2, s: float, safe: Dictionary = {}) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if n <= 0:
		return out
	var left := EDGE * s + float(safe.get("left", 0.0))
	var right := vp.x - EDGE * s - float(safe.get("right", 0.0))
	var bottom := vp.y - EDGE * s - float(safe.get("bottom", 0.0))
	var h := H * s
	var gap := GAP * s
	var per_side := 2 if n >= 3 else 1
	var free := right - left - CENTER_FREE * s - gap * float(2 * (per_side - 1))
	var w := minf(W * s, free / float(per_side * 2))
	var stacked := w < MIN_W * s
	if stacked:
		w = minf(W * s, (right - left - CENTER_FREE * s) * 0.5)
	var n_left := n - n / 2 # 1 -> 1, 2 -> 1, 3 -> 2, 4 -> 2
	for i in n:
		var on_left := i < n_left
		var k := i if on_left else i - n_left # rang dans son groupe
		var count := n_left if on_left else n - n_left
		var x := 0.0
		var y := bottom - h
		if stacked:
			x = left if on_left else right - w
			y = bottom - h - float(count - 1 - k) * (h + gap)
		elif on_left:
			x = left + float(k) * (w + gap)
		else:
			x = right - float(count - k) * w - float(count - 1 - k) * gap
		out.append(Rect2(Vector2(x, y), Vector2(w, h)))
	return out


## Haut de la rangée de plaques (px écran) : l'invite d'interaction et les objectifs restent au-dessus.
func top_y() -> float:
	var r := layout(Players.count(), get_viewport_rect().size, ui_scale, Platform.safe_margins())
	var y := get_viewport_rect().size.y
	for rect in r:
		y = minf(y, rect.position.y)
	return y


# --- Dessin ---------------------------------------------------------------------------

func _draw() -> void:
	plates.clear()
	var entries := Players.entries()
	if entries.is_empty():
		return
	var s := ui_scale
	var rects := layout(entries.size(), get_viewport_rect().size, s, Platform.safe_margins())
	for i in entries.size():
		_draw_plate(entries[i], rects[i], s)
	_draw_prompts(s)


func _draw_plate(e, r: Rect2, s: float) -> void: # e : Players.Entry (classe interne de l'autoload)
	var node: Node2D = e.node if is_instance_valid(e.node) else null
	var st: PlayerState = e.state
	var spectator: bool = (st != null and st.spectating) or (node != null and node.get(&"dead") == true)
	var absent: bool = e.input is InputSourceIdle
	var tint: Color = Palette.team_color(e.id)
	# Spectateur : seuls le cadre, le liseré et les icônes s'atténuent ; fond et texte restent pleins (contraste >= 4,5:1,
	# audit UX 07/11 P3).
	var a := 0.6 if spectator else 1.0
	var low_hp := false
	if not absent and not spectator and node != null and "hp" in node and "max_hp" in node:
		low_hp = float(node.get(&"hp")) / maxf(float(node.get(&"max_hp")), 1.0) <= HpBarStyle.LOW_HP_FRAC
	draw_rect(r, COL_BG)
	draw_rect(Rect2(r.position, Vector2(STRIPE * s, r.size.y)), Color(tint, a))
	var border_w := maxf(2.0, 2.0 * s)
	var border_a := 0.9 * a
	if low_hp: # PV bas : cadre épais qui pulse à 1 Hz (fixe et épais si « Réduire les mouvements »), pas que la couleur
		border_w = maxf(4.0, 4.0 * s)
		border_a = 1.0 if GameSettings.reduce_motion() else lerpf(0.45, 1.0, 0.5 + 0.5 * sin(Time.get_ticks_msec() * TAU / 1000.0))
	draw_rect(r, Color(Palette.hp_low() if low_hp else (COL_ABSENT if absent else tint), border_a), false, border_w)
	var x0 := r.position.x + (STRIPE + PAD) * s
	var inner_w := r.end.x - PAD * s - x0
	var y := r.position.y + PAD * s
	# ligne 1 : pastille numérotée, nom, niveau, appareil | or
	var pill := 28.0 * s
	draw_rect(Rect2(Vector2(x0, y), Vector2(pill, pill)), Color(tint, a))
	var fs_glyph := maxi(int(20 * s), 14)
	_text(Vector2(x0 + pill * 0.5, y + pill * 0.5), Palette.team_glyph(e.id), fs_glyph, Color(0.05, 0.05, 0.05, a), true)
	var fs1 := HudMetrics.font(HudMetrics.T4_SMALL, s, false)
	var cname := ""
	if node != null and "character" in node and node.get(&"character") != null:
		cname = str((node.get(&"character") as CharacterData).display_name)
	if cname == "" and st != null:
		cname = String(st.character).capitalize()
	var lvl: int = st.level if st != null else 1
	var line1 := "%s · Niv. %d · %s" % [cname, lvl, _device_label(e.input)]
	var gold_txt := str(int(st.gold)) if st != null else "0"
	var fs_gold := maxi(int(22 * s), HudMetrics.floor_px(false))
	var gold_w := _font.get_string_size(gold_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_gold).x
	var gold_x := r.end.x - PAD * s - gold_w
	_text(Vector2(gold_x, y + pill * 0.5), gold_txt, fs_gold, Color(COL_GOLD, a))
	if _gold_tex != null:
		var gs := 24.0 * s
		draw_texture_rect(_gold_tex, Rect2(Vector2(gold_x - gs - 4.0 * s, y + (pill - gs) * 0.5), Vector2(gs, gs)), false, Color(1, 1, 1, a))
		gold_x -= gs + 4.0 * s
	# noyaux d'orage portés : icône + « 1/2 » à gauche de l'or, seulement s'il y en a au moins un
	var cores: int = st.catalysts if st != null else 0
	if cores >= 1:
		var core_txt := "%d/%d" % [cores, Balance.CRAFT_CATALYST_CAP]
		var core_w := _font.get_string_size(core_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_gold).x
		gold_x -= 14.0 * s + core_w
		var core_x := gold_x
		_text(Vector2(gold_x, y + pill * 0.5), core_txt, fs_gold, Color(0.62, 0.86, 1.0, a))
		if _core_tex != null:
			var cs := 24.0 * s
			draw_texture_rect(_core_tex, Rect2(Vector2(gold_x - cs - 4.0 * s, y + (pill - cs) * 0.5), Vector2(cs, cs)), false, Color(1, 1, 1, a))
			gold_x -= cs + 4.0 * s
		core_rects[e.id] = Rect2(Vector2(gold_x, y), Vector2(core_x + core_w - gold_x, pill))
	else:
		core_rects.erase(e.id)
	var name_w := maxf(gold_x - (x0 + pill + 8.0 * s) - 8.0 * s, 20.0)
	_text_clip(Vector2(x0 + pill + 8.0 * s, y + pill * 0.5), line1, fs1, COL_TEXT, name_w)
	y += pill + 6.0 * s
	# ligne 2 : PV (ou état)
	var bar_h := 26.0 * s
	var bar := Rect2(Vector2(x0, y), Vector2(inner_w, bar_h))
	if absent:
		var off_x := x0
		var off_tex := KeyPrompt.icon("device_gamepad_off")
		if off_tex != null: # UX-A : manette barrée (le texte reste le signal principal)
			var isz := bar_h * 1.3
			draw_texture_rect(off_tex, Rect2(Vector2(x0, y + bar_h * 0.5 - isz * 0.5), Vector2(isz, isz)), false, Color(1, 1, 1, a))
			off_x += isz + 6.0 * s
		_text_clip(Vector2(off_x, y + bar_h * 0.5), "Manette déconnectée", fs1, COL_TEXT, inner_w - (off_x - x0))
	elif spectator:
		_text_clip(Vector2(x0, y + bar_h * 0.5), "Spectateur · retour à l'étage suivant", fs1, COL_TEXT, inner_w)
	elif node != null:
		var hp := float(node.get(&"hp")) if "hp" in node else 0.0
		var mx := maxf(float(node.get(&"max_hp")) if "max_hp" in node else 1.0, 1.0)
		var frac := clampf(hp / mx, 0.0, 1.0)
		draw_rect(bar, Color(HpBarStyle.COL_BG, 0.92))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Palette.hp() if frac > HpBarStyle.LOW_HP_FRAC else Palette.hp_low())
		_text(bar.get_center(), ("! " if low_hp else "") + "%d / %d" % [ceili(hp), ceili(mx)], HudMetrics.font(HudMetrics.T1_HP, s, false), COL_TEXT, true, 4)
	y += bar_h + 6.0 * s
	# ligne 3 : sorts 1-4
	if node == null or spectator or not node.has_method(&"get_spell_cooldowns"):
		plates.append({"slot": e.id, "rect": r, "spectator": spectator, "absent": absent, "low_hp": low_hp})
		return
	var isz := minf(ICON * s, r.end.y - PAD * s - y)
	var cx := x0
	var fs_cd := maxi(int(24 * s), HudMetrics.floor_px(false))
	for c: Dictionary in node.get_spell_cooldowns():
		var ir := Rect2(Vector2(cx, y), Vector2(isz, isz))
		var tex := _icon(StringName(str(c.get("id", ""))))
		draw_rect(ir, Color(SpellButton.ICON_UNDERLAY, 0.35))
		if tex != null:
			draw_texture_rect(tex, ir, false, Color(1, 1, 1, 0.55 if absent else 1.0))
		else:
			_text(ir.get_center(), str(c.get("name", "?")).left(1), fs_cd, COL_TEXT, true)
		var rem := float(c.get("remaining", 0.0))
		var tot := float(c.get("total", 0.0))
		var auto := bool(c.get("auto", false))
		if not auto and rem > 0.0 and tot > 0.0:
			var k := clampf(rem / tot, 0.0, 1.0)
			draw_rect(Rect2(ir.position, Vector2(ir.size.x, ir.size.y * k)), COL_VEIL)
			_text(ir.get_center(), str(ceili(rem)) if rem >= 1.0 else "%.1f" % rem, fs_cd, COL_TEXT, true, 4)
		elif auto:
			_text(Vector2(ir.get_center().x, ir.end.y - 10.0 * s), "AUTO", HudMetrics.font(HudMetrics.T4_SMALL, s * 0.8, false), COL_TEXT, true, 3)
		draw_rect(ir, Color(tint, 0.5) if not auto else Color(COL_DIM, 0.5), false, 1.5)
		cx += isz + 8.0 * s
		if cx + isz > r.end.x - PAD * s:
			break
	plates.append({"slot": e.id, "rect": r, "spectator": spectator, "absent": absent, "low_hp": low_hp})


## Invites d'interaction des joueurs 2-4 au-dessus de leur tête : « 2 · A Ouvrir ».
func _draw_prompts(s: float) -> void:
	var xf := get_viewport().get_canvas_transform()
	var local_id := Players.local_id()
	var fs := HudMetrics.font(HudMetrics.T5_BADGE, s, false)
	for e in Players.entries():
		if e.id == local_id or not is_instance_valid(e.node) or e.state.spectating:
			continue
		var pi: Variant = e.node.get(&"interaction")
		if pi == null or not (pi is PlayerInteract):
			continue
		var it := pi as PlayerInteract
		if it.target == null or not is_instance_valid(it.target) or not bool(it.state.get("visible", true)):
			continue
		var label := str(it.state.get("label", "Interagir"))
		var txt := "%s · %s" % [Palette.team_glyph(e.id), label]
		var head: Vector2 = xf * (e.node.global_position + OverheadBars.head_offset(e.node))
		var sz := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		# touche : invite existante (pad_a, ou key_1x1 « E » au clavier), sinon la lettre en texte
		var key := _interact_key(e.input)
		var ktex := _key_tex(e.input)
		var isz := maxf(sz.y * 1.5, 28.0 * s) if ktex != null else 0.0
		var kw := isz + 6.0 * s if ktex != null else 0.0
		if ktex == null:
			txt = "%s · %s %s" % [Palette.team_glyph(e.id), key, label]
			sz = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var bh := maxf(sz.y, isz) + 8.0 * s
		var box := Rect2(Vector2(head.x - (sz.x + kw) * 0.5 - 8.0 * s, head.y - 34.0 * s - bh), Vector2(sz.x + kw + 16.0 * s, bh))
		draw_rect(box, COL_BG)
		draw_rect(box, Palette.team_color(e.id), false, 2.0)
		var tx := box.position.x + 8.0 * s
		if ktex != null:
			var kr := Rect2(Vector2(tx, box.get_center().y - isz * 0.5), Vector2(isz, isz))
			draw_texture_rect(ktex, kr, false)
			if e.input.kind == InputSource.Kind.KBM:
				_text(kr.get_center(), key, maxi(int(isz * 0.42), 12), Color(0.1, 0.1, 0.12), true)
			tx += kw
		_text(Vector2(tx, box.get_center().y), txt, fs, COL_TEXT)


# --- Outils ---------------------------------------------------------------------------

func _icon(sid: StringName) -> Texture2D:
	if not _icons.has(sid):
		_icons[sid] = ArdentKit.spell_icon(sid) if sid != &"" else null
	return _icons[sid]


static func _device_label(src: InputSource) -> String:
	if src == null:
		return ""
	if src is InputSourceIdle:
		return "manette ?"
	match src.kind:
		InputSource.Kind.KBM:
			return "clavier"
		InputSource.Kind.PAD:
			return "manette"
	return ""


## Invite de la touche d'interaction (assets ui/prompts) : pad_a à la manette, key_1x1 au clavier ; null si absente.
static func _key_tex(src: InputSource) -> Texture2D:
	return KeyPrompt._tex("key_1x1" if src != null and src.kind == InputSource.Kind.KBM else "pad_a")


static func _interact_key(src: InputSource) -> String:
	return "E" if src != null and src.kind == InputSource.Kind.KBM else "A"


## Texte centré (ou aligné à gauche, centré verticalement), contour noir.
func _text(at: Vector2, txt: String, fs: int, col: Color, center := false, outline := 0) -> void:
	var p := at
	if center:
		p.x -= _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	p.y += (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	if outline > 0:
		draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0, 0, 0, 0.85 * col.a))
	draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Texte à gauche coupé à `max_w` px (points de suspension).
func _text_clip(at: Vector2, txt: String, fs: int, col: Color, max_w: float) -> void:
	var p := at
	p.y += (_font.get_ascent(fs) - _font.get_descent(fs)) * 0.5
	draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, max_w, fs, col, TextServer.JUSTIFICATION_NONE)
