class_name CorpsePool
extends Node2D
## Cadavres des monstres de base : à la mort, le monstre joue `death_<e|s|w|n>` (direction la plus proche de son
## orientation) puis reste au sol (dernière frame) CORPSE_HOLD_S, puis s'efface en fondu CORPSE_FADE_S.
## Pool d'AnimatedSprite2D créés une fois (Director._ready) : une mort ne crée aucun nœud, elle réutilise l'emplacement
## le plus ancien (anneau). Plafond par palier de qualité (Balance.CORPSE_MAX_BY_TIER, suit Quality.quality_changed).
## Sous les pickups (z -2 < -1) et au-dessus du sol, sans collision ni lumière. Un seul _process pour tout le pool,
## éteint tant qu'aucun cadavre n'est vivant. Monstre sans anim death (anciens sprites, biomes à venir, invocations,
## boss) : try_spawn() retourne faux, l'ancien comportement (disparition immédiate) reste.

const DEATH_ANIMS: Array[StringName] = [&"death_e", &"death_s", &"death_w", &"death_n"]
## Octant d'orientation (EnemyVisual.DIRS : e se s sw w nw n ne) -> index de DEATH_ANIMS.
const DIR4_OF_OCTANT: Array[int] = [0, 1, 1, 2, 2, 3, 3, 0]
const Z_CORPSE := -2

var _sprites: Array[AnimatedSprite2D] = []
var _age := PackedFloat32Array()
var _live := PackedByteArray()
var _slot := 0 ## prochain emplacement (anneau : toujours le plus ancien)
var _cap := 40
var live_count := 0
var spawned_total := 0 ## tests


func _ready() -> void:
	z_index = Z_CORPSE
	light_mask = 0
	_cap = cap_for_tier(Quality.tier)
	prewarm(Balance.CORPSE_MAX_BY_TIER[Balance.CORPSE_MAX_BY_TIER.size() - 1])
	set_process(false)
	Quality.quality_changed.connect(_on_quality_changed)
	Events.floor_started.connect(_on_floor_started)


static func cap_for_tier(t: int) -> int:
	return Balance.CORPSE_MAX_BY_TIER[clampi(t, 0, Balance.CORPSE_MAX_BY_TIER.size() - 1)]


func prewarm(n: int) -> void:
	while _sprites.size() < n:
		var s := AnimatedSprite2D.new()
		s.visible = false
		s.light_mask = 0
		s.name = &"Corpse%d" % _sprites.size()
		add_child(s)
		_sprites.append(s)
		_age.append(0.0)
		_live.append(0)


func capacity() -> int:
	return _cap


## Fixe le plafond (tests, changement de qualité) ; les cadavres au-delà sont retirés.
func set_capacity(n: int) -> void:
	_cap = clampi(n, 1, _sprites.size())
	for i in range(_cap, _sprites.size()):
		_kill(i)
	if _slot >= _cap:
		_slot = 0


func _on_floor_started(_stage: int) -> void:
	clear()


func _on_quality_changed(t: int) -> void:
	set_capacity(cap_for_tier(t))


## Pose un cadavre si `frames` a l'anim de mort de la direction. `octant` : orientation du monstre (0..7).
## `sprite_scale`, `sprite_offset`, `tint` : ceux du sprite vivant. Retourne vrai si le cadavre est posé.
func try_spawn(pos: Vector2, frames: SpriteFrames, octant: int, sprite_scale: Vector2, sprite_offset: Vector2, tint: Color) -> bool:
	if frames == null or octant < 0:
		return false
	var anim: StringName = DEATH_ANIMS[DIR4_OF_OCTANT[octant & 7]]
	if not frames.has_animation(anim):
		return false
	var i := _slot
	_slot = (_slot + 1) % _cap
	var s := _sprites[i]
	if _live[i] == 0:
		live_count += 1
	_live[i] = 1
	_age[i] = 0.0
	s.sprite_frames = frames
	s.position = pos
	s.scale = sprite_scale
	s.offset = sprite_offset
	s.self_modulate = tint
	s.modulate = Color.WHITE
	s.visible = true
	s.play(anim)
	spawned_total += 1
	set_process(true)
	return true


func _kill(i: int) -> void:
	if _live[i] == 0:
		return
	_live[i] = 0
	_sprites[i].visible = false
	_sprites[i].stop()
	live_count -= 1
	if live_count <= 0:
		live_count = 0
		set_process(false)


## Retire tous les cadavres (changement d'étage, despawn).
func clear() -> void:
	for i in _sprites.size():
		_kill(i)
	_slot = 0


func _process(delta: float) -> void:
	var total := Balance.CORPSE_HOLD_S + Balance.CORPSE_FADE_S
	for i in _cap:
		if _live[i] == 0:
			continue
		var a := _age[i] + delta
		_age[i] = a
		if a >= total:
			_kill(i)
		elif a > Balance.CORPSE_HOLD_S:
			var m := _sprites[i].modulate
			m.a = 1.0 - (a - Balance.CORPSE_HOLD_S) / Balance.CORPSE_FADE_S
			_sprites[i].modulate = m


## Cadavres vivants dont l'alpha est en cours de fondu (tests).
func fading_count() -> int:
	var n := 0
	for i in _cap:
		if _live[i] != 0 and _age[i] > Balance.CORPSE_HOLD_S:
			n += 1
	return n


func sprite_at(i: int) -> AnimatedSprite2D:
	return _sprites[i]


func is_live(i: int) -> bool:
	return _live[i] != 0
