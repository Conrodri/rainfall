class_name MiniPatterns
extends RefCounted
## Bibliothèque de motifs d'attaque réutilisables des mini-boss (MiniBossBrain, data/minibosses.json).
## Chaque motif : begin (télégraphe orienté vers le joueur + anim armée dont la frame d'impact tombe à la
## fin du télégraphe), step (progression, dégâts à l'impact, phase active éventuelle ; vrai = fini),
## harm_point (où le joueur prend le coup, tests). Types : cone, line, charge, projectile_fan, ring,
## circles, summon, leap, beam, burrow. Les sorts suivent le joueur pendant AIM_TRACK de leur télégraphe
## puis se figent (on esquive en lisant la forme figée) ; les autos ne suivent pas.
## Mécaniques de terrain (MiniHazards) : `obstacle` (circles : un bloc par impact) / `obstacles` (ring : N blocs
## sur l'anneau ou dans le disque) = obstacles réels ; `cover` (cone, beam) : les obstacles couvrent le joueur ;
## `gaps` + `gap_u` (ring) : anneau à brèches (jamais d'enfermement) ; `bounces` / `status` (projectile_fan) :
## projectiles qui rebondissent sur les murs / transmettent un statut (burn, poison, frost, slow) ; `jam_s` :
## brouille la minimap du joueur touché.

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PR: float:
	get: return PlayerHitbox.radius_px
const LINE_BACK := 0.3 ## les lignes partent un peu sous le corps (rayon)
const CHAIN_WINDUP := 0.8
const VOLLEY_GAP := 0.25
const EMERGE_WARN := 1.0
const PROJ_LINE_U := 3.0


static func begin(b: MiniBossBrain, p: Dictionary) -> void:
	var wind := float(p["_wind"])
	var anim := StringName(p.get("anim", "attack"))
	match String(p.get("type", "")):
		"cone":
			_show_cones(b, p, false)
			b.vis.play_attack(anim, wind, b.aim)
		"line":
			p["_center"] = b.apos
			_show_lines(b, p)
			b.vis.play_attack(anim, wind, b.aim)
		"charge":
			p["_chain"] = int(p.get("chain", 0))
			_show_charge(b, p)
			b.set_camo(true)
			b.vis.play_attack(anim, wind, b.aim)
		"projectile_fan":
			b.tele(0).show_line(b.e.position, b.aim.angle(), PROJ_LINE_U * U, 0.5 * U, _w(p))
			p["_vol"] = int(p.get("volleys", 1))
			b.vis.play_attack(anim, wind, b.aim)
		"ring":
			p["_c"] = b.apos if String(p.get("center", "self")) == "player" else b.e.position
			_place_gaps(b, p)
			_show_ring(b, p)
			b.vis.play_attack(anim, wind, b.aim)
		"circles":
			_place_circles(b, p)
			b.vis.play_attack(anim, wind, b.aim)
		"summon":
			var rt := b.ring_tele(0)
			var r := float(p.get("ring_u", 3.0)) * U
			rt.global_position = b.e.position
			rt.set_param(r + 0.35 * U, r - 0.35 * U, 0.0)
			b.vis.play_attack(anim, wind, b.aim)
		"leap":
			p["_chain"] = int(p.get("chain", 0))
			_begin_leap(b, p)
		"beam":
			_show_cones(b, p, true)
			b.vis.play_attack(anim, wind, b.aim)
		"burrow":
			p["_stage"] = 0
			b.tele(0).show_circle(b.e.position, b.e.radius_px * 1.6) # creuse : terre qui se soulève sous lui
			b.vis.play_attack(anim, wind, b.aim)


## Un pas du motif ; vrai quand il est terminé.
static func step(b: MiniBossBrain, p: Dictionary, delta: float) -> bool:
	match String(p.get("type", "")):
		"cone":
			return _step_cone(b, p)
		"line":
			return _step_line(b, p)
		"charge":
			return _step_charge(b, p, delta)
		"projectile_fan":
			return _step_fan(b, p)
		"ring":
			return _step_ring(b, p)
		"circles":
			return _step_circles(b, p)
		"summon":
			return _step_summon(b, p)
		"leap":
			return _step_leap(b, p, delta)
		"beam":
			return _step_beam(b, p, delta)
		"burrow":
			return _step_burrow(b, p, delta)
	return true


## Motif interrompu (passage en phase 2) : rien de persistant à défaire hors télégraphes (le cerveau les masque).
static func cancel(b: MiniBossBrain, p: Dictionary) -> void:
	if p.get("_flash") != null:
		b.free_fx(p["_flash"])


static func harm_point(b: MiniBossBrain, p: Dictionary) -> Vector2:
	var e := b.e
	match String(p.get("type", "")):
		"cone":
			return e.position + b.aim * float(p.get("range_u", 2.0)) * U * 0.5
		"line":
			var best: Array = []
			var bo := INF
			for l: Array in _lines(b, p):
				if absf(float(l[4])) < bo:
					bo = absf(float(l[4]))
					best = l
			if best.is_empty():
				return b.ppos
			var mid := (best[0] as Vector2) + Vector2.from_angle(float(best[1])) * float(best[2]) * 0.5
			if String(p.get("from", "self")) == "player":
				return mid
			return (best[0] as Vector2) + Vector2.from_angle(float(best[1])) * minf(float(best[2]) * 0.5, 2.5 * U)
		"charge":
			return e.position + b.aim * minf(3.0 * U, float(p.get("length_u", 8.0)) * U * 0.5)
		"projectile_fan":
			return e.position + b.aim * 3.0 * U
		"ring":
			var c: Vector2 = p.get("_c", e.position)
			var r := float(p.get("radius_u", 3.0)) * U
			var inner := float(p.get("inner_u", 0.0)) * U
			var d := b.ppos - c
			var dir := d.normalized() if d.length_squared() > 1.0 else b.aim
			var gs: Array = p.get("_gaps", [])
			if not gs.is_empty(): # sur les chaînes, loin des brèches
				dir = Vector2.from_angle(float(gs[0]) + PI * 0.5)
			return c + dir * ((r + inner) * 0.5 if inner > 0.0 else r * 0.5)
		"circles":
			var tg: Array = p.get("_targets", [])
			return tg[0] if not tg.is_empty() else b.ppos
		"leap":
			if String(p.get("target", "player")) == "behind":
				return b.ppos
			return p.get("_to", b.ppos)
		"beam":
			var a := float(p.get("_rot", 0.0))
			var angs: Array = p.get("angles_deg", [0])
			return e.position + b.aim.rotated(a + deg_to_rad(float(angs[0]))) * float(p.get("range_u", 6.0)) * U * 0.4
		"burrow":
			return b.ppos
	return e.position + b.aim * 2.0 * U


# --- Géométrie -------------------------------------------------------------------------

static func in_cone(origin: Vector2, angle: float, r: float, half: float, pos: Vector2) -> bool:
	var v := pos - origin
	if v.length() <= PR * 1.5:
		return true
	return v.length() <= r + PR and absf(angle_difference(angle, v.angle())) <= half + 0.15


static func in_line(origin: Vector2, angle: float, length: float, width: float, pos: Vector2) -> bool:
	var l := (pos - origin).rotated(-angle)
	return l.x >= -PR and l.x <= length + PR and absf(l.y) <= width * 0.5 + PR


static func zone_contains(z: Dictionary, pos: Vector2) -> bool:
	var c: Vector2 = z["pos"]
	match String(z["shape"]):
		"line":
			return in_line(c, float(z["angle"]), float(z["len"]), float(z["w"]), pos)
		"ring":
			var d := c.distance_to(pos)
			if z.has("gaps") and in_gap(z["gaps"], float(z["gap_half"]), (pos - c).angle()):
				return false
			return d <= float(z["r"]) + PR and d >= float(z["inner"]) - PR
	return c.distance_to(pos) <= float(z["r"]) + PR


## L'angle `a` tombe-t-il dans une brèche (angles `gaps`, demi-ouverture `half` rad) ?
static func in_gap(gaps: Array, half: float, a: float) -> bool:
	for g in gaps:
		if absf(angle_difference(float(g), a)) < half:
			return true
	return false


## Télégraphe d'un sort qui suit le joueur pendant la première part de l'armement.
static func _tracking(b: MiniBossBrain, p: Dictionary) -> bool:
	return not bool(p.get("auto", false)) and b.state == MiniBossBrain.S.WIND and b.t < float(p["_wind"]) * MiniBossBrain.AIM_TRACK


static func _retarget(b: MiniBossBrain) -> void:
	var to := b.apos - b.e.position
	if to.length_squared() > 1.0:
		b.aim = to.normalized()
		b.face(b.aim)
		b.vis.set_strike_dir(b.aim)


# --- Cône (et rayon canalisé en cône / ligne) ---------------------------------------------

## Poids du télégraphe d'un motif : d'après son coef de dégâts ; un rayon canalisé, un motif à ticks (tick_s) ou à trace au sol (zone) est une zone
## persistante : toujours dessinée (lourde au moins).
static func _w(p: Dictionary) -> int:
	var w := EnemyTelegraph.weight_for_coef(float(p.get("coef", 1.0)))
	if w == EnemyTelegraph.Weight.LIGHT and (p.has("tick_s") or p.has("zone") or String(p.get("type", "")) == "beam"):
		return EnemyTelegraph.Weight.HEAVY
	return w


static func _show_cones(b: MiniBossBrain, p: Dictionary, beam: bool) -> void:
	var angs: Array = p.get("angles_deg", [0]) if beam else [0]
	var rot := float(p.get("_rot", 0.0))
	var r := float(p.get("range_u", 2.5)) * U
	for i in angs.size():
		var a := b.aim.angle() + rot + deg_to_rad(float(angs[i]))
		if String(p.get("shape", "cone")) == "line" and beam:
			b.tele(i).show_line(b.e.position, a, r, float(p.get("width_u", 1.5)) * U, _w(p))
		else:
			b.tele(i).show_cone(b.e.position, a, r, deg_to_rad(float(p.get("half_deg", 45.0))), _w(p))


static func _progress(b: MiniBossBrain, n: int, k: float) -> void:
	for i in n:
		b.tele(i).set_progress(k)


static func _step_cone(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	b.tele(0).set_progress(b.t / wind)
	if b.t < wind:
		return false
	var r := float(p.get("range_u", 2.5)) * U
	var half := deg_to_rad(float(p.get("half_deg", 45.0)))
	b.e._sfx(&"enemy.brute_cone.heavy")
	if in_cone(b.e.position, b.aim.angle(), r, half, b.ppos) and not covered(b, p):
		b.hurt(float(p.get("coef", 1.0)), &"impact", String(p.get("status", "")))
	else:
		b.log_event(&"impact", false, {"covered": covered(b, p)})
	return not _repeat(b, p)


## Le joueur est-il à couvert derrière un obstacle (motifs `cover` : souffle de l'Ours) ?
static func covered(b: MiniBossBrain, p: Dictionary) -> bool:
	return bool(p.get("cover", false)) and is_instance_valid(b.hazards) and b.hazards.blocks_segment(b.e.position, b.ppos)


## Coup répété (meule, claquement double) : réarme un court télégraphe au même endroit.
static func _repeat(b: MiniBossBrain, p: Dictionary) -> bool:
	if int(p.get("_repeat", 0)) <= 0:
		return false
	p["_repeat"] = int(p["_repeat"]) - 1
	p["_wind"] = maxf(float(p.get("repeat_gap", 0.3)), Balance.BOSS_PACE_COMBO_GAP_S) # écart d'enchaînement lisible
	p["_armed"] = true
	b.t = 0.0
	b.state = MiniBossBrain.S.WIND
	b.pace.wind(StringName(p.get("_cat", &"spell"))) # planté entre deux coups (sans arrêt sur image : l'anim réarme)
	var anim := StringName(p.get("anim", "attack"))
	match String(p.get("type", "")):
		"cone":
			_show_cones(b, p, false)
		"line":
			_show_lines(b, p)
		"ring":
			_show_ring(b, p)
	b.vis.play_attack(anim, float(p["_wind"]), b.aim)
	return true


static func _step_beam(b: MiniBossBrain, p: Dictionary, delta: float) -> bool:
	var wind := float(p["_wind"])
	var angs: Array = p.get("angles_deg", [0])
	if b.state == MiniBossBrain.S.WIND:
		if _tracking(b, p):
			_retarget(b)
			_show_cones(b, p, true)
		_progress(b, angs.size(), b.t / wind)
		b.light_boost(0.8 * clampf(b.t / wind, 0.0, 1.0))
		if b.t < wind:
			return false
		b.state = MiniBossBrain.S.ACTIVE
		p["_ch"] = 0.0
		p["_tick"] = 0.0
		var to := b.ppos - b.e.position
		p["_sdir"] = signf(angle_difference(b.aim.angle(), to.angle())) if to.length_squared() > 1.0 else 1.0
		if float(p["_sdir"]) == 0.0:
			p["_sdir"] = 1.0
		b.e._sfx(&"enemy.shockwave.heavy", -2.0, true)
		b.pace.impact(StringName(p.get("_cat", &"spell"))) # le rayon jaillit : arrêt sur image (canalisation plantée)
		p["_impacted"] = true
	p["_ch"] = float(p["_ch"]) + delta
	var channel := float(p.get("channel_s", 1.5))
	var sweep := deg_to_rad(float(p.get("sweep_deg", 0.0)))
	p["_rot"] = sweep * clampf(float(p["_ch"]) / channel, 0.0, 1.0) * float(p["_sdir"])
	_show_cones(b, p, true)
	_progress(b, angs.size(), 1.0)
	p["_tick"] = float(p["_tick"]) - delta
	if float(p["_tick"]) <= 0.0:
		p["_tick"] = float(p.get("tick_s", 0.5))
		var r := float(p.get("range_u", 6.0)) * U
		var hit := false
		for a in angs:
			var ang := b.aim.angle() + float(p["_rot"]) + deg_to_rad(float(a))
			if String(p.get("shape", "cone")) == "line":
				hit = hit or in_line(b.e.position, ang, r, float(p.get("width_u", 1.5)) * U, b.ppos)
			else:
				hit = hit or in_cone(b.e.position, ang, r, deg_to_rad(float(p.get("half_deg", 45.0))), b.ppos)
		var cov := hit and covered(b, p)
		if hit and not cov:
			b.hurt(float(p.get("coef", 0.5)), &"tick", String(p.get("status", "")))
		else:
			b.log_event(&"tick", false, {"covered": cov})
	return float(p["_ch"]) >= channel


# --- Lignes -----------------------------------------------------------------------------------

## Lignes du motif : [origine, angle, longueur px, largeur px, décalage u].
static func _lines(b: MiniBossBrain, p: Dictionary) -> Array:
	var out: Array = []
	var angs: Array = p.get("angles_deg", [0])
	var offs: Array = p.get("offsets_u", [0])
	var length := float(p.get("length_u", 6.0)) * U
	var w := float(p.get("width_u", 1.0)) * U
	var from_player := String(p.get("from", "self")) == "player"
	for a in angs:
		var d := b.aim.rotated(deg_to_rad(float(a)))
		for o in offs:
			var ortho := d.orthogonal() * float(o) * U
			var origin: Vector2
			if from_player:
				origin = (p.get("_center", b.apos) as Vector2) - d * length * 0.5 + ortho
			else:
				origin = b.e.position - d * b.e.radius_px * LINE_BACK + ortho
			out.append([origin, d.angle(), length, w, float(o)])
	return out


static func _show_lines(b: MiniBossBrain, p: Dictionary) -> void:
	var ls := _lines(b, p)
	for i in ls.size():
		var l: Array = ls[i]
		b.tele(i).show_line(l[0], float(l[1]), float(l[2]), float(l[3]), _w(p))
	p["_n"] = ls.size()


static func _step_line(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	if b.state == MiniBossBrain.S.ACTIVE: # éclat du rayon (Jugement) : forme provisoire
		if b.t >= float(p.get("flash_s", 0.0)):
			b.free_fx(p.get("_flash"))
			p.erase("_flash")
			return not _repeat(b, p)
		return false
	if _tracking(b, p):
		_retarget(b)
		if String(p.get("from", "self")) == "player":
			p["_center"] = b.apos
		_show_lines(b, p)
	_progress(b, int(p.get("_n", 1)), b.t / wind)
	if b.t < wind:
		return false
	var hit := false
	var ls := _lines(b, p)
	for l: Array in ls:
		if in_line(l[0], float(l[1]), float(l[2]), float(l[3]), b.ppos):
			hit = true
	b.e._sfx(&"enemy.brute_cone.heavy")
	if hit:
		var pull := float(p.get("pull_u", 0.0)) * U
		if pull > 0.0:
			var to := b.e.position - b.ppos
			b.move_player(to.normalized() * minf(pull, maxf(to.length() - b.e.radius_px - PR, 0.0)))
		var push := float(p.get("push_u", 0.0)) * U
		if push > 0.0:
			b.move_player(b.aim * push)
		b.hurt(float(p.get("coef", 1.0)), &"impact", String(p.get("status", "")))
	else:
		b.log_event(&"impact", false)
	var zc: Dictionary = p.get("zone", {})
	if not zc.is_empty():
		for l: Array in ls:
			b.add_zone({"shape": "line", "pos": l[0], "angle": float(l[1]), "len": float(l[2]), "w": float(l[3])}, zc)
	var fs := float(p.get("flash_s", 0.0))
	if fs > 0.0:
		b.hide_teles()
		var lc := MiniBossBrain.color_of(b.cfg.get("light", {}).get("color"), Color(0.6, 0.9, 1.0))
		var f := b.make_fx(RecluseFx.Kind.BEAM, Color(lc.r, lc.g, lc.b, 0.7))
		var l0: Array = ls[0]
		f.global_position = l0[0]
		f.rotation = float(l0[1])
		f.width = float(l0[3])
		f.color2 = Color(1, 1, 1, 0.9)
		f.set_param(float(l0[2]))
		p["_flash"] = f
		LightRig.flash(b.e.global_position, &"boss", 0.3)
		b.pace.impact(StringName(p.get("_cat", &"spell"))) # impact à la frame du coup, pas à la fin de l'éclat
		p["_impacted"] = true
		b.state = MiniBossBrain.S.ACTIVE
		b.t = 0.0
		return false
	p.erase("_impacted") # coup répété : l'impact final passe par BossPace.strike
	return not _repeat(b, p)


# --- Charge -------------------------------------------------------------------------------------

static func _show_charge(b: MiniBossBrain, p: Dictionary) -> void:
	var back := b.e.radius_px * 0.6
	b.tele(0).show_line(b.e.position - b.aim * back, b.aim.angle(), float(p.get("length_u", 10.0)) * U + back, float(p.get("width_u", 2.0)) * U, _w(p))


static func _step_charge(b: MiniBossBrain, p: Dictionary, delta: float) -> bool:
	var e := b.e
	if b.state == MiniBossBrain.S.WIND:
		var k := clampf(b.t / float(p["_wind"]), 0.0, 1.0)
		if k < 0.55:
			_retarget(b)
			_show_charge(b, p)
		b.tele(0).set_progress(k)
		b.light_boost(1.2 * k * k)
		if b.t < float(p["_wind"]):
			return false
		b.set_camo(false)
		b.state = MiniBossBrain.S.ACTIVE
		p["_moving"] = true
		b.pace.act() # ruée : mouvement pendant l'action seulement
		p["_left"] = float(p.get("length_u", 10.0)) * U
		p["_hit"] = false
		b.log_event(&"dash", false)
		e._sfx(&"enemy.shockwave.heavy", 0.0, true)
	var stepl := minf(float(p.get("speed_u", 12.0)) * U * delta, float(p["_left"]))
	p["_left"] = float(p["_left"]) - stepl
	var want := e.position + b.aim * stepl
	var np := e.nav.resolve(want, e.radius_px) if e.nav else want
	var blocked := np.distance_squared_to(want) > 4.0
	if not blocked and is_instance_valid(b.hazards) and b.hazards.blocked_at(np, e.radius_px * 0.8):
		np = e.position # s'écrase sur un rocher / bloc (fenêtre de punition comme contre un mur)
		blocked = true
	e.position = np
	b.face(b.aim)
	b.vis.set_action(&"run")
	if not bool(p["_hit"]) and b.player != null and e.position.distance_to(b.ppos) <= e.radius_px + PR:
		p["_hit"] = true
		b.move_player(b.aim * float(p.get("push_u", 0.0)) * U)
		b.hurt(float(p.get("coef", 1.6)), &"contact", String(p.get("status", "")))
	if float(p["_left"]) > 0.0 and not blocked:
		return false
	b.tele(0).hide_telegraph()
	b.light_boost(0.0)
	p["_moving"] = false
	if blocked and float(p.get("stun_wall_s", 0.0)) > 0.0:
		b.set_stun(float(p["stun_wall_s"])) # écrasé contre le mur : fenêtre de punition
		e._sfx(&"enemy.shockwave.heavy", 2.0, true)
		return true
	if int(p["_chain"]) > 0:
		p["_chain"] = int(p["_chain"]) - 1
		_retarget(b)
		p["_wind"] = CHAIN_WINDUP
		p["_armed"] = true
		b.t = 0.0
		b.state = MiniBossBrain.S.WIND
		b.pace.wind(&"charge") # arrêt net entre deux ruées
		_show_charge(b, p)
		b.vis.play_attack(StringName(p.get("anim", "cast_a")), CHAIN_WINDUP, b.aim)
		return false
	return true


# --- Éventail de projectiles ------------------------------------------------------------------

static func _step_fan(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	if b.state == MiniBossBrain.S.WIND:
		b.tele(0).set_progress(b.t / wind)
		if b.t < wind:
			return false
		b.tele(0).hide_telegraph()
		b.state = MiniBossBrain.S.ACTIVE
		b.t = VOLLEY_GAP # première salve tout de suite (frame d'impact)
		b.pace.impact(StringName(p.get("_cat", &"mini_auto"))) # salves suivantes : toujours planté
		p["_impacted"] = true
	if b.t < VOLLEY_GAP:
		return false
	b.t = 0.0
	var e := b.e
	var to := b.apos - e.position
	var dir := to.normalized() if to.length_squared() > 1.0 else b.aim
	var n := maxi(int(p.get("count", 1)), 1)
	var spread := deg_to_rad(float(p.get("spread_deg", 0.0)))
	var spd := float(p.get("speed_u", 8.0)) * U
	var dmg := Balance.mini_attack_damage(e.damage, float(p.get("coef", 0.8))) * b.damage_out_mult()
	var fired := 0
	var bounces := int(p.get("bounces", 0))
	var st := String(p.get("status", ""))
	if bounces > 0 or st != "": # projectiles spéciaux (rebonds, statut transmis) : MiniHazards
		var h := b.haz()
		if h != null:
			var col: Color = MiniBossBrain.STATUS_COLORS.get(st, MiniBossBrain.color_of(p.get("color"), Color(0.85, 0.82, 0.78)))
			for i in n:
				var a := 0.0 if n == 1 else -spread * 0.5 + spread * float(i) / float(n - 1)
				var d := dir.rotated(a)
				h.fire(e.position + d * e.radius_px, d * spd, dmg, st, bounces, float(p.get("radius_u", 0.2)), col)
				fired += 1
	elif e.director != null and e.director.has_method(&"fire_projectile"):
		for i in n:
			var a := 0.0 if n == 1 else -spread * 0.5 + spread * float(i) / float(n - 1)
			var d := dir.rotated(a)
			e.director.fire_projectile(e, e.position + d * e.radius_px, d * spd, dmg)
			fired += 1
	e._sfx(&"enemy.shot.medium")
	b.log_event(&"volley", false, {"spawned": fired})
	p["_vol"] = int(p["_vol"]) - 1
	return int(p["_vol"]) <= 0


# --- Anneau ---------------------------------------------------------------------------------------

## Brèches d'un anneau `gaps` (Cercle de chaînes) : la première du côté du boss (±1 rad), les autres réparties (±0,6).
static func _place_gaps(b: MiniBossBrain, p: Dictionary) -> void:
	var n := int(p.get("gaps", 0))
	if n <= 0:
		p.erase("_gaps")
		return
	var c: Vector2 = p["_c"]
	var r := (float(p.get("radius_u", 3.0)) + float(p.get("inner_u", 0.0))) * 0.5 * U
	var to := b.e.position - c
	var g1 := (to.angle() if to.length_squared() > 1.0 else b.aim.angle()) + b.rng.randf_range(-1.0, 1.0)
	var gs: Array = []
	for i in n:
		gs.append(g1 + TAU * i / n + (b.rng.randf_range(-0.6, 0.6) if i > 0 else 0.0))
	p["_gaps"] = gs
	p["_gap_half"] = float(p.get("gap_u", 2.0)) * U * 0.5 / maxf(r, 1.0)


static func _show_ring(b: MiniBossBrain, p: Dictionary) -> void:
	var c: Vector2 = p["_c"]
	var r := float(p.get("radius_u", 3.0)) * U
	var inner := float(p.get("inner_u", 0.0)) * U
	if p.has("_gaps"):
		var g := b.gap_tele()
		g.global_position = c
		g.size = (r + inner) * 0.5
		g.width = maxf(r - inner, 16.0)
		g.gaps = p["_gaps"]
		g.gap_half = float(p["_gap_half"])
		g.progress = 0.0
		g.queue_redraw()
	elif inner > 0.0:
		var f := b.ring_tele(0)
		f.global_position = c
		f.set_param(r, inner, 0.0)
	else:
		b.tele(0).show_circle(c, r, _w(p))


static func _step_ring(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	var r := float(p.get("radius_u", 3.0)) * U
	var inner := float(p.get("inner_u", 0.0)) * U
	var k := clampf(b.t / wind, 0.0, 1.0)
	if p.has("_gaps"):
		var g := b.gap_tele()
		if absf(g.progress - k) > 0.01:
			g.progress = k
			g.queue_redraw()
	elif inner > 0.0:
		b.ring_tele(0).set_param(r, inner, k)
	else:
		b.tele(0).set_progress(k)
	b.light_boost(0.6 * k)
	if b.t < wind:
		return false
	var c: Vector2 = p["_c"]
	var d := c.distance_to(b.ppos)
	b.e._sfx(&"enemy.shockwave.heavy", 1.0, true)
	LightRig.flash(c, &"boss", 0.3)
	var gaps: Array = p.get("_gaps", [])
	var in_band := d <= r + PR and d >= inner - PR and not (not gaps.is_empty() and in_gap(gaps, float(p["_gap_half"]), (b.ppos - c).angle()))
	if in_band:
		var pull := float(p.get("pull_u", 0.0)) * U
		if pull > 0.0 and d > 1.0:
			b.move_player((c - b.ppos).normalized() * minf(pull, maxf(d - b.e.radius_px - PR, 0.0)))
		var push := float(p.get("push_u", 0.0)) * U
		if push > 0.0:
			var away := b.ppos - c
			b.move_player((away.normalized() if away.length_squared() > 1.0 else b.aim) * push)
		b.hurt(float(p.get("coef", 1.2)), &"impact", String(p.get("status", "")))
	else:
		b.log_event(&"impact", false)
	var zc: Dictionary = p.get("zone", {})
	if not zc.is_empty():
		var z := {"shape": "ring" if inner > 0.0 else "circle", "pos": c, "r": r, "inner": inner}
		if not gaps.is_empty():
			z["gaps"] = gaps.duplicate()
			z["gap_half"] = float(p["_gap_half"])
		b.add_zone(z, zc)
	_drop_obstacles(b, p, c, r, inner)
	return not _repeat(b, p)


## Obstacles laissés par un motif (`obstacles` : {count, r_u, life_s, style, at: ring | area}) : rochers du
## Colosse sur l'onde de choc, tas d'os du Porte-ossuaire dans l'effondrement.
static func _drop_obstacles(b: MiniBossBrain, p: Dictionary, c: Vector2, r: float, inner: float) -> void:
	var oc: Dictionary = p.get("obstacles", {})
	if oc.is_empty():
		return
	var h := b.haz()
	if h == null:
		return
	var n := maxi(int(oc.get("count", 3)), 1)
	var a0 := b.rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * i / n + b.rng.randf_range(-0.3, 0.3)
		var dist := (inner + r) * 0.5 if String(oc.get("at", "ring")) == "ring" else b.rng.randf_range(0.3, 0.8) * r
		h.add_obstacle(c + Vector2.from_angle(a) * dist, float(oc.get("r_u", 0.5)), float(oc.get("life_s", 5.0)), StringName(oc.get("style", "rock")))
	b.log_event(&"obstacles", false, {"spawned": n})


# --- Cercles au sol -------------------------------------------------------------------------------

static func _place_circles(b: MiniBossBrain, p: Dictionary) -> void:
	var n := maxi(int(p.get("count", 1)), 1)
	var r := float(p.get("radius_u", 1.5)) * U
	var spread := float(p.get("spread_u", 0.0)) * U
	var tg: Array = [b.walkable(b.apos)]
	var tries := 0
	while tg.size() < n and tries < 60:
		tries += 1
		var q: Vector2 = b.apos + Vector2.from_angle(b.rng.randf() * TAU) * b.rng.randf_range(r * 1.6, maxf(spread, r * 2.0) + r)
		q = b.walkable(q)
		var ok := true
		for o: Vector2 in tg:
			if o.distance_to(q) < r * 1.9:
				ok = false
				break
		if ok or tries > 40:
			tg.append(q)
	p["_targets"] = tg
	p["_done"] = []
	for i in tg.size():
		b.tele(i).show_circle(tg[i], r, _w(p))
		(p["_done"] as Array).append(false)


static func _step_circles(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	var stag := float(p.get("stagger_s", 0.0))
	var r := float(p.get("radius_u", 1.5)) * U
	var tg: Array = p["_targets"]
	var done: Array = p["_done"]
	var all := true
	for i in tg.size():
		if done[i]:
			continue
		var ti := wind + stag * i
		b.tele(i).set_progress(b.t / ti)
		if b.t < ti:
			all = false
			continue
		done[i] = true
		b.tele(i).hide_telegraph()
		var c: Vector2 = tg[i]
		b.e._sfx(&"enemy.shockwave.heavy", -2.0, true)
		LightRig.flash(c, StringName(b.cfg.get("light", {}).get("preset", "boss")), 0.25)
		if c.distance_to(b.ppos) <= r + PR:
			b.hurt(float(p.get("coef", 1.0)), &"impact", String(p.get("status", "")), {"circle": i})
		else:
			b.log_event(&"impact", false, {"circle": i})
		var zc: Dictionary = p.get("zone", {})
		if not zc.is_empty():
			b.add_zone({"shape": "circle", "pos": c, "r": r}, zc)
		var oc: Dictionary = p.get("obstacle", {})
		if not oc.is_empty() and b.haz() != null: # bloc de glace laissé par chaque stalactite
			b.hazards.add_obstacle(c, float(oc.get("r_u", 0.5)), float(oc.get("life_s", 4.0)), StringName(oc.get("style", "ice")))
	return all


# --- Invocation -------------------------------------------------------------------------------------

static func _step_summon(b: MiniBossBrain, p: Dictionary) -> bool:
	var wind := float(p["_wind"])
	var r := float(p.get("ring_u", 3.0)) * U
	b.ring_tele(0).set_param(r + 0.35 * U, r - 0.35 * U, b.t / wind)
	if b.t < wind:
		return false
	var n := maxi(int(p.get("count", 4)), 1)
	var tier := int(p.get("tier", 1))
	var hpf := float(p.get("hp_frac", 0.5))
	var hatch := float(p.get("hatch_s", 0.0))
	var made := 0
	for i in n:
		var pos := b.e.position + Vector2.from_angle(b.aim.angle() + TAU * float(i) / float(n)) * r
		if hatch > 0.0:
			b.add_egg(b.walkable(pos), hatch, tier, hpf)
			made += 1
		elif b.summon_at(pos, tier, hpf, StringName(p.get("affix", "")) if i == 0 else &"") != null:
			made += 1
	b.e._sfx(&"enemy.shockwave.heavy", -4.0, true)
	b.log_event(&"spawn", false, {"spawned": made})
	return true


# --- Bond / envol / pas de brume -------------------------------------------------------------------

static func _leap_target(b: MiniBossBrain, p: Dictionary) -> Vector2:
	var to := b.apos
	if String(p.get("target", "player")) == "behind":
		var d := b.apos - b.e.position
		to = b.apos + (d.normalized() if d.length_squared() > 1.0 else b.aim) * float(p.get("behind_u", 1.5)) * U
	return b.walkable(to)


static func _begin_leap(b: MiniBossBrain, p: Dictionary) -> void:
	p["_to"] = _leap_target(b, p)
	p["_moving"] = false
	b.tele(0).show_circle(p["_to"], float(p.get("radius_u", 2.5)) * U, _w(p))
	b.vis.play_attack(StringName(p.get("anim", "cast_b")), float(p["_wind"]) + float(p.get("air_s", 0.5)), b.aim)


static func _step_leap(b: MiniBossBrain, p: Dictionary, delta: float) -> bool:
	var e := b.e
	var wind := float(p["_wind"])
	var air := maxf(float(p.get("air_s", 0.5)), 0.05)
	if b.state == MiniBossBrain.S.WIND:
		if b.t < wind * MiniBossBrain.AIM_TRACK:
			p["_to"] = _leap_target(b, p)
			b.tele(0).global_position = p["_to"]
			_retarget(b)
		b.tele(0).set_progress(b.t / (wind + air))
		if b.t < wind:
			return false
		b.state = MiniBossBrain.S.ACTIVE
		p["_moving"] = true
		b.pace.act() # bond : mouvement pendant l'action seulement
		p["_from"] = e.position
		p["_air"] = b.t - wind # le dépassement de cette frame compte déjà dans le vol (impact calé sur l'anim)
		if p.get("vanish", false):
			b.set_hidden(true)
	else:
		p["_air"] = float(p["_air"]) + delta
	var u := clampf(float(p["_air"]) / air, 0.0, 1.0)
	e.position = (p["_from"] as Vector2).lerp(p["_to"], u)
	b.tele(0).set_progress((wind + float(p["_air"])) / (wind + air))
	if u < 1.0:
		return false
	e.position = b.walkable(p["_to"])
	if p.get("vanish", false):
		b.set_hidden(false)
	b.tele(0).hide_telegraph()
	e._sfx(&"enemy.shockwave.heavy", 2.0, true)
	LightRig.flash(e.global_position, StringName(b.cfg.get("light", {}).get("preset", "boss")), 0.35)
	var r := float(p.get("radius_u", 2.5)) * U
	if e.position.distance_to(b.ppos) <= r + PR:
		var push := float(p.get("push_u", 0.0)) * U
		if push > 0.0:
			var away := b.ppos - e.position
			b.move_player((away.normalized() if away.length_squared() > 1.0 else b.aim) * push)
		b.hurt(float(p.get("coef", 1.3)), &"land", String(p.get("status", "")))
	else:
		b.log_event(&"land", false)
	p["_moving"] = false
	var zc: Dictionary = p.get("zone", {})
	if not zc.is_empty(): # éclaboussure (envol du Héron) : flaque d'eau au point de chute
		b.add_zone({"shape": "circle", "pos": e.position, "r": r * 0.8}, zc)
	if int(p["_chain"]) > 0: # bonds en chaîne
		p["_chain"] = int(p["_chain"]) - 1
		p["_wind"] = CHAIN_WINDUP
		p["_armed"] = true
		b.t = 0.0
		b.state = MiniBossBrain.S.WIND
		b.pace.wind(&"charge") # réception : planté jusqu'au bond suivant (l'anim réarme : pas d'arrêt sur image)
		_retarget(b)
		_begin_leap(b, p)
		return false
	return true


# --- Enfouissement -----------------------------------------------------------------------------------

static func _step_burrow(b: MiniBossBrain, p: Dictionary, delta: float) -> bool:
	var e := b.e
	var wind := float(p["_wind"])
	var under := maxf(float(p.get("under_s", 2.0)), EMERGE_WARN + 0.1)
	var r := float(p.get("radius_u", 3.0)) * U
	match int(p["_stage"]):
		0: # creuse
			b.tele(0).set_progress(b.t / wind)
			if b.t < wind:
				return false
			b.log_event(&"dig", false)
			b.tele(0).hide_telegraph()
			b.set_hidden(true)
			b.state = MiniBossBrain.S.ACTIVE
			p["_stage"] = 1
			p["_moving"] = true
			b.pace.act() # sous terre : se déplace
			p["_to"] = b.walkable(b.apos)
			b.t = 0.0
			return false
		1: # sous terre : suit le joueur, puis alerte figée sous lui
			if b.t < under - EMERGE_WARN:
				p["_to"] = b.walkable(b.apos)
				e.position = e.position.move_toward(p["_to"], e.speed_px * 2.5 * delta)
				return false
			p["_stage"] = 2
			p["_armed"] = true
			p["_t2"] = b.t
			b.tele(0).show_circle(p["_to"], r, _w(p))
			b.vis.play_attack(StringName(p.get("anim", "cast_b")), EMERGE_WARN, b.aim)
			e._sfx(&"telegraph.boss.heavy", 0.0, true)
			return false
		_: # jaillit
			var k := (b.t - float(p["_t2"])) / EMERGE_WARN
			b.tele(0).set_progress(k)
			if k < 1.0:
				return false
			e.position = p["_to"]
			b.set_hidden(false)
			b.tele(0).hide_telegraph()
			e._sfx(&"enemy.shockwave.heavy", 2.0, true)
			if e.position.distance_to(b.ppos) <= r + PR:
				b.hurt(float(p.get("coef", 1.4)), &"emerge", String(p.get("status", "")))
			else:
				b.log_event(&"emerge", false)
			p["_moving"] = false
			return true
