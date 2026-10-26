extends Node
## Barres de PV (contrat CONTRACTS.md « Barres de PV ») : encoches aux seuils réels (boss 70/35, Balance par
## défaut, mini-boss phase2.threshold, seuil propre d'un cerveau), rupture au franchissement, transition /
## invulnérable, barre retard qui rattrape, statuts brûlure / poison / gel visibles puis effacés (boss,
## mini-boss, élite, monstre de base), vrai nom du mini-boss.
## godot --headless --path game res://tests/hp_bars_test.tscn

var _fails := 0
var _main: Node


## Cerveau factice : seuils propres + transition / invulnérabilité forcées (le Director est suspendu pendant
## son usage : Enemy.tick ne l'appelle pas).
class StubBrain extends RefCounted:
	func phase_thresholds() -> Array:
		return [0.8, 0.5, 0.2]

	func is_phase_transition() -> bool:
		return true

	func is_invulnerable() -> bool:
		return true

	func clear() -> void:
		pass


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


static func _approx(a: PackedFloat32Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - float(b[i])) > 0.001:
			return false
	return true


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 4242)
	add_child(_main)
	await _main.game_ready
	await _frames(5)
	var hud: Hud = _main.hud
	var stage: StageManager = _main.stage
	var director: Director = _main.director
	var player: Node2D = _main.player
	player.grant_invulnerability(1.0e6)
	player.process_mode = Node.PROCESS_MODE_DISABLED # pas de sort automatique
	director.spawning_enabled = false
	director.despawn_all()
	var hb: EnemyHealthBars = _main.health_bars
	var bb: BossBars = hud.boss_bars
	var pp: Vector2 = player.global_position

	# --- Boss d'étage 70 / 35 (Semeur de pluie)
	stage.floor_boss = &"rain_sower"
	var boss := director.spawn_boss(&"etage", pp + Vector2(0, -420)) as Enemy
	await _frames(3)
	_check(_approx(boss.phase_thresholds(), [0.70, 0.35]), "Enemy.phase_thresholds() Semeur = %s" % boss.phase_thresholds())
	var bar := bb.bar_for(boss)
	_check(bar != null and _approx(bar.notch_fracs(), [0.70, 0.35]), "barre de boss : encoches 70 / 35 (%s)" % (bar.notch_fracs() if bar else "absente"))
	_check(bar != null and bar.broken_count() == 0, "aucune encoche brisée à pleins PV")
	await _wait(2.6) # entrée du Semeur (intouchable par ses coups, pas par les nôtres)
	# barre retard
	boss.take_damage(boss.max_hp * 0.12, true)
	await _frames(2)
	_check(bar.ghost_frac() > bar.fill_frac() + 0.1, "ghost maintenu après un gros coup (%.2f > %.2f)" % [bar.ghost_frac(), bar.fill_frac()])
	await _wait(0.25)
	_check(bar.ghost_frac() > bar.fill_frac() + 0.05, "ghost encore maintenu à 0,25 s (délai)")
	await _wait(0.6)
	_check(absf(bar.ghost_frac() - bar.fill_frac()) < 0.005, "ghost rattrapé en < 1 s (%.3f / %.3f)" % [bar.ghost_frac(), bar.fill_frac()])
	# rupture du premier seuil
	boss.hp = boss.max_hp * 0.72
	boss.take_damage(boss.max_hp * 0.04)
	await _frames(3)
	_check(bar.broken_count() == 1 and bar.phase_index() == 2, "seuil 70 %% franchi : 1 encoche brisée, phase 2 (%d)" % bar.broken_count())
	_check(bar.ghost_frac() <= bar.fill_frac() + 0.001, "rupture : ghost écrasé")
	var seen_tr := false
	for k in 30: # le cerveau passe en S.STAGGER à son prochain pas : la barre doit le montrer
		if boss.phase_transitioning() and bar.is_transition_shown():
			seen_tr = true
			break
		await _frames(1)
	_check(seen_tr, "transition de phase affichée (cerveau en S.STAGGER)")
	# statuts sur le boss
	boss.apply_status(&"burn", {"total": 1.0, "duration": 1.0})
	boss.apply_status(&"poison", {"total": 1.0, "duration": 1.0})
	boss.apply_status(&"slow", {"pct": 0.3, "duration": 1.0})
	await _frames(2)
	var ids := bar.status_ids()
	_check(ids.has(&"burn") and ids.has(&"poison") and ids.has(&"frost"), "boss : icônes brûlure / poison / gel %s" % [ids])
	await _wait(1.4)
	_check(bar.status_ids().is_empty(), "boss : statuts effacés à expiration %s" % [bar.status_ids()])
	boss.take_damage(boss.max_hp * 2.0)
	await _frames(3)

	# --- Boss par défaut (Balance.BOSS_PHASE_THRESHOLDS_DEFAULT) et seuils propres d'un cerveau
	stage.floor_boss = &"cerf"
	var cerf := director.spawn_boss(&"etage", pp + Vector2(0, -420)) as Enemy
	await _frames(3)
	var bar2 := bb.bar_for(cerf)
	var def: Array = Balance.BOSS_PHASE_THRESHOLDS.get(cerf.boss_id(), Balance.BOSS_PHASE_THRESHOLDS_DEFAULT)
	_check(bar2 != null and _approx(bar2.notch_fracs(), def), "boss « %s » : encoches %s = Balance %s" % [cerf.boss_id(), bar2.notch_fracs() if bar2 else "?", def])
	director.process_mode = Node.PROCESS_MODE_DISABLED
	var real_brain = cerf.brain
	cerf.brain = StubBrain.new()
	bar2.refresh_thresholds()
	await _frames(2)
	_check(_approx(bar2.notch_fracs(), [0.8, 0.5, 0.2]), "seuils propres du cerveau : %s" % bar2.notch_fracs())
	_check(bar2.is_transition_shown() and bar2.is_invulnerable_shown(), "cerveau : transition + invulnérable affichés")
	cerf.brain = real_brain
	bar2.refresh_thresholds()
	director.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(2)
	_check(not bar2.is_invulnerable_shown(), "invulnérable retiré avec le vrai cerveau")
	# Nom du boss d'étage : celui de son id (floors.json boss_names), pas celui de la carte.
	var cerf_name := str((FloorPlan.data().get("boss_names", {}) as Dictionary).get(String(cerf.boss_id()), ""))
	_check(not cerf_name.is_empty() and BossBars.boss_name(cerf, true, get_tree()) == cerf_name, "nom du boss d'étage par id : « %s »" % BossBars.boss_name(cerf, true, get_tree()))
	for f: Dictionary in FloorPlan.floors():
		for bid in f.get("floor_bosses", []):
			_check((FloorPlan.data().get("boss_names", {}) as Dictionary).has(bid), "floors.json boss_names : nom pour %s" % bid)
	cerf.take_damage(cerf.max_hp * 2.0)
	await _frames(3)

	# --- Mini-boss (combat du pilier) : vrai nom, seuil phase2.threshold, effets
	var mids := MiniBossBrain.ids()
	_check(not mids.is_empty(), "data/minibosses.json : %d mini-boss" % mids.size())
	if not mids.is_empty():
		var mid: StringName = mids[0]
		director.set_meta(&"next_mini_id", String(mid))
		var mini := director.spawn_boss(&"mini", pp + Vector2(380, 0)) as Enemy
		await _frames(3)
		var cfg := MiniBossBrain.config(mid)
		var want_name := str(cfg.get("name", ""))
		var th := float((cfg.get("phase2", {}) as Dictionary).get("threshold", Balance.MINI_BOSS_PHASE_THRESHOLD))
		_check(bb.names().has(want_name) and want_name != BossBars.MINI_NAME, "barre du mini-boss : vrai nom « %s » (%s)" % [want_name, bb.names()])
		var mb := bb.bar_for(mini)
		_check(mb != null and _approx(mb.notch_fracs(), [th]), "mini-boss : encoche au seuil %.2f (%s)" % [th, mb.notch_fracs() if mb else "?"])
		mini.take_damage(mini.max_hp * 0.15)
		await _frames(2)
		_check(mb.ghost_frac() > mb.fill_frac() + 0.1, "mini-boss : barre retard")
		_check(hb.bar_info(mini).get("kind", -1) == EnemyHealthBars.KIND_MINI, "mini-boss : barre riche au-dessus de la tête")
		mini.apply_status(&"burn", {"total": 1.0, "duration": 1.0})
		mini.apply_status(&"poison", {"total": 1.0, "duration": 1.0})
		mini.apply_status(&"slow", {"pct": 0.3, "duration": 1.0})
		await _frames(9) # masque relu une image sur 8
		var mi := mb.status_ids()
		var mask: int = hb.bar_info(mini).get("mask", 0)
		_check(mi.has(&"burn") and mi.has(&"poison") and mi.has(&"frost"), "mini-boss : icônes de statut %s" % [mi])
		_check(mask & (Enemy.ST_BURN | Enemy.ST_POISON | Enemy.ST_FROST) == (Enemy.ST_BURN | Enemy.ST_POISON | Enemy.ST_FROST), "mini-boss : statuts sur la barre de monde (%d)" % mask)
		mini.hp = mini.max_hp * (th + 0.02)
		mini.take_damage(mini.max_hp * 0.05)
		await _frames(3)
		_check(mb.broken_count() == 1, "mini-boss : rupture au seuil de phase")
		await _wait(1.4)
		_check(mb.status_ids().is_empty(), "mini-boss : statuts effacés")
		mini.take_damage(mini.max_hp * 2.0)
		await _frames(3)
		director.remove_meta(&"next_mini_id")
		_check(bb.count() == 0, "barres de boss retirées")

	# --- Monstres : élite (riche) et base (pips)
	var e1 := director.spawn_enemy(1, pp + Vector2(300, 0))
	var el := director.spawn_enemy(2, pp + Vector2(-300, 0), true)
	await _frames(2)
	e1.take_damage(e1.max_hp * 0.3)
	el.take_damage(el.max_hp * 0.3)
	await _frames(1)
	var i1 := hb.bar_info(e1)
	_check(not i1.is_empty() and float(i1["ghost"]) > float(i1["frac"]) + 0.2, "monstre : barre retard au coup")
	_check(float(i1.get("flash", 0.0)) > 0.0 or Quality.flashes_level == 0, "monstre : flash au coup direct")
	_check(hb.bar_info(el).get("kind", -1) == EnemyHealthBars.KIND_ELITE, "élite : barre riche")
	e1.apply_status(&"burn", {"total": 0.5, "duration": 2.5})
	e1.apply_status(&"poison", {"total": 0.5, "duration": 2.5})
	e1.apply_status(&"slow", {"pct": 0.3, "duration": 2.5})
	el.apply_status(&"slow", {"pct": 0.3, "duration": 2.5})
	await _frames(9) # masque relu une image sur 8
	var m1: int = hb.bar_info(e1).get("mask", 0)
	_check(m1 & Enemy.ST_BURN and m1 & Enemy.ST_POISON and m1 & Enemy.ST_FROST, "monstre : pips brûlure / poison / gel (%d)" % m1)
	_check(int(hb.bar_info(el).get("mask", 0)) & Enemy.ST_FROST, "élite : gel affiché")
	# Lot A11y-L1 : pictogramme du statut dominant (gel) à côté de la barre d'un monstre de base, hors couleur
	var vp := get_viewport()
	if vp.get_visible_rect().grow(-40.0).has_point(vp.get_canvas_transform() * e1.global_position):
		var pids: Array = []
		for d in hb.picto_list():
			pids.append(d["id"])
		_check(&"frost" in pids, "monstre : pictogramme du statut dominant (gel) dessiné %s" % [pids])
	_check(StatusPictos.atlas().get_width() == StatusPictos.CELL * StatusPictos.IDS.size(), "atlas de pictogrammes : 5 cases de 16 px, un seul")
	CvdPalette.override_mode = 0
	var tint_n := hb.tint_for_mask(Enemy.ST_POISON)
	CvdPalette.override_mode = CvdPalette.DEUTAN
	var tint_d := hb.tint_for_mask(Enemy.ST_POISON)
	CvdPalette.override_mode = -1
	_check(tint_n.is_equal_approx(tint_d) == false, "mode daltonien : la teinte du poison change (%s -> %s)" % [tint_n, tint_d])
	hb.tint_for_mask(0) # reconstruit au mode réel
	var dot_seen := false
	for k in 30:
		await _wait(0.05)
		if int(hb.bar_info(e1).get("dot", 0)) != 0:
			dot_seen = true
			break
	_check(dot_seen, "monstre : tick de DoT reconnu (ghost teinté, sans flash)")
	await _wait(0.6)
	_check(absf(float(hb.bar_info(e1).get("ghost", 0.0)) - float(hb.bar_info(e1).get("frac", 1.0))) < 0.01, "monstre : ghost rattrapé")
	for k in 80: # statuts de 2,5 s : sondage, robuste à une machine chargée
		if int(hb.bar_info(e1).get("mask", 1)) == 0 and int(hb.bar_info(el).get("mask", 1)) == 0:
			break
		await _wait(0.05)
	var info_end := hb.bar_info(e1)
	_check(not info_end.is_empty() and int(info_end["mask"]) == 0, "monstre : statuts effacés, barre encore là (%s)" % [info_end])
	_check(int(hb.bar_info(el).get("mask", 1)) == 0, "élite : gel effacé")
	await _wait(3.4)
	_check(hb.visible_count() == 0, "barres masquées 3 s après le dernier coup")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
