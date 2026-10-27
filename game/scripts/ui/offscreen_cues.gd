extends Control
## Indicateurs de menace hors écran (audit A-12, lot A11y-L9) : flèches au bord de l'écran vers les boss, mini-boss,
## élites et télégraphes ennemis dont le centre est hors champ. Indice VISUEL des sons porteurs d'information
## (sorts de boss, élites) pour les joueurs sourds / sans son.
## Au plus MAX_CUES flèches de CUE_PX (48 px × échelle du HUD), priorité boss > télégraphe > élite puis distance.
## Les flèches évitent Hud.reserved_rects() (glissées le long du bord, sinon rentrées vers le centre).
## Mise à jour à UPDATE_HZ (pas de redessin par image). Formes en code = PLACEHOLDER (brief Codex _uxl9.txt) :
## la forme porte le sens (boss = double chevron, télégraphe = pastille rouge à double liseré + pointe, élite = chevron simple).
## Chargé par preload (pas de class_name) : `preload("res://scripts/ui/offscreen_cues.gd").new()` puis bind(hud).

const MAX_CUES := 6
const CUE_PX := 48.0
const CUE_PX_MOBILE := 64.0 ## téléphone : même taille physique lisible que les pictos du HUD tactile
const MARGIN_PX := 12.0 ## retrait depuis le bord de l'écran (en plus de la demi-taille de la flèche)
const UPDATE_HZ := 10.0
const SLIDE_STEP_PX := 16.0
const SLIDE_STEPS := 60
const EDGE_DARK := Color(0.04, 0.02, 0.02, 1.0)
const COL_BOSS := Color(1.0, 0.32, 0.22, 1.0)
const COL_TELE := Color(1.0, 0.886, 0.784, 1.0) ## même liseré clair que les télégraphes (#FFE2C8)
const COL_ELITE := Color(1.0, 0.78, 0.30, 1.0)

enum Kind { BOSS, TELEGRAPH, ELITE }

const TEX_DIR := "res://assets/sprites/ui/cues/"
const TEX_NAMES := {Kind.BOSS: "cue_boss.png", Kind.TELEGRAPH: "cue_telegraph.png", Kind.ELITE: "cue_elite.png"}
static var _tex: Dictionary = {}

var hud: Node = null ## Hud (reserved_rects) ; null = aucun évitement
var scale_override := -1.0 ## tests / captures
var cues: Array[Dictionary] = [] ## [{pos, angle, kind}] — lecture des tests
var _acc := 0.0


## Texture livrée par Codex (lot UXL9) ou null (placeholder dessiné en code).
static func cue_texture(kind: int) -> Texture2D:
	if not _tex.has(kind):
		var path: String = TEX_DIR + String(TEX_NAMES.get(kind, ""))
		_tex[kind] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex[kind]


func _ready() -> void:
	name = "OffscreenCues"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_PAUSABLE


func bind(h: Node) -> void:
	hud = h


func cue_px() -> float:
	if scale_override > 0.0:
		return CUE_PX * scale_override
	var vp := get_viewport_rect().size
	var base: float = HudMetrics.pick([CUE_PX, CUE_PX_MOBILE])
	return base * (HudMetrics.geometry_scale(vp) if vp.y > 0.0 else 1.0)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / UPDATE_HZ:
		return
	_acc = 0.0
	refresh()


## Recalcule les flèches (appelable directement par les tests).
func refresh() -> void:
	var screen := Rect2(Vector2.ZERO, size if size.x > 1.0 else get_viewport_rect().size)
	var targets := collect_targets(get_tree(), screen)
	var reserved: Array = []
	if hud != null and is_instance_valid(hud) and hud.has_method(&"reserved_rects"):
		reserved = hud.call(&"reserved_rects")
	var px := cue_px()
	cues.clear()
	var placed: Array[Rect2] = []
	for t: Dictionary in targets:
		if cues.size() >= MAX_CUES:
			break
		var p := place(screen, t["pos"], px, reserved, placed)
		var c := screen.get_center()
		cues.append({"pos": p, "angle": (t["pos"] - c).angle(), "kind": t["kind"]})
		placed.append(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)))
	queue_redraw()


## Cibles hors écran triées (boss, télégraphes, élites ; puis distance au centre). pos = position écran.
static func collect_targets(tree: SceneTree, screen: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tree == null:
		return out
	var c := screen.get_center()
	for n in tree.get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.active or not e.is_inside_tree() or not (e.is_boss or e.is_elite):
			continue
		var sp := e.get_global_transform_with_canvas().origin
		if screen.has_point(sp):
			continue
		out.append({"pos": sp, "kind": Kind.BOSS if e.is_boss else Kind.ELITE, "d": sp.distance_squared_to(c)})
	for n in tree.get_nodes_in_group(&"enemy_telegraphs"):
		var tg := n as EnemyTelegraph
		if tg == null or not tg.is_inside_tree() or not tg.is_showing():
			continue
		var sp2 := tg.get_global_transform_with_canvas().origin
		if screen.has_point(sp2):
			continue
		out.append({"pos": sp2, "kind": Kind.TELEGRAPH, "d": sp2.distance_squared_to(c)})
	for n in tree.get_nodes_in_group(&"raid_cues"): # objets de boss façon raid (RaidFx.CUE_GROUP) : points faibles, cloches, pylônes…
		var rc := n as Node2D
		if rc == null or not rc.is_inside_tree() or not rc.visible:
			continue
		var sp3 := rc.get_global_transform_with_canvas().origin
		if screen.has_point(sp3):
			continue
		out.append({"pos": sp3, "kind": Kind.TELEGRAPH, "d": sp3.distance_squared_to(c)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := _priority(a["kind"])
		var pb := _priority(b["kind"])
		return pa < pb if pa != pb else float(a["d"]) < float(b["d"]))
	return out


static func _priority(kind: int) -> int:
	match kind:
		Kind.BOSS:
			return 0
		Kind.TELEGRAPH:
			return 1
	return 2


## Position de la flèche : intersection centre -> cible avec le cadre intérieur, puis glissement le long du bord
## hors des zones réservées du HUD et des flèches déjà posées ; à défaut, rentrée vers le centre.
static func place(screen: Rect2, target: Vector2, px: float, reserved: Array, placed: Array = []) -> Vector2:
	var inner := screen.grow(-(px * 0.5 + MARGIN_PX))
	var c := inner.get_center()
	var d := target - c
	if d.length_squared() < 1.0:
		d = Vector2.RIGHT
	var tx := INF if is_zero_approx(d.x) else (inner.size.x * 0.5) / absf(d.x)
	var ty := INF if is_zero_approx(d.y) else (inner.size.y * 0.5) / absf(d.y)
	var p := c + d * minf(tx, ty)
	if _free(p, px, reserved, placed):
		return p
	var horizontal_edge := ty <= tx # bord haut / bas : glisser en x
	var tangent := Vector2.RIGHT if horizontal_edge else Vector2.DOWN
	for i in range(1, SLIDE_STEPS + 1):
		for sgn: float in [1.0, -1.0]:
			var q := p + tangent * sgn * SLIDE_STEP_PX * i
			q = Vector2(clampf(q.x, inner.position.x, inner.end.x), clampf(q.y, inner.position.y, inner.end.y))
			if _free(q, px, reserved, placed):
				return q
	var inward := (c - p).normalized()
	for j in range(1, SLIDE_STEPS + 1):
		var r := p + inward * SLIDE_STEP_PX * j
		if _free(r, px, reserved, placed):
			return r
	return p


static func _free(p: Vector2, px: float, reserved: Array, placed: Array) -> bool:
	var box := Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px))
	for r: Rect2 in reserved:
		if r.intersects(box):
			return false
	for r2: Rect2 in placed:
		if r2.intersects(box):
			return false
	return true


func _draw() -> void:
	var px := cue_px()
	for cue: Dictionary in cues:
		draw_cue(self, cue["pos"], cue["angle"], cue["kind"], px)


## Flèche placeholder (pointe vers la cible). Contour sombre + remplissage clair : >= 3:1 sur tout fond.
## Télégraphe : pastille rouge à double liseré (même grammaire que la zone au sol) + pointe claire vers la cible.
static func draw_cue(ci: CanvasItem, pos: Vector2, angle: float, kind: int, px: float) -> void:
	var tex := cue_texture(kind)
	if tex != null: # asset Codex livré (cue_<sens>.png, orienté vers +X)
		ci.draw_set_transform(pos, angle, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-Vector2(px, px) * 0.5, Vector2(px, px)), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var h := px * 0.5
	var lw := maxf(2.0, px / 16.0)
	var xf := Transform2D(angle, pos)
	if kind == Kind.TELEGRAPH:
		var c := xf * Vector2(-h * 0.30, 0.0)
		var r := h * 0.55
		ci.draw_circle(c, r, Color(0.95, 0.10, 0.10, 1.0))
		ci.draw_arc(c, r, 0.0, TAU, 24, EDGE_DARK, lw * 2.0)
		ci.draw_arc(c, r, 0.0, TAU, 24, COL_TELE, lw * 0.75)
		_chevron(ci, xf, h, h * 0.40, 0.55, COL_TELE, lw)
		return
	var col := COL_BOSS if kind == Kind.BOSS else COL_ELITE
	_chevron(ci, xf, h, 0.0, 1.0, col, lw)
	if kind == Kind.BOSS:
		_chevron(ci, xf, h, -0.42 * px, 1.0, col, lw)


static func _chevron(ci: CanvasItem, xf: Transform2D, h: float, off: float, k: float, col: Color, lw: float) -> void:
	var pts := PackedVector2Array([Vector2(h * k + off, 0.0), Vector2(-h * 0.35 * k + off, -h * 0.85 * k),
		Vector2(-h * 0.05 * k + off, 0.0), Vector2(-h * 0.35 * k + off, h * 0.85 * k)])
	var poly := xf * pts
	var closed := poly.duplicate()
	closed.append(poly[0])
	ci.draw_colored_polygon(poly, col)
	ci.draw_polyline(closed, EDGE_DARK, lw)
