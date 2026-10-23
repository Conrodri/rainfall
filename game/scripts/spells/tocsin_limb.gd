class_name TocsinLimb
extends Node2D
## Membre lancé de Tocsin (Design_Personnages §1.3) : objet du monde, piloté par TocsinKit.
## - Bras-grappin (`arm`) : ALLER (couloir, 150 %, accroche jusqu'au plafond de 6 points) -> RETOUR (traîne les
##   accrochés jusqu'au point de dépôt, 2 u devant Tocsin) -> PINCE 2,5 s (paquet emprisonné) -> AU SOL
##   (ramassable ; disparaît quand sa recharge finit). Ramassé pendant la pince : prisonniers libérés.
## - Jambe (`leg`) : couloir 5 u × 1,5 u en 0,4 s, 300 %, poussée massive (×1,5 sur les prisonniers, qui sont
##   libérés), « quilles » (un poussé qui en percute un autre lui transmet 50 % et 100 % des dégâts de base),
##   puis AU SOL (ramassable).
## - Tête-cloche (`head`) : lob 0,9 s (arc + ombre), tintement 0,3 s (anneau), explosion 4 u, 1 000 %
##   (+50 % sur les emprisonnés / accrochés), poussée 2 u × masse ; jamais ramassable.
## Variantes (docs/Variantes_Sorts.md §2.3) : `harpoon` (Bras-harpon : tir droit jusqu'au premier monstre, planté
## 2,5 s sur lui, Tocsin tiré par le kit puis bras au sol) et `smoke` (Tête-fumigène : au lieu de l'explosion, zone
## de fumée de 5 s, 10 ticks, étourdissement d'entrée).
## Accrochés / emprisonnés : statut `imprisoned` d'Enemy (Enemy.imprison, partagé avec Arpenteuse) rafraîchi à
## chaque frame + position tenue (Enemy.hold_at) ; libération = Enemy.release_imprison. Boss jamais accrochés.

enum Phase { OUT, BACK, CLAMP, GROUND, FLY, RING, DONE, HOOKED, SMOKE }

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const WALL_MASK := 1
const VISUAL_SCALE := Vector2(0.70710678, 1.4142136) ## = Visual du joueur (rig CREA, billboard)
const VISUAL_OFFSET := Vector2(0, -40.32) ## pivot des pieds 96/136,32 dans la cellule 192
const HOLD_REFRESH_S := 0.25 ## emprisonnement rafraîchi à chaque frame : tombe seul si le membre disparaît
const QUILLE_TRACK_S := 0.35
const QUILLE_MIN_PX := 6.0 ## recul restant sous lequel un poussé ne renverse plus rien

var kind: StringName = &"arm"
var harpoon := false ## Bras-harpon
var smoke := false ## Tête-fumigène
var hooked: Node2D = null ## harpon : monstre harponné
var _smoke_ticks := 0
var key: StringName = &"arm_l"
var kit: TocsinKit = null
var caster: SpellCaster = null
var spell: SpellData = null
var phase := Phase.OUT
var dir := Vector2.RIGHT
var speed_px := 1024.0
var travel_left_px := 0.0
var half_width_px := 38.4
var lateral := 0.0 ## décalage latéral du dépôt (u), deux paquets côte à côte
var start := Vector2.ZERO
var target := Vector2.ZERO
var radius_px := 256.0
var t := 0.0
var captured: Array = [] ## {e, off: Vector2 (aller/retour) | pos: Vector2 (pince)}
var points := 0
var hit := {} ## instance_id -> true (un coup par membre)
var pushed: Array = [] ## quilles : {e, t, struck: Dictionary}
var pickup: GroundPickup = null
var sprite: AnimatedSprite2D = null
var shadow: Sprite2D = null
var _light: LightRig.Handle = null
var ring: AnimatedSprite2D = null ## tête : télégraphe `head_ring` (T6) posé au sol sur la cible, frère du membre
var _frames: Dictionary = {} ## nom -> SpriteFrames chargées


# --- Création (TocsinKit._launch) ----------------------------------------------------------------

func _new_sprite() -> void:
	var y := 0.0
	if sprite != null:
		y = sprite.position.y
		sprite.queue_free()
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.scale = VISUAL_SCALE
	sprite.offset = VISUAL_OFFSET
	sprite.position.y = y
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)


func setup_visual() -> void:
	_new_sprite()
	if kind == &"head":
		var tex: Texture2D = AmbianceTextures.get_tex(&"shadow_blob_256")
		if tex != null:
			shadow = Sprite2D.new()
			shadow.texture = tex
			shadow.scale = Vector2.ONE * (0.9 * Balance.UNIT_PX / maxf(tex.get_width(), 1.0))
			shadow.modulate = Color(0, 0, 0, 0.45)
			shadow.z_index = -1
			add_child(shadow)
			move_child(shadow, 0)
	_light = LightRig.attach(self, &"tocsin_limb")
	_play(StringName("%s_fly" % kind), dir)
	if kind == &"head":
		_spawn_ring()


## Anneau de tintement (TOP) sur le point de chute, dès le lob : discret pendant le vol, plein au tintement.
func _spawn_ring() -> void:
	var parent := get_parent()
	if parent == null or not ResourceLoader.exists(TocsinKit.HEAD_RING_FRAMES):
		return
	var sf := load(TocsinKit.HEAD_RING_FRAMES) as SpriteFrames
	if sf == null or not sf.has_animation(&"default"):
		return
	ring = AnimatedSprite2D.new()
	ring.name = "HeadRing"
	ring.z_index = -1
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(ring)
	ring.global_position = target
	EmissiveOverlay.apply(ring, sf)
	var k := radius_px / TocsinKit.HEAD_RING_PX
	ring.scale = Vector2(k, k)
	ring.modulate.a = 0.35
	ring.play(&"default")


## Anim `<base>_<dir>` du SpriteFrames du membre (tocsin_<base>.tres) ; absent = rien (le repli _draw reste).
func _play(base: StringName, d: Vector2) -> void:
	if sprite == null:
		return
	var sf: SpriteFrames = _frames.get(base)
	if sf == null and not _frames.has(base):
		var p := String(TocsinKit.ASSET_DIR) + "tocsin_%s.tres" % base
		if ResourceLoader.exists(p):
			sf = load(p) as SpriteFrames
		_frames[base] = sf
	if sf == null:
		sprite.visible = false
		queue_redraw()
		return
	var i := roundi(d.angle() / (TAU / 8.0))
	var anim := StringName("%s_%s" % [base, DIRS[(i % 8 + 8) % 8]])
	if not sf.has_animation(anim):
		return
	if sprite.sprite_frames != sf:
		_new_sprite() # autre ressource : sprite neuf (l'émission synchronisée ne connaît pas les anims de l'autre)
		sprite.sprite_frames = sf
		sprite.animation = anim
		EmissiveOverlay.apply(sprite, sf)
	sprite.visible = true
	sprite.play(anim)


# --- Boucle ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	step(delta)


## Le rendu suit aussi la position tenue (le Director a pu déplacer un prisonnier après nous).
func _process(_delta: float) -> void:
	_hold_all()


## Public pour les tests.
func step(delta: float) -> void:
	if kit == null or not is_instance_valid(kit) or kit.player == null:
		queue_free()
		return
	t += delta
	match phase:
		Phase.OUT:
			if harpoon:
				_step_harpoon(delta)
			else:
				_step_out(delta)
		Phase.HOOKED:
			_step_hooked(delta)
		Phase.SMOKE:
			_step_smoke(delta)
		Phase.BACK:
			_step_back(delta)
		Phase.CLAMP:
			if t >= TocsinKit.CLAMP_S:
				release_all(TocsinKit.ARM_RELEASE_SLOW_PCT, TocsinKit.ARM_RELEASE_SLOW_S)
				phase = Phase.GROUND
				_play(&"arm_ground", dir)
		Phase.FLY:
			_step_fly()
		Phase.RING:
			if ring != null:
				ring.modulate.a = 1.0
			queue_redraw()
			if t >= TocsinKit.HEAD_RING_S:
				_blast()
	if not pushed.is_empty():
		_step_quilles(delta)
	_hold_all()


func _step_out(delta: float) -> void:
	var from := global_position
	var step_px := minf(speed_px * delta, travel_left_px)
	var to := from + dir * step_px
	var wall := _wall_between(from, to)
	if wall != Vector2.INF:
		to = wall - dir * 4.0
		travel_left_px = 0.0
	else:
		travel_left_px -= step_px
	global_position = to
	_sweep(from, to)
	if travel_left_px <= 0.0:
		if kind == &"arm":
			phase = Phase.BACK
			t = 0.0
			_play(&"arm_fly", -dir)
		else: # jambe : couchée là où elle s'arrête, botte vers le haut
			_to_ground()


## Bras-harpon : avance en ligne droite et s'arrête au premier monstre touché (le plus proche le long du tir) ou au mur.
func _step_harpoon(delta: float) -> void:
	var from := global_position
	var step_px := minf(speed_px * delta, travel_left_px)
	var to := from + dir * step_px
	var wall := _wall_between(from, to)
	if wall != Vector2.INF:
		to = wall - dir * 4.0
		travel_left_px = 0.0
	else:
		travel_left_px -= step_px
	global_position = to
	queue_redraw()
	var e := _first_in_segment(from, to)
	if e != null:
		_hook(e)
	elif travel_left_px <= 0.0:
		_to_ground() # rien touché : le harpon retombe là où il s'arrête


func _first_in_segment(a: Vector2, b: Vector2) -> Node2D:
	var best: Node2D = null
	var best_along := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not e.has_method(&"take_damage") or not _alive(e):
			continue
		if _seg_dist((e as Node2D).global_position, a, b) > half_width_px + _radius_of(e):
			continue
		var along: float = ((e as Node2D).global_position - a).dot(dir)
		if along < best_along:
			best_along = along
			best = e
	return best


func _hook(e: Node2D) -> void:
	hooked = e
	phase = Phase.HOOKED
	t = 0.0
	global_position = e.global_position
	_play(&"arm_clamp", dir)
	Audio.play(&"hit.heavy", e.global_position, -3.0, 0.6) # « clang » d'accroche
	caster.deal_damage(e, spell, {})
	if not _alive(e):
		hooked = null
		_to_ground()
		return
	if not _is_boss(e):
		e.apply_status(&"slow", {"pct": TocsinKit.HARPON_PLANT_SLOW_PCT, "duration": 0.3})
	kit.begin_pull(self, e)


## Planté sur sa cible : la suit 2,5 s (ralentie 40 %, pas un boss) puis tombe au sol (ramassable).
func _step_hooked(delta: float) -> void:
	queue_redraw()
	if hooked == null or not _alive(hooked) or t >= TocsinKit.HARPON_PLANT_S:
		hooked = null
		_to_ground()
		return
	global_position = hooked.global_position
	if not _is_boss(hooked) and fmod(t, 0.25) < delta:
		hooked.apply_status(&"slow", {"pct": TocsinKit.HARPON_PLANT_SLOW_PCT, "duration": 0.3})


## Jambe-ressort laissée au décollage : posée au sol tout de suite.
func plant_ground() -> void:
	_to_ground()


func drop_point() -> Vector2:
	var p: Vector2 = kit.player.global_position
	return p + dir * TocsinKit.ARM_DROP_U * Balance.UNIT_PX + dir.orthogonal() * lateral * Balance.UNIT_PX


func _step_back(delta: float) -> void:
	var goal := drop_point()
	var to_goal := goal - global_position
	var step_px := speed_px * delta
	if to_goal.length() <= step_px or t >= TocsinKit.ARM_BACK_MAX_S:
		global_position = goal
		_start_clamp()
		return
	global_position += to_goal.normalized() * step_px


func _step_fly() -> void:
	var k := clampf(t / TocsinKit.HEAD_FLIGHT_S, 0.0, 1.0)
	global_position = start.lerp(target, k)
	if ring != null:
		ring.modulate.a = 0.35 + 0.4 * k
	if sprite != null:
		sprite.position.y = Iso.lift_logical(TocsinKit.HEAD_LOB_HEIGHT_U) * sin(PI * k)
	if shadow != null:
		var s := 1.0 - 0.45 * sin(PI * k)
		shadow.scale = Vector2.ONE * s * (0.9 * Balance.UNIT_PX / maxf(shadow.texture.get_width(), 1.0))
	if k >= 1.0:
		phase = Phase.RING
		t = 0.0
		if sprite != null:
			sprite.position.y = 0.0
		Audio.play(&"telegraph.warn_heavy.heavy", global_position, -2.0, 1.35) # la cloche tinte
		if _light != null:
			_light.set_energy(1.8)
		queue_redraw()


# --- Coups ---------------------------------------------------------------------------------------

## Mur entre a et b (couche 1) : point d'impact, sinon Vector2.INF.
func _wall_between(a: Vector2, b: Vector2) -> Vector2:
	if not is_inside_tree() or a.distance_squared_to(b) < 0.01:
		return Vector2.INF
	var q := PhysicsRayQueryParameters2D.create(a, b, WALL_MASK)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else Vector2.INF


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


static func _radius_of(e: Node) -> float:
	return float(e.get(&"radius_px")) if &"radius_px" in e else 0.0


static func _is_boss(e: Node) -> bool:
	return e.is_in_group(&"bosses") or (e is Enemy and (e as Enemy).is_boss)


func _sweep(a: Vector2, b: Vector2) -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not e.has_method(&"take_damage") or hit.has(e.get_instance_id()):
			continue
		if _seg_dist((e as Node2D).global_position, a, b) > half_width_px + _radius_of(e):
			continue
		hit[e.get_instance_id()] = true
		if kind == &"arm":
			_arm_hit(e)
		else:
			_leg_hit(e)


func _arm_hit(e: Node2D) -> void:
	caster.deal_damage(e, spell, {})
	if not _alive(e):
		return
	if _is_boss(e):
		e.apply_status(&"slow", {"pct": TocsinKit.ARM_BOSS_SLOW_PCT, "duration": TocsinKit.ARM_BOSS_SLOW_S})
		return
	var cost := TocsinKit.capture_cost(e)
	if points + cost <= TocsinKit.ARM_CAPACITY and not kit.is_captured(e):
		points += cost
		RunState.add_counter(TocsinKit.COUNTER_IMPRISONED)
		var off := (e.global_position - global_position).limit_length(0.5 * Balance.UNIT_PX)
		captured.append({"e": e, "off": off, "pos": e.global_position})
		Audio.play(&"enemy.contact.light", e.global_position, -6.0, 0.7)
	else:
		e.apply_status(&"slow", {"pct": TocsinKit.ARM_RELEASE_SLOW_PCT, "duration": TocsinKit.ARM_RELEASE_SLOW_S})


func _leg_hit(e: Node2D) -> void:
	var was: bool = kit.is_captured(e)
	if was:
		kit.free_enemy(e) # « la boule de quilles » : libéré et poussé plus loin
	caster.deal_damage(e, spell, {})
	if not _alive(e):
		return
	_push(e, dir * TocsinKit.LEG_PUSH_U * (TocsinKit.LEG_PRISONER_PUSH_MULT if was else 1.0))
	pushed.append({"e": e, "t": QUILLE_TRACK_S, "struck": {}})
	RunState.add_counter(TocsinKit.COUNTER_PUSHED)


## Poussée (u, avant masse) par-dessus le plafond de recul : Enemy.push (sans effet sur un boss).
static func _push(e: Node2D, v_u: Vector2) -> void:
	if not e.has_method(&"push"):
		return
	var mass := 1.0
	if e is Enemy:
		mass = Balance.knockback_mass(e.tier, e.is_elite, e.boss_kind if e.is_boss else &"")
	e.push(v_u * mass * Balance.UNIT_PX)


## Quilles (S4) : un monstre poussé qui en percute un autre lui transmet 50 % de sa poussée restante et
## lui inflige 100 % des dégâts de base (une fois par monstre percuté), en chaîne.
func _step_quilles(delta: float) -> void:
	var others := get_tree().get_nodes_in_group(&"enemies")
	var i := pushed.size() - 1
	while i >= 0:
		var q: Dictionary = pushed[i]
		q["t"] = float(q["t"]) - delta
		var e: Node2D = q["e"]
		if float(q["t"]) <= 0.0 or not _alive(e) or not (e is Enemy):
			pushed.remove_at(i)
			i -= 1
			continue
		var kb: Vector2 = e.knockback_left()
		if kb.length() < QUILLE_MIN_PX:
			i -= 1
			continue
		var struck: Dictionary = q["struck"]
		for o in others:
			if o == e or not (o is Enemy) or struck.has(o.get_instance_id()) or hit.has(o.get_instance_id()):
				continue
			if (o as Node2D).global_position.distance_to(e.global_position) > _radius_of(o) + _radius_of(e):
				continue
			struck[o.get_instance_id()] = true
			hit[o.get_instance_id()] = true
			caster.deal_damage(o, kit.quille_spell, {})
			if _alive(o) and not _is_boss(o):
				o.push(kb * TocsinKit.QUILLE_TRANSFER)
				pushed.append({"e": o, "t": QUILLE_TRACK_S, "struck": {}})
				RunState.add_counter(TocsinKit.COUNTER_PUSHED)
		i -= 1


## Tête-fumigène : à l'arrivée, étourdissement d'entrée dans la zone, puis la tête reste au sol et fume.
func _start_smoke() -> void:
	phase = Phase.SMOKE
	t = 0.0
	_smoke_ticks = 0
	var c := global_position
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not e.has_method(&"take_damage") or not _alive(e):
			continue
		if (e as Node2D).global_position.distance_to(c) > radius_px + _radius_of(e) * 0.5:
			continue
		if _is_boss(e): # le boss n'est pas étourdi : ralenti
			e.apply_status(&"slow", {"pct": TocsinKit.FUMI_BOSS_SLOW_PCT, "duration": TocsinKit.FUMI_STUN_S})
		else:
			e.apply_status(&"imprisoned", {"duration": TocsinKit.FUMI_STUN_S, "release_pct": TocsinKit.FUMI_SLOW_PCT,
					"release_s": 0.6})
	if ring != null and is_instance_valid(ring):
		ring.queue_free()
		ring = null
	kit.on_smoke_start(self, c)
	queue_redraw()


func _step_smoke(_delta: float) -> void:
	queue_redraw()
	var due := mini(int(t / TocsinKit.FUMI_TICK_S + 0.0001), int(TocsinKit.FUMI_S / TocsinKit.FUMI_TICK_S))
	while _smoke_ticks < due:
		_smoke_ticks += 1
		_smoke_tick()
	if t >= TocsinKit.FUMI_S:
		phase = Phase.DONE
		queue_free()


## Un tick de fumée : coef par tick (+50 % sur les emprisonnés), ralentissement 50 % rafraîchi, ni recul ni éclat.
func _smoke_tick() -> void:
	var c := global_position
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not e.has_method(&"take_damage") or not _alive(e):
			continue
		if (e as Node2D).global_position.distance_to(c) > radius_px + _radius_of(e) * 0.5:
			continue
		var held: bool = e.has_method(&"is_imprisoned") and bool(e.is_imprisoned())
		caster.deal_damage(e, spell, {"is_dot": true})
		if held and _alive(e):
			caster.deal_damage(e, kit.smoke_bonus_spell, {"is_dot": true})
		if _alive(e):
			e.apply_status(&"slow", {"pct": TocsinKit.FUMI_SLOW_PCT, "duration": TocsinKit.FUMI_TICK_S + 0.2})


func _blast() -> void:
	if smoke:
		_start_smoke()
		return
	phase = Phase.DONE
	var c := global_position
	var r := radius_px
	var victims: Array = []
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Node2D and e.has_method(&"take_damage") and (e as Node2D).global_position.distance_to(c) <= r + _radius_of(e) * 0.5:
			victims.append(e)
	for e: Node2D in victims:
		var held: bool = kit.is_captured(e)
		if held:
			kit.free_enemy(e)
		caster.deal_damage(e, spell, {"source_pos": c})
		if held and _alive(e): # explosion confinée : +50 %, sans proc supplémentaire
			caster.deal_damage(e, kit.blast_bonus_spell, {})
		if _alive(e) and not _is_boss(e):
			var away := e.global_position - c
			_push(e, (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT) * TocsinKit.HEAD_PUSH_EXTRA_U)
	kit.on_head_blast(self, c)
	queue_free()


static func _alive(e: Node) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_inside_tree():
		return false
	return not (e is Enemy) or bool(e.active)


# --- Prise (accrochés / emprisonnés) --------------------------------------------------------------

func _start_clamp() -> void:
	phase = Phase.CLAMP
	t = 0.0
	_play(&"arm_clamp", dir)
	var n := captured.size()
	for i in n: # tournesol sur un disque de 1 u : le paquet
		var rr := TocsinKit.PACK_RADIUS_U * Balance.UNIT_PX * 0.9 * sqrt((i + 0.5) / maxf(n, 1))
		var a := i * 2.39996
		captured[i]["pos"] = global_position + Vector2.from_angle(a) * (rr if n > 1 else 0.0)
	Audio.play(&"hit.heavy", global_position, -4.0, 0.6) # la pince se plante
	_make_pickup()
	_hold_all()


func _to_ground() -> void:
	phase = Phase.GROUND
	_play(StringName("%s_ground" % kind), dir)
	Audio.play(&"hit.heavy", global_position, -6.0, 0.8)
	_make_pickup()


func _make_pickup() -> void:
	if pickup != null or kit.player.get_parent() == null:
		return
	pickup = GroundPickup.spawn(kit.player.get_parent(), global_position, kit.player, func(_g: GroundPickup) -> void:
		pickup = null
		if is_instance_valid(kit):
			kit.collect_limb(self), 1.0e9, TocsinKit.PICKUP_CONTACT_U, "")
	pickup.delay_s = TocsinKit.PICKUP_DELAY_S
	pickup.show_placeholder = sprite == null or not sprite.visible # repli : le trait du pickup tant que l'asset manque
	pickup.set_marker_radius_u(0.55) # repère au sol (GroundMarker) : halo sous le membre à ramasser


func holds(e: Node) -> bool:
	for c in captured:
		if c["e"] == e:
			return true
	return false


func is_clamping() -> bool:
	return phase == Phase.CLAMP and not captured.is_empty()


func _hold_all() -> void:
	if captured.is_empty():
		return
	var i := captured.size() - 1
	while i >= 0:
		var c: Dictionary = captured[i]
		var e: Node2D = c["e"]
		if not _alive(e):
			captured.remove_at(i)
		else:
			var p: Vector2 = c["pos"] if phase == Phase.CLAMP else global_position + (c["off"] as Vector2)
			_hold(e, p)
		i -= 1


## Statut `imprisoned` d'Enemy rafraîchi à chaque frame (physique ET rendu) et position tenue.
static func _hold(e: Node2D, p: Vector2) -> void:
	if e is Enemy:
		var en := e as Enemy
		en.imprison(HOLD_REFRESH_S)
		en.hold_at(p)
	else:
		e.global_position = p


static func _unhold(e: Node2D, slow_pct: float, slow_s: float) -> void:
	if e is Enemy and (e as Enemy).active:
		(e as Enemy).release_imprison(slow_pct, slow_s)


func release(e: Node) -> void:
	var i := captured.size() - 1
	while i >= 0:
		if captured[i]["e"] == e:
			captured.remove_at(i)
			_unhold(e as Node2D, TocsinKit.ARM_RELEASE_SLOW_PCT, TocsinKit.ARM_RELEASE_SLOW_S)
		i -= 1


func release_all(slow_pct: float, slow_s: float) -> void:
	for c in captured:
		if _alive(c["e"]):
			_unhold(c["e"], slow_pct, slow_s)
	captured.clear()


func forget(e: Node) -> void:
	var i := captured.size() - 1
	while i >= 0:
		if captured[i]["e"] == e:
			captured.remove_at(i)
		i -= 1


## Fin de recharge : le membre au sol part en braises (le kit le refait sur le robot).
func vanish() -> void:
	release_all(TocsinKit.ARM_RELEASE_SLOW_PCT, TocsinKit.ARM_RELEASE_SLOW_S)
	if pickup != null and is_instance_valid(pickup):
		pickup.queue_free()
	pickup = null
	if is_inside_tree() and phase != Phase.DONE and kind != &"head":
		HitFx.impact(global_position + Vector2(0, -12), Vector2.UP, &"fire", 0.3, false, false)
	queue_free()


func _exit_tree() -> void:
	if not captured.is_empty():
		release_all(TocsinKit.ARM_RELEASE_SLOW_PCT, TocsinKit.ARM_RELEASE_SLOW_S)
	if ring != null and is_instance_valid(ring):
		ring.queue_free()
	ring = null
	if pickup != null and is_instance_valid(pickup):
		pickup.queue_free()


## Repli sans asset (placeholder temporaire) : anneau de tintement de la tête si `head_ring` manque ; membres = trait du pickup.
func _draw() -> void:
	if kit == null:
		return
	var c := Color(1.0, 0.48, 0.12)
	if harpoon and (phase == Phase.OUT or phase == Phase.HOOKED) and is_instance_valid(kit.player):
		# câble bronze depuis l'épaule (placeholder temporaire : Line2D bronze attendu du lot TOCV)
		draw_line(Vector2.ZERO, to_local(kit.player.global_position), Color(0.62, 0.42, 0.2, 0.9), 2.0)
	if phase == Phase.SMOKE:
		var k := clampf(t / TocsinKit.FUMI_S, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius_px, Color(0.85, 0.5, 0.2, 0.10 * (1.0 - 0.5 * k)))
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.35), 2.0)
		draw_circle(Vector2.ZERO, 6.0, c)
	elif phase == Phase.RING and ring == null:
		var k := clampf(t / TocsinKit.HEAD_RING_S, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.25 + 0.45 * k), 2.0)
		draw_arc(Vector2.ZERO, radius_px * (0.2 + 0.8 * k), 0.0, TAU, 72, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.6 * (1.0 - k)), 2.0)
	elif sprite == null or not sprite.visible:
		var d := dir * 18.0
		draw_line(-d, d, Color(0.37, 0.56, 0.5), 6.0)
		draw_circle(d, 4.0, c)
