class_name AverseRivulet
extends Node2D
## Gouttière d'Averse (variante du sort 3, docs/Variantes_Sorts.md §2.4) : ruisseau rectangulaire posé au sol
## depuis Averse vers le point visé. Rongé par tick (deal_damage en DoT) ; le kit lit contains() pour rendre
## de l'eau à Averse et la faire courir plus vite. Visuel : tuiles `rivulet_tile` (états `empty` / `full`, la bande
## se remplit selon fill_ratio()) + `rivulet_burst` (déversement à la pose). Repli dessiné en code si un sprite manque.

const _ZONE := preload("res://scripts/spells/zone_effect.gd")
const FADE_IN_S := 0.12
const FADE_OUT_S := 0.4
const FILL_S := 0.35 ## durée de remplissage de la bande (fill_ratio de 0 à 1)
const TILE_PATH := "res://assets/sprites/characters/averse/variants/rivulet_tile/rivulet_tile.tres"
const BURST_PATH := "res://assets/sprites/characters/averse/variants/rivulet_burst/rivulet_burst.tres"
const TILE_PX := 128.0 ## cellule de la tuile : 1 u x 1 u à 128 px/u
const BURST_LEN_PX := 768.0 ## bande de 6 u dans la cellule du déversement
const BURST_H_PX := 256.0 ## pic de 2 u
const SLACK_U := 0.25 ## marge latérale pour qu'un monstre dont le centre frôle la bande soit pris

var caster: Object = null
var spell: SpellData = null
var dir := Vector2.RIGHT
var length_px := 384.0
var width_px := 64.0
var duration := 6.0
var tick := 0.5
var _t := 0.0
var _tick_t := 0.0
var _ending := false
var _full: Array[AnimatedSprite2D] = [] ## calques « plein » des tuiles, opacité = fill_ratio()
var _has_tiles := false


func setup(new_caster: Object, new_spell: SpellData, origin: Vector2, new_dir: Vector2, len_px: float, w_px: float) -> void:
	caster = new_caster
	spell = new_spell
	global_position = origin
	dir = new_dir.normalized() if new_dir.length_squared() > 0.0 else Vector2.RIGHT
	length_px = len_px
	width_px = w_px
	duration = new_spell.duration
	tick = maxf(new_spell.tick, 0.05)
	z_index = _ZONE.VFX_Z
	_build_visual()
	_apply()


## Point `p` (monde) sur la bande ? (marge latérale SLACK_U)
func contains(p: Vector2) -> bool:
	var v := p - global_position
	var along := v.dot(dir)
	if along < 0.0 or along > length_px:
		return false
	return absf(v.dot(Vector2(-dir.y, dir.x))) <= width_px * 0.5 + SLACK_U * Balance.UNIT_PX


## Remplissage de la bande (0 = lit vide, 1 = pleine) : monte à la pose, redescend à la fin.
func fill_ratio() -> float:
	return minf(clampf(_t / FILL_S, 0.0, 1.0), clampf((duration - _t) / FADE_OUT_S, 0.0, 1.0))


func _build_visual() -> void:
	if not ResourceLoader.exists(TILE_PATH):
		return
	var tf := load(TILE_PATH) as SpriteFrames
	if tf == null or not tf.has_animation(&"empty") or not tf.has_animation(&"full"):
		return
	_has_tiles = true
	var n := maxi(1, ceili(length_px / Balance.UNIT_PX))
	var sx := length_px / float(n) / TILE_PX
	var sy := width_px / TILE_PX
	var root := Node2D.new()
	root.name = "Tiles"
	root.rotation = dir.angle()
	add_child(root)
	for i in n:
		for state in [&"empty", &"full"]:
			var sp := AnimatedSprite2D.new()
			sp.sprite_frames = tf
			sp.scale = Vector2(sx, sy)
			sp.position = Vector2((float(i) + 0.5) * length_px / float(n), 0.0)
			root.add_child(sp)
			sp.play(state)
			sp.frame = i % 4 # tuiles voisines déphasées
			if state == &"full":
				sp.modulate.a = 0.0
				_full.append(sp)
	if ResourceLoader.exists(BURST_PATH):
		var bf := load(BURST_PATH) as SpriteFrames
		if bf != null and bf.has_animation(&"default"):
			var b := AnimatedSprite2D.new()
			b.name = "Burst"
			b.sprite_frames = bf
			bf.set_animation_loop(&"default", false)
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			b.material = m
			b.scale = Vector2(length_px / BURST_LEN_PX, width_px * 2.0 / BURST_H_PX)
			b.position = dir * (length_px * 0.5)
			b.rotation = dir.angle()
			add_child(b)
			b.play(&"default")
			b.animation_finished.connect(b.queue_free)


func is_ending() -> bool:
	return _ending


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	_t += delta
	if _ending:
		return
	_tick_t += delta
	while _tick_t >= tick:
		_tick_t -= tick
		_apply()
	if _t >= duration:
		_ending = true
		queue_free()
	if _has_tiles:
		var f := fill_ratio()
		for sp in _full:
			sp.modulate.a = f
	else:
		queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _apply() -> void:
	if caster == null or not is_instance_valid(caster) or spell == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("take_damage") and contains((e as Node2D).global_position) \
				and StageMap.los(get_tree(), global_position, (e as Node2D).global_position):
			caster.deal_damage(e, spell, {"is_dot": true})


func _draw() -> void:
	if _has_tiles:
		return
	var a := minf(clampf(_t / FADE_IN_S, 0.0, 1.0), clampf((duration - _t) / FADE_OUT_S, 0.0, 1.0))
	var c := spell.color if spell != null else Color("#5FD4E8")
	var n := Vector2(-dir.y, dir.x) * width_px * 0.5
	var l := dir * length_px
	draw_colored_polygon(PackedVector2Array([-n, n, n + l, -n + l]), Color(c.r * 0.6, c.g * 0.7, c.b * 0.8, 0.22 * a))
	draw_line(n, n + l, Color(c.r, c.g, c.b, 0.7 * a), 2.0)
	draw_line(-n, -n + l, Color(c.r, c.g, c.b, 0.7 * a), 2.0)
	var step_px := 0.75 * Balance.UNIT_PX # filets qui défilent dans le sens du courant
	var off := fmod(_t * 2.0 * Balance.UNIT_PX, step_px)
	var d := off
	while d < length_px:
		var p := dir * d
		draw_line(p - n * 0.5, p + n * 0.5, Color(c.r, c.g, c.b, 0.45 * a), 1.5)
		d += step_px
