class_name GroundMarker
extends Node2D
## Repère au sol commun (demande du joueur, 22/10/2026) : petit halo blanc chaud doux + cercle fin sous
## les objets à ramasser (GroundPickup : membres de Tocsin, pièces d'Avare, couteaux de Rictus) et sous
## les invocations alliées (Decoy : doublures de Rictus, mottes de Bourbe).
## - Textures Blender déjà livrées (ambiance) : `halo_soft_256` (lueur, additive). Texture absente = lueur sautée.
## - Grammaire des formes (GroundShapes, lot UX D) : la FORME porte le sens, plus seulement la couleur.
##   Ressource à ramasser (pulse) = losange à 8 tirets or chaud ; invocation alliée = hexagone plein vert menthe.
##   Ni l'un ni l'autre n'est un cercle : plus de confusion avec l'anneau de hitbox, les auras d'élite ou les zones.
##   Textures de forme = `GroundShapes.texture` (assets Codex `ui/shapes/` si livrés, sinon placeholder généré en code).
## - Décalque plat en repère logique : disque, la caméra iso 2:1 le rend ellipse (jamais pré-écrasé).
## - z absolu Z_GROUND + 3/+4 : au-dessus du sol et des ombres de contact (+2), sous les corps (0).
##   Toutes les lueurs à un z, tous les cercles à un autre : matériaux et textures partagés -> lots groupés.
## - Unshaded : lisible de nuit (échappe au CanvasModulate), alpha modéré pour ne pas éblouir.
## - Pulsation lente des objets à ramasser dans le shader (TIME, phase tirée de la position) : aucun
##   _process par objet (des dizaines de pièces d'Avare). Invocations : fixe.
## - `watch` : propriété booléenne de l'hôte qui le cache quand elle passe à vrai (Decoy.exploded : motte
##   écrasée / recollée pendant son anim de fin). Seul cas avec _process (≤ 6 doublures).

const NAME := &"GroundMarker"
const Z_GLOW := AmbianceManager.Z_GROUND + 3
const Z_RING := AmbianceManager.Z_GROUND + 4
const GLOW_TEX := &"halo_soft_256"
const RING_TEX := &"aura_ring_128" ## ancien cercle fin (plus utilisé pour le repère ; gardé pour les autres systèmes)
const SHAPE_LOOT := &"diamond_dashed"
const SHAPE_SUMMON := &"hexagon"
const RING_AT := 0.8 ## rayon du cercle d'aura_ring_128 / demi-largeur de la texture
const GLOW_SPREAD := 1.7 ## rayon de la lueur / rayon du cercle
const WARM := Color(1.0, 0.93, 0.80) ## blanc chaud (jamais blanc pur)
const GLOW_ALPHA := 0.24
const RING_ALPHA := 0.62 ## tracé de forme (tirets / hexagone) un peu plus présent que l'ancien cercle fin
const PULSE_AMP := 0.22 ## objets à ramasser : ±22 % d'opacité, ±5 % de taille
const PULSE_HZ := 0.55
const SHADER_GLOW := preload("res://shaders/ground_marker_glow.gdshader")
const SHADER_RING := preload("res://shaders/ground_marker_ring.gdshader")

static var _mats: Dictionary = {} ## "glow0"/"glow1"/"ring0"/"ring1" -> ShaderMaterial partagé

var radius_px := 24.0
var pulse := false
var watch: StringName = &""
var glow: Sprite2D = null
var ring: Sprite2D = null


## Pose (ou retaille) le repère sous `host`. `radius_u` = rayon du cercle en unités (≈ taille de l'objet).
static func attach(host: Node2D, radius_u: float, p_pulse: bool, p_watch: StringName = &"") -> GroundMarker:
	if host == null:
		return null
	var m := host.get_node_or_null(NodePath(NAME)) as GroundMarker
	if m == null:
		m = GroundMarker.new()
		m.name = NAME
		host.add_child(m)
		host.move_child(m, 0)
	m.pulse = p_pulse
	m.watch = p_watch
	m.set_radius_u(radius_u)
	m.set_process(p_watch != &"")
	return m


## Forme du repère : SHAPE_LOOT (&"diamond_dashed", ressource, `pulse`) sinon SHAPE_SUMMON (&"hexagon", invocation).
## Jamais &"" : l'absence de repère se teste avec GroundMarker.of(host) == null.
func shape_id() -> StringName:
	return SHAPE_LOOT if pulse else SHAPE_SUMMON


static func of(host: Node) -> GroundMarker:
	return host.get_node_or_null(NodePath(NAME)) as GroundMarker if host != null else null


func set_radius_u(r_u: float) -> void:
	radius_px = maxf(r_u, 0.05) * Balance.UNIT_PX
	_build()


func _build() -> void:
	var gt := AmbianceTextures.get_tex(GLOW_TEX) if AmbianceTextures.is_real(GLOW_TEX) else null
	var rt := GroundShapes.texture(SHAPE_LOOT if pulse else SHAPE_SUMMON)
	glow = _layer(glow, gt, Z_GLOW, &"glow", radius_px * GLOW_SPREAD / maxf(gt.get_width() * 0.5, 1.0) if gt else 1.0)
	ring = _layer(ring, rt, Z_RING, &"ring", radius_px / maxf(rt.get_width() * 0.5 * RING_AT, 1.0) if rt else 1.0)


func _layer(spr: Sprite2D, tex: Texture2D, z: int, kind: StringName, k: float) -> Sprite2D:
	if tex == null:
		if spr != null:
			spr.queue_free()
		return null
	if spr == null:
		spr = Sprite2D.new()
		spr.name = String(kind).capitalize()
		spr.z_as_relative = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(spr)
	spr.texture = tex
	spr.z_index = z
	spr.scale = Vector2(k, k)
	spr.material = _material(kind, pulse)
	return spr


static func _material(kind: StringName, p: bool) -> ShaderMaterial:
	var key := "%s%d" % [kind, int(p)]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER_GLOW if kind == &"glow" else SHADER_RING
	var a := GLOW_ALPHA if kind == &"glow" else RING_ALPHA
	var base := WARM if kind == &"glow" else GroundShapes.color_of(&"loot" if p else &"summon")
	m.set_shader_parameter(&"tint", Color(base.r, base.g, base.b, a))
	m.set_shader_parameter(&"pulse_amp", PULSE_AMP if p else 0.0)
	m.set_shader_parameter(&"pulse_hz", PULSE_HZ)
	_mats[key] = m
	return m


func _process(_delta: float) -> void:
	var host := get_parent()
	if watch == &"" or host == null:
		set_process(false)
		return
	if bool(host.get(watch)):
		visible = false
		set_process(false)
