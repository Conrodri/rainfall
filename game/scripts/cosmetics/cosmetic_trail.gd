class_name CosmeticTrail
extends Node2D
## Sillage (boutique cosmétique, docs/Boutique_Rubis.md §3.6) : émetteur UNIQUE sous le joueur, purement visuel.
##  - traces de pas (emplacement « sillage:pas ») : à chaque foulée (même cadence que les pas sonores d'AudioManager,
##    `steps.player_stride` px parcourus), un décalque `step` posé au sol et une particule `particle` qui s'éteint ;
##  - traînée d'esquive (emplacement « sillage:esquive ») : une gerbe `burst` au départ de l'esquive puis des `wake`
##    espacés pendant qu'elle dure.
## Garde-fous de lisibilité : 8 sprites vivants au plus (4 au-delà de 150 monstres), alpha <= 0,5, durée <= 0,8 s, rayon
## <= 0,4 u autour du pied, sous les créatures (z absolu -11 : au-dessus de l'eau et des éclaboussures, sous les entités),
## aucune lumière, aucune émission additive, coupé en qualité Bas. Pool de Sprite2D créé une fois : aucune allocation
## par image. Textures rendues par Codex (catalogue data/cosmetics.json) : rien n'est dessiné en code ; un Sillage dont un
## asset manque n'est pas équipé (Cosmetics.equipped_item), l'émetteur reste alors inactif.

const MAX_ALIVE := 8
const MAX_ALIVE_CROWD := 4
const CROWD_THRESHOLD := 150
const ALPHA := 0.45
const STEP_LIFE_S := 0.75
const PARTICLE_LIFE_S := 0.55
const WAKE_LIFE_S := 0.3
const WAKE_INTERVAL_S := 0.07
const Z_TRAIL := -11
const STEP_MAX_U := 0.5 ## largeur affichée maxi d'un décalque de pas (u)
const PARTICLE_MAX_U := 0.15 ## taille affichée maxi d'une particule (u)
const WAKE_MAX_U := 0.6
const RADIUS_U := 0.4
const SIDE_U := 0.12 ## pied gauche / pied droit
const DEFAULT_STRIDE_PX := 105.0
const U := 64.0

var player: Node2D = null
var step_item: Dictionary = {}
var dodge_item: Dictionary = {}
var enabled := false

var _pool: Array[Sprite2D] = []
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _rise := PackedFloat32Array() ## px/s vers le haut (particules)
var _base_alpha := PackedFloat32Array()
var _next := 0
var _alive := 0
var _stride := DEFAULT_STRIDE_PX
var _acc := 0.0
var _prev := Vector2.INF
var _side := 1.0
var _was_dodging := false
var _wake_t := 0.0
var _cap := MAX_ALIVE
var _tex_step: Texture2D = null
var _tex_particle: Texture2D = null
var _particle_frames := 1
var _tex_wake: Texture2D = null
var _tex_burst: Texture2D = null
var _rng := RandomNumberGenerator.new()


## Ajoute l'émetteur sous `p` (joueur) et lit le Sillage équipé.
static func attach(p: Node2D) -> CosmeticTrail:
	var t := CosmeticTrail.new()
	t.name = "CosmeticTrail"
	p.add_child(t)
	return t


func _ready() -> void:
	player = get_parent() as Node2D
	add_to_group(&"cosmetic_trail")
	_build_pool()
	refresh()
	if not Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.connect(_on_quality)


func _exit_tree() -> void:
	if Quality.quality_changed.is_connected(_on_quality):
		Quality.quality_changed.disconnect(_on_quality)


func _build_pool() -> void:
	_age.resize(MAX_ALIVE)
	_life.resize(MAX_ALIVE)
	_rise.resize(MAX_ALIVE)
	_base_alpha.resize(MAX_ALIVE)
	for i in MAX_ALIVE:
		var s := Sprite2D.new()
		s.name = "Mark%d" % i
		s.top_level = true # reste où il a été posé quand le joueur repart
		s.z_as_relative = false
		s.z_index = Z_TRAIL
		s.visible = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(s)
		_pool.append(s)
		_life[i] = 0.0


## Relit les Sillages équipés (profil, ou override du mode test) et la qualité.
func refresh() -> void:
	step_item = Cosmetics.equipped_item(&"sillage", Cosmetics.SILLAGE_STEPS)
	dodge_item = Cosmetics.equipped_item(&"sillage", Cosmetics.SILLAGE_DODGE)
	_tex_step = _load(step_item, "step")
	_tex_particle = _load(step_item, "particle")
	_particle_frames = 4 if _tex_particle != null and _tex_particle.get_width() >= 128 and _tex_particle.get_width() == _tex_particle.get_height() else 1
	_tex_wake = _load(dodge_item, "wake")
	_tex_burst = _load(dodge_item, "burst")
	var any := _tex_step != null or _tex_particle != null or _tex_wake != null or _tex_burst != null
	enabled = any and Quality.tier != Quality.Tier.LOW
	var am := get_node_or_null(^"/root/Audio")
	var bank: Variant = am.get(&"bank") if am != null else null
	if bank is Object and (bank as Object).get(&"config") is Dictionary:
		var steps: Variant = ((bank as Object).get(&"config") as Dictionary).get("steps", {})
		if steps is Dictionary:
			_stride = float((steps as Dictionary).get("player_stride", DEFAULT_STRIDE_PX))
	if not enabled:
		_hide_all()
	set_process(enabled)


func _load(it: Dictionary, key: String) -> Texture2D:
	var p := Cosmetics.asset(it, key)
	return load(p) as Texture2D if p != "" else null


func _on_quality(_t: int) -> void:
	refresh()


func _hide_all() -> void:
	for i in _pool.size():
		_pool[i].visible = false
		_life[i] = 0.0
	_alive = 0


func _process(delta: float) -> void:
	if player == null:
		return
	var p := player.global_position
	if _tex_step != null or _tex_particle != null:
		if is_finite(_prev.x):
			var dist := p.distance_to(_prev)
			if dist < 400.0 and dist > 0.0:
				_acc += dist
				if _acc >= _stride:
					_acc = fmod(_acc, _stride)
					_on_step(p, (p - _prev).normalized())
			else:
				_acc = minf(_acc, _stride * 0.5)
		_prev = p
	if _tex_wake != null or _tex_burst != null:
		var dodging := player.has_method(&"is_dodging") and bool(player.call(&"is_dodging"))
		if dodging and not _was_dodging and _tex_burst != null:
			_spawn(_tex_burst, p, WAKE_MAX_U, WAKE_LIFE_S, 0.0, 1)
			_wake_t = 0.0
		if dodging and _tex_wake != null:
			_wake_t -= delta
			if _wake_t <= 0.0:
				_wake_t = WAKE_INTERVAL_S
				_spawn(_tex_wake, p, WAKE_MAX_U, WAKE_LIFE_S, 0.0, 1)
		_was_dodging = dodging
	_tick(delta)


## Une foulée : décalque au pied (alterné gauche / droite) + une particule qui s'éteint en montant un peu.
func _on_step(pos: Vector2, dir: Vector2) -> void:
	_cap = MAX_ALIVE_CROWD if get_tree().get_node_count_in_group(&"enemies") > CROWD_THRESHOLD else MAX_ALIVE
	_side = -_side
	var lateral := Vector2(-dir.y, dir.x) * SIDE_U * U * _side
	var foot := pos + lateral.limit_length(RADIUS_U * U)
	if _tex_step != null:
		_spawn(_tex_step, foot, STEP_MAX_U, STEP_LIFE_S, 0.0, 1)
	if _tex_particle != null:
		_spawn(_tex_particle, foot, PARTICLE_MAX_U, PARTICLE_LIFE_S, 18.0, _particle_frames)


func _spawn(tex: Texture2D, pos: Vector2, max_u: float, life: float, rise: float, grid: int) -> void:
	if _alive >= _cap:
		return
	# emplacement libre suivant (ou le plus ancien : le pool tourne)
	var i := _next
	for k in MAX_ALIVE:
		var j := (_next + k) % MAX_ALIVE
		if _life[j] <= 0.0:
			i = j
			break
	_next = (i + 1) % MAX_ALIVE
	var s := _pool[i]
	if _life[i] <= 0.0:
		_alive += 1
	s.texture = tex
	s.hframes = grid
	s.vframes = grid
	s.frame = _rng.randi() % (grid * grid) if grid > 1 else 0 # RNG propre : ne consomme pas le hasard du jeu
	var w := float(tex.get_width()) / float(grid)
	var k_scale := minf(Iso.SPRITE_K, max_u * U / maxf(w, 1.0))
	s.scale = Iso.UNSQUASH * k_scale
	s.global_position = pos
	s.modulate = Color(1, 1, 1, ALPHA)
	s.visible = true
	_age[i] = 0.0
	_life[i] = minf(life, 0.8)
	_rise[i] = rise
	_base_alpha[i] = ALPHA


func _tick(delta: float) -> void:
	if _alive <= 0:
		return
	for i in MAX_ALIVE:
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		var s := _pool[i]
		if _age[i] >= _life[i]:
			_life[i] = 0.0
			s.visible = false
			_alive -= 1
			continue
		var f := 1.0 - _age[i] / _life[i]
		s.modulate.a = _base_alpha[i] * f
		if _rise[i] > 0.0:
			s.position.y -= _rise[i] * delta


## Nombre de sprites vivants (tests).
func alive_count() -> int:
	return _alive
