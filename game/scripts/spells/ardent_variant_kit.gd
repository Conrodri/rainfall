class_name ArdentVariantKit
extends Node
## Kit-nœud d'Ardent quand le joueur a choisi au moins une variante de sort à comportement propre
## (docs/Variantes_Sorts.md §2.1 ; ajouté par CharacterData.apply_loadout via la méta `kit_script` du SpellData).
## Ardent de base n'a pas de kit : ce nœud n'existe que pour les variantes.
## - Braises errantes (sort 1, auto) : ArdentEmberRing, 3 orbes qui tournent autour du joueur.
## - Pilier de flamme (sort 2) : télégraphe 0,3 s puis ZoneEffect persistante (SpellCaster.spawn_zone) + ralentissement.
## - Pluie de météores (sort 3) : 5 impacts télégraphiés 0,8 s, un toutes les 0,4 s, sur un disque de 3 u.
## - Phénix (sort 4) : ArdentPhoenix, familier de 12 s.
## Contrat de kit (Player) : setup/tick + hooks par défaut neutres ; sorts via cast_spell(s, aim).

const PILLAR_TELEGRAPH_S := 0.3
const PILLAR_SLOW_PCT := 0.30
const PILLAR_SLOW_EVERY_S := 0.2
const PILLAR_SLOW_S := 0.5
const METEOR_COUNT := 5
const METEOR_DISC_U := 3.0
const METEOR_EVERY_S := 0.4
const METEOR_TELEGRAPH_S := 0.8
const METEOR_CELL_U := 1.0

var player: CharacterBody2D = null
var ring: ArdentEmberRing = null
var phoenix: ArdentPhoenix = null
var _events: Array[Dictionary] = [] ## effets différés : {t, kind, pos, spell}
var _pillars: Array[Dictionary] = [] ## piliers actifs : {pos, r, left}
var _slow_t := 0.0


func setup(new_player: CharacterBody2D) -> void:
	player = new_player
	Events.player_died.connect(_on_player_died)
	Events.floor_started.connect(_on_floor_started)


# --- Hooks génériques du joueur (aucun effet) -------------------------------------------------

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


## Anim d'action : mêmes bases que le joueur sans kit (Player.action_base_for) ; les braises ne jouent rien.
func action_for(spell: SpellData) -> StringName:
	if spell.id == &"roaming_embers":
		return &""
	if spell.is_auto:
		return &"attack"
	return &"cast_ult" if spell.slot == ArdentKit.ULTIMATE_SLOT else &"cast"


# --- Sorts ---------------------------------------------------------------------------------

## `aim` : point monde visé (souris, stick, ou paquet le plus dense en tactile) ou null.
func cast_spell(s: SpellData, aim: Variant) -> bool:
	match s.id:
		&"roaming_embers":
			return _cast_embers(s)
		&"flame_pillar":
			return _cast_pillar(s, aim)
		&"meteor_rain":
			return _cast_meteors(s, aim)
		&"phoenix":
			return _cast_phoenix(s)
	return false


func _cast_embers(s: SpellData) -> bool:
	if ring == null or not is_instance_valid(ring):
		ring = ArdentEmberRing.new()
		player.add_child(ring)
		ring.setup(player, s)
	else:
		ring.spell = s
	# sort permanent : jamais « lancé » (ni anim, ni son à chaque cycle) ; on revient vérifier deux fois par seconde
	player.spells.set_cooldown(s.slot, 0.5, 0.5)
	return false


## Point d'effet : visé, limité à la portée du sort ; null = rien à viser.
func _target_point(s: SpellData, aim: Variant) -> Variant:
	if aim == null:
		return null
	var rng_px: float = player.spells.range_px(s)
	var off: Vector2 = ((aim as Vector2) - player.global_position).limit_length(rng_px)
	return player.global_position + off


func _zone_r_px(radius_u: float) -> float:
	return radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))


func _cast_pillar(s: SpellData, aim: Variant) -> bool:
	var pt: Variant = _target_point(s, aim)
	if pt == null:
		return false
	_events.append({"t": PILLAR_TELEGRAPH_S, "kind": &"pillar", "pos": pt, "spell": s})
	_telegraph(pt, _zone_r_px(s.radius_u), PILLAR_TELEGRAPH_S, false)
	Audio.play(&"telegraph.warn_light", pt)
	return true


func _cast_meteors(s: SpellData, aim: Variant) -> bool:
	var pt: Variant = _target_point(s, aim)
	if pt == null:
		return false
	var u := Balance.UNIT_PX
	# grille de METEOR_CELL_U : cases dont le centre est dans le disque, 5 tirées sans remise
	var cells: Array[Vector2] = []
	var n := int(ceil(METEOR_DISC_U / METEOR_CELL_U))
	for ix in range(-n, n + 1):
		for iy in range(-n, n + 1):
			var c := Vector2(ix, iy) * METEOR_CELL_U
			if c.length() <= METEOR_DISC_U:
				cells.append(c)
	var rng: RandomNumberGenerator = player.spells.rng
	for i in mini(METEOR_COUNT, cells.size()):
		var k: int = rng.randi_range(0, cells.size() - 1)
		var c: Vector2 = cells[k]
		cells.remove_at(k)
		var at: Vector2 = (pt as Vector2) + (c + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * METEOR_CELL_U) * u
		var delay := METEOR_EVERY_S * i
		_events.append({"t": delay + METEOR_TELEGRAPH_S, "kind": &"meteor", "pos": at, "spell": s})
		_events.append({"t": delay, "kind": &"telegraph", "pos": at, "spell": s}) # le cercle apparaît à son tour
	return true


func _cast_phoenix(s: SpellData) -> bool:
	if phoenix != null and is_instance_valid(phoenix) and not phoenix.exploded:
		phoenix.explode() # un seul phénix : l'ancien se consume
	var burst := ArdentKit.phoenix_burst_spell()
	phoenix = ArdentPhoenix.new()
	player.spells.effects_parent().add_child(phoenix)
	phoenix.setup(player.spells, player, s, burst)
	return true


func _telegraph(pos: Vector2, r_px: float, life: float, fall: bool) -> void:
	var t := ArdentTelegraph.new()
	t.radius = r_px
	t.life = life
	t.fall = fall
	player.spells.effects_parent().add_child(t)
	t.global_position = pos


# --- Boucle ---------------------------------------------------------------------------------

func tick(delta: float) -> void:
	if player == null or player.spells == null:
		return
	if ring != null and is_instance_valid(ring):
		ring.step(delta)
	_tick_events(delta)
	_tick_pillars(delta)


func _tick_events(delta: float) -> void:
	for i in range(_events.size() - 1, -1, -1):
		var ev := _events[i]
		ev["t"] = float(ev["t"]) - delta
		if float(ev["t"]) > 0.0:
			continue
		_events.remove_at(i)
		if player.dead:
			continue
		var s: SpellData = ev["spell"]
		var pos: Vector2 = ev["pos"]
		match ev["kind"]:
			&"pillar":
				player.spells.spawn_zone(s, pos)
				_pillars.append({"pos": pos, "r": _zone_r_px(s.radius_u), "left": s.duration})
			&"telegraph":
				_telegraph(pos, _zone_r_px(s.radius_u), METEOR_TELEGRAPH_S, true)
			&"meteor":
				player.spells.spawn_zone(s, pos) # durée 0 : impact instantané de rayon radius_u
				LightRig.flash(pos, &"meteor_impact", 0.35)


func _tick_pillars(delta: float) -> void:
	if _pillars.is_empty():
		return
	_slow_t -= delta
	var do_slow := _slow_t <= 0.0
	if do_slow:
		_slow_t = PILLAR_SLOW_EVERY_S
	for i in range(_pillars.size() - 1, -1, -1):
		var p := _pillars[i]
		p["left"] = float(p["left"]) - delta
		if float(p["left"]) <= 0.0:
			_pillars.remove_at(i)
			continue
		if not do_slow:
			continue
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"apply_status") or e.get(&"active") == false:
				continue
			var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
			if e.global_position.distance_to(p["pos"]) <= float(p["r"]) + er:
				e.apply_status(&"slow", {"pct": PILLAR_SLOW_PCT, "duration": PILLAR_SLOW_S})


func _on_player_died() -> void:
	if phoenix != null and is_instance_valid(phoenix) and not phoenix.exploded:
		phoenix.explode() # « à la mort d'Ardent » : il se consume


func _on_floor_started(_stage: int) -> void:
	_events.clear()
	_pillars.clear()
	if phoenix != null and is_instance_valid(phoenix):
		phoenix.dismiss()
