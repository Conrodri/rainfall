class_name HurtFeedback
extends CanvasLayer
## Vignette rouge des bords de l'écran quand le joueur est touché (retour joueur : coups reçus
## illisibles sur terrasses_noyees). Intensité proportionnelle aux dégâts (part des PV max), fondu en
## FADE_S. Texture rendue dans Blender par Codex : VIGNETTE_TEX (étirée plein écran). Si elle
## manque, simple voile rouge très léger plein écran (provisoire, aucun asset dessiné en code).
## Créée par le joueur (`HurtFeedback.ensure(player)`), une seule par joueur ; au-dessus de
## l'étalonnage et des flashs d'ambiance (couches 4-6), sous le HUD (10).

const VIGNETTE_TEX := "res://assets/sprites/ui/da/vignette_hit.png"
const LAYER_HURT := 7
const MIN_ALPHA := 0.2 ## petit coup : bords à peine teintés
const ALPHA_PER_HP_FRAC := 1.5 ## +0,15 d'opacité par tranche de 10 % des PV max perdus
const MAX_ALPHA := 0.6 ## plafond : le cadre rouge livré est épais (≈ 20 % de chaque bord), le centre doit rester lisible
const FADE_S := 0.45
const FALLBACK_COLOR := Color(0.85, 0.05, 0.05, 1.0)
const REDUCED_MAX_ALPHA := 0.25 ## flashs « Réduits » (A-07) : opacité plafonnée
const NONE_ALPHA := 0.2 ## flashs « Aucun » : cadre fixe, sans montée ni fondu progressif
const FALLBACK_ALPHA_MULT := 0.12 ## voile provisoire sans texture : très léger

var _rect: CanvasItem = null
var _alpha := 0.0
var _peak := 0.0
var _has_tex := false
var _fixed := false ## flashs « Aucun » : cadre fixe
var _hold_left := 0.0


## Retourne la vignette du joueur (créée au premier appel).
static func ensure(owner_node: Node) -> HurtFeedback:
	var hf := owner_node.get_node_or_null(^"HurtFeedback") as HurtFeedback
	if hf == null:
		hf = HurtFeedback.new()
		hf.name = &"HurtFeedback"
		owner_node.add_child(hf)
	return hf


func _ready() -> void:
	layer = LAYER_HURT
	var tex: Texture2D = null
	if ResourceLoader.exists(VIGNETTE_TEX):
		tex = load(VIGNETTE_TEX) as Texture2D
	_has_tex = tex != null
	if _has_tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		_rect = tr
	else:
		var cr := ColorRect.new()
		cr.color = FALLBACK_COLOR
		_rect = cr
	var c := _rect as Control
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)


## Coup reçu : `hp_frac` = dégâts / PV max. L'opacité ne baisse jamais d'un coup (on garde le max).
func pulse(hp_frac: float) -> void:
	var a := clampf(MIN_ALPHA + hp_frac * ALPHA_PER_HP_FRAC, 0.0, MAX_ALPHA)
	var fs := GameSettings.flash_scale()
	_fixed = fs <= 0.0
	if _fixed:
		a = NONE_ALPHA # contour fixe : même opacité quel que soit le coup, tenu FADE_S puis coupé net
	elif fs < 1.0:
		a = minf(a, REDUCED_MAX_ALPHA)
	_alpha = maxf(_alpha, a)
	_peak = maxf(_alpha, 0.001)
	_hold_left = FADE_S
	_apply()


## Opacité courante de la vignette [0, 1] (avant le facteur du voile provisoire ; tests).
func intensity() -> float:
	return _alpha


func has_texture() -> bool:
	return _has_tex


func _process(delta: float) -> void:
	if _alpha <= 0.0:
		return
	if _fixed:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_alpha = 0.0
	else:
		_alpha = maxf(_alpha - _peak * delta / FADE_S, 0.0)
	_apply()


func _apply() -> void:
	if _rect == null:
		return
	_rect.visible = _alpha > 0.0
	_rect.modulate.a = _alpha * (1.0 if _has_tex else FALLBACK_ALPHA_MULT)
