class_name TocsinLimb
extends Node2D
## Membre lancé de Tocsin (Design_Personnages §1.3) : objet du monde, piloté par TocsinKit.
## - Bras-pilier (`arm`, 23/10/2026 : remplace le Bras-grappin) : lob 0,6 s vers le point visé, se plante comme un
##   pilier et décharge en zone 5 s (ticks de 0,5 s, premier tick à la pose, télégraphe au sol dès le lancer), puis
##   reste AU SOL (ramassable au contact, rattaché dans la frame ; disparaît en braises quand sa recharge finit).
## - Tête-cloche (`head`) : lob 0,9 s (arc + ombre), tintement 0,3 s (anneau), explosion 4 u, 1 000 %,
##   poussée 2 u × masse ; jamais ramassable.
## Variante `smoke` (Tête-fumigène) : au lieu de l'explosion, zone de fumée de 5 s, 10 ticks, étourdissement d'entrée.
## Les jambes ne sont plus lancées (23/10/2026) : plus de jambe, de harpon ni d'emprisonnement par les bras.
## Visuel du pilier et des décharges : PLACEHOLDER dessiné en code (_draw), à remplacer par les rendus Codex
## (brief art/tools/tocsin/_tocsin_pilier.txt).

enum Phase { GROUND, FLY, RING, DONE, SMOKE, PILLAR }

const DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const VISUAL_SCALE := Vector2(0.70710678, 1.4142136) ## = Visual du joueur (rig CREA, billboard)
const VISUAL_OFFSET := Vector2(0, -40.32) ## pivot des pieds 96/136,32 dans la cellule 192

var kind: StringName = &"arm"
var smoke := false ## Tête-fumigène
var key: StringName = &"arm_l"
var kit: TocsinKit = null
var caster: SpellCaster = null
var spell: SpellData = null
var phase := Phase.FLY
var dir := Vector2.RIGHT
var start := Vector2.ZERO
var target := Vector2.ZERO
var radius_px := 256.0
var t := 0.0
var expired := false ## recharge finie pendant la décharge : le pilier finit son travail puis part en braises
var pickup: GroundPickup = null
var sprite: AnimatedSprite2D = null
var shadow: Sprite2D = null
var _light: LightRig.Handle = null
var ring: AnimatedSprite2D = null ## tête : télégraphe `head_ring` (T6) posé au sol sur la cible, frère du membre
var _frames: Dictionary = {} ## nom -> SpriteFrames chargées
var _ticks := 0 ## ticks de décharge / de fumée déjà joués
var _tick_flash := 0.0 ## éclair visuel du dernier tick (placeholder des arcs)


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
	var tex: Texture2D = AmbianceTextures.get_tex(&"shadow_blob_256")
	if tex != null and phase == Phase.FLY:
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
	queue_redraw()


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
		var p := Skins.asset_dir(&"tocsin", String(TocsinKit.ASSET_DIR)) + "tocsin_%s.tres" % base
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


## Public pour les tests.
func step(delta: float) -> void:
	if kit == null or not is_instance_valid(kit) or kit.player == null:
		queue_free()
		return
	t += delta
	_tick_flash = maxf(_tick_flash - delta, 0.0)
	match phase:
		Phase.FLY:
			_step_fly()
		Phase.PILLAR:
			_step_pillar()
		Phase.SMOKE:
			_step_smoke()
		Phase.RING:
			if ring != null:
				ring.modulate.a = 1.0
			queue_redraw()
			if t >= TocsinKit.HEAD_RING_S:
				_blast()


## Lob : la tête (0,9 s) ou le bras-pilier (0,6 s) décrit un arc vers `target`, ombre de contact.
func _step_fly() -> void:
	var dur := TocsinKit.HEAD_FLIGHT_S if kind == &"head" else TocsinKit.PILLAR_FLIGHT_S
	var height := TocsinKit.HEAD_LOB_HEIGHT_U if kind == &"head" else TocsinKit.PILLAR_LOB_HEIGHT_U
	var k := clampf(t / dur, 0.0, 1.0)
	global_position = start.lerp(target, k)
	if ring != null:
		ring.modulate.a = 0.35 + 0.4 * k
	if sprite != null:
		sprite.position.y = Iso.lift_logical(height) * sin(PI * k)
	if shadow != null:
		var s := 1.0 - 0.45 * sin(PI * k)
		shadow.scale = Vector2.ONE * s * (0.9 * Balance.UNIT_PX / maxf(shadow.texture.get_width(), 1.0))
	queue_redraw() # télégraphe du pilier : le cercle de la zone grandit pendant le vol
	if k < 1.0:
		return
	if sprite != null:
		sprite.position.y = 0.0
	if shadow != null:
		shadow.queue_free()
		shadow = null
	if kind == &"arm":
		_start_pillar()
		return
	phase = Phase.RING
	t = 0.0
	Audio.play(&"telegraph.warn_heavy.heavy", global_position, -2.0, 1.35) # la cloche tinte
	if _light != null:
		_light.set_energy(1.8)
	queue_redraw()


# --- Bras-pilier -----------------------------------------------------------------------------------

func _start_pillar() -> void:
	phase = Phase.PILLAR
	t = 0.0
	_ticks = 0
	_play(&"arm_clamp", dir) # planté (anim de repli : `arm_clamp`)
	if _light != null:
		_light.set_energy(1.6)
	Audio.play(&"hit.heavy", global_position, -3.0, 0.7) # il se plante
	kit.on_pillar_planted(self, global_position)
	_outline(TocsinKit.PILLAR_S)
	_ticks = 1 # premier tick à la pose (la zone est visible avant qu'il ne frappe)
	_pillar_tick()
	queue_redraw()


## Nombre de ticks dus à l'instant t : un à la pose, puis un toutes les PILLAR_TICK_S, PILLAR_TICKS au total.
static func pillar_ticks_due(elapsed: float) -> int:
	return mini(int(elapsed / TocsinKit.PILLAR_TICK_S + 0.0001) + 1, TocsinKit.PILLAR_TICKS)


## Contour de la zone au sol (ZoneOutline, couleur du sort) pendant la décharge / la fumée.
func _outline(life_s: float) -> void:
	ZoneOutline.attach(self, radius_px, ZoneOutline.color_for(spell, caster), life_s)


func _step_pillar() -> void:
	queue_redraw()
	while _ticks < pillar_ticks_due(t):
		_ticks += 1
		_pillar_tick()
	if t >= TocsinKit.PILLAR_S:
		_pillar_end()


## Un tick de décharge : coef par tick à tout monstre de la zone, léger ralentissement rafraîchi.
func _pillar_tick() -> void:
	_tick_flash = 0.18
	var c := global_position
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not e.has_method(&"take_damage") or not _alive(e):
			continue
		if (e as Node2D).global_position.distance_to(c) > radius_px + _radius_of(e) * 0.5:
			continue
		caster.deal_damage(e, spell, {"is_dot": true})
		if _alive(e):
			e.apply_status(&"slow", {"pct": TocsinKit.PILLAR_SLOW_PCT, "duration": TocsinKit.PILLAR_TICK_S + 0.2})
	Audio.play(&"hit.heavy", c, -14.0, 1.9) # crépitement : un coup sec par tick
	kit.on_pillar_tick(self, c)


## Fin de décharge : au sol et ramassable, sauf si la recharge du bras est déjà finie (braises).
func _pillar_end() -> void:
	if expired or not kit.is_queued(key):
		vanish()
		return
	_to_ground()


## Fin de recharge (kit) : le pilier en décharge ne s'interrompt pas, le reste part en braises.
func expire() -> void:
	if phase == Phase.PILLAR:
		expired = true
		return
	vanish()


# --- Coups ---------------------------------------------------------------------------------------

static func _radius_of(e: Node) -> float:
	return float(e.get(&"radius_px")) if &"radius_px" in e else 0.0


static func _is_boss(e: Node) -> bool:
	return e.is_in_group(&"bosses") or (e is Enemy and (e as Enemy).is_boss)


## Poussée (u, avant masse) par-dessus le plafond de recul : Enemy.push (sans effet sur un boss).
static func _push(e: Node2D, v_u: Vector2) -> void:
	if not e.has_method(&"push"):
		return
	var mass := 1.0
	if e is Enemy:
		mass = Balance.knockback_mass(e.tier, e.is_elite, e.boss_kind if e.is_boss else &"")
	e.push(v_u * mass * Balance.UNIT_PX)


## Tête-fumigène : à l'arrivée, étourdissement d'entrée dans la zone, puis la tête reste au sol et fume.
func _start_smoke() -> void:
	phase = Phase.SMOKE
	t = 0.0
	_ticks = 0
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
	_outline(TocsinKit.FUMI_S)
	queue_redraw()


func _step_smoke() -> void:
	queue_redraw()
	var due := mini(int(t / TocsinKit.FUMI_TICK_S + 0.0001), int(TocsinKit.FUMI_S / TocsinKit.FUMI_TICK_S))
	while _ticks < due:
		_ticks += 1
		_smoke_tick()
	if t >= TocsinKit.FUMI_S:
		phase = Phase.DONE
		queue_free()


## Un tick de fumée : coef par tick (+50 % sur les étourdis), ralentissement 50 % rafraîchi, ni recul ni éclat.
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
		caster.deal_damage(e, spell, {"source_pos": c})
		if _alive(e) and not _is_boss(e):
			var away := e.global_position - c
			_push(e, (away.normalized() if away.length_squared() > 1.0 else Vector2.RIGHT) * TocsinKit.HEAD_PUSH_EXTRA_U)
	kit.on_head_blast(self, c)
	queue_free()


static func _alive(e: Node) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_inside_tree():
		return false
	return not (e is Enemy) or bool(e.active)


# --- Sol et ramassage -----------------------------------------------------------------------------

func _to_ground() -> void:
	phase = Phase.GROUND
	_play(StringName("%s_ground" % kind), dir)
	Audio.play(&"hit.heavy", global_position, -6.0, 0.8)
	_make_pickup()
	queue_redraw()


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


func is_pillar_active() -> bool:
	return phase == Phase.PILLAR


## Fin de recharge ou étage : le membre part en braises (le kit le refait sur le robot).
func vanish() -> void:
	if pickup != null and is_instance_valid(pickup):
		pickup.queue_free()
	pickup = null
	if is_inside_tree() and phase != Phase.DONE and kind != &"head":
		HitFx.impact(global_position + Vector2(0, -12), Vector2.UP, &"fire", 0.3, false, false)
	phase = Phase.DONE
	queue_free()


func _exit_tree() -> void:
	if ring != null and is_instance_valid(ring):
		ring.queue_free()
	ring = null
	if pickup != null and is_instance_valid(pickup):
		pickup.queue_free()


## Placeholders temporaires (assets finaux : Codex) : télégraphe et arcs du pilier, anneau de la tête, trait du membre.
func _draw() -> void:
	if kit == null:
		return
	var c := Color(1.0, 0.48, 0.12)
	var arc_c := Color(0.55, 0.85, 1.0) ## décharge électrique : bleu-blanc, l'accent orange reste celui du foyer
	if kind == &"arm" and phase == Phase.FLY:
		# télégraphe : zone de décharge au sol, qui se précise pendant le vol
		var k := clampf(t / TocsinKit.PILLAR_FLIGHT_S, 0.0, 1.0)
		var tl := to_local(target)
		draw_arc(tl, radius_px, 0.0, TAU, 72, Color(arc_c.r, arc_c.g, arc_c.b, 0.25 + 0.45 * k), 2.0)
		draw_circle(tl, radius_px, Color(arc_c.r, arc_c.g, arc_c.b, 0.05 + 0.07 * k))
	elif phase == Phase.PILLAR:
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		# pilier : tige verticale + tête incandescente
		draw_line(Vector2.ZERO, Vector2(0, -34), Color(0.37, 0.56, 0.5), 7.0)
		draw_circle(Vector2(0, -36), 6.0 + 2.0 * pulse, c)
		# arcs : 5 éclairs en zigzag qui changent à chaque tick
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_ticks) * 7919 + 13
		var n := 5
		for i in n:
			var a := rng.randf() * TAU
			var len_px := radius_px * (0.55 + 0.45 * rng.randf())
			var p := Vector2(0, -36)
			var end := Vector2.from_angle(a) * len_px
			var pts := PackedVector2Array([p])
			for j in 1 + 4:
				var f := float(j) / 4.0
				var jit := Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0)) if j < 4 else Vector2.ZERO
				pts.append(p.lerp(end, f) + jit)
			var al := 0.35 + 0.65 * clampf(_tick_flash / 0.18, 0.0, 1.0)
			draw_polyline(pts, Color(arc_c.r, arc_c.g, arc_c.b, al), 2.0)
			draw_polyline(pts, Color(1, 1, 1, al * 0.7), 0.8)
	elif phase == Phase.SMOKE:
		draw_circle(Vector2.ZERO, 6.0, c)
	elif phase == Phase.RING and ring == null:
		var k4 := clampf(t / TocsinKit.HEAD_RING_S, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.25 + 0.45 * k4), 2.0)
		draw_arc(Vector2.ZERO, radius_px * (0.2 + 0.8 * k4), 0.0, TAU, 72, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.6 * (1.0 - k4)), 2.0)
	elif sprite == null or not sprite.visible:
		var d := dir * 18.0
		draw_line(-d, d, Color(0.37, 0.56, 0.5), 6.0)
		draw_circle(d, 4.0, c)
