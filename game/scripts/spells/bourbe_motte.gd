class_name BourbeMotte
extends Decoy
## Motte de Bourbe (docs/Design_Personnages.md §2.5, S10 léger) : un morceau d'elle, familier autonome.
## Étend Decoy (S14) pour réutiliser sans rien toucher la provocation des monstres (Enemy.tick : leurre le
## plus proche à Decoy.PROVOKE_RANGE_U) et les tirs ennemis reçus (EnemyProjectilePool : Decoy.hit_by).
## États :
## - FLY : lancée en cloche du corps de Bourbe vers le point visé ; à l'atterrissage, « plouf » (land_spell).
## - FIGHT : FIGHT_S s ; chasse l'ennemi le plus proche dans un rayon de CHASE_U autour de Bourbe, coup de
##   contact (contact_spell) toutes les CONTACT_INTERVAL_S ; sans cible, suit Bourbe.
## - RETURN : rampe vers Bourbe (sans traverser les murs : la vase s'infiltre) ; se recolle au contact.
## - RECALL (sort 3) : fonce vers Bourbe, chaque monstre traversé prend recall_spell (une fois), se recolle.
## Mort (PV à 0) ou recollage : sort de Decoy.live, prévient le kit (masse rendue ou perdue 8 s).
## Visuel : motte/motte.tres (lot BO2 : idle_/run_/die_<dir>) ; absente = sprite de Bourbe (ou d'Ardent
## teinté) réduit et assombri. Anneau d'allié : ally_ring.tres (lot BO3, TOP) ou contour dessiné.

enum State { FLY, FIGHT, RETURN, RECALL, GONE }

const DIR_NAMES_M := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const RETARGET_S := 0.2
const STUCK_STEP := 0.5 ## glissement le long d'un mur : on retente chaque axe
## IA de ciblage (retour joueur 26/10 : mottes qui ne focus pas les boss, rentrent trop vite, sans ré-aggro).
const SCAN_S := 0.25 ## période du scan de cibles (combat, suivi et retour)
const DETECT_U := 9.0 ## détection d'un ennemi ordinaire, mesurée depuis la motte
const BOSS_DETECT_U := 14.0 ## détection d'un boss ou mini-boss (groupe bosses), depuis la motte : prioritaire
const LEASH_U := 16.0 ## une cible ordinaire est lâchée si elle s'éloigne de plus de 16 u du joueur
const BOSS_LEASH_U := 22.0 ## idem pour un boss (on le suit plus loin)
const PLAYER_MAX_U := 24.0 ## joueur plus loin que ça : plus de chasse, la motte rejoint Bourbe
const CATCHUP_U := 8.0 ## sans cible, au-delà de 8 u de Bourbe : course de rattrapage
const CATCHUP_MULT := 1.6 ## multiplicateur de vitesse du rattrapage
const REAGGRO_S := 4.0 ## temps de combat rendu quand une cible est réacquise pendant le retour
const REAGGRO_MAX := 2 ## nombre maximal de ré-aggros pendant le retour (la durée de vie reste bornée)

var kit: Node = null ## BourbeKit
var bourbe: Node2D = null
var state: State = State.FLY
var contact_spell: SpellData = null
var land_spell: SpellData = null
var recall_spell: SpellData = null
var costed := true ## false : motte gratuite (sortie du Bourbier)
var big := false ## grosse motte (variante Bouture) : sprite x1,5, plus lente, plus durable
var weight := 1 ## places occupées sur les MAX_MOTTES (grosse motte : 2)
var fight_s := BourbeKit.MOTTE_FIGHT_S
var contact_interval_s := BourbeKit.MOTTE_CONTACT_INTERVAL_S
var speed_u := BourbeKit.MOTTE_SPEED_U
var radius_u := BourbeKit.MOTTE_RADIUS_U
var ring_u := BourbeKit.ALLY_RING_U
var paid_hp := 0.0 ## PV actuels payés par Bourbe au Détacher (rendus au recollage × PV restants)
var mass_frac := 0.0 ## part des PV max (non divisés) retirée à Bourbe tant que la motte est dehors (0 : motte gratuite)
var fight_left := 0.0
var target: Node2D = null
var hits := 0 ## coups de contact portés (tests)
var fed := false ## nourrie par une Gifle (docs/Design_Combos.md §5.5) : son prochain coup de contact est multiplié
var feed_cd_left := 0.0 ## s avant de pouvoir être nourrie de nouveau
var flow_left := 0.0 ## s restantes de vitesse de traînée (Coulée : BourbeKit.FLOW_TRAIL_MOTTE_SPEED_U)
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO
var _fly_t := 0.0
var _landed := false
var _attack_cd := 0.0
var _retarget := 0.0
var _reaggro := 0
var _recall_hits: Array = []
var _moving := false
var _ring: AnimatedSprite2D = null
var _base_scale := Vector2.ONE
var _fallback_look := false ## motte.tres absent : sprite de Bourbe réduit + follet dessiné


func _ready() -> void:
	super._ready()
	lures_bosses = false # audit 23/10 (P4) : la vase ne provoque plus les boss ni les mini-boss (immunité de fait sinon)
	z_index = 0
	LightRig.attach(self, &"bourbe_motte")


# --- Constantes de gameplay lues sur le kit (une seule source : BourbeKit) ----------------------

func _u() -> float:
	return Balance.UNIT_PX


func _speed_px() -> float:
	return (maxf(speed_u, BourbeKit.FLOW_TRAIL_MOTTE_SPEED_U) if flow_left > 0.0 else speed_u) * _u()


## Gifle transmise : soin (fraction des PV max), prochain coup de contact multiplié, flambée du follet et de l'anneau.
func feed(heal_frac: float, cd_s: float) -> void:
	if state == State.GONE or state == State.FLY:
		return
	hp = minf(hp + heal_frac * max_hp, max_hp)
	fed = true
	feed_cd_left = cd_s
	if _sprite != null:
		_sprite.modulate = Color(1.9, 2.3, 1.9) # follet qui flambe, retombe en 0,4 s
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.4)
	if _ring != null:
		_ring.modulate = Color(1.8, 2.2, 1.8)
	Audio.play(&"pickup.coin", global_position, -10.0, 1.4)


# --- Lancement ---------------------------------------------------------------------------------

## Lancée en cloche de `from` à `to` (le kit l'a déjà ajoutée à l'arbre).
func launch(from: Vector2, to: Vector2) -> void:
	_fly_from = from
	_fly_to = to
	_fly_t = 0.0
	_landed = false
	state = State.FLY
	airborne = true
	global_position = from
	var d := to - from
	if d.length_squared() > 1.0:
		facing = d.normalized()


## Apparition sur place (sortie du Bourbier) : déjà au combat.
func pop_at(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	facing = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.DOWN
	state = State.FIGHT
	fight_left = fight_s
	appear()


func recall() -> void:
	if state == State.GONE:
		return
	_land_now() # rappelée en plein vol : le plouf part quand même
	state = State.RECALL
	_recall_hits.clear()
	if _sprite != null:
		_sprite.position.y = 0.0


func is_out() -> bool:
	return state != State.GONE


# --- Visuel ------------------------------------------------------------------------------------

## Sprite : motte.tres si livré, sinon le sprite de Bourbe réduit (src = Visual du joueur).
func build_look(src: AnimatedSprite2D) -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Body"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sf: SpriteFrames = null
	if ResourceLoader.exists(BourbeKit.MOTTE_FRAMES):
		sf = load(BourbeKit.MOTTE_FRAMES) as SpriteFrames
	if sf != null:
		EmissiveOverlay.apply(_sprite, sf)
		_base_scale = src.scale if src != null else Vector2(Iso.SPRITE_K, Iso.SPRITE_K * Iso.UNSQUASH.y)
		_sprite.offset = src.offset if src != null else Vector2.ZERO
	elif src != null and src.sprite_frames != null:
		_sprite.sprite_frames = src.sprite_frames
		_base_scale = src.scale * BourbeKit.MOTTE_FALLBACK_SCALE
		_sprite.offset = src.offset
		_sprite.self_modulate = BourbeKit.MOTTE_FALLBACK_TINT
		_fallback_look = true
	if big: # grosse motte (Bouture) : la motte existante agrandie, sans rendu nouveau
		_base_scale *= BourbeKit.BIG_SCALE
	_sprite.scale = _base_scale
	add_child(_sprite)
	_build_ring()
	_play_dir(&"idle")


func _build_ring() -> void:
	if not ResourceLoader.exists(BourbeKit.ALLY_RING_FRAMES):
		return # repli : _draw (contour au sol)
	var sf := load(BourbeKit.ALLY_RING_FRAMES) as SpriteFrames
	if sf == null or not sf.has_animation(&"default") or sf.get_frame_count(&"default") == 0:
		return
	_ring = AnimatedSprite2D.new()
	_ring.name = "AllyRing"
	_ring.z_index = -1
	EmissiveOverlay.apply(_ring, sf)
	var tex := sf.get_frame_texture(&"default", 0)
	var w := float(tex.get_width()) if tex != null else 128.0
	# rig TOP : l'anneau occupe ~90 % de la frame ; on le cale sur le rayon réel (ALLY_RING_U)
	var k := ring_u * _u() / maxf(w * 0.45, 1.0)
	_ring.scale = Vector2(k, k)
	add_child(_ring)
	move_child(_ring, 0)
	_ring.play(&"default")


func _draw() -> void:
	if state == State.GONE:
		return
	var c: Color = BourbeKit.ACCENT
	if _ring == null: # repli de l'anneau d'allié (BO3) : contour au sol
		var r := ring_u * _u()
		draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.07))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, 0.6), 2.0)
	if _fallback_look and _sprite != null: # repli du feu follet de la motte (BO2) : braise froide au cœur
		var h := _sprite.position.y + Iso.lift_logical(BourbeKit.MOTTE_FOLLET_U)
		draw_circle(Vector2(0.0, h), 4.0, Color(c.r * 2.2, c.g * 2.2, c.b * 2.2, 0.9))


func _dir_name_m() -> String:
	var i := roundi(facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES_M[(i + 8) % 8]


func _play_dir(base: StringName) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	for a: StringName in [StringName("%s_%s" % [base, _dir_name_m()]), base, StringName("%s_s" % base)]:
		if _sprite.sprite_frames.has_animation(a):
			if _sprite.animation != a:
				_sprite.play(a)
			return


# --- Contrat « cible » des monstres --------------------------------------------------------------

func take_damage(amount: float, _source: Node = null) -> void:
	if state == State.GONE or state == State.FLY or exploded or amount <= 0.0: # en l'air : intouchable
		return
	hp -= amount
	if _sprite != null:
		_sprite.modulate = Color(1.8, 0.7, 0.6)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hp <= 0.0:
		die()


## Écrasée : la vase s'étale (die_<dir>), la masse est perdue BourbeKit.DEAD_MASS_S s.
func die() -> void:
	if state == State.GONE:
		return
	_land_now() # détruite en plein vol : le plouf part à l'endroit où elle se trouve
	leave()
	HitFx.impact(global_position, facing, &"physical", 0.5)
	Audio.play(&"enemy.contact.light", global_position, -6.0, 0.6)
	if kit != null and is_instance_valid(kit):
		kit.on_motte_died(self)
	var anim := StringName("die_" + _dir_name_m())
	if _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.sprite_frames.set_animation_loop(anim, false)
		_sprite.play(anim)
		get_tree().create_timer(_anim_len(_sprite.sprite_frames, anim) + 0.1, false).timeout.connect(queue_free)
	elif _sprite != null and is_inside_tree():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_sprite, "scale", Vector2(_base_scale.x * 1.5, _base_scale.y * 0.25), 0.3)
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()


static func _anim_len(sf: SpriteFrames, anim: StringName) -> float:
	var fps := sf.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.3
	var t := 0.0
	for i in sf.get_frame_count(anim):
		t += sf.get_frame_duration(anim, i)
	return t / fps


## Recollée à Bourbe : disparaît dans son corps (masse rendue par le kit).
func merge() -> void:
	if state == State.GONE:
		return
	_land_now() # recollée en plein vol (Bourbier) : le plouf part quand même
	leave()
	if kit != null and is_instance_valid(kit):
		kit.on_motte_merged(self)
	if _sprite != null and is_inside_tree():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_sprite, "scale", _base_scale * 0.3, 0.12)
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()


## Retire la motte (fin de vie, changement d'étage) : plus de provocation ni de cible.
func leave() -> void:
	state = State.GONE
	exploded = true # hors de la provocation et des tirs (Decoy.nearest_to / hit_by)
	Decoy.live.erase(self)
	queue_redraw()
	if _ring != null:
		_ring.visible = false


## Jamais d'explosion de doublure : une motte meurt ou se recolle.
func explode(_s: SpellData) -> void:
	die()


func push(_dir := Vector2.ZERO) -> bool:
	return false


# --- Boucle ------------------------------------------------------------------------------------

func step(delta: float) -> void:
	if state == State.GONE:
		return
	if bourbe == null or not is_instance_valid(bourbe):
		die()
		return
	_moving = false
	feed_cd_left = maxf(feed_cd_left - delta, 0.0)
	flow_left = maxf(flow_left - delta, 0.0)
	match state:
		State.FLY:
			_step_fly(delta)
		State.FIGHT:
			_step_fight(delta)
		State.RETURN:
			_step_home(delta, _speed_px(), false)
		State.RECALL:
			_step_home(delta, BourbeKit.RECALL_SPEED_U * _u(), true)
	if state != State.GONE and state != State.FLY:
		_play_dir(&"run" if _moving else &"idle")


func _step_fly(delta: float) -> void:
	_fly_t = minf(_fly_t + delta / BourbeKit.MOTTE_FLY_S, 1.0)
	global_position = _fly_from.lerp(_fly_to, _fly_t)
	if _sprite != null: # cloche : la motte monte puis retombe (hauteur en y logique)
		_sprite.position.y = Iso.lift_logical(BourbeKit.MOTTE_FLY_HEIGHT_U) * sin(PI * _fly_t)
		if _fallback_look:
			queue_redraw()
	if _fly_t >= 1.0:
		_land_now()
		state = State.FIGHT
		fight_left = fight_s
		queue_redraw()
		HitFx.impact(global_position, facing, &"physical", 0.45)
		Audio.play_cast(&"detacher", global_position, 0.6)


## Atterrissage : « plouf » (land_spell) à la position courante, une seule fois. Appelé à la fin du vol et par
## tout ce qui interrompt une motte en l'air (mort, rappel, recollage) : une motte lancée applique toujours son AOE.
func _land_now() -> void:
	if state != State.FLY or _landed:
		return
	_landed = true
	airborne = false
	if _sprite != null:
		_sprite.position.y = 0.0
	if caster != null and is_instance_valid(caster) and land_spell != null:
		caster.spawn_zone(land_spell, global_position)


func _step_fight(delta: float) -> void:
	fight_left -= delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if fight_left <= 0.0:
		state = State.RETURN
		target = null
		return
	_scan_tick(delta)
	var u := _u()
	if target != null:
		var er: float = float(target.get(&"radius_px")) if &"radius_px" in target else 0.0
		var reach := radius_u * u + er + 2.0
		var to := target.global_position - global_position
		if to.length() > reach:
			_move(to.normalized() * minf(_speed_px() * delta, to.length() - reach))
		elif _attack_cd <= 0.0 and caster != null and is_instance_valid(caster):
			_attack_cd = contact_interval_s
			if to.length_squared() > 1.0:
				facing = to.normalized()
			hits += 1
			var cs := contact_spell
			if fed and kit != null and is_instance_valid(kit) and kit.has_method(&"fed_contact_spell"):
				cs = kit.fed_contact_spell(self) # ×3 une fois (Gifle transmise)
				fed = false
				if _ring != null:
					_ring.modulate = Color.WHITE
			caster.deal_damage(target, cs, {"source_pos": global_position})
	else: # sans cible : reste au pied de Bourbe
		var home := bourbe.global_position - global_position
		var keep := BourbeKit.MOTTE_FOLLOW_U * u
		if home.length() > keep:
			var sp := _speed_px() * (CATCHUP_MULT if home.length() > CATCHUP_U * u else 1.0)
			_move(home.normalized() * minf(sp * delta, home.length() - keep))


func _step_home(delta: float, speed: float, ram: bool) -> void:
	var u := _u()
	if state == State.RETURN and _reaggro < REAGGRO_MAX: # le retour continue de scanner
		_retarget -= delta
		if _retarget <= 0.0:
			_retarget = SCAN_S
			var t := _find_target()
			if t != null:
				_reaggro += 1
				target = t
				state = State.FIGHT
				fight_left = REAGGRO_S
				return
	var home := bourbe.global_position - global_position
	var dist := home.length()
	if dist <= BourbeKit.ATTACH_U * u:
		merge()
		return
	var step_px := minf(speed * delta, dist)
	var dir := home / maxf(dist, 0.001)
	global_position += dir * step_px # la vase rampe et s'infiltre : jamais coincée derrière un mur
	facing = dir
	_moving = true
	if ram and caster != null and is_instance_valid(caster):
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if not (e is Node2D) or e in _recall_hits or not _valid(e):
				continue
			var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
			if e.global_position.distance_to(global_position) <= BourbeKit.RECALL_WIDTH_U * u + er:
				_recall_hits.append(e)
				RunState.add_counter(BourbeKit.COUNTER_RAPPEL_HITS) # déblocage de l'Éclatement
				caster.deal_damage(e, recall_spell, {"source_pos": global_position - dir * u})
				HitFx.impact(e.global_position, dir, &"physical", 0.8)
	if global_position.distance_to(bourbe.global_position) <= BourbeKit.ATTACH_U * u:
		merge()


func _valid(e: Node) -> bool:
	return is_instance_valid(e) and e.is_inside_tree() and e.is_in_group(&"enemies") and e.get(&"active") != false


## Scan périodique : garde la cible tant qu'elle est valide (pas de zapping), sauf si un boss entre en portée.
func _scan_tick(delta: float) -> void:
	_retarget -= delta
	var invalid := target == null or not _valid(target) or not _in_leash(target)
	if not invalid and _retarget > 0.0:
		return
	if _retarget <= 0.0:
		_retarget = SCAN_S
	if invalid or not _is_boss(target):
		var t := _find_target()
		if t != null and (invalid or _is_boss(t)):
			target = t
		elif invalid:
			target = null


func _is_boss(e: Node) -> bool:
	return is_instance_valid(e) and (e.is_in_group(&"bosses") or e.get(&"is_boss") == true)


## La cible reste tenable : pas trop loin du joueur (boss : plus loin), joueur pas trop loin de la motte.
func _in_leash(e: Node2D) -> bool:
	if bourbe == null or not is_instance_valid(bourbe):
		return false
	var u := _u()
	if bourbe.global_position.distance_to(global_position) > PLAYER_MAX_U * u:
		return false
	var lim := (BOSS_LEASH_U if _is_boss(e) else LEASH_U) * u
	return e.global_position.distance_to(bourbe.global_position) <= lim


## Meilleure cible : boss/mini-boss (détection large), puis élite, puis le plus proche ; null si rien à portée.
func _find_target() -> Node2D:
	var u := _u()
	var best: Node2D = null
	var best_rank := 99
	var best_d := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not _valid(e) or not e.has_method(&"take_damage"):
			continue
		var boss := _is_boss(e)
		var d: float = e.global_position.distance_to(global_position)
		if d > (BOSS_DETECT_U if boss else DETECT_U) * u or not _in_leash(e):
			continue
		var rank := 0 if boss else (1 if e.get(&"is_elite") == true else 2)
		var d2 := d * d
		if rank < best_rank or (rank == best_rank and d2 < best_d):
			best_rank = rank
			best_d = d2
			best = e
	return best


## Déplacement au sol qui glisse le long des murs (couche 1).
func _move(motion: Vector2) -> void:
	if motion.length_squared() < 0.0001:
		return
	facing = motion.normalized()
	_moving = true
	if not is_inside_tree():
		global_position += motion
		return
	var space := get_world_2d().direct_space_state
	for m: Vector2 in [motion, Vector2(motion.x, 0.0), Vector2(0.0, motion.y)]:
		if m.length_squared() < 0.0001:
			continue
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + m * (1.0 + STUCK_STEP), WALL_MASK)
		if space.intersect_ray(q).is_empty():
			global_position += m
			return
