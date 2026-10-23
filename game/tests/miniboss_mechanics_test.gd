extends Node
## Mécaniques de terrain des mini-boss (MiniHazards, MiniFx, MiniBossBrain, MiniPatterns, data/minibosses.json).
## godot --headless --path game res://tests/miniboss_mechanics_test.tscn  -> RESULT: OK
## Vérifie :
## 1. Rémouleur : disques (projectiles spéciaux) tirés, rebond sur un mur (vitesse renvoyée, compteur), fin de vie ;
## 2. Nuée aveugle : le cri qui touche brouille la minimap du HUD (Minimap.set_jammed), puis elle revient ;
## 3. eau : envol du Héron -> flaque d'eau (in_water, échasses plus vives), foudre (Events.lightning_struck)
##    -> joueur électrocuté dans la flaque, pas dehors ; Crapaud : +30 % reçus hors de l'eau ; Golem : se
##    dissout dans l'eau ; eau peu profonde de la carte (« , ») reconnue ; croûte de sel du Golem ;
## 4. obstacles réels : stalactites de l'Ours = blocs de glace (NavField, joueur bloqué, tirs du pool arrêtés,
##    couverture contre le souffle), rochers du Colosse (phase 2), tas d'os du Porte-ossuaire ; expiration ;
## 5. Archonte : anneau de chaînes à brèches (le joueur dans une brèche n'est pas touché, sur les chaînes oui) ;
## 6. statuts transmis par projectiles : brûlure (Seigneur), poison (Reine), gel (Ours) ;
## 7. louveteaux du Loup de brume : corps mist_wolf_cub (fauna.json summons) ;
## 8. lisibilité de nuit : corps éclaircis (body_gain) du Héron, du Loup et de la Chouette ;
## 9. poussées/attractions sûres : joueur collé à un mur fin ou au bord de la carte, poussée forte
##    (move_player) et vrais motifs (charge/onde du Colosse, bond de l'Ours, langue, aspiration, pince)
##    -> il reste sur une case praticable (il peut glisser le long du mur) sans jamais traverser un mur d'une image à l'autre.
## Sauvegarde de test seulement (jamais user://run_save.json).

const SAVE := "user://test_miniboss_mechanics.json"
const U := 64.0

var _main: Node
var _fails := 0
var _hits: Array = [] ## [frame, source]


func _ready() -> void:
	MiniBossBrain.reload()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load("res://scenes/stage/maps/terrasses_noyees.tscn"))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 91)
	add_child(_main)
	Events.player_damaged.connect(func(_a: float, s: Node) -> void: _hits.append([Engine.get_physics_frames(), s]))
	_main.game_ready.connect(_run)


func _p() -> Node2D:
	return _main.get(&"player")


func _d() -> Director:
	return _main.get(&"director")


func _frames(n: int) -> void:
	for i in n:
		var p := _p()
		p.hp = p.max_hp
		p.set(&"_invuln", 0.0)
		await get_tree().physics_frame


func _spawn(id: StringName, at: Vector2) -> MiniBossBrain:
	var d := _d()
	d.set_meta(&"next_mini_id", id)
	var b := d.spawn_boss(&"mini", d.nav.resolve(at, 70.0) if d.nav != null else at) as Enemy
	d.remove_meta(&"next_mini_id")
	var br := b.brain as MiniBossBrain
	br.ai_enabled = false
	b.max_hp = 1.0e6
	b.hp = 1.0e6
	return br


func _kill(b: MiniBossBrain) -> void:
	var e := b.e
	e.take_damage(e.hp * 10.0 + 10.0)
	await _frames(3)
	for m in get_tree().get_nodes_in_group(&"enemies").duplicate():
		if m is Enemy and not m.is_boss:
			_d().release_enemy(m)


## Lance le motif `id` ; le joueur reste au point visé pendant l'armement si `follow`.
func _cast(b: MiniBossBrain, id: StringName, follow := true, timeout := 8.0) -> void:
	b.force(id)
	var t := 0.0
	var seen := false
	while t < timeout:
		await _frames(1)
		t += get_physics_process_delta_time()
		if not b.cur.is_empty():
			seen = true
			if follow and b.state == MiniBossBrain.S.WIND:
				_p().global_position = b.harm_point()
		elif seen and not b.busy():
			return


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _run() -> void:
	await _frames(60)
	_d().spawning_enabled = false
	for m in get_tree().get_nodes_in_group(&"enemies").duplicate():
		if m is Enemy:
			_d().release_enemy(m)
	var anchor := _p().global_position
	await _grinder(anchor)
	await _swarm(anchor)
	await _water(anchor)
	await _obstacles(anchor)
	await _chains(anchor)
	await _statuses(anchor)
	await _cubs(anchor)
	await _push_safety(anchor)
	_legibility()
	_finish()


# --- 1. Rémouleur -----------------------------------------------------------------------------------

func _grinder(anchor: Vector2) -> void:
	print("— grinder : disques qui rebondissent")
	_p().global_position = anchor
	var b := _spawn(&"grinder", anchor + Vector2(3.0 * U, 0.0))
	await _frames(5)
	await _cast(b, &"discs")
	var h := b.hazards
	_check("disques tirés par MiniHazards (projectiles spéciaux)", h != null and (h.shot_count() > 0 or h.shots_hit > 0), "h=%s" % h)
	# rebond : un disque lancé droit sur un mur repart dans l'autre sens
	var nav := b.e.nav
	var start := anchor
	var dir := Vector2.ZERO
	for a in 16:
		var d := Vector2.from_angle(TAU * a / 16.0)
		for k in range(2, 24):
			if nav.is_blocked_at(anchor + d * k * 32.0):
				if dir == Vector2.ZERO or k * 32.0 < start.distance_to(anchor):
					dir = d
					start = anchor + d * (k - 1) * 32.0
				break
	_check("mur trouvé pour le rebond", dir != Vector2.ZERO)
	_p().global_position = anchor - dir * 20.0 * U # hors de portée
	var b0 := h.bounced
	h.fire(start - dir * 40.0, dir * 9.0 * U, 1.0, "", 1, 0.4, Color.WHITE)
	var s: Dictionary = h.shots[h.shots.size() - 1]
	await _frames(30)
	_check("rebond sur le mur (1)", h.bounced > b0, "rebonds=%d" % (h.bounced - b0))
	_check("vitesse renvoyée après le rebond", h.shots.has(s) and (s["vel"] as Vector2).dot(dir) < 0.0)
	await _frames(int(MiniHazards.SHOT_LIFE * 60.0) + 10)
	_check("disques détruits en fin de vie", h.shot_count() == 0, "restants=%d" % h.shot_count())
	var p2 := b._merged(b.pattern(&"discs"))
	b.phase = 2
	_check("phase 2 : rebonds ×2 (données)", int(b._merged(b.pattern(&"discs")).get("bounces", 0)) == 2 and int(p2.get("bounces", 0)) == 1)
	b.phase = 1
	_p().global_position = anchor
	await _kill(b)
	_check("MiniHazards libéré à la mort", not is_instance_valid(h) or h.is_queued_for_deletion())


# --- 2. Nuée aveugle -------------------------------------------------------------------------------

func _swarm(anchor: Vector2) -> void:
	print("— blind_swarm : cri qui brouille la minimap")
	_p().global_position = anchor
	var mm := get_tree().get_first_node_in_group(&"minimap") as Minimap
	_check("minimap du HUD dans le groupe « minimap »", mm != null)
	var b := _spawn(&"blind_swarm", anchor + Vector2(3.0 * U, 0.0))
	await _frames(5)
	await _cast(b, &"screech")
	_check("cri touché -> minimap brouillée", mm != null and mm.is_jammed() and b.jam_count == 1, "jam=%d" % b.jam_count)
	# _cast rend la main après la récupération immobile du mini (BossPace) : le brouillage a déjà coulé d'autant
	var jam_seen := (mm.jam_left + b.pace.last_recover) if mm else -1.0
	_check("brouillage ~3 s (données jam_s)", mm != null and jam_seen > 2.6 and mm.jam_left <= 3.0, "%.2f (+ récup. %.2f)" % [mm.jam_left if mm else -1.0, b.pace.last_recover])
	await _frames(200)
	_check("minimap revenue après 3 s", mm != null and not mm.is_jammed())
	await _kill(b)


# --- 3. Eau ----------------------------------------------------------------------------------------

func _water(anchor: Vector2) -> void:
	print("— eau : héron, crapaud, golem de sel, foudre")
	_p().global_position = anchor
	var b := _spawn(&"iron_heron", anchor + Vector2(3.0 * U, 0.0))
	await _frames(5)
	var dry_speed := b.move_speed_mult()
	await _cast(b, &"flight")
	var land := b.e.position
	_check("envol -> flaque d'eau au point de chute", b.in_water(land) and b.zone_count() >= 1)
	_check("échasses : plus vif dans l'eau", b.move_speed_mult() > dry_speed * 1.2, "%.2f -> %.2f" % [dry_speed, b.move_speed_mult()])
	var mf: MiniFx = null
	for n in b._fx:
		if n is MiniFx and (n as MiniFx).kind == MiniFx.Kind.WATER:
			mf = n
	_check("flaque dessinée (MiniFx WATER, sous les corps)", mf != null and mf.z_index < 0)
	# foudre : électrocute le joueur dans la flaque, pas dehors
	_p().global_position = anchor + Vector2(0.0, 9.0 * U)
	await _frames(2)
	b.ppos = _p().global_position
	var s0 := b.shocks
	Events.lightning_struck.emit(0.8, anchor)
	_check("foudre hors de l'eau : rien", b.shocks == s0)
	_check("flaque électrisée (lueur)", mf != null and mf.glow > 0.5)
	_p().global_position = land
	await _frames(2)
	b.ppos = land
	_hits.clear()
	Events.lightning_struck.emit(0.8, anchor)
	_check("foudre dans l'eau : joueur électrocuté", b.shocks == s0 + 1 and not _hits.is_empty())
	# eau peu profonde de la carte
	var wp := _map_shallow_point()
	_check("eau peu profonde de la carte reconnue (« , »)", wp != Vector2.INF and b.in_water(wp), str(wp))
	var dry_p := anchor + Vector2(0.0, 9.0 * U)
	_check("sol sec : pas d'eau", not b.in_water(dry_p) or b._map_shallow(dry_p))
	await _kill(b)
	# crapaud : peau glissante
	_p().global_position = anchor
	var t := _spawn(&"vat_toad", anchor + Vector2(3.0 * U, 0.0))
	await _frames(3)
	var dry := t.damage_taken_mult()
	t.add_zone({"shape": "circle", "pos": t.e.position, "r": 2.0 * U}, (t.pattern(&"mud_bubbles")["zone"] as Dictionary))
	var wet := t.damage_taken_mult()
	_check("crapaud : +30 %% reçus hors de l'eau (%.2f / %.2f)" % [dry, wet], absf(dry - 1.3) < 0.01 and absf(wet - 1.0) < 0.01)
	_p().global_position = t.e.position
	await _frames(20)
	_check("boue du crapaud : joueur ralenti", _p().call(&"is_slowed"))
	await _kill(t)
	# golem : se dissout dans l'eau ; croûte de sel
	_p().global_position = anchor
	var g := _spawn(&"salt_golem", anchor + Vector2(3.0 * U, 0.0))
	await _frames(3)
	var hp0 := g.e.hp
	await _frames(30)
	_check("golem au sec : ne fond pas", g.dissolved == 0.0 and not g.in_water(g.e.position))
	g.add_zone({"shape": "circle", "pos": g.e.position, "r": 2.0 * U}, {"water": true, "linger_s": 5.0, "slow_only": true})
	await _frames(60)
	_check("golem dans l'eau : se dissout (~2 % PV max / s)", g.dissolved > g.e.max_hp * 0.012 and g.e.hp < hp0, "%.0f" % g.dissolved)
	await _cast(g, &"salt_shards")
	var salt := false
	for n in g._fx:
		salt = salt or (n is MiniFx and (n as MiniFx).kind == MiniFx.Kind.SALT and is_instance_valid(n))
	_check("éclats de sel -> croûte de sel au sol", salt)
	await _kill(g)


func _map_shallow_point() -> Vector2:
	var sm := get_tree().get_first_node_in_group(&"stage_manager")
	var m: Node2D = sm.get(&"map")
	var g := AmbianceWater.grid_of(m)
	if g.is_empty():
		return Vector2.INF
	var grid: PackedStringArray = g["grid"]
	for y in grid.size():
		var x := grid[y].find(",")
		if x >= 0:
			var l := (g["origin"] as Vector2) + (Vector2(x, y) + Vector2(0.5, 0.5)) * float(g["cell_px"])
			return m.to_global(StageMap.frame_of(m) * l)
	return Vector2.INF


# --- 4. Obstacles ----------------------------------------------------------------------------------

func _obstacles(anchor: Vector2) -> void:
	print("— obstacles réels : glace, rochers, os")
	_p().global_position = anchor
	var b := _spawn(&"frost_bear", anchor + Vector2(4.0 * U, 0.0))
	await _frames(5)
	await _cast(b, &"stalactites")
	var h := b.hazards
	var n := int(b.pattern(&"stalactites").get("count", 6))
	_check("stalactites -> %d blocs de glace" % n, h != null and h.obstacle_count(&"ice") == n, "n=%d" % (h.obstacle_count(&"ice") if h else -1))
	var nav := b.e.nav
	var ob: Dictionary = h.obstacles[0]
	_check("bloc déclaré au NavField (monstres)", nav.has_method(&"has_obstacle") and nav.has_obstacle(ob["id"]))
	# le joueur est bloqué par le bloc
	var pl := _p() as CharacterBody2D
	var bp: Vector2 = ob["pos"]
	pl.global_position = bp + Vector2(-2.0 * U, 0.0)
	await _frames(2)
	var col := pl.move_and_collide(Vector2(4.0 * U, 0.0), true)
	_check("joueur bloqué par le bloc (StaticBody couche 1)", col != null and col.get_collider() is StaticBody2D)
	# tirs du pool arrêtés
	# (le pool s'arrête aussi de lui-même sur les cases bloquées du NavField, où le bloc est déclaré :
	# l'un ou l'autre peut l'arrêter en premier)
	var pool := h._pool()
	if pool:
		pool.clear_all()
	var a0 := pool.active_count() if pool else 0
	_d().fire_projectile(b.e, bp + Vector2(-1.5 * U, 0.0), Vector2(6.0 * U, 0.0), 1.0)
	var a1 := pool.active_count() if pool else 0
	await _frames(30)
	_check("projectile ennemi arrêté par le bloc", pool != null and a1 > a0 and pool.active_count() <= a0,
		"actifs %d -> %d -> %d" % [a0, a1, pool.active_count() if pool else -1])
	# couverture contre le souffle
	_check("couverture : segment coupé par le bloc", h.blocks_segment(bp + Vector2(-1.5 * U, 0.0), bp + Vector2(1.5 * U, 0.0)))
	b.e.position = nav.resolve(bp + Vector2(-2.5 * U, 0.0), b.e.radius_px)
	var behind := bp + Vector2(1.2 * U, 0.0)
	b.ppos = behind
	var bc := b._merged(b.pattern(&"breath"))
	_check("souffle : joueur derrière le bloc couvert", MiniPatterns.covered(b, bc) or not h.blocks_segment(b.e.position, behind))
	# ours plus fort près de sa glace
	b.e.position = nav.resolve(bp + Vector2(-1.2 * U, 0.0), b.e.radius_px)
	var near := b.damage_out_mult()
	_check("Fourrure : +20 %% près d'un bloc (%.2f)" % near, near >= 1.19)
	await _frames(int(4.2 * 60.0))
	_check("blocs fondus après 4 s (NavField nettoyé)", h.obstacle_count() == 0 and not nav.has_obstacle(ob["id"]))
	await _kill(b)
	# Colosse : rochers en phase 2
	_p().global_position = anchor
	var c := _spawn(&"stone_colossus", anchor + Vector2(3.0 * U, 0.0))
	await _frames(3)
	c.phase = 2
	await _cast(c, &"shockwave")
	_check("Colosse phase 2 : 3 rochers sur l'onde", c.hazards != null and c.hazards.obstacle_count(&"rock") == 3)
	await _kill(c)
	# Porte-ossuaire : tas d'os
	_p().global_position = anchor
	var o := _spawn(&"ossuary_bearer", anchor + Vector2(3.0 * U, 0.0))
	await _frames(3)
	await _cast(o, &"collapse")
	var oh := o.hazards
	_check("effondrement : 3 tas d'os", oh != null and oh.obstacle_count(&"bones") == 3)
	await _kill(o)
	_check("obstacles libérés à la mort", not is_instance_valid(oh) or oh.is_queued_for_deletion())


# --- 5. Chaînes de l'Archonte --------------------------------------------------------------------------

func _chains(anchor: Vector2) -> void:
	print("— rust_archon : anneau de chaînes à brèches")
	_p().global_position = anchor
	var b := _spawn(&"rust_archon", anchor + Vector2(4.0 * U, 0.0))
	await _frames(3)
	await _cast(b, &"chains")
	var z: Dictionary = {}
	for zz in b._zones:
		if zz.has("gaps"):
			z = zz
	_check("zone de chaînes à 2 brèches", not z.is_empty() and (z["gaps"] as Array).size() == 2)
	if z.is_empty():
		await _kill(b)
		return
	var c: Vector2 = z["pos"]
	var rm := (float(z["r"]) + float(z["inner"])) * 0.5
	var gap_p := c + Vector2.from_angle(float(z["gaps"][0])) * rm
	var chain_p := c + Vector2.from_angle(float(z["gaps"][0]) + PI * 0.5) * rm
	_check("brèche : on passe sans toucher les chaînes", not MiniPatterns.zone_contains(z, gap_p))
	_check("sur les chaînes : touché", MiniPatterns.zone_contains(z, chain_p))
	_check("brèche >= 2 u (largeur de passage)", float(z["gap_half"]) * 2.0 * rm >= 2.0 * U - 1.0, "%.0f px" % (float(z["gap_half"]) * 2.0 * rm))
	var drawn := false
	for n in b._fx:
		drawn = drawn or (n is MiniFx and (n as MiniFx).kind == MiniFx.Kind.CHAIN and (n as MiniFx).gaps.size() == 2)
	_check("chaînes dessinées avec leurs brèches", drawn)
	_p().global_position = gap_p
	_hits.clear()
	await _frames(40)
	var hit_gap := _hits.filter(func(h: Array) -> bool: return h[1] == b.e).size()
	_p().global_position = chain_p
	await _frames(40)
	var hit_chain := _hits.filter(func(h: Array) -> bool: return h[1] == b.e).size() - hit_gap
	_check("dans la brèche : aucun coup ; sur les chaînes : coups", hit_gap == 0 and hit_chain > 0, "brèche=%d chaînes=%d" % [hit_gap, hit_chain])
	await _kill(b)


# --- 6. Statuts par projectiles ------------------------------------------------------------------------

func _statuses(anchor: Vector2) -> void:
	print("— statuts transmis par les projectiles")
	for row in [[&"ash_lord", &"fireball", "burn"], [&"bramble_queen", &"thorns", "poison"], [&"frost_bear", &"frost_spit", "frost"]]:
		_p().global_position = anchor
		var pl := _p()
		await _frames(int(4.5 * 60.0)) # statuts précédents dissipés
		var b := _spawn(row[0], anchor + Vector2(4.0 * U, 0.0))
		await _frames(3)
		await _cast(b, row[1], false)
		var ok := false
		for i in 120:
			await _frames(1)
			match String(row[2]):
				"burn":
					ok = pl.call(&"is_burning")
				"poison":
					ok = int(pl.call(&"poison_stacks")) > 0
				"frost":
					ok = pl.call(&"is_slowed")
			if ok:
				break
		_check("%s.%s : statut %s transmis par le projectile" % row, ok and b.hazards != null and b.hazards.shots_hit > 0)
		await _kill(b)


# --- 7. Louveteaux ---------------------------------------------------------------------------------------

func _cubs(anchor: Vector2) -> void:
	print("— mist_wolf : louveteaux")
	_p().global_position = anchor
	var b := _spawn(&"mist_wolf", anchor + Vector2(3.0 * U, 0.0))
	await _frames(3)
	await _cast(b, &"howl")
	var want := EnemyVisual.summon_frames(&"mist_wolf_cub", &"foret")
	var n := 0
	var ok := 0
	for m in b._summons:
		if is_instance_valid(m) and m.active:
			n += 1
			var spr: AnimatedSprite2D = m.visual.body_sprite() if m.visual.has_method(&"body_sprite") else null
			if spr == null:
				spr = m.visual.get_node_or_null(^"Sprite") as AnimatedSprite2D
			if m.get_meta(&"summon_sprite", &"") == &"mist_wolf_cub" and spr != null and spr.visible and spr.sprite_frames != null and spr.sprite_frames.has_animation(&"run_s"):
				ok += 1
	_check("hurlement : louveteaux nés", n > 0, "n=%d" % n)
	_check("louveteaux avec le corps mist_wolf_cub", want == null or (ok == n and n > 0), "%d/%d (frames=%s)" % [ok, n, want])
	await _kill(b)



# --- 9. Poussées sûres --------------------------------------------------------------------------------

## Murs autour de `from` : [{free, dir, thin}] (free = dernier point libre avant le mur, thin = case libre
## à moins de 2,5 u derrière). Bord de carte compris (hors grille = mur).
func _walls_around(from: Vector2) -> Array:
	var nav := _d().nav
	var out: Array = []
	for k in 16:
		var dir := Vector2.from_angle(TAU * k / 16.0)
		var q := from
		var hit := false
		for i in 240:
			var nq := q + dir * 8.0
			if nav.is_wall_at(nq):
				hit = true
				break
			q = nq
		if not hit:
			continue
		var thin := false
		for j in range(2, 40):
			var r := q + dir * 8.0 * j
			if j * 8.0 > 2.5 * U:
				break
			if not nav.is_wall_at(r):
				thin = true
				break
		out.append({"free": q, "dir": dir, "thin": thin})
	return out


## Vrai si le segment a-b passe par une case de mur (pas de 6 px).
func _crosses_wall(a: Vector2, b: Vector2) -> bool:
	var nav := _d().nav
	var n := ceili(a.distance_to(b) / 6.0)
	for i in range(1, n + 1):
		if nav.is_wall_at(a.lerp(b, float(i) / n)):
			return true
	return false


func _push_safety(anchor: Vector2) -> void:
	print("— poussées sûres : mur fin, bord de carte")
	var nav := _d().nav
	var pl := _p() as CharacterBody2D
	var walls := _walls_around(anchor)
	var thin := walls.filter(func(w: Dictionary) -> bool: return w["thin"])
	_check("murs trouvés autour du point d'essai", walls.size() >= 4, "n=%d dont fins %d" % [walls.size(), thin.size()])
	# a) poussée forte brute (8 u) contre chaque mur
	var b := _spawn(&"stone_colossus", anchor)
	await _frames(3)
	var bad := 0
	var detail := ""
	for w: Dictionary in walls:
		var dir: Vector2 = w["dir"]
		var start := nav.resolve(w["free"] - dir * (MiniBossBrain.PLAYER_R + 4.0), MiniBossBrain.PLAYER_R)
		pl.global_position = start
		await _frames(1)
		var before := pl.global_position
		b.move_player(dir * 8.0 * U)
		await _frames(2)
		var now := pl.global_position
		if nav.is_blocked_at(now) or _crosses_wall(before, now):
			bad += 1
			detail += " %s%s->%s[bloq=%s trav=%s]" % ["fin " if w["thin"] else "", before.round(), now.round(),
				nav.is_blocked_at(now), _crosses_wall(before, now)]
	_check("poussée 8 u contre %d murs (%d fins) : joueur jamais dans un mur ni au travers (glisse le long)" % [walls.size(), thin.size()], bad == 0, detail)
	await _kill(b)
	# b) vrais motifs : le mini est du côté libre, le joueur dos au mur (poussée vers le mur) ;
	#    attraction : le mini derrière un mur fin (tirage à travers le mur)
	var cases := [[&"stone_colossus", &"charge"], [&"stone_colossus", &"shockwave"], [&"frost_bear", &"leap"],
		[&"sarcophagus_crab", &"snap"], [&"vat_toad", &"tongue"], [&"blind_pump", &"suction"]]
	for c: Array in cases:
		var pull: bool = c[1] in [&"tongue", &"suction"]
		var pool: Array = thin if (pull and not thin.is_empty()) else walls
		var w: Dictionary = pool[0] if thin.is_empty() or pull else thin[0]
		var dir: Vector2 = w["dir"]
		var ppos := nav.resolve(w["free"] - dir * (MiniBossBrain.PLAYER_R + 4.0), MiniBossBrain.PLAYER_R)
		var bpos: Vector2 = (w["free"] as Vector2) + dir * 2.5 * U if pull else ppos - dir * 3.0 * U
		var m := _spawn(c[0], bpos)
		m.e.position = nav.resolve(bpos, m.e.radius_px)
		pl.global_position = ppos
		await _frames(2)
		var crossed := 0
		var prev := pl.global_position
		m.force(c[1])
		var t := 0.0
		var seen := false
		while t < 8.0:
			await _frames(1)
			t += get_physics_process_delta_time()
			var now := pl.global_position
			if _crosses_wall(prev, now) or nav.is_blocked_at(now):
				crossed += 1
			prev = now
			if not m.cur.is_empty():
				seen = true
			elif seen and not m.busy():
				break
		_check("%s/%s contre un mur%s : jamais de traversée, case praticable" % [c[0], c[1], " fin" if w["thin"] else ""],
			seen and crossed == 0, "vu=%s traversées=%d pos=%s" % [seen, crossed, pl.global_position.round()])
		await _kill(m)

# --- 8. Lisibilité ---------------------------------------------------------------------------------------

func _legibility() -> void:
	for id: StringName in [&"iron_heron", &"mist_wolf", &"lantern_owl"]:
		var c := MiniBossBrain.config(id)
		_check("%s : corps éclairci pour la nuit (body_gain %.1f)" % [id, float(c.get("body_gain", 0.0))], float(c.get("body_gain", 0.0)) >= 1.8)


func _finish() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
