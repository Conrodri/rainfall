extends Node
## Test headless de Grésille (docs/fiches/gresille.md) : stats, Statique (cumuls, expiration, crispé, Foudroiement,
## immunité, boss), Arc et rebond (mouillé +2 u), Décharge (cible la plus chargée, +0,15 n, n arcs, mouillé +2 u),
## Mise à la terre (disque sec, nappe d'eau connexe plafonnée à 113 cases), Orage (6 coups, cible la plus chargée,
## sort 1 libre, 70 %, interruption par l'esquive), Isolée, Enemy.is_wet, compteur de déblocage de la run.
## godot --headless res://tests/gresille_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var wet := false
	var is_boss := false
	var is_elite := false
	var active := true
	var radius_px := 20.0
	var stunned := 0.0
	var mods: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func is_wet() -> bool:
		return wet

	func mark_wet(_seconds: float) -> void:
		wet = true

	func stun(seconds: float) -> void:
		stunned += seconds

	func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
		mods.append([id, mult, duration])

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func slowed_20() -> bool:
		for s in statuses:
			if s[0] == &"slow" and is_equal_approx(float(s[1]["pct"]), 0.2):
				return true
		return false


class FakeBrain extends RefCounted:
	var _zones: Array = []


class FakeSource extends Node2D:
	var brain: Object = null


const ZONE := preload("res://scripts/spells/zone_effect.gd")
const U := 64.0
const BASE := 12.0

var _fails := 0
var _player: CharacterBody2D
var _kit: GresilleKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _advance(t: float) -> void:
	var n := roundi(t / 0.01)
	for i in n:
		_player.spells._remaining[1] = 99.0 # sort 1 suspendu (le test le lance à la main)
		_player.tick(0.01)
		if _kit.field is ZONE:
			_kit.field.set_process(false)
			_kit.field.step(0.01)
		elif _kit.field != null and is_instance_valid(_kit.field):
			_kit.field.set_process(false)
			_kit.field.step(0.01)
	_player.spells._remaining[1] = 0.0


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.storm_left = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0
	StageMap.water_override = {}


## Lance le sort `slot` et déclenche tout de suite sa frame d'impact.
func _cast(slot: int) -> bool:
	var ok: bool = _player.spells.cast(slot)
	_kit.flush_pending()
	return ok


func _water_grid(cells: int, pond: Array = []) -> Dictionary:
	# grille de `cells` x `cells` cases de 2 u, centrée sur l'origine ; `pond` = [x0, y0, x1, y1] (inclus) ou tout en eau
	var rows := PackedStringArray()
	for y in cells:
		var row := ""
		for x in cells:
			var w: bool = pond.is_empty() or (x >= pond[0] and x <= pond[2] and y >= pond[1] and y <= pond[3])
			row += "," if w else "."
		rows.append(row)
	return {"grid": rows, "cell_px": 2.0 * U, "origin": -Vector2(cells, cells) * U}


func _run() -> void:
	RunState.level = 1
	RunState.character = &"gresille"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as GresilleKit

	print("Personnage et rendu")
	_check("kit Grésille", _kit != null)
	_check("4 sorts / ids", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["gresille_arc", "gresille_decharge", "gresille_terre", "gresille_orage"])
	_check("PV L1 = 95", _near(_player.max_hp, 95.0), str(_player.max_hp))
	_check("armure 5", _near(_player.armor(), 5.0), str(_player.armor()))
	_check("vitesse 4,1 u/s", _near(_player.move_speed(), 4.1 * U, 0.1), str(_player.move_speed()))
	var vis := _player.get_node("Visual") as AnimatedSprite2D
	_check("sprites GR1 chargés", vis.sprite_frames != null and vis.sprite_frames.has_animation(&"call_s") and vis.sprite_frames.has_animation(&"ground_ne"))
	var el_ok := true
	for sp in GresilleKit.character().spells:
		el_ok = el_ok and sp.element == &"lightning" and sp.behavior == SpellData.Behavior.KIT and LightRig.has_preset(sp.light_preset)
	_check("sorts électriques (lightning), Behavior.KIT, lumière existante", el_ok)
	_check("Décharge : cible la plus chargée (target_mode)", GresilleKit.character().spells[1].target_mode == &"most_stacked")
	_reset()
	_kit.tick(10.0)
	var e0 := _kit.emission_step()
	_check("émission des bouteilles : Décharge prête = palier max", e0 == GresilleKit.EMISSION_STEPS, str(e0))
	_player.spells.set_cooldown(2, 7.0, 7.0)
	_kit._update_emission()
	_check("émission : Décharge en recharge = palier 0", _kit.emission_step() == 0, str(_kit.emission_step()))
	_player.spells.set_cooldown(2, 0.0, 7.0)

	print("Statique")
	_reset()
	var a := _fake(Vector2(3 * U, 0))
	_kit.apply_static(a)
	_check("1 cumul par coup", _kit.stacks_of(a) == 1)
	a.wet = true
	_kit.apply_static(a)
	_check("mouillé : 2 cumuls par application", _kit.stacks_of(a) == 3, str(_kit.stacks_of(a)))
	_check("3 cumuls : crispé (ralenti 20 %)", a.slowed_20())
	_kit.apply_static(a)
	_check("plafond 5", _kit.stacks_of(a) == 5, str(_kit.stacks_of(a)))
	_kit.tick(5.9)
	_check("cumuls tenus 5,9 s", _kit.stacks_of(a) == 5)
	_kit.tick(0.2)
	_check("cumuls expirés après 6 s", _kit.stacks_of(a) == 0, str(_kit.stacks_of(a)))
	a.wet = false
	for i in 5:
		_kit.apply_static(a)
	_check("5 cumuls sans foudroiement tant qu'aucun coup ne tombe", _kit.stacks_of(a) == 5 and a.stunned == 0.0)
	_kit.apply_static(a)
	_check("prochain coup : Foudroiement (étourdi 0,5 s, cumuls à 0)", _near(a.stunned, 0.5) and _kit.stacks_of(a) == 0, "%s %d" % [a.stunned, _kit.stacks_of(a)])
	for i in 5:
		_kit.apply_static(a, false)
	_kit.apply_static(a)
	_check("immunité 2,5 s : pas de second foudroiement", _near(a.stunned, 0.5) and _kit.stacks_of(a) == 5)
	_kit.tick(2.4)
	_kit.apply_static(a)
	_check("toujours immunisé à 2,4 s", _near(a.stunned, 0.5))
	_kit.tick(0.2)
	_kit.apply_static(a)
	_check("foudroyable de nouveau après 2,5 s", _near(a.stunned, 1.0) and _kit.stacks_of(a) == 0, str(a.stunned))
	var boss := _fake(Vector2(2 * U, 2 * U))
	boss.is_boss = true
	for i in 5:
		_kit.apply_static(boss, false)
	_kit.apply_static(boss)
	_check("boss : pas d'étourdissement, +10 % de dégâts subis 2 s", boss.stunned == 0.0 and boss.mods.size() == 1 and _near(float(boss.mods[0][1]), 1.1) and _near(float(boss.mods[0][2]), 2.0), str(boss.mods))
	var sill := _fake(Vector2(0, 4 * U))
	for i in 5:
		_kit.apply_static(sill, false)
	_kit.apply_static(sill, false)
	_check("le sillage ne foudroie jamais", sill.stunned == 0.0 and _kit.stacks_of(sill) == 5)

	print("Arc et rebond")
	_reset()
	var t1 := _fake(Vector2(3 * U, 0))
	var n1 := _fake(Vector2(3 * U, 2.0 * U))
	var far := _fake(Vector2(3 * U, 4.2 * U)) # à 4,2 u de t1 : hors 2,5 u, dans 4,5 u si mouillé
	_check("Arc lancé", _cast(1))
	_check("cible 0,8 coef", _near(t1.total(), 0.8 * BASE, 0.05), str(t1.total()))
	_check("rebond 0,45 coef sur le voisin à 2 u", _near(n1.total(), 0.45 * BASE, 0.05), str(n1.total()))
	_check("hors portée (4,2 u) : rien", far.taken.is_empty())
	_check("Statique 1 sur la cible et le rebond", _kit.stacks_of(t1) == 1 and _kit.stacks_of(n1) == 1)
	_reset()
	t1 = _fake(Vector2(3 * U, 0))
	far = _fake(Vector2(3 * U, 4.2 * U))
	t1.wet = true
	_cast(1)
	_check("mouillé : le rebond saute à 4,2 u (+2 u)", _near(far.total(), 0.45 * BASE, 0.05), str(far.total()))
	_check("mouillé : 2 cumuls sur la cible", _kit.stacks_of(t1) == 2, str(_kit.stacks_of(t1)))
	_reset()
	var lone := _fake(Vector2(9 * U, 0))
	_check("Arc : sans cible à 7 u, rien (aucun arc à vide)", not _player.spells.cast(1) and lone.taken.is_empty())

	print("Décharge")
	_reset()
	var close := _fake(Vector2(2 * U, 0)) # plus proche, 0 cumul
	var hot := _fake(Vector2(5 * U, 0))
	var nbs: Array = []
	for i in 6:
		nbs.append(_fake(hot.global_position + Vector2.from_angle(i * 1.0) * 2.0 * U))
	for i in 4:
		_kit.apply_static(hot, false)
	_check("Décharge lancée", _cast(2))
	_check("vise le monstre le plus CHARGÉ, pas le plus proche", hot.taken.size() == 1 and close.taken.is_empty(), str(hot.taken))
	_check("coef 2,8 + 0,15 × 4 = 3,4", _near(hot.taken[0], 3.4 * BASE, 0.05), str(hot.taken))
	var arced := 0
	for nb in nbs:
		if nb.taken.size() == 1 and _near(nb.taken[0], 0.6 * BASE, 0.05):
			arced += 1
	_check("n = 4 arcs de 0,6 vers 4 voisins distincts", arced == 4, str(arced))
	_check("cumuls consommés, la cible repart avec 1", _kit.stacks_of(hot) == 1, str(_kit.stacks_of(hot)))
	_check("voisins touchés : +1 Statique", _kit.stacks_of(nbs[0]) + _kit.stacks_of(nbs[1]) + _kit.stacks_of(nbs[2]) + _kit.stacks_of(nbs[3]) + _kit.stacks_of(nbs[4]) + _kit.stacks_of(nbs[5]) == 4)
	_check("plafond de recharge : Décharge 7 s", _near(_player.spells.cooldown_total(2), 7.0, 0.01), str(_player.spells.cooldown_total(2)))
	_reset()
	var hot2 := _fake(Vector2(5 * U, 0))
	var wetnb := _fake(hot2.global_position + Vector2(0, 4.5 * U))
	var drynb := _fake(hot2.global_position + Vector2(4.5 * U, 0))
	for i in 3:
		_kit.apply_static(hot2, false)
	_cast(2)
	_check("cible sèche : voisin sec à 4,5 u hors de portée (3 u)", drynb.taken.is_empty() and wetnb.taken.is_empty())
	_reset()
	hot2 = _fake(Vector2(5 * U, 0))
	wetnb = _fake(hot2.global_position + Vector2(0, 4.5 * U))
	drynb = _fake(hot2.global_position + Vector2(4.5 * U, 0))
	wetnb.wet = true
	for i in 3:
		_kit.apply_static(hot2, false)
	_cast(2)
	_check("un voisin mouillé est atteint à 4,5 u (5 u) même si la cible est sèche", wetnb.taken.size() == 1 and drynb.taken.is_empty())
	_reset()
	var five := _fake(Vector2(4 * U, 0))
	for i in 5:
		_kit.apply_static(five, false)
	_cast(2)
	_check("Décharge sur 5 cumuls : foudroyée (étourdie), coef 3,55", _near(five.stunned, 0.5) and _near(five.taken[0], 3.55 * BASE, 0.05), "%s %s" % [five.stunned, five.taken])
	_reset()
	var pt_near := _fake(Vector2(2 * U, 0))
	var pt_hot := _fake(Vector2(6 * U, 0))
	_check("pick_target sans cumul : le plus proche", _kit.pick_target(8 * U) == pt_near)
	_kit.apply_static(pt_hot, false)
	_check("pick_target : le plus chargé", _kit.pick_target(8 * U) == pt_hot)
	_reset()
	var cur_a := _fake(Vector2(4 * U, 0))
	var cur_b := _fake(Vector2(4 * U, 1.5 * U))
	_kit.apply_static(cur_b, false)
	_player.spells.aim_override = Vector2(4 * U, 0.5 * U)
	_cast(2)
	_check("PC : la Décharge vise au curseur (le plus chargé à <= 2 u du curseur)", cur_b.taken.size() >= 1 and _near(cur_b.taken[0], 2.95 * BASE, 0.05), str(cur_b.taken))
	_player.spells.aim_override = null

	print("Mise à la terre")
	_reset()
	var in_zone := _fake(Vector2(2 * U, 0))
	var out_zone := _fake(Vector2(5 * U, 0))
	_check("Mise à la terre lancée", _cast(3))
	_check("sec : disque (ZoneEffect) de 3 u", _kit.field is ZONE and _near(float(_kit.field.radius), 3.0 * U, 0.5), str(_kit.field))
	_advance(0.55)
	_check("tick 0,5 s : coef 0,45 et +1 Statique dans la zone", in_zone.taken.size() >= 1 and _near(in_zone.taken[0], 0.45 * BASE, 0.05) and _kit.stacks_of(in_zone) >= 1, str(in_zone.taken))
	_check("ralentissement 20 % dans la zone", in_zone.slowed_20())
	_check("rien hors de la zone", out_zone.taken.is_empty())
	_advance(2.0)
	_check("Statique qui monte à chaque tick puis foudroie à 5 (tick à t=0 compris : 6 ticks en 2,55 s)", in_zone.stunned > 0.0 or _kit.stacks_of(in_zone) >= 3, str(_kit.stacks_of(in_zone)))
	_check("recharge 10 s", _near(_player.spells.cooldown_total(3), 10.0, 0.01))
	_advance(3.0)
	_check("la zone disparaît après 5 s", _kit.field == null or not is_instance_valid(_kit.field) or _kit.field.is_queued_for_deletion())
	# nappe d'eau
	_reset()
	StageMap.water_override = _water_grid(40) # tout en eau : 80 u de côté
	_check("Enemy/StageMap : is_water_at sur la carte d'essai", StageMap.is_water_at(get_tree(), Vector2(10, 10)))
	var patch := StageMap.water_patch_at(get_tree(), Vector2.ZERO, GresilleKit.GROUND_WATER_CELLS_MAX)
	_check("nappe plafonnée à 113 cases", patch.size() == 113, str(patch.size()))
	var rmax := 0.0
	for c in patch:
		rmax = maxf(rmax, c.length())
	_check("la nappe plafonnée est un rond (rayon <= ~6,5 u)", rmax <= 6.6 * U, str(rmax / U))
	var wet_target := _fake(Vector2(5 * U, 0))
	_check("Mise à la terre sur l'eau", _cast(3))
	_check("l'eau : GresilleGroundField de 113 cases", _kit.field is GresilleGroundField and _kit.field.cells.size() == 113, str(_kit.field))
	var gw0: float = PlayerRef.state_of(_player).counters.get(GresilleKit.COUNTER_GROUNDED_WET, 0.0)
	_advance(0.55)
	_check("la nappe électrise à 5 u (hors disque de 3 u), 2 cumuls par tick : tout est mouillé", wet_target.taken.size() >= 1 and _kit.stacks_of(wet_target) >= 2, "%s %d" % [wet_target.taken, _kit.stacks_of(wet_target)])
	_advance(1.05)
	var gw1: float = PlayerRef.state_of(_player).counters.get(GresilleKit.COUNTER_GROUNDED_WET, 0.0)
	_check("compteur du Paratonnerre : +1 par monstre électrisé, une seule fois par nappe", _near(gw1 - gw0, 1.0, 0.01), "%s -> %s" % [gw0, gw1])
	_reset()
	StageMap.water_override = _water_grid(40, [18, 18, 20, 20]) # un bassin de 3x3 cases = 6x6 u = 36 cases de 1 u
	patch = StageMap.water_patch_at(get_tree(), Vector2.ZERO, 113)
	_check("bassin plus petit que le plafond : épouse la nappe (36 cases)", patch.size() == 36, str(patch.size()))
	var rows := PackedStringArray(["..,,.", "..,,.", ".....", ",,...", ",,..."])
	_check("remplissage 4-connexe : deux mares séparées ne se mélangent pas", StageMap.water_cells_connected(rows, Vector2i(4, 0), 1000, 2).size() == 16 and StageMap.water_cells_connected(rows, Vector2i(0, 6), 1000, 2).size() == 16)
	_check("départ hors de l'eau : vide", StageMap.water_cells_connected(rows, Vector2i(0, 0), 113, 2).is_empty())
	_reset()
	var dry_sp := _fake(Vector2(1 * U, 0))
	StageMap.water_override = _water_grid(40, [30, 30, 33, 33]) # eau loin du joueur
	_cast(3)
	_check("sur la terre ferme : disque", _kit.field is ZONE)
	StageMap.water_override = {}

	print("Orage appelé")
	_reset()
	var st_hot := _fake(Vector2(5 * U, 0))
	var st_near := _fake(Vector2(2 * U, 0))
	for i in 3:
		_kit.apply_static(st_hot, false)
	_check("Orage lancé", _player.spells.cast(4))
	_check("Orage : le sort 1 reste libre pendant la montée, le sort 4 est bloqué (audit R1)", not _kit.blocks_slot(1) and _kit.blocks_slot(4))
	_kit.flush_pending()
	_check("canalisation commencée, premier coup", _kit.is_channeling() and _kit.storm_strikes_done == 1)
	_check("coup 1 sur le plus chargé : 1,3 + 0,05 × 3 = 1,45 coef", st_hot.taken.size() >= 1 and _near(st_hot.taken[0], 1.45 * BASE, 0.05), str(st_hot.taken))
	_check("le plus proche (0 cumul) n'est pas visé", st_near.taken.is_empty())
	_check("marche à 70 %", _near(_kit.speed_mult(), 2.9 / 4.1, 0.001))
	_check("sort 1 libre pendant la canalisation (audit R1)", not _kit.blocks_slot(1) and _kit.blocks_slot(4))
	_advance(2.6)
	_check("6 coups en 2,5 s, canalisation encore tenue (3 s)", _kit.storm_strikes_done == 6 and _kit.is_channeling(), str(_kit.storm_strikes_done))
	_advance(0.5)
	_check("canalisation finie après 3 s (6 coups)",_kit.storm_strikes_done == 6 and not _kit.is_channeling(), "%d %s" % [_kit.storm_strikes_done, _kit.storm_left])
	_check("après l'Orage : sort 1 libre, vitesse normale", not _kit.blocks_slot(1) and _near(_kit.speed_mult(), 1.0))
	_check("recharge 22 s", _near(_player.spells.cooldown_total(4), 22.0, 0.01))
	_reset()
	var st2 := _fake(Vector2(3 * U, 0))
	_player.spells.cast(4)
	_kit.flush_pending()
	_advance(0.6)
	var done := _kit.storm_strikes_done
	_kit.on_dodge_start(Vector2.RIGHT)
	_advance(1.0)
	_check("l'esquive interrompt l'Orage (coups restants perdus)", not _kit.is_channeling() and _kit.storm_strikes_done == done and done < 6, str(done))
	_reset()
	_player.spells.cast(4)
	_kit.flush_pending()
	var fl := _kit.storm_strikes_done
	_check("sans monstre : le coup tombe dans le vide", fl == 1)
	_kit.on_dodge_start(Vector2.RIGHT)

	print("Esquive Court-circuit et Isolée")
	_reset()
	var sw := _fake(Vector2(1.5 * U, 0))
	var sw_far := _fake(Vector2(1.5 * U, 3 * U))
	_player.global_position = Vector2.ZERO
	_kit.on_dodge_start(Vector2.RIGHT)
	_player.global_position = Vector2(1.5 * U, 0.2 * U)
	_kit._trail.append({"p": _player.global_position, "t": 0.0})
	_kit._tick_wake(GresilleKit.WAKE_SAMPLE_S)
	_check("sillage : +1 Statique à un monstre traversé, 0 sans contact", _kit.stacks_of(sw) == 1 and _kit.stacks_of(sw_far) == 0, str(_kit.stacks_of(sw)))
	_kit._tick_wake(GresilleKit.WAKE_SAMPLE_S)
	_check("une seule fois par esquive", _kit.stacks_of(sw) == 1)
	_kit._trail.clear()
	_kit._tick_wake(GresilleKit.WAKE_SAMPLE_S)
	var src := FakeSource.new()
	var br := FakeBrain.new()
	br._zones = [{"conduct": true, "shock": 0.6, "shape": "disc", "pos": Vector2.ZERO, "r": 3.0 * U}]
	src.brain = br
	get_tree().root.add_child(src)
	_junk.append(src)
	_check("Isolée : -50 % d'une flaque électrisée de mini-boss", _near(_kit.damage_taken_mult(src), 0.5))
	br._zones[0]["shock"] = 0.0
	_check("Isolée : flaque éteinte = dégâts pleins", _near(_kit.damage_taken_mult(src), 1.0))
	_check("Isolée : sans cerveau = dégâts pleins", _near(_kit.damage_taken_mult(null), 1.0))

	print("Isolée : flaques d'eau de mini-boss")
	_reset()
	_check("Isolée : Player.ignores_water_slow lit le kit", _player.ignores_water_slow() and _kit.ignores_water_slow())
	director.set_meta(&"next_mini_id", &"iron_heron")
	var mini_e := director.spawn_boss(&"mini", Vector2(4000, 4000)) as Enemy
	director.remove_meta(&"next_mini_id")
	var brain := mini_e.brain as MiniBossBrain
	brain.ai_enabled = false
	var zw := {"coef": 0.0, "status": "slow", "slow_mult": 0.8, "tick_s": 0.5, "water": true}
	brain._zone_tick_on(zw, _player)
	_check("Isolée : une flaque d'eau de mini-boss ne la ralentit pas", not _player.is_slowed())
	var zd := zw.duplicate()
	zd["water"] = false
	brain._zone_tick_on(zd, _player)
	_check("Isolée : une zone qui n'est pas de l'eau la ralentit encore", _player.is_slowed())
	_player.clear_statuses()
	var saved_kit = _player.kit
	_player.kit = null
	brain._zone_tick_on(zw, _player)
	_check("sans le trait : la flaque d'eau ralentit", _player.is_slowed())
	_player.kit = saved_kit
	_player.clear_statuses()
	director.release_enemy(mini_e)

	print("Variantes : Paratonnerre et Bouteille de Leyde")
	var vr := GresilleKit.variant(3, GresilleKit.V_PARATONNERRE)
	var vl := GresilleKit.variant(4, GresilleKit.V_LEYDE)
	_check("variant() : Paratonnerre (slot 3, recharge 10 s, coef 0,8, 6 s, tick 1 s)", vr != null and vr.id == GresilleKit.V_PARATONNERRE and vr.slot == 3 and _near(vr.base_cooldown, 10.0) and _near(vr.coef, 0.8) and _near(vr.duration, 6.0) and _near(vr.tick, 1.0))
	_check("variant() : Leyde (slot 4, recharge 22 s, coef 6,5, 4 u)", vl != null and vl.id == GresilleKit.V_LEYDE and vl.slot == 4 and _near(vl.base_cooldown, 22.0) and _near(vl.coef, 6.5) and _near(vl.radius_u, 4.0))
	_check("variant() : slot ou id inconnu = null", GresilleKit.variant(1, GresilleKit.V_LEYDE) == null and GresilleKit.variant(3, &"nope") == null)
	_check("variantes déclarées dans characters.json et résolues par CharacterData", CharacterData.variant_spell(&"gresille", 3, GresilleKit.V_PARATONNERRE, true) != null and CharacterData.variant_spell(&"gresille", 4, GresilleKit.V_LEYDE, true) != null)
	var budget_rod := 6.0 * vr.coef
	var budget_ground := 10.0 * GresilleKit.GROUND_COEF # 10 ticks de 0,45 en 5 s
	_check("budget Paratonnerre : 4,8 contre 4,5 (<= +15 %)", budget_rod <= budget_ground * 1.15 and budget_rod >= budget_ground * 0.85, "%s / %s" % [budget_rod, budget_ground])
	var counters_vars := 0
	for ch in (JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json")) as Array):
		if ch.get("id", "") == "gresille":
			for sp in ch["spells"]:
				for v in sp["variants"]:
					if v["unlock_rule"]["type"] == "counter" and float(v["unlock_rule"]["value"]) == 300.0:
						counters_vars += 1
	_check("2 variantes à compteur (300) dans le JSON", counters_vars == 2, str(counters_vars))

	# Paratonnerre en jeu
	var base3: SpellData = _player.character.spells[2]
	var base4: SpellData = _player.character.spells[3]
	_player.character.spells[2] = vr
	_reset()
	var r_in := _fake(Vector2(5 * U, 0))
	var r_in2 := _fake(Vector2(5 * U, 1.5 * U))
	var r_out := _fake(Vector2(5 * U, 3 * U))
	var r_near := _fake(Vector2(1 * U, 0)) # près de Grésille, loin de la tige
	_player.spells.aim_override = Vector2(5 * U, 0)
	_check("Paratonnerre lancé", _cast(3))
	_check("la tige est un GresilleRod en (5 u, 0)", _kit.field is GresilleRod and _kit.field.global_position.distance_to(Vector2(5 * U, 0)) < 1.0, str(_kit.field))
	_advance(0.95)
	_check("rien avant la première seconde", r_in.taken.is_empty())
	_advance(0.1)
	_check("1 s : coup de foudre coef 0,8 dans les 2 u de la tige", r_in.taken.size() == 1 and _near(r_in.taken[0], 0.8 * BASE, 0.05) and r_in2.taken.size() == 1, str(r_in.taken))
	_check("+1 Statique, hors cercle et loin de la tige : rien", _kit.stacks_of(r_in) == 1 and r_out.taken.is_empty() and r_near.taken.is_empty())
	_check("pas de ralentissement", not r_in.slowed_20() or _kit.stacks_of(r_in) >= 3)
	_advance(5.1)
	_check("6 coups en 6 s, puis la tige disparaît", r_in.taken.size() == 6 and (_kit.field == null or not is_instance_valid(_kit.field) or _kit.field.is_queued_for_deletion()), str(r_in.taken.size()))
	_check("recharge 10 s", _near(_player.spells.cooldown_total(3), 10.0, 0.01))
	_reset()
	_player.spells.aim_override = Vector2(12 * U, 0)
	_cast(3)
	_check("portée 7 u : la tige est ramenée à 7 u", _kit.field != null and _near(_kit.field.global_position.x, 7 * U, 1.0), str(_kit.field.global_position if _kit.field != null else null))
	_reset()
	_player.spells.aim_override = null
	_check("sans point visé (mobile sans monstre) : rien lancé, rien en attente", not _kit.cast_spell(vr, null) and not _kit.has_pending())
	_player.character.spells[2] = base3

	# Bouteille de Leyde en jeu
	_player.character.spells[3] = vl
	_reset()
	var ja := _fake(Vector2(6 * U, 0))
	var jb := _fake(Vector2(6 * U, 1 * U))
	var jc := _fake(Vector2(6 * U, -1 * U))
	var jfar := _fake(Vector2(6 * U, 4.5 * U))
	for i in 3:
		_kit.apply_static(ja, false)
	for i in 5:
		_kit.apply_static(jb, false)
	_player.spells.aim_override = Vector2(6 * U, 0)
	_check("Leyde lancée", _cast(4))
	_check("instantané : aucune canalisation, sort 1 libre", not _kit.is_channeling() and not _kit.blocks_slot(1) and not _kit.blocks_slot(4))
	_check("la bouteille est en vol (rien de touché)", _kit._lob is GresilleLob and ja.taken.is_empty())
	_kit._lob.set_process(false)
	_kit._lob.step(0.5)
	_check("0,5 s : toujours en vol", ja.taken.is_empty() and not _kit._lob.landed)
	_kit._lob.step(0.4)
	_check("0,8 s : éclat, coef 6,5 + 0,3 n (n = 3)", ja.taken.size() == 1 and _near(ja.taken[0], (6.5 + 0.9) * BASE, 0.1), str(ja.taken))
	_check("cumuls consommés (jamais ré-ajoutés)", _kit.stacks_of(ja) == 0 and _kit.stacks_of(jc) == 0)
	_check("monstre à 5 cumuls : foudroyé (étourdi) et vidé", jb.stunned > 0.0 and _kit.stacks_of(jb) == 0 and _near(jb.taken[0], 8.0 * BASE, 0.1), str(jb.taken))
	_check("sans cumul : coef 6,5", jc.taken.size() == 1 and _near(jc.taken[0], 6.5 * BASE, 0.1), str(jc.taken))
	_check("hors des 4 u : rien", jfar.taken.is_empty())
	_check("recharge 22 s", _near(_player.spells.cooldown_total(4), 22.0, 0.01))
	_player.character.spells[3] = base4
	_player.spells.aim_override = null

	print("Compteur de kills d'Orage")
	_reset()
	var pid := PlayerRef.id_of(_player)
	var sk0: float = PlayerRef.state_of(_player).counters.get(GresilleKit.COUNTER_STORM_KILLS, 0.0)
	var killed := _FoeVia.new()
	get_tree().root.add_child(killed)
	_junk.append(killed)
	killed.last_hit_via = GresilleKit.VIA_STORM
	_kit._on_enemy_killed_by(pid, killed, Vector2.ZERO, 1, false)
	killed.last_hit_via = &"zone"
	_kit._on_enemy_killed_by(pid, killed, Vector2.ZERO, 1, false)
	killed.last_hit_via = GresilleKit.VIA_STORM
	_kit._on_enemy_killed_by(pid + 7, killed, Vector2.ZERO, 1, false)
	var sk1: float = PlayerRef.state_of(_player).counters.get(GresilleKit.COUNTER_STORM_KILLS, 0.0)
	_check("kill dont le dernier coup est d'Orage : +1 (autre via ou autre joueur : 0)", _near(sk1 - sk0, 1.0, 0.01), "%s -> %s" % [sk0, sk1])

	print("Sons : boucle de Mise à la terre et cliquetis des bouteilles")
	_reset()
	_kit._poll_audio()
	_player.spells.set_cooldown(2, 5.0, 7.0)
	_kit._poll_audio()
	_check("Décharge en recharge : cliquetis armé", _kit._jars_armed)
	_player.spells.set_cooldown(2, 0.0, 7.0)
	_kit._poll_audio()
	_check("Décharge prête de nouveau : cliquetis joué une fois, désarmé", not _kit._jars_armed)
	_cast(3)
	var looping := not _kit._ground_loop.is_empty()
	print("  info boucle de Mise à la terre démarrée : ", looping, " (faux en headless sans banque audio)")
	if looping:
		_check("une boucle active (poignée gardée)", Audio.active_loops() >= 1)
	_kit.field.queue_free()
	await get_tree().process_frame
	_kit._poll_audio()
	_check("zone expirée : poignée de boucle rendue", _kit._ground_loop.is_empty())

	print("static_crawl : arcs sur les monstres chargés")
	await get_tree().process_frame
	var crawl: GresilleCrawl = _kit._crawl
	_check("GresilleCrawl présent, pool de 60 sprites", crawl != null and crawl.pool_size() == 60, str(crawl.pool_size() if crawl != null else -1))
	_reset()
	var cw_a := _fake(Vector2(200, 200))
	var cw_b := _fake(Vector2(300, 200))
	_kit.apply_static(cw_a, false)
	_kit.apply_static(cw_a, false)
	_kit._refresh_crawl()
	_check("2 cumuls : aucun arc", crawl.active_count() == 0)
	_kit.apply_static(cw_a, false)
	_kit._refresh_crawl()
	_check("3 cumuls : un arc", crawl.active_count() == 1)
	for i in 5:
		_kit.apply_static(cw_b, false)
	_kit._refresh_crawl()
	var sp_b := (crawl._slots[0]["sp"] as AnimatedSprite2D)
	_check("5 cumuls : deux arcs, le plus chargé d'abord, plus vif et plus lumineux", crawl.active_count() == 2 and sp_b.modulate.a > 0.95 and sp_b.speed_scale > 1.4 and crawl._slots[0]["target"] == cw_b)
	_kit.tick(7.0) # les cumuls expirent
	_kit._refresh_crawl()
	_check("cumuls expirés : plus rien d'actif (aucun coût sans cumul)", crawl.active_count() == 0)
	var crowd: Array = []
	for i in 250:
		var ce := _fake(Vector2(120 + (i % 25) * 36, 120 + (i / 25) * 40))
		for k in 5:
			_kit.apply_static(ce, false)
		crowd.append(ce)
	_kit._refresh_crawl()
	_check("250 monstres à 5 cumuls : pool borné au plafond du palier (Haut 60)", crawl.active_count() == mini(GresilleCrawl.cap(), 60) and crawl.active_count() <= 60, "%d / cap %d" % [crawl.active_count(), GresilleCrawl.cap()])
	var tier0: int = Quality.tier
	Quality.tier = Quality.Tier.LOW
	_kit._refresh_crawl()
	_check("palier Bas : au plus 9 arcs", crawl.active_count() == 9 and GresilleCrawl.cap() == 9, str(crawl.active_count()))
	Quality.tier = Quality.Tier.MEDIUM
	_kit._refresh_crawl()
	_check("palier Moyen : au plus 27 arcs", crawl.active_count() == 27, str(crawl.active_count()))
	Quality.tier = tier0
	var t0 := Time.get_ticks_usec()
	for i in 100:
		_kit._refresh_crawl()
		crawl._process(0.016)
	var per_ms := float(Time.get_ticks_usec() - t0) / 100.0 / 1000.0
	print("  info coût : refresh + suivi de %d arcs parmi 250 monstres chargés = %.3f ms par sélection (toutes les %.1f s) " % [crawl.active_count(), per_ms, GresilleCrawl.REFRESH_S])
	_check("coût d'une sélection < 2 ms", per_ms < 2.0, "%.3f ms" % per_ms)
	_kit.clear_transients()
	_check("clear_transients éteint tout", crawl.active_count() == 0)

	print("Audit 10/11 : Orage sans suspension, Mise à la terre auto, réarmement d'étourdissement, sillage échantillonné")
	_reset()
	var tough_near := _fake(Vector2(2 * U, 0))
	_check("R2 : un monstre ordinaire seul ne déclenche pas la Mise à la terre auto", not _kit.auto_cast_ok(3))
	tough_near.is_elite = true
	_check("R2 : une élite seule à <= 3 u la déclenche", _kit.auto_cast_ok(3))
	tough_near.is_elite = false
	tough_near.is_boss = true
	_check("R2 : un boss ou mini-boss seul à <= 3 u aussi", _kit.auto_cast_ok(3))
	tough_near.global_position = Vector2(5 * U, 0)
	_check("R2 : hors des 3 u : non", not _kit.auto_cast_ok(3))
	_check("R3 : immunité de foudroiement 2,5 s", _near(GresilleStatic.ZAP_IMMUNE_S, 2.5))
	_reset()
	var wk := _fake(Vector2(1.5 * U, 0))
	_kit._trail.append({"p": Vector2(1.5 * U, 0.2 * U), "t": 0.0})
	_kit._tick_wake(0.01)
	_check("R5b : pas de recherche de victimes entre deux échantillons (0,05 s)", _kit.stacks_of(wk) == 0)
	_kit._tick_wake(0.045)
	_check("R5b : au 2e échantillon, la victime est touchée", _kit.stacks_of(wk) == 1)
	_check("R5a : voisin hors portée sèche et hors bande mouillée : jamais de is_wet superflu", _kit._nearest_neighbor(wk, 2.5, {wk.get_instance_id(): true}, true) == null)

	print("R4 : réarmement d'étourdissement des élites (Enemy.stun)")
	var dir_node: Node2D = director
	var elite_e: Enemy = dir_node.spawn_enemy(3, Vector2(3000, 3000), true)
	var plain_e: Enemy = dir_node.spawn_enemy(3, Vector2(3300, 3000), false)
	for m: Enemy in [elite_e, plain_e]:
		m.hp = m.max_hp * 1000.0
		m.test_dummy = false
	_check("l'élite est une élite, l'autre non", elite_e.is_elite and not plain_e.is_elite)
	elite_e.stun(0.5)
	_check("élite : premier étourdissement accepté", elite_e.is_stunned())
	elite_e.stun(5.0)
	_check("élite : une 2e source pendant l'étourdissement est ignorée (durée inchangée)", elite_e.is_stunned() and _near(elite_e.hitstop_left(), 0.5, 0.06), str(elite_e.hitstop_left()))
	for i in 7: # 0,7 s : l'étourdissement de 0,5 s est fini, le réarmement (1,5 s) court
		elite_e.tick(0.1, _player, _player.global_position, Vector2.ZERO)
	_check("élite : étourdissement fini", not elite_e.is_stunned())
	elite_e.stun(0.5)
	_check("élite : tout nouvel étourdissement refusé pendant le réarmement (1,5 s après la fin)", not elite_e.is_stunned())
	for i in 18: # +1,8 s : 2,5 s au total depuis le début, réarmement échu (0,5 + 1,5 = 2,0 s)
		elite_e.tick(0.1, _player, _player.global_position, Vector2.ZERO)
	elite_e.stun(0.5)
	_check("élite : de nouveau étourdissable après le réarmement", elite_e.is_stunned())
	plain_e.stun(0.5)
	plain_e.stun(0.5)
	_check("monstre ordinaire : règle inchangée (pas de réarmement)", plain_e.is_stunned())
	_check("constante Balance.ELITE_STUN_REARM_S = 1,5", _near(Balance.ELITE_STUN_REARM_S, 1.5))
	dir_node.release_enemy(elite_e)
	dir_node.release_enemy(plain_e)

	print("Enemy.is_wet et déblocage")
	var real := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(real)
	_junk.append(real)
	_check("Enemy.is_wet : sec par défaut", not real.is_wet())
	real.mark_wet(2.0)
	_check("Enemy.mark_wet : trempé", real.is_wet())
	var tr := UnlockTracker.new()
	add_child(tr)
	var was_running := RunState.running
	RunState.running = true
	var foe := FakeEnemy.new()
	foe.set_meta(&"x", 1)
	var holder := _FoeVia.new()
	get_tree().root.add_child(holder)
	_junk.append(holder)
	holder.last_hit_via = &"eclair_bouteille"
	tr._on_enemy_killed_by(0, holder, Vector2(9999, 9999), 1, false)
	_check("compteur lightning_kills : un kill de l'Éclair en bouteille", tr.lightning_kills == 1, str(tr.lightning_kills))
	holder.last_hit_via = &"zone"
	tr._on_enemy_killed_by(0, holder, Vector2(9999, 9999), 1, false)
	_check("un autre kill ne compte pas", tr.lightning_kills == 1)
	_check("la mesure est exposée au profil", float(tr.metrics().get("lightning_kills", -1)) == 1.0 and Profile.UNLOCK_ON_OBJECTIVE.has("lightning_kills") and Profile.UNLOCK_ON_OBJECTIVE["lightning_kills"][1] == &"character:gresille")
	RunState.running = was_running
	foe.free()
	tr.queue_free()

	print(("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


class _FoeVia extends Node2D:
	var last_hit_via: StringName = &""
