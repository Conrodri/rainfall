extends Node
## Faune par biome (data/fauna.json -> EnemyVisual) : table, replis vers l'étage 1, mini-boss et boss
## enregistrés (lots N2a-N2e branchés à la livraison), intégration avec un vrai StageManager (étages 1-3).
## (le sprite affiché porte une copie convertie des SpriteFrames, NormalMaps : on compare `_tier_frames`).
## godot --headless --path game res://tests/biome_fauna_test.tscn

class FakeDirector extends Node:
	func spawn_boss(_kind: StringName, position: Vector2) -> Node2D:
		var b := Node2D.new()
		b.position = position
		add_child(b)
		return b

	func set_zone(_id: int, _center: Vector2, _radius: float, _active: bool, _kind: StringName = &"mini") -> void:
		pass


var _fails := 0
var _fake_chest_script: GDScript


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _ready() -> void:
	await get_tree().process_frame
	EnemyVisual.biome_override = &""
	EnemyVisual.set_fauna(null)
	_table()
	_fallbacks()
	_injected()
	_bosses()
	await _stage()
	EnemyVisual.biome_override = &""
	EnemyVisual.set_fauna(null)
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


# --- table ---------------------------------------------------------------------------------
func _table() -> void:
	var data := EnemyVisual.fauna()
	_check(not data.is_empty(), "fauna.json lu")
	var floors := {}
	for b in EnemyVisual.biomes():
		var bd := EnemyVisual.biome_data(b)
		floors[int(bd.get("floor", -1))] = b
		var mons: Dictionary = bd.get("monsters", {})
		for role in ["swarm", "shooter", "leaper", "brute"]:
			_check(mons.has(role), "%s : rôle %s déclaré" % [b, role])
		_check(bd.has("elites"), "%s : table d'élites" % b)
		_check(not (bd.get("floor_bosses", []) as Array).is_empty(), "%s : boss d'étage déclarés" % b)
		for id in (bd.get("floor_bosses", []) as Array) + (bd.get("minis", []) as Array):
			_check(not EnemyVisual.boss_cfg(StringName(id)).is_empty(), "%s : géométrie de %s" % [b, id])
	_check(floors.size() == 5, "5 étages distincts (%d)" % floors.size())
	var expect := {1: &"terrasses", 2: &"foret", 3: &"cite", 4: &"cryptes", 5: &"source"}
	for f in expect:
		_check(EnemyVisual.biome_for_floor(f) == expect[f], "étage %d -> %s (a %s)" % [f, expect[f], EnemyVisual.biome_for_floor(f)])
	_check(EnemyVisual.biome_for_floor(6) == &"terrasses" and EnemyVisual.biome_for_floor(10) == &"source", "sans fin : 6 -> terrasses, 10 -> source")
	_check(EnemyVisual.default_biome() == &"terrasses", "biome par défaut = terrasses")
	_check(EnemyVisual.biome_of_map("terrasses_noyees") == &"terrasses", "carte terrasses_noyees")
	_check(EnemyVisual.biome_of_map("foret_brume") == &"foret", "carte foret_brume")
	_check(EnemyVisual.biome_of_map("cite_rouille") == &"cite", "carte cite_rouille")
	_check(EnemyVisual.biome_of_map("inconnue") == &"", "carte inconnue -> vide")
	_check(EnemyVisual.biome_of_boss(&"cerf_lanterne") == &"foret", "cerf_lanterne -> forêt (alias)")
	_check(EnemyVisual.biome_of_boss(&"sonneur") == &"cite" and EnemyVisual.biome_of_boss(&"eclusier") == &"terrasses", "sonneur / éclusier")
	# étage 1 = sprites actuels
	for k in [1, 2, EnemyVisual.LEAPER_KEY, 3]:
		var e := EnemyVisual.monster_entry(k, &"terrasses")
		_check(e[0] != null and e[0] == EnemyVisual.frames_for_tier(k), "terrasses clé %d : sprite actuel" % k)
		_check(String(e[1]["name"]) == String(EnemyVisual.SPRITES[k]["name"]), "terrasses clé %d : dossier %s" % [k, EnemyVisual.SPRITES[k]["name"]])


# --- replis : asset de biome absent -> étage 1 ----------------------------------------------
func _fallbacks() -> void:
	for b in EnemyVisual.biomes():
		for k in [1, 2, EnemyVisual.LEAPER_KEY, 3]:
			var role: String = EnemyVisual.ROLE_BY_KEY[k]
			var spec: Variant = (EnemyVisual.biome_data(b)["monsters"] as Dictionary)[role]
			var nm: String = spec if spec is String else String(spec["name"])
			var own := "res://assets/sprites/monsters/%s/%s.tres" % [nm, nm]
			var e := EnemyVisual.monster_entry(k, b)
			var el := EnemyVisual.monster_entry(k, b, true)
			_check(e[0] != null, "%s clé %d : un sprite (propre ou repli)" % [b, k])
			_check(el[0] == e[0], "%s clé %d : élite sans asset -> sprite normal" % [b, k])
			if ResourceLoader.exists(own):
				_check(String(e[1]["name"]) == nm, "%s clé %d : asset livré %s utilisé" % [b, k, nm])
			else:
				_check(e[0] == EnemyVisual.monster_frames(k, &"terrasses"), "%s clé %d : repli étage 1 (%s absent)" % [b, k, nm])
	# biome inconnu -> étage 1
	_check(EnemyVisual.monster_frames(1, &"nulle_part") == EnemyVisual.frames_for_tier(1), "biome inconnu -> étage 1")


# --- table injectée : mapping réel, élites, surcharge de géométrie, repli bondisseur ---------
func _injected() -> void:
	EnemyVisual.set_fauna({
		"default_biome": "base",
		"biomes": {
			"base": {"floor": 1, "monsters": {"swarm": "swarm_tier1", "shooter": "shooter_tier2", "leaper": "absent_leaper", "brute": "brute_tier3"}, "elites": {}},
			"x": {"floor": 2, "monsters": {"swarm": "shooter_tier2", "shooter": "absent_x", "leaper": "absent_x2", "brute": {"name": "brute_tier3", "scale": 0.5}},
				"elites": {"swarm": "brute_tier3"}},
		},
	})
	var sw_x := EnemyVisual.monster_entry(1, &"x")
	_check(String(sw_x[1]["name"]) == "shooter_tier2" and sw_x[0] == EnemyVisual.frames_for_tier(2), "biome x : essaim -> dossier du biome")
	var el_x := EnemyVisual.monster_entry(1, &"x", true)
	_check(String(el_x[1]["name"]) == "brute_tier3" and el_x[0] == EnemyVisual.frames_for_tier(3), "biome x : élite d'essaim -> dossier d'élite")
	var sh_x := EnemyVisual.monster_entry(2, &"x")
	_check(String(sh_x[1]["name"]) == "shooter_tier2", "biome x : tireur absent -> base")
	var br_x := EnemyVisual.monster_entry(3, &"x")
	_check(is_equal_approx(float(br_x[1]["scale"]), 0.5) and is_equal_approx(float(br_x[1]["offset_y"]), float(EnemyVisual.SPRITES[3]["offset_y"])), "biome x : surcharge d'échelle, reste hérité du rôle")
	var lp := EnemyVisual.monster_entry(EnemyVisual.LEAPER_KEY, &"x")
	_check(lp[2] == 2 and lp[0] == EnemyVisual.frames_for_tier(2), "bondisseur absent partout -> tireur (clé %d)" % lp[2])
	# configure() : biome forcé, élite, géométrie
	EnemyVisual.biome_override = &"x"
	var v := EnemyVisual.new()
	add_child(v)
	v.configure(1, 22.4, false, 0, &"", true)
	var s := v.get_node("Sprite") as AnimatedSprite2D
	_check(s.visible and v._tier_frames == EnemyVisual.frames_for_tier(3), "configure élite (biome x) -> sprite d'élite")
	v.configure(3, 30.0, false)
	var exp_sc := EnemyVisual._billboard_scale(0.5, EnemyVisual.SPRITES[3])
	_check(s.scale.is_equal_approx(exp_sc), "configure brute (biome x) -> échelle surchargée")
	v.configure(2, 22.4, false, 1)
	_check(v._tier_frames == EnemyVisual.frames_for_tier(2) and s.sprite_frames.has_animation(&"run_e"), "configure bondisseur sans sprite -> tireur")
	v.queue_free()
	EnemyVisual.biome_override = &""
	# sans fauna.json : sprites de l'étage 1 (constante SPRITES)
	EnemyVisual.set_fauna({})
	for k in [1, 2, EnemyVisual.LEAPER_KEY, 3]:
		_check(EnemyVisual.monster_frames(k, &"foret") == EnemyVisual.frames_for_tier(k), "table vide : clé %d -> étage 1" % k)
	_check(EnemyVisual.mini_pool(&"cerf") == [&"bramble_queen", &"brood_mother"], "table vide : mini-boss par MINIS_BY_FLOOR")
	EnemyVisual.set_fauna(null)


# --- boss et mini-boss ------------------------------------------------------------------------
func _bosses() -> void:
	var expected := {
		&"mist_wolf": "res://assets/sprites/bosses/mini/mist_wolf/mist_wolf.tres",
		&"lantern_owl": "res://assets/sprites/bosses/mini/lantern_owl/lantern_owl.tres",
		&"moss_mantis": "res://assets/sprites/bosses/mini/moss_mantis/moss_mantis.tres",
		&"weaver": "res://assets/sprites/bosses/etage/weaver/weaver.tres",
		&"hermit_cedar": "res://assets/sprites/bosses/etage/hermit_cedar/hermit_cedar.tres",
	}
	for id in expected:
		_check(EnemyVisual.boss_path(id) == expected[id], "%s : chemin enregistré %s (a %s)" % [id, expected[id], EnemyVisual.boss_path(id)])
		_check(EnemyVisual.boss_available(id) == ResourceLoader.exists(expected[id]), "%s : disponibilité = présence du .tres" % id)
	_check(bool(EnemyVisual.boss_cfg(&"weaver")["floor"]), "weaver = boss d'étage")
	_check(EnemyVisual.boss_cfg(&"mist_wolf")["floor"] == false, "mist_wolf = mini-boss")
	_check(EnemyVisual.boss_cfg(&"cerf") == EnemyVisual.BOSS_SPRITES[&"cerf"], "BOSS_SPRITES prime sur le JSON")
	var all_f := EnemyVisual.minis_for_biome(&"foret", false)
	_check(all_f.size() == 5 and &"mist_wolf" in all_f and &"lantern_owl" in all_f and &"moss_mantis" in all_f, "forêt : 5 mini-boss enregistrés")
	var avail_f := EnemyVisual.minis_for_biome(&"foret")
	_check(avail_f.size() >= 2 and avail_f[0] == &"bramble_queen" and avail_f[1] == &"brood_mother", "forêt : rotation livrée commence par bramble_queen, brood_mother")
	for id in avail_f:
		_check(EnemyVisual.boss_frames(id) != null, "forêt : %s livré et valide" % id)
	for id in all_f:
		if not id in avail_f:
			_check(not ResourceLoader.exists(EnemyVisual.boss_path(id)), "forêt : %s absent -> hors rotation" % id)
	_check(EnemyVisual.floor_bosses_for_biome(&"foret").has(&"cerf"), "forêt : cerf livré")
	_check(EnemyVisual.minis_for_biome(&"terrasses").slice(0, 2) == [&"frost_bear", &"stone_colossus"], "terrasses : frost_bear, stone_colossus")
	_check(EnemyVisual.minis_for_biome(&"cite").slice(0, 2) == [&"ash_lord", &"rust_archon"], "cité : ash_lord, rust_archon")
	# résolution par le boss d'étage du Director (sans StageManager)
	var d := Node.new()
	add_child(d)
	d.set_meta(&"next_boss_id", "cerf_lanterne")
	EnemyVisual._mini_count = 0
	_check(EnemyVisual.resolve_boss_id(null, &"mini", d) == &"bramble_queen", "mini du biome du Cerf = bramble_queen")
	_check(EnemyVisual.resolve_boss_id(null, &"etage", d) == &"cerf", "boss d'étage = cerf")
	d.set_meta(&"next_boss_id", "eclusier")
	EnemyVisual._mini_count = 0
	_check(EnemyVisual.resolve_boss_id(null, &"mini", d) == &"frost_bear", "mini du biome de l'Éclusier = frost_bear")
	d.set_meta(&"next_boss_id", "weaver")
	_check(EnemyVisual.resolve_boss_id(null, &"etage", d) == &"weaver", "weaver résolu (sprite ou placeholder selon livraison)")
	d.queue_free()
	_check(EnemyVisual.summon_frames(&"mist_wolf_cub", &"foret") == (load("res://assets/sprites/bosses/mini/mist_wolf_cub/mist_wolf_cub.tres") if ResourceLoader.exists("res://assets/sprites/bosses/mini/mist_wolf_cub/mist_wolf_cub.tres") else null), "louveteau : enregistré, null tant que non livré")
	EnemyVisual._mini_count = 0


# --- intégration : vrai StageManager, étages 1 -> 3 ------------------------------------------
func _stage() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nfunc setup(_k, _s):\n\tpass\n"
	_fake_chest_script.reload()
	var director := FakeDirector.new()
	director.add_to_group(&"director")
	add_child(director)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var mgr := StageManager.new()
	mgr.chest_factory = func() -> Node2D:
		var c := Node2D.new()
		c.set_script(_fake_chest_script)
		return c
	add_child(mgr)
	EnemyVisual.reset_fauna_caches()
	var v := EnemyVisual.new()
	add_child(v)
	var expect := {1: [&"terrasses", "terrasses_noyees", &"frost_bear"], 2: [&"foret", "foret_brume", &"bramble_queen"], 3: [&"cite", "cite_rouille", &"ash_lord"]}
	RunState.rng.seed = 777
	for st in [1, 2, 3]:
		RunState.stage = st
		mgr.start_stage()
		await get_tree().process_frame
		var want: Array = expect[st]
		_check(mgr.map_id == want[1], "étage %d : carte %s (a %s)" % [st, want[1], mgr.map_id])
		_check(EnemyVisual.current_biome() == want[0], "étage %d : biome %s (a %s)" % [st, want[0], EnemyVisual.current_biome()])
		for k in [1, 2, 3]:
			v.configure(k, 24.0, false)
			var s := v.get_node("Sprite") as AnimatedSprite2D
			_check(s.visible and v._tier_frames == EnemyVisual.monster_frames(k, want[0]), "étage %d : tier %d sprite du biome (ou repli)" % [st, k])
		v.configure(2, 24.0, false, 1)
		_check(v._tier_frames == EnemyVisual.monster_frames(EnemyVisual.LEAPER_KEY, want[0]), "étage %d : bondisseur" % st)
		EnemyVisual._mini_count = 0
		var mini := EnemyVisual.resolve_boss_id(get_tree(), &"mini", director)
		_check(mini == want[2], "étage %d : premier mini-boss %s (a %s)" % [st, want[2], mini])
		_check(mini in EnemyVisual.minis_for_biome(want[0]), "étage %d : mini-boss du biome" % st)
		var fb := EnemyVisual.resolve_boss_id(get_tree(), &"etage", director)
		_check(fb != &"" and EnemyVisual.biome_of_boss(fb) == want[0], "étage %d : boss d'étage du biome (%s)" % [st, fb])
	v.queue_free()
	mgr.queue_free()
	director.queue_free()
	player.queue_free()
	EnemyVisual._mini_count = 0
	RunState.stage = 1
	await get_tree().process_frame
