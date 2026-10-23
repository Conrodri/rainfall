extends Node
## Lisibilité des télégraphes rouges et de la rive de l'eau (audit A-04 / A-10, lot L2).
## godot --headless --path game res://tests/telegraph_contrast_test.tscn  -> RESULT: OK
## Calcule les contrastes WCAG à partir des constantes (EnemyTelegraph, AmbianceWater, StageMap), en vision
## normale et en protanopie (matrice de Machado 2009, sévérité 1,0, appliquée en RGB linéaire), sur une grille
## de sols (gris de 0 à 1 + teintes des 4 biomes). Règle : le double liseré atteint 3:1 sur tous les sols.

const MIN := 3.0
## Sols types (couleur de rendu approximative des 4 biomes, claire et sombre) en plus de la grille de gris.
const GROUNDS := [Color(0.18, 0.20, 0.14), Color(0.55, 0.62, 0.40), Color(0.42, 0.40, 0.38), Color(0.75, 0.70, 0.58),
	Color(0.10, 0.12, 0.16), Color(0.30, 0.22, 0.16), Color(0.85, 0.85, 0.80), Color(0.05, 0.06, 0.05)]

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


## Luminance relative après simulation de protanopie (0 = vision normale).
static func _lum(c: Color, protan: bool) -> float:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	if protan:
		var r2 := 0.152286 * r + 1.052583 * g - 0.204868 * b
		var g2 := 0.114503 * r + 0.786281 * g + 0.099216 * b
		var b2 := -0.003882 * r - 0.048116 * g + 1.051998 * b
		r = clampf(r2, 0.0, 1.0)
		g = clampf(g2, 0.0, 1.0)
		b = clampf(b2, 0.0, 1.0)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


static func _cr(a: Color, b: Color, protan: bool) -> float:
	var la := _lum(a, protan)
	var lb := _lum(b, protan)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _run() -> void:
	print("telegraph_contrast_test")
	var grounds: Array = GROUNDS.duplicate()
	for i in 41:
		var v := float(i) / 40.0
		grounds.append(Color(v, v, v))
	var inner := EnemyTelegraph.EDGE_INNER
	var outer := EnemyTelegraph.EDGE_OUTER
	_check("remplissage à 0,28", is_equal_approx(EnemyTelegraph.FILL.a, 0.28))
	_check("liseré clair opaque, 2 px ; sombre opaque, plus large", inner.a == 1.0 and outer.a == 1.0
		and EnemyTelegraph.EDGE_INNER_PX >= 2.0 and EnemyTelegraph.EDGE_OUTER_PX >= EnemyTelegraph.EDGE_INNER_PX + 2.0)
	_check("la fonction du jeu et le test calculent le même contraste",
		absf(EnemyTelegraph.contrast(inner, outer) - _cr(inner, outer, false)) < 0.001)
	for protan in [false, true]:
		var mode := "protanopie" if protan else "vision normale"
		_check("liseré clair / sombre : >= 4,5:1 entre eux (%s)" % mode, _cr(inner, outer, protan) >= 4.5,
			"%.2f" % _cr(inner, outer, protan))
		var worst := 99.0
		var worst_g := Color.BLACK
		for g: Color in grounds:
			var best := maxf(_cr(inner, g, protan), _cr(outer, g, protan))
			if best < worst:
				worst = best
				worst_g = g
		_check("double liseré >= %.1f:1 sur %d sols (%s), pire %.2f" % [MIN, grounds.size(), mode, worst],
			worst >= MIN, "sol " + str(worst_g))
		# rive de l'eau : écume contre l'eau profonde, encre contre le sol clair, écume contre l'encre
		var water := AmbianceWater.DEEP_TINT
		_check("rive : écume / eau profonde >= 3:1 (%s)" % mode, _cr(StageMap.BANK_FOAM, water, protan) >= MIN,
			"%.2f" % _cr(StageMap.BANK_FOAM, water, protan))
		_check("rive : écume / encre >= 3:1 (%s)" % mode, _cr(StageMap.BANK_FOAM, StageMap.BANK_INK, protan) >= MIN)
	# Anneau : le télégraphe exposé progresse par paliers et son anneau apparaît, sans redessin par image
	var t := EnemyTelegraph.new()
	add_child(t)
	await get_tree().process_frame
	t.show_circle(Vector2(100, 100), 120.0)
	t.set_progress(0.0)
	_check("anneau caché à 0", not t._ring.visible)
	t.set_progress(0.5)
	_check("anneau visible à 0,5", t._ring.visible)
	var step: int = t._ring_step
	t.set_progress(0.5 + 0.2 / EnemyTelegraph.RING_STEPS)
	_check("pas de redessin dans le même palier", t._ring_step == step)
	t.set_progress(1.0)
	_check("anneau au bord à 1", t._ring_step == int(EnemyTelegraph.RING_STEPS))
	t.hide_telegraph()
	t.queue_free()
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
