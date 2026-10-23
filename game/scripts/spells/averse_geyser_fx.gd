class_name AverseGeyserFx
extends Node2D
## Geyser d'Averse (variante du sort 2) : bouillonnement au sol (télégraphe) puis colonne d'eau. Rendu seulement,
## les dégâts et la projection sont dans AverseKit. Avec `geyser.tres` (lot Codex AVSV) l'effet joue le sprite
## (`default`, rig TOP) ; sinon PLACEHOLDER dessiné en code (cercle de bulles puis colonne cyan).

const _ZONE := preload("res://scripts/spells/zone_effect.gd")

var radius_px := 128.0
var telegraph_s := 0.3
var column_s := 0.5
var color := Color("#5FD4E8")
var frames_path := ""
var frames_radius_px := 128.0
var _t := 0.0
var _vfx: AnimatedSprite2D = null
var _burst := false


func setup(at: Vector2, r_px: float, telegraph: float, tint: Color, frames: String, frames_r_px: float) -> void:
	global_position = at
	radius_px = r_px
	telegraph_s = telegraph
	color = tint
	frames_path = frames
	frames_radius_px = frames_r_px
	z_index = _ZONE.VFX_Z


## Passe du télégraphe à la colonne (appelé par le kit à l'instant du jaillissement).
func burst() -> void:
	_burst = true
	_t = 0.0
	if frames_path != "" and ResourceLoader.exists(frames_path):
		var sf := load(frames_path) as SpriteFrames
		if sf != null and sf.has_animation(&"default"):
			_vfx = AnimatedSprite2D.new()
			_vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(_vfx)
			EmissiveOverlay.apply(_vfx, sf)
			var k := radius_px / maxf(frames_radius_px, 1.0)
			_vfx.scale = Vector2(k, k) # rig TOP, aspect 1
			sf.set_animation_loop(&"default", false)
			_vfx.play(&"default")
			column_s = maxf(_ZONE.anim_length(sf, &"default"), 0.1)


func _process(delta: float) -> void:
	_t += delta
	if _burst and _t >= column_s:
		queue_free()
		return
	if not _burst and _t > telegraph_s + 0.5: # filet : le jaillissement n'est jamais venu (kit libéré)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _vfx != null:
		return
	var c := color
	if not _burst:
		var k := clampf(_t / maxf(telegraph_s, 0.01), 0.0, 1.0)
		GroundShapes.draw_dotted_circle(self, radius_px, Color(c.r, c.g, c.b, 0.35 + 0.45 * k), 24, 2.0)
		for i in 7: # bouillonnement : bulles qui montent dans le disque
			var ang := float(i) * 2.399 + _t * 3.0
			var rr := radius_px * (0.2 + 0.6 * fmod(float(i) * 0.37 + k, 1.0))
			draw_circle(Vector2.from_angle(ang) * rr, 3.0 + 3.0 * k, Color(c.r, c.g, c.b, 0.5))
		return
	var k2 := clampf(_t / maxf(column_s, 0.01), 0.0, 1.0)
	var a := 1.0 - k2
	var h := radius_px * 2.4 * sin(minf(k2 * 2.0, 1.0) * PI * 0.5) # colonne (haut = y négatif)
	var w := radius_px * (0.55 - 0.25 * k2)
	draw_colored_polygon(PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0), Vector2(w * 0.7, -h), Vector2(-w * 0.7, -h)]),
		Color(c.r, c.g, c.b, 0.35 * a))
	draw_arc(Vector2.ZERO, radius_px * (0.5 + 0.5 * k2), 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.8 * a), 2.0)
