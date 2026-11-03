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
		_check(p.top_level and p.get_parent() == p.follow, "%s : %s top_level sous son hôte" % [what, p.key])
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
		_check(p.global_position.distance_to(h.global_position) < 1.0 or p._t == 0.0, "%s : %s posé sur son hôte" % [what, p.key])


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
