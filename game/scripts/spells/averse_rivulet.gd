class_name AverseRivulet
extends Node2D
## Gouttière-collecteur d'Averse (variante du sort 3, docs/Variantes_Sorts.md §2.4) : ruisseau rectangulaire posé au
## sol depuis Averse vers le point visé. Rongé par tick (deal_damage en DoT) ; le kit lit contains() pour tremper et
## compter les kills, y verse l'eau collectée (`collected`) et déclenche le déversement (`on_spill`) quand la
## gouttière finit (expiration ou relance, finish()). PLACEHOLDER dessiné en code : un seul nœud visuel (bande qui se
## remplit selon `collected / fill_ref`, flash au déversement) que le lot Codex remplace (`rivulet_tile` variante
## pleine + `rivulet_burst`).

const _ZONE := preload("res://scripts/spells/zone_effect.gd")
const FADE_IN_S := 0.12
const FADE_OUT_S := 0.4
const BURST_S := 0.3 ## durée du flash de déversement avant disparition
const SLACK_U := 0.25 ## marge latérale pour qu'un monstre dont le centre frôle la bande soit pris

var caster: Object = null
var spell: SpellData = null
var dir := Vector2.RIGHT
var length_px := 384.0
var width_px := 64.0
var duration := 6.0
var tick := 0.5
var collected := 0.0 ## eau recueillie (pluie + kills), lue au déversement
var fill_ref := 9.0 ## eau collectée = bande pleine (indicateur)
var on_spill: Callable = Callable() ## appelé une fois avec ce ruisseau au déversement
var _t := 0.0
var _tick_t := 0.0
var _ending := false
var _burst_t := 0.0


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


func fill_ratio() -> float:
	return clampf(collected / maxf(fill_ref, 0.01), 0.0, 1.0)


## Fin de vie : `spill` = déversement (expiration, relance) ; sans (nettoyage) la bande disparaît sans effet.
func finish(spill := true) -> void:
	if _ending:
		return
	_ending = true
	if spill and on_spill.is_valid():
		on_spill.call(self)
		_burst_t = BURST_S
	else:
		queue_free()


func step(delta: float) -> void: ## public pour les tests sans boucle de rendu
	_t += delta
	if _ending:
		if _burst_t > 0.0:
			_burst_t -= delta
			if _burst_t <= 0.0:
				queue_free()
		queue_redraw()
		return
	_tick_t += delta
	while _tick_t >= tick:
		_tick_t -= tick
		_apply()
	if _t >= duration:
		finish(true)
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
	var c := spell.color if spell != null else Color("#5FD4E8")
	var n := Vector2(-dir.y, dir.x) * width_px * 0.5
	var l := dir * length_px
	if _ending: # déversement : flash qui s'étire en largeur puis s'efface
		var k := clampf(_burst_t / BURST_S, 0.0, 1.0)
		var w := n * (1.0 + 1.2 * (1.0 - k))
		draw_colored_polygon(PackedVector2Array([-w, w, w + l, -w + l]), Color(0.85, 0.97, 1.0, 0.6 * k))
		return
	var a := minf(clampf(_t / FADE_IN_S, 0.0, 1.0), clampf((duration - _t) / FADE_OUT_S, 0.0, 1.0))
	draw_colored_polygon(PackedVector2Array([-n, n, n + l, -n + l]), Color(c.r * 0.6, c.g * 0.7, c.b * 0.8, 0.22 * a))
	var f := fill_ratio() # la bande se remplit depuis l'embouchure (Averse) selon l'eau recueillie
	if f > 0.0:
		var lf := l * f
		draw_colored_polygon(PackedVector2Array([-n, n, n + lf, -n + lf]), Color(c.r, c.g, c.b, 0.42 * a))
	draw_line(n, n + l, Color(c.r, c.g, c.b, 0.7 * a), 2.0)
	draw_line(-n, -n + l, Color(c.r, c.g, c.b, 0.7 * a), 2.0)
	var step_px := 0.75 * Balance.UNIT_PX # filets qui défilent dans le sens du courant
	var off := fmod(_t * 2.0 * Balance.UNIT_PX, step_px)
	var d := off
	while d < length_px:
		var p := dir * d
		draw_line(p - n * 0.5, p + n * 0.5, Color(c.r, c.g, c.b, 0.45 * a), 1.5)
		d += step_px
