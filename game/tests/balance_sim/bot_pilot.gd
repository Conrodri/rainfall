extends RefCounted
## Pilote automatique du simulateur d'équilibrage (tests/balance_sim) : un « joueur moyen » scripté,
## identique pour tous les personnages.
## - Distance préférée tirée du kit : portée utile du sort 1 (projectile = portée, demi-cercle / nova = rayon).
## - Va au contact pour lancer un sort 2-4 prêt dont la portée de déclenchement est plus courte (nova…),
##   tant que les PV sont au-dessus de 50 %.
## - Kite (recule du centre de gravité des monstres proches) si trop près, tourne autour de la cible sinon.
## - Esquive : sort d'un télégraphe (cercle, cône, ligne de bond) en marchant ; roulade si l'impact est imminent.
## - Sorts 2-4 : auto-cast du jeu (Player.auto_cast_spells, option d'accessibilité) ; ciblage automatique
##   (visée manuelle coupée : comportement mobile).
## Déplacement par Input.action_press sur move_* : le kit lit les mêmes entrées que pour un vrai joueur.

const U := 64.0
const DODGE_LEAD_S := 0.3 ## roulade si l'impact tombe dans moins de ce délai
const DANGER_MARGIN_U := 0.5
const STRAFE_FLIP_S := 3.0
const LEASH_U := 12.0 ## au-delà, le pilote revient vers le centre de l'arène
## Joueur moyen, pas parfait : réagit à un télégraphe après REACTION_S et en rate MISS_CHANCE.
const REACTION_S := 0.2
const MISS_CHANCE := 0.25

var player: Node2D
var base_pref_u := 3.0
var dodges := 0
var _strafe_sign := 1.0
var _strafe_t := 0.0
var rng := RandomNumberGenerator.new()
var _seen := {} ## instance id -> {w, ignore} : un tirage par télégraphe


func setup(p: Node2D, seed_value := 1) -> void:
	player = p
	rng.seed = seed_value
	base_pref_u = preferred_range_u(p.character)


## Portée utile du sort automatique (u), bornée [0,9 ; 5,5].
static func preferred_range_u(c: CharacterData) -> float:
	if c == null or c.spells.is_empty():
		return 3.0
	var s: SpellData = c.spells[0]
	for sp in c.spells:
		if sp.slot == 1:
			s = sp
	var reach := 3.0
	match s.behavior:
		SpellData.Behavior.PROJECTILE, SpellData.Behavior.FAN:
			reach = s.range_u * 0.7
		SpellData.Behavior.ARC, SpellData.Behavior.NOVA, SpellData.Behavior.SPIN:
			reach = maxf(s.radius_u, 0.8) * 0.75
		SpellData.Behavior.GROUND_ZONE:
			reach = s.range_u * 0.6
		_:
			reach = minf(s.trigger_range_u, maxf(s.range_u, s.radius_u)) * 0.7
	return clampf(reach, 0.9, 5.5)


func release() -> void:
	for a in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _set_move(v: Vector2) -> void:
	if v.length_squared() < 0.0001:
		release()
		return
	v = v.normalized()
	_press(&"move_right", maxf(v.x, 0.0))
	_press(&"move_left", maxf(-v.x, 0.0))
	_press(&"move_down", maxf(v.y, 0.0))
	_press(&"move_up", maxf(-v.y, 0.0))


func _press(a: StringName, s: float) -> void:
	if not InputMap.has_action(a):
		return
	if s > 0.001:
		Input.action_press(a, s)
	else:
		Input.action_release(a)


## Une décision par frame physique.
func tick(delta: float, enemies: Array) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		release()
		return
	_strafe_t += delta
	if _strafe_t >= STRAFE_FLIP_S:
		_strafe_t = 0.0
		_strafe_sign = -_strafe_sign
	var ppos: Vector2 = player.global_position
	# 1. Danger : télégraphe qui couvre le joueur.
	var escape := Vector2.ZERO
	var soonest := INF
	for e in enemies:
		var d := _danger(e, ppos)
		if d.is_empty():
			continue
		escape += d["dir"]
		soonest = minf(soonest, float(d["left"]))
	if escape != Vector2.ZERO:
		if soonest <= DODGE_LEAD_S and player.has_method(&"dodge") and player.dodge(escape.normalized()):
			dodges += 1
		_set_move(escape)
		return
	# 2. Placement par rapport à la cible la plus proche.
	var nearest: Node2D = null
	var nd := INF
	var crowd := Vector2.ZERO
	var crowd_n := 0
	for e in enemies:
		var dd: float = ppos.distance_to(e.global_position)
		if dd < nd:
			nd = dd
			nearest = e
		if dd < 2.0 * U:
			crowd += e.global_position
			crowd_n += 1
	if nearest == null:
		_set_move(-ppos if ppos.length() > 2.0 * U else Vector2.ZERO)
		return
	var pref := _pref_now() * U
	var to := nearest.global_position - ppos
	var dir := to / maxf(nd, 0.001)
	var move := Vector2.ZERO
	if nd > pref + 0.4 * U:
		move = dir
	elif nd < pref - 0.4 * U:
		move = -dir
	if crowd_n >= 3 and pref > 1.6 * U: # distance : sortir du paquet
		move += (ppos - crowd / crowd_n).normalized() * 1.5
	move += dir.orthogonal() * _strafe_sign * 0.6
	if ppos.length() > LEASH_U * U:
		move += -ppos.normalized() * 0.8
	_set_move(move)


## Distance voulue : plus courte si un sort 2-4 prêt demande d'aller au contact.
func _pref_now() -> float:
	var pref := base_pref_u
	if player.max_hp <= 0.0 or player.hp / player.max_hp < 0.5:
		return pref
	var cds: Array = player.get_spell_cooldowns()
	for c in cds:
		if c.get("auto", false) or float(c.get("remaining", 1.0)) > 0.0 or c.get("blocked", false):
			continue
		var sp := _spell(int(c.get("slot", 0)))
		if sp != null and sp.trigger_range_u > 0.0:
			pref = minf(pref, maxf(sp.trigger_range_u * 0.8, 0.8))
	return pref


func _spell(slot: int) -> SpellData:
	for s in player.character.spells:
		if s.slot == slot:
			return s
	return null


## {dir: direction de fuite, left: s avant l'impact} si le télégraphe de `e` couvre `ppos`, sinon {}.
func _danger(e: Node2D, ppos: Vector2) -> Dictionary:
	if not (e is Enemy): # nœuds du groupe « enemies » sans télégraphe d'Enemy (jarres, appendices, leurres...)
		return {}
	var w: int = int(e.get(&"_windup"))
	var id := e.get_instance_id()
	if w == Enemy.Windup.NONE or w == Enemy.Windup.AUTO:
		_seen.erase(id)
		return {}
	var left: float = float(e.get(&"_windup_left"))
	var total: float = float(e.get(&"_windup_total"))
	var seen: Dictionary = _seen.get(id, {})
	if seen.is_empty() or int(seen["w"]) != w or float(seen["left"]) < left:
		seen = {"w": w, "ignore": rng.randf() < MISS_CHANCE, "left": left}
		_seen[id] = seen
	seen["left"] = left
	if seen["ignore"] or total - left < REACTION_S:
		return {}
	var target: Vector2 = e.get(&"_target")
	var m := DANGER_MARGIN_U * U
	match w:
		Enemy.Windup.SHOCK:
			return _circle(target, Enemy.SHOCK_RADIUS_U * U + m, ppos, left)
		Enemy.Windup.SLAM:
			return _circle(target, Enemy.BOSS_SLAM_RADIUS_U * U + m, ppos, left)
		Enemy.Windup.STRIKE:
			return _circle(target, Enemy.BOSS_STRIKE_RADIUS_U * U + m, ppos, left)
		Enemy.Windup.CONE:
			return _circle(e.global_position, Enemy.CONE_RANGE_U * U + m, ppos, left)
		Enemy.Windup.LEAP:
			var fwd := Vector2.from_angle(float(e.get(&"_facing")))
			var rel := ppos - e.global_position
			var along := rel.dot(fwd)
			var side := rel.dot(fwd.orthogonal())
			if along > -m and along < Enemy.LEAP_LENGTH_U * U + m and absf(side) < Enemy.LEAP_WIDTH_U * U * 0.5 + m + 26.0:
				var s := 1.0 if side >= 0.0 else -1.0
				return {"dir": fwd.orthogonal() * s, "left": left}
	return {}


func _circle(c: Vector2, r: float, ppos: Vector2, left: float) -> Dictionary:
	var v := ppos - c
	if v.length() > r:
		return {}
	var dir := v.normalized() if v.length_squared() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
	return {"dir": dir, "left": left}
