class_name HpBarStyle
extends RefCounted
## Réglages partagés des barres de PV (monde : EnemyHealthBars ; HUD : BossHealthBar) et chargement des
## assets Blender (lot Codex HB1, art/tools/night/_hb1.txt) avec repli en formes de code.
## Valeurs : docs/HP_Bars_Recherche.md (§2 ressenti, §3 phases, §4 statuts, §5 palette Rainfall).
## Contrat : game/CONTRACTS.md « Barres de PV ».

const ART_DIR := "res://assets/sprites/ui/hp_bars/"

# --- Ressenti des coups (recherche §2 / §5 « Timings »)
const GHOST_HOLD_S := 0.40 ## la portion perdue reste affichée avant le rattrapage ; chaque coup relance
const GHOST_DRAIN_S := 0.30 ## durée visée du rattrapage (plafonnée, voir ghost_step)
const GHOST_MIN_RATE := 0.6 ## vitesse plancher (fraction de barre / s)
const GHOST_WHITE_S := 0.10 ## ghost blanc cassé puis rouge pâle
## Flash court et partiel (retour joueur : jamais de blanc qui écrase les décors sombres) : bord du
## remplissage seulement, alpha <= FLASH_ALPHA, <= 80 ms.
const FLASH_S := 0.08
const FLASH_FULL_S := 0.03
const FLASH_ALPHA := 0.5
const FLASH_EDGE_PX := 6.0
const SHAKE_S := 0.14
const SHAKE_MIN_FRAC := 0.10 ## tremblement seulement si le coup retire >= 10 % des PV max (ou critique)
const SHAKE_CRIT_MULT := 1.5
const LOW_HP_FRAC := 0.25 ## pulsation sous 25 % (période 1,2 s), sous 10 % (0,7 s)
const CRIT_HP_FRAC := 0.10
const LOW_PULSE_S := 1.2
const CRIT_PULSE_S := 0.7
const LOW_PULSE_GAIN := 0.20 ## +20 % de luminosité au sommet
# --- Phases (recherche §3)
const BREAK_FLASH_S := 0.06 ## segment perdu à la rupture : ambre alpha 0,5 qui s'éteint en <= 0,3 s
const BREAK_FADE_S := 0.22
const BREAK_SHAKE_S := 0.30
const BREAK_SHAKE_PX := 6.0
const PHASE_SWEEP_S := 1.0 ## nouvelle teinte qui balaie la barre de gauche à droite après une rupture
const APPEAR_S := 0.5 ## barre de boss qui se déploie du centre

# --- Palette (recherche §5) : un seul accent émissif (braise)
const COL_BG := Color("#0B0907", 0.75)
const COL_FRAME := Color("#4A423C")
const COL_FRAME_DARK := Color("#2A2623")
const COL_OUTLINE := Color(0, 0, 0, 0.9)
const COL_FILL := Color("#B8321E") ## vie ennemie : rouille / braise
const COL_FILL_LOW := Color("#7A1F12") ## bas du dégradé
## Barre retard : ambre / rouille désaturés, luminance < remplissage + 30 % (jamais crème ni blanc)
const COL_GHOST_HIT := Color("#9A5A36")
const COL_GHOST := Color("#7E4630")
const COL_GLINT := Color("#D89A5C") ## éclat de bord ambre (pas de blanc)
## Remplissage du boss par phase (de plus en plus chaud, toujours la même braise)
const COL_PHASE: Array[Color] = [Color("#B8321E"), Color("#D2461C"), Color("#EE6422")]
const COL_MINI := Color("#A33A2A")
const COL_TRANSITION := Color(0.40, 0.38, 0.36) ## transition : gris acier sombre (distinct du ghost clair)

## Statuts : une couleur unique et constante chacun ; brûlure = l'accent, les autres en tons ternes.
const STATUS_ORDER: Array[StringName] = [&"burn", &"poison", &"frost", &"stun", &"imprisoned"]
const STATUS_COL := {
	&"burn": Color("#F07A2A"),
	&"poison": Color("#8DAA3C"),
	&"frost": Color("#9CC3D2"),
	&"stun": Color("#D8C47A"),
	&"imprisoned": Color("#9A948C"),
}
## Bits Enemy.ST_* -> id (même ordre que STATUS_ORDER)
const STATUS_BITS: Array[int] = [1, 2, 4, 8, 16]

static var _tex_cache := {}


## Texture d'UI des barres (`<ART_DIR><name>.png`) ou null si le lot HB1 n'est pas livré (repli en code).
static func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var p := ART_DIR + name + ".png"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex_cache[name] = t
	return t


## Tests : oublie le cache (assets livrés pendant la session).
static func clear_cache() -> void:
	_tex_cache.clear()


static func status_color(id: StringName) -> Color:
	return CvdPalette.status(id) # palette selon le mode daltonien (lecture seule du réglage) ; STATUS_COL = mode « aucun »


## Statut dominant d'un masque Enemy.ST_* (teinte de la barre de monde) : emprisonné > étourdi > gel >
## brûlure > poison ; &"" si aucun.
static func dominant(mask: int) -> StringName:
	if mask & 16:
		return &"imprisoned"
	if mask & 8:
		return &"stun"
	if mask & 4:
		return &"frost"
	if mask & 1:
		return &"burn"
	if mask & 2:
		return &"poison"
	return &""


## Pas du ghost (fraction) vers `frac` : maintien `hold` (géré par l'appelant), puis rattrapage en
## ~GHOST_DRAIN_S, jamais plus lent que GHOST_MIN_RATE. Un soin le remonte immédiatement.
static func ghost_step(ghost: float, frac: float, delta: float) -> float:
	if ghost <= frac:
		return frac
	var rate := maxf((ghost - frac) / GHOST_DRAIN_S * 1.6, GHOST_MIN_RATE)
	return maxf(frac, ghost - rate * delta)


## Gain de luminosité de la pulsation PV bas (0 au-dessus de LOW_HP_FRAC).
static func low_pulse(frac: float, clock: float) -> float:
	if frac > LOW_HP_FRAC or frac <= 0.0:
		return 0.0
	if GameSettings.reduce_motion():
		return LOW_PULSE_GAIN * 0.5 # pulsation fixe (pas de battement)
	var period := CRIT_PULSE_S if frac <= CRIT_HP_FRAC else LOW_PULSE_S
	return LOW_PULSE_GAIN * (0.5 - 0.5 * cos(TAU * clock / period))


## Icône de statut (rangée sous la barre) : fond fer sombre, anneau de durée restante `frac` (0-1, part
## de l'anneau encore pleine, depuis midi dans le sens horaire), glyphe (asset `status_<id>` sinon forme de
## code), chiffre de stacks en bas à droite si > 1. `size` = diamètre (px), `a` = opacité.
static func draw_status_icon(ci: CanvasItem, id: StringName, c: Vector2, size: float, frac: float, stacks: int,
		font: Font, font_size: int, a := 1.0) -> void:
	var r := size * 0.5
	var col := status_color(id)
	ci.draw_circle(c, r + 1.0, Color(0, 0, 0, 0.9 * a))
	ci.draw_circle(c, r, Color(COL_FRAME_DARK, a))
	var ring_w := maxf(size * 0.13, 1.5)
	ci.draw_arc(c, r - ring_w * 0.5, 0.0, TAU, 24, Color(0, 0, 0, 0.6 * a), ring_w, true)
	if frac > 0.01:
		ci.draw_arc(c, r - ring_w * 0.5, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(int(24 * frac), 3), Color(col, a), ring_w, true)
	var t := tex("status_" + String(id))
	if t != null:
		var gs := size * 0.72
		ci.draw_texture_rect(t, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, a))
	else:
		draw_status_glyph(ci, id, c, r * 0.62, Color(col, a))
	if stacks > 1 and font != null:
		var txt := str(stacks)
		var pos := c + Vector2(r * 0.25, r + font_size * 0.35)
		ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(font_size / 4, 2), Color(0, 0, 0, a))
		ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.96, 0.9, a))


## Glyphe de repli (formes simples, placeholder en attendant les icônes HB1) : flamme, goutte, flocon,
## étoile, grille.
static func draw_status_glyph(ci: CanvasItem, id: StringName, c: Vector2, r: float, col: Color) -> void:
	match id:
		&"burn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r * 0.75, r * 0.2),
				c + Vector2(r * 0.45, r * 0.85), c + Vector2(-r * 0.45, r * 0.85), c + Vector2(-r * 0.75, r * 0.2)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.2), c + Vector2(r * 0.3, r * 0.45),
				c + Vector2(0, r * 0.8), c + Vector2(-r * 0.3, r * 0.45)]), Color(1, 0.9, 0.6, col.a))
		&"poison":
			ci.draw_circle(c + Vector2(0, r * 0.3), r * 0.62, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 0.58, r * 0.1),
				c + Vector2(-r * 0.58, r * 0.1)]), col)
		&"frost":
			var w := maxf(r * 0.28, 1.0)
			for k in 3:
				var d := Vector2.from_angle(PI * 0.5 + k * PI / 3.0) * r
				ci.draw_line(c - d, c + d, col, w)
		&"stun":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28), c + Vector2(r, 0),
				c + Vector2(r * 0.28, r * 0.28), c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28), c + Vector2(-r, 0),
				c + Vector2(-r * 0.28, -r * 0.28)]), col)
		&"imprisoned":
			var w2 := maxf(r * 0.26, 1.0)
			for k in 3:
				var x := (k - 1) * r * 0.62
				ci.draw_line(c + Vector2(x, -r), c + Vector2(x, r), col, w2)
			ci.draw_line(c + Vector2(-r, -r * 0.35), c + Vector2(r, -r * 0.35), col, w2)
		_:
			ci.draw_circle(c, r * 0.6, col)


## Dessin 9-patch de `t` dans `r`, marges source `m` (px) mises à l'échelle k, modulé par `mod`.
static func nine_patch(ci: CanvasItem, t: Texture2D, r: Rect2, m: Vector2, k: float, mod := Color.WHITE) -> void:
	var ts := t.get_size()
	var dm := m * k
	var xs := [r.position.x, r.position.x + dm.x, r.end.x - dm.x, r.end.x]
	var ys := [r.position.y, r.position.y + dm.y, r.end.y - dm.y, r.end.y]
	var us := [0.0, m.x, ts.x - m.x, ts.x]
	var vs := [0.0, m.y, ts.y - m.y, ts.y]
	for yi in 3:
		for xi in 3:
			var dst := Rect2(xs[xi], ys[yi], xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi])
			var src := Rect2(us[xi], vs[yi], us[xi + 1] - us[xi], vs[yi + 1] - vs[yi])
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				ci.draw_texture_rect_region(t, dst, src, mod)


## Éclaircit une couleur (pulsation) : c × (1 + g), alpha gardé.
static func brighten(c: Color, g: float) -> Color:
	return Color(minf(c.r * (1.0 + g) + g * 0.15, 1.0), minf(c.g * (1.0 + g) + g * 0.1, 1.0), minf(c.b * (1.0 + g) + g * 0.1, 1.0), c.a)
