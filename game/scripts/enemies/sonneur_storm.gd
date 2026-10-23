class_name SonneurStorm
extends Node2D
## Trace du Sonneur après sa mort (docs/Design_Boss_Cartes.md §3.3) : tant que la charge du gros pilier
## n'est pas finie, la foudre frappe le joueur toutes les STORM_EVERY s (cercle télégraphié 1 s,
## Balance.BOSS_ATTACK_COEF[&"sonneur"][&"storm"]). Créé par SonneurBrain.clear() à la mort (phase 2+),
## se libère quand le pilier n'est plus actif (ou au bout de MAX_S).

const STORM_EVERY := 8.0
const FIRST_S := 3.0
const MAX_S := 120.0

var damage := 0.0
var strikes := 0 ## éclairs tombés (tests)
var _frames: SpriteFrames
var _pillar: Node = null
var _t := 0.0
var _life := 0.0
var _pending := false
var _pos := Vector2.ZERO
var _tele: EnemyTelegraph = null
var _fx: Array = []


## Orage laissé par le boss `e` (mort) si un gros pilier actif l'entoure. null sinon.
static func spawn(e: Enemy, frames: SpriteFrames) -> SonneurStorm:
	var host := e.get_parent()
	if host == null or not e.is_inside_tree():
		return null
	var pillar: Node = null
	for p in e.get_tree().get_nodes_in_group(&"pillars"):
		if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
			pillar = p
			break
	if pillar == null:
		return null
	var s := SonneurStorm.new()
	s.name = &"SonneurStorm"
	s._frames = frames
	s._pillar = pillar
	s.damage = e.damage * Balance.boss_attack_coef(SonneurBrain.ID, &"storm")
	s._t = STORM_EVERY - FIRST_S
	host.add_child(s)
	return s


func _ready() -> void:
	_tele = EnemyTelegraph.new()
	add_child(_tele)


func _physics_process(delta: float) -> void:
	_life += delta
	var p := _pillar as Pillar
	if _life > MAX_S or not is_instance_valid(p) or p.state != Pillar.STATE_ACTIVE:
		_free()
		return
	_update_fx(delta)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	_t += delta
	if not _pending and _t >= STORM_EVERY - SonneurBrain.LIGHTNING_WINDUP:
		_pending = true
		_pos = player.global_position
		_tele.show_circle(_pos, SonneurBrain.LIGHTNING_R_U * SonneurBrain.U)
	if _pending:
		_tele.set_progress((_t - (STORM_EVERY - SonneurBrain.LIGHTNING_WINDUP)) / SonneurBrain.LIGHTNING_WINDUP)
		if _t >= STORM_EVERY:
			_t = 0.0
			_pending = false
			_tele.hide_telegraph()
			strikes += 1
			SonneurBrain.strike_fx(get_parent(), _frames, _pos, _fx)
			Audio.play(&"amb.thunder_close", _pos)
			if player.global_position.distance_to(_pos) <= SonneurBrain.LIGHTNING_R_U * SonneurBrain.U + SonneurBrain.PLAYER_R and player.has_method(&"take_damage"):
				player.take_damage(damage, self)


func _update_fx(delta: float) -> void:
	var i := _fx.size() - 1
	while i >= 0:
		var f: Dictionary = _fx[i]
		f["life"] = float(f["life"]) - delta
		var n := f["node"] as CanvasItem
		if not is_instance_valid(n) or float(f["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_fx.remove_at(i)
		else:
			n.modulate.a = clampf(float(f["life"]) / float(f["max"]), 0.0, 1.0)
		i -= 1


func _free() -> void:
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	if is_instance_valid(_tele):
		_tele.queue_free()
	queue_free()
