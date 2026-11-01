class_name EpreuveEscort
extends Epreuve
## Escorte (docs/Boucle_Etage_Refonte.md §1.1) : « Lancer la barque » au ponton ; elle suit `path` (polyligne en repère local
## de la carte, `escort_path` du JSON) à Balance.ESCORT_SPEED_U, s'ARRÊTE si le joueur s'éloigne à plus de
## Balance.ESCORT_LEASH_U (corde), est blessée par les monstres au contact (PV = Balance.escort_hp), et à 0 PV s'immobilise
## Balance.ESCORT_STALL_S s puis repart pleine (jamais détruite). Arrivée -> mini-boss au ponton d'arrivée. Parfait :
## durée <= EPREUVE_TARGET_S[escorte] et barque jamais à 0 PV. Placeholder : polygone brun 1,5 x 1,0 u (barque Codex à venir).
## Écart au doc : la barque ne repousse pas les monstres sur son tracé (prototype).

const HIT_SAMPLE_S := 0.25 ## période de relevé des monstres au contact
const CONTACT_INTERVAL_S := 1.0 ## un monstre au contact frappe une fois par seconde (Enemy.CONTACT_INTERVAL)

var path := PackedVector2Array() ## points du tracé, repère local de la carte
var length := 0.0 ## longueur du tracé (px)
var dist_along := 0.0 ## distance parcourue (px)
var max_hp := 0.0
var hp := 0.0
var stall_left := 0.0 ## s d'immobilisation restantes (PV à 0)
var stall_count := 0 ## nombre d'immobilisations (journal, note)
var leash_blocked := false ## le joueur est trop loin : la barque attend
var leash_wait_s := 0.0 ## cumul d'attente à la corde (mesure)
var _seg_len := PackedFloat32Array()
var _hit_t := 0.0
var _body: Polygon2D = null
var _heading := Vector2.RIGHT


## Escorte sur le tracé `pts` (au moins 2 points, repère local de la carte).
static func make(pts: PackedVector2Array) -> EpreuveEscort:
	var e := EpreuveEscort.new()
	e.set_path(pts)
	return e


func _init() -> void:
	verb = &"escorte"
	uses_sprite = false


func set_path(pts: PackedVector2Array) -> void:
	path = pts
	_seg_len.clear()
	length = 0.0
	for i in range(path.size() - 1):
		var l := path[i].distance_to(path[i + 1])
		_seg_len.append(l)
		length += l
	dist_along = 0.0
	if not path.is_empty():
		position = path[0]
		if path.size() > 1:
			_heading = (path[1] - path[0]).normalized()


func _ready() -> void:
	super._ready()
	_body = Polygon2D.new()
	_body.name = &"Barque"
	_body.polygon = PackedVector2Array([Vector2(-48, -26), Vector2(30, -26), Vector2(56, 0), Vector2(30, 26), Vector2(-48, 26)])
	_body.color = Color(0.46, 0.30, 0.17)
	add_child(_body)
	_body.rotation = _heading.angle()


func zone_radius() -> float:
	return Balance.EPREUVE_ZONE_RADIUS_U * Balance.UNIT_PX


func interact_label() -> String:
	return "Lancer la barque"


func progress() -> float:
	return clampf(dist_along / length, 0.0, 1.0) if length > 0.0 else 0.0


## Position (repère local de la carte) à la distance `s` (px) le long du tracé.
func point_at(s: float) -> Vector2:
	if path.is_empty():
		return position
	s = clampf(s, 0.0, length)
	for i in _seg_len.size():
		if s <= _seg_len[i] or i == _seg_len.size() - 1:
			var t := clampf(s / _seg_len[i], 0.0, 1.0) if _seg_len[i] > 0.0 else 0.0
			return path[i].lerp(path[i + 1], t)
		s -= _seg_len[i]
	return path[path.size() - 1]


func _heading_at(s: float) -> Vector2:
	s = clampf(s, 0.0, length)
	for i in _seg_len.size():
		if s <= _seg_len[i] or i == _seg_len.size() - 1:
			return (path[i + 1] - path[i]).normalized()
		s -= _seg_len[i]
	return _heading


func _begin() -> void:
	max_hp = Balance.escort_hp(RunState.difficulty(), RunState.stage)
	hp = max_hp
	stall_left = 0.0
	stall_count = 0
	leash_wait_s = 0.0
	dist_along = 0.0
	_hit_t = 0.0
	_place()


func _run(delta: float) -> void:
	# coop : la corde tient tant qu'AU MOINS UN joueur vivant est à portée
	leash_blocked = not (is_inside_tree() and CoopRules.any_within(global_position, Balance.ESCORT_LEASH_U * Balance.UNIT_PX, true))
	if stall_left > 0.0:
		stall_left -= delta
		if stall_left <= 0.0:
			stall_left = 0.0
			hp = max_hp # repart pleine
	else:
		_hit_t += delta
		if _hit_t >= HIT_SAMPLE_S:
			damage(_contact_dps() * _hit_t)
			_hit_t = 0.0
	if stall_left > 0.0:
		return
	if leash_blocked:
		leash_wait_s += delta
		return
	advance(Balance.ESCORT_SPEED_U * Balance.UNIT_PX * delta)


## Fait avancer la barque de `px` pixels (tests, mode test) ; arrivée -> fin de l'épreuve.
func advance(px: float) -> void:
	dist_along = minf(dist_along + px, length)
	_place()
	if dist_along >= length and is_running():
		_resolve()


## Dégâts reçus par la barque. À 0 PV : immobilisée ESCORT_STALL_S, la note « parfait » est perdue.
func damage(amount: float) -> void:
	if amount <= 0.0 or stall_left > 0.0 or not is_running():
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		stall_left = Balance.ESCORT_STALL_S
		stall_count += 1
		clean = false


func _place() -> void:
	position = point_at(dist_along)
	_heading = _heading_at(dist_along)
	if _body != null:
		_body.rotation = _heading.angle()


## Dégâts par seconde des monstres au contact de la barque (somme de leurs dégâts / CONTACT_INTERVAL_S).
func _contact_dps() -> float:
	var total := 0.0
	var reach := Balance.ESCORT_HIT_RADIUS_U * Balance.UNIT_PX
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.active or e.is_boss:
			continue
		if e.global_position.distance_to(global_position) <= reach + e.radius_px:
			total += e.damage
	return total / CONTACT_INTERVAL_S


func _on_resolved() -> void:
	leash_blocked = false
	stall_left = 0.0


func _extra_dict() -> Dictionary:
	return {"s": dist_along, "hp": hp, "max_hp": max_hp, "stall": stall_left, "stalls": stall_count}


func _extra_restore(d: Dictionary) -> void:
	dist_along = float(d.get("s", 0.0))
	max_hp = float(d.get("max_hp", 0.0))
	hp = float(d.get("hp", max_hp))
	stall_left = float(d.get("stall", 0.0))
	stall_count = int(d.get("stalls", 0))
	_place()


func draw_overlay(c: Node2D) -> void:
	var m := get_parent() as Node2D
	if m == null or path.size() < 2:
		return
	var pts := PackedVector2Array()
	for p in path:
		pts.append(c.to_local(m.to_global(p)))
	var on := state != Pillar.STATE_DONE
	if on:
		c.draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.30), 4.0)
		c.draw_circle(pts[0], 26.0, Color(0.55, 0.9, 1.0, 0.25)) # ponton de départ
		c.draw_arc(pts[pts.size() - 1], 40.0, 0.0, TAU, 32, Color(1.0, 0.8, 0.4, 0.7), 4.0) # ponton d'arrivée
	if not is_running():
		return
	# corde et PV
	var pl := Players.nearest(global_position, true) if is_inside_tree() else null # corde vers le joueur vivant le plus proche
	if pl != null:
		var tp := c.to_local(pl.global_position)
		var k := clampf(pl.global_position.distance_to(global_position) / (Balance.ESCORT_LEASH_U * Balance.UNIT_PX), 0.0, 1.0)
		c.draw_line(Vector2.ZERO, tp, Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.25, 0.2), k * k), 3.0)
	if leash_blocked:
		c.draw_arc(Vector2.ZERO, Balance.ESCORT_LEASH_U * Balance.UNIT_PX, 0.0, TAU, 64, Color(1.0, 0.3, 0.2, 0.35), 3.0)
	var w := 96.0
	var frac := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	c.draw_rect(Rect2(-w * 0.5, -60.0, w, 8.0), Color(0, 0, 0, 0.6))
	c.draw_rect(Rect2(-w * 0.5, -60.0, w * frac, 8.0), Color(0.3, 0.9, 0.4) if stall_left <= 0.0 else Color(0.9, 0.3, 0.2))
	if _body != null:
		_body.modulate = Color(1.0, 0.55, 0.5) if stall_left > 0.0 else Color.WHITE
