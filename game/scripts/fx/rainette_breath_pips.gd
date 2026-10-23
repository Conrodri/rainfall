class_name RainetteBreathPips
extends Node2D
## Souffle de Rainette lisible sans HUD (placeholder : 6 pastilles au sol devant ses pieds, en attendant une
## jauge de ressource HUD générique S8 ou une pastille rendue par Codex). Repère logique du joueur : l'arc
## devient une demi-ellipse iso. Pleine et immobile : s'efface ; essoufflée : clignote ; Chant de crue : luit.

const ARC_RADIUS_U := 0.62
const ARC_FROM_DEG := 30.0
const ARC_TO_DEG := 150.0
const PIP_RADIUS_PX := 4.5 ## audit HUD lot C : plus grosses, contour clair (>= 3:1 plein / vide)
const MOBILE_K := 1.25
const EDGE := Color("#E8E2D6")
const HIDE_AFTER_S := 0.8
const FADE_S := 0.3

var kit: RainetteKit = null
var _full_t := 0.0
var _gulp := 0.0


func _ready() -> void:
	z_index = -1


func gulp() -> void:
	_gulp = 0.35


func _process(delta: float) -> void:
	if kit == null or kit.player == null:
		return
	_gulp = maxf(_gulp - delta, 0.0)
	var full := kit.breath >= float(RainetteKit.BREATH_MAX) and not kit.is_breathless() and not kit.is_singing() and kit._warn_left <= 0.0
	_full_t = _full_t + delta if full else 0.0
	modulate.a = 1.0 - clampf((_full_t - HIDE_AFTER_S) / FADE_S, 0.0, 1.0)
	visible = modulate.a > 0.01 and not kit.player.dead
	if visible:
		queue_redraw()


func _draw() -> void:
	if kit == null:
		return
	var acc := RainetteKit.ACCENT
	var n := RainetteKit.BREATH_MAX
	var r := ARC_RADIUS_U * Balance.UNIT_PX
	var blink := (kit.is_breathless() or kit._warn_left > 0.0) and int(Time.get_ticks_msec() / 120) % 2 == 0
	var glow := 1.6 if kit.is_singing() or _gulp > 0.0 else 0.9
	for i in n:
		var a := deg_to_rad(lerpf(ARC_FROM_DEG, ARC_TO_DEG, float(i) / float(n - 1)))
		var p := Vector2.from_angle(a) * r
		var on := kit.is_singing() or float(i) < kit.breath - 0.001
		var pr := PIP_RADIUS_PX * (MOBILE_K if Platform.is_mobile() else 1.0)
		var c := Color(minf(acc.r * glow, 1.0), minf(acc.g * glow, 1.0), minf(acc.b * glow, 1.0), 0.95) if on else Color(0.04, 0.05, 0.05, 0.7)
		c = ResourceGauge.lift(c, Color(0.1, 0.1, 0.1)) if on else c
		if blink:
			c = Color(0.6, 0.2, 0.18, 0.8)
		elif not on and float(i) < kit.breath + 1.0 - 0.001 and kit.breath < float(n) and not kit.is_singing():
			# prochaine pastille : arc de progression (régénération, ou reprise de souffle) sur son contour
			var prog: float = kit._regen_progress()
			draw_arc(p, pr + 3.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 12, Color(acc, 0.95), 2.0)
		draw_circle(p, pr + 1.5, Color(0, 0, 0, 0.8)) # ombre de lisibilité sur le sol
		draw_circle(p, pr, c)
		if on: # pleine : liseré clair continu
			draw_arc(p, pr, 0.0, TAU, 16, Color(EDGE, 0.9), 1.5)
		else: # vide : contour pointillé (la forme, pas la couleur, dit « vide »)
			for j in 6:
				var a0 := TAU * j / 6.0
				draw_arc(p, pr, a0, a0 + TAU / 12.0, 4, Color(EDGE, 0.8), 1.5)
