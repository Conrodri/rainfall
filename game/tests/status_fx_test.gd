extends Node
## Visuels d'état sur les monstres (StatusFx, docs/Design_Etats_Visuels.md).
## godot --headless --path game res://tests/status_fx_test.tscn (avec ou sans --fixed-fps 60 : attentes en temps de jeu)
## 1. Chaque état est visible quand il est actif (poison -> bulles, brûlure -> flammèches + cendres, trempé -> gouttes
##    + corps assombri, coup électrique -> arcs, étourdi -> étoiles) et retiré à la fin (suivi relâché, teinte rendue).
## 2. Le flash de coup se compose avec la teinte mouillée (blanc pendant le flash, sombre après).
## 3. Plafonds : 250 monstres tous affectés -> émetteurs par état et particules par sorte sous les plafonds du palier ;
##    Bas réduit ; hors écran = rien ; aucun nœud créé pendant le jeu ; rien ne tourne sans état.
## 4. Banc : coût de StatusFx par image (médiane) et temps d'image avec / sans visuels d'état (250 monstres affectés).

const N := 250
const BENCH_FRAMES := 240
const BUDGET_MS := 0.6 ## médiane du coût de StatusFx (Haut, 250 monstres tous affectés) sur PC de dev

var _director: Node2D
var _player: Node2D
var _cam: Camera2D
var _fails := 0


func _ready() -> void:
	RunState.active_time_s = 400.0
	_player = load("res://tests/enemies_fake_player.gd").new()
	add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	add_child(_director)
	_cam = Camera2D.new()
	_cam.zoom = Iso.camera_zoom()
	add_child(_cam)
	_cam.make_current()
	_run.call_deferred()


func _fx() -> StatusFx:
	return StatusFx.instance()


## Attend n images ET au moins n/60 s de temps de jeu : le test lit des durées (vie des particules, états,
## relecture toutes les 50-100 ms). Sans --fixed-fps, le temps réel d'une image headless (quelques ms) remplace le 1/60 s et
## compter des images ne mesurait plus le temps (gouttes et arcs pas encore émis, particules encore vivantes).
func _frames(n: int) -> void:
	var t := 0.0
	var want := float(n) / 60.0 - 0.0001
	var i := 0
	while i < n or t < want:
		await get_tree().process_frame
		t += get_process_delta_time()
		i += 1


func _run() -> void:
	Quality.tier = Quality.Tier.HIGH
	await get_tree().physics_frame
	await _frames(2)
	var fx := _fx()
	_check("instance StatusFx créée avec le pool", fx != null)
	if fx == null:
		_finish()
		return
	for k in StatusFx.KIND_COUNT:
		_check("sorte %s : texture (lot Codex ou repli)" % StatusFx.KIND_FILES[k][0], fx.has_texture(k))
	await _single_states(fx)
	await _caps(fx)
	await _bench(fx)
	_finish()


func _spawn_one(tier: int, pos: Vector2) -> Enemy:
	_director.spawn_enemy(tier, pos, false)
	var e: Enemy = _director._active[_director._active.size() - 1]
	e.test_dummy = true # immobile, ne meurt pas (les DoT n'emportent pas le test)
	return e


func _single_states(fx: StatusFx) -> void:
	_cam.global_position = Vector2.ZERO
	var e := _spawn_one(3, Vector2(40.0, 30.0))
	await _frames(3)
	_check("aucun suivi ni traitement sans état", fx.tracked_count() == 0 and not fx.is_processing() and fx.live_count() == 0)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# poison -> bulles
	e.apply_status(&"poison", {"total": 1.0, "duration": 1.0})
	await _frames(20)
	_check("poison : monstre suivi, bulles vivantes (%d)" % fx.kind_live(StatusFx.Kind.BUBBLE), fx.is_tracked(e) and fx.kind_live(StatusFx.Kind.BUBBLE) > 0)
	_check("poison : ni flammèche ni goutte", fx.kind_live(StatusFx.Kind.FLAME) == 0 and fx.kind_live(StatusFx.Kind.DROP) == 0)
	await _wait_untracked(fx, e, 3.0)
	_check("poison fini : suivi relâché", not fx.is_tracked(e))

	# brûlure -> flammèches + cendres/braises
	e.apply_status(&"burn", {"total": 1.0, "duration": 1.0})
	await _frames(40)
	_check("brûlure : flammèches (%d) et cendres/braises (%d)" % [fx.kind_live(StatusFx.Kind.FLAME), fx.kind_live(StatusFx.Kind.ASH) + fx.kind_live(StatusFx.Kind.EMBER)],
		fx.kind_live(StatusFx.Kind.FLAME) > 0 and fx.kind_live(StatusFx.Kind.ASH) + fx.kind_live(StatusFx.Kind.EMBER) > 0)
	await _wait_untracked(fx, e, 3.0)
	_check("brûlure finie : suivi relâché", not fx.is_tracked(e))

	# trempé -> gouttes + teinte ; composition avec le flash
	var vis := e.visual as EnemyVisual
	var spr := vis.get_node_or_null(^"Sprite") as AnimatedSprite2D
	var base := spr.self_modulate if spr != null else Color.WHITE
	e.apply_status(&"slow", {"pct": 0.3, "duration": 1.0})
	StatusFx.wet(e, 1.0)
	await _frames(20)
	_check("trempé : gouttes (%d)" % fx.kind_live(StatusFx.Kind.DROP), fx.kind_live(StatusFx.Kind.DROP) > 0)
	if spr != null:
		var dark := spr.self_modulate
		_check("trempé : corps assombri (r %.2f), pas noir" % dark.r, vis.is_wet() and dark.r < base.r * 0.8 and dark.r > 0.3)
		vis.set_flash(true)
		_check("flash pendant la trempe : teinte levée (drapeau de flash intact)", spr.self_modulate == base)
		vis.set_flash(false)
		_check("après le flash : de nouveau assombri", spr.self_modulate == dark)
	else:
		_check("trempé : sprite du monstre présent", false)
	await _wait_untracked(fx, e, 3.0)
	_check("trempe finie : suivi relâché, teinte rendue", not fx.is_tracked(e) and not vis.is_wet() and (spr == null or spr.self_modulate == base))

	# coup électrique -> arcs brefs
	e.take_damage(1.0, false, &"lightning")
	await _frames(6)
	_check("électrique : arcs (%d)" % fx.kind_live(StatusFx.Kind.ARC), fx.kind_live(StatusFx.Kind.ARC) > 0)
	await _frames(60)
	_check("électrique : plus d'arc après ~1 s", fx.kind_live(StatusFx.Kind.ARC) == 0 and not fx.is_tracked(e))

	# étourdi -> étoiles (le monstre de test est figé par test_dummy : on le libère le temps de l'étourdissement)
	e.test_dummy = false
	e.hp = e.max_hp * 100.0
	e.stun(0.8)
	await _frames(8)
	_check("étourdi : couronne d'étoiles (%d)" % fx.kind_live(StatusFx.Kind.STAR), fx.kind_live(StatusFx.Kind.STAR) >= 3)
	await _wait_untracked(fx, e, 3.0)
	_check("étourdissement fini : suivi relâché", not fx.is_tracked(e))
	await _frames(70)
	_check("tout fini : aucune particule, traitement éteint", fx.live_count() == 0 and not fx.is_processing())
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("aucun nœud créé par les états (%d -> %d)" % [nodes0, nodes1], nodes0 == nodes1)

	# boss : particules plus nombreuses (corps plus grand), même cycle de vie
	var boss := _director.spawn_boss(&"mini", Vector2(-120.0, 40.0)) as Enemy
	if boss != null:
		await _frames(2)
		boss.apply_status(&"poison", {"total": 1.0, "duration": 1.5})
		StatusFx.wet(boss, 1.5)
		await _frames(40)
		_check("boss : bulles (%d) et gouttes (%d) sur le corps" % [fx.kind_live(StatusFx.Kind.BUBBLE), fx.kind_live(StatusFx.Kind.DROP)],
			fx.is_tracked(boss) and fx.kind_live(StatusFx.Kind.BUBBLE) > 0 and fx.kind_live(StatusFx.Kind.DROP) > 0)
		boss.stun(1.0)
		await _frames(5)
		_check("boss : insensible à l'étourdissement, aucune étoile", fx.kind_live(StatusFx.Kind.STAR) == 0)
		_director.release_enemy(boss)
		_check("boss rendu au pool : oublié", not fx.is_tracked(boss))
		await _frames(80)
	else:
		_check("mini-boss invoqué", false)

	# rendu au pool en plein état : oublié tout de suite, teinte rendue
	e.test_dummy = true
	StatusFx.wet(e, 5.0)
	e.apply_status(&"poison", {"total": 1.0, "duration": 5.0})
	await _frames(10)
	_director.release_enemy(e)
	_check("monstre rendu au pool : oublié, teinte rendue", not fx.is_tracked(e) and not vis.is_wet())
	await _frames(70)


func _wait_untracked(fx: StatusFx, e: Enemy, max_s: float) -> void:
	var t := 0.0
	while fx.is_tracked(e) and t < max_s:
		await get_tree().process_frame
		t += get_process_delta_time()


## 250 monstres, tous les états : plafonds par palier, hors écran.
func _affect_all(seconds: float) -> void:
	for e: Enemy in _director._active:
		e.apply_status(&"poison", {"total": 1.0, "duration": seconds})
		e.apply_status(&"burn", {"total": 1.0, "duration": seconds})
		StatusFx.wet(e, seconds)
		StatusFx.shock(e, seconds)


func _place_all(rng: RandomNumberGenerator) -> void:
	_director.despawn_all()
	var placed := 0
	while placed < N:
		var tier := 1
		var r := rng.randf()
		if r < 0.10:
			tier = 3
		elif r < 0.32:
			tier = 2
		_director.spawn_enemy(tier, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(60.0, 1500.0), rng.randf() < 0.12)
		placed += 1
	for e: Enemy in _director._active:
		e.test_dummy = true


func _caps(fx: StatusFx) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_place_all(rng)
	await _frames(3)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var res := {}
	for tier in [Quality.Tier.HIGH, Quality.Tier.MEDIUM, Quality.Tier.LOW]:
		Quality.tier = tier
		_affect_all(30.0)
		fx.refresh_now()
		await _frames(95) # les particules du palier précédent (vie <= 1,4 s) s'éteignent
		var max_em := PackedInt32Array([0, 0, 0, 0, 0])
		var max_kind := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
		var max_live := 0
		var ok_caps := true
		var t_s := 0.0
		var f := 0
		while f < 90 or t_s < 1.5: # 1,5 s de jeu échantillonnées, quel que soit le débit d'images
			await get_tree().process_frame
			t_s += get_process_delta_time()
			f += 1
			for s in StatusFx.ST_COUNT:
				max_em[s] = maxi(max_em[s], fx.emitter_count(s))
				ok_caps = ok_caps and fx.emitter_count(s) <= StatusFx.EMITTERS[tier]
			for k in StatusFx.KIND_COUNT:
				max_kind[k] = maxi(max_kind[k], fx.kind_live(k))
				ok_caps = ok_caps and fx.kind_live(k) <= fx.kind_cap(k)
			max_live = maxi(max_live, fx.live_count())
		print("  palier %s : suivis %d, émetteurs/état %s (plafond %d), particules/sorte %s, total max %d" % [
			Quality.tier_name(tier), fx.tracked_count(), max_em, StatusFx.EMITTERS[tier], max_kind, max_live])
		_check("palier %s : 250 suivis" % Quality.tier_name(tier), fx.tracked_count() == N)
		_check("palier %s : émetteurs et particules sous les plafonds" % Quality.tier_name(tier), ok_caps)
		res[tier] = max_live
	_check("Bas réduit (%d particules au plus, Haut %d)" % [res[Quality.Tier.LOW], res[Quality.Tier.HIGH]],
		res[Quality.Tier.LOW] * 3 < res[Quality.Tier.HIGH] and res[Quality.Tier.LOW] > 0)
	Quality.tier = Quality.Tier.HIGH

	# hors écran : caméra loin de tous les monstres -> aucun émetteur
	_cam.global_position = Vector2(20000.0, 20000.0)
	fx.refresh_now()
	await _frames(4)
	var em := 0
	for s in StatusFx.ST_COUNT:
		em += fx.emitter_count(s)
	_check("hors écran : aucun émetteur (%d)" % em, em == 0)
	await _frames(95)
	_check("hors écran : plus aucune particule (%d)" % fx.live_count(), fx.live_count() == 0)
	_cam.global_position = Vector2.ZERO
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("aucun nœud créé à 250 monstres affectés (%d -> %d)" % [nodes0, nodes1], nodes0 == nodes1)


func _bench(fx: StatusFx) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_place_all(rng)
	await _frames(3)
	# avant : mêmes états de jeu, visuels coupés ; après : visuels actifs (Haut)
	StatusFx.enabled = false
	_affect_all(60.0)
	var before := await _measure(fx, false)
	StatusFx.enabled = true
	_affect_all(60.0)
	fx.refresh_now()
	var after := await _measure(fx, true)
	print("== Banc 250 monstres (poison + brûlure + trempé + électrique), palier Haut, headless")
	print("  sans visuels d'état : image médiane %.3f ms" % before[0])
	print("  avec visuels d'état : image médiane %.3f ms, StatusFx médiane %.3f ms, p90 %.3f ms, max %d particules" % [after[0], after[1], after[2], after[3]])
	_check("coût StatusFx médian %.3f ms < %.2f ms" % [after[1], BUDGET_MS], after[1] < BUDGET_MS)
	_director.despawn_all()
	await _frames(80)
	_check("tout rendu au pool : plus rien de suivi ni traité", fx.tracked_count() == 0 and not fx.is_processing())


func _measure(fx: StatusFx, with_fx: bool) -> Array:
	var frames := PackedInt64Array()
	var fxs := PackedInt64Array()
	var max_live := 0
	var last := Time.get_ticks_usec()
	for f in 30 + BENCH_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if f >= 30:
			frames.append(now - last)
			fxs.append(StatusFx.stat_usec if with_fx and fx.is_processing() else 0)
			max_live = maxi(max_live, fx.live_count())
		last = now
	frames.sort()
	fxs.sort()
	return [frames[frames.size() / 2] / 1000.0, fxs[fxs.size() / 2] / 1000.0, fxs[fxs.size() * 9 / 10] / 1000.0, max_live]


func _finish() -> void:
	Quality.tier = Quality.Tier.HIGH
	StatusFx.enabled = true
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
