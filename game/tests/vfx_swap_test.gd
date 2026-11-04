extends Node
## Mode test : les VRAIS sorts affichent les VFX de test pixelfx (VfxSwap + VfxTestPlayer en mode follow).
## godot --headless --path game res://tests/vfx_swap_test.tscn  -> RESULT: OK
## Vérifie :
## 1. résolution des clés (chemins, `_cel`, anims de boss sans direction, corps et coup auto exclus, meta du point d'appel) ;
## 2. interrupteur coupé (TestMode.vfx_test = false) : aucun VfxTestPlayer, effets d'origine visibles, frames intactes ;
## 3. interrupteur allumé : vrais lancers (SpellPreview) d'Ardent (zone, projectile), Averse (sprite de kit via
##    EmissiveOverlay, zone), Avare (salve de projectiles), Tocsin (sort de kit au lancement), Rainette (langue) :
##    un VfxTestPlayer suit chaque effet (top_level, hôte = effet d'origine), l'original est caché
##    (self_modulate.a = 0, émission comprise) et garde ses SpriteFrames ; tout est libéré à la fin ;
## 4. projectile poolé relancé interrupteur coupé : visuel rendu, aucun suiveur ;
## 5. boss d'étage (Éclusier, Récluse) dans l'arène de test : leurs attaques (coup auto, sprites d'effet du .tres)
##    accrochent des VfxTestPlayer sous les sprites d'origine cachés ; libération propre à leur mort.
## 6. effets permanents dessinés en code : orbes d'Ardent (Braises errantes, un effet par orbe), chaîne et chaîne
##    lestée d'Arpenteuse (effets répartis le long, chaîne cachée) ; interrupteur coupé : rien créé, recoupé : rendus ;
## 7. Canonnier de crue (rivets poolés suivis + impact, Obus en vol, fumée de rechargement), Cèdre (traînée de
##    charge), Fondeur (coulée) ; interrupteur coupé : aucun effet sur les projectiles du pool.
## 8. caméra iso : visée vers le haut -> projectiles tournés par Iso.screen_angle, traînée / coulée / chaîne couchées
##    au sol (ground_dir, angle logique), segments posés en repère logique le long de la ligne ; billboards retournés.
## Profil jamais écrit ; sauvegarde de test seulement.

const SAVE := "user://test_vfx_swap.json"
const CAST_FRAMES := 45

var _fails: Array[String] = []
var _chars := {}


func _check(c: bool, w: String) -> void:
	if not c:
		_fails.append(w)
		printerr("FAIL: ", w)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	Profile.write_enabled = false
	for c in CharacterCard.load_characters():
		_chars[String(c.id)] = c
	TestMode.begin()
	_test_keys()
	await _test_off()
	await _test_on()
	await _test_pool_off()
	await _test_bosses()
	await _test_points()
	await _test_enemy_fx()
	await _test_iso_dirs()
	await _test_usage_hooks()
	if TestMode.active:
		TestMode.end()
	VfxSwap.trace_on = false
	print("RESULT: ", "OK" if _fails.is_empty() else "FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- Outils ------------------------------------------------------------------------------------------------------

func _players() -> Array[VfxTestPlayer]:
	var out: Array[VfxTestPlayer] = []
	for n in get_tree().root.find_children("*", "Node2D", true, false):
		if n is VfxTestPlayer and not (n as VfxTestPlayer).finished_flag:
			out.append(n as VfxTestPlayer)
	return out


func _keys_of(ps: Array[VfxTestPlayer]) -> Array[String]:
	var out: Array[String] = []
	for p in ps:
		if not out.has(p.key):
			out.append(p.key)
	return out


func _arena(id: String, chosen := {}) -> SpellPreview:
	var host := Control.new()
	host.size = Vector2(560, 700)
	add_child(host)
	var pv := SpellPreview.new()
	host.add_child(pv)
	pv.start(_chars[id], chosen)
	await get_tree().process_frame
	_check(pv.ready_to_cast, "%s : arène prête" % id)
	return pv


func _close(pv: SpellPreview) -> void:
	var host := pv.get_parent()
	pv.shutdown()
	await get_tree().process_frame
	host.queue_free()
	await get_tree().process_frame


## Les VfxTestPlayer vivants suivent un hôte valide, caché, aux frames d'origine (jamais un .tres de vfx_test).
func _check_followers(what: String) -> void:
	for p in _players():
		_check(p.follow != null and is_instance_valid(p.follow), "%s : %s suit un hôte" % [what, p.key])
		if p.follow == null or not is_instance_valid(p.follow):
			continue
		# effet en boucle (ou projectile) sous son hôte ; one-shot à côté de l'hôte (il finit sur place si l'hôte part)
		var under := p.get_parent() == p.follow or (not p._loop and p.projection != "projectile" and p.get_parent() == p.follow.get_parent())
		_check(p.top_level and under, "%s : %s top_level sous son hôte (ou à côté, one-shot)" % [what, p.key])
		_check(p.process_mode != Node.PROCESS_MODE_ALWAYS, "%s : %s respecte la pause" % [what, p.key])
		var h := p.follow
		if h is AnimatedSprite2D:
			var a := h as AnimatedSprite2D
			_check(is_zero_approx(a.self_modulate.a), "%s : %s original caché" % [what, p.key])
			var em := a.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
			_check(em == null or is_zero_approx(em.self_modulate.a), "%s : %s émission cachée" % [what, p.key])
			var path := a.sprite_frames.resource_path if a.sprite_frames != null else ""
			_check(not path.contains("/vfx_test/"), "%s : %s frames d'origine gardées (%s)" % [what, p.key, path])
		elif h.get_script() == load(VfxSwap.ZONE_SCRIPT):
			var v := h.get(&"vfx") as AnimatedSprite2D
			_check(v == null or is_zero_approx(v.self_modulate.a), "%s : %s vfx de zone caché" % [what, p.key])
		_check(p.global_position.distance_to(h.global_position + p.follow_offset) < 1.0 or p._t == 0.0, "%s : %s posé sur son hôte" % [what, p.key])


# --- 1. Résolution ------------------------------------------------------------------------------------------------

func _test_keys() -> void:
	_check(VfxSwap.key_for_path("res://assets/sprites/vfx/ardent_nova/ardent_nova.tres") == "ardent/nova_ardente", "clé : chemin")
	_check(VfxSwap.key_for_path("res://assets/sprites/bosses/etage/cerf/cerf.tres", &"wisp_explode") == "cerf/wisp_explode", "clé : anim de boss")
	_check(VfxSwap.key_for_path("res://assets/sprites/bosses/etage/eclusier/eclusier.tres", &"ground_wave_s") == "eclusier/ground_water", "clé : anim de boss + direction + alias")
	_check(VfxSwap.key_for_path("res://assets/sprites/bosses/etage/cerf/cerf.tres", &"auto_s") == "", "clé : corps du boss exclu (auto)")
	_check(VfxSwap.key_for_path("res://assets/sprites/bosses/etage/cerf/cerf.tres", &"idle_p1_s") == "", "clé : corps du boss exclu (idle)")
	_check(VfxSwap.key_for_path("res://assets/sprites/characters/ardent/ardent.tres", &"idle_s") == "", "clé : corps du joueur exclu")
	_check(VfxSwap.available("ardent/brasier") and not VfxSwap.available("ardent/inconnu"), "clé : asset présent / absent")
	# interrupteur
	TestMode.vfx_test = true
	TestMode.active = false
	_check(not VfxSwap.enabled(), "interrupteur : hors mode test, rien")
	TestMode.active = true
	_check(VfxSwap.enabled(), "interrupteur : mode test + case")
	TestMode.vfx_test = false
	_check(not VfxSwap.enabled(), "interrupteur : case décochée")
	# meta du point d'appel (aucun asset d'origine : un sprite nu)
	TestMode.vfx_test = true
	var s := AnimatedSprite2D.new()
	add_child(s)
	s.set_meta(VfxSwap.META_KEY, "rainette/rainette_choeur")
	var sf := load("res://assets/sprites/characters/rainette/effects/land_ring/land_ring.tres") as SpriteFrames
	VfxSwap.on_sprite(s, sf)
	s.sprite_frames = sf
	VfxSwap._reevaluate(s)
	var f := VfxSwap.follower_of(s)
	_check(f != null and f.key == "rainette/rainette_choeur", "meta vfx_key du point d'appel prioritaire")
	_check(VfxSwap.is_hidden(s), "meta : original caché")
	TestMode.vfx_test = false
	VfxSwap._reevaluate(s)
	_check(VfxSwap.follower_of(s) == null and not VfxSwap.is_hidden(s), "réévaluation interrupteur coupé : original rendu, suiveur arrêté")
	s.queue_free()


# --- 2. Interrupteur coupé ----------------------------------------------------------------------------------------

func _test_off() -> void:
	TestMode.vfx_test = false
	var pv := await _arena("ardent")
	for slot in [1, 2]:
		pv.play(slot, {})
		await _frames(CAST_FRAMES)
		_check(_players().is_empty(), "coupé : ardent sort %d sans VfxTestPlayer" % slot)
	for n in get_tree().root.find_children("Vfx", "AnimatedSprite2D", true, false):
		var a := n as AnimatedSprite2D
		_check(is_equal_approx(a.self_modulate.a, 1.0) and not VfxSwap.is_hidden(a), "coupé : vfx de zone visible")
		_check(not a.sprite_frames.resource_path.contains("/vfx_test/"), "coupé : frames d'origine")
	await _close(pv)


# --- 3. Interrupteur allumé ----------------------------------------------------------------------------------------

func _test_on() -> void:
	TestMode.vfx_test = true
	VfxSwap.trace_on = true
	var seen := {}
	var cases := [
		["ardent", 2, "ardent/nova_ardente", "zone"],
		["ardent", 1, "ardent/eclat_de_braise", "projectile"],
		["averse", 2, "averse/vague", "sprite"],
		["averse", 3, "averse/flaque_miroir", "zone"],
		["avare", 2, "avare/avare_poignee_de_pieces", "projectile"],
		["tocsin", 3, "tocsin/tocsin_coup_de_tocsin", "cast"],
		["rainette", 1, "rainette/rainette_langue", "sprite"],
	]
	var cur_id := ""
	var pv: SpellPreview = null
	var n0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for c in cases:
		if c[0] != cur_id:
			if pv != null:
				await _close(pv)
			cur_id = c[0]
			pv = await _arena(cur_id)
		VfxSwap.clear_trace()
		pv.play(int(c[1]), {})
		var found := false
		for i in 90:
			await get_tree().physics_frame
			for t in VfxSwap.trace:
				if String(t.get("key", "")) == c[2] and String(t.get("src", "")) == c[3]:
					found = true
			if found:
				break
		_check(found, "allumé : %s sort %d -> %s (%s)" % [c[0], c[1], c[2], c[3]])
		var keys := _keys_of(_players())
		_check(keys.has(c[2]) or c[3] == "projectile", "allumé : VfxTestPlayer %s présent (vu : %s)" % [c[2], keys])
		_check_followers("%s sort %d" % [c[0], c[1]])
		seen[c[2]] = true
	await _frames(240)
	_check_followers("après 4 s")
	await _close(pv)
	await _frames(5)
	_check(_players().is_empty(), "allumé : tous les VfxTestPlayer libérés avec leurs hôtes (reste %s)" % [_keys_of(_players())])
	var grown := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - n0
	_check(grown <= 8, "allumé : pas de fuite de nœuds (+%d)" % int(grown))
	print("  remplacements vus : ", seen.keys())


# --- 4. Pool de projectiles, interrupteur recoupé ----------------------------------------------------------------

func _test_pool_off() -> void:
	TestMode.vfx_test = true
	var pv := await _arena("tocsin")
	pv.play(1, {})
	await _frames(CAST_FRAMES)
	var hidden_before := 0
	for n in get_tree().root.find_children("Visual", "AnimatedSprite2D", true, false):
		if VfxSwap.is_hidden(n as CanvasItem):
			hidden_before += 1
	_check(hidden_before > 0, "pool : un projectile caché sous son effet de test")
	TestMode.vfx_test = false
	for i in 6:
		pv.play(1, {})
		await _frames(30)
	var active_hidden := 0
	for n in get_tree().root.find_children("Visual", "AnimatedSprite2D", true, false):
		var a := n as AnimatedSprite2D
		var proj := a.get_parent().get_parent() if a.get_parent() != null else null
		if proj != null and proj.get(&"active") == true and VfxSwap.is_hidden(a):
			active_hidden += 1
	_check(active_hidden == 0, "pool : projectile relancé interrupteur coupé -> visuel rendu (%d cachés)" % active_hidden)
	_check(_players().is_empty(), "pool : plus aucun VfxTestPlayer interrupteur coupé")
	await _close(pv)


# --- 5. Boss d'étage -------------------------------------------------------------------------------------------------

func _test_bosses() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"map_scene", load(TestMode.ARENA_SCENE))
	main.set(&"save_path", SAVE)
	main.set(&"run_seed", 7)
	add_child(main)
	await main.game_ready
	TestMode.active = true
	TestMode.vfx_test = true
	TestMode.god = true
	VfxSwap.trace_on = true
	var d: Director = main.get(&"director")
	d.spawning_enabled = false
	for id in ["eclusier", "recluse"]:
		VfxSwap.clear_trace()
		var p: Node2D = main.get(&"player")
		var b := TestTools.spawn_boss(get_tree(), StringName(id), &"etage", p.global_position + Vector2(220.0, 0.0)) as Enemy
		_check(b != null and b.boss_id() == StringName(id), "%s : apparu" % id)
		if b == null:
			continue
		var auto_seen := false
		var sprite_seen := false
		var checked := false
		for i in 60 * 16:
			await get_tree().physics_frame
			for t in VfxSwap.trace:
				var k := String(t.get("key", ""))
				if k.begins_with(id + "/"):
					if String(t["src"]) == "boss_auto":
						auto_seen = true
					elif String(t["src"]) == "sprite":
						sprite_seen = true
			if sprite_seen and not checked:
				checked = true
				_check_followers("%s (sprites)" % id)
			if auto_seen and sprite_seen:
				break
		_check(auto_seen, "%s : coup auto -> %s/auto" % [id, id])
		_check(sprite_seen, "%s : sprite d'effet du .tres remplacé" % id)
		# corps jamais caché
		var vis := b.visual as EnemyVisual
		for c in vis.get_children():
			if c is AnimatedSprite2D:
				_check(not VfxSwap.is_hidden(c as CanvasItem) and VfxSwap.follower_of(c) == null, "%s : corps jamais remplacé" % id)
		b.take_damage(b.hp + 1.0)
		await _frames(240)
		TestTools.kill_all(get_tree())
		await _frames(30)
		var left: Array[String] = []
		for pl in _players():
			if pl.key.begins_with(id + "/"):
				left.append(pl.key)
		_check(left.is_empty(), "%s : effets de test libérés après la mort (reste %s)" % [id, left])
	TestMode.god = false
	main.queue_free()
	await get_tree().process_frame


# --- 6. Effets permanents dessinés en code (orbes d'Ardent, chaîne d'Arpenteuse) ------------------------------------

func _new_player(id: String, loadout: Dictionary) -> CharacterBody2D:
	RunState.start_run(&"moyen", 1234)
	RunState.running = false
	RunState.level = 1
	RunState.character = StringName(id)
	RunState.loadout = loadout.duplicate()
	var p: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.character = CharacterData.for_id(StringName(id), loadout)
	add_child(p)
	p.global_position = Vector2.ZERO
	p.set_physics_process(false)
	p.spells.manual_aim_enabled = false
	await get_tree().process_frame
	return p


## Fait vivre le joueur `frames` images (kit et sorts), en le déplaçant de `move` px par image.
func _drive(p: CharacterBody2D, frames: int, move := Vector2.ZERO) -> void:
	for i in frames:
		p.global_position += move
		p.tick(1.0 / 60.0)
		await get_tree().process_frame


func _poly_len(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


func _test_points() -> void:
	TestMode.active = true # la partie de boss précédente a refermé le mode test
	VfxSwap.trace_on = true
	# Braises errantes : 3 orbes, un effet de test par orbe
	TestMode.vfx_test = false
	var p := await _new_player("ardent", {1: &"roaming_embers"})
	await _drive(p, 40)
	var ring := p.get_node_or_null(^"EmberRing") as ArdentEmberRing
	_check(ring != null, "braises : anneau créé")
	if ring != null:
		_check(_players().is_empty() and not ring.has_meta(VfxSwap.META_POINTS) and is_equal_approx(ring.self_modulate.a, 1.0), "braises coupé : rien créé, dessin visible")
		TestMode.vfx_test = true
		await _drive(p, 20)
		var ps := _players()
		_check(ps.size() == ArdentEmberRing.ORBS and _keys_of(ps) == ["ardent/roaming_embers"], "braises : un effet de test par orbe (%d, %s)" % [ps.size(), _keys_of(ps)])
		_check(VfxSwap.is_hidden(ring), "braises : dessin d'origine caché")
		var lift := Iso.lift_logical(ArdentEmberRing.LIFT_U)
		for f in ps:
			var best := INF
			for o in ring.orb_positions():
				best = minf(best, f.global_position.distance_to(o + Vector2(0.0, lift)))
			_check(best < 24.0, "braises : effet posé sur une orbe (%.1f px)" % best)
			_check(f.process_mode != Node.PROCESS_MODE_ALWAYS, "braises : respecte la pause")
		await _drive(p, 120) # l'anneau tourne : les effets restent les mêmes (aucune recréation)
		var again := _players()
		_check(again.size() == ArdentEmberRing.ORBS and again[0] in ps, "braises : effets stables pendant 2 s")
		TestMode.vfx_test = false
		await _drive(p, 3)
		_check(_players().is_empty() and not ring.has_meta(VfxSwap.META_POINTS) and not VfxSwap.is_hidden(ring), "braises recoupé : effets libérés, dessin rendu")
	p.queue_free()
	await get_tree().process_frame
	# Chaîne et Chaîne lestée : effets répartis le long, chaîne cachée en entier
	for c in [[{}, "arpenteuse/arpenteuse_chaine"], [{1: &"arpenteuse_chaine_lestee"}, "arpenteuse/arpenteuse_chaine_lestee"]]:
		var key: String = c[1]
		TestMode.vfx_test = false
		var a := await _new_player("arpenteuse", c[0])
		var kit := a.kit as ArpenteuseKit
		_check(kit != null, "%s : kit" % key)
		if kit == null:
			a.queue_free()
			continue
		await _drive(a, 60, Vector2(6.0, 2.0))
		_check(_players().is_empty() and not kit.fx_root.has_meta(VfxSwap.META_POINTS) and is_equal_approx(kit.line.modulate.a, 1.0), "%s coupé : rien créé, chaîne visible" % key)
		TestMode.vfx_test = true
		VfxSwap.clear_trace()
		await _drive(a, 90, Vector2(6.0, 2.0))
		var pts := kit.line.base.points
		var seg := VfxSwap._tile_segment_px(key)
		var want := 0
		if seg > 0.0: # chaîne : tuiles bout à bout tous les segment_u (meta usage tile_along_line)
			want = mini(int(VfxTestPlayer.tile_layout(_poly_len(pts), seg).x), VfxSwap.TILES_MAX)
		else:
			var spacing := float(VfxSwap.POINT_SPACING.get(key, VfxSwap.POINT_SPACING_U)) * Balance.UNIT_PX
			want = clampi(int(_poly_len(pts) / spacing), 1, VfxSwap.POINTS_MAX)
		var ps := _players()
		_check(ps.size() == want and _keys_of(ps) == [key], "%s : %d effets le long (%d, %s, chaîne %.1f u)" % [key, want, ps.size(), _keys_of(ps), _poly_len(pts) / Balance.UNIT_PX])
		if seg > 0.0:
			var cover := 0.0
			for f in ps:
				cover += f.line_px
			_check(absf(cover - _poly_len(pts)) < 0.03 * _poly_len(pts) + 2.0, "%s : tuiles couvrant toute la chaîne (%.1f / %.1f px)" % [key, cover, _poly_len(pts)])
		_check(is_zero_approx(kit.line.modulate.a), "%s : chaîne d'origine cachée" % key)
		for f in ps:
			_check(ArpenteuseKit.dist_to_polyline(f.global_position, pts) < 8.0, "%s : effet sur la chaîne (%.1f px)" % [key, ArpenteuseKit.dist_to_polyline(f.global_position, pts)])
		var traced := false
		for t in VfxSwap.trace:
			traced = traced or (String(t.get("key", "")) == key and String(t.get("src", "")) == "points")
		_check(traced, "%s : trace points" % key)
		TestMode.vfx_test = false
		await _drive(a, 3, Vector2(6.0, 2.0))
		_check(_players().is_empty() and is_equal_approx(kit.line.modulate.a, 1.0) and not kit.fx_root.has_meta(VfxSwap.META_POINTS), "%s recoupé : effets libérés, chaîne rendue" % key)
		a.queue_free()
		await get_tree().process_frame
	await _frames(3)
	_check(_players().is_empty(), "points : tout libéré (reste %s)" % [_keys_of(_players())])


# --- 7. Boss : projectiles ennemis poolés, charges et coulées sans anim d'origine ------------------------------------

func _pool_of(d: Director) -> EnemyProjectilePool:
	return d.get(&"_projectiles") as EnemyProjectilePool


## Projectiles actifs du pool dont le visuel est caché.
func _hidden_shots(pool: EnemyProjectilePool) -> int:
	var n := 0
	for c in pool.get_children():
		var pr := c as EnemyProjectilePool.Projectile
		if pr != null and pr.active and VfxSwap.is_hidden(pr.get_node(^"Visual") as CanvasItem):
			n += 1
	return n


func _traced(key: String, src: String) -> bool:
	for t in VfxSwap.trace:
		if String(t.get("key", "")) == key and (src == "" or String(t.get("src", "")) == src):
			return true
	return false


func _wait_trace(key: String, src: String, max_frames: int) -> bool:
	for i in max_frames:
		if _traced(key, src):
			return true
		await get_tree().physics_frame
	return _traced(key, src)


func _test_enemy_fx() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"map_scene", load(TestMode.ARENA_SCENE))
	main.set(&"save_path", SAVE)
	main.set(&"run_seed", 11)
	add_child(main)
	await main.game_ready
	TestMode.active = true
	TestMode.god = true
	TestMode.vfx_test = false
	VfxSwap.trace_on = true
	VfxSwap.clear_trace()
	var d: Director = main.get(&"director")
	d.spawning_enabled = false
	var pool := _pool_of(d)
	var pl: Node2D = main.get(&"player")
	# Canonnier, interrupteur coupé : ses rivets restent des disques, aucun effet
	var g := TestTools.spawn_boss(get_tree(), &"flood_gunner", &"etage", pl.global_position + Vector2(200.0, 0.0)) as Enemy
	_check(g != null and g.boss_id() == &"flood_gunner", "canonnier : apparu")
	if g != null:
		var fired := false
		for i in 60 * 8:
			await get_tree().physics_frame
			if d.projectile_count() > 0:
				fired = true
				break
		_check(fired, "canonnier : tire (interrupteur coupé)")
		_check(_players().is_empty() and _hidden_shots(pool) == 0, "canonnier coupé : aucun effet de test, rivets visibles")
		# allumé : rivets suivis, visuel caché, impact au contact
		TestMode.vfx_test = true
		VfxSwap.clear_trace()
		var seen := await _wait_trace("flood_gunner/rivet", "enemy_projectile", 60 * 10)
		_check(seen, "canonnier : rivet -> flood_gunner/rivet")
		var followed := 0
		for c in pool.get_children():
			var pr := c as EnemyProjectilePool.Projectile
			if pr == null or not pr.active or not pr.has_meta(VfxSwap.META_POOLED):
				continue
			var f := VfxSwap.follower_of(pr)
			_check(f != null and f.key == "flood_gunner/rivet" and f.follow == pr and f.top_level, "canonnier : effet de test sur le rivet")
			_check(VfxSwap.is_hidden(pr.get_node(^"Visual") as CanvasItem), "canonnier : disque d'origine caché")
			followed += 1
		_check(followed > 0 or _traced("flood_gunner/rivet_hit", ""), "canonnier : au moins un rivet suivi en vol")
		_check(await _wait_trace("flood_gunner/rivet_hit", "enemy_projectile_hit", 60 * 10), "canonnier : impact -> flood_gunner/rivet_hit")
		# fin d'étage (clear_all) : les rivets en vol sont rendus au pool sans impact de test
		for k in 3:
			pool.fire(g, g.global_position + Vector2(0.0, 40.0 * k), Vector2(-300.0, 0.0), 1.0)
		VfxSwap.clear_trace()
		pool.clear_all()
		_check(not _traced("flood_gunner/rivet_hit", "enemy_projectile_hit"), "canonnier : clear_all ne pose aucun impact de rivet")
		# Obus : vole du canon au cercle pendant l'armement
		var gb: Object = g.brain
		gb.call(&"_start_shell", (pl.global_position - g.global_position).normalized(), pl.global_position)
		_check(_traced("flood_gunner/shell", "spawn_at"), "canonnier : Obus -> flood_gunner/shell")
		var shell_fx: VfxTestPlayer = null
		for v in _players():
			if v.key == "flood_gunner/shell":
				shell_fx = v
		_check(shell_fx != null and shell_fx.projection == "projectile" and shell_fx.follow == null, "canonnier : Obus de test en vol libre")
		# Fumée de rechargement : tant que la Mitraille recharge (follow_while sur le boss)
		VfxSwap.follow_while(g, "flood_gunner/reload_smoke", true, Vector2.RIGHT, 2.0)
		var smoke: VfxTestPlayer = null
		for v in _players():
			if v.key == "flood_gunner/reload_smoke":
				smoke = v
		_check(smoke != null and smoke.follow == g, "canonnier : fumée de rechargement sur le boss")
		VfxSwap.follow_while(g, "flood_gunner/reload_smoke", true, Vector2.RIGHT, 2.0)
		var n_smoke := 0
		for v in _players():
			if v.key == "flood_gunner/reload_smoke":
				n_smoke += 1
		_check(n_smoke == 1, "canonnier : une seule fumée tant que l'état dure (%d)" % n_smoke)
		VfxSwap.follow_while(g, "flood_gunner/reload_smoke", false)
		_check(smoke == null or smoke.finished_flag, "canonnier : fumée arrêtée à la fin du rechargement")
		_check(not g.has_meta(VfxSwap.META_WHILE), "canonnier : état « tant que » vidé")
		# recoupé : les tirs suivants rendent leur disque
		TestMode.vfx_test = false
		await _frames(60 * 6)
		_check(_hidden_shots(pool) == 0, "canonnier recoupé : rivets relancés visibles (%d cachés)" % _hidden_shots(pool))
		var left := 0
		for v in _players():
			if v.key.begins_with("flood_gunner/rivet"):
				left += 1
		_check(left <= 2, "canonnier recoupé : effets de rivets finis (%d)" % left)
		TestTools.kill_all(get_tree())
		await _frames(30)
	# Cèdre : traînée de charge (phase 3) qui suit le boss
	TestMode.vfx_test = true
	VfxSwap.clear_trace()
	var cedar := TestTools.spawn_boss(get_tree(), &"hermit_cedar", &"etage", pl.global_position + Vector2(300.0, 0.0)) as Enemy
	_check(cedar != null and cedar.boss_id() == &"hermit_cedar", "cèdre : apparu")
	if cedar != null:
		await _frames(5)
		var cb: Object = cedar.brain
		# vrille (coup auto de phase 2) : la racine root_spike est le seul effet, pas de hermit_cedar/auto en plus
		cb.set(&"phase", 2)
		VfxSwap.clear_trace()
		cb.call(&"_start_tendril", (pl.global_position - cedar.global_position).normalized())
		_check(await _wait_trace("hermit_cedar/root_spike", "sprite", 60 * 5), "cèdre : vrille -> hermit_cedar/root_spike")
		await _frames(2)
		_check(not _traced("hermit_cedar/auto", "boss_auto"), "cèdre : vrille sans hermit_cedar/auto en plus")
		cb.set(&"phase", 3)
		cb.set(&"_cycle", 0)
		cb.call(&"_start_spell", (pl.global_position - cedar.global_position).normalized(), pl.global_position)
		_check(await _wait_trace("hermit_cedar/charge_trail", "", 60 * 5), "cèdre : charge -> hermit_cedar/charge_trail")
		var trail: VfxTestPlayer = null
		for v in _players():
			if v.key == "hermit_cedar/charge_trail":
				trail = v
		_check(trail != null and trail.follow == cedar, "cèdre : traînée qui suit le boss")
		_check(trail != null and trail.projection == "ground_dir" and absf(wrapf(trail.rot.rotation - (cb.get(&"aim") as Vector2).angle(), -PI, PI)) < 0.01, "cèdre : traînée orientée sur la charge")
		await _frames(150)
		_check(trail == null or not is_instance_valid(trail) or trail.finished_flag, "cèdre : traînée finie avec la charge")
		TestTools.kill_all(get_tree())
		await _frames(30)
	# Fondeur : coulée posée sur la ligne
	VfxSwap.clear_trace()
	var sm := TestTools.spawn_boss(get_tree(), &"smelter", &"etage", pl.global_position + Vector2(260.0, 0.0)) as Enemy
	_check(sm != null and sm.boss_id() == &"smelter", "fondeur : apparu")
	if sm != null:
		await _frames(5)
		var sb: Object = sm.brain
		sb.set(&"_cycle", 0)
		sb.call(&"_start_spell", (pl.global_position - sm.global_position).normalized(), pl.global_position)
		_check(await _wait_trace("smelter/molten_arc", "spawn_at", 60 * 5), "fondeur : coulée -> smelter/molten_arc")
		var arc: VfxTestPlayer = null
		for v in _players():
			if v.key == "smelter/molten_arc":
				arc = v
		_check(arc != null and arc.follow != null and arc.follow.name.begins_with("VfxSwapAnchor"), "fondeur : coulée ancrée au sol")
		_check(arc != null and arc.projection == "ground_dir" and arc.space.scale == Vector2.ONE, "fondeur : coulée couchée dans le plan du sol")
		if arc != null:
			var p0 := arc.global_position
			await _frames(20)
			_check(not is_instance_valid(arc) or arc.global_position.distance_to(p0) < 1.0, "fondeur : coulée immobile")
		# bande de métal : sprite d'origine gardé (danger lisible 5 s) ; éclaboussure au milieu -> smelter/molten_pool
		var slag: Variant = sb.get(&"_slag")
		if slag != null and is_instance_valid(slag) and not (slag as SmelterSlag).pools.is_empty():
			var q: Dictionary = (slag as SmelterSlag).pools[0]
			_check(VfxSwap.follower_of(q["node"]) == null and not VfxSwap.is_hidden(q["node"]), "fondeur : bande de métal d'origine gardée")
			var pc: Vector2 = (q["a"] as Vector2) + Vector2.from_angle(float(q["ang"])) * float(q["len"]) * 0.5
			var sp: VfxTestPlayer = null
			for v in _players():
				if v.key == "smelter/molten_pool" and (sp == null or v.global_position.distance_to(pc) < sp.global_position.distance_to(pc)):
					sp = v
			_check(sp != null and sp.global_position.distance_to(pc) < 1.0, "fondeur : éclaboussure au milieu de la coulée")
			var want := float(VfxTestPlayer.resolve("smelter/molten_pool")["size_u"]) * Balance.UNIT_PX / sp._fw if sp != null else 0.0
			_check(sp != null and sp.projection == "ground" and is_equal_approx(sp.node_scale, want), "fondeur : éclaboussure à plat, rayon 1,2 u (r du cerveau)")
		TestTools.kill_all(get_tree())
		await _frames(30)
	TestMode.god = false
	TestMode.vfx_test = false
	main.queue_free()
	await _frames(5)
	_check(_players().is_empty(), "boss : tous les effets de test libérés (reste %s)" % [_keys_of(_players())])


# --- 9. Usages des metas sur les vrais sprites d'origine ----------------------------------------------------------

func _follower_key(key: String) -> VfxTestPlayer:
	for v in _players():
		if v.key == key:
			return v
	return null


func _boss_sprite(boss: String, anim: StringName, energy := 2.0) -> AnimatedSprite2D:
	var sf := load("res://assets/sprites/bosses/etage/%s/%s.tres" % [boss, boss]) as SpriteFrames
	if sf == null or not sf.has_animation(anim):
		return null
	var s := AnimatedSprite2D.new()
	EmissiveOverlay.apply(s, sf, energy)
	s.animation = anim
	return s


## Images de rendu (les suiveurs vivent dans _process ; une libération a lieu en fin d'image).
func _pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Rayon affiché (px) de l'effet de crue : rayon dessiné de la meta (asset dédié) ou demi-largeur de planche (repli).
func _flood_r(v: VfxTestPlayer) -> float:
	var nr := VfxTestPlayer.note_radius_u(VfxTestPlayer.load_meta(v.key))
	if nr > 0.0:
		return nr * Balance.UNIT_PX * v.body.scale.x / v._fit_base
	return v._fw * v.body.scale.x * 0.5


func _test_usage_hooks() -> void:
	TestMode.active = true
	TestMode.vfx_test = true
	VfxSwap.trace_on = true
	VfxSwap.clear_trace()
	const U := 64.0
	var root := Node2D.new()
	add_child(root)
	# fil de la Tisseuse (WeaverSnare.add_thread) : tuiles bout à bout sur toute la longueur du fil
	var sn := WeaverSnare.new()
	sn.frames = load("res://assets/sprites/bosses/etage/weaver/weaver.tres")
	sn.set_physics_process(false)
	root.add_child(sn)
	var a := Vector2(100.0, 50.0)
	var ang := -1.0
	sn.add_thread(a, a + Vector2.from_angle(ang) * 7.0 * U, 0.5, 5.0)
	await _pframes(2)
	var th := _follower_key("weaver/thread")
	_check(th != null and th.usage == "tile_along_line", "fil : effet de test tuilé")
	if th != null:
		_check(absf(th.line_px - 7.0 * U) < 1.0 and th.tiles.size() == 4, "fil : 7 u couverts par 4 tuiles (%.1f px, %d)" % [th.line_px, th.tiles.size()])
		_check(th.global_position.distance_to(a) < 1.0 and _near_angle(th.rot.rotation, ang), "fil : part de A, orienté vers B")
	# racines en gerbe du Cèdre (2,2 u, sprite libéré à 0,7 s) : étirées à 2,2 u, finissent sur place
	var rs := _boss_sprite("hermit_cedar", &"root_spike")
	if rs != null:
		var tex := rs.sprite_frames.get_frame_texture(&"root_spike", 0)
		rs.centered = false
		rs.offset = Vector2(0.0, -tex.get_height() * 0.5)
		rs.scale = Vector2(2.2 * U / tex.get_width(), 0.6 * U / tex.get_height())
		rs.play(&"root_spike")
		root.add_child(rs)
		rs.position = Vector2(-200.0, 0.0)
		rs.rotation = PI * 0.5
		await _pframes(2)
		var rf := VfxSwap.follower_of(rs)
		_check(rf != null and rf.key == "hermit_cedar/root_spike" and absf(rf.line_px - 2.2 * U) < 1.0, "racines : gerbe affichée à 2,2 u (%.1f px)" % (rf.line_px if rf != null else -1.0))
		_check(rf != null and is_equal_approx(rf.body.scale.x / rf.node_scale, 2.2 / 8.0) and _near_angle(rf.rot.rotation, PI * 0.5), "racines : corps étiré en x, couché vers le bas")
		_check(rf != null and is_equal_approx(rf.body.scale.y / rf.node_scale, 0.6), "racines : épaisseur ramenée au w gameplay (0,6 u sur 1 u dessiné)")
		_check(rf != null and rf.get_parent() == root, "racines : one-shot posé à côté du sprite d'origine")
		rs.queue_free()
		await _pframes(3)
		_check(rf != null and is_instance_valid(rf) and not rf.finished_flag and rf.detached, "racines : l'effet finit sur place après la libération du sprite")
	# croix de l'Éclusier : une crête par bras, orientée sur le bras, largeur du bras ; le sillage garde sa clé
	var d := Vector2.from_angle(PI * 0.25)
	var arm := _boss_sprite("eclusier", &"ground_wave", 1.8)
	if arm != null:
		arm.rotation = d.angle() - PI * 0.5
		arm.scale = Vector2(EclusierBrain.CROSS_W_U * U / EclusierBrain.WAVE_SRC_T, EclusierBrain.CROSS_LEN_U * U / EclusierBrain.WAVE_SRC_W)
		arm.play(&"ground_wave")
		root.add_child(arm)
		arm.global_position = Vector2(400.0, 0.0) + d * EclusierBrain.CROSS_LEN_U * U * 0.5
		await _pframes(2)
		_check(_traced("eclusier/wave", "cross"), "croix : bras -> crête eclusier/wave")
		var cr: VfxTestPlayer = null
		for v in _players():
			if v.key == "eclusier/wave" and v.follow == null:
				cr = v
		_check(cr != null and _near_angle(cr.rot.rotation, d.angle()) and cr.projection == "ground_dir", "croix : crête orientée sur le bras")
		if cr != null:
			_check(is_equal_approx(cr._move_range, EclusierBrain.CROSS_LEN_U * U) and cr.position.distance_to(Vector2(400.0, 0.0)) < cr._moved + 1.0, "croix : la crête part du boss et file sur le bras")
			var want_w := float(VfxTestPlayer.resolve("eclusier/wave")["size_u"]) * U * EclusierBrain.CROSS_W_U / 4.0
			_check(absf(cr.node_scale * cr._fw - want_w) < 0.5, "croix : crête à la largeur du bras (3 u sur 4)")
		_check(VfxSwap.is_hidden(arm), "croix : jet d'origine caché")
	var trail := _boss_sprite("eclusier", &"ground_wave", 1.2)
	if trail != null:
		# EclusierBrain._spawn_wave / _place_wave : tourné de -90° sur le trajet, posé au milieu, échelle y = dist / WAVE_SRC_W
		var o := Vector2(-300.0, 200.0)
		var wd := Vector2.from_angle(0.7)
		trail.rotation = 0.7 - PI * 0.5
		trail.scale = Vector2(3.0 * U / EclusierBrain.WAVE_SRC_T, 1.0 / EclusierBrain.WAVE_SRC_W)
		trail.play(&"ground_wave")
		root.add_child(trail)
		trail.position = o
		await _pframes(2)
		var tf := VfxSwap.follower_of(trail)
		_check(tf != null and tf.key == "eclusier/ground_water" and tf.usage == "tile_along_line", "sillage de vague : eclusier/ground_water tuilé (%s)" % (tf.key if tf != null else "aucune"))
		if tf != null:
			_check(_near_angle(tf.rot.rotation, 0.7) and tf.projection == "ground_dir", "sillage de vague : orienté sur le trajet")
			trail.position = o + wd * 3.5 * U
			trail.scale.y = 7.0 * U / EclusierBrain.WAVE_SRC_W
			await _pframes(2)
			_check(absf(tf.line_px - 7.0 * U) < 1.0 and tf.tiles.size() == 4, "sillage de vague : 7 u couverts par 4 tuiles (%.1f px, %d)" % [tf.line_px, tf.tiles.size()])
			_check(tf.global_position.distance_to(o) < 1.0, "sillage de vague : part de l'origine de la vague (écart %.1f px)" % tf.global_position.distance_to(o))
			_check(is_equal_approx(tf.tiles[0].scale.y, tf.node_scale * 0.75), "sillage de vague : largeur 3 u (4 u dessinés)")
	# crue du Semeur : flaque vue de dessus ajustée au disque, masquée avec lui
	var fl := _boss_sprite("rain_sower", &"flood_water", 1.4)
	if fl != null:
		fl.play(&"flood_water")
		root.add_child(fl)
		fl.scale = Vector2.ONE * (4.0 * U / 448.0)
		await _pframes(2)
		var ff := VfxSwap.follower_of(fl)
		var own := VfxSwap.available("rain_sower/flood_water")
		var fk := "rain_sower/flood_water" if own else "jar_bearer/puddle"
		_check(ff != null and ff.key == fk, "crue -> %s (%s)" % [fk, ff.key if ff != null else "aucune"])
		if ff != null:
			_check(absf(_flood_r(ff) - 4.0 * U) < 1.0, "crue : rayon de l'effet = rayon du disque (4 u, %.1f px)" % _flood_r(ff))
			_check(is_equal_approx(ff.body.scale.y / ff.body.scale.x, 1.0 if own else 1.6), "crue : ellipse 2:1 (aspect %s)" % ("1" if own else "1,6 du repli"))
			fl.visible = false
			await _pframes(2)
			_check(is_instance_valid(ff) and not ff.finished_flag and not ff.space.visible, "crue : masquée avec le disque, pas libérée")
			fl.visible = true
			fl.scale = Vector2.ONE * (6.0 * U / 448.0)
			await _pframes(2)
			_check(is_instance_valid(ff) and ff.space.visible and absf(_flood_r(ff) - 6.0 * U) < 1.0, "crue : rendue et agrandie avec le disque (6 u de rayon)")
	# rayon de la Recluse : ligne relue sur le sprite qui tourne
	var ray := _boss_sprite("recluse", &"ray", 2.6)
	if ray != null:
		ray.scale = Vector2(RecluseBrain.RAY_LEN_U * U / 896.0, RecluseBrain.RAY_W_U * U / 64.0)
		ray.offset = Vector2(448.0, 0.0)
		ray.play(&"ray")
		root.add_child(ray)
		ray.rotation = 0.3
		await _pframes(2)
		var yf := VfxSwap.follower_of(ray)
		var ray_px := (448.0 + ray.sprite_frames.get_frame_texture(&"ray", 0).get_width() * 0.5) * ray.scale.x
		_check(yf != null and yf.usage == "line_from_pivot" and absf(yf.line_px - ray_px) < 1.0 and _near_angle(yf.rot.rotation, 0.3), "rayon : ligne du pivot sur %.1f u (%.1f px)" % [ray_px / U, yf.line_px if yf != null else -1.0])
		ray.rotation = 1.2
		await _pframes(2)
		_check(yf != null and _near_angle(yf.rot.rotation, 1.2), "rayon : suit la rotation du sprite")
	# anneau de cloche : à plat, rayon gameplay = rayon dessiné (8 u)
	var bw := _boss_sprite("recluse", &"bell_wave", 2.4)
	if bw != null:
		bw.play(&"bell_wave")
		root.add_child(bw)
		await _pframes(2)
		var bf := VfxSwap.follower_of(bw)
		_check(bf != null and bf.projection == "ground" and absf(bf.node_scale * bf._fw - float(VfxTestPlayer.resolve("recluse/bell_wave")["size_u"]) * U) < 0.5, "anneau de cloche : à plat, 8 u de rayon")
	root.queue_free()
	await _pframes(3)
	TestMode.vfx_test = false
	for v in _players():
		v.stop()
	await _pframes(2)


# --- 8. Caméra iso : aucun effet figé vers la droite (visée vers le haut) --------------------------------------------

func _near_angle(a: float, b: float) -> bool:
	return absf(wrapf(a - b, -PI, PI)) < 0.01


func _test_iso_dirs() -> void:
	TestMode.active = true
	TestMode.vfx_test = true
	var root := Node2D.new()
	add_child(root)
	var up := Vector2.UP # visée logique vers le haut de l'écran
	var sa := Iso.screen_angle(up)
	_check(absf(sa) > 0.1, "iso : angle écran d'une visée vers le haut non nul (%.2f)" % sa)
	# classe projectile (rivet, Obus, braises) : tournée par Iso.screen_angle dans l'espace billboard
	var h1 := Node2D.new()
	root.add_child(h1)
	var rv := VfxSwap.spawn_follow(h1, "flood_gunner/rivet", up)
	_check(rv != null and rv.projection == "projectile" and _near_angle(rv.rot.rotation, sa), "iso : rivet vers le haut tourné (%.2f)" % (rv.rot.rotation if rv != null else 0.0))
	var sh := VfxSwap.spawn_travel(root, "flood_gunner/shell", Vector2.ZERO, Vector2(0.0, -320.0), 1.0)
	_check(sh != null and sh.projection == "projectile" and _near_angle(sh.rot.rotation, sa), "iso : Obus vers le haut tourné")
	if sh != null:
		_check(is_equal_approx(sh._range_px, 320.0) and is_equal_approx(sh._speed_px, 320.0), "iso : Obus arrive sur sa cible à l'heure (%.0f px, %.0f px/s)" % [sh._range_px, sh._speed_px])
	var orb_owner := Node2D.new()
	root.add_child(orb_owner)
	var orbs: Array[Vector2] = [Vector2(100.0, 0.0)] # orbe à droite du centre : tangente vers le bas (sens horaire écran)
	VfxSwap.track_orbit(orb_owner, "ardent/roaming_embers", orbs, Vector2.ZERO, 0.0)
	await get_tree().process_frame
	VfxSwap.track_orbit(orb_owner, "ardent/roaming_embers", orbs, Vector2.ZERO, 0.0)
	var emb := VfxSwap.follower_of((orb_owner.get_meta(VfxSwap.META_POINTS)["anchors"] as Array)[0] as Node)
	_check(emb != null and _near_angle(emb.rot.rotation, Iso.screen_angle(Vector2.DOWN)), "iso : orbe tournée sur sa tangente")
	# classe ground_dir (traînée de charge, coulée, chaîne) : angle logique, plan du sol (la caméra écrase en 2:1)
	var h2 := Node2D.new()
	root.add_child(h2)
	var ct := VfxSwap.spawn_follow(h2, "hermit_cedar/charge_trail", up)
	_check(ct != null and ct.projection == "ground_dir" and _near_angle(ct.rot.rotation, up.angle()) and ct.space.scale == Vector2.ONE, "iso : traînée de charge couchée au sol vers le haut")
	var ma := VfxSwap.spawn_at(root, "smelter/molten_arc", Vector2.ZERO, up, null, {"anchored": true, "projection": "ground_dir"})
	_check(ma != null and ma.projection == "ground_dir" and _near_angle(ma.rot.rotation, up.angle()) and ma.space.scale == Vector2.ONE, "iso : coulée couchée au sol vers le haut")
	var ch_owner := Node2D.new()
	root.add_child(ch_owner)
	var ch_line := Node2D.new()
	ch_owner.add_child(ch_line)
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(0.0, -640.0)]) # 10 u vers le haut, en repère logique
	VfxSwap.track_polyline(ch_owner, "arpenteuse/arpenteuse_chaine", poly, ch_line)
	var segs: Array = (ch_owner.get_meta(VfxSwap.META_POINTS)["anchors"] as Array)
	_check(segs.size() == 5, "iso : chaîne de 10 u -> 5 tuiles de 2 u (%d)" % segs.size())
	for i in segs.size():
		var a: Node2D = segs[i]
		var f := VfxSwap.follower_of(a)
		var gp := a.global_position
		_check(f != null and f.projection == "ground_dir" and _near_angle(f.rot.rotation, up.angle()), "iso : tuile de chaîne couchée le long de la ligne")
		_check(gp.is_equal_approx(Vector2(0.0, -128.0 * i)), "iso : tuile %d posée bout à bout sur la ligne logique (%s)" % [i, gp])
		_check(f != null and is_equal_approx(f.line_px, 128.0), "iso : tuile de 2 u")
	# billboards (impact de rivet, fumée, chaîne lestée) : face caméra, retournés vers la gauche
	_check(rv != null and is_equal_approx(rv.rot.scale.x, 0.5) and is_equal_approx(rv.rot.scale.y, 1.0), "iso : rivet vers le haut raccourci de moitié par la perspective")
	var hit := VfxSwap.spawn_at(root, "flood_gunner/rivet_hit", Vector2.ZERO, Vector2.LEFT)
	_check(hit != null and hit.projection == "ground" and hit.space.scale == Vector2.ONE, "iso : impact de rivet à plat au sol (vu de dessus)")
	var h3 := Node2D.new()
	root.add_child(h3)
	VfxSwap.follow_while(h3, "flood_gunner/reload_smoke", true, Vector2.LEFT)
	var sm: VfxTestPlayer = null
	for v in _players():
		if v.key == "flood_gunner/reload_smoke":
			sm = v
	_check(sm != null and sm.rot.scale.x < 0.0, "iso : fumée tournée vers la visée (gauche)")
	VfxSwap.release_points(orb_owner)
	VfxSwap.release_points(ch_owner)
	_check(not VfxSwap.is_hidden(orb_owner) and is_equal_approx(ch_line.modulate.a, 1.0), "iso : originaux rendus")
	root.queue_free()
	await _frames(3)
	_check(_players().is_empty(), "iso : tout libéré (reste %s)" % [_keys_of(_players())])
	TestMode.vfx_test = false
