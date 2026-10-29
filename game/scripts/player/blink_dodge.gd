class_name BlinkDodge
extends DodgeMove
## Éclat (esquive d'Ardent, docs/Design_Esquives.md §Ardent) : il se disperse en braises (BLINK_OUT_S, immobile),
## réapparaît BLINK_DISTANCE_U plus loin d'un déplacement BALAYÉ (move_and_collide + glissement + zone praticable :
## jamais à travers un mur, jamais dans le vide hors carte ; dos au mur il parcourt ce qu'il peut), puis se reforme
## (BLINK_IN_S, déplacement et sorts permis). Invulnérable du premier au dernier instant. Recharge Balance.DODGE_COOLDOWN_S.
## Marques : silhouette de braises laissée au départ, gerbe de braises aux deux bouts (VFX ember_shard_impact tant que
## le lot Codex `dodge_blink` n'est pas livré : art/tools/vfx/_dodge_ardent.txt), éclat de lumière `ember`.

const BLINK_DISTANCE_U := 3.0
const BLINK_OUT_S := 0.06
const BLINK_IN_S := 0.14
const SOUND_OUT := [&"spell.cendres.cast_light", -4.0, 1.3]
const SOUND_IN := [&"spell.eclat_de_braise.hit_light", -8.0, 0.9]
const GHOST_COLOR := Color(1.0, 0.55, 0.2, 0.7)
const LIGHT_PRESET := &"ember"
## VFX du lot Codex (anims `out` et `in`) ; repli : ember_shard_impact (gerbe existante).
const VFX_PATH := "res://assets/sprites/vfx/dodge_blink/dodge_blink.tres"
const FALLBACK_VFX := "res://assets/sprites/vfx/ember_shard_impact/ember_shard_impact.tres"
const FX_SCALE_OUT := 0.9
const FX_SCALE_IN := 1.2

var phase := 0 ## 0 = dispersion (immobile), 1 = reformation (libre)
var phase_left := 0.0
var _jumped := false


func kind() -> StringName:
	return KIND_BLINK


func label() -> String:
	if kit != null and kit.has_method(&"dodge_label"):
		return str(kit.dodge_label())
	return "Éclat"


func distance_u() -> float:
	return BLINK_DISTANCE_U


func allows_move() -> bool:
	return active and phase == 1


func start(d: Vector2) -> bool:
	if not can_start():
		return false
	dir = _motion_dir(d)
	player.facing = dir
	start_pos = player.global_position
	active = true
	phase = 0
	phase_left = BLINK_OUT_S
	_jumped = false
	invuln_left = BLINK_OUT_S + BLINK_IN_S
	cooldown_left = cooldown_total
	player.spawn_dodge_ghost(GHOST_COLOR, 0.35)
	_burst(player.global_position, &"out", FX_SCALE_OUT)
	Audio.play(SOUND_OUT[0], player.global_position, SOUND_OUT[1], SOUND_OUT[2])
	_on_start_hook(d)
	return true


func step(delta: float) -> void:
	if not active:
		return
	phase_left -= delta
	if phase == 0:
		player.velocity = Vector2.ZERO
		player.is_moving = false
		player.set_visual_alpha(clampf(phase_left / BLINK_OUT_S, 0.0, 1.0))
		if phase_left <= 0.0:
			_jump()
			phase = 1
			phase_left = BLINK_IN_S
	else:
		player.set_visual_alpha(clampf(1.0 - phase_left / BLINK_IN_S, 0.0, 1.0))
		if phase_left <= 0.0:
			player.set_visual_alpha(1.0)
			active = false
			_on_end_hook()


## Le saut lui-même : déplacement balayé immédiat (murs, remparts, eau profonde, vide : jamais traversés).
func _jump() -> void:
	if _jumped:
		return
	_jumped = true
	_sweep(dir * BLINK_DISTANCE_U * Balance.UNIT_PX)
	_burst(player.global_position, &"in", FX_SCALE_IN)
	LightRig.flash(player.global_position, LIGHT_PRESET, 0.25)
	Audio.play(SOUND_IN[0], player.global_position, SOUND_IN[1], SOUND_IN[2])


## Gerbe de braises au sol (billboard) ; anim du lot Codex si livrée, sinon la gerbe d'impact d'Ardent.
func _burst(at: Vector2, anim: StringName, k: float) -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var path := VFX_PATH if ResourceLoader.exists(VFX_PATH) else FALLBACK_VFX
	if not ResourceLoader.exists(path):
		return
	var sf := load(path) as SpriteFrames
	if sf == null:
		return
	var a: StringName = anim if sf.has_animation(anim) else &"default"
	if not sf.has_animation(a):
		return
	var fx := AnimatedSprite2D.new()
	fx.scale = Iso.UNSQUASH * k
	fx.z_index = 5
	parent.add_child(fx)
	fx.global_position = at
	EmissiveOverlay.apply(fx, sf)
	fx.sprite_frames.set_animation_loop(a, false)
	fx.play(a)
	fx.animation_finished.connect(fx.queue_free)


func progress_left() -> float:
	if not active:
		return 0.0
	var tot := BLINK_OUT_S + BLINK_IN_S
	var left := phase_left + (BLINK_IN_S if phase == 0 else 0.0)
	return clampf(left / tot, 0.0, 1.0)


func duration_s() -> float:
	return BLINK_OUT_S + BLINK_IN_S


func reset() -> void:
	super.reset()
	if player != null:
		player.set_visual_alpha(1.0)
