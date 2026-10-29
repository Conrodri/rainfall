class_name DamageNumbers
extends Node2D
## Chiffres de degats flottants (Events.enemy_damaged), poolés. En foule, les chiffres proches et
## recents de meme couleur sont regroupes (somme). A instancier une fois dans la scene de jeu, sous
## AmbianceManager.telegraph_layer (coordonnees monde, ni eclaire ni etalonne) : unshaded, light_mask 0.
## Camera iso 2:1 : le texte n'est pas plat au sol, le noeud porte Iso.UNSQUASH (espace billboard).
## `show_number(at, ...)` prend un point DEJA en espace billboard (x, y/2 - hauteur au-dessus des pieds).
## Lots UX D / A11y-L1 : dégât subi = signe « − » + cramoisi + contour clair épais de 4 px (distinct du critique or par
## la teinte ET la forme, ΔE2000 >= 20 dans les 3 daltonismes simulés) ; taille plancher 20 px quel que soit le réglage
## « Taille des chiffres » ; couleurs d'élément via CvdPalette (mode daltonien lu en lecture seule) ; les nouveaux chiffres
## évitent `Hud.reserved_rects()` (appel tolérant : sans HUD ou sans la fonction, aucun décalage).

const POOL_SIZE := 64
const LIFETIME := 0.7
const RISE := 70.0
const HEAD_PX := 40.0 ## hauteur d'apparition au-dessus des pieds (px billboard)
const MERGE_WINDOW_S := 0.2
const MERGE_DIST := 56.0
const ELEMENT_COLORS := {
	&"fire": Color(1.0, 0.5, 0.15),
	&"ice": Color(0.5, 0.85, 1.0),
	&"lightning": Color(0.8, 0.7, 1.0),
	&"poison": Color(0.5, 0.9, 0.3),
}
## Critique : or vif (CvdPalette.CRIT), taille plus grande, « pop » d'échelle et icône de critique
## (rendu Blender, ui/crit_icon.png) à gauche du chiffre ; tant que l'icône n'existe pas, un « ! » textuel.
const CRIT_COLOR := CvdPalette.CRIT
const CRIT_ICON := "res://assets/sprites/ui/crit_icon.png"
const CRIT_ICON_PX := 24.0
const CRIT_POP_S := 0.14
## Dégâts reçus par le joueur (Events.player_damaged) : cramoisi (CvdPalette.HURT), plus haut (au-dessus de la tête
## d'Ardent), préfixe « − » et contour clair épais : ne se confond ni avec le critique or ni avec un élément.
const PLAYER_HURT_COLOR := CvdPalette.HURT
const HURT_OUTLINE_COLOR := Color(0.97, 0.91, 0.84, 0.95)
const HURT_OUTLINE_PX := 4
const PLAYER_HEAD_PX := 96.0
## Style : petits chiffres condensés, os chaud mat (jamais blanc pur : ils passaient devant les décors
## sombres), contour fin brun-noir, opacité plafonnée. Police bitmap Codex (lot DF1) si livrée, sinon
## police système condensée (Bahnschrift sous Windows, Roboto Condensed sous Android).
const BASE_COLOR := Color(0.80, 0.74, 0.64)
const MAX_ALPHA := 0.88
const FONT_PX := 24 ## « Normaux » ; × DAMAGE_SCALES (0,8 / 1 / 1,3), plancher MIN_FONT_PX
const MIN_FONT_PX := 20
const CRIT_FONT_PX := 32
const HURT_FONT_PX := 28
const MINUS := "−" ## « − » ; repli « - » si la police bitmap n'a pas le glyphe
const SCALE_REFRESH_MS := 500
const OUTLINE_PX := 3
const CRIT_OUTLINE_PX := 4
const OUTLINE_COLOR := Color(0.05, 0.035, 0.03, 0.8)
const FONT_PATH := "res://assets/sprites/ui/damage_font/damage_font.fnt"
const FALLBACK_FONTS := ["Bahnschrift SemiCondensed", "Bahnschrift", "Roboto Condensed", "sans-serif-condensed", "Arial Narrow"]

## Teinte du chiffre d'un coup de combo (docs/Design_Combos.md §6) : posée par SpellCaster.deal_damage le temps de
## take_damage (alpha 0 = aucune). Évite de changer la signature du signal enemy_damaged.
static var combo_tint := Color(0, 0, 0, 0)

var active_count := 0
var _labels: Array[Label] = []
var _age := PackedFloat32Array()
var _sum := PackedFloat32Array()
var _origin := PackedVector2Array()
var _color: Array[Color] = []
var _active := PackedByteArray()
var _crit := PackedByteArray()
var _crit_tex: Texture2D
var _next := 0
var _font: Font = null
var _minus := "-"
var scale_override := -1.0 ## tests : facteur de taille forcé (>= 0), sinon GameSettings.damage_text_scale() en cache
var hud_provider := Callable() ## tests : () -> Array[Rect2] zones réservées en coordonnées écran
var _scale_cache := 1.0
var _scale_at := -1000000
var _hud: Node = null
var _hud_retry_at := 0
var _rects_frame := -1
var _rects: Array[Rect2] = []


func _ready() -> void:
	z_index = 100
	light_mask = 0
	scale = Iso.UNSQUASH
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	if ResourceLoader.exists(CRIT_ICON):
		_crit_tex = load(CRIT_ICON) as Texture2D
	var font := _load_font()
	_font = font
	_minus = MINUS if font.has_char(0x2212) else "-"
	for i in POOL_SIZE:
		var l := Label.new()
		l.visible = false
		l.light_mask = 0
		l.use_parent_material = true
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", FONT_PX)
		l.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
		l.add_theme_constant_override("outline_size", OUTLINE_PX)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		var icon := TextureRect.new()
		icon.name = "CritIcon"
		icon.texture = _crit_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(CRIT_ICON_PX, CRIT_ICON_PX)
		icon.use_parent_material = true
		icon.light_mask = 0
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		l.add_child(icon)
		_labels.append(l)
		_age.append(0.0)
		_sum.append(0.0)
		_origin.append(Vector2.ZERO)
		_color.append(Color.WHITE)
		_active.append(0)
		_crit.append(0)
	Events.enemy_damaged.connect(_on_damaged)
	Events.player_damaged.connect(_on_player_damaged)


func _on_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var col: Color = CRIT_COLOR if is_crit else CvdPalette.element(element)
	if combo_tint.a > 0.0:
		col = combo_tint
	var gp := enemy.global_position
	show_number(Vector2(gp.x + randf_range(-14.0, 14.0), gp.y / Iso.UNSQUASH.y - HEAD_PX), amount, col, is_crit)


func _on_player_damaged(amount: float, _source: Node) -> void:
	if amount <= 0.0 or not is_inside_tree():
		return
	var p := get_tree().get_first_node_in_group(&"player") as Node2D
	if p == null:
		return
	var gp := p.global_position
	show_number(Vector2(gp.x, gp.y / Iso.UNSQUASH.y - PLAYER_HEAD_PX), amount, PLAYER_HURT_COLOR)


func show_number(at: Vector2, amount: float, col: Color, is_crit: bool = false) -> void:
	for i in POOL_SIZE:
		if _active[i] == 1 and _age[i] < MERGE_WINDOW_S and _color[i] == col and _crit[i] == int(is_crit) \
				and _origin[i].distance_to(at) < MERGE_DIST:
			_sum[i] += amount
			_labels[i].text = _text(_sum[i], is_crit, col == PLAYER_HURT_COLOR)
			_age[i] = minf(_age[i], 0.05)
			return
	var idx := -1
	for k in POOL_SIZE:
		var j := (_next + k) % POOL_SIZE
		if _active[j] == 0:
			idx = j
			break
	if idx < 0: # pool sature : recycle le plus ancien
		idx = 0
		for j in POOL_SIZE:
			if _age[j] > _age[idx]:
				idx = j
	else:
		active_count += 1
	_next = (idx + 1) % POOL_SIZE
	var l := _labels[idx]
	_sum[idx] = amount
	_age[idx] = 0.0
	_origin[idx] = at
	_color[idx] = col
	_active[idx] = 1
	_crit[idx] = int(is_crit)
	var hurt := col == PLAYER_HURT_COLOR
	l.text = _text(amount, is_crit, hurt)
	l.modulate = Color(col, MAX_ALPHA)
	l.add_theme_font_size_override("font_size", font_px(is_crit, hurt))
	l.add_theme_constant_override("outline_size", HURT_OUTLINE_PX if hurt else (CRIT_OUTLINE_PX if is_crit else OUTLINE_PX))
	l.add_theme_color_override("font_outline_color", HURT_OUTLINE_COLOR if hurt else OUTLINE_COLOR)
	var icon := l.get_node(^"CritIcon") as TextureRect
	icon.visible = is_crit and _crit_tex != null
	icon.position = Vector2(-CRIT_ICON_PX - 2.0, 4.0)
	at = _avoid_reserved(l, at)
	_origin[idx] = at
	l.position = at
	l.visible = true


func _process(delta: float) -> void:
	if active_count == 0:
		return
	for i in POOL_SIZE:
		if _active[i] == 0:
			continue
		_age[i] += delta
		var t := _age[i] / LIFETIME
		if t >= 1.0:
			_active[i] = 0
			_labels[i].visible = false
			active_count -= 1
			continue
		var l := _labels[i]
		l.position = _origin[i] + Vector2(-l.size.x * 0.5, -RISE * t)
		if _crit[i] == 1: # pop : 1,5 -> 1 sur CRIT_POP_S
			l.pivot_offset = l.size * 0.5
			l.scale = Vector2.ONE * lerpf(1.35, 1.0, clampf(_age[i] / CRIT_POP_S, 0.0, 1.0))
		else:
			l.scale = Vector2.ONE
		var m := _color[i]
		m.a = MAX_ALPHA * (1.0 if t < 0.55 else (1.0 - t) / 0.45)
		l.modulate = m


func _text(amount: float, is_crit: bool, hurt := false) -> String:
	var n := str(int(round(amount)))
	if hurt:
		return _minus + n
	return ("!" + n) if is_crit and _crit_tex == null else n


## Taille de police (px) d'un chiffre : base × réglage « Taille des chiffres », jamais sous MIN_FONT_PX.
func font_px(is_crit: bool, hurt: bool) -> int:
	var base := CRIT_FONT_PX if is_crit else (HURT_FONT_PX if hurt else FONT_PX)
	return maxi(MIN_FONT_PX, roundi(base * _text_scale()))


## Facteur du réglage de taille (cache : le réglage vit dans un fichier, on ne le relit pas à chaque coup).
func _text_scale() -> float:
	if scale_override >= 0.0:
		return scale_override
	var now := Time.get_ticks_msec()
	if now - _scale_at >= SCALE_REFRESH_MS or _scale_at > now:
		_scale_at = now
		_scale_cache = clampf(GameSettings.damage_text_scale(), 0.5, 2.0)
	return _scale_cache


## Zones réservées du HUD (écran). `hud_provider` s'il est valide (injecté par les tests, il prime), sinon
## `Hud.reserved_rects()` de l'instance du HUD (trouvée via un ancêtre portant `hud`, appel tolérant), sinon liste
## vide. Un résultat par image.
func reserved_rects() -> Array[Rect2]:
	var frame := Engine.get_process_frames()
	if frame == _rects_frame:
		return _rects
	_rects_frame = frame
	_rects = []
	var res: Variant = null
	if hud_provider.is_valid():
		res = hud_provider.call()
	else:
		if (_hud == null or not is_instance_valid(_hud)) and Time.get_ticks_msec() >= _hud_retry_at:
			_hud = _find_hud()
			_hud_retry_at = Time.get_ticks_msec() + 1000
		if _hud != null and is_instance_valid(_hud) and _hud.has_method(&"reserved_rects"):
			res = _hud.call(&"reserved_rects")
	if res is Array:
		for r in res:
			if r is Rect2:
				_rects.append(r)
	return _rects


func _find_hud() -> Node:
	var n: Node = get_parent()
	while n != null:
		var h: Variant = n.get(&"hud")
		if h is Node and (h as Node).has_method(&"reserved_rects"):
			return h
		n = n.get_parent()
	return null


## Décale `at` (espace local) pour que le chiffre et sa montée ne recouvrent aucune zone réservée du HUD.
## Le plus petit déplacement (gauche, droite, haut, bas) qui dégage la zone et reste dans la vue est retenu.
func _avoid_reserved(l: Label, at: Vector2) -> Vector2:
	var rects := reserved_rects()
	if rects.is_empty() or not is_inside_tree():
		return at
	var xf := get_global_transform_with_canvas()
	var k := xf.get_scale().abs()
	if k.x < 0.001 or k.y < 0.001:
		return at
	var sz := l.get_minimum_size()
	var view := get_viewport().get_visible_rect()
	var out := at
	for _pass in 3:
		var sp := xf * (out + Vector2(-sz.x * 0.5, -RISE))
		var box := Rect2(sp, Vector2(sz.x, sz.y + RISE) * k)
		var hit := false
		for r in rects:
			var rr := r.grow(6.0)
			if not rr.intersects(box):
				continue
			hit = true
			var opts: Array[Vector2] = [Vector2(rr.end.x - box.position.x, 0.0), Vector2(-(box.end.x - rr.position.x), 0.0),
				Vector2(0.0, rr.end.y - box.position.y), Vector2(0.0, -(box.end.y - rr.position.y))]
			var best := Vector2.ZERO
			var best_len := INF
			for o in opts:
				var moved := Rect2(box.position + o, box.size)
				if view.size != Vector2.ZERO and not view.encloses(moved):
					continue
				if o.length() < best_len:
					best_len = o.length()
					best = o
			if best_len < INF:
				out += best / k
			break
		if not hit:
			break
	return out


func _load_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f := load(FONT_PATH) as Font
		if f != null:
			return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(FALLBACK_FONTS)
	sf.font_weight = 600
	sf.font_stretch = 75
	return sf
