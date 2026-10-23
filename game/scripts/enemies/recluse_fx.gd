class_name RecluseFx
extends Node2D
## Formes dessinées PROVISOIRES des boss de l'étage 4 et de la Source (Reclus, Semeur de pluie) tant que
## leurs sprites Blender (Codex, art/tools/night/requests_bosses45.md) ne sont pas livrés : chaque usage
## essaie d'abord l'anim du .tres du boss et ne retombe ici qu'en son absence (CLAUDE.md : formes en code =
## placeholders temporaires). Toutes non éclairées (light_mask 0, matériau unshaded) : lisibles dans le noir
## des Cryptes, comme les télégraphes.
## Un seul nœud par effet, redessiné seulement quand un paramètre change (set_param).

enum Kind { RING, RING_TELE, DISC, BAND, WAVE, STREAK, COLUMN, BEAM, BODY_RECLUSE, BODY_SOWER,
	BODY_MOTHER, BODY_EEL, CRYSTAL, WAKE } ## étage 4 suite : Mère-Cristal, Anguille, bloc de cristal, sillage

const TELE_FILL := EnemyTelegraph.FILL
const TELE_PROGRESS := EnemyTelegraph.PROGRESS

var kind := Kind.RING
var radius := 64.0 ## RING/DISC/BAND : rayon (extérieur) ; WAVE : demi-largeur du front ; STREAK/COLUMN : hauteur ; BEAM : longueur (px logiques)
var inner := 0.0 ## BAND/RING_TELE : rayon intérieur
var width := 8.0 ## épaisseur de trait (RING), largeur (STREAK/COLUMN), profondeur (WAVE)
var color := Color.WHITE
var color2 := Color.WHITE ## liseré / cœur
var progress := 0.0 ## RING_TELE : remplissage ; BODY_* : flash de coup (0..1)
var lift := 0.0 ## BODY_* : lévitation (px logiques, négatif = vers le haut)
var glow := 1.0 ## BODY_* : intensité du cristal


static func make(p_kind: Kind, p_color: Color, p_z: int = 0) -> RecluseFx:
	var f := RecluseFx.new()
	f.kind = p_kind
	f.color = p_color
	f.color2 = p_color.lightened(0.5)
	f.z_index = p_z
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	return f


## Ajoute `f` sous la couche des télégraphes (coordonnées monde, ni éclairée ni étalonnée) ; repli : `host`.
## Les alertes rouges (RING_TELE, `tele`, méta mini_tele) restent dans le monde, z -1 : sous les corps de boss.
static func add_to_tele_layer(f: Node2D, host: Node) -> void:
	var is_tele: bool = (f is RecluseFx and (f as RecluseFx).kind == Kind.RING_TELE) or f.get(&"tele") == true or f.has_meta(&"mini_tele")
	if is_tele and host != null:
		f.z_index = -1
		host.add_child(f)
		return
	var layer: CanvasLayer = AmbianceManager.telegraph_layer(host.get_tree()) if host != null and host.is_inside_tree() else null
	if layer != null:
		layer.add_child(f)
		if not host.tree_exiting.is_connected(f.queue_free):
			host.tree_exiting.connect(f.queue_free)
	elif host != null:
		host.add_child(f)


func set_param(p_radius: float, p_inner := -1.0, p_progress := -1.0) -> void:
	var dirty := not is_equal_approx(p_radius, radius)
	radius = p_radius
	if p_inner >= 0.0 and not is_equal_approx(p_inner, inner):
		inner = p_inner
		dirty = true
	if p_progress >= 0.0 and absf(p_progress - progress) > 0.01:
		progress = p_progress
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.RING:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, width, true)
			draw_arc(Vector2.ZERO, maxf(radius - width * 0.5, 1.0), 0.0, TAU, 64, color2, maxf(width * 0.3, 1.5), true)
		Kind.RING_TELE: # anneau d'alerte (rouge réservé) : bande inner..radius, remplissage qui monte de l'intérieur
			_band(inner, radius, TELE_FILL)
			var r_fill := lerpf(inner, radius, clampf(progress, 0.0, 1.0))
			if r_fill > inner + 0.5:
				_band(inner, r_fill, TELE_PROGRESS)
			EnemyTelegraph.edge_arc(self, Vector2.ZERO, radius, 0.0, TAU, 64)
			if inner > 1.0:
				EnemyTelegraph.edge_arc(self, Vector2.ZERO, inner, 0.0, TAU, 64)
			if r_fill > inner + 0.5 and r_fill < radius - 1.0:
				EnemyTelegraph.edge_arc(self, Vector2.ZERO, r_fill, 0.0, TAU, 64) # anneau de progression
		Kind.DISC:
			draw_circle(Vector2.ZERO, radius, color)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, color2, width, true)
		Kind.BAND:
			_band(inner, radius, color)
			draw_arc(Vector2.ZERO, inner, 0.0, TAU, 72, color2, width, true)
		Kind.WAVE: # front de vague : barre perpendiculaire à +x (écume claire devant, eau sombre derrière)
			draw_rect(Rect2(-width, -radius, width, radius * 2.0), color)
			draw_rect(Rect2(-width * 0.25, -radius, width * 0.25, radius * 2.0), color2)
		Kind.STREAK: # goutte qui tombe : trait vertical, tête claire en bas (pied au sol à l'origine)
			draw_line(Vector2(0.0, -radius), Vector2.ZERO, color, width, true)
			draw_circle(Vector2.ZERO, width * 0.9, color2)
		Kind.COLUMN: # colonne de pluie / de lumière : dégradé vertical par bandes
			for i in 6:
				var k := float(i) / 6.0
				var c := color
				c.a *= 1.0 - k * 0.8
				draw_rect(Rect2(-width * 0.5 * (1.0 - k * 0.3), -radius * (k + 1.0 / 6.0), width * (1.0 - k * 0.3), radius / 6.0 + 1.0), c)
			draw_line(Vector2(0.0, -radius), Vector2.ZERO, color2, maxf(width * 0.15, 2.0), true)
		Kind.BEAM: # rayon au sol vers +x : `radius` de long, `width` de large, cœur clair
			draw_rect(Rect2(0.0, -width * 0.5, radius, width), color)
			draw_line(Vector2.ZERO, Vector2(radius, 0.0), color2, maxf(width * 0.22, 2.0), true)
		Kind.BODY_RECLUSE:
			_body_recluse()
		Kind.BODY_SOWER:
			_body_sower()
		Kind.BODY_MOTHER:
			_body_mother()
		Kind.BODY_EEL:
			_body_eel()
		Kind.CRYSTAL:
			_crystal()
		Kind.WAKE:
			_wake()


func _band(r0: float, r1: float, c: Color) -> void:
	if r0 <= 0.5:
		draw_circle(Vector2.ZERO, r1, c)
		return
	if r1 - r0 < 0.5:
		return
	draw_arc(Vector2.ZERO, (r0 + r1) * 0.5, 0.0, TAU, 72, c, r1 - r0) # anneau plein (sans couture de polygone)


## Silhouette provisoire du Reclus : moine de pierre encapuchonné (3,6 u), cristal dans la poitrine, cloche.
## Hauteurs en y logique (Iso.lift_logical) ; `color` = pierre, `color2` = cristal.
func _body_recluse() -> void:
	var h := -Iso.lift_logical(3.6)
	var w := 0.9 * Balance.UNIT_PX
	var stone := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	draw_colored_polygon(PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0), Vector2(w * 0.55, -h * 0.72),
		Vector2(w * 0.42, -h * 0.9), Vector2(0.0, -h), Vector2(-w * 0.42, -h * 0.9), Vector2(-w * 0.55, -h * 0.72)]), stone)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.28, -h * 0.74), Vector2(w * 0.28, -h * 0.74),
		Vector2(w * 0.2, -h * 0.9), Vector2(-w * 0.2, -h * 0.9)]), Color(0.02, 0.03, 0.04)) # capuche vide
	var cr := color2
	cr.a = clampf(0.55 + 0.45 * glow, 0.0, 1.0)
	var cy := -h * 0.55
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, cy - w * 0.32), Vector2(w * 0.18, cy), Vector2(0.0, cy + w * 0.32), Vector2(-w * 0.18, cy)]), cr)
	draw_circle(Vector2(w * 1.05, -h * 0.35), w * 0.3, stone.darkened(0.25)) # cloche de silence
	draw_line(Vector2(w * 0.6, -h * 0.55), Vector2(w * 1.05, -h * 0.45), stone.darkened(0.4), 4.0)
	draw_arc(Vector2.ZERO, w * 0.95, 0.0, TAU, 24, Color(cr.r, cr.g, cr.b, 0.35), 2.0) # pied
	draw_set_transform(Vector2.ZERO)


## Silhouette provisoire du Semeur : figure encapuchonnée de bronze noirci (4,5 u), bras-chaînes, cœur-goutte.
func _body_sower() -> void:
	var h := -Iso.lift_logical(4.5)
	var w := 1.05 * Balance.UNIT_PX
	var bronze := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 1.1, 0.0), Vector2(w * 1.1, 0.0), Vector2(w * 0.7, -h * 0.6),
		Vector2(w * 0.95, -h * 0.78), Vector2(0.0, -h), Vector2(-w * 0.95, -h * 0.78), Vector2(-w * 0.7, -h * 0.6)]), bronze)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.3, -h * 0.8), Vector2(w * 0.3, -h * 0.8),
		Vector2(w * 0.18, -h * 0.94), Vector2(-w * 0.18, -h * 0.94)]), Color(0.02, 0.02, 0.03))
	for s in [-1.0, 1.0]: # bras-chaînes : maillons pendants
		var x0: float = s * w * 0.8
		for k in 6:
			draw_circle(Vector2(x0 + s * w * 0.12 * k, -h * 0.62 + k * h * 0.07), w * 0.09, bronze.lightened(0.15))
	var cr := color2
	cr.a = clampf(0.6 + 0.4 * glow, 0.0, 1.0)
	var cy := -h * 0.5
	draw_circle(Vector2(0.0, cy + w * 0.1), w * 0.2, cr) # cœur : goutte de cristal
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.17, cy), Vector2(w * 0.17, cy), Vector2(0.0, cy - w * 0.42)]), cr)
	draw_arc(Vector2.ZERO, w * 1.1, 0.0, TAU, 24, Color(cr.r, cr.g, cr.b, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO)


## Silhouette provisoire de la Mère-Cristal : amas de cristal de sel à silhouette féminine (3,4 u), robe de
## facettes, couronne en pointe, 6 bras-stalactites qui pendent ; `color` = sel, `color2` = cristal ;
## `inner` = éclatement (0..1, phase 3 : les facettes s'écartent du cœur).
func _body_mother() -> void:
	var h := -Iso.lift_logical(3.4)
	var w := 0.85 * Balance.UNIT_PX
	var salt := color.lerp(Color.WHITE, progress * 0.7)
	var sp := inner * w * 0.35
	draw_set_transform(Vector2(0.0, lift))
	for i in 7: # robe : 7 facettes en éventail, plus claires au centre (lumière haut-gauche)
		var k := (float(i) - 3.0) / 3.0
		var x0 := k * w
		var off := Vector2(k * sp, -absf(k) * sp * 0.4)
		var c := salt.darkened(0.18 * absf(k) + (0.12 if k > 0.0 else 0.0))
		draw_colored_polygon(PackedVector2Array([off + Vector2(x0 - w * 0.2, 0.0), off + Vector2(x0 + w * 0.2, 0.0),
			off + Vector2(k * w * 0.25, -h * (0.62 - 0.08 * absf(k)))]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.3, -h * 0.5), Vector2(w * 0.3, -h * 0.5),
		Vector2(w * 0.22, -h * 0.8), Vector2(-w * 0.22, -h * 0.8)]), salt.lightened(0.08)) # buste
	draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.2, -h * 0.8), Vector2(w * 0.2, -h * 0.8),
		Vector2(w * 0.08, -h * 0.9), Vector2(0.0, -h - sp * 0.5), Vector2(-w * 0.08, -h * 0.9)]), salt.lightened(0.15)) # couronne
	for s in [-1.0, 1.0]: # 6 bras-stalactites (3 par côté) qui pendent des épaules
		for j in 3:
			var sx: float = s * (w * 0.28 + j * w * 0.2 + sp * 0.6)
			var top := Vector2(sx, -h * (0.78 - 0.05 * j))
			var tip := Vector2(sx + s * w * (0.18 + 0.1 * j), -h * (0.36 - 0.06 * j) - sp * 0.3)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-w * 0.07, 0.0), top + Vector2(w * 0.07, 0.0), tip]),
				salt.darkened(0.1 + 0.08 * j))
			draw_line(top, tip, Color(color2.r, color2.g, color2.b, 0.35 * glow), 1.5, true)
	var cr := color2
	cr.a = clampf(0.55 + 0.45 * glow, 0.0, 1.0)
	var cy := -h * 0.62
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, cy - w * 0.36), Vector2(w * 0.2, cy), Vector2(0.0, cy + w * 0.3), Vector2(-w * 0.2, cy)]), cr) # cœur
	draw_line(Vector2(0.0, cy), Vector2(0.0, -h * 0.05), Color(cr.r, cr.g, cr.b, 0.45 * glow), 2.0, true) # veine
	draw_arc(Vector2.ZERO, w * 1.05, 0.0, TAU, 24, Color(cr.r, cr.g, cr.b, 0.35), 2.0)
	draw_set_transform(Vector2.ZERO)


## Silhouette provisoire de l'Anguille : arche qui sort de l'eau noire vers +x (tête à droite, retournée par
## scale.x) ; `radius` = longueur hors de l'eau (px), `inner` = sortie (0 plongée .. 1 arche pleine),
## `width` = épaisseur ; `color` = écailles de sel, `color2` = lueur interne.
func _body_eel() -> void:
	if inner <= 0.02:
		return
	var L := radius
	var H := -Iso.lift_logical(2.2) * inner
	var scale_c := color.lerp(Color.WHITE, progress * 0.7)
	draw_set_transform(Vector2(0.0, lift))
	for e2 in [-0.5, 0.5]: # anneaux d'eau aux deux points d'entrée
		draw_arc(Vector2(e2 * L, 0.0), width * 0.9, 0.0, TAU, 20, Color(0.02, 0.04, 0.06, 0.85), width * 0.5, true)
		draw_arc(Vector2(e2 * L, 0.0), width * 1.15, 0.0, TAU, 20, Color(color2.r, color2.g, color2.b, 0.5), 2.0, true)
	var n := 18
	var prev := Vector2.ZERO
	for i in n + 1: # corps : chapelet de disques sur l'arche (tête plus haute)
		var t := float(i) / n
		var p := Vector2(-0.5 * L + L * t, -H * sin(PI * t) - H * 0.45 * t * t)
		var r := width * (0.55 + 0.45 * sin(PI * minf(t * 1.2, 1.0)))
		draw_circle(p, r, scale_c.darkened(0.25 * (1.0 - t)))
		draw_circle(p + Vector2(-r * 0.25, -r * 0.3), r * 0.45, scale_c.lightened(0.18)) # reflet de sel haut-gauche
		if i > 0 and i % 3 == 0 and i < n: # nageoires-lames sur le dos
			var nrm := (p - prev).orthogonal().normalized()
			if nrm.y > 0.0:
				nrm = -nrm
			draw_colored_polygon(PackedVector2Array([p - (p - prev) * 0.6, p + (p - prev) * 0.4, p + nrm * width * 1.3]), scale_c.darkened(0.35))
		prev = p
	var head := Vector2(0.5 * L, -H * 1.45)
	var gl := Color(color2.r, color2.g, color2.b, clampf(0.45 + 0.55 * glow, 0.0, 1.0))
	draw_circle(head + Vector2(width * 0.35, -width * 0.15), width * 0.18, gl) # œil-lanterne
	for i in 6: # lueur interne : points qui courent le long du flanc
		var t := (float(i) + 0.5) / 6.0
		draw_circle(Vector2(-0.5 * L + L * t, -H * sin(PI * t) - H * 0.45 * t * t), width * 0.12, Color(gl.r, gl.g, gl.b, gl.a * 0.7))
	draw_set_transform(Vector2.ZERO)


## Bloc de cristal provisoire : prisme hexagonal (billboard) de hauteur `radius`, largeur `width`, cœur
## `color2` (intensité `glow`) ; pied à l'origine.
func _crystal() -> void:
	var hh := radius
	var w := width * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-w, 0.0), Vector2(0.0, w * 0.3), Vector2(0.0, -hh * 0.9), Vector2(-w, -hh * 0.75)]), color.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, w * 0.3), Vector2(w, 0.0), Vector2(w, -hh * 0.75), Vector2(0.0, -hh * 0.9)]), color.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -hh * 0.75), Vector2(0.0, -hh * 0.9), Vector2(w, -hh * 0.75), Vector2(w * 0.15, -hh)]), color.lightened(0.35))
	var cr := Color(color2.r, color2.g, color2.b, clampf(0.4 + 0.6 * glow, 0.0, 1.0))
	draw_line(Vector2(0.0, -hh * 0.1), Vector2(0.0, -hh * 0.82), cr, maxf(w * 0.28, 2.0), true)
	draw_arc(Vector2.ZERO, w * 1.2, 0.0, TAU, 16, Color(cr.r, cr.g, cr.b, 0.4 * glow), 2.0, true)


## Sillage provisoire sous l'eau noire : V de rides vers -x et lueur interne au point (anguille plongée) ;
## `radius` = taille, `glow` = lueur.
func _wake() -> void:
	var r := radius
	var c := Color(color.r, color.g, color.b, color.a)
	for i in 3:
		var k := 0.45 + 0.3 * i
		draw_arc(Vector2(-r * 0.35 * i, 0.0), r * k, PI * 0.62, PI * 1.38, 10, Color(c.r, c.g, c.b, c.a * (1.0 - 0.28 * i)), 2.5, true)
	draw_circle(Vector2.ZERO, r * 0.32, Color(color2.r, color2.g, color2.b, 0.25 * glow))
	draw_circle(Vector2.ZERO, r * 0.14, Color(color2.r, color2.g, color2.b, 0.6 * glow))
