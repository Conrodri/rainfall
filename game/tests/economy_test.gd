extends Node
## Économie de l'étage 1 (5 min, Moyen) après l'Alignement RoR2 (docs/Maths_Scaling.md §14) :
## director réel (Balance : crédits 0,894 × (1 + 0,4 coeff), rampe de début, zones mini ×1,5 / étage ×2,33)
## -> kills (crédits / coût moyen) -> or 2 × coeff × coût × R et XP coeff × coût × R, + capsules et primes de boss.
## Vérifie : pas de réserve d'or d'étage, or total de l'étage entre 7,5 et 12 P (P = petit coffre ; doc Ateliers_Chiffres
## §1.1 : 8,0-8,8 P mesurés à l'étage 1), niveau 6 à 9 en fin d'étage, rythme de kills décroissant.
## Capsules 10 -> 4 (joueur, 01/11/2026) : le reliquat après les 10 coffres n'est plus positif (on n'ouvre plus tout :
## ≈ 7-8 coffres sur 10 au lieu de 10) ; il doit rester entre -200 et +300 or. Avant : 0 à 300 et 613 or de total.
## Remplacé : vérification du budget d'or d'étage (RunState.take_monster_gold, supprimé).
## godot --headless --path game res://tests/economy_test.tscn

## Programme d'un étage de 5:00 : [fin (s), zone du joueur (&"" hors zone)]
const SCHED := [[60, &""], [100, &"mini"], [130, &""], [170, &"mini"], [200, &""], [290, &"etage"], [300, &""]]
const KILL_SHARE := 0.95 ## part des monstres apparus réellement tués (simulation : 98 %)

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	print("ok   " if ok else "FAIL ", msg)
	if not ok:
		_fails += 1


static func _zone(t: float) -> StringName:
	for e in SCHED:
		if t < float(e[0]):
			return e[1]
	return &""


func _ready() -> void:
	RunState.start_run(&"moyen", 99)
	RunState.running = true
	_check(not ("monster_gold_budget" in RunState), "plus de réserve d'or d'étage dans RunState")
	var kill_gold := 0.0
	var kills := 0.0
	var at := {}
	var bounties := 0.0
	var dt := 0.25
	var steps := int(300.0 / dt)
	for k in steps:
		var t := k * dt
		var D := RunState.difficulty()
		var credits := Balance.director_credits_per_s(D, _zone(t)) * Balance.director_ramp(t) * dt
		var mean_cost := 1.0 + Balance.DIRECTOR_MEAN_COST_SLOPE * (D - 1.0)
		var killed := credits / mean_cost * KILL_SHARE
		kills += killed
		# Prime ∝ coût : la somme des coûts tués = crédits × KILL_SHARE (élites ×6 en coût et en prime).
		var g := Balance.monster_gold(D, mean_cost) * killed
		kill_gold += g
		RunState.add_xp(Balance.monster_xp(D, mean_cost) * killed)
		if is_equal_approx(t, 100.0) or is_equal_approx(t, 170.0):
			bounties += Balance.boss_gold(&"mini", D)
			RunState.add_xp(Balance.boss_xp(&"mini", D))
		if is_equal_approx(t, 290.0):
			bounties += Balance.boss_gold(&"etage", D)
			RunState.add_xp(Balance.boss_xp(&"etage", D))
		RunState._process(dt)
		var t1 := (k + 1) * dt
		if fmod(t1, 60.0) < 0.001:
			at[int(t1 / 60.0)] = [kills, kill_gold, RunState.level, D]
	var caps := Balance.CAPSULES_PER_STAGE * Balance.capsule_gold(RunState.floor_start_d, 1)
	var chests := 8.0 * Balance.chest_price(&"petit", RunState.floor_start_d, 1) + 2.0 * Balance.chest_price(&"large", RunState.floor_start_d, 1)
	print("min | kills | kills/s | or des kills | niveau | coeff")
	var prev := 0.0
	for m in [1, 2, 3, 4, 5]:
		var a: Array = at[m]
		print("%d:00 | %5.0f | %4.2f | %5.0f | %d | %.3f" % [m, a[0], (float(a[0]) - prev) / 60.0, a[1], a[2], a[3]])
		prev = float(a[0])
	var total := kill_gold + caps + bounties
	var surplus := total - chests
	print("capsules %.0f, primes %.0f, kills %.0f -> total %.0f ; 10 coffres %.0f -> reliquat %.0f ; niveau %d (+%.0f XP)" % [
		caps, bounties, kill_gold, total, chests, surplus, RunState.level, RunState.xp])
	var p_small := Balance.chest_price(&"petit", RunState.floor_start_d, 1)
	_check(total >= 7.5 * p_small and total <= 12.0 * p_small, "or total de l'étage dans [7,5 ; 12] P (%.1f P ; 11,5 P avec 4 capsules de 40 or, 12,3 P avant avec 10 de 20)" % (total / p_small))
	_check(surplus >= -200.0 and surplus <= 300.0, "reliquat après les 10 coffres dans [-200, 300] (%.0f)" % surplus)
	_check(RunState.level >= 6 and RunState.level <= 9, "niveau fin d'étage 1 dans [6, 9] (%d)" % RunState.level)
	_check(chests == 600.0, "coffres de l'étage 1 : 8 × 50 + 2 × 100 (%.0f)" % chests)
	_check(caps == 160.0, "capsules : 4 × 40 à coeff 1 (%.0f)" % caps)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
