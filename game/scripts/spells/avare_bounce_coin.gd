class_name AvareBounceCoin
extends Node2D
## Pièce truquée d'Avare (variante du sort 2, docs/Variantes_Sorts.md §2.7) : une seule pièce vole vers le point
## visé, touche le premier monstre croisé puis rebondit de monstre en monstre (jamais deux fois le même, <= BOUNCE_U),
## puis tombe où elle s'arrête : le kit y pose la pièce au sol (80 % du coût). Boss : touché une fois, rebond possible.
## Placeholder visuel (disque doré dessiné) : remplaçable par `coin_big` (Codex) sans toucher à la logique.

const HIT_R_PX := 30.0 ## rayon de contact en vol
const LINK_LIFE_S := 0.1 ## fil doré entre deux rebonds
const REHIT_S := 0.12 ## cible isolée (boss, élite seul) : la pièce ricoche sur elle faute d'autre monstre à portée
const GOLD := Color("#F2C14E")

var kit: Object = null ## AvareKit : drop_coin, caster
var spell: SpellData = null
var speed_px := 832.0
var bounce_px := 192.0
var bounces_left := 4
var value := 0.0 ## or de la pièce au sol à l'arrêt
var _dir := Vector2.RIGHT
var _left_px := 384.0 ## portée restante du vol libre
var _target: Node2D = null ## cible de rebond en cours (null = vol libre)
var _hit: Array[int] = []
var hits := 0 ## touches portées (tests)
var landed := false
var _spin := 0.0
var _last: Node2D = null ## dernier monstre touché
var _wait := 0.0 ## pause avant de re-frapper la même cible (rien d'autre à portée)


func launch(from: Vector2, dir: Vector2, range_px: float) -> void:
	global_position = from
	_dir = dir.normalized()
	_left_px = range_px
	z_index = 3


func _physics_process(delta: float) -> void:
	if landed:
		return
	_spin += delta * 14.0
	if _wait > 0.0:
		_wait -= delta
		return
	var step := speed_px * delta
	if _target != null:
		if not is_instance_valid(_target) or not _target.is_inside_tree():
			_target = null
			if not _pick_next():
				_land()
				return
		var to := _target.global_position - global_position
		if to.length() <= step + HIT_R_PX * 0.5:
			global_position = _target.global_position
			_strike(_target)
			return
		global_position += to.normalized() * step
		queue_redraw()
		return
	# vol libre : premier monstre non touché croisé
	var move := _dir * minf(step, _left_px)
	var e := _enemy_near(global_position + move * 0.5, HIT_R_PX + move.length() * 0.5)
	if e != null:
		global_position = e.global_position
		_strike(e)
		return
	global_position += move
	_left_px -= move.length()
	queue_redraw()
	if _left_px <= 0.5:
		_land()


func _enemy_near(p: Vector2, r: float) -> Node2D:
	var best: Node2D = null
	var best_d := r
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and is_instance_valid(e) and not _hit.has(e.get_instance_id()) and e.has_method(&"take_damage"):
			var d := (e as Node2D).global_position.distance_to(p)
			if d <= best_d:
				best_d = d
				best = e
	return best


func _strike(e: Node2D) -> void:
	_hit.append(e.get_instance_id())
	_last = e
	hits += 1
	var c: Variant = kit.get(&"player").spells if kit != null and kit.get(&"player") != null else null
	if c != null:
		(c as SpellCaster).deal_damage(e, spell, {"source_pos": global_position})
	_target = null
	if bounces_left <= 0 or not _pick_next():
		_land()
		return
	bounces_left -= 1


## Prochain monstre non touché à <= bounce_px ; false = aucun (la pièce tombe ici).
func _pick_next() -> bool:
	var nxt := _enemy_near(global_position, bounce_px)
	if nxt == null:
		if _last == null or not is_instance_valid(_last) or not _last.is_inside_tree() or not _last.is_in_group(&"enemies") or _last.global_position.distance_to(global_position) > bounce_px:
			return false
		_target = _last # cible isolée : ricochet sur elle-même
		_wait = REHIT_S
		return true
	_target = nxt
	_link(global_position, nxt.global_position)
	return true


func _link(a: Vector2, b: Vector2) -> void:
	var par := get_parent()
	if par == null:
		return
	var l := Line2D.new()
	l.width = 5.0
	l.default_color = Color(GOLD, 0.9)
	l.add_point(a)
	l.add_point(b)
	l.z_index = 2
	par.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, LINK_LIFE_S)
	tw.tween_callback(l.queue_free)


func _land() -> void:
	if landed:
		return
	landed = true
	if kit != null and kit.has_method(&"drop_coin") and value > 0.0:
		kit.drop_coin(global_position, value, AvareKit.COIN_LIFE_S)
	queue_free()


func _draw() -> void:
	var w := absf(cos(_spin)) * 0.8 + 0.2
	draw_circle(Vector2.ZERO, 14.0, Color(GOLD.r * 0.55, GOLD.g * 0.5, GOLD.b * 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(w, 1.0))
	draw_circle(Vector2.ZERO, 12.0, GOLD)
