class_name ArdentTracker
extends Node
## Compteurs de déblocage des variantes d'Ardent (RunState.add_counter, versés au profil en fin de run).
## Enfant du joueur Ardent, installé par ArdentTracker.ensure_hook() (appelé par ArdentKit.variant_a()) pour ne pas
## faire de l'Ardent de base un personnage « à kit » (SpellCaster diffère les effets de l'anim d'action sans kit).
## Sans hook dans SpellCaster (signal de dégâts par sort), l'attribution se fait par observation :
##   ardent.nova_big_casts      lancers de Nova ardente qui touchent >= NOVA_BIG_HITS monstres  (-> Pilier de flamme)
##   ardent.cendres_kills       monstres morts dans une zone de Cendres active (approximation : tout kill dans la
##                              zone compte, quel que soit le sort qui porte le coup)          (-> Pluie de météores)
##   ardent.floor2_boss_kills   boss d'étage vaincu à l'étage 2                                 (-> Phénix)

const NOVA_BIG_HITS := 15
const COUNTER_NOVA := "ardent.nova_big_casts"
const COUNTER_ASH := "ardent.cendres_kills"
const COUNTER_BOSS2 := "ardent.floor2_boss_kills"
const BOSS_FLOOR := 2
const ZoneScript := preload("res://scripts/spells/zone_effect.gd")

static var _hooked := false

var player: Node = null
var _cur: Node = null ## zone en cours de création (ses coups partent de façon synchrone dans setup)
var _hits := {} ## monstres touchés par la zone en cours
var _ash: Array = [] ## zones de Cendres vues


## Branche une fois l'installation du tracker sur tout joueur Ardent qui apparaît.
static func ensure_hook() -> void:
	if _hooked:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hooked = true
	tree.node_added.connect(_on_node_added)


static func _on_node_added(n: Node) -> void:
	if n is CharacterBody2D and &"kit" in n and &"character" in n:
		n.ready.connect(install.bind(n), CONNECT_ONE_SHOT)


## Ajoute le tracker au joueur s'il est Ardent (sinon rien). Rend le tracker, ou null.
static func install(p: Node) -> ArdentTracker:
	var cd: Variant = p.get(&"character")
	if not (cd is CharacterData) or (cd as CharacterData).id != &"ardent":
		return null
	var existing := p.get_node_or_null("ArdentTracker")
	if existing is ArdentTracker:
		return existing
	var t := ArdentTracker.new()
	t.name = "ArdentTracker"
	p.add_child(t)
	t.setup(p)
	return t


func setup(new_player: Node) -> void:
	player = new_player
	var sp: Variant = player.get(&"spells")
	if sp is SpellCaster and (sp as SpellCaster).effects_parent() != null:
		(sp as SpellCaster).effects_parent().child_entered_tree.connect(_on_fx)
	Events.enemy_damaged.connect(_on_damaged)
	Events.enemy_killed.connect(_on_killed)
	Events.boss_killed.connect(_on_boss_killed)


func _on_fx(n: Node) -> void:
	if n.get_script() != ZoneScript:
		return
	_cur = n
	_hits.clear()
	_finish.call_deferred(n)


## Coup porté pendant la création de la zone `_cur` (ZoneEffect.setup applique son premier tick de façon synchrone).
func _on_damaged(e: Node2D, _amount: float, _crit: bool, _element: StringName) -> void:
	if _cur == null or not is_instance_valid(_cur) or e == null or not is_instance_valid(e):
		return
	var s: Variant = _cur.get(&"spell")
	if not (s is SpellData) or (s as SpellData).id != &"nova_ardente":
		return
	var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
	if e.global_position.distance_to(_cur.global_position) <= float(_cur.get(&"radius")) + er:
		_hits[e.get_instance_id()] = true


func _finish(n: Node) -> void:
	if n != null and is_instance_valid(n):
		var s: Variant = n.get(&"spell")
		if s is SpellData:
			match (s as SpellData).id:
				&"nova_ardente":
					if _cur == n and _hits.size() >= NOVA_BIG_HITS:
						RunState.add_counter(COUNTER_NOVA)
				&"cendres":
					_ash.append(n)
	if _cur == n:
		_cur = null
		_hits.clear()


func _on_killed(enemy: Node2D, pos: Vector2, _tier: int, _elite: bool) -> void:
	if _ash.is_empty():
		return
	var er: float = float(enemy.get(&"radius_px")) if enemy != null and &"radius_px" in enemy else 0.0
	var n := 0
	for i in range(_ash.size() - 1, -1, -1):
		var z: Variant = _ash[i] # peut être libérée : pas de type Node avant is_instance_valid
		if not is_instance_valid(z) or (z as Node).is_queued_for_deletion():
			_ash.remove_at(i)
			continue
		if z.has_method(&"is_ending") and z.is_ending():
			continue
		if n == 0 and pos.distance_to(z.global_position) <= float(z.get(&"radius")) + er:
			n = 1 # un monstre ne compte qu'une fois, même dans deux zones
	if n > 0:
		RunState.add_counter(COUNTER_ASH)


func _on_boss_killed(_boss: Node2D, is_floor_boss: bool) -> void:
	if is_floor_boss and RunState.stage == BOSS_FLOOR:
		RunState.add_counter(COUNTER_BOSS2)
