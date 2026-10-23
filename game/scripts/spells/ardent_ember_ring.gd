class_name ArdentEmberRing
extends Node2D
## Braises errantes (variante du sort 1 d'Ardent) : 3 orbes qui tournent autour du joueur et brûlent ce qu'elles
## frôlent. Enfant du joueur, piloté par ArdentVariantKit.tick -> step(delta) (déterministe, testable sans rendu).
## Dégâts via SpellCaster.deal_damage (items et procs s'appliquent) ; immunité par monstre ET par orbe.
## Visuel : PLACEHOLDER dessiné en code (orbes + halo) ; l'asset final est demandé à Codex (art/tools/night/_ardv.txt).

const ORBS := 3
const PERIOD_S := 1.2 ## un tour ; divisé par (1 + vitesse d'attaque)
const ORB_RADIUS_U := 0.35
const IMMUNITY_S := 0.4 ## par monstre et par orbe
const RANGE_ADD_SHARE := 0.5 ## la portée des items agrandit le cercle de moitié seulement
const LIFT_U := 0.4
const COLOR := Color(1.0, 0.55, 0.2)

var player: CharacterBody2D = null
var caster: SpellCaster = null
var spell: SpellData = null
var hits := 0 ## touches portées (tests)
var _angle := 0.0
var _immune := {} ## clé (id du monstre × 4 + orbe) -> s restantes
var _orbs: Array[Vector2] = [] ## positions monde des orbes


func setup(new_player: CharacterBody2D, new_spell: SpellData) -> void:
	player = new_player
	caster = new_player.spells
	spell = new_spell
	name = "EmberRing"
	z_index = 1
	_recompute()


func ring_radius_px() -> float:
	return spell.range_u * Balance.UNIT_PX * (1.0 + RANGE_ADD_SHARE * player.stat(&"range_add"))


func period_s() -> float:
	return PERIOD_S / (1.0 + minf(player.stat(&"attack_speed"), Balance.ATTACK_SPEED_BONUS_CAP))


## Positions monde des orbes (tests, visuels).
func orb_positions() -> Array[Vector2]:
	return _orbs


func _recompute() -> void:
	_orbs.clear()
	var r := ring_radius_px()
	for i in ORBS:
		_orbs.append(player.global_position + Vector2.from_angle(_angle + TAU * i / ORBS) * r)


func step(delta: float) -> void:
	if player == null or caster == null or spell == null:
		return
	_angle = fposmod(_angle + TAU * delta / period_s(), TAU)
	for k in _immune.keys():
		_immune[k] -= delta
		if _immune[k] <= 0.0:
			_immune.erase(k)
	_recompute()
	if player.dead:
		queue_redraw()
		return
	var u := Balance.UNIT_PX
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage") or e.get(&"active") == false:
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var reach := ORB_RADIUS_U * u + er
		for i in ORBS:
			if e.global_position.distance_squared_to(_orbs[i]) > reach * reach:
				continue
			var key: int = e.get_instance_id() * 4 + i
			if _immune.has(key):
				continue
			_immune[key] = IMMUNITY_S
			hits += 1
			caster.deal_damage(e, spell, {"source_pos": _orbs[i]})
	queue_redraw()


func _draw() -> void:
	var lift := Iso.lift_logical(LIFT_U)
	for p in _orbs:
		var local := p - global_position
		# l'orbe est un volume : dessiné « debout » (échelle billboard) à LIFT_U au-dessus du sol
		draw_set_transform(local + Vector2(0.0, lift), 0.0, Iso.UNSQUASH)
		draw_circle(Vector2.ZERO, 11.0, Color(COLOR.r, COLOR.g, COLOR.b, 0.25))
		draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.62, 0.22, 0.95))
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.9, 0.6, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
