class_name GroundPickup
extends Node2D
## S6 (Design_Personnages §3.3) : objet posé au sol que le joueur ramasse au contact (couteaux plantés
## de Rictus ; plus tard les membres de Tocsin). Pas d'aimant ; contact `contact_u` ; expiration
## `life_s` ; délai `delay_s` avant de pouvoir ramasser. Au ramassage : on_collect.call(self), puis libéré.
## Peu nombreux (≤ 15 à l'écran) : un nœud chacun, distance au joueur testée à chaque frame physique.
## Visuel : SpriteFrames `frames_path` (billboard, anim `<anim>_<dir>` ou `default`) ; absent = placeholder _draw.

const GROUP := &"ground_pickups"
## Ressource de joueur (contrat 22/10/2026) : tout GroundPickup se ramasse à la main (contact), jamais en
## automatique comme l'or et l'XP des primes (PickupManager). Les kits posent leurs ressources ici.
const PLAYER_RESOURCE := true
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"] ## ordre des planches

var contact_u := 0.6
var life_s := 4.0
var delay_s := 0.0
var on_collect: Callable = Callable()
var player: Node2D = null
var facing := Vector2.RIGHT ## direction de l'objet (couteau : sens du vol)
var color := Color("#9FC8C0")
## Repli dessiné (_draw) affiché ou non (Tocsin le coupe quand le membre a son propre sprite) ; le
## repère au sol (GroundMarker) reste visible dans tous les cas.
var show_placeholder := true
var _t := 0.0
var _sprite: AnimatedSprite2D = null

## Rayon du repère au sol par défaut (u) ; un kit le retaille via set_marker_radius_u (pièce, membre).
const MARKER_U := 0.35


## Pose l'objet à `at` (coordonnées globales) dans `parent`.
static func spawn(parent: Node, at: Vector2, p_player: Node2D, p_on_collect: Callable, p_life_s := 4.0,
		p_contact_u := 0.6, frames_path := "", p_facing := Vector2.RIGHT) -> GroundPickup:
	var g := GroundPickup.new()
	g.player = p_player
	g.on_collect = p_on_collect
	g.life_s = p_life_s
	g.contact_u = p_contact_u
	g.facing = p_facing
	parent.add_child(g)
	g.global_position = at
	g._make_visual(frames_path)
	GroundMarker.attach(g, MARKER_U, true) # ressource à ramasser : halo qui pulse doucement
	return g


## Taille du repère au sol (≈ taille de l'objet, en u).
func set_marker_radius_u(r_u: float) -> void:
	var m := GroundMarker.of(self)
	if m != null:
		m.set_radius_u(r_u)


func _ready() -> void:
	add_to_group(GROUP)


func _make_visual(frames_path: String) -> void:
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return # placeholder _draw
	var sf := load(frames_path) as SpriteFrames
	if sf == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.scale = Iso.UNSQUASH * Iso.SPRITE_K # billboard
	add_child(_sprite)
	var i := roundi(facing.angle() / (TAU / 8.0))
	var anim := StringName("default_" + DIR_NAMES[(i % 8 + 8) % 8])
	_sprite.play(anim if sf.has_animation(anim) else &"default")


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance le temps et teste le contact.
func step(delta: float) -> void:
	_t += delta
	if _t >= life_s:
		queue_free()
		return
	if _t >= delay_s and player != null and is_instance_valid(player) and not bool(player.get(&"dead")):
		if player.global_position.distance_to(global_position) <= contact_u * Balance.UNIT_PX:
			collect()
			return
	modulate.a = expire_alpha(life_s - _t, GameSettings.reduce_motion())
	if _sprite == null:
		queue_redraw()


## Alpha d'avertissement d'expiration (Audit_Choix P12) selon le temps restant : 1 hors de la dernière
## PICKUP_EXPIRE_WARN_S ; ensuite clignotement à PICKUP_EXPIRE_BLINK_HZ entre PICKUP_EXPIRE_ALPHA_MIN et 1
## (commence plein). Avec « Réduire les mouvements » : fondu continu de 1 à PICKUP_EXPIRE_ALPHA_MIN, sans clignoter.
## S'applique au nœud entier (sprite ou repli dessiné, et halo GroundMarker enfant).
static func expire_alpha(remaining: float, reduce := false) -> float:
	var warn := Balance.PICKUP_EXPIRE_WARN_S
	if remaining >= warn or warn <= 0.0:
		return 1.0
	var lo := Balance.PICKUP_EXPIRE_ALPHA_MIN
	var e := clampf(warn - remaining, 0.0, warn) # temps écoulé dans l'avertissement
	if reduce:
		return lerpf(1.0, lo, e / warn)
	return lerpf(lo, 1.0, 0.5 + 0.5 * cos(TAU * Balance.PICKUP_EXPIRE_BLINK_HZ * e))


func collect() -> void:
	if is_queued_for_deletion():
		return
	if on_collect.is_valid():
		on_collect.call(self)
	queue_free()


func _draw() -> void:
	if _sprite != null or not show_placeholder:
		return
	# placeholder (en attendant `knife_planted`) : trait argent planté dans le sens du vol, qui pâlit
	var a := clampf(1.0 - _t / maxf(life_s, 0.01), 0.25, 1.0)
	var d := facing.normalized() * 14.0
	draw_line(-d, d, Color(color.r, color.g, color.b, a), 4.0)
	draw_circle(-d, 3.0, Color(0.35, 0.25, 0.2, a))

