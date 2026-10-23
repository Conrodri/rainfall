class_name ArpenteuseChainLine
extends Node2D
## Rendu d'une chaîne de l'Arpenteuse au sol : deux Line2D en mode TILE sur la même polyligne,
## diffus éclairé à plat (arpenteuse_chain.gdshader) et émission additive (arpenteuse_chain_e.gdshader).
## Textures = planches rendues dans Blender (lot AR2, rig TOP 128 px/u, cellules 128×64 = 1 u × 0,5 u) :
## `chain_tile` (4 frames d'incandescence en boucle), `chain_snap` / `chain_rewind` (6 frames, Tendeur).
## Sans planche sur disque : repli = Line2D unie fine dans l'accent (placeholder, à remplacer).
## Le nœud vit en coordonnées globales (top_level) : set_line(points globaux).

const SHEET_DIR := "res://assets/sprites/characters/arpenteuse/effects/"
const SHEETS := {&"tile": ["chain_tile", 4, 8.0], &"snap": ["chain_snap", 6, 24.0], &"rewind": ["chain_rewind", 6, 12.0]}
const CELL_ASPECT := 2.0 ## 128 × 64
const SHADER := preload("res://scripts/fx/arpenteuse_chain.gdshader")
const SHADER_E := preload("res://scripts/fx/arpenteuse_chain_e.gdshader")
const FALLBACK_WIDTH_FRAC := 0.35

var base: Line2D = null
var glow: Line2D = null
var sheet: StringName = &""
var frame := 0.0
var fps := 8.0
var frame_count := 4
var loop := true
var energy := 2.0 ## énergie HDR de l'émission (modulée par le kit : chaleur, coups)
var u_offset := 0.0
var has_sheet := false
var _accent := Color("#FF7A1F")
static var _cache := {} ## nom -> [Texture2D diffus, Texture2D émission]


static func _load_sheet(sname: String) -> Array:
	if _cache.has(sname):
		return _cache[sname]
	var out: Array = []
	var d := SHEET_DIR + sname + ".png"
	if ResourceLoader.exists(d):
		var e := SHEET_DIR + sname + "_e.png"
		out = [load(d), load(e) if ResourceLoader.exists(e) else null]
	_cache[sname] = out
	return out


func _init() -> void:
	top_level = true
	base = _make_line()
	glow = _make_line()
	add_child(base)
	add_child(glow)


func _make_line() -> Line2D:
	var l := Line2D.new()
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_NONE
	l.end_cap_mode = Line2D.LINE_CAP_NONE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.antialiased = false
	return l


## width_px : largeur logique de la bande (la cellule 128×64 y tient : 1 maillon-tuile = 2 × largeur).
func setup(width_px: float, accent: Color) -> void:
	_accent = accent
	base.width = width_px
	glow.width = width_px
	set_sheet(&"tile")


func set_sheet(which: StringName) -> void:
	if which == sheet:
		return
	sheet = which
	var spec: Array = SHEETS[which]
	frame_count = int(spec[1])
	fps = float(spec[2])
	loop = which == &"tile"
	frame = 0.0
	var tex := _load_sheet(String(spec[0]))
	has_sheet = not tex.is_empty()
	if not has_sheet: # repli : trait fin dans l'accent (placeholder)
		base.texture = null
		base.material = null
		base.default_color = Color(_accent.r * 0.35, _accent.g * 0.3, _accent.b * 0.3)
		glow.texture = null
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		glow.material = m
		glow.default_color = _accent
		glow.width = base.width * FALLBACK_WIDTH_FRAC
		return
	base.texture = tex[0]
	var mb := ShaderMaterial.new()
	mb.shader = SHADER
	base.material = mb
	base.default_color = Color.WHITE
	glow.texture = tex[0] # donne l'UV de tuile ; l'émission vient de emit_tex
	var me := ShaderMaterial.new()
	me.shader = SHADER_E
	me.set_shader_parameter(&"emit_tex", tex[1])
	glow.material = me
	glow.default_color = _accent if tex[1] == null else Color.WHITE
	glow.visible = tex[1] != null
	_push_params()


## Avance l'anim de la planche ; retourne false quand une planche non bouclée est finie.
func advance(delta: float) -> bool:
	frame += delta * fps
	if frame >= frame_count:
		if loop:
			frame = fmod(frame, frame_count)
		else:
			frame = frame_count - 1
			_push_params()
			return false
	_push_params()
	return true


func set_line(points: PackedVector2Array) -> void:
	base.points = points
	glow.points = points
	visible = points.size() >= 2


func _push_params() -> void:
	if not has_sheet:
		glow.default_color = Color(_accent.r * energy, _accent.g * energy, _accent.b * energy, 1.0)
		return
	for l: Line2D in [base, glow]:
		var m := l.material as ShaderMaterial
		if m == null:
			continue
		m.set_shader_parameter(&"frames", float(frame_count))
		m.set_shader_parameter(&"frame", floorf(frame))
		m.set_shader_parameter(&"u_offset", u_offset)
	(glow.material as ShaderMaterial).set_shader_parameter(&"energy", energy)


func refresh() -> void:
	_push_params()
