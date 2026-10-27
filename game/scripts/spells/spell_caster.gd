class_name SpellCaster
extends Node
## Gère les 4 slots de sorts d'un personnage (data-driven via CharacterData/SpellData),
## les cooldowns, le pool de projectiles, l'auto-cast optionnel et la formule de dégâts (Maths §6).

const PROJECTILE_SCENE := preload("res://scenes/spells/projectile.tscn")
const ZoneEffect := preload("res://scripts/spells/zone_effect.gd")
const LIGHTNING_RANGE_U := 5.0
const LOW_HP_THRESHOLD := 0.35

## Option d'accessibilité : les slots 2-4 se lancent seuls quand un ennemi est à portée de déclenchement.
var auto_cast_enabled := false

## Lancement réussi d'un sort (tous slots, kits compris). Écouté par le simulateur d'équilibrage (tests/balance_sim).
signal spell_cast(spell: SpellData)
## Coup de sort porté (chemin commun deal_damage, kits compris ; pas la foudre en chaîne des items) : `amount` = dégât
## infligé, critique compris. Pour des compteurs exacts (déblocage des variantes). Sans abonné, l'émission ne coûte presque rien.
signal spell_hit(spell: SpellData, enemy: Node, amount: float)

## Visée manuelle des sorts 2-4 (souris / stick droit). Le sort 1 reste toujours automatique.
var manual_aim_enabled := true
var aim_override: Variant = null ## Vector2 monde ou null ; force la visée (tests)
const STICK_AIM_MIN := 0.3

var player: Node2D
var character: CharacterData
var rng := RandomNumberGenerator.new()
var _remaining := {} ## slot -> s restantes
var _totals := {} ## slot -> durée totale du dernier cooldown
var _pool: Array = []
var _container: Node2D
## Effets (tir, zone, son, lumière) en attente de la frame d'impact de l'anim d'action du joueur
## (Player.action_impact). Sans kit (Ardent : attack 2, cast 3, cast_ult 4 -> 0,17 / 0,25 / 0,36 s) ou si le kit
## le demande (`kit.defers_effects() -> bool`, ArdentVariantKit) ; les autres kits (Rictus) gèrent leur propre synchro.
var _pending: Array[Callable] = []
var _last_tick_frame := -10
var _repeat_mult := 1.0 ## facteur de dégâts du rejeu en cours (repeat_cast)
## Vrai pendant un lancer venu de l'auto-cast (option « Sorts automatiques ») : la visée manuelle (curseur, stick droit,
## aim_override) est ignorée et le « paquet le plus dense » devient le monstre le plus proche. Point central lu par
## cast(), get_manual_aim_point() et densest_point() : les kits qui les appellent pendant un lancer sont alignés d'office.
var _auto_ctx := false


func setup(new_player: CharacterBody2D, new_character: CharacterData) -> void:
	player = new_player
	character = new_character
	rng.randomize()
	_container = Node2D.new()
	_container.name = "SpellFX"
	_container.top_level = true
	player.add_child(_container)
	if player.has_signal(&"action_impact"):
		player.action_impact.connect(_on_action_impact)
	for s in character.spells:
		_remaining[s.slot] = 0.0
		_totals[s.slot] = _cooldown_of(s)


## Démontage (changement de personnage en mode test) : conteneur d'effets libéré, plus aucun écho de l'anim d'action.
func teardown() -> void:
	_pending.clear()
	if player != null and player.has_signal(&"action_impact") and player.action_impact.is_connected(_on_action_impact):
		player.action_impact.disconnect(_on_action_impact)
	if is_instance_valid(_container):
		_container.queue_free()
	_pool.clear()


func _spell_for(slot: int) -> SpellData:
	for s in character.spells:
		if s.slot == slot:
			return s
	return null


func _cooldown_of(s: SpellData) -> float:
	if s.is_auto:
		return Balance.attack_interval(s.base_cooldown, player.stat(&"attack_speed"))
	var m: float = player.stat(&"cooldown_mult")
	return Balance.effective_cooldown(s.base_cooldown, m if m > 0.0 else 1.0)


func get_spell_cooldowns() -> Array:
	var out: Array = []
	for s in character.spells:
		out.append({"slot": s.slot, "id": s.id, "name": s.display_name, "auto": s.is_auto,
			"remaining": maxf(_remaining[s.slot], 0.0), "total": _totals[s.slot], "blocked": is_slot_blocked(s.slot),
			"charges": slot_charges(s.slot), "affordable": slot_affordable(s.slot), "cost": slot_cost_info(s.slot)})
	return out


## Ressource suffisante pour le slot (kit : `slot_affordable(slot) -> bool`, Averse : eau) ; vrai sans hook.
## Lu par le HUD : bouton grisé « ressource insuffisante » au lieu d'un camembert de recharge.
func slot_affordable(slot: int) -> bool:
	var k := _kit()
	return k == null or not k.has_method(&"slot_affordable") or bool(k.slot_affordable(slot))


## Coût affiché d'un slot (kit : `slot_cost_info(slot) -> {cost: "20 d'eau", lack: "pas assez d'eau"}`) ; {} sans.
func slot_cost_info(slot: int) -> Dictionary:
	var k := _kit()
	if k != null and k.has_method(&"slot_cost_info"):
		var d: Variant = k.slot_cost_info(slot)
		return d if d is Dictionary else {}
	return {}


## Kit du personnage (CharacterData.kit_script), ou null (Ardent).
func _kit() -> Node:
	return player.get(&"kit") if player != null and &"kit" in player else null


## Charges d'un slot (kit : `slot_charges(slot) -> Vector2i(disponibles, max)`, Tocsin) ; (-1, 0) = aucune.
func slot_charges(slot: int) -> Vector2i:
	var k := _kit()
	if k != null and k.has_method(&"slot_charges"):
		return k.slot_charges(slot)
	return Vector2i(-1, 0)


## Le kit peut suspendre un slot (Rictus : sort 1 pendant la Toupie, tout pendant la levée).
func is_slot_blocked(slot: int) -> bool:
	var k := _kit()
	return k != null and k.has_method(&"blocks_slot") and bool(k.blocks_slot(slot))


## Rend `seconds` de recharge au slot (couteaux plantés de Rictus, S6). Retourne le temps rendu.
func reduce_cooldown(slot: int, seconds: float) -> float:
	if not _remaining.has(slot) or seconds <= 0.0:
		return 0.0
	var before: float = _remaining[slot]
	_remaining[slot] = maxf(before - seconds, 0.0)
	return before - float(_remaining[slot])


## Silence (cloche du Reclus) : chaque sort à recharge (non automatique) repart pour au moins
## `seconds` s ; une recharge en cours n'est jamais raccourcie, la durée totale affichée suit.
## Retourne le nombre de slots touchés.
func silence(seconds: float) -> int:
	if character == null or seconds <= 0.0:
		return 0
	var n := 0
	for s in character.spells:
		if s.is_auto or not _remaining.has(s.slot):
			continue
		_remaining[s.slot] = maxf(float(_remaining[s.slot]), seconds)
		_totals[s.slot] = maxf(float(_totals.get(s.slot, 0.0)), float(_remaining[s.slot]))
		n += 1
	return n


## Relance le sort du slot sans toucher à sa recharge (Couronne d'écho) ; passe par cast(), donc aussi pour les sorts de kit.
## `damage_mult` : facteur sur tous les dégâts du rejeu (projectiles, zones, kits : le SpellData lancé est une copie au coef réduit).
func repeat_cast(slot: int, damage_mult := 1.0) -> bool:
	if not _remaining.has(slot):
		return false
	_repeat_mult = damage_mult
	var rem: float = _remaining[slot]
	var tot: float = _totals[slot]
	_remaining[slot] = 0.0
	var ok := cast(slot)
	_repeat_mult = 1.0
	_remaining[slot] = rem
	_totals[slot] = tot
	return ok


## Vrai si le slot existe (sort du personnage, recharge suivie).
func has_slot(slot: int) -> bool:
	return _remaining.has(slot)


## Recharge restante d'un slot (0 si inconnu).
func cooldown_remaining(slot: int) -> float:
	return maxf(float(_remaining.get(slot, 0.0)), 0.0)


## Restaure la recharge d'un slot (reprise de sauvegarde). Retourne faux si le slot est inconnu.
func set_cooldown(slot: int, remaining: float, total: float) -> bool:
	if not _remaining.has(slot):
		return false
	_remaining[slot] = maxf(remaining, 0.0)
	_totals[slot] = maxf(total, 0.001)
	return true


func tick(delta: float) -> void:
	# Appui qui a servi à l'UI : ticks sautés (jeu en pause : coffre, choix d'item, menu) -> l'appui qui a
	# fermé l'UI et relancé le jeu ne lance pas de sort ; clic souris sur un contrôle d'UI non plus.
	var frame := Engine.get_physics_frames()
	var ui_press := frame - _last_tick_frame > 1 or _mouse_on_ui()
	_last_tick_frame = frame
	if player == null or player.dead:
		_pending.clear() # mort avant l'impact : l'effet est perdu
		return
	for s in character.spells:
		_remaining[s.slot] = maxf(_remaining[s.slot] - delta, 0.0)
		if _remaining[s.slot] > 0.0 or is_slot_blocked(s.slot):
			continue
		if s.is_auto:
			cast(s.slot)
		elif Input.is_action_just_pressed("spell_%d" % s.slot):
			if not ui_press:
				cast(s.slot)
		elif auto_cast_enabled and _auto_cast_ok(s.slot) and _nearest_enemy(_trigger_px(s)) != null:
			cast(s.slot, true)
	if TestMode.full_resource:
		refill_kit_resource()


## Mode test « ressource pleine » : jauge du kit au maximum (point d'entrée `refill_resource` des kits qui en ont une).
## Avare n'a pas de jauge : sa puissance suit l'or, remonté au plancher du mode test.
func refill_kit_resource() -> void:
	var k := _kit()
	if k == null:
		return
	if k.has_method(&"refill_resource"):
		k.refill_resource()
	elif k is AvareKit:
		RunState.gold = maxf(RunState.gold, TestMode.GOLD_FLOOR)


## Clavier-souris : le pointeur est sur un contrôle d'UI qui capte la souris (bouton, carte, bulle de sort).
## Tactile exclu : les boutons de sorts y simulent l'action alors que le doigt est sur un contrôle.
func _mouse_on_ui() -> bool:
	if not is_inside_tree() or Platform.input_mode == Platform.InputMode.TOUCH:
		return false
	var c := get_viewport().gui_get_hovered_control()
	return c != null and c.mouse_filter == Control.MOUSE_FILTER_STOP


## Auto-cast (option d'accessibilité) : le kit peut retenir un sort pour jouer ses combos
## (Tocsin garde un bras pour les bottes, Averse garde son eau pour la Crue). Jamais consulté en manuel.
func _auto_cast_ok(slot: int) -> bool:
	var k := _kit()
	return k == null or not k.has_method(&"auto_cast_ok") or bool(k.auto_cast_ok(slot))


## Portée de déclenchement de l'auto-cast (px) ; sans limite en mode test « portée infinie ».
func _trigger_px(s: SpellData) -> float:
	var r: float = s.trigger_range_u * Balance.UNIT_PX
	return maxf(r, TestMode.INF_RANGE_PX) if TestMode.inf_range else r


## Lance le sort du slot s'il est prêt. Retourne true si lancé.
## `from_auto` : lancer de l'auto-cast -> visée sur le monstre le plus proche, jamais le curseur ni le stick droit.
func cast(slot: int, from_auto := false) -> bool:
	var prev := _auto_ctx
	_auto_ctx = from_auto or prev # le rejeu d'un lancer auto (Couronne d'écho) reste auto
	var ok := _cast(slot)
	_auto_ctx = prev
	return ok


func _cast(slot: int) -> bool:
	var s := _spell_for(slot)
	if s == null or _remaining[slot] > 0.0 or is_slot_blocked(slot):
		return false
	if _repeat_mult != 1.0:
		s = s.duplicate() as SpellData
		s.coef *= _repeat_mult
	var target := _nearest_enemy(_range_px(s))
	var manual: Variant = null if s.is_auto else get_manual_aim_point(_range_px(s))
	if manual == null and not s.is_auto and s.target_mode == &"densest":
		manual = densest_point(_range_px(s)) # S5 : paquet le plus dense (null = aucun ennemi)
	var ok := false
	var fx_pos := player.global_position
	var aim_dir := Vector2.ZERO ## sens de l'anim d'action du joueur (nul : orientation actuelle)
	## Sans kit (Ardent) ou kit qui le demande (variantes d'Ardent), tir / zone partent à la frame d'impact de l'anim.
	var defer := defers_effects()
	var effect := Callable()
	match s.behavior:
		SpellData.Behavior.PROJECTILE:
			if manual != null:
				var mdir: Vector2 = (manual as Vector2) - player.global_position
				if mdir.length_squared() < 1.0:
					mdir = player.facing
				effect = _fire_projectile_dir.bind(s, mdir.normalized(), {})
				aim_dir = mdir
			elif target == null:
				return false # le sort auto ne consomme rien sans cible
			else:
				aim_dir = target.global_position - player.global_position
				effect = _fire_at.bind(s, target, aim_dir.normalized())
			ok = true
		SpellData.Behavior.NOVA:
			effect = func() -> void: _spawn_zone(s, player.global_position) # centrée sur le joueur à l'impact
			ok = true
		SpellData.Behavior.GROUND_ZONE:
			if manual != null:
				# visée manuelle : la zone tombe au point visé, limitée à la portée du sort
				var off: Vector2 = ((manual as Vector2) - player.global_position).limit_length(_range_px(s))
				fx_pos = player.global_position + off
			else:
				fx_pos = target.global_position if target != null else player.global_position
			aim_dir = fx_pos - player.global_position
			effect = _spawn_zone.bind(s, fx_pos)
			ok = true
		SpellData.Behavior.ARC:
			# demi-cercle vers l'ennemi le plus proche à portée, jamais vers le curseur ; rien sans cible.
			# La portée suit le rayon de la zone (Rune de portée : zone_size_add), pas range_add.
			target = _nearest_enemy(s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add")))
			if target == null:
				return false
			var adir := target.global_position - player.global_position
			if adir.length_squared() < 1.0:
				adir = player.facing
			spawn_zone(s, player.global_position, adir.normalized())
			aim_dir = adir
			fx_pos = target.global_position
			ok = true
		SpellData.Behavior.FAN:
			var fdir: Vector2 = player.facing
			if manual != null:
				fdir = (manual as Vector2) - player.global_position
			elif target != null:
				fdir = target.global_position - player.global_position
			if fdir.length_squared() < 1.0:
				fdir = player.facing if player.facing != Vector2.ZERO else Vector2.DOWN
			fdir = fdir.normalized()
			var n := maxi(s.count, 1)
			var group := {"spell": s, "refunded": 0.0} # une salve : plafond de recharge rendue (couteaux plantés)
			for i in n:
				var a := 0.0 if n == 1 else deg_to_rad(s.spread_deg) * (float(i) / float(n - 1) - 0.5)
				_fire_projectile_dir(s, fdir.rotated(a), group)
			fx_pos = player.global_position + fdir * Balance.UNIT_PX
			aim_dir = fdir
			ok = true
		SpellData.Behavior.SPIN, SpellData.Behavior.DECOYS, SpellData.Behavior.KIT:
			var k := _kit()
			if k == null or not k.has_method(&"cast_spell"):
				return false
			ok = bool(k.cast_spell(s, manual))
			if manual != null:
				aim_dir = (manual as Vector2) - player.global_position
	if not ok:
		return false
	_totals[slot] = _cooldown_of(s)
	_remaining[slot] = 0.0 if TestMode.cdr_full else _totals[slot] # mode test : recharge nulle
	spell_cast.emit(s)
	if not effect.is_valid():
		player.on_cast(s, aim_dir)
		_cast_fx(s, fx_pos)
		return true
	var nova := s.behavior == SpellData.Behavior.NOVA
	var fire := func() -> void:
		effect.call()
		_cast_fx(s, player.global_position if nova else fx_pos)
	if not defer:
		fire.call()
		player.on_cast(s, aim_dir)
		return true
	# on_cast vide d'abord l'impact précédent (ses effets partent), puis donne le délai du nouveau.
	var delay: Variant = player.on_cast(s, aim_dir)
	if delay is float and float(delay) > 0.0:
		_pending.append(fire)
	else:
		fire.call()
	return true


## Vrai si tir / zone des comportements génériques attendent la frame d'impact : sans kit, ou `kit.defers_effects()`.
func defers_effects() -> bool:
	var k := _kit()
	return k == null or (k.has_method(&"defers_effects") and bool(k.defers_effects()))


## Frame d'impact de l'anim d'action : les effets différés partent.
func _on_action_impact(_base: StringName) -> void:
	flush_pending()


## Déclenche tout de suite les effets en attente de la frame d'impact (impact, tests).
func flush_pending() -> void:
	if _pending.is_empty():
		return
	var fx := _pending.duplicate()
	_pending.clear()
	for f: Callable in fx:
		f.call()


func has_pending() -> bool:
	return not _pending.is_empty()


## Tir auto à l'impact : vers la cible si elle vit encore (depuis la position actuelle), sinon le sens visé au lancement.
## `target` non typé : bindé au lancement, il peut être libéré avant l'impact, et un argument typé
## Node2D libéré fait échouer l'appel du Callable avant même la garde is_instance_valid.
func _fire_at(s: SpellData, target: Variant, dir0: Vector2) -> bool:
	var dir := dir0
	if is_instance_valid(target) and (target as Node2D).is_inside_tree():
		var d: Vector2 = (target as Node2D).global_position - player.global_position
		if d.length_squared() > 1.0:
			dir = d.normalized()
	return _fire_projectile_dir(s, dir)


## Puissance d'un lancement pour le son : dégât attendu / Dégât_base (coef × bonus d'items).
func cast_power(s: SpellData) -> float:
	var mult: float = player.stat(&"damage_mult")
	if mult <= 0.0:
		mult = 1.0
	var add: float = player.stat(&"damage_add") + (player.stat(&"auto_damage_add") if s.is_auto else player.stat(&"cd_damage_add"))
	return s.coef * (1.0 + add) * mult


## Son de lancement (ultime : son + ducking + étalonnage teinté de l'accent du personnage) et éclat de lumière.
func _cast_fx(s: SpellData, pos: Vector2) -> void:
	var power := cast_power(s)
	var preset: StringName = s.light_preset
	if s.slot == ArdentKit.ULTIMATE_SLOT:
		Audio.play_ultimate(s.id, pos, power)
		var am := AmbianceManager.find(player.get_tree())
		if am != null:
			am.set_ultimate_warmth(true, character.ultimate_grade_color())
			player.get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
				if is_instance_valid(am):
					am.set_ultimate_warmth(false))
	else:
		Audio.play_cast(s.id, pos, power)
	if preset != &"" and s.behavior == SpellData.Behavior.NOVA:
		LightRig.flash(pos, preset, 0.9 if s.slot == ArdentKit.ULTIMATE_SLOT else 0.45)


func _range_px(s: SpellData) -> float:
	var r: float = s.range_u * Balance.UNIT_PX * (1.0 + player.stat(&"range_add"))
	return maxf(r, TestMode.INF_RANGE_PX) if TestMode.inf_range else r # mode test : portée infinie


# --- API publique pour les kits (ne pas lire les champs privés du SpellCaster) ---

## Portée effective du sort en px (portée × (1 + range_add)).
func range_px(s: SpellData) -> float:
	return _range_px(s)


## Monstre vivant le plus proche du joueur à moins de `max_dist` px, ou null.
func nearest_enemy(max_dist: float) -> Node2D:
	return _nearest_enemy(max_dist)


## Tire le projectile `s` vers `target` (s'il vit encore, sinon dans le sens `dir0`).
func fire_at(s: SpellData, target: Node2D, dir0: Vector2) -> bool:
	return _fire_at(s, target, dir0)


## Tire le projectile `s` dans le sens `dir` (sans cible ni recharge : tirs supplémentaires des items, Rafale d'acier).
func fire_dir(s: SpellData, dir: Vector2) -> bool:
	return _fire_projectile_dir(s, dir.normalized())


## Parent des projectiles et zones du caster (conteneur monde), ou null avant setup.
func effects_parent() -> Node:
	return _container


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d > max_dist:
			continue
		## aim_priority (adds, points faibles de boss raid) : distance effective divisée (défaut 1).
		var pr: Variant = e.get(&"aim_priority")
		var score: float = d / maxf(float(pr), 0.01) if pr != null else d
		if score <= best_d or best == null:
			best_d = score
			best = e
	return best


## Point du monde visé manuellement par les sorts 2-4, ou null (ciblage automatique).
## Souris (kbm) : le curseur. Manette : direction du stick droit (au repos : null -> ennemi le plus proche).
## Tactile : toujours null. `aim_override` (Vector2) force un point (tests, replays).
func get_manual_aim_point(range_px: float) -> Variant:
	if _auto_ctx:
		return null # lancer auto : ciblage automatique (monstre le plus proche), jamais la visée manuelle
	if aim_override != null:
		return aim_override
	if not manual_aim_enabled or player == null:
		return null
	match Platform.input_mode:
		Platform.InputMode.KBM:
			return player.get_global_mouse_position()
		Platform.InputMode.GAMEPAD:
			var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
			if v.length() >= STICK_AIM_MIN:
				return player.global_position + Iso.screen_to_logical_dir(v) * range_px * 0.8
	return null


func _fire_projectile(s: SpellData, target: Node2D) -> bool:
	return _fire_projectile_dir(s, (target.global_position - player.global_position).normalized())


func _fire_projectile_dir(s: SpellData, dir: Vector2, group: Dictionary = {}) -> bool:
	var p := _get_projectile()
	var spd := Balance.projectile_speed_px(player.stat(&"projectile_speed"))
	if s.speed_u > 0.0: # vitesse propre au sort (couteaux 14 u/s), même bonus d'items
		spd = s.speed_u * Balance.UNIT_PX * (1.0 + minf(player.stat(&"projectile_speed"), Balance.PROJECTILE_SPEED_BONUS_CAP))
	var hits := 1 + s.pierce + (int(player.stat(&"pierce")) if s.item_pierce else 0) # plafond : Balance.PIERCE_CAP via ItemStats
	p.launch(player.global_position, dir, s, self, spd, _range_px(s), hits)
	if s.rests_on_ground:
		var k := _kit()
		if k != null and k.has_method(&"on_projectile_rest"):
			p.stop_on_walls = true
			p.rest_on_hit = k.has_method(&"rests_on_hit") and bool(k.rests_on_hit(s)) # retombe aussi au dernier coup
			p.on_rest = func(at: Vector2) -> void:
				if is_instance_valid(k):
					k.on_projectile_rest(s, at, group)
	return true


func _get_projectile() -> Node:
	for p in _pool:
		if not p.active:
			return p
	var np := PROJECTILE_SCENE.instantiate()
	_container.add_child(np)
	_pool.append(np)
	return np


func active_projectile_count() -> int:
	var n := 0
	for p in _pool:
		if p.active:
			n += 1
	return n


func _spawn_zone(s: SpellData, pos: Vector2) -> void:
	spawn_zone(s, pos)


## Zone du sort à `pos` (rayon × zone_size_add). arc_dir non nul : seulement le secteur de
## s.spread_deg autour de cette direction (ARC). Public : explosions et ticks des kits.
func spawn_zone(s: SpellData, pos: Vector2, arc_dir := Vector2.ZERO) -> Node2D:
	var z := Node2D.new()
	z.set_script(ZoneEffect)
	_container.add_child(z)
	var r: float = s.radius_u * Balance.UNIT_PX * (1.0 + player.stat(&"zone_size_add"))
	if arc_dir != Vector2.ZERO:
		z.arc_dir = arc_dir
		z.arc_half = deg_to_rad(s.spread_deg) * 0.5
	z.setup(self, s, pos, r)
	if s.duration > 0.0:
		var preset: StringName = s.light_preset
		if preset != &"":
			LightRig.attach(z, preset, {"radius": r / maxf(float(LightRig.get_preset(preset)["radius_u"]) * Balance.UNIT_PX, 1.0)})
	return z


## S5 : position de l'ennemi qui a le plus de voisins à DENSE_RADIUS_U (paquet le plus dense à portée),
## ou null sans ennemi. O(n²) sur les seuls ennemis à portée, au lancement seulement.
const DENSE_RADIUS_U := 1.5
func densest_point(range_px: float) -> Variant:
	if _auto_ctx: # lancer auto : le monstre le plus proche (pondération aim_priority comprise), pas le paquet
		var near := _nearest_enemy(range_px)
		return near.global_position if near != null else null
	var cands: Array = []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and is_instance_valid(e) and e.global_position.distance_to(player.global_position) <= range_px:
			cands.append(e)
	if cands.is_empty():
		return null
	var r2 := pow(DENSE_RADIUS_U * Balance.UNIT_PX, 2.0)
	var best: Node2D = cands[0]
	var best_n := -1
	for a in cands:
		var n := 0
		for b in cands:
			if a.global_position.distance_squared_to(b.global_position) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best = a
	return best.global_position


## Formule Maths §6 : coef × base(L) × (1+Σadd) × Π(mult) × crit. Applique aussi les procs.
## hit : infos de coup transmises à Enemy.take_damage (source_pos, is_dot, anim ; voir CONTRACTS.md).
func deal_damage(enemy: Node, s: SpellData, hit: Dictionary = {}) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return 0.0
	var is_crit: bool = rng.randf() < player.crit_chance()
	var amount: float = compute_damage(s, enemy, is_crit)
	var at: Vector2 = (enemy as Node2D).global_position
	if s.hit_force >= 0.0 and not hit.has("force"):
		hit = hit.duplicate()
		hit["force"] = s.hit_force
	if enemy is Enemy:
		enemy.take_damage(amount, is_crit, s.element, hit)
	else: # cibles factices des tests : signature à 3 arguments
		enemy.take_damage(amount, is_crit, s.element)
	Audio.play_hit(s.id, amount, is_crit, at, s.element)
	_roll_procs(enemy, amount, s.proc_coef)
	var k := _kit() # coup porté (Averse : une élite ou un boss touché rend de l'eau)
	if k != null and k.has_method(&"on_spell_hit"):
		k.on_spell_hit(s, enemy, amount)
	spell_hit.emit(s, enemy, amount)
	return amount


func compute_damage(s: SpellData, enemy: Node, is_crit: bool) -> float:
	var add: float = player.stat(&"damage_add")
	if s.is_auto:
		add += player.stat(&"auto_damage_add")
	else:
		add += player.stat(&"cd_damage_add")
	if s.is_zone and not s.is_auto: # l'attaque auto ne prend que auto_damage_add (équilibrage 23/10, décision du joueur)
		add += player.stat(&"zone_damage_add")
	if enemy != null and (enemy.get("is_elite") == true or enemy.is_in_group("bosses")):
		add += player.stat(&"elite_boss_damage_add")
	if player.max_hp > 0.0 and player.hp / player.max_hp <= LOW_HP_THRESHOLD:
		add += player.stat(&"low_hp_damage_add")
	if player.is_moving:
		add += player.stat(&"moving_damage_add")
	if enemy != null and enemy.has_method("is_slowed") and enemy.is_slowed():
		add += player.stat(&"slowed_target_damage_add")
	var kit := _kit() # bonus additif propre au personnage (Avare : puissance de l'or)
	if kit != null and kit.has_method(&"damage_add"):
		add += float(kit.damage_add(s, enemy))
	var mult: float = player.stat(&"damage_mult")
	if mult <= 0.0:
		mult = 1.0
	var dmg: float = s.coef * Balance.player_base_damage(RunState.level) * (1.0 + add) * mult
	if is_crit:
		dmg *= player.crit_mult()
	return dmg


## Aperçu pour l'infobulle de sort (SpellHint) : dégâts d'un coup sans critique, sur une cible neutre (ni élite, ni
## boss, ni ralentie). Même formule que compute_damage ; seul le facteur propre au kit (`preview_mult`, ex. aiguisage
## de Taliant, déjà appliqué au coef des coups réels) s'y ajoute.
func preview_damage(s: SpellData) -> float:
	var m := 1.0
	var kit := _kit()
	if kit != null and kit.has_method(&"preview_mult"):
		m = float(kit.preview_mult(s))
	return compute_damage(s, null, false) * m


## Procs d'items (RoR2) : chance × proc coefficient du coup (pc). Les DoT reçoivent leur total de dégâts :
## brûlure = base_fraction × dégât de base × pc + hit_fraction × coup, × (1 + burn_damage_add) (Ignition Tank) ;
## poison = hit_fraction × coup. Durée dans data.duration.
func _roll_procs(enemy: Node, hit: float, pc: float = 1.0) -> void:
	for p in player.procs:
		if rng.randf() >= float(p.get("chance", 0.0)) * pc:
			continue
		var status: StringName = p.get("status", &"")
		var data: Dictionary = (p.get("data", {}) as Dictionary).duplicate()
		match status:
			&"lightning":
				_lightning(enemy, hit, data)
				continue
			&"burn":
				data["total"] = (float(data.get("base_fraction", 0.0)) * Balance.player_base_damage(RunState.level) * pc
					+ float(data.get("hit_fraction", 0.0)) * hit) * (1.0 + player.stat(&"burn_damage_add"))
			&"poison":
				data["total"] = float(data.get("hit_fraction", 0.0)) * hit
		if enemy.has_method("apply_status"):
			enemy.apply_status(status, data)


## Ennemis actifs à moins de range_px de `origin`, du plus proche au plus lointain, au plus `count`.
func nearest_enemies(origin: Vector2, range_px: float, count: int, exclude: Node = null) -> Array:
	var cands: Array = []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e != exclude and e is Node2D and is_instance_valid(e) and e.has_method("take_damage") \
				and e.global_position.distance_to(origin) <= range_px:
			cands.append(e)
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	return cands.slice(0, count)


## Foudre (Ukulele) : N autres cibles proches de la victime, à damage_fraction du coup (pas de proc en chaîne).
func _lightning(origin: Node, hit: float, data: Dictionary) -> void:
	var frac := float(data.get("damage_fraction", 0.8))
	var o := origin as Node2D
	var targets := nearest_enemies(o.global_position, LIGHTNING_RANGE_U * Balance.UNIT_PX, int(data.get("targets", 3)), origin)
	if not targets.is_empty():
		Audio.play(&"lightning.chain.medium", o.global_position)
		LightRig.flash(o.global_position, &"spell_lightning", 0.15)
	for e in targets:
		if e is Enemy: # coup direct venu de la victime d'origine (recul à l'opposé)
			e.take_damage(hit * frac, false, &"lightning", {"source_pos": o.global_position})
		else:
			e.take_damage(hit * frac, false, &"lightning")
