class_name ArdentPhoenix
extends Node2D
## Phénix d'Ardent (variante de l'ultime) : familier volant, invulnérable (il est en feu), 12 s. Il reste près d'Ardent
## (suit à 1,4 u, laisse 8 u) et, toutes les 1,5 s, lance un trait de feu (ArdentPhoenixBolt) vers le paquet le plus
## dense à 8 u d'Ardent : le trait TRAVERSE tous les monstres sur 8 u (prolongés jusqu'au paquet visé + 1,5 u au besoin ; couloir de 0,7 u + corps du monstre) et pose
## une brûlure de 2 s sur chacun. À la fin, il se lance en un dernier trait vers le paquet le plus dense et y explose en
## se consumant (zone rayon 3 u). Un seul à la fois (ArdentVariantKit).
## Revu le 04/11/2026 (demande du joueur) : il ne fonce plus dans le tas (ancien piqué en ligne de 3 × 1 u).
## Ce n'est PAS un Decoy : il ne provoque personne (volant, intouchable) ; groupe `allies` seulement.
## Dégâts toujours via SpellCaster (deal_damage / spawn_zone) : items et procs du joueur s'appliquent.
## Visuel : assets/sprites/vfx/phoenix/phoenix.tres (rendu 55°, à re-rendre iso : brief _ardv.txt), sinon disque dessiné.

const LIFE_S := 12.0
const SPEED_U := 6.0
const SHOT_EVERY_S := 1.5
const FIRST_SHOT_S := 0.5 ## premier trait après l'invocation
const RETRY_S := 0.3 ## rien à viser : il réessaie bientôt
const AIM_RANGE_U := 8.0 ## recherche du paquet le plus dense, depuis Ardent (× portée des items)
const LEASH_U := 8.0 ## distance maximale à Ardent
const BOLT_RANGE_U := 8.0 ## course du trait depuis le phénix (× portée des items)
## Course prolongée au besoin jusqu'à la cible + cette marge : le phénix suit à 1,4 u d'Ardent, un paquet visé à 7 u
## d'Ardent peut être à 8,4 u de lui (Ardent qui fuit) ; le trait traverse toujours le paquet visé.
const BOLT_OVERSHOOT_U := 1.5
const BOLT_SPEED_U := 24.0 ## u/s (vitesse de l'ancien piqué) (× vitesse de projectile des items, plafonnée comme les projectiles du joueur)
const BOLT_HALF_W_U := 0.35 ## couloir de 0,7 u de large (+ rayon du monstre)
const HOVER_U := 1.2 ## altitude visuelle
const FOLLOW_U := 1.4 ## distance de suivi derrière Ardent
const BURN_S := 2.0
const FINAL_BOLT_SPEED_U := 24.0 ## dernier trait (le phénix lui-même) vers le paquet où il explose
const FINAL_BOLT_SCALE := 1.6 ## dernier trait : visuel agrandi
## Brûlure totale posée par chaque touche, en multiple du coef du trait (ArdentKit.PHOENIX_COEF) : la brûlure suit
## donc le réglage du coef (banc, rejeux à dégâts réduits). 0,38 + 2 × 0,38 = 1,14 Dégât_base par monstre traversé.
const BURN_PER_COEF := 2.0
const FRAMES := "res://assets/sprites/vfx/phoenix/phoenix.tres"
const SPRITE_SCALE := 0.37 ## frame 256 px -> ~1,5 u d'envergure

var caster: SpellCaster = null
var player: Node2D = null
var bolt_spell: SpellData = null
var burst_spell: SpellData = null
var life_left := LIFE_S
var exploded := false
var shots := 0 ## traits lancés (tests)
var bolt_hits := 0 ## monstres touchés par ses traits (tests ; compté par ArdentPhoenixBolt)
var _shot_cd := FIRST_SHOT_S
var _dir := Vector2.RIGHT
var _sprite: AnimatedSprite2D = null


func setup(new_caster: SpellCaster, new_player: Node2D, bolt: SpellData, burst: SpellData) -> void:
	caster = new_caster
	player = new_player
	bolt_spell = bolt
	burst_spell = burst
	name = "Phoenix"
	add_to_group(&"allies")
	global_position = player.global_position + Vector2(-FOLLOW_U * Balance.UNIT_PX, 0.0)
	_build_visual()


func _build_visual() -> void:
	if ResourceLoader.exists(FRAMES):
		var sf := load(FRAMES) as SpriteFrames
		if sf != null and sf.has_animation(&"default"):
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = sf
			_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * Iso.UNSQUASH
			_sprite.position = Vector2(0.0, Iso.lift_logical(HOVER_U))
			add_child(_sprite)
			_sprite.play(&"default")
			if VfxSwap.enabled(): # mode test : VFX de test (scripts/testmode/vfx_swap.gd)
				VfxSwap.on_sprite(_sprite, sf)
	LightRig.attach(self, &"phoenix")


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance de `delta` s.
func step(delta: float) -> void:
	if exploded:
		return
	life_left -= delta
	if life_left <= 0.0:
		explode()
		return
	_step_follow(delta)
	_shot_cd -= delta
	if _shot_cd <= 0.0:
		_try_shoot()
	if _sprite != null and absf(_dir.x) > 0.05:
		_sprite.flip_h = _dir.x < 0.0
		if VfxSwap.enabled() and VfxSwap.follower_of(_sprite) != null: VfxSwap.follower_of(_sprite).set_dir(_dir) # mode test : le VFX de test se tourne avec lui (vfx_swap.gd)


func _step_follow(delta: float) -> void:
	var u := Balance.UNIT_PX
	var want: Vector2 = player.global_position + Vector2(-FOLLOW_U * u, 0.0)
	global_position = global_position.move_toward(want, SPEED_U * u * delta)
	var off: Vector2 = global_position - player.global_position
	if off.length() > LEASH_U * u: # laisse
		global_position = player.global_position + off.normalized() * LEASH_U * u


## Trait de feu vers le monstre qui a le plus de voisins à 1,5 u (SpellCaster.densest_point), à portée d'Ardent.
func _try_shoot() -> void:
	var range_k: float = 1.0 + player.stat(&"range_add")
	var pt: Variant = caster.densest_point(AIM_RANGE_U * Balance.UNIT_PX * range_k)
	if pt == null:
		_shot_cd = RETRY_S
		return
	var d: Vector2 = (pt as Vector2) - global_position
	_dir = d.normalized() if d.length_squared() > 1.0 else Vector2.RIGHT
	_shot_cd = SHOT_EVERY_S
	shots += 1
	var u := Balance.UNIT_PX
	var spd: float = BOLT_SPEED_U * u * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	var burn_total: float = BURN_PER_COEF * bolt_spell.coef * Balance.player_base_damage(PlayerRef.state_of(player).level) \
			* (1.0 + player.stat(&"burn_damage_add"))
	var bolt := ArdentPhoenixBolt.new()
	caster.effects_parent().add_child(bolt)
	var course: float = maxf(BOLT_RANGE_U * u * range_k, d.length() + BOLT_OVERSHOOT_U * u)
	bolt.setup(caster, player, bolt_spell, global_position, _dir, spd, course, BOLT_HALF_W_U * u,
			BURN_S, burn_total, HOVER_U, self)
	Audio.play_cast(&"phoenix", global_position, bolt_spell.coef)


## Se consume : il se lance en un dernier trait (sans dégâts au passage) vers le paquet le plus dense à portée et
## explose à l'arrivée (zone du sort `burst_spell`) ; rien à viser : il explose sur place. Puis disparition.
## L'explosion reste ainsi sur les monstres (et sur les marqués : combo du Brasier, ArdentBaseKit.BRASIER_IDS) alors
## que le phénix vole près d'Ardent.
func explode() -> void:
	if exploded:
		return
	exploded = true
	if caster != null and is_instance_valid(caster) and burst_spell != null and player != null and is_instance_valid(player):
		var range_k: float = 1.0 + player.stat(&"range_add")
		var pt: Variant = caster.densest_point(AIM_RANGE_U * Balance.UNIT_PX * range_k)
		var d: Vector2 = (pt as Vector2) - global_position if pt != null else Vector2.ZERO
		if d.length() > 0.5 * Balance.UNIT_PX:
			var u := Balance.UNIT_PX
			var bolt := ArdentPhoenixBolt.new()
			bolt.on_end = ArdentPhoenix.burst_at.bind(caster, burst_spell) # statique : le phénix est libéré avant l'arrivée
			caster.effects_parent().add_child(bolt)
			bolt.setup(caster, player, null, global_position, d, FINAL_BOLT_SPEED_U * u, d.length(), 0.0, 0.0, 0.0, HOVER_U, null)
			bolt.scale_visual(FINAL_BOLT_SCALE)
		else:
			burst_at(global_position, caster, burst_spell)
	queue_free()


## Explosion finale en `pos` (appelée aussi par le dernier trait à son arrivée, après la disparition du phénix).
static func burst_at(pos: Vector2, by_caster: SpellCaster, s: SpellData) -> void:
	if by_caster == null or not is_instance_valid(by_caster) or s == null:
		return
	by_caster.spawn_zone(s, pos)
	LightRig.flash(pos, &"nova", 0.35)
	Audio.play_cast(s.id, pos, s.coef)


## Disparaît sans exploser (changement d'étage).
func dismiss() -> void:
	exploded = true
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.0, 0.0, 0.0, 0.28)) # ombre de contact
	if _sprite == null:
		draw_set_transform(Vector2(0.0, Iso.lift_logical(HOVER_U)), 0.0, Iso.UNSQUASH)
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.5, 0.15, 0.35))
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.75, 0.3, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
