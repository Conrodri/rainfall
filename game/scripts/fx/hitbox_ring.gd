class_name HitboxRing
extends Node2D
## Indicateur de hitbox au sol sous le joueur (demande du joueur, 22/10/2026 : « comprendre où nous nous faisons
## toucher »). Enfant du joueur dans le plan de sol LOGIQUE : le cercle devient une ellipse iso 2:1 à l'écran.
## - Repos : anneau clair fin et discret (alpha bas) au rayon EXACT des dégâts (`Player.hit_radius_px()`,
##   PlayerHitbox) ; suit set_hitbox_u (Bourbe qui rétrécit, toupie de Rictus). Atténué pendant la roulade.
## - Coup reçu (`Player.take_damage` -> `on_hit(source)`) : l'anneau s'illumine (flash chaud FLASH_S) ET un éclat en
##   arc s'allume sur le bord, côté d'où vient le coup (source -> joueur ; point d'impact précis des projectiles via
##   `Player.note_hit_from`), puis s'estompe en glissant vers l'extérieur (ARC_S). Pièges sans position (zones) :
##   flash de l'anneau seul. `Quality.flashes_level` 0 : pas de flash HDR, éclat doux.
## - Réglage : `GameSettings.show_hitbox()` (Réglages > Accessibilité « Afficher la hitbox », défaut activé).
## Visuels : textures du lot Codex HX1 (art/tools/night/_hx1.txt, `assets/sprites/fx/hitbox/`) si livrées ; sinon
## anneau = `ambiance/light_ring_256.png` (rendu Blender existant) et éclat dessiné en code (PLACEHOLDER temporaire).

const GROUP := &"hitbox_ring"
const RING_TEX := "res://assets/sprites/fx/hitbox/hitbox_ring.png" ## HX1 (256², pic de l'anneau à RING_PEAK_PX)
const ARC_TEX := "res://assets/sprites/fx/hitbox/hitbox_arc.png" ## HX1 (256², arc centré sur +X, même rayon)
const RING_FALLBACK_TEX := "res://assets/sprites/ambiance/light_ring_256.png" ## anneau fin existant (pic r = 97/128)
const TEX_HALF := 128.0
const RING_PEAK_PX := 97.0 ## rayon du pic de l'anneau dans la texture 256²

const IDLE_COLOR := Color(0.84, 0.92, 1.0, 0.2) ## anneau clair doux, alpha bas (capture : 0,34 trop présent)
const DODGE_ALPHA_K := 0.35 ## roulade : aucune hitbox, anneau atténué
const FLASH_S := 0.25
const FLASH_COLOR := Color(1.6, 0.85, 0.42, 0.8) ## flash chaud HDR (glow), sous l'éclat pour que la direction domine
const FLASH_COLOR_SOFT := Color(1.0, 0.7, 0.45, 0.6) ## flashes_level 0
const ARC_S := 0.55
const ARC_HALF_RAD := 0.7 ## demi-ouverture de l'éclat (≈ 40°)
const ARC_DRIFT_PX := 9.0 ## l'éclat glisse vers l'extérieur en s'estompant
const ARC_COLOR := Color(2.4, 1.25, 0.55, 1.0)
const ARC_COLOR_SOFT := Color(1.0, 0.75, 0.5, 0.75)
const ARC_WIDTH_PX := 4.5
const ARC_GLOW_WIDTH_PX := 12.0
const ARC_POINTS := 13
const TICK_LEN_PX := 7.0 ## crans cardinaux de la grammaire des formes (GroundShapes.draw_ticks)

var enabled := true:
	set(v):
		enabled = v
		visible = v
var _player: Node2D = null
var _ring_tex: Texture2D = null
var _arc_tex: Texture2D = null
var _r := 0.0
var _dodging := false
var _flash_left := 0.0
var _arc_left := 0.0
var _arc_angle := 0.0
var _soft := false
var _pending_from := Vector2.ZERO
var _pending_frame := -1


func _ready() -> void:
	name = "HitboxRing"
	add_to_group(GROUP)
	z_index = -1 # sous le corps (comme l'ombre de Rainette)
	_player = get_parent() as Node2D
	if ResourceLoader.exists(RING_TEX):
		_ring_tex = load(RING_TEX) as Texture2D
	elif ResourceLoader.exists(RING_FALLBACK_TEX):
		_ring_tex = load(RING_FALLBACK_TEX) as Texture2D
	if ResourceLoader.exists(ARC_TEX):
		_arc_tex = load(ARC_TEX) as Texture2D
	enabled = GameSettings.show_hitbox()
	_r = _target_radius()


func _target_radius() -> float:
	if _player != null and _player.has_method(&"hit_radius_px"):
		return float(_player.hit_radius_px())
	return PlayerHitbox.radius_px


## Point d'impact précis du coup qui suit dans la même image (projectile).
func note_hit_from(world_pos: Vector2) -> void:
	_pending_from = world_pos
	_pending_frame = Engine.get_process_frames()


## Coup reçu : flash de l'anneau + éclat côté source (si la source a une position de combattant).
func on_hit(source: Node = null) -> void:
	_soft = Quality.flashes_level <= 0
	_flash_left = FLASH_S
	var from := Vector2.INF
	if _pending_frame == Engine.get_process_frames():
		from = _pending_from
	elif source is Node2D and is_instance_valid(source) and (source.is_in_group(&"enemies") or source.is_in_group(&"bosses")):
		from = (source as Node2D).global_position
	_pending_frame = -1
	if from != Vector2.INF and _player != null:
		var d := from - _player.global_position
		if d.length_squared() > 1.0:
			_arc_angle = d.angle()
			_arc_left = ARC_S
	queue_redraw()


func _process(delta: float) -> void:
	var r := _target_radius()
	var dodging := _player != null and _player.has_method(&"is_dodging") and bool(_player.is_dodging())
	var redraw := not is_equal_approx(r, _r) or dodging != _dodging or _flash_left > 0.0 or _arc_left > 0.0
	_r = r
	_dodging = dodging
	_flash_left = maxf(_flash_left - delta, 0.0)
	_arc_left = maxf(_arc_left - delta, 0.0)
	if redraw:
		queue_redraw()


func _draw() -> void:
	var f := _flash_left / FLASH_S # 1 -> 0
	var col := IDLE_COLOR
	if f > 0.0:
		col = IDLE_COLOR.lerp(FLASH_COLOR_SOFT if _soft else FLASH_COLOR, f * f * (3.0 - 2.0 * f))
	if _dodging:
		col.a *= DODGE_ALPHA_K
	_draw_ring(_r, col)
	# Grammaire des formes au sol (GroundShapes) : anneau continu + 4 crans cardinaux = hitbox, jamais confondue avec le
	# losange du butin, l'hexagone des invocations ou les auras d'élite. Crans à l'alpha de l'anneau (flash inclus).
	GroundShapes.draw_ticks(self, _r, Color(col, minf(col.a * 1.5, 1.0)), 2.0, TICK_LEN_PX)
	if _arc_left > 0.0:
		_draw_arc_flash(_arc_left / ARC_S)


func _draw_ring(r: float, col: Color) -> void:
	if _ring_tex != null:
		var h := TEX_HALF * r / RING_PEAK_PX
		draw_texture_rect(_ring_tex, Rect2(-h, -h, 2.0 * h, 2.0 * h), false, col)
	else: # PLACEHOLDER temporaire (aucune texture d'anneau)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, col, 2.0, true)


## Éclat sur le bord, côté source ; k = vie restante 1 -> 0.
func _draw_arc_flash(k: float) -> void:
	var r := _r + ARC_DRIFT_PX * (1.0 - k)
	var a := k * (2.0 - k) # tient puis s'estompe
	var base := ARC_COLOR_SOFT if _soft else ARC_COLOR
	if _arc_tex != null:
		var h := TEX_HALF * r / RING_PEAK_PX
		draw_set_transform(Vector2.ZERO, _arc_angle, Vector2.ONE)
		draw_texture_rect(_arc_tex, Rect2(-h, -h, 2.0 * h, 2.0 * h), false, Color(base, base.a * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# PLACEHOLDER temporaire (en attendant hitbox_arc.png, lot HX1) : arc effilé aux extrémités + halo large.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var glow := PackedColorArray()
	var half := ARC_HALF_RAD * (0.85 + 0.15 * k)
	for i in ARC_POINTS:
		var t := float(i) / float(ARC_POINTS - 1) # 0..1
		var ang := _arc_angle - half + 2.0 * half * t
		pts.append(Vector2.from_angle(ang) * r)
		var taper := sin(PI * t) # 0 aux bouts, 1 au centre
		cols.append(Color(base, base.a * a * taper))
		glow.append(Color(base, base.a * a * taper * 0.28))
	draw_polyline_colors(pts, glow, ARC_GLOW_WIDTH_PX, true)
	draw_polyline_colors(pts, cols, ARC_WIDTH_PX, true)


# --- Lecture (tests, debug) ----------------------------------------------

func radius_px() -> float:
	return _r


func flash_left() -> float:
	return _flash_left


func arc_left() -> float:
	return _arc_left


## Angle (rad, repère logique) du centre de l'éclat : direction joueur -> source.
func arc_angle() -> float:
	return _arc_angle


## Rayon dessiné à l'écran : demi-largeur et demi-hauteur de l'ellipse (px logiques ; la caméra écrase y de moitié).
func drawn_half_extent() -> float:
	return TEX_HALF * _r / RING_PEAK_PX if _ring_tex != null else _r
