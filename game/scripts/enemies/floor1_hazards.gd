class_name Floor1Hazards
extends Node2D
## Zones au sol des boss d'étage 1 (Éclusier, Bouvier, Porteuse de jarres) : sillons d'eau, flaques de vase,
## geysers permanents, nappe d'eau. Un nœud par boss (sous le conteneur des monstres), créé par son cerveau.
## Zone = {kind, shape (&"circle" | &"line" | &"none"), pos, dir, len (px), r (rayon ou demi-largeur, px),
## life (s, < 0 = infini), slow (ralentit le joueur dedans : statut &"slow" -30 %, ou `slow_mult` > 0 =
## Player.apply_slow paramétré, ex. 0,8 = -20 % du Bouvier), dmg (dégâts par tick), tick (s), pulse (période
## d'un jaillissement télégraphié, s), wind (télégraphe du jaillissement), trace (reste après la mort), node
## (visuel, fondu en fin de vie), burst (anim d'extra du .tres jouée au jaillissement)}.
## Trace (docs/Design_Boss_Cartes.md §0 « traces au sol ») : à la mort du boss, les zones `trace` restent tant que
## le gros pilier actif charge encore, puis tout se libère. Retour au pool sans mort : release().

const U := 64.0
## Rayon de dégâts du joueur (PlayerHitbox, suit Player.set_hitbox_u ; ex-constante 26 px).
static var PLAYER_R: float:
	get: return PlayerHitbox.radius_px
const MAX_TRACE_S := 150.0
const FADE_S := 0.6
const SLOW_LINGER_S := 0.3 ## traîne du ralentissement paramétré après la sortie de la zone

var boss: Enemy = null ## null après la mort (dégâts alors infligés par ce nœud)
var frames: SpriteFrames = null
var prefix := "Floor1"
var trace := false
var zones: Array[Dictionary] = []
var pulses := 0 ## jaillissements (tests)
var slowed := 0 ## ralentissements infligés (tests)
var _pillar: Node = null
var _life := 0.0
var _fx: Array[Dictionary] = []


static func create(e: Enemy, p_frames: SpriteFrames, p_prefix: String) -> Floor1Hazards:
	var h := Floor1Hazards.new()
	h.name = StringName(p_prefix + "Hazards")
	h.boss = e
	h.frames = p_frames
	h.prefix = p_prefix
	var host := e.get_parent()
	if host != null:
		host.add_child(h)
	return h


func add_zone(z: Dictionary) -> Dictionary:
	var d := {"kind": &"zone", "shape": &"circle", "pos": Vector2.ZERO, "dir": Vector2.RIGHT, "len": 0.0, "r": U,
		"life": -1.0, "age": 0.0, "slow": false, "dmg": 0.0, "tick": 0.5, "tick_cd": 0.0, "pulse": 0.0, "wind": 0.9,
		"pulse_t": 0.0, "shown": false, "trace": false, "node": null, "tele": null, "burst": &"", "burst_px": 68.0, "hits": 0}
	d.merge(z, true)
	if float(d["pulse"]) > 0.0 and d["tele"] == null:
		var t := EnemyTelegraph.new()
		t.name = StringName(prefix + "_pulse_tele")
		add_child(t)
		d["tele"] = t
	zones.append(d)
	return d


func count(kind: StringName) -> int:
	var n := 0
	for z in zones:
		if z["kind"] == kind:
			n += 1
	return n


## Le joueur est-il dans la zone ?
static func inside(z: Dictionary, ppos: Vector2, margin := PLAYER_R) -> bool:
	match z["shape"]:
		&"circle":
			return ppos.distance_to(z["pos"]) <= float(z["r"]) + margin
		&"line":
			var v: Vector2 = ppos - (z["pos"] as Vector2)
			var d: Vector2 = z["dir"]
			var along := v.dot(d)
			return along >= -margin and along <= float(z["len"]) + margin and absf(v.cross(d)) <= float(z["r"]) + margin
	return false


## Mort du boss : les zones `trace` restent tant que le gros pilier actif charge ; sinon tout se libère.
func on_boss_dead() -> void:
	boss = null
	_pillar = null
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(&"pillars"):
			if p is Pillar and (p as Pillar).kind == Pillar.Kind.BIG and (p as Pillar).state == Pillar.STATE_ACTIVE and not (p as Pillar).is_charged():
				_pillar = p
				break
	var i := zones.size() - 1
	while i >= 0:
		if _pillar == null or not zones[i]["trace"]:
			_free_zone(zones[i])
			zones.remove_at(i)
		i -= 1
	if zones.is_empty():
		release()
		return
	trace = true
	_life = 0.0


func release() -> void:
	for z in zones:
		_free_zone(z)
	zones.clear()
	for f in _fx:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_fx.clear()
	queue_free()


func _free_zone(z: Dictionary) -> void:
	if is_instance_valid(z.get("node")):
		(z["node"] as Node).queue_free()
	if is_instance_valid(z.get("tele")):
		(z["tele"] as Node).queue_free()


func _physics_process(delta: float) -> void:
	_life += delta
	if trace:
		var p := _pillar as Pillar
		if _life > MAX_TRACE_S or not is_instance_valid(p) or p.state != Pillar.STATE_ACTIVE:
			release()
			return
	elif boss != null and (not is_instance_valid(boss) or not boss.active):
		boss = null
	_update_fx(delta)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var ppos := player.global_position if player != null else Vector2(INF, INF)
	var i := zones.size() - 1
	while i >= 0:
		var z: Dictionary = zones[i]
		z["age"] = float(z["age"]) + delta
		var life := float(z["life"])
		var n := z.get("node") as CanvasItem
		if life >= 0.0:
			if float(z["age"]) >= life:
				_free_zone(z)
				zones.remove_at(i)
				i -= 1
				continue
			if is_instance_valid(n):
				n.modulate.a = clampf((life - float(z["age"])) / FADE_S, 0.0, 1.0) * float(z.get("alpha", 1.0))
		if player != null:
			_apply(z, player, ppos, delta)
		i -= 1


func _apply(z: Dictionary, player: Node2D, ppos: Vector2, delta: float) -> void:
	if float(z["pulse"]) > 0.0:
		_pulse(z, player, ppos, delta)
		return
	if not inside(z, ppos, PLAYER_R * 0.5):
		return
	if z["slow"] and player.has_method(&"apply_status"):
		if not (player.has_method(&"is_slowed") and player.is_slowed()):
			slowed += 1
		if float(z.get("slow_mult", 0.0)) > 0.0 and player.has_method(&"apply_slow"):
			player.apply_slow(float(z["slow_mult"]), SLOW_LINGER_S, self)
		else:
			player.apply_status(&"slow", {"hit": 0.0, "source": self})
	if float(z["dmg"]) > 0.0:
		z["tick_cd"] = float(z["tick_cd"]) - delta
		if float(z["tick_cd"]) <= 0.0:
			z["tick_cd"] = float(z["tick"])
			_hurt(player, float(z["dmg"]))
			z["hits"] = int(z["hits"]) + 1


## Jaillissement périodique : télégraphe `wind` s avant chaque fin de période, puis éclat + dégâts.
func _pulse(z: Dictionary, player: Node2D, ppos: Vector2, delta: float) -> void:
	var period := float(z["pulse"])
	var wind := float(z["wind"])
	z["pulse_t"] = float(z["pulse_t"]) + delta
	var t := float(z["pulse_t"])
	var tele := z["tele"] as EnemyTelegraph
	if t >= period - wind:
		if not z["shown"]:
			z["shown"] = true
			if is_instance_valid(tele):
				tele.show_circle(z["pos"], float(z["r"]))
			Audio.play(&"telegraph.warn_light.light", z["pos"], -6.0)
		if is_instance_valid(tele):
			tele.set_progress((t - (period - wind)) / wind)
	if t >= period:
		z["pulse_t"] = 0.0
		z["shown"] = false
		if is_instance_valid(tele):
			tele.hide_telegraph()
		pulses += 1
		burst_fx(z["pos"], float(z["r"]), z["burst"], float(z["burst_px"]))
		Audio.play(&"enemy.shockwave.heavy", z["pos"], -4.0)
		if inside(z, ppos):
			_hurt(player, float(z["dmg"]))
			z["hits"] = int(z["hits"]) + 1


func _hurt(player: Node2D, amount: float) -> void:
	if amount <= 0.0:
		return
	if boss != null and is_instance_valid(boss) and boss.active:
		boss._hit_player(player, amount)
	elif player.has_method(&"take_damage"):
		player.take_damage(amount, self)


## Éclat (extra billboard `anim` du .tres, sinon colonne d'eau dessinée) au sol, durée de l'anim.
func burst_fx(pos: Vector2, r_px: float, anim: StringName, src_px := 68.0) -> void:
	var n: Node2D
	var life := 0.7
	if anim != &"" and frames != null and frames.has_animation(anim):
		var s := Floor1Fx.sprite(frames, anim, prefix + "_", 2.2)
		s.scale = Floor1Fx.billboard(r_px * 2.0, src_px)
		s.offset = Vector2(0.0, -18.0)
		s.play(anim)
		life = frames.get_frame_count(anim) / maxf(frames.get_animation_speed(anim), 1.0)
		n = s
	else:
		var f := RecluseFx.make(RecluseFx.Kind.COLUMN, Color(Floor1Fx.CYAN.r, Floor1Fx.CYAN.g, Floor1Fx.CYAN.b, 0.7), 0)
		f.radius = -Iso.lift_logical(2.0 * r_px / U)
		f.width = 1.4 * r_px
		f.color2 = Color(1, 1, 1, 0.9)
		n = f
	n.name = StringName(prefix + "_burst")
	add_child(n)
	n.global_position = pos
	_fx.append({"node": n, "life": life, "max": life})


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
			n.modulate.a = clampf(float(f["life"]) / minf(float(f["max"]), 0.35), 0.0, 1.0)
		i -= 1
