class_name MiniFx
extends Node2D
## Visuels des mécaniques de mini-boss (MiniHazards, MiniBossBrain). Depuis le 11/11/2026, les FX de sol, de
## chaînes, du rayon du Jugement et de l'œuf de l'Essaim-mère utilisent les planches Codex de
## `assets/sprites/fx/minis/` (zone_*, chain_link/chain_break, beam_judgment, egg_brood) ; la forme dessinée
## ci-dessous n'est qu'un REPLI SILENCIEUX si un PNG manque. Formes dessinées PROVISOIRES restantes : blocs de glace de l'Ours, rochers du Colosse, tas d'os du
## Porte-ossuaire, anneau de chaînes de l'Archonte, disques du Rémouleur, flaques d'eau (héron, crapaud),
## croûte de sel (golem). CLAUDE.md : formes en code = placeholders temporaires, chaque usage essaie
## d'abord une anim du .tres du mini (MiniHazards.sprite_for). Repère logique (sol écrasé à l'écran :
## les hauteurs se dessinent ×VS). Non éclairées (lisibles la nuit), un seul accent par forme.

enum Kind { BLOCK, CHAIN, SAW, WATER, SALT, ORB, POOL, BEAM, EGG }

const DIR := "res://assets/sprites/fx/minis/"
const SHEET_FRAMES := 8 ## planches de sol : 8 images de 256 px (1 u = 64 px, disque de 4 u de diamètre)
const SHEET_FPS := 8.0
const DISC_K := 1.04 ## le contenu opaque de la cellule couvre ~94 % : léger agrandissement pour couvrir la zone de dégâts
const EGG_FRAMES := 4
## Planches de sol disponibles pour les zones pilotées par données (clé `tex` de data/minibosses.json).
const POOL_SHEETS: PackedStringArray = ["poison", "mud", "oil", "salt", "ember", "ice", "water", "bubbles"]
static var _cache: Dictionary = {}

const VS := 2.0 ## Iso.UNSQUASH.y
const STYLES := {
	&"ice": [Color(0.62, 0.86, 1.0), Color(0.92, 0.98, 1.0)],
	&"rock": [Color(0.45, 0.40, 0.36), Color(1.0, 0.54, 0.19)],
	&"bones": [Color(0.66, 0.63, 0.55), Color(0.75, 0.96, 1.0)],
}

var kind := Kind.BLOCK
var style: StringName = &"rock" ## BLOCK : ice | rock | bones
var color := Color.WHITE
var color2 := Color.WHITE
var radius := 32.0 ## BLOCK/SAW/WATER/SALT : rayon ; CHAIN : rayon médian
var width := 32.0 ## CHAIN : épaisseur de la bande ; SALT (ligne) : largeur
var length := 0.0 ## WATER/SALT : > 0 = bande le long de +x (sinon disque)
var gaps: Array = [] ## CHAIN : angles des brèches (rad)
var gap_half := 0.2
var glow := 0.0 ## WATER : électrisée (0..1) ; CHAIN : contact ; BLOCK : impact
var seed_i := 0
var sheet := "" ## POOL/WATER/SALT : planche de sol (poison, mud, oil, salt, ember, ice, water, bubbles) ; vide = défaut du genre
var progress := 0.0 ## EGG : éclosion 0..1
var _t := 0.0
var _redraw := 0.0
var _resolved := false
var _tex: Texture2D = null ## diffus de la planche (null = repli dessiné)
var _emi: Texture2D = null ## masque d'émission (_e), additif
var _tex2: Texture2D = null ## WATER : variante électrisée ; CHAIN : maillon rompu
var _emi2: Texture2D = null
var _glow_node: Node2D = null
var _frame := -1


static func make(p_kind: Kind, p_color: Color, p_z: int = 0) -> MiniFx:
	var f := MiniFx.new()
	f.kind = p_kind
	f.color = p_color
	f.color2 = p_color.lightened(0.45)
	f.z_index = p_z
	f.light_mask = 0
	f.material = EnemyTelegraph.unshaded_material()
	f.seed_i = randi() % 997
	return f


## Texture du dossier fx/minis (cache statique) ; null si absente (repli silencieux sur la forme dessinée).
static func load_tex(tex_name: String) -> Texture2D:
	if _cache.has(tex_name):
		return _cache[tex_name]
	var path := DIR + tex_name + ".png"
	var t: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[tex_name] = t
	return t


static func has_sheet(tex_name: String) -> bool:
	return POOL_SHEETS.has(tex_name) and load_tex("zone_" + tex_name) != null


func set_glow(g: float) -> void:
	if absf(g - glow) > 0.02:
		glow = g
		_redraw_all()


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	if kind == Kind.EGG:
		var f := mini(int(progress * EGG_FRAMES), EGG_FRAMES - 1)
		if f != _frame:
			_frame = f
			_redraw_all()


## Vrai si la planche du genre est livrée et utilisée (sinon repli dessiné).
func textured() -> bool:
	_resolve()
	return _tex != null


func _resolve() -> void:
	if _resolved:
		return
	_resolved = true
	var n := ""
	var n2 := ""
	match kind:
		Kind.WATER:
			n = "zone_" + (sheet if sheet != "" else "water")
			n2 = "zone_water_shock" if sheet in ["", "water"] else ""
		Kind.SALT:
			n = "zone_" + (sheet if sheet != "" else "salt")
		Kind.POOL:
			n = "zone_" + sheet
		Kind.CHAIN:
			n = "chain_link"
			n2 = "chain_break"
		Kind.BEAM:
			n = "beam_judgment"
		Kind.EGG:
			n = "egg_brood"
	if n == "":
		return
	_tex = load_tex(n)
	if _tex == null:
		return
	_emi = load_tex(n + "_e")
	if n2 != "":
		_tex2 = load_tex(n2)
		_emi2 = load_tex(n2 + "_e")
	if _emi != null or _emi2 != null:
		_glow_node = Node2D.new()
		_glow_node.name = &"MiniFxGlow"
		_glow_node.light_mask = 0
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow_node.material = m
		_glow_node.draw.connect(_draw_glow)
		add_child(_glow_node)


func _redraw_all() -> void:
	queue_redraw()
	if _glow_node != null:
		_glow_node.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_resolve()
	if _tex != null:
		if kind == Kind.WATER or kind == Kind.SALT or kind == Kind.POOL: # boucle de 8 images, redessin à 8 Hz seulement
			var f := int(_t * SHEET_FPS + seed_i) % SHEET_FRAMES
			if f != _frame:
				_frame = f
				_redraw_all()
		return
	if kind == Kind.SAW: # disque qui tourne : rotation du nœud, pas de redessin
		rotation += delta * 18.0
		return
	if kind == Kind.WATER or kind == Kind.CHAIN:
		_redraw -= delta
		if _redraw <= 0.0: # ondulation à 12 Hz (quelques nœuds au plus)
			_redraw = 1.0 / 12.0
			queue_redraw()


func _draw() -> void:
	_resolve()
	if _tex != null and kind in [Kind.WATER, Kind.SALT, Kind.POOL, Kind.CHAIN, Kind.BEAM, Kind.EGG]:
		_draw_textured()
		return
	match kind:
		Kind.BLOCK:
			_block()
		Kind.CHAIN:
			_chain()
		Kind.SAW:
			_saw()
		Kind.WATER, Kind.POOL:
			_water()
		Kind.SALT:
			_salt()
		Kind.ORB: # projectile porteur de statut : halo de la couleur du statut, cœur blanc
			draw_circle(Vector2(0.0, 6.0), radius * 0.9, Color(0.0, 0.0, 0.0, 0.3))
			draw_circle(Vector2.ZERO, radius * 1.35, Color(color.r, color.g, color.b, 0.35))
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.95))


## Obstacle debout (1 u) : ombre de contact, corps à facettes, arête claire (glace : cristal ; rocher : fissure
## orange du Colosse ; os : crânes empilés).
func _block() -> void:
	var r := radius
	var st: Array = STYLES.get(style, STYLES[&"rock"])
	var c: Color = st[0]
	var hi: Color = st[1]
	draw_circle(Vector2.ZERO, r * 1.1, Color(0.02, 0.03, 0.04, 0.5))
	var h := r * 1.15 * VS
	match style:
		&"ice": # prisme de glace : 2 faces + sommet en pointe
			var l := PackedVector2Array([Vector2(-r * 0.85, 0.0), Vector2(0.0, r * 0.35), Vector2(0.0, -h), Vector2(-r * 0.7, -h * 0.72)])
			var rr := PackedVector2Array([Vector2(0.0, r * 0.35), Vector2(r * 0.85, 0.0), Vector2(r * 0.6, -h * 0.8), Vector2(0.0, -h)])
			draw_colored_polygon(l, c.darkened(0.15))
			draw_colored_polygon(rr, c.lightened(0.1))
			draw_polyline(PackedVector2Array([Vector2(-r * 0.7, -h * 0.72), Vector2(0.0, -h), Vector2(r * 0.6, -h * 0.8)]), hi, 2.5, true)
			draw_line(Vector2(0.0, r * 0.35), Vector2(0.0, -h), Color(hi.r, hi.g, hi.b, 0.8), 2.0, true)
		&"bones": # tas d'os : dôme beige, os croisés, 2 orbites
			var pts := PackedVector2Array()
			for i in 16:
				var a := PI + PI * i / 15.0
				pts.append(Vector2(cos(a) * r, sin(a) * h * 0.55))
			pts.append(Vector2(r, r * 0.25))
			pts.append(Vector2(-r, r * 0.25))
			draw_colored_polygon(pts, c)
			for k in 3:
				var y := -h * (0.12 + 0.13 * k)
				draw_line(Vector2(-r * 0.75 + k * 6.0, y + 6.0), Vector2(r * 0.7 - k * 5.0, y - 4.0), c.lightened(0.35), 4.0, true)
			draw_circle(Vector2(-r * 0.22, -h * 0.4), r * 0.12, Color(0.05, 0.05, 0.06))
			draw_circle(Vector2(r * 0.18, -h * 0.4), r * 0.12, Color(0.05, 0.05, 0.06))
			draw_circle(Vector2(-r * 0.22, -h * 0.4), r * 0.05, Color(hi.r, hi.g, hi.b, 0.9))
			draw_circle(Vector2(r * 0.18, -h * 0.4), r * 0.05, Color(hi.r, hi.g, hi.b, 0.9))
		_: # rocher anguleux, fissure orange
			var body := PackedVector2Array([Vector2(-r * 0.95, 0.0), Vector2(-r * 0.6, r * 0.3), Vector2(r * 0.7, r * 0.25), Vector2(r * 0.95, -h * 0.25),
				Vector2(r * 0.55, -h * 0.85), Vector2(-r * 0.2, -h), Vector2(-r * 0.85, -h * 0.55)])
			draw_colored_polygon(body, c)
			draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.85, -h * 0.55), Vector2(-r * 0.2, -h), Vector2(r * 0.55, -h * 0.85),
				Vector2(r * 0.1, -h * 0.6)]), c.lightened(0.18))
			draw_polyline(PackedVector2Array([Vector2(-r * 0.3, -h * 0.1), Vector2(-r * 0.05, -h * 0.4), Vector2(r * 0.2, -h * 0.45), Vector2(r * 0.35, -h * 0.7)]),
				hi, 3.0, true)
	if glow > 0.0:
		draw_circle(Vector2(0.0, -h * 0.5), r * 0.9, Color(1, 1, 1, 0.35 * glow))


## Anneau de chaînes (bande `width` autour de `radius`) interrompu aux brèches : maillons ovales acier,
## liseré cyan de l'Archonte, brèches marquées par deux poteaux clairs.
func _chain() -> void:
	var segs := _segments()
	var link := maxf(width * 0.55, 14.0)
	var steel := color
	var hot := color2.lerp(Color.WHITE, glow)
	for s: Array in segs:
		var a0: float = s[0]
		var a1: float = s[1]
		var pts := maxi(int((a1 - a0) * 24.0), 4)
		draw_arc(Vector2.ZERO, radius, a0, a1, pts, Color(0.03, 0.04, 0.05, 0.55), width) # ombre au sol
		var n := maxi(int((a1 - a0) * radius / link), 1)
		for i in n:
			var a := a0 + (a1 - a0) * (i + 0.5) / n
			var p := Vector2.from_angle(a) * radius
			var tng := Vector2.from_angle(a + PI * 0.5)
			var lift := Vector2(0.0, -4.0 - 3.0 * sin(_t * 3.0 + i))
			var w := link * 0.5
			var thick := maxf(width * (0.2 if i % 2 == 0 else 0.13), 4.0)
			draw_line(p - tng * w + lift, p + tng * w + lift, Color(0.02, 0.03, 0.04, 0.9), thick + 4.0, true)
			draw_line(p - tng * w + lift, p + tng * w + lift, steel, thick, true)
			draw_line(p - tng * w * 0.8 + lift + Vector2(0.0, -thick * 0.25), p + tng * w * 0.8 + lift + Vector2(0.0, -thick * 0.25),
				steel.lightened(0.45), maxf(thick * 0.3, 1.5), true) # reflet : maillons lisibles sous la pluie
		draw_arc(Vector2.ZERO, radius, a0, a1, pts, Color(hot.r, hot.g, hot.b, 0.55 + 0.35 * glow), 2.0, true)
		for a in [a0, a1]: # poteaux d'ancrage : la brèche se lit de loin
			var q := Vector2.from_angle(a) * radius
			draw_line(q, q + Vector2(0.0, -26.0 * VS * 0.5), Color(0.9, 0.95, 1.0, 0.9), 4.0, true)
			draw_circle(q + Vector2(0.0, -26.0 * VS * 0.5), 5.0, hot)


func _segments() -> Array:
	if gaps.is_empty():
		return [[0.0, TAU]]
	var gs: Array = []
	for g in gaps:
		gs.append(fposmod(float(g), TAU))
	gs.sort()
	var out: Array = []
	for i in gs.size():
		var a0: float = gs[i] + gap_half
		var a1: float = (gs[(i + 1) % gs.size()] if i + 1 < gs.size() else gs[0] + TAU) - gap_half
		if a1 > a0:
			out.append([a0, a1])
	return out


## Disque de scie (ombre au sol + lame dentée à arête claire, cœur orange).
func _saw() -> void:
	var r := radius
	draw_circle(Vector2(0.0, 6.0), r, Color(0.0, 0.0, 0.0, 0.35))
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.78))
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.95), 2.0, true)
	draw_circle(Vector2.ZERO, r * 0.42, color.darkened(0.45))
	draw_circle(Vector2.ZERO, r * 0.22, color2)


## Flaque d'eau : disque (ou bande) bleu sombre, reflets et rides concentriques ; blanche quand électrisée.
func _water() -> void:
	var base := Color(color.r * 0.35, color.g * 0.45, color.b * 0.55, 0.32) # eau sombre : se lit comme un sol mouillé, pas comme une alerte
	var lite := color2.lerp(Color(0.95, 0.98, 1.0), glow)
	if length > 0.0:
		draw_rect(Rect2(0.0, -width * 0.5, length, width), base)
		draw_rect(Rect2(0.0, -width * 0.5, length, width), Color(lite.r, lite.g, lite.b, 0.6), false, 2.0)
		return
	draw_circle(Vector2.ZERO, radius, base)
	for k in 3:
		var ph := fposmod(_t * 0.45 + k / 3.0 + seed_i * 0.01, 1.0)
		draw_arc(Vector2.ZERO, radius * (0.25 + 0.7 * ph), 0.0, TAU, 32, Color(lite.r, lite.g, lite.b, 0.28 * (1.0 - ph)), 1.5, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(lite.r, lite.g, lite.b, 0.45), 2.0, true)
	if glow > 0.0: # arcs électriques
		for i in 6:
			var a := TAU * i / 6.0 + _t * 7.0
			var p0 := Vector2.from_angle(a) * radius * 0.2
			var p1 := Vector2.from_angle(a + 0.4) * radius * 0.6
			var p2 := Vector2.from_angle(a - 0.2) * radius * 0.95
			draw_polyline(PackedVector2Array([p0, p1, p2]), Color(1, 1, 1, 0.9 * glow), 2.5, true)


## Croûte de sel : bande (ou disque) blanc cassé, cristaux en losanges qui accrochent la lumière.
func _salt() -> void:
	var base := Color(color.r * 0.7, color.g * 0.72, color.b * 0.76, 0.13) # croûte discrète : le rouge des alertes reste seul à crier
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	if length > 0.0:
		draw_rect(Rect2(0.0, -width * 0.5, length, width), base)
		var n := int(length / 26.0)
		for i in n:
			var p := Vector2(rng.randf() * length, rng.randf_range(-0.4, 0.4) * width)
			_crystal(p, rng.randf_range(4.0, 8.0))
		return
	draw_circle(Vector2.ZERO, radius, base)
	for i in int(radius / 9.0):
		_crystal(Vector2.from_angle(rng.randf() * TAU) * rng.randf() * radius * 0.9, rng.randf_range(4.0, 8.0))


func _crystal(p: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * VS), p + Vector2(s * 0.6, 0), p + Vector2(0, s * 0.4), p + Vector2(-s * 0.6, 0)]),
		Color(0.95, 0.98, 1.0, 0.45))


# --- Rendu par les planches Codex (fx/minis) ---------------------------------------------------------

func _cur_frame() -> int:
	return maxi(_frame, 0)


## Région de la frame `i` d'une planche en bande horizontale de `n` images (le _e est à demi-résolution : proportionnel).
static func _src(tex: Texture2D, i: int, n: int) -> Rect2:
	var w := float(tex.get_width()) / n
	return Rect2(w * i, 0.0, w, float(tex.get_height()))


func _draw_textured() -> void:
	match kind:
		Kind.WATER, Kind.SALT, Kind.POOL:
			var fill := Color(color.r * 0.4, color.g * 0.45, color.b * 0.5, 0.2)
			if length > 0.0:
				draw_rect(Rect2(0.0, -width * 0.5, length, width), fill)
			else:
				draw_circle(Vector2.ZERO, radius, fill) # sous la texture : la zone de dégâts reste pleine sous la bordure douce
			_pool_tiles(self, _tex, 1.0)
			if glow > 0.0 and _tex2 != null: # eau électrisée : variante aux arcs cyan par-dessus
				_pool_tiles(self, _tex2, clampf(glow, 0.0, 1.0))
			var edge := color2.lerp(Color(0.95, 0.98, 1.0), glow)
			var ea := 0.4 if kind == Kind.POOL else 0.3
			if length > 0.0:
				draw_rect(Rect2(0.0, -width * 0.5, length, width), Color(edge.r, edge.g, edge.b, ea), false, 2.0)
			else:
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(edge.r, edge.g, edge.b, ea), 2.0, true)
		Kind.BEAM: # rayon du Jugement : cellule 16 u x 1,5 u étirée sur longueur x largeur du coup
			draw_texture_rect(_tex, Rect2(0.0, -width * 0.5, length, width), false)
		Kind.EGG: # œuf de l'Essaim-mère : 4 images d'éclosion, 1 u par cellule
			draw_texture_rect_region(_tex, Rect2(-32.0, -32.0, 64.0, 64.0), _src(_tex, _cur_frame(), EGG_FRAMES))
		Kind.CHAIN:
			_chain_tex()


## Lueur d'émission (_e) additive : accents des planches, contact des chaînes, œuf, rayon.
func _draw_glow() -> void:
	if _glow_node == null:
		return
	var ci: CanvasItem = _glow_node
	match kind:
		Kind.WATER, Kind.SALT, Kind.POOL:
			if _emi != null:
				_pool_tiles(ci, _emi, 1.0)
			if glow > 0.0 and _emi2 != null:
				_pool_tiles(ci, _emi2, clampf(glow, 0.0, 1.0))
		Kind.BEAM:
			if _emi != null:
				ci.draw_texture_rect(_emi, Rect2(0.0, -width * 0.5, length, width), false)
		Kind.EGG:
			if _emi != null:
				ci.draw_texture_rect_region(_emi, Rect2(-32.0, -32.0, 64.0, 64.0), _src(_emi, _cur_frame(), EGG_FRAMES))
		Kind.CHAIN:
			if glow > 0.02 and _emi != null: # lueur de contact orange-rouille : seulement quand le joueur touche
				_chain_tiles(ci, _emi, _emi2 if _emi2 != null else _emi, Color(1, 1, 1, clampf(glow, 0.0, 1.0)))


## Disque (rayon `radius`) ou bande (`length` x `width` le long de +x, disques jointifs) à partir de la frame courante.
func _pool_tiles(ci: CanvasItem, tex: Texture2D, alpha: float) -> void:
	var col := Color(1, 1, 1, alpha)
	var fr := _cur_frame()
	if length <= 0.0:
		var d := radius * 2.0 * DISC_K
		ci.draw_texture_rect_region(tex, Rect2(-d * 0.5, -d * 0.5, d, d), _src(tex, fr, SHEET_FRAMES), col)
		return
	var d2 := width * DISC_K
	var span := maxf(length - width, 0.0)
	var n := maxi(int(ceil(span / (width * 0.7))) + 1, 1)
	for i in n:
		var cx := width * 0.5 + (span * i / (n - 1) if n > 1 else 0.0)
		var f := (fr + i * 3) % SHEET_FRAMES # frames décalées : pas de motif répété à l'identique
		ci.draw_texture_rect_region(tex, Rect2(cx - d2 * 0.5, -d2 * 0.5, d2, d2), _src(tex, f, SHEET_FRAMES), col)


## Anneau de chaînes texturé : maillons de 1 u (64 x 32 px) étirés à l'épaisseur de la bande, bords de brèche en
## maillon rompu (ouverture vers +x de l'arc, miroir au début), poteaux d'ancrage et liseré conservés.
func _chain_tex() -> void:
	var hot := color2.lerp(Color.WHITE, glow)
	for s: Array in _segments():
		var a0: float = s[0]
		var a1: float = s[1]
		var pts := maxi(int((a1 - a0) * 24.0), 4)
		draw_arc(Vector2.ZERO, radius, a0, a1, pts, Color(0.03, 0.04, 0.05, 0.4), width) # ombre au sol sous la bande
	_chain_tiles(self, _tex, _tex2 if _tex2 != null else _tex, Color.WHITE)
	for s: Array in _segments():
		var a0: float = s[0]
		var a1: float = s[1]
		var pts := maxi(int((a1 - a0) * 24.0), 4)
		draw_arc(Vector2.ZERO, radius - width * 0.5, a0, a1, pts, Color(hot.r, hot.g, hot.b, 0.4 + 0.4 * glow), 1.5, true)
		draw_arc(Vector2.ZERO, radius + width * 0.5, a0, a1, pts, Color(hot.r, hot.g, hot.b, 0.4 + 0.4 * glow), 1.5, true)
		for a in [a0, a1]: # poteaux d'ancrage : la brèche se lit de loin
			var q := Vector2.from_angle(a) * radius
			draw_line(q, q + Vector2(0.0, -13.0), Color(0.9, 0.95, 1.0, 0.9), 4.0, true)
			draw_circle(q + Vector2(0.0, -13.0), 5.0, hot)


func _chain_tiles(ci: CanvasItem, link: Texture2D, brk: Texture2D, col: Color) -> void:
	var k := width / 32.0 # épaisseur du maillon = épaisseur de la bande (zone de dégâts)
	for s: Array in _segments():
		var a0: float = s[0]
		var a1: float = s[1]
		var arc_len := (a1 - a0) * radius
		var n := maxi(roundi(arc_len / (64.0 * k)), 1)
		var step := (a1 - a0) / n
		var sx := (arc_len / n) / 64.0
		for i in n:
			var a := a0 + step * (i + 0.5)
			var tex := link
			var flip := 1.0
			if n > 1 and i == n - 1:
				tex = brk
			elif n > 1 and i == 0:
				tex = brk
				flip = -1.0
			ci.draw_set_transform(Vector2.from_angle(a) * radius, a + PI * 0.5, Vector2(sx * flip, k))
			ci.draw_texture_rect(tex, Rect2(-32.0, -16.0, 64.0, 32.0), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
