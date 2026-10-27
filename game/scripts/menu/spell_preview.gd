class_name SpellPreview
extends SubViewportContainer
## Aperçu de jeu de la fiche personnage (demande du joueur, 26/10/2026) : une mini-arène dans un SubViewport.
## Sol iso réel du biome 1 (tuiles terrasses), éclairage d'ambiance du profil de la carte, caméra iso 2:1 du jeu
## (64 px/u ; zoom réduit pour que ~11 u tiennent dans le tiers gauche), le VRAI joueur (player.tscn + kit +
## variantes choisies) et 3 à 5 mannequins : de vrais monstres du jeu (Enemy) aux PV inépuisables, immobiles
## (vitesse et dégâts nuls, cible fictive très lointaine : ils ne bougent ni ne frappent). Un sort est lancé par le
## vrai chemin `SpellCaster.cast(slot)` (et le kit) : VFX, chiffres de dégâts, zones, télégraphes, sons.
##
## ISOLATION (un « faux contexte » plutôt que des interrupteurs dans le code du jeu) :
##  - RunState : instantané des champs de run à l'ouverture (premier détenteur), restitué à la fermeture ; pendant
##    l'aperçu : étage 1, niveau 1, aucun objet, run figée (`running = false`), or de poche pour Avare. Compteurs de
##    déblocage, kills, XP touchés par les sorts disparaissent donc avec le restore.
##  - Profile : jamais d'écriture du profil par l'aperçu (les sorts n'en touchent aucune donnée : les compteurs vont dans
##    RunState). Seule exception, la bulle d'Avare (une fois par profil, UI posée sur la scène courante) : elle est
##    neutralisée en marquant le profil « vu » en mémoire le temps du minuteur de la bulle, puis le marqueur est retiré s'il n'existait
##    pas ; `Profile.write_enabled` n'est PAS coupé (la fiche enregistre le choix de variantes pendant l'aperçu).
##  - InputMap : événements de move_*, spell_2..4, dodge et interact retirés le temps de l'aperçu (le clavier / la manette
##    ne déplacent ni ne font lancer rien dans l'arène) puis rétablis dans le même ordre.
##  - Audio : bus Spells / Impacts / Footsteps baissés de SFX_DB dB (restaurés) ; l'écouteur est calé sur la caméra de
##    l'arène (l'arène est loin de la carte du menu : sinon tout serait « trop loin » et muet).
##  - Monde : arène à ARENA_CENTER (très loin de la carte du fond de menu) ; SubViewport à `own_world_3d` (son
##    WorldEnvironment ne touche pas le viewport racine) ; LightRig propre (les lumières se partagent par vue) ; le
##    joueur de l'arène n'est pas dans le groupe `player` (le fond de menu y lit sa position pour la brume).
## Les détenteurs sont comptés (statique) : changer de personnage (nouvelle arène avant la libération de l'ancienne)
## ne restitue rien tant qu'un détenteur reste.
## Le sort 1 (auto) tourne en boucle tant qu'il est sélectionné (AUTO_LOOP_MAX_S), les autres se lancent à chaque appui.
## Hors écran (fiche cachée) la simulation est coupée ; tout est libéré en quittant la fiche.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const BIOME_MAP := &"terrasses_noyees" ## profil d'ambiance et tuiles du biome 1
const ISO_DIR := "res://assets/sprites/terrain/terraces/iso/"
const GROUND_TILES: Array[String] = ["ground_a", "ground_b", "ground_c", "ground_d"]
const GROUND_PICK: Array[int] = [0, 0, 1, 0, 0, 2, 0, 1, 3] ## tirage stable par case (variantes a-d, a plus fréquente)
const U := 64.0
const ARENA_CENTER := Vector2(-300000.0, -300000.0) ## repère logique, très loin de la carte du menu
const VIEW_U := 7.0 ## largeur visée de la vue, en u (joueur 26/10 : caméra rapprochée ×1,6, 11 -> 7)
const MIN_ZOOM_MULT := 0.3
const MAX_ZOOM_MULT := 1.8
const PLAYER_HOME_U := Vector2(-2.6, 0.9) ## position du joueur par rapport au centre de l'arène (u logiques)
const CAMERA_SHIFT_U := Vector2(0.4, 0.6)
const GROUND_RADIUS := 4 ## demi-largeur du carré de tuiles de 4 u
const DUMMY_BIG := 1.0e9
const DUMMY_PATTERN: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.9, -1.5), Vector2(0.9, 1.5), Vector2(1.9, -0.7), Vector2(1.9, 0.8)]
const DUMMY_TIERS: Array[int] = [1, 1, 1, 3, 1] ## 4 essaims et 1 brute
const DUMMY_RETURN_PX_S := 140.0
const DUMMY_SNAP_PX := 40.0
const AUTO_LOOP_MAX_S := 20.0
const HOME_AFTER_S := 1.4 ## le joueur revient à sa place après ce délai sans lancer
const SFX_DB := -7.0
const SFX_BUSES: Array[String] = ["Spells", "Impacts", "Footsteps"]
const LOCKED_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"spell_2", &"spell_3",
	&"spell_4", &"dodge", &"interact"]
const PRIME_GOLD := 400.0
const PRIME_PERIOD_S := 0.2
const FAR_TARGET_PX := 100000.0
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const HOME_ENTER_PX := 14.0 ## hystérésis du retour : repart au-delà, s'arrête en deçà de HOME_LEAVE_PX
const HOME_LEAVE_PX := 7.0
const WALK_REACH_PX := 26.0
const TIP_GUARD_MARGIN_S := 0.4
const SHARP_FLOOR := 60.0 ## aiguisage de Taliant gardé au-dessus (le sort 3 le met plus bas pour pouvoir aiguiser)

## Un lancer a abouti (ok) ou a été refusé par le kit (la fiche rejoue alors l'ancienne animation).
signal cast_finished(slot: int, ok: bool)

## Mesures de l'aperçu (tests, repli) : dégâts infligés aux mannequins, nœuds apparus dans l'arène, lancers.
var damage_total := 0.0
var spawned_total := 0
var casts_ok := 0
var casts_failed := 0
## Tout est monté : le lancer est possible.
var ready_to_cast := false
var character_id: StringName = &""
var player: CharacterBody2D = null
var dummies: Array[Enemy] = []
var selected_slot := 0
var auto_loop := false

var _tree: SceneTree
var _vp: SubViewport
var _world: Node2D
var _cam: Camera2D
var _ground: TileMapLayer
var _sun: DirectionalLight2D
var _fill: DirectionalLight2D
var _modulate: CanvasModulate
var _env: WorldEnvironment
var _rig: LightRig
var _numbers: Node2D
var _far_target: Node2D
var _keep: Array[Node] = [] ## nœuds permanents du monde (le reste vient des lancers)
var _homes: Array[Vector2] = []
var _loadout: Dictionary = {} ## variantes en jeu : {slot: id}
var _base_ids: Dictionary = {} ## slot -> id du sort de base
var _since_cast := 99.0
var _loop_t := 0.0
var _prime_t := 0.0
var _holds := false
var _counting := false
var _walk: Array[Vector2] = []
var _walk_i := -1
var _homing := false

# Contexte statique partagé (détenteurs comptés).
static var _holders := 0
static var _snap_run := {}
static var _tip_marked := false ## marqueur « bulle vue » posé par l'aperçu (à retirer)
static var _snap_inputs := {}
static var _snap_buses := {}


# --- API --------------------------------------------------------------------------------------------------

## Aperçu possible pour ce personnage (ouvert, au moins un sort décrit).
static func supported(c: Dictionary, locked: bool) -> bool:
	return not locked and not (c.get("spells", []) as Array).is_empty() and ResourceLoader.exists(PLAYER_SCENE)


## Monte l'arène pour `c` (entrée de characters.json) avec les variantes `chosen` ({slot: id}).
func start(c: Dictionary, chosen: Dictionary) -> void:
	character_id = StringName(String(c.get("id", "")))
	_base_ids.clear()
	var spells: Array = c.get("spells", [])
	for i in spells.size():
		_base_ids[i + 1] = StringName(String((spells[i] as Dictionary).get("id", "")))
	_acquire_context()
	_holds = true
	_prepare_run()
	_loadout = _variants_of(chosen)
	_build_world()
	_spawn_player()
	_spawn_dummies()
	_update_zoom()
	_apply_ambience()
	_poke_listener()
	_counting = true
	_tree = get_tree()
	_tree.node_added.connect(_on_node_added)
	Events.enemy_damaged.connect(_on_enemy_damaged)
	set_physics_process(is_visible_in_tree() and ready_to_cast)


## Lance le sort `slot` avec les variantes `chosen`. Faux = le kit n'a pas pu le lancer (la fiche rejoue l'ancienne anim).
func play(slot: int, chosen: Dictionary) -> bool:
	if not ready_to_cast or not is_instance_valid(player) or player.dead:
		return false
	var want := _variants_of(chosen)
	if want != _loadout:
		_loadout = want
		_respawn_player()
		if not ready_to_cast:
			return false
	var sd := _spell_data(slot)
	if sd == null:
		return false
	_poke_listener()
	selected_slot = slot
	var spells: SpellCaster = player.spells
	_walk_i = -1
	_place_dummies(sd)
	_since_cast = 0.0
	_prime()
	if slot == 1:
		auto_loop = true
		_loop_t = 0.0
		spells.set_cooldown(1, 0.0, 1.0)
		var ok1 := spells.cast(1)
		if not ok1 and spells.is_slot_blocked(1) and _has_chain():
			ok1 = _start_walk_demo() # Arpenteuse : la chaîne se déroule en marchant, le sort 1 n'est jamais lancé
		elif not ok1:
			ok1 = _nearest_dummy_dist() <= spells.range_px(sd) # la boucle tirera dès que la cible est à portée
		_finish(slot, ok1)
		return ok1
	auto_loop = false
	spells.set_cooldown(slot, 0.0, 1.0)
	_prime_for_cast(slot)
	spells.aim_override = _aim_point_for(sd)
	var ok := spells.cast(slot)
	spells.aim_override = null
	_finish(slot, ok)
	return ok


## Le sort `slot` est-il décrit dans le kit en cours ?
func has_spell(slot: int) -> bool:
	return _spell_data(slot) != null


## Position logique du centre des mannequins vivants.
func dummies_center() -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for d in dummies:
		if is_instance_valid(d):
			s += d.global_position
			n += 1
	return s / float(n) if n > 0 else ARENA_CENTER


## Libère l'arène tout de suite (changement de personnage, fermeture).
func shutdown() -> void:
	ready_to_cast = false
	set_physics_process(false)
	_clear_world()
	_release_context_once()
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()


# --- Cycle de vie ------------------------------------------------------------------------------------------

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_physics_process(false)


func _ready() -> void:
	resized.connect(_update_zoom)


func _exit_tree() -> void:
	_clear_world()
	_release_context_once()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _world != null:
		var on := is_visible_in_tree()
		_world.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		set_physics_process(on and ready_to_cast)


static func _unmark_avare_tip() -> void:
	if _tip_marked:
		_tip_marked = false
		Profile.objectives.erase(String(AvareKit.TIP_KEY))


func _release_context_once() -> void:
	if not _holds:
		return
	_holds = false
	_release_context()


# --- Contexte d'isolation (statique, détenteurs comptés) ---------------------------------------------------------

func _acquire_context() -> void:
	_holders += 1
	if _holders > 1:
		return
	_snap_run = {
		"mode": RunState.mode, "stage": RunState.stage, "active_time_s": RunState.active_time_s, "running": RunState.running,
		"gold": RunState.gold, "xp": RunState.xp, "level": RunState.level, "items": RunState.items.duplicate(),
		"character": RunState.character, "loadout": RunState.loadout.duplicate(), "counters": RunState.counters.duplicate(true),
		"bosses_killed": RunState.bosses_killed.duplicate(true), "kills": RunState.kills, "run_seed": RunState.run_seed,
		"rng_seed": RunState.rng.seed, "rng_state": RunState.rng.state, "floor_start_d": RunState.floor_start_d,
	}
	_snap_inputs.clear()
	for a in LOCKED_ACTIONS:
		if InputMap.has_action(a):
			_snap_inputs[a] = InputMap.action_get_events(a).duplicate()
			InputMap.action_erase_events(a)
	_snap_buses.clear()
	for b in SFX_BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx != -1:
			_snap_buses[b] = AudioServer.get_bus_volume_db(idx)
			AudioServer.set_bus_volume_db(idx, float(_snap_buses[b]) + SFX_DB)


func _release_context() -> void:
	_holders = maxi(_holders - 1, 0)
	if _holders > 0:
		return
	var s := _snap_run
	if not s.is_empty():
		RunState.mode = s["mode"]
		RunState.stage = s["stage"]
		RunState.active_time_s = s["active_time_s"]
		RunState.running = s["running"]
		RunState.gold = s["gold"]
		RunState.xp = s["xp"]
		RunState.level = s["level"]
		RunState.items = (s["items"] as Dictionary).duplicate()
		RunState.character = s["character"]
		RunState.loadout = (s["loadout"] as Dictionary).duplicate()
		RunState.counters = (s["counters"] as Dictionary).duplicate(true)
		RunState.bosses_killed = (s["bosses_killed"] as Array).duplicate(true)
		RunState.kills = s["kills"]
		RunState.run_seed = s["run_seed"]
		RunState.rng.seed = s["rng_seed"]
		RunState.rng.state = s["rng_state"]
		RunState.floor_start_d = s["floor_start_d"]
	_snap_run = {}
	_unmark_avare_tip()
	for a in _snap_inputs:
		InputMap.action_erase_events(a)
		for ev in _snap_inputs[a]:
			InputMap.action_add_event(a, ev)
	_snap_inputs.clear()
	for b in _snap_buses:
		var idx := AudioServer.get_bus_index(b)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, _snap_buses[b])
	_snap_buses.clear()


## État de run de l'aperçu : étage 1, niveau 1, sans objet, figée (les chiffres du joueur = ceux de la fiche).
func _prepare_run() -> void:
	RunState.stage = 1
	RunState.level = 1
	RunState.xp = 0.0
	RunState.items.clear()
	RunState.counters = {}
	RunState.bosses_killed = []
	RunState.character = character_id
	RunState.running = false
	RunState.gold = PRIME_GOLD
	# bulle d'Avare (une fois par profil) : marquée vue en mémoire le temps que son minuteur (TIP_DELAY_S) expire
	if not _tip_marked and Profile.objective_progress(AvareKit.TIP_KEY) <= 0.0:
		Profile.objectives[String(AvareKit.TIP_KEY)] = 1.0
		_tip_marked = true
		get_tree().create_timer(AvareKit.TIP_DELAY_S + TIP_GUARD_MARGIN_S, false).timeout.connect(_unmark_avare_tip)


# --- Monde ---------------------------------------------------------------------------------------------------

func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.name = "Arena"
	_vp.own_world_3d = true
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.use_hdr_2d = get_tree().root.use_hdr_2d
	_vp.gui_disable_input = true
	_vp.handle_input_locally = false
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	_vp.add_child(_world)
	_cam = Camera2D.new()
	_cam.name = "ArenaCamera"
	_cam.position = ARENA_CENTER + CAMERA_SHIFT_U * U
	_world.add_child(_cam)
	_cam.make_current()
	_build_ground()
	_build_lights()
	_rig = LightRig.new()
	_rig.name = "LightRig"
	_world.add_child(_rig)
	var dn := DamageNumbers.new()
	dn.name = "DamageNumbers"
	_world.add_child(dn)
	_numbers = dn
	_far_target = Node2D.new()
	_far_target.name = "FarTarget"
	_world.add_child(_far_target)
	_keep = [_cam, _ground, _sun, _fill, _modulate, _env, _rig, _numbers, _far_target]


func _on_node_added(n: Node) -> void:
	if not _counting or _world == null or not is_instance_valid(_world) or not (n is Node2D):
		return
	if n != _world and _world.is_ancestor_of(n) and not (n is Camera2D) and not _is_dummy_part(n):
		spawned_total += 1


func _is_dummy_part(n: Node) -> bool:
	for d in dummies:
		if is_instance_valid(d) and (d == n or d.is_ancestor_of(n)):
			return true
	return false


func _on_enemy_damaged(e: Node2D, amount: float, _crit: bool, _el: StringName) -> void:
	if dummies.has(e):
		damage_total += amount


func _build_ground() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.z_index = -20
	_ground.light_mask = LightRig.MASK_GROUND
	if ResourceLoader.exists(ISO_DIR + GROUND_TILES[0] + ".png"):
		_ground.tile_set = StageMap._iso_tileset(ISO_DIR, GROUND_TILES, Vector2i(512, 256), 0)
		var n := GROUND_PICK.size()
		for y in range(-GROUND_RADIUS, GROUND_RADIUS + 1):
			for x in range(-GROUND_RADIUS, GROUND_RADIUS + 1):
				var h := absi(hash([x * 73856093, y * 19349663, 7])) % n
				_ground.set_cell(Vector2i(x, y), GROUND_PICK[h], Vector2i.ZERO)
		# couche en espace billboard (comme StageMap._place_billboard_layer) : case (0,0) au centre de l'arène
		var local := Transform2D(0.0, StageMap.ISO_SCALE, 0.0, Vector2.ZERO)
		local.origin = ARENA_CENTER - local.basis_xform(_ground.map_to_local(Vector2i.ZERO))
		_ground.transform = local
	_world.add_child(_ground)


func _build_lights() -> void:
	_modulate = CanvasModulate.new()
	_modulate.name = "Ambient"
	_world.add_child(_modulate)
	_sun = DirectionalLight2D.new()
	_sun.name = "Sun"
	_sun.blend_mode = Light2D.BLEND_MODE_ADD
	_sun.range_z_min = LightRig.RANGE_Z_MIN
	_sun.range_z_max = LightRig.RANGE_Z_MAX
	_sun.range_item_cull_mask = LightRig.MASK_LIT | LightRig.MASK_PUDDLES
	_sun.shadow_enabled = false
	_world.add_child(_sun)
	_fill = DirectionalLight2D.new()
	_fill.name = "EntityFill"
	_fill.blend_mode = Light2D.BLEND_MODE_ADD
	_fill.height = 1.0
	_fill.range_z_min = LightRig.RANGE_Z_MIN
	_fill.range_z_max = LightRig.RANGE_Z_MAX
	_fill.range_item_cull_mask = LightRig.MASK_WORLD
	_fill.shadow_enabled = false
	_world.add_child(_fill)
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	if bool(Quality.get_setting(&"glow")):
		env.glow_enabled = true
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		var levels: Array = Quality.get_setting(&"glow_levels")
		for i in 7:
			env.set_glow_level(i, levels.has(i + 1))
		env.glow_intensity = float(Quality.get_setting(&"glow_intensity"))
		env.glow_bloom = float(Quality.get_setting(&"glow_bloom"))
		env.glow_normalized = Quality.tier == Quality.Tier.MEDIUM
	_env.environment = env
	_world.add_child(_env)


## Ambiance du profil de la carte du biome 1 à D = 1 (mêmes garde-fous que AmbianceManager._push, soleil + fill).
func _apply_ambience() -> void:
	var prof := AmbianceManager.load_profile(BIOME_MAP)
	if prof == null or _modulate == null:
		return
	var p: Dictionary = prof.evaluate(1.0)
	var sun_on := bool(Quality.get_setting(&"sun"))
	var fill_on := bool(Quality.get_setting(&"entity_fill"))
	var sun_c: Color = p[&"sun_color"]
	var sun_e := float(p[&"sun_energy"])
	var amb: Color = p[&"ambient_color"] if sun_on else p[&"ambient_low"]
	amb = AmbianceProfile.guard_ambient(amb, sun_c, sun_e, sun_on, -1.0 if fill_on else AmbianceProfile.MIN_EFFECTIVE_LUMINANCE)
	var fill_c: Color = p[&"fill_color"]
	var fill_e := float(p[&"fill_energy"] if sun_on else p[&"fill_energy_low"])
	fill_e = AmbianceProfile.guard_fill(amb, sun_c, sun_e, sun_on, fill_c, fill_e) if fill_on else 0.0
	var ldr := not _vp.use_hdr_2d
	var sun_out := Color(sun_c, 1.0)
	var sun_out_e := sun_e
	if ldr:
		var ref := AmbianceManager.LDR_SUN_REF
		var amb_l := amb.srgb_to_linear()
		var lit_l := amb_l
		var lit_s := amb
		if sun_on:
			var s: Array = AmbianceManager.ldr_light(amb_l, amb, sun_c, sun_e, ref)
			sun_out = s[0]
			sun_out_e = s[1]
			lit_l = AmbianceManager._add_light_l(amb_l, sun_c, sun_e * ref)
			lit_s = Color(amb.r + sun_out.r * sun_out_e * ref, amb.g + sun_out.g * sun_out_e * ref, amb.b + sun_out.b * sun_out_e * ref)
		if fill_on and fill_e > 0.0:
			var f: Array = AmbianceManager.ldr_light(lit_l, lit_s, fill_c, fill_e, 1.0)
			fill_c = f[0]
			fill_e = f[1]
	_modulate.color = amb
	_fill.visible = fill_on
	_fill.color = fill_c
	_fill.energy = fill_e
	_sun.visible = sun_on
	_sun.color = sun_out
	_sun.energy = sun_out_e
	_sun.rotation_degrees = float(p[&"sun_rotation_deg"])
	_sun.height = float(p[&"sun_height"])


func _update_zoom() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var w := size.x if size.x > 8.0 else 480.0
	_cam.zoom = Iso.camera_zoom(clampf(w / (VIEW_U * Iso.SCREEN_PX_PER_U), MIN_ZOOM_MULT, MAX_ZOOM_MULT))


func _clear_world() -> void:
	_counting = false
	_walk_i = -1
	_release_moves()
	if _tree != null and _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)
	_tree = null
	if Events.enemy_damaged.is_connected(_on_enemy_damaged):
		Events.enemy_damaged.disconnect(_on_enemy_damaged)
	for d in dummies:
		if is_instance_valid(d):
			d.remove_from_group(&"enemies")
	dummies.clear()
	player = null
	if _vp != null and is_instance_valid(_vp):
		remove_child(_vp)
		_vp.queue_free()
	_vp = null
	_world = null


# --- Joueur ---------------------------------------------------------------------------------------------------

func _home() -> Vector2:
	return ARENA_CENTER + PLAYER_HOME_U * U


func _variants_of(chosen: Dictionary) -> Dictionary:
	var out := {}
	for k in chosen:
		var slot := int(str(k))
		var id := StringName(str(chosen[k]))
		if id != &"" and id != _base_ids.get(slot, &""):
			out[slot] = id
	return out


func _spawn_player() -> void:
	var cd := CharacterData.for_id(character_id, _loadout)
	if cd == null:
		ready_to_cast = false
		return
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as CharacterBody2D
	player.character = cd
	player.auto_cast_spells = false
	player.position = _home()
	_world.add_child(player)
	player.remove_from_group(&"player")
	var cam := player.get_node_or_null(^"Camera2D") as Camera2D
	if cam != null:
		cam.enabled = false
	_cam.make_current()
	player.global_position = _home()
	player.facing = Vector2(1.0, 0.0)
	if player.spells != null:
		player.spells.manual_aim_enabled = false
		player.spells.auto_cast_enabled = false
	player.hp = player.max_hp
	ready_to_cast = player.spells != null


## Nouveau joueur (variantes changées) : l'ancien et ce qu'il a posé dans le monde sont libérés.
func _respawn_player() -> void:
	ready_to_cast = false
	if is_instance_valid(player):
		_world.remove_child(player)
		player.queue_free()
	player = null
	for n in _world.get_children():
		if not _keep.has(n) and not (n is Enemy and dummies.has(n as Enemy)):
			_world.remove_child(n)
			n.queue_free()
	_spawn_player()
	_since_cast = 99.0


func _spell_data(slot: int) -> SpellData:
	if not is_instance_valid(player) or player.character == null:
		return null
	for s in player.character.spells:
		if s != null and s.slot == slot:
			return s
	return null


# --- Mannequins -------------------------------------------------------------------------------------------------

func _spawn_dummies() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	for i in DUMMY_PATTERN.size():
		var e := packed.instantiate() as Enemy
		_world.add_child(e)
		var pos := _home() + (Vector2(3.0, 0.0) + DUMMY_PATTERN[i]) * U
		e.activate(DUMMY_TIERS[i], pos, 1.0, false, [] as Array[StringName])
		e.max_hp = DUMMY_BIG
		e.hp = DUMMY_BIG
		e.damage = 0.0
		e.speed_px = 0.0
		dummies.append(e)
		_homes.append(pos)


## Place le groupe devant le joueur, à la portée utile du sort (le plus proche = le premier du motif).
func _place_dummies(sd: SpellData) -> void:
	var r := _reach(sd)
	var base := _home() + Vector2(r.x, 0.0) * U
	for i in dummies.size():
		var d := dummies[i]
		if not is_instance_valid(d):
			continue
		var want := base + DUMMY_PATTERN[i] * r.y * U
		_homes[i] = want
		if d.position.distance_to(want) > DUMMY_SNAP_PX:
			d.position = want
			d._kb = Vector2.ZERO


## (distance du premier mannequin en u, échelle du motif) selon le sort.
func _reach(sd: SpellData) -> Vector2:
	match sd.behavior:
		SpellData.Behavior.PROJECTILE, SpellData.Behavior.FAN:
			return Vector2(clampf(sd.range_u * 0.5, 2.2, 4.4), 1.0)
		SpellData.Behavior.ARC:
			return Vector2(clampf(sd.radius_u * 0.55, 1.3, 2.6), clampf(sd.radius_u / 3.0, 0.5, 1.0))
		SpellData.Behavior.NOVA:
			var d := clampf(sd.radius_u * 0.5, 1.2, 3.4)
			return Vector2(d, clampf((sd.radius_u * 0.9 - d) / 2.2, 0.35, 1.0))
		SpellData.Behavior.GROUND_ZONE:
			return Vector2(clampf(sd.range_u * 0.5, 2.0, 4.2), clampf(sd.radius_u / 2.4, 0.45, 1.0))
		SpellData.Behavior.SPIN:
			return Vector2(clampf(sd.radius_u * 0.7, 1.4, 2.6), clampf(sd.radius_u / 3.0, 0.5, 1.0))
	var reach := minf(sd.trigger_range_u if sd.trigger_range_u > 0.0 else 6.0, maxf(sd.range_u, sd.radius_u)) * 0.6
	return Vector2(clampf(reach, 1.6, 4.2), 0.8)


## Point visé (null = ciblage automatique du caster) : centre des mannequins pour une zone / un sort de kit,
## mannequin le plus proche pour un tir.
func _aim_point_for(sd: SpellData) -> Variant:
	match sd.behavior:
		SpellData.Behavior.GROUND_ZONE, SpellData.Behavior.KIT, SpellData.Behavior.DECOYS:
			return dummies_center()
		SpellData.Behavior.PROJECTILE, SpellData.Behavior.FAN:
			return _nearest_dummy_pos()
	return null


func _nearest_dummy_pos() -> Vector2:
	var best := dummies_center()
	var bd := INF
	for d in dummies:
		if is_instance_valid(d):
			var dd := d.global_position.distance_to(player.global_position)
			if dd < bd:
				bd = dd
				best = d.global_position
	return best


func _nearest_dummy_dist() -> float:
	return _nearest_dummy_pos().distance_to(player.global_position)


# --- Boucle -----------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not ready_to_cast or not is_instance_valid(player):
		return
	_poke_listener()
	_since_cast += delta
	var spells: SpellCaster = player.spells
	# sort 1 : seulement en boucle ; sinon retenu (sa recharge est sans cesse remise à zéro)
	if auto_loop and selected_slot == 1:
		_loop_t += delta
		_since_cast = 0.0
		if _loop_t > AUTO_LOOP_MAX_S:
			auto_loop = false
	if not auto_loop:
		spells.set_cooldown(1, 5.0, 5.0)
	_prime_t += delta
	if _prime_t >= PRIME_PERIOD_S:
		_prime_t = 0.0
		_prime()
	_tick_dummies(delta)
	_steer_step()


func _tick_dummies(delta: float) -> void:
	for i in dummies.size():
		var d := dummies[i]
		if not is_instance_valid(d):
			continue
		var away := player.global_position - d.global_position
		_far_target.global_position = d.global_position + away.normalized() * FAR_TARGET_PX
		d.tick(delta, _far_target, _far_target.global_position, Vector2.ZERO, Vector2.ZERO, false)
		d.hp = DUMMY_BIG
		d.active = true
		if d._kb == Vector2.ZERO:
			d.position = d.position.move_toward(_homes[i], DUMMY_RETURN_PX_S * delta)


## Ressources des kits maintenues tant que l'aperçu est actif : eau d'Averse, tension de Vigie, or d'Avare, aiguisage de
## Taliant (au-dessus de SHARP_FLOOR). Les besoins propres à un sort sont posés au lancer (_prime_for_cast).
func _prime() -> void:
	if not is_instance_valid(player):
		return
	RunState.gold = maxf(RunState.gold, PRIME_GOLD)
	var k: Variant = player.kit
	if k == null:
		return
	if &"sharpness" in k:
		k.sharpness = maxf(k.sharpness, SHARP_FLOOR) # plancher voulu : la démo du sort 3 veut une lame entamée
	elif k.has_method(&"refill_resource") and not k is TocsinKit and not k is BourbeKit:
		k.refill_resource() # eau d'Averse, tension de Vigie


## État nécessaire au sort `slot` juste avant son lancer : aiguisage plein (Taliant ; le sort 3 aiguise, il faut donc
## une lame entamée), chaîne posée à travers les mannequins (Arpenteuse : Halage et Tendeur la lisent).
func _prime_for_cast(slot: int) -> void:
	var k: Variant = player.kit
	if k == null:
		return
	if &"sharpness" in k:
		k.sharpness = 45.0 if slot == 3 else MorfilKit.SHARP_MAX
	if _has_chain() and slot != 3 and slot != 1:
		var head: Vector2 = player.global_position
		var along := (dummies_center() - head).normalized()
		var tail := head + along * maxf(head.distance_to(dummies_center()) + 2.0 * U, 6.0 * U) # au-delà du groupe, >= 6 u
		var pts := PackedVector2Array()
		var n := maxi(int(head.distance_to(tail) / 32.0), 2)
		for i in n + 1:
			pts.append(tail.lerp(head, float(i) / float(n)))
		k.chain = pts
		k._last_head = head
		k._idle_t = 0.0


func _has_chain() -> bool:
	var k: Variant = player.kit if is_instance_valid(player) else null
	return k != null and &"chain" in k and k.has_method(&"chain_length")


## Marche de démonstration (chaîne d'Arpenteuse) : le joueur traverse le groupe, la chaîne brûle ce qu'elle touche.
func _start_walk_demo() -> bool:
	var c := dummies_center()
	_walk = [c + Vector2(-1.6, -1.1) * U, c + Vector2(1.7, -0.6) * U, c + Vector2(1.7, 1.1) * U, c + Vector2(-0.6, 1.0) * U,
		c + Vector2(-0.4, -0.8) * U, c + Vector2(2.0, 0.2) * U]
	_walk_i = 0
	return true


## Pilote le joueur comme un vrai joueur (Input.action_press, voir tests/balance_sim/bot_pilot.gd) : marche de démonstration,
## sinon retour à la place d'origine une fois le sort fini.
func _steer_step() -> void:
	var want := Vector2.ZERO
	var pos := player.global_position
	if _walk_i >= 0 and _walk_i < _walk.size():
		_since_cast = 0.0
		var wp: Vector2 = _walk[_walk_i]
		if pos.distance_to(wp) < WALK_REACH_PX:
			_walk_i += 1
		else:
			want = (wp - pos).normalized()
	elif _since_cast > HOME_AFTER_S:
		var d := _home().distance_to(pos)
		if d > HOME_ENTER_PX or (_homing and d > HOME_LEAVE_PX):
			_homing = true
			want = (_home() - pos).normalized()
		else:
			_homing = false
	_press(want)


func _press(dir: Vector2) -> void:
	Input.action_press(&"move_left", maxf(-dir.x, 0.0)) if dir.x < 0.0 else Input.action_release(&"move_left")
	Input.action_press(&"move_right", maxf(dir.x, 0.0)) if dir.x > 0.0 else Input.action_release(&"move_right")
	Input.action_press(&"move_up", maxf(-dir.y, 0.0)) if dir.y < 0.0 else Input.action_release(&"move_up")
	Input.action_press(&"move_down", maxf(dir.y, 0.0)) if dir.y > 0.0 else Input.action_release(&"move_down")


func _release_moves() -> void:
	for a in MOVE_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


func _finish(slot: int, ok: bool) -> void:
	if ok:
		casts_ok += 1
	else:
		casts_failed += 1
	cast_finished.emit(slot, ok)


## Écouteur audio calé sur la caméra de l'arène (voir l'en-tête : sinon tout est trop loin du listener du menu).
func _poke_listener() -> void:
	if _cam == null or not is_instance_valid(_cam) or not (&"_listener_cache" in Audio):
		return
	Audio.set(&"_listener_frame", Engine.get_process_frames())
	Audio.set(&"_listener_cache", _cam.get_screen_center_position())
