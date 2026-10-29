class_name ArdentBaseKit
extends Node
## Nœud de kit d'Ardent de base (docs/Design_Combos.md §3 et §6) : porte la marque « braise » des combos
## « ce qui brûle explose plus fort ». ArdentVariantKit en hérite et ajoute les sorts des variantes.
## Hooks facultatifs lus par SpellCaster : combo_coef_add / combo_mult / combo_hit / combo_ready / is_marked /
## on_spell_hit / auto_cast_ok ; par DodgeMove : on_dodge_end(from, to).
## Marque : { instance_id: {"t": fin (s du kit), "ref": WeakRef, "zone": WeakRef|null} }, comme AvareKit.marks.
## Posée par Cendres (chaque tick), Pluie de météores (chaque impact), Phénix (chaque piqué) et la silhouette de
## braises de l'Éclat (au DÉPART seulement). Un coup d'Éclat de braise ou une orbe des Braises errantes sur un marqué
## la prolonge ; la Nova (ou le Pilier de flamme) la consomme (+30 %), le Brasier (ou l'explosion du Phénix) aussi.
## Pas de boucle par monstre et par image : tout passe par les coups portés ; seul le nettoyage tourne 2 fois/s.

const EMBER_MARK_S := 1.5 ## durée d'une pose (rafraîchie à chaque pose)
const EMBER_MARK_MAX_S := 3.0 ## plafond de durée restante
const EMBER_MARK_EXTEND_S := 0.6 ## Éclat de braise / orbe sur un marqué
const NOVA_EMBER_MULT := 1.3 ## Nova (et premier tick du Pilier) sur un marqué
const ASH_EXTEND_S := 1.0 ## la Cendres qui a posé la marque consommée par la Nova gagne 1 s (une fois par Cendres)
const BRASIER_EMBER_ADD := 1.0 ## coef ajouté au Brasier / explosion du Phénix par marqué touché
const ASH_FLARE_COEF := 2.0 ## flambée d'une Cendres dans le rayon du Brasier
const ASH_FLARE_RADIUS_U := 2.5
const BLINK_MARK_U := 1.2 ## rayon de la silhouette de départ de l'Éclat
const NOVA_PULSE_U := 3.5 ## le bouton de la Nova pulse si un marqué est à cette distance
const AUTO_HOLD_MIN_U := 3.5 ## aide mobile : marqués juste hors de portée de la Nova auto
const AUTO_HOLD_MAX_U := 4.5
const AUTO_HOLD_MAX_S := 0.5 ## retard maximal de la Nova auto
const PRUNE_EVERY_S := 0.5
const ASH_ID := &"cendres"
const ZoneScript := preload("res://scripts/spells/zone_effect.gd")
const NOVA_IDS := [&"nova_ardente", &"flame_pillar"]
const BRASIER_IDS := [&"brasier", &"phoenix_burst"]
const EXTEND_IDS := [&"eclat_de_braise", &"roaming_embers"]
const MARK_IDS := [&"cendres", &"meteor_rain", &"phoenix"]

var player: CharacterBody2D = null
var marks := {} ## instance_id -> {"t": float, "ref": WeakRef, "zone": WeakRef ou null}
var _clock := 0.0
var _prune_t := 0.0
var _hold_since := -1.0 ## début du retard de la Nova auto (-1 : aucun)
var _flare_spell: SpellData = null


func setup(new_player: CharacterBody2D) -> void:
	player = new_player
	Events.player_died.connect(_on_player_died)
	Events.floor_started.connect(_on_floor_started)
	Events.enemy_killed.connect(_on_enemy_killed)
	var sp: Variant = player.get(&"spells")
	if sp is SpellCaster and (sp as SpellCaster).effects_parent() != null:
		(sp as SpellCaster).effects_parent().child_entered_tree.connect(_on_fx)


# --- Hooks génériques du joueur (aucun effet : Ardent de base se joue comme sans kit) ---------------

func speed_mult() -> float:
	return 1.0


func slow_immune() -> bool:
	return false


func inertia_s() -> float:
	return 0.0


func locks_facing() -> bool:
	return false


func can_dodge() -> bool:
	return true


func on_dodge_start(_dir: Vector2) -> void:
	pass


func dodge_ghosts() -> bool:
	return true


func visual_anim(anim: StringName) -> StringName:
	return anim


func on_cast(_spell: SpellData) -> void:
	pass


## Sorts de base d'Ardent : tir / zone à la frame d'impact de l'anim d'action (comme avant le kit).
func defers_effects() -> bool:
	return true


## Mêmes bases d'anim que Player.action_base_for sans kit.
func action_for(spell: SpellData) -> StringName:
	if spell.is_auto:
		return &"attack"
	return &"cast_ult" if spell.slot == ArdentKit.ULTIMATE_SLOT else &"cast"


func tick(delta: float) -> void:
	_clock += delta
	_prune_t -= delta
	if _prune_t <= 0.0:
		_prune_t = PRUNE_EVERY_S
		_prune()


# --- Marque braise ----------------------------------------------------------------------------

func is_marked(e: Node) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	var m: Variant = marks.get(e.get_instance_id())
	return m != null and float(m["t"]) > _clock


## Temps de marque restant (s), 0 sans marque.
func mark_left(e: Node) -> float:
	if e == null or not is_instance_valid(e):
		return 0.0
	var m: Variant = marks.get(e.get_instance_id())
	return maxf(float(m["t"]) - _clock, 0.0) if m != null else 0.0


## Pose (ou rafraîchit) la marque : fin = max(fin actuelle, maintenant + dur), plafonnée à EMBER_MARK_MAX_S.
func add_mark(e: Node, dur := EMBER_MARK_S, zone: Node = null) -> void:
	if e == null or not is_instance_valid(e) or e.get(&"active") == false:
		return
	var id := e.get_instance_id()
	var m: Variant = marks.get(id)
	var end := _clock + dur
	var zref: WeakRef = null
	if m != null:
		if float(m["t"]) > _clock:
			end = maxf(end, float(m["t"]))
		zref = m["zone"]
	if zone != null:
		zref = weakref(zone)
	marks[id] = {"t": minf(end, _clock + EMBER_MARK_MAX_S), "ref": weakref(e), "zone": zref}


## Prolonge une marque vivante de `secs` (plafond EMBER_MARK_MAX_S). Sans marque : rien.
func extend_mark(e: Node, secs := EMBER_MARK_EXTEND_S) -> void:
	if not is_marked(e):
		return
	var m: Dictionary = marks[e.get_instance_id()]
	m["t"] = minf(float(m["t"]) + secs, _clock + EMBER_MARK_MAX_S)


## Consomme la marque ; rend la Cendres qui l'avait posée (ou null).
func consume_mark(e: Node) -> Node:
	var id := e.get_instance_id()
	var m: Variant = marks.get(id)
	marks.erase(id)
	if m == null:
		return null
	var z: Variant = (m["zone"] as WeakRef).get_ref() if m["zone"] != null else null
	return z as Node


## Nombre de monstres marqués (tests, HUD).
func marked_count() -> int:
	var n := 0
	for id in marks:
		if float(marks[id]["t"]) > _clock:
			n += 1
	return n


## Marqués à moins de `max_u` (et au moins `min_u`) du joueur.
func marked_within(max_u: float, min_u := 0.0) -> int:
	var n := 0
	var lo := min_u * Balance.UNIT_PX
	var hi := max_u * Balance.UNIT_PX
	for id in marks:
		var m: Dictionary = marks[id]
		if float(m["t"]) <= _clock:
			continue
		var e: Variant = (m["ref"] as WeakRef).get_ref()
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var d: float = (e as Node2D).global_position.distance_to(player.global_position)
		if d <= hi and d >= lo:
			n += 1
	return n


func _prune() -> void:
	if marks.is_empty():
		return
	for id in marks.keys():
		if float(marks[id]["t"]) <= _clock or (marks[id]["ref"] as WeakRef).get_ref() == null:
			marks.erase(id)


func _on_enemy_killed(enemy: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	if enemy != null:
		marks.erase(enemy.get_instance_id()) # le pool recycle les monstres : jamais de marque héritée


func _on_floor_started(_stage: int) -> void:
	marks.clear()


func _on_player_died() -> void:
	marks.clear()


# --- Hooks de combo lus par SpellCaster -------------------------------------------------------

## Coef additif : Brasier / explosion du Phénix, +1,0 par marqué touché.
func combo_coef_add(s: SpellData, e: Node) -> float:
	return BRASIER_EMBER_ADD if BRASIER_IDS.has(s.id) and is_marked(e) else 0.0


## Multiplicateur : Nova ardente (et premier tick du Pilier de flamme) sur un marqué.
func combo_mult(s: SpellData, e: Node) -> float:
	return NOVA_EMBER_MULT if NOVA_IDS.has(s.id) and is_marked(e) else 1.0


## Chiffre en couleur d'accent et son lourd : le coup encaisse une marque.
func combo_hit(s: SpellData, e: Node) -> bool:
	return (NOVA_IDS.has(s.id) or BRASIER_IDS.has(s.id)) and is_marked(e)


## Le bouton pulse tant que le coup de ce slot encaisserait : Nova/Pilier = un marqué à portée, Brasier = en plus
## une Cendres active à 6 u.
func combo_ready(slot: int) -> bool:
	if marks.is_empty() or player == null:
		return false
	var s := _spell_at(slot)
	if s == null:
		return false
	if NOVA_IDS.has(s.id):
		return marked_within(NOVA_PULSE_U if s.id == &"nova_ardente" else s.range_u) > 0
	if s.id == &"brasier":
		return marked_within(s.radius_u) > 0 and not _ash_zones_near(s.radius_u * Balance.UNIT_PX).is_empty()
	return false


func on_spell_hit(s: SpellData, e: Node, _amount: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	var sid := s.id
	if MARK_IDS.has(sid):
		add_mark(e, EMBER_MARK_S, _ash_zone_of(e as Node2D) if sid == ASH_ID else null)
	elif EXTEND_IDS.has(sid):
		extend_mark(e)
	elif NOVA_IDS.has(sid) and is_marked(e):
		var z := consume_mark(e)
		if sid == &"nova_ardente" and z != null and is_instance_valid(z) and not bool(z.call(&"is_ending")) \
				and not z.has_meta(&"ardent_extended"):
			z.set_meta(&"ardent_extended", true)
			z.set(&"duration", float(z.get(&"duration")) + ASH_EXTEND_S) # une fois par Cendres
	elif BRASIER_IDS.has(sid) and is_marked(e):
		consume_mark(e)


## Éclat : la silhouette de braises laissée au DÉPART marque ceux qui étaient sur lui. Aucun dégât.
func on_dodge_end(from: Vector2, _to: Vector2) -> void:
	if player == null or not is_inside_tree():
		return
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get(&"active") == false:
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		if (e as Node2D).global_position.distance_to(from) <= BLINK_MARK_U * Balance.UNIT_PX + er:
			add_mark(e, EMBER_MARK_S)


## Aide mobile (auto-cast seulement) : la Nova attend au plus AUTO_HOLD_MAX_S si >= 2 marqués sont juste hors de
## portée (3,5-4,5 u) : ils arrivent.
func auto_cast_ok(slot: int) -> bool:
	var s := _spell_at(slot)
	if s == null or s.id != &"nova_ardente":
		return true
	if marked_within(AUTO_HOLD_MAX_U, AUTO_HOLD_MIN_U) < 2:
		_hold_since = -1.0
		return true
	if _hold_since < 0.0:
		_hold_since = _clock
	if _clock - _hold_since >= AUTO_HOLD_MAX_S:
		_hold_since = -1.0 # le délai est écoulé : elle part, le prochain retard repart de zéro
		return true
	return false


func _spell_at(slot: int) -> SpellData:
	var cd: Variant = player.get(&"character") if player != null else null
	if cd is CharacterData:
		for sp in (cd as CharacterData).spells:
			if sp != null and sp.slot == slot:
				return sp
	return null


# --- Cendres et flambée -----------------------------------------------------------------------

## Cendres actives de la scène (une passe sur les effets, appelée par coup de Cendres : quelques dizaines d'enfants).
func _ash_zones() -> Array:
	var out: Array = []
	var parent: Node = player.spells.effects_parent() if player != null and player.get(&"spells") != null else null
	if parent == null:
		return out
	for c in parent.get_children():
		if c.get_script() == ZoneScript and not c.is_queued_for_deletion() and c.get(&"spell") is SpellData 				and (c.get(&"spell") as SpellData).id == ASH_ID and not bool(c.call(&"is_ending")):
			out.append(c)
	return out


## Cendres qui contient ce monstre (la plus proche), null sinon.
func _ash_zone_of(e: Node2D) -> Node:
	var best: Node = null
	var bd := INF
	var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
	for z in _ash_zones():
		var d: float = e.global_position.distance_to((z as Node2D).global_position)
		if d <= float(z.get(&"radius")) + er and d < bd:
			bd = d
			best = z
	return best


func _ash_zones_near(radius_px: float) -> Array:
	var out: Array = []
	for z in _ash_zones():
		if (z as Node2D).global_position.distance_to(player.global_position) <= radius_px:
			out.append(z)
	return out


## Un Brasier (ou l'explosion du Phénix) vient d'apparaître : chaque Cendres dans son rayon s'éteint en flambée.
func _on_fx(n: Node) -> void:
	if n.get_script() == ZoneScript:
		_check_brasier.call_deferred(n)


func _check_brasier(z: Node) -> void:
	if z == null or not is_instance_valid(z) or z.is_queued_for_deletion():
		return
	var s: Variant = z.get(&"spell")
	if not (s is SpellData) or not BRASIER_IDS.has((s as SpellData).id):
		return
	var r: float = float(z.get(&"radius"))
	for a in _ash_zones():
		if (a as Node2D).global_position.distance_to((z as Node2D).global_position) <= r:
			_flare(a)


func _flare(ash: Node2D) -> void:
	if _flare_spell == null:
		_flare_spell = SpellData.new()
		_flare_spell.id = &"ash_flare"
		_flare_spell.display_name = "Flambée de cendres"
		_flare_spell.slot = 3
		_flare_spell.behavior = SpellData.Behavior.NOVA
		_flare_spell.coef = ASH_FLARE_COEF
		_flare_spell.radius_u = ASH_FLARE_RADIUS_U
		_flare_spell.proc_coef = 1.0
		_flare_spell.color = Color(1.0, 0.45, 0.1)
		ArdentKit.apply_vfx(_flare_spell)
	player.spells.spawn_zone(_flare_spell, ash.global_position)
	# la Cendres se contracte et éclate : anim `end` à x2, extinction immédiate
	ash.set(&"duration", float(ash.get(&"_t")))
	var v: Variant = ash.get(&"vfx")
	if v is AnimatedSprite2D:
		(v as AnimatedSprite2D).speed_scale = 2.0
	LightRig.flash(ash.global_position, &"nova", 0.3)
