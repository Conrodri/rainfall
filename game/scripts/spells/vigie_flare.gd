class_name VigieFlare
extends Node2D
## Fusée de magnésium plantée par la Fusée de détresse de Vigie (VigieKit) : pas de dégâts propres, c'est
## une LUMIÈRE (preset LightRig `vigie_flare`, rouge de détresse qui crachote) ; VigieKit expose les monstres
## à moins de `radius`. Visuel : `flare.tres` (lot Codex VG2, CREA, `default` en boucle + `end` facultative)
## sous un billboard ; sans asset, repli dessiné (placeholder) : cœur incandescent + anneau fin au rayon réel.

const FADE_S := 0.4
const FALLBACK_RING_W := 2.0
const CORE_U := 0.18

var radius := 192.0
var life := 5.0
var color := Color("#FF3A4F")
var follow: Node2D = null ## Fanal : la lumière suit ce nœud (Vigie)
var counts_exposed := true ## compte dans `vigie_exposed` (Fusée, Fanal ; pas le Tir de signal)
var seen := {} ## instance_id des monstres déjà comptés pour cette fusée
var _bb: Node2D = null
var _t := 0.0
var _ending := false
var _sprite: AnimatedSprite2D = null
var _light: LightRig.Handle = null


func setup(at: Vector2, radius_px: float, life_s: float, frames_path: String, accent: Color) -> void:
	global_position = at
	radius = radius_px
	life = life_s
	color = accent
	z_index = -1 # au sol, sous les personnages (comme les zones)
	if frames_path != "" and ResourceLoader.exists(frames_path):
		var frames := load(frames_path) as SpriteFrames
		if frames != null and frames.has_animation(&"default"):
			var bb := Node2D.new()
			bb.name = "Billboard"
			bb.scale = Iso.UNSQUASH
			bb.z_index = 1
			add_child(bb)
			_bb = bb
			_sprite = AnimatedSprite2D.new()
			_sprite.name = "Visual"
			bb.add_child(_sprite)
			EmissiveOverlay.apply(_sprite, frames)
			var tex := frames.get_frame_texture(&"default", 0)
			if tex != null: # pivot de la planche = bas-centre (point d'impact au sol), brief VG2
				_sprite.offset = Vector2(0.0, -tex.get_height() * 0.5)
			_sprite.play(&"default")
	_light = LightRig.attach(self, &"vigie_flare", {"radius": radius / maxf(float(LightRig.get_preset(&"vigie_flare").get("radius_u", 3.0)) * Balance.UNIT_PX, 1.0)})


## Agrandit le visuel (Tir de signal : fusée x1,5) ; la lumière et le rayon de jeu restent ceux de setup.
func set_visual_scale(k: float) -> void:
	if _bb != null:
		_bb.scale = Iso.UNSQUASH * k


func is_ending() -> bool:
	return _ending


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	_t += delta
	if not _ending and _t >= life:
		_ending = true
		if _sprite != null and _sprite.sprite_frames.has_animation(&"end"):
			_sprite.sprite_frames.set_animation_loop(&"end", false)
			_sprite.play(&"end")
		if _light != null:
			_light.set_fade(FADE_S)
	if _ending:
		var k := clampf((_t - life) / FADE_S, 0.0, 1.0)
		modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
	if _sprite == null:
		queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _exit_tree() -> void:
	if _light != null:
		LightRig.detach(_light)
		_light = null


## Repli (placeholder, remplacé par flare.tres) : cœur qui crachote + anneau de portée de la lumière.
func _draw() -> void:
	if _sprite != null:
		return
	var flick := 0.75 + 0.25 * sin(_t * 23.0) * sin(_t * 7.0)
	var core := CORE_U * Balance.UNIT_PX
	draw_circle(Vector2.ZERO, core * 2.2, Color(color.r, color.g, color.b, 0.18 * flick))
	draw_circle(Vector2.ZERO, core, Color(color.r * 2.0, color.g * 1.6, color.b * 1.6, 0.95))
	var a := 0.24 + 0.1 * sin(_t * 4.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color.r, color.g, color.b, a), FALLBACK_RING_W)
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.03))
