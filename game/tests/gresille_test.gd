extends Node
## Test headless de Grésille (docs/fiches/gresille.md) : stats, Statique (cumuls, expiration, crispé, Foudroiement,
## immunité, boss), Arc et rebond (mouillé +2 u), Décharge (cible la plus chargée, +0,15 n, n arcs, mouillé +2 u),
## Mise à la terre (disque sec, nappe d'eau connexe plafonnée à 113 cases), Orage (6 coups, cible la plus chargée,
## sort 1 suspendu, 70 %, interruption par l'esquive), Isolée, Enemy.is_wet, compteur de déblocage de la run.
## godot --headless res://tests/gresille_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var wet := false
	var is_boss := false
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
	_check("immunité 1,5 s : pas de second foudroiement", _near(a.stunned, 0.5) and _kit.stacks_of(a) == 5)
	_kit.tick(1.4)
	_kit.apply_static(a)
	_check("toujours immunisé à 1,4 s", _near(a.stunned, 0.5))
	_kit.tick(0.2)
	_kit.apply_static(a)
	_check("foudroyable de nouveau après 1,5 s", _near(a.stunned, 1.0) and _kit.stacks_of(a) == 0, str(a.stunned))
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
	_check("compteur de déblocage de la variante (électrisés sur l'eau)", PlayerRef.state_of(_player).counters.get(GresilleKit.COUNTER_GROUNDED_WET, 0.0) >= 1.0)
	_advance(0.55)
	_check("la nappe électrise à 5 u (hors disque de 3 u), 2 cumuls par tick : tout est mouillé", wet_target.taken.size() >= 1 and _kit.stacks_of(wet_target) >= 2, "%s %d" % [wet_target.taken, _kit.stacks_of(wet_target)])
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
	_check("sort 1 suspendu pendant la montée", _kit.blocks_slot(1))
	_kit.flush_pending()
	_check("canalisation commencée, premier coup", _kit.is_channeling() and _kit.storm_strikes_done == 1)
	_check("coup 1 sur le plus chargé : 1,3 + 0,05 × 3 = 1,45 coef", st_hot.taken.size() >= 1 and _near(st_hot.taken[0], 1.45 * BASE, 0.05), str(st_hot.taken))
	_check("le plus proche (0 cumul) n'est pas visé", st_near.taken.is_empty())
	_check("marche à 70 %", _near(_kit.speed_mult(), 2.9 / 4.1, 0.001))
	_check("sort 1 suspendu", _kit.blocks_slot(1))
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
	_kit._tick_wake(0.01)
	_check("sillage : +1 Statique à un monstre traversé, 0 sans contact", _kit.stacks_of(sw) == 1 and _kit.stacks_of(sw_far) == 0, str(_kit.stacks_of(sw)))
	_kit._tick_wake(0.01)
	_check("une seule fois par esquive", _kit.stacks_of(sw) == 1)
	_kit._trail.clear()
	_kit._tick_wake(0.01)
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
