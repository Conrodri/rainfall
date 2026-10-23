extends CharacterBody2D
## Joueur (contrat : CONTRACTS.md « Joueur »). Groupe "player", couche 2.
## Les sorts viennent d'un CharacterData (RunState.character, par défaut Ardent variante A) via SpellCaster.
## Un personnage à kit (CharacterData.kit_script, ex. Rictus) ajoute un enfant « Kit » interrogé par hooks :
## états (vitesse, inertie, immunité aux ralentissements, roulade permise), sorts suspendus, anims.

signal hp_changed(hp: float, max_hp: float)

const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const BASE_PICKUP_RADIUS := 160.0 ## 2,5 u
const INVULN_AFTER_HIT := 0.4
const DODGE_CAP := 0.75
const MITIGATION_CAP := 0.90
const BURN_FRACTION := 0.25 ## du coup, sur BURN_TIME
const BURN_TIME := 3.0
const POISON_FRACTION_PER_S := 0.08
const POISON_TIME := 4.0
const POISON_MAX_STACKS := 5
const POISON_REGEN_MULT := 0.5
const SLOW_FRACTION := 0.30
const SLOW_TIME := 1.5
const SLOW_IMMUNITY := 2.0
const SLOW_FLOOR := 0.5 ## on ne descend jamais sous 50 % de la vitesse
const RIPOSTE_COOLDOWN := 0.5
const RIPOSTE_BASE_FRACTION := 1.6
const RIPOSTE_RANGE_U := 6.0
const ZoneEffectScript := preload("res://scripts/spells/zone_effect.gd")

@export var character: CharacterData ## null -> CharacterData.for_id(RunState.character)
@export var auto_cast_spells := false: ## accessibilité : sorts 2-4 automatiques
	set(v):
		auto_cast_spells = v
		if spells != null:
			spells.auto_cast_enabled = v

var hp := 100.0
var max_hp := 100.0
var shield := 0.0
var pickup_radius := BASE_PICKUP_RADIUS
var dead := false
var is_moving := false
var facing := Vector2.DOWN
var stats: Dictionary = {}
var procs: Array = []
var specials: Dictionary = {}
var spells: SpellCaster
var kit: Node = null ## logique propre au personnage (null : Ardent)
## Monstres tués à moins de CLOSE_KILL_U (déblocage caché de Rictus, Profile.add_run_result).
var close_kills := 0
const CLOSE_KILL_U := 2.0
var _base_hitbox_px := 0.0
var _hit_radius_px := PlayerHitbox.BASE_PX ## rayon de DÉGÂTS (PlayerHitbox), suit set_hitbox_u
var _hitbox_ring: HitboxRing = null ## anneau de hitbox au sol (réglage « Afficher la hitbox »)

var _invuln := 0.0
var _burn_left := 0.0
var _burn_dps := 0.0
var _poison: Array = [] ## {dps, t}
var _slow_left := 0.0
var _slow_immune := 0.0
var _slows := {} ## clé de source -> Vector2(multiplicateur, s restantes) : ralentissements paramétrés (apply_slow)
var _slow_param := 1.0 ## multiplicateur le plus fort des ralentissements paramétrés en cours (1 = aucun)
var _push_vel := Vector2.ZERO ## poussée en cours (px/s), jouée par move_and_collide : jamais à travers un mur
var _push_left := 0.0
var _riposte_cd := 0.0
var _light: LightRig.Handle = null
var _low_hp := false

## Roulade (action `dodge`, Balance.DODGE_*) : court dash invulnérable, bloqué par les murs.
## Aucune collision avec les monstres (masque 1 = monde seulement) ; coups et statuts ignorés pendant.
const DODGE_SOUND := &"spell.cendres.cast_light" ## souffle de braise bref (pas de « whoosh » dédié au manifeste)
const DODGE_SOUND_DB := -4.0
const DODGE_SOUND_PITCH := 1.3
const DODGE_GHOST_EVERY_S := 0.04 ## fantômes du sprite d'Ardent laissés pendant la roulade
const DODGE_GHOST_FADE_S := 0.3
const DODGE_GHOST_COLOR := Color(1.0, 0.72, 0.45, 0.5)
var _dodge_left := 0.0
var _dodge_total := Balance.DODGE_DURATION_S ## durée de la roulade en cours (distance / vitesse de Balance)
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _ghost_t := 0.0

## Ressenti des coups reçus (retour joueur sur terrasses_noyees : « aucune impression de perdre de la
## vie ») : flash rouge du sprite, vignette rouge (HurtFeedback), chiffre rouge (DamageNumbers, via
## Events.player_damaged), son `player.hurt` (AudioManager, même signal), traîne blanche de la barre
## de vie (HpTrail). Gros coup (>= HURT_BIG_HIT_FRAC des PV max) : secousse de caméra et court hitstop.
const HURT_FLASH_S := 0.12
const HURT_FLASH_COLOR := Color(2.4, 0.35, 0.3) ## modulate HDR : rouge franc, lisible sur l'Ardent
const HURT_FLASH_COLOR_SOFT := Color(1.6, 0.55, 0.5) ## option « secousses et flashs » à 0 : teinte douce
const HURT_BIG_HIT_FRAC := 0.10
const HURT_SHAKE_SMALL_PX := 2.5 ## petit coup : frémissement
const HURT_SHAKE_BIG_PX := 9.0 ## gros coup
const HURT_SHAKE_HZ := 24.0
const HURT_SHAKE_S := 0.22
const HURT_HITSTOP_S := 0.06 ## gros coup : jeu ralenti (temps réel)
const HURT_HITSTOP_SCALE := 0.05
var _hurt_flash_left := 0.0
var _hurt_flash_color := HURT_FLASH_COLOR
static var _hitstop_active := false

## Anims d'action (retour joueur : « aucune animation de lancer de sort ni de l'auto ») : à chaque lancement,
## le sprite joue `<base>_<dir>` du SpriteFrames du personnage, une fois, puis revient à idle/run.
## Bases : `attack` (sort auto), `cast` (sorts 2-3), `cast_ult` (ultime ; repli sur `cast`) ; un kit peut
## en imposer d'autres (Rictus : slash, throw, summon) via action_for(spell). Frame d'impact :
## CharacterData.action_impact_frames -> signal action_impact (Rictus : doublures posées à cette frame).
## Anim absente : repli procédural visible (recul, squash/stretch, flash de l'accent) de ACTION_FALLBACK_S.
signal action_impact(base: StringName)
const ACTION_ALIASES := {&"cast_ult": [&"cast_ult", &"cast"]}
const ACTION_FALLBACK_S := {&"attack": 0.18, &"cast": 0.22, &"cast_ult": 0.25}
const ACTION_FALLBACK_DEFAULT_S := 0.2
const ACTION_IMPACT_DEFAULT_FRAC := 0.4 ## impact sans frame déclarée : 40 % de la durée
const ACTION_RECOIL_PX := 9.0 ## recul du repli, px de la frame (192 px = 1,5 u)
const ACTION_SQUASH := 0.13
const ACTION_FLASH_HDR := 2.2 ## accent en HDR (glow de l'étalonnage)
const ACTION_FLASH_MAX := 0.75
var _action: StringName = &"" ## base en cours (&"" = aucune)
var _action_anim: StringName = &"" ## anim jouée ; &"" = repli procédural
var _action_left := 0.0
var _action_total := 0.0
var _action_impact_left := 0.0 ## s avant la frame d'impact
var _action_impact_pending := false ## impact pas encore émis
var _action_dir := Vector2.ZERO
var _action_serial := 0
var _shown_serial := -1
var _fallback_on := false
var _vis_base_scale := Vector2.ONE
var _vis_base_offset := Vector2.ZERO
var _vis_base_self_modulate := Color.WHITE

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	if character == null:
		character = CharacterData.for_id(RunState.character, RunState.loadout) # variantes de sorts choisies
	var cam := get_node_or_null(^"Camera2D") as Camera2D
	if cam != null:
		cam.zoom = Iso.camera_zoom() # vue isométrique 2:1 (Visual en billboard : échelle (k, 2k))
	spells = SpellCaster.new()
	spells.name = "Spells"
	add_child(spells)
	spells.setup(self, character)
	spells.auto_cast_enabled = auto_cast_spells
	_apply_character_look()
	add_to_group(RenderStyle.GROUP)
	apply_render_style() # style de rendu courant (3d / cel) dès l'apparition
	_capture_visual_base()
	PlayerHitbox.set_radius(_hit_radius_px, get_instance_id()) # référence (personnage sans hitbox_u)
	if character.hitbox_u > 0.0:
		set_hitbox_u(character.hitbox_u)
	_hitbox_ring = HitboxRing.new()
	add_child(_hitbox_ring)
	if character.kit_script != null:
		kit = Node.new()
		kit.set_script(character.kit_script)
		kit.name = "Kit"
		add_child(kit)
		kit.setup(self)
	RunState.level_up.connect(_on_level_up)
	Events.enemy_killed.connect(_on_enemy_killed)
	Haptics.connect_events()
	_light = LightRig.attach(self, &"player")
	var core := LightRig.attach(self, &"player_core")
	if character.light_color.a > 0.0: # lumière propre au personnage (Averse pluie froide, Rainette jade pâle)
		_light.set_color(character.light_color)
	if character.light_core_color.a > 0.0:
		core.set_color(character.light_core_color)
	hp_changed.connect(_on_hp_changed_light)
	_recompute(true)


func _enter_tree() -> void:
	if is_node_ready(): # ré-entrée dans l'arbre (le premier passage pose le rayon dans _ready)
		PlayerHitbox.set_radius(_hit_radius_px, get_instance_id())


func _exit_tree() -> void:
	PlayerHitbox.release(get_instance_id())
	if RunState.level_up.is_connected(_on_level_up):
		RunState.level_up.disconnect(_on_level_up)
	if Events.enemy_killed.is_connected(_on_enemy_killed):
		Events.enemy_killed.disconnect(_on_enemy_killed)
	if _hitstop_active: # jamais de jeu ralenti qui survive au joueur
		_hitstop_active = false
		Engine.time_scale = 1.0


# --- Stats ---------------------------------------------------------------

func stat(key: StringName) -> float:
	return float(stats.get(key, 0.0))


func crit_chance() -> float:
	return clampf(Balance.BASE_CRIT_CHANCE + stat(&"crit_chance"), 0.0, 1.0)


func crit_mult() -> float:
	return Balance.BASE_CRIT_MULT + stat(&"crit_mult_add")


## Multiplicateurs de récompense (1 + bonus) lus par le système de pickups.
func xp_mult() -> float:
	return 1.0 + stat(&"xp_mult")


func gold_mult() -> float:
	return 1.0 + stat(&"gold_mult")


func luck() -> float:
	return stat(&"luck")


func special_stacks(id: StringName) -> int:
	return int(specials.get(id, 0))


func apply_stats(new_stats: Dictionary) -> void:
	stats = new_stats.duplicate(true)
	procs = (stats.get("procs", []) as Array).duplicate(true)
	specials = (stats.get("specials", {}) as Dictionary).duplicate(true)
	_recompute(false)


## Montée de niveau (façon Risk of Rain, retour joueur) : le gain de PV max est soigné (_recompute),
## plus LEVEL_UP_HEAL_PCT des PV max, un court répit et l'effet visuel rendu dans Blender.
const LEVEL_UP_HEAL_PCT := 0.25
const LEVEL_UP_INVULN_S := 1.0
const LEVEL_UP_VFX := "res://assets/sprites/vfx/level_up/level_up.tres"


func _on_level_up(_level: int) -> void:
	_recompute(false)
	Haptics.pulse(Haptics.Kind.LEVEL_UP)
	heal(max_hp * LEVEL_UP_HEAL_PCT)
	grant_invulnerability(LEVEL_UP_INVULN_S)
	LightRig.flash(global_position, &"level_up", 0.8)
	if ResourceLoader.exists(LEVEL_UP_VFX):
		var fx := AnimatedSprite2D.new()
		fx.scale = Iso.UNSQUASH # billboard : effet volumique
		add_child(fx)
		EmissiveOverlay.apply(fx, load(LEVEL_UP_VFX) as SpriteFrames)
		fx.sprite_frames.set_animation_loop(&"default", false)
		fx.play(&"default")
		fx.animation_finished.connect(fx.queue_free)


## PV max recalculés (kit.max_hp_mult changé : masse de Bourbe). full_heal : PV pleins.
func refresh_max_hp(full_heal := false) -> void:
	_recompute(full_heal)


func _recompute(full_heal: bool) -> void:
	var base := character.max_hp_at(RunState.level) if character != null else Balance.player_max_hp(RunState.level)
	var old_max := max_hp
	max_hp = base * (1.0 + stat(&"max_hp_pct")) + stat(&"max_hp_flat")
	if kit != null and kit.has_method(&"max_hp_mult"): # kit : PV max réduits (masse détachée de Bourbe)
		max_hp *= kit.max_hp_mult()
	if full_heal:
		hp = max_hp
	elif max_hp > old_max:
		hp += max_hp - old_max # un gain de PV max se ressent tout de suite
	hp = minf(hp, max_hp)
	pickup_radius = BASE_PICKUP_RADIUS * (1.0 + stat(&"pickup_radius_mult"))
	hp_changed.emit(hp, max_hp)


func regen_per_s() -> float:
	# régén plate des items, qui suit le niveau comme la régén de base (RoR2)
	var base := character.regen_at(RunState.level) if character != null else Balance.player_regen(RunState.level)
	var r := base + stat(&"regen_flat") * (1.0 + 0.2 * (RunState.level - 1))
	if not _poison.is_empty():
		r *= POISON_REGEN_MULT
	return r


func move_speed() -> float:
	var m := character.speed_mult() if character != null else 1.0
	if kit != null:
		m *= kit.speed_mult()
	return Balance.move_speed_px(stat(&"move_speed")) * m * slow_mult()


func slow_mult() -> float:
	if kit != null and kit.slow_immune():
		return 1.0
	var m := (1.0 - SLOW_FRACTION) if _slow_left > 0.0 else 1.0
	return maxf(SLOW_FLOOR, minf(m, _slow_param))


## Armure totale : base du personnage + items.
func armor() -> float:
	return stat(&"armor") + (character.armor if character != null else 0.0)


## Rayon de la hitbox en unités (Rictus 0,45 u, 0,5 u en toupie) ; relatif à la forme de la scène (0,5 u).
## Règle à la fois le cercle de collision (déplacement) et le rayon de DÉGÂTS (PlayerHitbox : contact, projectiles,
## boss, pièges) ; l'anneau de hitbox au sol suit.
func set_hitbox_u(u: float) -> void:
	_hit_radius_px = PlayerHitbox.px_for_u(u)
	if is_inside_tree():
		PlayerHitbox.set_radius(_hit_radius_px, get_instance_id())
	var cs := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is CircleShape2D):
		return
	if _base_hitbox_px <= 0.0:
		cs.shape = cs.shape.duplicate()
		_base_hitbox_px = (cs.shape as CircleShape2D).radius
	(cs.shape as CircleShape2D).radius = _base_hitbox_px * u / 0.5


## Rayon de DÉGÂTS du joueur (px) : celui de tous les tests de coup reçu (PlayerHitbox) et de l'anneau au sol.
func hit_radius_px() -> float:
	return _hit_radius_px


## Point d'impact précis du prochain coup de cette image (projectile ennemi) : oriente l'éclat de l'anneau de
## hitbox mieux que la position de la source. Facultatif (sinon : position de `source`).
func note_hit_from(world_pos: Vector2) -> void:
	if _hitbox_ring != null:
		_hitbox_ring.note_hit_from(world_pos)


func hitbox_ring() -> HitboxRing:
	return _hitbox_ring


## Style de rendu (RenderStyle) : recharge les frames `_cel` / d'origine sans casser l'anim en cours.
func apply_render_style() -> void:
	RenderStyle.restyle_sprite(_visual as AnimatedSprite2D)


## Debug : F7 bascule le style de rendu 3D / cel-shadé à chaud (joueur et monstres vivants).
func _unhandled_key_input(event: InputEvent) -> void:
	if RenderStyle.is_toggle_event(event):
		RenderStyle.toggle(get_tree())
		get_viewport().set_input_as_handled()


## Purge le ralentissement en cours (début de la Toupie de Rictus).
func clear_slow() -> void:
	_slow_left = 0.0
	_slows.clear()
	_slow_param = 1.0


## SpriteFrames du personnage si livrées ; sinon celles de la scène (Ardent) teintées : placeholder propre.
func _apply_character_look() -> void:
	var spr := _visual as AnimatedSprite2D
	if spr == null or character == null or character.sprite_frames_path == "":
		return
	if ResourceLoader.exists(character.sprite_frames_path):
		var sf := load(character.sprite_frames_path) as SpriteFrames
		if sf != null:
			EmissiveOverlay.apply(spr, sf)
			var first: StringName = &"idle_s" if sf.has_animation(&"idle_s") else StringName(sf.get_animation_names()[0])
			spr.play(first)
			return
	spr.self_modulate = character.placeholder_tint
	spr.scale *= character.placeholder_scale


# --- Boucle --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	if InputMap.has_action(&"dodge") and Input.is_action_just_pressed(&"dodge"):
		dodge()
	if _dodge_left > 0.0:
		_dodge_step(delta)
	elif kit != null and kit.has_method(&"locomote"): # locomotion propre au kit (S11, bonds de Rainette)
		kit.locomote(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta)
	else:
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var want := dir * move_speed()
		var inertia: float = kit.inertia_s() if kit != null else 0.0
		if inertia > 0.0: # glisse (Toupie) : la vitesse rejoint la consigne en `inertia` s
			velocity = velocity.move_toward(want, move_speed() / inertia * delta)
			is_moving = velocity.length_squared() > 1.0
		else:
			velocity = want
			is_moving = dir.length_squared() > 0.0001
		if dir.length_squared() > 0.0001 and not (kit != null and kit.locks_facing()) and not action_locks_facing():
			facing = dir.normalized()
		move_and_slide()
	if _push_left > 0.0:
		_push_step(delta)
	tick(delta)
	_update_visual(delta)


## Temps, régénération, statuts, cooldowns de sorts. Public pour les tests.
func tick(delta: float) -> void:
	if dead:
		return
	_invuln = maxf(_invuln - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_riposte_cd = maxf(_riposte_cd - delta, 0.0)
	_action_step(delta)
	if kit != null:
		kit.tick(delta)
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow_immune = SLOW_IMMUNITY
	elif _slow_immune > 0.0:
		_slow_immune -= delta
	if not _slows.is_empty():
		_tick_slows(delta)
	var dot := 0.0
	if _burn_left > 0.0:
		dot += _burn_dps * minf(delta, _burn_left)
		_burn_left -= delta
	for p in _poison:
		dot += p.dps * minf(delta, p.t)
		p.t -= delta
	_poison = _poison.filter(func(p): return p.t > 0.0)
	if dot > 0.0:
		_damage_hp(dot * (1.0 - clampf(stat(&"dot_taken_reduction"), 0.0, MITIGATION_CAP)))
		if dead:
			return
	if hp < max_hp:
		hp = minf(hp + regen_per_s() * delta, max_hp)
		hp_changed.emit(hp, max_hp)
	spells.tick(delta)


# --- Dégâts, soin, statuts ----------------------------------------------

func take_damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0.0 or _invuln > 0.0 or _dodge_left > 0.0:
		return
	if kit != null and kit.has_method(&"ignores_hit") and kit.ignores_hit(source): # ex. en l'air : pas de contact
		return
	var frac := Balance.MAX_HIT_FRACTION
	if source != null and source.is_in_group("bosses"):
		frac = Balance.MAX_HIT_FRACTION_BOSS
	amount = minf(amount, max_hp * frac)
	if randf() < clampf(stat(&"dodge"), 0.0, DODGE_CAP):
		return
	var keep := (1.0 - Balance.armor_reduction(armor())) * (1.0 - clampf(stat(&"damage_taken_reduction"), 0.0, 1.0))
	if kit != null and kit.has_method(&"damage_taken_mult"): # défense propre au kit (garde de mêlée…), plafonnée
		keep *= clampf(float(kit.damage_taken_mult(source)), 0.0, 1.0)
	amount *= maxf(keep, 1.0 - MITIGATION_CAP)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
	_invuln = INVULN_AFTER_HIT
	Events.player_damaged.emit(amount, source)
	_damage_hp(amount)
	if not dead:
		Haptics.hurt(amount, max_hp)
	_hurt_feedback(amount)
	if _hitbox_ring != null:
		_hitbox_ring.on_hit(source)
	if not dead and source != null and special_stacks(&"riposte") > 0 and _riposte_cd <= 0.0 \
			and is_instance_valid(source) and source.has_method("take_damage"):
		_riposte(special_stacks(&"riposte"))


## Épines (Razorwire RoR2) : RIPOSTE_BASE_FRACTION du dégât de base à 5 ennemis proches (+2 par exemplaire).
func _riposte(n: int) -> void:
	_riposte_cd = RIPOSTE_COOLDOWN
	var dmg := RIPOSTE_BASE_FRACTION * Balance.player_base_damage(RunState.level)
	for e in spells.nearest_enemies(global_position, RIPOSTE_RANGE_U * Balance.UNIT_PX, 5 + 2 * (n - 1)):
		e.take_damage(dmg, false, &"")


func _damage_hp(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0 and not dead:
		dead = true
		velocity = Vector2.ZERO
		Haptics.pulse(Haptics.Kind.DEATH)
		Events.player_died.emit()


## Retour visuel d'un coup direct (pas des DoT) : voir HURT_*.
func _hurt_feedback(amount: float) -> void:
	_hurt_flash_left = HURT_FLASH_S
	_hurt_flash_color = HURT_FLASH_COLOR if Quality.flashes_level > 0 else HURT_FLASH_COLOR_SOFT
	if _visual != null:
		_visual.modulate = _hurt_flash_color
	if amount <= 0.0 or not is_inside_tree():
		return # entièrement absorbé par le bouclier : flash seul
	var frac := amount / maxf(max_hp, 1.0)
	HurtFeedback.ensure(self).pulse(frac)
	var big := frac >= HURT_BIG_HIT_FRAC
	var shaker := _find_shaker()
	if shaker != null:
		shaker.shake((HURT_SHAKE_BIG_PX if big else HURT_SHAKE_SMALL_PX), HURT_SHAKE_HZ, HURT_SHAKE_S)
	if big and GameSettings.hitstop_enabled():
		_hitstop(HURT_HITSTOP_S)


## Flash rouge restant (tests, debug).
func hurt_flash_left() -> float:
	return _hurt_flash_left


## Nœud qui porte la secousse de caméra (Main.shake) : premier ancêtre qui l'expose.
func _find_shaker() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method(&"shake"):
			return n
		n = n.get_parent()
	return null


## Hitstop global court (gros coup reçu) : temps ralenti, rétabli en temps réel (même en pause).
func _hitstop(seconds: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = HURT_HITSTOP_SCALE
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if _hitstop_active:
			_hitstop_active = false
			Engine.time_scale = 1.0)


## Hitstop global en cours (tests).
static func hitstop_active() -> bool:
	return _hitstop_active


func add_shield(amount: float) -> void:
	shield += maxf(amount, 0.0)


## Protection temporaire (reprise après la pause : 1,5 s). Ne raccourcit jamais une protection en cours.
func grant_invulnerability(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)


func is_invulnerable() -> bool:
	return _invuln > 0.0 or _dodge_left > 0.0


# --- Roulade ---------------------------------------------------------------

func is_dodging() -> bool:
	return _dodge_left > 0.0


## Recharge de la roulade pour l'UI : {remaining, total, active}.
func get_dodge_cooldown() -> Dictionary:
	return {"remaining": _dodge_cd, "total": Balance.DODGE_COOLDOWN_S, "active": _dodge_left > 0.0,
		"blocked": kit != null and not kit.can_dodge()}


## Fraction restante de la roulade en cours (1 au départ, 0 à la fin).
func dodge_progress_left() -> float:
	return clampf(_dodge_left / maxf(_dodge_total, 0.001), 0.0, 1.0)


## Longueur de la roulade qui partirait maintenant (u) : hook du kit (varie en jeu : Tocsin, Averse), sinon
## CharacterData.dodge_distance_u (Avare, Bourbe), sinon Balance. Seul mécanisme de longueur de roulade.
func dodge_distance_u() -> float:
	if kit != null and kit.has_method(&"dodge_distance_u"):
		return float(kit.dodge_distance_u())
	return character.base_dodge_distance_u() if character != null else Balance.DODGE_DISTANCE_U


## Durée de la roulade en cours : vitesse de Balance constante, une roulade courte est plus brève.
func dodge_duration_s() -> float:
	return _dodge_total


## Direction par défaut : déplacement en cours, sinon curseur (clavier-souris), sinon l'avant.
func dodge_direction() -> Vector2:
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if mv.length_squared() > 0.0001:
		return mv.normalized()
	if Platform.input_mode == Platform.InputMode.KBM and is_inside_tree():
		var d := get_global_mouse_position() - global_position
		if d.length_squared() > 1.0:
			return d.normalized()
	return facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN


## Lance une roulade (dir nulle = dodge_direction()). Faux si en recharge, déjà en roulade ou mort.
func dodge(dir := Vector2.ZERO) -> bool:
	if dead or _dodge_left > 0.0 or _dodge_cd > 0.0:
		return false
	if kit != null and not kit.can_dodge(): # Rictus : pas de roulade pendant le vertige
		return false
	if dir.length_squared() < 0.0001:
		dir = dodge_direction()
	dir = dir.normalized()
	# hook : sens réel du déplacement (bond arrière de Rainette) ; l'orientation suit, le kit peut la reprendre
	_dodge_dir = kit.dodge_motion_dir(dir).normalized() if kit != null and kit.has_method(&"dodge_motion_dir") else dir
	facing = _dodge_dir
	_dodge_total = Balance.DODGE_DURATION_S * dodge_distance_u() / Balance.DODGE_DISTANCE_U
	_dodge_left = _dodge_total
	_dodge_cd = Balance.DODGE_COOLDOWN_S
	_ghost_t = 0.0
	Audio.play(DODGE_SOUND, global_position, DODGE_SOUND_DB, DODGE_SOUND_PITCH)
	if kit != null:
		kit.on_dodge_start(dir)
	return true


## Pas de roulade : vitesse constante (distance exacte), move_and_collide (les murs arrêtent,
## le reste glisse le long du mur), fantômes du sprite.
func _dodge_step(delta: float) -> void:
	var step := minf(delta, _dodge_left)
	_dodge_left -= delta
	is_moving = true
	velocity = Vector2.ZERO
	var motion := _dodge_dir * (Balance.DODGE_DISTANCE_U * Balance.UNIT_PX / Balance.DODGE_DURATION_S) * step
	var col := move_and_collide(motion)
	if col != null:
		var rest := col.get_remainder().slide(col.get_normal())
		if rest.length_squared() > 0.01:
			move_and_collide(rest)
	_ghost_t -= delta
	if _ghost_t <= 0.0 and (kit == null or kit.dodge_ghosts()):
		_ghost_t = DODGE_GHOST_EVERY_S
		_spawn_ghost()


## Copie semi-transparente de l'image courante d'Ardent qui s'estompe (effet sur l'asset existant).
func _spawn_ghost() -> void:
	var spr := _visual as AnimatedSprite2D
	if spr == null or spr.sprite_frames == null or get_parent() == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = spr.centered
	g.offset = spr.offset
	g.flip_h = spr.flip_h
	g.modulate = DODGE_GHOST_COLOR
	get_parent().add_child(g)
	g.global_transform = spr.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, DODGE_GHOST_FADE_S)
	tw.tween_callback(g.queue_free)


## Battement de la lumière du joueur plus rapide sous 30 % PV (Direction §4.1).
func _on_hp_changed_light(new_hp: float, new_max: float) -> void:
	var low := new_max > 0.0 and new_hp / new_max < 0.3
	if low != _low_hp and _light != null:
		_low_hp = low
		_light.set_rate_mult(1.6 if low else 1.0)


func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if amount >= 0.05 * max_hp and hp < max_hp:
		Audio.play(&"player.heal", global_position)
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


## data : {hit, source?}. Même filtre que take_damage : un coup que le kit ignore (Rainette en l'air au contact)
## n'applique pas non plus ses affixes d'élite.
func apply_status(status: StringName, data: Dictionary) -> void:
	if dead or _dodge_left > 0.0:
		return
	var source: Variant = data.get("source")
	if source != null and kit != null and kit.has_method(&"ignores_hit") and kit.ignores_hit(source):
		return
	var hit := float(data.get("hit", 0.0))
	match status:
		&"burn":
			_burn_dps = maxf(_burn_dps if _burn_left > 0.0 else 0.0, BURN_FRACTION * hit / BURN_TIME)
			_burn_left = BURN_TIME # se rafraîchit, ne se cumule pas
		&"poison":
			var st := {"dps": POISON_FRACTION_PER_S * hit, "t": POISON_TIME}
			if _poison.size() < POISON_MAX_STACKS:
				_poison.append(st)
			else:
				var oldest: Dictionary = _poison[0]
				for p in _poison:
					if p.t < oldest.t:
						oldest = p
				oldest.dps = st.dps
				oldest.t = POISON_TIME
		&"slow":
			if kit != null and kit.slow_immune():
				return
			if _slow_immune <= 0.0 and _slow_left <= 0.0:
				_slow_left = SLOW_TIME


func is_burning() -> bool:
	return _burn_left > 0.0


func poison_stacks() -> int:
	return _poison.size()


func is_slowed() -> bool:
	return _slow_left > 0.0 or _slow_param < 1.0


## API publique (boss, mini-boss, pièges) : ralentissement paramétré. `mult` = multiplicateur de vitesse
## (0,6 = -40 %, fils de la Tisseuse ; 0,8 = -20 %, sillon du Bouvier), `duration` s, `source` = clé (nœud,
## StringName…) : la même source rafraîchit son entrée (multiplicateur remplacé, durée prolongée), des
## sources différentes coexistent et LE PLUS FORT L'EMPORTE (jamais de cumul multiplicatif), y compris face au
## statut &"slow" (-30 %, apply_status). Plancher SLOW_FLOOR ; ni immunité de 2 s (appel à chaque image dans
## une zone permis) ni effet si le kit est insensible (kit.slow_immune) ou ignore la source (kit.ignores_hit).
## Retourne vrai si le ralentissement est posé.
func apply_slow(mult: float, duration: float, source: Variant = &"") -> bool:
	if dead or duration <= 0.0 or mult >= 1.0:
		return false
	if kit != null and kit.slow_immune():
		return false
	if source is Node and kit != null and kit.has_method(&"ignores_hit") and kit.ignores_hit(source):
		return false
	var key: Variant = (source as Object).get_instance_id() if source is Object else source
	var cur: Vector2 = _slows.get(key, Vector2(1.0, 0.0))
	_slows[key] = Vector2(clampf(mult, 0.0, 1.0), maxf(cur.y, duration))
	_slow_param = _strongest_slow()
	return true


## Retire le ralentissement paramétré d'une source (sortie d'une zone sans traîne).
func remove_slow(source: Variant) -> void:
	var key: Variant = (source as Object).get_instance_id() if source is Object else source
	if _slows.erase(key):
		_slow_param = _strongest_slow()


func _strongest_slow() -> float:
	var m := 1.0
	for v: Vector2 in _slows.values():
		m = minf(m, v.x)
	return m


func _tick_slows(delta: float) -> void:
	var gone := false
	for k in _slows.keys():
		var v: Vector2 = _slows[k]
		v.y -= delta
		if v.y <= 0.0:
			_slows.erase(k)
			gone = true
		else:
			_slows[k] = v
	if gone:
		_slow_param = _strongest_slow()


## API publique : poussée / recul du joueur qui RESPECTE LES MURS (move_and_collide, glisse le long du mur).
## `dir_or_impulse` : direction si `strength_u` >= 0 (distance totale = strength_u unités), sinon déplacement
## total en px. Étalée linéairement sur `duration` s (0 = immédiate) ; deux poussées en cours s'additionnent
## (reste de la première + nouvelle, sur la plus longue des deux durées). Jouée pendant une roulade aussi.
## Retourne faux si mort ou poussée nulle.
func push(dir_or_impulse: Vector2, strength_u: float = -1.0, duration: float = 0.25) -> bool:
	if dead:
		return false
	var disp := dir_or_impulse.normalized() * strength_u * Balance.UNIT_PX if strength_u >= 0.0 else dir_or_impulse
	if disp.length_squared() < 0.01:
		return false
	if duration <= 0.0:
		_push_move(disp)
		return true
	var rest := _push_vel * _push_left + disp
	_push_left = maxf(_push_left, duration)
	_push_vel = rest / _push_left
	return true


## Vrai pendant une poussée.
func is_pushed() -> bool:
	return _push_left > 0.0


func _push_step(delta: float) -> void:
	var step := minf(delta, _push_left)
	_push_left -= delta
	var motion := _push_vel * step
	if _push_left <= 0.0:
		_push_left = 0.0
		_push_vel = Vector2.ZERO
	_push_move(motion)


## API publique : déplacement BALAYÉ immédiat du joueur (attirance, éjection, noyade…) : move_and_collide (jamais
## à travers un mur, même fin, même à grande vitesse) + glissement, puis maintien dans la zone praticable du
## NavField (bornes de la carte, jamais dans une case de mur). `ignore` : corps physiques traversés pour ce seul
## déplacement (conteneur de la Grue tombé sur le joueur). Retourne le déplacement réel. Remplace toute écriture
## de `global_position` du joueur par un autre script.
func move_swept(offset: Vector2, ignore: Array = []) -> Vector2:
	var from := global_position
	for b in ignore:
		if b is PhysicsBody2D and is_instance_valid(b):
			add_collision_exception_with(b)
	_push_move(offset)
	for b in ignore:
		if b is PhysicsBody2D and is_instance_valid(b):
			remove_collision_exception_with(b)
	return global_position - from


func _push_move(motion: Vector2) -> void:
	var col := move_and_collide(motion)
	if col != null:
		var rest := col.get_remainder().slide(col.get_normal())
		if rest.length_squared() > 0.01:
			move_and_collide(rest)
	_keep_walkable()


## Bord de carte sans collision ou case de mur : ramené dans la zone praticable (champ du Director).
func _keep_walkable() -> void:
	if not is_inside_tree():
		return
	var d := get_tree().get_first_node_in_group(&"director")
	var nav: Variant = d.get(&"nav") if d != null else null
	if not (nav is NavField) or not (nav as NavField).is_valid():
		return
	var nf := nav as NavField
	var r := 24.0
	var cs := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		r = (cs.shape as CircleShape2D).radius
	var p := nf.clamp_to_bounds(global_position, r)
	if nf.is_wall_at(p):
		p = nf.resolve(p, r)
	if p.distance_squared_to(global_position) > 0.01:
		global_position = p


func _on_enemy_killed(_e: Node2D, pos: Vector2, _tier: int, _elite: bool) -> void:
	if not dead and pos.distance_to(global_position) <= CLOSE_KILL_U * Balance.UNIT_PX:
		close_kills += 1
	var n := special_stacks(&"morsure_vorace")
	if n > 0:
		heal(0.002 * n * max_hp)


## Sort lancé (SpellCaster) : anim d'action tournée vers `dir` (plan de sol ; nul = orientation actuelle).
## Retourne le délai avant la frame d'impact (s) ; 0 : impact déjà émis (ou pas d'anim).
func on_cast(spell: SpellData, dir := Vector2.ZERO) -> float:
	var to_impact := play_action(action_base_for(spell), dir)
	if kit != null:
		kit.on_cast(spell)
	return to_impact


# --- Anims d'action (voir ACTION_*) ----------------------------------------------

## Base d'anim d'un sort : le kit décide s'il le veut (&"" = aucune), sinon attack / cast / cast_ult.
func action_base_for(spell: SpellData) -> StringName:
	if kit != null and kit.has_method(&"action_for"):
		return kit.action_for(spell)
	if spell.is_auto:
		return &"attack"
	return &"cast_ult" if spell.slot == ArdentKit.ULTIMATE_SLOT else &"cast"


## Lance l'anim d'action `base` vers `dir`. Une action précédente dont l'impact n'est pas encore passé
## l'émet tout de suite (jamais d'effet perdu). Retourne le délai avant l'impact (s).
func play_action(base: StringName, dir := Vector2.ZERO) -> float:
	_flush_action_impact()
	if base == &"" or dead:
		return 0.0
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()
	_action = base
	_action_dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.ZERO
	_action_anim = &""
	var spr := _visual as AnimatedSprite2D
	var sf: SpriteFrames = spr.sprite_frames if spr != null else null
	var impact_frame := -1
	if sf != null:
		for name: StringName in ACTION_ALIASES.get(base, [base]):
			for a: StringName in [StringName("%s_%s" % [name, _dir_name()]), name]:
				if sf.has_animation(a) and sf.get_frame_count(a) > 0:
					_action_anim = a
					impact_frame = int(character.action_impact_frames.get(name, -1)) if character != null else -1
					break
			if _action_anim != &"":
				break
	if _action_anim != &"":
		var scale_k := maxf(absf(spr.speed_scale), 0.01)
		_action_total = ZoneEffectScript.anim_length(sf, _action_anim) / scale_k
		var fps := sf.get_animation_speed(_action_anim) * scale_k
		if impact_frame >= 0 and fps > 0.0:
			var t := 0.0
			for i in mini(impact_frame, sf.get_frame_count(_action_anim)):
				t += sf.get_frame_duration(_action_anim, i)
			_action_impact_left = t / fps
		else:
			_action_impact_left = _action_total * ACTION_IMPACT_DEFAULT_FRAC
	else:
		_action_total = float(ACTION_FALLBACK_S.get(base, ACTION_FALLBACK_DEFAULT_S))
		_action_impact_left = _action_total * ACTION_IMPACT_DEFAULT_FRAC
	_action_total = maxf(_action_total, 0.01)
	_action_left = _action_total
	_action_impact_pending = true
	_action_serial += 1
	var to_impact := maxf(_action_impact_left, 0.0)
	if _action_impact_left <= 0.0:
		_flush_action_impact()
	return to_impact


## Action en cours (&"" sinon), anim jouée (&"" = repli procédural), temps restant.
func action_base() -> StringName:
	return _action if _action_left > 0.0 else &""


func action_anim() -> StringName:
	return _action_anim if _action_left > 0.0 else &""


func action_left() -> float:
	return _action_left


## Une vraie anim d'action tient l'orientation (le personnage frappe vers sa cible) ; le repli non.
func action_locks_facing() -> bool:
	return _action_left > 0.0 and _action_anim != &"" and _action_dir != Vector2.ZERO


func _action_step(delta: float) -> void:
	if _action_left <= 0.0:
		return
	_action_left = maxf(_action_left - delta, 0.0)
	if _action_impact_pending:
		_action_impact_left -= delta
		if _action_impact_left <= 0.0:
			_flush_action_impact()
	if _action_left <= 0.0:
		_flush_action_impact()
		_action = &""


func _flush_action_impact() -> void:
	if not _action_impact_pending or _action == &"":
		return
	_action_impact_pending = false
	_action_impact_left = 0.0
	if not dead:
		action_impact.emit(_action)


func _capture_visual_base() -> void:
	if _visual == null:
		return
	_vis_base_scale = _visual.scale
	_vis_base_self_modulate = _visual.self_modulate
	if _visual is AnimatedSprite2D:
		_vis_base_offset = (_visual as AnimatedSprite2D).offset


## Repli procédural (anim d'action absente) : anticipation écrasée, recul opposé à la visée, détente étirée,
## flash de l'accent au moment de l'impact ; tout revient à la base à la fin.
func _update_action_fallback() -> void:
	var active := _action_left > 0.0 and _action_anim == &"" and _visual != null
	if not active:
		if _fallback_on:
			_fallback_on = false
			_visual.scale = _vis_base_scale
			_visual.self_modulate = _vis_base_self_modulate
			if _visual is AnimatedSprite2D:
				(_visual as AnimatedSprite2D).offset = _vis_base_offset
		return
	_fallback_on = true
	var p := 1.0 - _action_left / _action_total
	var sq := sin(PI * clampf(p / 0.35, 0.0, 1.0)) # anticipation : écrasé
	var st := sin(PI * clampf((p - 0.3) / 0.7, 0.0, 1.0)) * (1.0 - p * 0.5) # détente : étiré
	var amp := ACTION_SQUASH * (1.3 if _action == &"cast_ult" else 1.0)
	_visual.scale = _vis_base_scale * Vector2(1.0 + amp * sq - amp * 0.5 * st, 1.0 - amp * sq + amp * st)
	if _visual is AnimatedSprite2D:
		var d := _action_dir if _action_dir != Vector2.ZERO else facing
		var sd := Iso.to_screen_dir(d) if d != Vector2.ZERO else Vector2.ZERO
		(_visual as AnimatedSprite2D).offset = _vis_base_offset - sd * ACTION_RECOIL_PX * sin(PI * p)
	var acc: Color = character.accent_color if character != null else Color(1.0, 0.55, 0.2)
	var hot := Color(acc.r * ACTION_FLASH_HDR, acc.g * ACTION_FLASH_HDR, acc.b * ACTION_FLASH_HDR, _vis_base_self_modulate.a)
	var f := ACTION_FLASH_MAX * clampf(1.0 - absf(p - ACTION_IMPACT_DEFAULT_FRAC) / 0.45, 0.0, 1.0)
	_visual.self_modulate = _vis_base_self_modulate.lerp(hot, f)


## Sauvegarde de run : état du kit (`save_state()` / `load_state(d)`, ex. eau d'Averse, membres de Tocsin) ;
## {} si le personnage n'a rien à garder.
func kit_save_state() -> Dictionary:
	if kit != null and kit.has_method(&"save_state"):
		return kit.save_state()
	return {}


func kit_load_state(d: Dictionary) -> void:
	if kit != null and kit.has_method(&"load_state") and not d.is_empty():
		kit.load_state(d)


func get_spell_cooldowns() -> Array:
	return spells.get_spell_cooldowns()


# --- Visuel (nœud "Visual" remplaçable par un AnimatedSprite2D) -----------

func _dir_name() -> String:
	var i := roundi(facing.angle() / (TAU / 8.0)) % 8
	return DIR_NAMES[(i + 8) % 8]


func _update_visual(delta: float) -> void:
	if _hurt_flash_left > 0.0:
		_hurt_flash_left = maxf(_hurt_flash_left - delta, 0.0)
		var k := _hurt_flash_left / HURT_FLASH_S # retour vers le blanc sur la durée du flash
		_visual.modulate = Color.WHITE.lerp(_hurt_flash_color, k)
	_update_action_fallback()
	if _visual is AnimatedSprite2D:
		var spr := _visual as AnimatedSprite2D
		var anim := StringName(("run_" if is_moving else "idle_") + _dir_name())
		if _action_left > 0.0 and _action_anim != &"":
			anim = _action_anim
		if kit != null: # états du kit (levée, toupie, vertige) prioritaires, sinon `anim` inchangée
			anim = kit.visual_anim(anim)
		if spr.sprite_frames != null and spr.sprite_frames.has_animation(anim):
			if anim == _action_anim and _shown_serial != _action_serial:
				_shown_serial = _action_serial # nouvelle action : l'anim repart de sa première frame
				spr.play(anim)
				spr.set_frame_and_progress(0, 0.0)
			elif spr.animation != anim:
				spr.play(anim)
	else:
		var aim := _visual.get_node_or_null("Aim")
		if aim != null:
			aim.rotation = facing.angle()


## Purge tous les statuts (soin de statuts, début d'étage, tests).
func clear_statuses() -> void:
	_burn_left = 0.0
	_burn_dps = 0.0
	_poison.clear()
	_slow_left = 0.0
	_slow_immune = 0.0
	_slows.clear()
	_slow_param = 1.0
	_push_vel = Vector2.ZERO
	_push_left = 0.0
