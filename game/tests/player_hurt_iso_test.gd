extends Node
## Diagnostic « le joueur perd-il des PV ? » sur la vraie carte iso terrasses_noyees (retour joueur :
## aucun dégât ressenti, ours mini-boss sans face au joueur), puis ressenti des coups reçus.
## godot --headless --path game res://tests/player_hurt_iso_test.tscn  -> RESULT: OK
## Phases : contact d'un essaim (tier 1) ; projectile ennemi ; tireur (tier 2) en ligne de vue ;
## mini-boss frost_bear placé au sud du joueur (doit tirer / frapper et se tourner vers le nord).
## Sauvegarde de test seulement (jamais user://run_save.json).

const MAP := "res://scenes/stage/maps/terrasses_noyees.tscn"
const SAVE := "user://test_player_hurt_iso.json"

var _main: Node
var _fails := 0
var _phase := -1
var _t := 0.0
var _hits: Array = [] ## {amount, source}
var _cur: Node2D = null
var _bear_hits := 0
var _bear_dirs: Dictionary = {} ## d4 vu pendant télégraphe / attaque -> nombre d'images
var _bear_attack_seen := false
var _feel_checked := false
var _big_feel := false ## gros coup de l'ours : hitstop global + secousse vus
var _proj_n := 0
var _bear_ev := 0 ## journal du cerveau du mini-boss déjà lu
var _sync_checked := 0
var _sync_bad := 0
var _pose_ok := false


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"map_scene", load(MAP))
	_main.set(&"save_path", SAVE)
	_main.set(&"run_seed", 11)
	add_child(_main)
	Events.player_damaged.connect(func(amount: float, source: Node) -> void:
		_hits.append({"amount": amount, "source": source}))
	_main.game_ready.connect(func() -> void: _phase = 0)


func _player() -> Node2D:
	return _main.get(&"player")


func _director() -> Director:
	return _main.get(&"director")


## Remet le joueur plein PV, sans protection ni statut (chaque phase part du même état).
func _reset_player() -> void:
	var p := _player()
	p.hp = p.max_hp
	p.set(&"_invuln", 0.0)
	p.clear_statuses()
	p.hp_changed.emit(p.hp, p.max_hp)


func _physics_process(delta: float) -> void:
	if _phase < 0:
		return
	var hud = _main.get(&"hud")
	if hud != null and hud.pause_menu.is_open:
		hud.pause_menu._close()
	_t += delta
	var d := _director()
	var p := _player()
	var ppos := p.global_position
	match _phase:
		0: # attente de la fin de la protection d'arrivée
			d.spawning_enabled = false
			if _t > 1.6:
				for e in d.get_tree().get_nodes_in_group(&"enemies").duplicate():
					if e is Enemy and not e.is_boss:
						d.release_enemy(e)
				_reset_player()
				_hits.clear()
				_cur = d.spawn_enemy(1, ppos + Vector2(40.0, 0.0), false, [] as Array[StringName], Enemy.VARIANT_SHOOTER)
				_tank(_cur)
				_next(1)
		1: # contact d'un essaim
			if _hit_from(_cur) or _t > 3.0:
				_check("contact tier 1 : PV perdus", _hit_from(_cur) and p.hp < p.max_hp,
					"hits=%d hp=%.1f/%.1f dist=%.1f" % [_hits.size(), p.hp, p.max_hp, _cur.position.distance_to(ppos)])
				_check_feel()
				d.release_enemy(_cur)
				_reset_player()
				_hits.clear()
				d.fire_projectile(d, ppos + Vector2(260.0, 0.0), Vector2(-6.0 * 64.0, 0.0), 12.0)
				_next(2)
		2: # projectile ennemi direct
			if not _hits.is_empty() or _t > 2.0:
				_check("projectile ennemi : PV perdus", not _hits.is_empty() and p.hp < p.max_hp,
					"hits=%d hp=%.1f" % [_hits.size(), p.hp])
				_reset_player()
				_hits.clear()
				_cur = d.spawn_enemy(2, ppos + Vector2(250.0, 0.0), false, [] as Array[StringName], Enemy.VARIANT_SHOOTER)
				_tank(_cur)
				_next(3)
		3: # tireur tier 2 (auto-tir en ligne de vue)
			if _hit_from(_cur) or _t > 6.0:
				var los := d.nav == null or d.nav.steer(_cur.position) == Vector2.ZERO
				if los:
					_check("tireur tier 2 : PV perdus", _hit_from(_cur), "hits=%d" % _hits.size())
				else:
					print("  (tireur hors ligne de vue : vérification sautée)")
				d.release_enemy(_cur)
				_reset_player()
				_hits.clear()
				var sm: StageManager = _main.get(&"stage")
				sm.floor_boss = &"eclusier" # carte forcée par la scène : biome des terrasses (Éclusier)
				EnemyVisual._mini_count = 0 # premier mini-boss du biome de l'Éclusier = frost_bear
				_cur = d.spawn_boss(&"mini", ppos + Vector2(0.0, 230.0)) # ours au sud : il doit regarder au nord
				_tank(_cur)
				_check("mini-boss = frost_bear", StringName(_cur.get(&"_boss_sprite_id")) == &"frost_bear",
					str(_cur.get(&"_boss_sprite_id")))
				_next(4)
		4: # mini-boss : coups reçus + orientation
			p.global_position = ppos # joueur immobile (aucune entrée en headless)
			for h in _hits:
				if h.source == _cur:
					_bear_hits += 1
					if h.amount >= 0.1 * p.max_hp and (p.get_script().hitstop_active() or Engine.time_scale < 1.0) 							and float(_main.get(&"_shake_left")) > 0.0:
						_big_feel = true
					print("  coup de l'ours : %.1f PV (%.0f %% des PV max)" % [h.amount, 100.0 * h.amount / p.max_hp])
			if not _hits.is_empty():
				_hits.clear()
				_reset_player()
			var vis: EnemyVisual = _cur.visual
			# tir auto synchronisé : le projectile naît à la frame d'impact de l'anim (fente au maximum)
			var pn := d.projectile_count()
			if pn > _proj_n and vis.is_attacking():
				_sync_checked += 1
				var lag := float(vis.get(&"_strike_t")) - float(vis.get(&"_strike_impact"))
				if lag < -0.001 or lag > 0.05:
					_sync_bad += 1
					print("  tir hors impact : décalage %.3f s" % lag)
			_proj_n = pn
			# crachat givrant (statut frost) : tiré par MiniHazards (hors pool du Director) -> journal du cerveau,
			# décalage du coup armé mesuré au moment de la salve (EnemyVisual.strike_lag)
			var evs: Array = _cur.brain.events if _cur.brain != null and _cur.brain.get(&"events") != null else []
			while _bear_ev < evs.size():
				var ev: Dictionary = evs[_bear_ev]
				_bear_ev += 1
				if ev.get("kind") == &"volley" and int(ev.get("spawned", 0)) > 0:
					_sync_checked += 1
					var vlag := float(ev.get("lag", 0.0))
					if vlag < -0.001 or vlag > 0.05:
						_sync_bad += 1
						print("  salve hors impact : décalage %.3f s" % vlag)
			if vis.is_attacking():
				var spr := vis.get(&"_sprite") as AnimatedSprite2D
				if spr != null and String(spr.animation) in ["attack_n", "run_n"]:
					_pose_ok = true # attack_n (lot R9a) ou, à défaut, posture orientée vers le nord
			if vis.has_method(&"facing_dir4") and vis.has_method(&"is_attacking") and vis.is_attacking():
				_bear_attack_seen = true
				var k: int = vis.facing_dir4()
				_bear_dirs[k] = int(_bear_dirs.get(k, 0)) + 1
			if _t > 9.0:
				_check("frost_bear : au moins 2 coups reçus", _bear_hits >= 2, "coups=%d" % _bear_hits)
				_check("gros coup (>= 10 % PV) : hitstop + secousse", _big_feel)
				_check("tir auto du boss à la frame d'impact", _sync_checked > 0 and _sync_bad == 0,
					"tirs=%d hors impact=%d" % [_sync_checked, _sync_bad])
				_check("frost_bear vers le nord : attack_n ou run_n (pas attack_s)", _pose_ok)
				_check("frost_bear : attaque visible (anim tenue)", _bear_attack_seen)
				var north := int(_bear_dirs.get(3, 0))
				var total := 0
				for v in _bear_dirs.values():
					total += int(v)
				_check("frost_bear : tourné vers le joueur (nord) en attaque", total > 0 and north * 10 >= total * 9,
					str(_bear_dirs))
				_finish()


## Les sorts automatiques d'Ardent fauchent un essaim en 1-2 coups : la cible du test ne doit pas mourir.
func _tank(e: Enemy) -> void:
	e.max_hp = 1.0e7
	e.hp = 1.0e7


func _hit_from(src: Node) -> bool:
	for h in _hits:
		if h.source == src:
			return true
	return false


## Ressenti du coup (flash rouge, chiffre, vignette) : vérifié une fois juste après le premier coup.
func _check_feel() -> void:
	if _feel_checked:
		return
	_feel_checked = true
	var p := _player()
	_check("flash rouge du joueur actif", p.hurt_flash_left() > 0.0)
	var vis := p.get_node(^"Visual") as CanvasItem
	_check("sprite du joueur teinté en rouge", vis.modulate.r > vis.modulate.g + 0.3, str(vis.modulate))
	var hf := p.get_node_or_null(^"HurtFeedback") as HurtFeedback
	_check("vignette rouge active", hf != null and hf.intensity() > 0.0)
	var dn: Node = _main.get(&"damage_numbers")
	var red := false
	if dn != null:
		var cols: Array = dn.get(&"_color")
		var act: PackedByteArray = dn.get(&"_active")
		for i in act.size():
			if act[i] == 1 and cols[i] == DamageNumbers.PLAYER_HURT_COLOR:
				red = true
	_check("chiffre de dégâts rouge au-dessus du joueur", red)
	var bar: Range = _main.get(&"hud").get(&"_hp_bar")
	var trail := bar.get_node_or_null(^"HpTrail") as HpTrail if bar != null else null
	_check("traîne blanche de la barre de vie", trail != null and trail.shown_value() > bar.value and trail.visible,
		"trail=%s bar=%s" % [trail.shown_value() if trail else -1.0, bar.value if bar else -1.0])


func _next(phase: int) -> void:
	_phase = phase
	_t = 0.0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	_phase = 99
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
