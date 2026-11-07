class_name EpreuveHold
extends Epreuve
## Tenue (docs/Design_Epreuves.md §3.5) : « Sonner la cloche » lance 40 s. Toutes les 8 s (t = 0, 8, 16, 24, 32 : 5 paquets)
## un côté est ANNONCÉ 2 s à l'avance (chevrons au sol vers ce côté), puis 4 monstres apparaissent à 10 u dans cette
## direction et marchent droit sur la cloche (`Enemy.walk_target`). Un joueur vivant à <= 3 u d'un monstre leurré lui
## retire sa cible (il redevient un monstre ordinaire) : intercepter avant le contact. Au contact (1,3 u, échantillon
## 0,25 s, même code que la barque d'Escorte) la cloche perd des PV ; à 0 PV elle s'éteint (`dim`), l'épreuve continue.
## À 40 s le mini-boss arrive par le dernier côté annoncé. Note à durée fixe, donc aux PV : >= 70 % `parfait`, > 0 `bien`,
## éteinte `fait`. L'or « fait » et le mini-boss tombent de toute façon : la Tenue note sans punir.
## Coop : PV de la cloche x 1,3 / 1,6 / 1,9 à 2 / 3 / 4 joueurs vivants au lancement (décision du 07/11/2026), paquets inchangés.
## La cloche (EpreuveHoldBell, enfant) est la cible des monstres et l'interactable ; le pilier lui-même n'a pas de sprite.

# TODO E0 : Balance.<NOM> (constantes locales, valeurs du doc §8 ; balance.gd n'est pas modifié par le lot E3)
const HOLD_HP_MINI_SHARE := 0.5 # TODO E0 : Balance.HOLD_HP_MINI_SHARE
const HOLD_DURATION_S := 40.0 # TODO E0 : Balance.HOLD_DURATION_S
const HOLD_SIDES := 3 # TODO E0 : Balance.HOLD_SIDES
const HOLD_WAVE_EVERY_S := 8.0 # TODO E0 : Balance.HOLD_WAVE_EVERY_S
const HOLD_PACKET := 4 # TODO E0 : Balance.HOLD_PACKET
const HOLD_ANNOUNCE_S := 2.0 # TODO E0 : Balance.HOLD_ANNOUNCE_S
const HOLD_SPAWN_DIST_U := 10.0 # TODO E0 : Balance.HOLD_SPAWN_DIST_U
const HOLD_LURE_BREAK_U := 3.0 # TODO E0 : Balance.HOLD_LURE_BREAK_U
const HOLD_HIT_RADIUS_U := 1.3 # TODO E0 : Balance.HOLD_HIT_RADIUS_U
const HOLD_PERFECT_HP_PCT := 0.7 # TODO E0 : Balance.HOLD_PERFECT_HP_PCT
const HOLD_ZONE_RADIUS_U := 12.0 # TODO E0 : Balance.HOLD_ZONE_RADIUS_U
const HOLD_CHEVRON_DIST_U := 4.0 ## chevrons d'annonce à 4 u de la cloche (doc §3.5)

const HIT_SAMPLE_S := 0.25 ## période de relevé des monstres au contact (comme la barque)
const CONTACT_INTERVAL_S := 1.0 ## un monstre au contact frappe une fois par seconde (Enemy.CONTACT_INTERVAL)
const PACKET_SPREAD_U := 0.8 ## écart latéral entre les monstres d'un paquet

var bell: EpreuveHoldBell = null
var sides: Array[Vector2] = [] ## HOLD_SIDES vecteurs unitaires, repère local de la carte
var order: Array[int] = [] ## côté de chaque paquet (indices dans `sides`), tiré au lancement
var next_i := 0 ## prochain paquet (0..packet_count)
var last_side := Vector2.DOWN ## dernier côté annoncé : par là arrive le mini-boss
var packets_spawned := 0
var monsters_spawned := 0
var intercepted := 0
var hits := 0 ## relevés de contact ayant blessé la cloche (mesure)
var party_override := 0 ## > 0 : nombre de joueurs pour les PV de la cloche (tests) ; 0 = joueurs vivants au lancement
var _announcing := false
var _announce_left := 0.0
var _hit_t := 0.0
var _lured: Array[Enemy] = []
var _rng := RandomNumberGenerator.new()


## Tenue de cloche en `pos` et de côtés `side_dirs` (vecteurs en repère local de la carte ; normalisés ici).
static func make(pos: Vector2, side_dirs: Array) -> EpreuveHold:
	var h := EpreuveHold.new()
	h.position = pos
	h.set_sides(side_dirs)
	return h


func _init() -> void:
	verb = &"tenue"
	uses_sprite = false
	bell = EpreuveHoldBell.new()
	bell.hold = self
	add_child(bell)
	bell.dimmed.connect(_on_bell_dimmed)


func set_sides(side_dirs: Array) -> void:
	sides.clear()
	for s in side_dirs:
		var v := Vector2.ZERO
		if s is Vector2:
			v = s
		elif s is Array and s.size() >= 2:
			v = Vector2(float(s[0]), float(s[1]))
		sides.append(v.normalized() if v.length() > 0.001 else Vector2.DOWN)
	if not sides.is_empty():
		last_side = sides[0]


# --- PV et note (à reprendre dans Balance à la fusion E0 : hold_hp / epreuve_grade_hold)
## PV de la cloche : 0,5 x PV d'un mini-boss, x (1 + 0,3 (n - 1)) en coop (= 1,3 / 1,6 / 1,9).
static func hold_hp(d: float, stage: int, n_alive: int = 1) -> float: # TODO E0 : Balance.hold_hp
	return HOLD_HP_MINI_SHARE * Balance.boss_hp(&"mini", d, stage, maxi(n_alive, 1))


## Note à durée fixe d'après la part de PV restante (cloche éteinte = hp_ratio 0).
static func grade_for(hp_ratio: float) -> StringName: # TODO E0 : Balance.epreuve_grade_hold
	if hp_ratio <= 0.0:
		return &"fait"
	return &"parfait" if hp_ratio >= HOLD_PERFECT_HP_PCT else &"bien"


## Paquets sur la durée : 40 s / 8 s -> t = 0, 8, 16, 24, 32 = 5.
static func packet_count() -> int:
	return int(ceil(HOLD_DURATION_S / HOLD_WAVE_EVERY_S - 0.001))


func zone_radius() -> float:
	return HOLD_ZONE_RADIUS_U * Balance.UNIT_PX


func interact_label() -> String:
	return "Sonner la cloche"


## Seule la cloche est interactable (le pilier n'a pas de sprite ; pas de seconde invite).
func can_interact() -> bool:
	return false


func progress() -> float:
	return clampf(elapsed / HOLD_DURATION_S, 0.0, 1.0)


func hp_ratio() -> float:
	return bell.hp_ratio() if bell != null else 1.0


func is_bell_dim() -> bool:
	return bell != null and bell.is_dim()


## Position globale à `dist_u` unités de la cloche vers le côté `idx` (repère de la carte -> monde).
func side_point(idx: int, dist_u: float) -> Vector2:
	return _dir_point(sides[idx] if idx >= 0 and idx < sides.size() else last_side, dist_u)


func _dir_point(dir: Vector2, dist_u: float) -> Vector2:
	var local := position + dir * dist_u * Balance.UNIT_PX
	var m := get_parent() as Node2D
	return m.to_global(local) if m != null else local


func _begin() -> void:
	var n := party_override if party_override > 0 else (Players.alive().size() if is_inside_tree() else 1)
	bell.arm(hold_hp(RunState.difficulty(), RunState.stage, n))
	next_i = 0
	packets_spawned = 0
	monsters_spawned = 0
	intercepted = 0
	hits = 0
	_announcing = false
	_announce_left = 0.0
	_hit_t = 0.0
	_lured.clear()
	_draw_order()
	if not sides.is_empty():
		last_side = sides[order[0]]


## Ordre des côtés : permutations successives (jamais deux fois de suite le même côté), tronquées à 5 paquets ; avec 3
## côtés chacun sort au moins une fois.
func _draw_order() -> void:
	_rng.seed = hash([int(position.x), int(position.y), RunState.stage, int(RunState.floor_start_d * 100.0)])
	order.clear()
	var count := packet_count()
	var n := maxi(sides.size(), 1)
	while order.size() < count:
		var perm: Array[int] = []
		for i in n:
			perm.append(i)
		for i in range(perm.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := perm[i]
			perm[i] = perm[j]
			perm[j] = tmp
		if n > 1 and not order.is_empty() and perm[0] == order[order.size() - 1]:
			perm.append(perm.pop_front())
		for k in perm:
			if order.size() < count:
				order.append(k)


func _run(delta: float) -> void:
	_hit_t += delta
	if _hit_t >= HIT_SAMPLE_S:
		_contact_hit(_hit_t)
		_hit_t = 0.0
	_update_lures()
	# paquets : annonce à t = k x 8 s, apparition 2 s plus tard
	if _announcing:
		_announce_left -= delta
		if _announce_left <= 0.0:
			_announcing = false
			_spawn_packet(order[next_i])
			next_i += 1
	if not _announcing and next_i < packet_count() and not sides.is_empty() and elapsed >= float(next_i) * HOLD_WAVE_EVERY_S:
		_announcing = true
		_announce_left = HOLD_ANNOUNCE_S
		last_side = sides[order[next_i]]
	if not resolved and elapsed >= HOLD_DURATION_S:
		_resolve()


func _resolve(g: StringName = &"") -> void:
	if resolved:
		return
	super._resolve(g if g != &"" else grade_for(hp_ratio()))


## Un paquet de HOLD_PACKET monstres à 10 u du côté `side_idx` (position repliée sur le sol praticable). Le plafond de
## vivants du director (pool vide : `spawn_enemy` rend null) donne un paquet plus petit, jamais plus grand.
func _spawn_packet(side_idx: int) -> int:
	var d := _director() as Director
	if d == null or sides.is_empty():
		return 0
	var dir := sides[side_idx]
	var tangent := dir.orthogonal()
	var made := 0
	for k in HOLD_PACKET:
		var off := (float(k) - float(HOLD_PACKET - 1) * 0.5) * PACKET_SPREAD_U
		var p := _walkable(d, _dir_point(dir, HOLD_SPAWN_DIST_U) + tangent * off * Balance.UNIT_PX)
		var e := d.spawn_enemy(d._pick_tier(RunState.difficulty()), p)
		if e == null:
			break
		e.walk_target = bell
		_lured.append(e)
		made += 1
	packets_spawned += 1
	monsters_spawned += made
	return made


func _walkable(d: Director, p: Vector2) -> Vector2:
	if d.nav != null and not d.nav.is_reachable(p):
		return d.nav.nearest_reachable(p)
	return p


## Interception : un joueur vivant à <= 3 u d'un monstre leurré lui retire `walk_target`.
func _update_lures() -> void:
	if _lured.is_empty():
		return
	var brk := HOLD_LURE_BREAK_U * Balance.UNIT_PX
	var players: Array[Node2D] = Players.alive() if is_inside_tree() else []
	var keep: Array[Enemy] = []
	for e in _lured:
		if not is_instance_valid(e) or not e.active or e.walk_target != bell:
			continue # mort, recyclé par le pool ou déjà libéré
		var freed := false
		for pl in players:
			if pl.global_position.distance_to(e.global_position) <= brk:
				e.walk_target = null
				intercepted += 1
				freed = true
				break
		if not freed:
			keep.append(e)
	_lured = keep


## Blessure de la cloche par les monstres à portée de contact (somme de leurs dégâts / CONTACT_INTERVAL_S x durée écoulée).
func _contact_hit(dt: float) -> void:
	if bell.state != EpreuveHoldBell.STATE_RINGING or not is_inside_tree():
		return
	var dps := _contact_dps()
	if dps > 0.0:
		hits += 1
		bell.damage(dps * dt)


func _contact_dps() -> float:
	var total := 0.0
	var reach := HOLD_HIT_RADIUS_U * Balance.UNIT_PX
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.active or e.is_boss:
			continue
		if e.global_position.distance_to(bell.global_position) <= reach + e.radius_px:
			total += e.damage
	return total / CONTACT_INTERVAL_S


func _on_bell_dimmed() -> void:
	clean = false


func _on_resolved() -> void:
	_announcing = false
	for e in _lured:
		if is_instance_valid(e) and e.walk_target == bell:
			e.walk_target = null
	_lured.clear()
	if bell != null and not bell.is_dim():
		bell.set_state(EpreuveHoldBell.STATE_OFF)


## Mini-boss : arrive par le dernier côté annoncé, à 10 u de la cloche, et marche (écart au socle : position imposée).
func _spawn_mini() -> void:
	var d := _director() as Director
	if d == null:
		push_warning("Epreuve : aucun Director (groupe `director`), pas de mini-boss.")
		return
	if boss_id != &"":
		d.set_meta(&"next_boss_id", boss_id)
		d.set_meta(&"next_mini_id", boss_id)
	_boss = d.spawn_boss(&"mini", _walkable(d, _dir_point(last_side, HOLD_SPAWN_DIST_U)))
	if d.has_meta(&"next_mini_id"):
		d.remove_meta(&"next_mini_id")
	if _boss != null and boss_id != &"":
		_boss.set_meta(&"boss_id", boss_id)
	_send_zone(true)


func _exit_tree() -> void:
	_lured.clear()
	super._exit_tree()


# --- Sauvegarde : {"t", "hp", "max_hp", "order", "next_i", "dim", "last_side", ...}. Les monstres leurrés ne sont pas sauvés.
func _extra_dict() -> Dictionary:
	return {
		"t": elapsed, "hp": bell.hp, "max_hp": bell.max_hp, "order": order.duplicate(), "next_i": next_i,
		"dim": bell.is_dim(), "last_side": [last_side.x, last_side.y],
		"packets": packets_spawned, "monsters": monsters_spawned, "intercepted": intercepted, "hits": hits,
	}


func _extra_restore(d: Dictionary) -> void:
	_apply_saved(d, true)


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var e: Dictionary = d.get("epreuve", {}) if d.get("epreuve") is Dictionary else {}
	if bool(e.get("resolved", false)): # _extra_restore n'est appelé que pour une épreuve en cours
		_apply_saved(e, false)


func _apply_saved(e: Dictionary, running: bool) -> void:
	order.clear()
	for i in e.get("order", []):
		order.append(clampi(int(i), 0, maxi(sides.size() - 1, 0)))
	next_i = clampi(int(e.get("next_i", 0)), 0, packet_count())
	var ls: Variant = e.get("last_side", null)
	if ls is Array and ls.size() >= 2:
		last_side = Vector2(float(ls[0]), float(ls[1]))
	packets_spawned = int(e.get("packets", 0))
	monsters_spawned = int(e.get("monsters", 0))
	intercepted = int(e.get("intercepted", 0))
	hits = int(e.get("hits", 0))
	bell.restore(float(e.get("hp", 0.0)), float(e.get("max_hp", 0.0)), bool(e.get("dim", false)), running)
	if order.size() < packet_count() and not sides.is_empty():
		_draw_order()
	_announcing = false # une annonce interrompue repart : le paquet dû est ré-annoncé 2 s
	_announce_left = 0.0
	_hit_t = 0.0
	_lured.clear()


# --- Dessin provisoire (couche des télégraphes)
func draw_overlay(c: Node2D) -> void:
	if state == Pillar.STATE_DONE or sides.is_empty():
		return
	var active := is_running()
	var u := Balance.UNIT_PX
	var origin := c.to_local(global_position)
	var announced := order[next_i] if (_announcing and next_i < order.size()) else -1
	for i in sides.size():
		var dir_px := (side_point(i, 1.0) - global_position).normalized() # direction du côté dans le monde
		var col := Color(0.95, 0.75, 0.3, 0.25 if active else 0.12)
		var k := 0.0
		if i == announced:
			k = 1.0 - clampf(_announce_left / HOLD_ANNOUNCE_S, 0.0, 1.0)
			col = Color(1.0, 0.3, 0.2, 0.45 + 0.5 * k)
		var perp := dir_px.orthogonal()
		for j in 3: # 3 chevrons
			var base := origin + dir_px * (HOLD_CHEVRON_DIST_U + 0.9 * float(j)) * u
			c.draw_colored_polygon(PackedVector2Array([base + dir_px * 22.0, base - dir_px * 14.0 + perp * 22.0, base - dir_px * 14.0 - perp * 22.0]), col)
		if i == announced:
			c.draw_arc(origin + dir_px * HOLD_SPAWN_DIST_U * u, 1.2 * u, 0.0, TAU, 24, Color(1.0, 0.3, 0.2, 0.3 + 0.5 * k), 4.0)
	if active:
		c.draw_arc(origin, 1.3 * u, -PI * 0.5, -PI * 0.5 + TAU * progress(), 48, Color(0.95, 0.8, 0.4, 0.8), 5.0) # temps écoulé
