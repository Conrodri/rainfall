class_name AverseRivulet
extends Node2D
## Gouttière d'Averse (variante du sort 3, docs/Variantes_Sorts.md §2.4) : ruisseau rectangulaire posé au sol
## depuis Averse vers le point visé. Rongé par tick (deal_damage en DoT) ; le kit lit contains() pour rendre
## de l'eau à Averse et la faire courir plus vite. PLACEHOLDER dessiné en code (bande cyan + filets qui défilent) :
## le lot Codex AVSV (`rivulet_tile`) le remplace.

const _ZONE := preload("res://scripts/spells/zone_effect.gd")
const FADE_IN_S := 0.12
const FADE_OUT_S := 0.4
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
	_apply()


## Point `p` (monde) sur la bande ? (marge latérale SLACK_U)
func contains(p: Vector2) -> bool:
	var v := p - global_position
	var along := v.dot(dir)
	if along < 0.0 or along > length_px:
		return false
	return absf(v.dot(Vector2(-dir.y, dir.x))) <= width_px * 0.5 + SLACK_U * Balance.UNIT_PX


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
	queue_redraw()


func _process(delta: float) -> void:
	step(delta)


func _apply() -> void:
	if caster == null or not is_instance_valid(caster) or spell == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and e.has_method("take_damage") and contains((e as Node2D).global_position):
			caster.deal_damage(e, spell, {"is_dot": true})


func _draw() -> void:
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
