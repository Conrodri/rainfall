extends Node
## Bug joueur (22/10/2026) : « j'ai tué un monstre, une pièce tombe, je la ramasse, le compteur d'or ne bouge pas ».
## Cause : la prime d'un petit monstre vaut 0,47 or à coeff 1 ; elle tombait en UNE pièce de 0,47 et le HUD
## affiche l'or en entier (%d) -> « 0 ». Correctif : PickupManager.drop_bounty ne crédite / montre que des ors
## entiers (fraction reportée). Puis décision du joueur : or et XP crédités AUTOMATIQUEMENT à la mort (portée
## infinie), les pièces ne sont qu'un effet visuel ; les ressources de kit (GroundPickup) restent manuelles.
## Parcours réel, pour Ardent ET Avare : vrai joueur, vrai Director, vrai monstre tué (près ou très loin) ->
## RunState.gold +1 au moins dès qu'une pièce apparaît ET le label du HUD affiche la nouvelle valeur.
## godot --headless --path game res://tests/gold_pickup_test.tscn

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", label, (" (" + detail + ")") if detail != "" else "")
	else:
		print("  ok  ", label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ground_gold(pm: PickupManager) -> Array:
	var out: Array = []
	for i in PickupManager.MAX_PICKUPS:
		if pm._alive[i] == 1 and pm._kind[i] == PickupManager.KIND_GOLD:
			out.append(pm._val[i])
	return out


func _run() -> void:
	for ch in [&"ardent", &"avare"]:
		await _scenario(ch)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _scenario(ch: StringName) -> void:
	print("Personnage : ", ch)
	RunState.start_run(&"moyen", 1234)
	RunState.character = ch
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	var pm := PickupManager.new()
	get_tree().root.add_child(pm)
	var player: CharacterBody2D = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(player)
	var hud: Node = load("res://scripts/ui/hud.gd").new()
	get_tree().root.add_child(hud)
	await _frames(3)
	player.set_physics_process(false) # immobile
	_check("joueur %s" % ch, player.get("character") != null and String(player.character.id) == String(ch), str(player.get("character")))

	var D := RunState.difficulty()
	var bounty := Balance.monster_gold(D, Balance.monster_cost(1, false))
	_check("prime d'un petit monstre < 1 or (cas du bug)", bounty < 1.0, str(bounty))

	var label: Label = hud._gold_label
	var coins_seen := 0
	var kills := 0
	var gained_total := 0.0
	var owed := 0.0 # somme des primes au coeff de chaque mort (D monte avec le temps)
	for k in 8:
		var gold_before := RunState.gold
		var xp_before := RunState.xp + 1000.0 * RunState.level
		var text_before := label.text
		var off := Vector2(90, 0) if k % 2 == 0 else Vector2(4000, -3000) # près, puis hors écran : portée infinie
		var e: Enemy = director.spawn_enemy(1, player.global_position + off)
		await get_tree().physics_frame
		owed += Balance.monster_gold(RunState.difficulty(), Balance.monster_cost(1, false))
		e.take_damage(1.0e9)
		kills += 1
		_check("XP créditée à la mort (kill %d)" % kills, RunState.xp + 1000.0 * RunState.level > xp_before)
		var drops := _ground_gold(pm)
		var gained := RunState.gold - gold_before
		gained_total += gained
		if drops.is_empty():
			_check("pas de pièce = pas d'or entier (fraction reportée)", gained == 0.0, str(gained))
			continue
		coins_seen += 1
		for v in drops:
			_check("pièce >= 1 or (jamais une pièce que le compteur ignore)", float(v) >= 1.0 - 0.0001, str(v))
		_check("or crédité dès la mort, sans ramassage : +%s (kill %d)" % [gained, kills], gained >= 1.0 - 0.0001)
		_check("label HUD = or (%s)" % label.text, label.text == "%d" % int(RunState.gold), "%s vs %s" % [label.text, RunState.gold])
		_check("label HUD a changé (%s -> %s)" % [text_before, label.text], label.text != text_before)
		for i in 240:
			await get_tree().process_frame
			if pm.active_count == 0:
				break
		_check("effet visuel : pièces et orbes arrivés au joueur (kill %d)" % kills, pm.active_count == 0, str(pm.active_count))
		_check("aucun or en plus à l'arrivée des pièces", absf(RunState.gold - gold_before - gained) < 0.0001)
	_check("au moins 3 pièces en 8 kills", coins_seen >= 3, str(coins_seen))
	var total := gained_total + pm.gold_carry
	_check("somme des primes conservée", absf(total - owed) < 0.01, "%s vs %s" % [total, owed])

	# Ressource de joueur (GroundPickup) : jamais ramassée à distance, seulement au contact.
	var got := [0]
	var res := GroundPickup.spawn(player.get_parent(), player.global_position + Vector2(400, 0), player,
			func(_g: GroundPickup) -> void: got[0] += 1, 30.0)
	_check("GroundPickup = ressource de joueur", GroundPickup.PLAYER_RESOURCE)
	await _frames(30)
	_check("ressource de kit loin : pas ramassée", got[0] == 0 and is_instance_valid(res))
	res.global_position = player.global_position # le joueur passe dessus
	res.step(0.01)
	_check("ressource de kit au contact : ramassée", got[0] == 1)

	# Le compteur reste visible : dans l'écran, à gauche du bouton pause, non masqué.
	await _frames(2)
	var box: Control = hud._gold_box
	var vp := hud.get_viewport().get_visible_rect()
	var r := box.get_global_rect()
	_check("rangée d'or visible", box.is_visible_in_tree() and label.is_visible_in_tree())
	_check("rangée d'or dans l'écran", vp.encloses(r), "%s dans %s" % [r, vp])
	_check("rangée d'or à gauche du bouton pause", r.end.x <= hud.pause_button.get_global_rect().position.x + 0.5,
			"%s / %s" % [r, hud.pause_button.get_global_rect()])
	RunState.add_gold(1234.0) # nombre plus long : la rangée reste calée et visible
	await _frames(1)
	r = box.get_global_rect()
	_check("label mis à jour (grand nombre)", label.text == "%d" % int(RunState.gold), label.text)
	_check("grand nombre : toujours dans l'écran", vp.encloses(r), str(r))
	_check("grand nombre : label pas tronqué", label.size.x + 0.5 >= label.get_minimum_size().x, "%s / %s" % [label.size, label.get_minimum_size()])

	hud.queue_free()
	player.queue_free()
	pm.queue_free()
	director.queue_free()
	await _frames(3)
