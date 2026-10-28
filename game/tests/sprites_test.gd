extends Node
## Test headless des sprites branchés : joueur, essaim, coffre, projectile (animations, frames, émission).
## godot --headless --path game res://tests/sprites_test.tscn

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _emission(n: Node) -> AnimatedSprite2D:
	return n.get_node_or_null("Emission") as AnimatedSprite2D


func _check_emission_sync(n: AnimatedSprite2D, label: String) -> void:
	var e := _emission(n)
	_check(e != null and e.visible, label + " : overlay d'émission présent")
	if e == null:
		return
	_check(e.material is ShaderMaterial, label + " : matériau émissif")
	_check(e.animation == n.animation, label + " : animation synchronisée")
	_check(e.frame == n.frame, label + " : frame synchronisée")
	_check(e.sprite_frames != n.sprite_frames, label + " : frames d'émission distinctes")


func _ready() -> void:
	await get_tree().process_frame
	# --- joueur -----------------------------------------------------------
	var player: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	var v := player.get_node("Visual") as AnimatedSprite2D
	_check(v != null, "joueur : Visual est un AnimatedSprite2D")
	if v != null:
		for d in ["e", "se", "s", "sw", "w", "nw", "n", "ne"]:
			_check(v.sprite_frames.has_animation("idle_" + d), "joueur : idle_" + d)
			_check(v.sprite_frames.has_animation("run_" + d), "joueur : run_" + d)
		_check(v.sprite_frames.get_frame_texture("run_e", 0) is AtlasTexture, "joueur : frames atlas")
		_check(v.is_playing(), "joueur : animation jouée")
		_check(absf(v.scale.x * 140.0 / 64.0 - 1.4) < 0.15, "joueur : ~1,4 u de haut")
		_check_emission_sync(v, "joueur")
		player.set("is_moving", true)
		player.set("facing", Vector2.DOWN)
		player.call("_update_visual", 0.5)
		# vérifié tout de suite : une frame physique pendant l'await remet is_moving à faux (aucune entrée en headless)
		_check(v.animation == &"run_s", "joueur : run_s en mouvement vers le bas (a %s)" % v.animation)
		await get_tree().process_frame
		_check_emission_sync(v, "joueur (run)")
	player.queue_free()

	# --- essaim -----------------------------------------------------------
	var a := EnemyVisual.new()
	var b := EnemyVisual.new()
	add_child(a)
	add_child(b)
	a.configure(1, 22.4, false)
	b.configure(1, 22.4, false)
	var sa := a.get_node("Sprite") as AnimatedSprite2D
	var sb := b.get_node("Sprite") as AnimatedSprite2D
	_check(sa.visible and sa.sprite_frames != null, "essaim : sprite visible")
	_check(sa.sprite_frames == sb.sprite_frames, "essaim : SpriteFrames partagés entre instances")
	_check(sa.animation == &"run_e", "essaim : run_e")
	a.set_facing(PI / 2.0)
	_check(sa.animation == &"run_s", "essaim : orientation s")
	a.set_facing(PI)
	_check(sa.animation == &"run_w", "essaim : orientation w")
	_check(sa.sprite_frames.get_frame_count("run_w") == 8, "essaim : 8 frames")
	_check(sa.sprite_frames.get_frame_count("attack_s") == 6 and sa.sprite_frames.get_frame_count("idle_s") == 4, "essaim v2 : attack_s 6 frames, idle_s 4")
	_check(sa.sprite_frames.get_frame_count("death_s") == 4 and not sa.sprite_frames.has_animation("death_se"), "essaim v2 : death 4 frames, 4 directions")
	_check(is_equal_approx(sa.scale.x, EnemyVisual.SPRITES[1]["scale"] * 1.0) and is_equal_approx(sa.offset.y, -20.0), "essaim v2 : échelle 1,0, offset_y -20")
	_check_v2_roles()
	_check_emission_sync(sa, "essaim")
	a.set_flash(true)
	_check(sa.modulate.r > 1.5 and sa.material is ShaderMaterial, "essaim : flash par shader")
	_check(sa.material == sb.material, "essaim : matériau de flash partagé")
	a.set_flash(false)
	_check(sa.modulate == Color.WHITE, "essaim : fin du flash")
	var ex := EnemyVisual.new()
	add_child(ex)
	ex.configure(4, 40.0, true)
	_check(not (ex.get_node("Sprite") as CanvasItem).visible, "boss : reste en placeholder")
	a.queue_free(); b.queue_free(); ex.queue_free()

	# --- coffres ----------------------------------------------------------
	for k in [&"petit", &"large", &"legendaire", &"boss"]:
		var c: Chest = load("res://scenes/chests/chest.tscn").instantiate()
		add_child(c)
		c.setup(k, 1)
		await get_tree().process_frame
		var cv := c.get_node("Visual") as AnimatedSprite2D
		_check(cv.animation == &"closed" and cv.sprite_frames.has_animation("open"), "coffre %s : closed" % k)
		var e := _emission(cv)
		if k == &"legendaire":
			_check_emission_sync(cv, "coffre légendaire")
		c.set("_opening", true)
		c._refresh_visual()
		_check(cv.animation == &"open", "coffre %s : open" % k)
		if e != null and e.visible:
			_check(e.animation == &"open", "coffre %s : émission open" % k)
		c.queue_free()

	# --- projectile -------------------------------------------------------
	var p: Area2D = load("res://scenes/spells/projectile.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	var pv := p.get_node("Billboard/Visual") as AnimatedSprite2D
	_check(pv.sprite_frames.get_frame_count("default") == 4, "projectile : 4 frames")
	_check(not pv.is_playing(), "projectile inactif : animation arrêtée")
	p.call("_set_active", true)
	_check(pv.is_playing(), "projectile actif : animation jouée")
	await get_tree().create_timer(0.2).timeout
	_check_emission_sync(pv, "projectile")
	p.queue_free()

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(_fails)


## Contrat de format v2 (art/briefs/monsters_v2.md §2) : frames par anim et géométrie par dossier.
func _check_v2_roles() -> void:
	var want := {
		"shooter_tier2": {"run_e": 8, "idle_s": 4, "attack_s": 8, "death_s": 4, "off": -44.0},
		"leaper_tier2": {"run_e": 8, "idle_s": 4, "charge_s": 6, "leap_s": 4, "attack_s": 6, "death_s": 4, "off": -34.0},
		"brute_tier3": {"run_e": 8, "idle_s": 4, "attack_s": 8, "cast_s": 8, "death_s": 6, "off": -56.0},
	}
	for folder: String in want:
		var f := load("res://assets/sprites/monsters/%s/%s.tres" % [folder, folder]) as SpriteFrames
		_check(f != null, folder + " : .tres chargé")
		if f == null:
			continue
		for anim: String in want[folder]:
			if anim == "off":
				continue
			_check(f.get_frame_count(anim) == int(want[folder][anim]), "%s : %s %d frames (a %d)" % [folder, anim, want[folder][anim], f.get_frame_count(anim)])
	var keys := {2: -44.0, EnemyVisual.LEAPER_KEY: -34.0, 3: -56.0, 1: -20.0}
	for k: int in keys:
		var cfg: Dictionary = EnemyVisual.monster_entry(k, &"terrasses")[1]
		_check(is_equal_approx(float(cfg["scale"]), 1.0) and is_equal_approx(float(cfg["offset_y"]), float(keys[k])) and not cfg.has("render_px_per_u"), "terrasses clé %d : géométrie v2" % k)
	# forêt et cité : v2 depuis les lots F/C, même géométrie que les terrasses
	for b in [&"foret", &"cite", &"cryptes", &"source"]:
		for k: int in keys:
			var cb: Dictionary = EnemyVisual.monster_entry(k, b)[1]
			_check(is_equal_approx(float(cb["scale"]), 1.0) and is_equal_approx(float(cb["offset_y"]), float(keys[k])) and not cb.has("render_px_per_u"), "%s clé %d : géométrie v2" % [b, k])
	# v2 jamais redirigé vers un doublon _cel (ancien format)
	var sf := EnemyVisual.monster_frames(1, &"terrasses")
	_check(sf != null and not sf.resource_path.contains("_cel"), "essaim v2 : pas de redirection _cel")
