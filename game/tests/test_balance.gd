extends SceneTree
## Vérifie Balance contre docs/Maths_Scaling.md (§14 Alignement RoR2).
## godot --headless --path game --script res://tests/test_balance.gd

var _fails := 0


func _init() -> void:
	var B = load("res://scripts/core/balance.gd").new()
	# Alignement RoR2 (docs/Maths_Scaling.md §14) : coeff = (1 + min × 0,0506 × diff × 1,5) × 1,15^(étage-1)
	_near("coeff moyen 2:30 étage 1", B.difficulty(150, 1, 2.0), 1.3795, 0.0005)
	_near("coeff difficile 5:00 étage 3", B.difficulty(300, 3, 3.0), 2.8282, 0.0005)
	_near("coeff moyen 10:00 étage 5 (pas d'endless)", B.difficulty(600, 5, 2.0), 4.4040, 0.001)
	_near("niveau ambiant (coeff 2)", B.monster_level(2.0), 4.0, 0.0)
	_near("PV tier 1 niv 2 (+33 %)", B.monster_hp(18.0, 1.3795, 1), 23.94, 0.001)
	_near("dégâts tier 1 niv 2 (+20 %)", B.monster_damage(5.0, 1.3795), 6.0, 0.001)
	_near("PV tier 2 niv 4 (90 x (1 + 0,36 x 3))", B.monster_hp(90.0, 2.0, 2), 187.2, 0.001)
	_near("PV tier 3 niv 4 (360 x (1 + 0,40 x 3))", B.monster_hp(360.0, 2.0, 3), 792.0, 0.001)
	_near("coût T2 (audit 29/10)", B.TIER_COST[2], 5.0, 0.0)
	_near("coût T3 (audit 29/10)", B.TIER_COST[3], 16.0, 0.0)
	_near("pente du coût moyen", B.DIRECTOR_MEAN_COST_SLOPE, 0.55, 0.0)
	_near("T3 dès D 1,6", B.TIER_MIN_D[3], 1.6, 0.0)
	_near("part T3 0,5", B.T3_SHARE, 0.5, 0.0)
	_near("masse de recul brute", B.KB_MASS[3], 0.25, 0.0)
	_near("chef de vague base", B.WAVE_LEADER_BASE, 0.20, 0.0)
	_near("les boss gardent LEVEL_HP_GROWTH 0,30", B.LEVEL_HP_GROWTH, 0.30, 0.0)
	_near("plafond d'explosion (coups de base)", B.BLAST_HP_CAP_HITS, 12.0, 0.0)
	_near("coût élite tier 1 (×6)", B.monster_cost(1, true), 6.0, 0.0)
	_near("or kill tier 2 (coeff 1,5)", B.monster_gold(1.5, 4.0), 2.82, 0.0001)
	_near("XP kill tier 2 (coeff 1,5)", B.monster_xp(1.5, 4.0), 1.41, 0.0001)
	_near("crédits/s hors zone (coeff 1,5)", B.director_credits_per_s(1.5), 1.4304, 0.0001)
	_near("crédits/s zone d'étage (coeff 1,5)", B.director_credits_per_s(1.5, &"etage"), 3.3328, 0.0001)
	_near("xp_required(1)", B.xp_required(1), 7.2368, 0.001)
	_near("xp_required(5)", B.xp_required(5), 41.771, 0.005)
	var total := 0.0
	for l in range(1, 8):
		total += B.xp_required(l)
	_near("XP totale niveau 8 = (1,55^7 - 1) / 0,076", total, (pow(1.55, 7) - 1.0) / 0.076, 0.01)
	_near("PV boss d'étage (coeff 1,5, étage 1)", B.boss_hp(&"etage", 1.5, 1), 5254.2, 1.0) # base 3300 (audit PV boss 28/10)
	_near("PV mini-boss (coeff 2, étage 3)", B.boss_hp(&"mini", 2.0, 3), 3869.3, 1.0) # × 1,20^2 (BOSS_STAGE_K)
	_near("BOSS_STAGE_K", B.BOSS_STAGE_K, 1.20, 0.0)
	_near("boss final × 1,55", B.FINAL_BOSS_HP_MULT, 1.55, 0.0)
	_near("mode Difficile : boss d'étage × 0,85", B.boss_hp_mode_mult(&"etage", &"difficile"), 0.85, 0.0)
	_near("mode Moyen : × 1", B.boss_hp_mode_mult(&"etage", &"moyen"), 1.0, 0.0)
	_near("mode Difficile : mini-boss × 1", B.boss_hp_mode_mult(&"mini", &"difficile"), 1.0, 0.0)
	_near("charge du gros pilier 60 s", B.PILLAR_CHARGE_S, 60.0, 0.0)
	_near("dégâts boss d'étage (coeff 2)", B.boss_damage(&"etage", 2.0), 44.8, 0.001)
	_near("enrage à 90 s", B.boss_enrage_mult(90.0), 1.0, 0.0)
	_near("elite_chance(4.3) (pente 0,06)", B.elite_chance(4.3), 0.198, 0.001)
	_near("elite_chance plafond", B.elite_chance(20.0), 0.25, 0.0)
	_near("armure 10", B.armor_reduction(10), 0.0909, 0.001)
	_near("cooldown ×0,75", B.effective_cooldown(8.0, 0.75), 6.0, 0.001)
	_near("cooldown plancher 35 %", B.effective_cooldown(8.0, 0.1), 2.8, 0.001)
	# Hâte additive (audit des objets 28/10/2026) : 1 / (1 + H), bornée à [COOLDOWN_FLOOR, 1]
	_near("hâte 0", B.haste_cooldown_mult(0.0), 1.0, 0.0001)
	_near("hâte Chronomètre x1 (0,35)", B.haste_cooldown_mult(0.35), 0.7407, 0.0001)
	_near("hâte Chronomètre x3 (0,75)", B.haste_cooldown_mult(0.75), 0.5714, 0.0001)
	_near("hâte cumul communs (1,20)", B.haste_cooldown_mult(1.20), 0.4545, 0.0001)
	_near("hâte au plancher", B.haste_cooldown_mult(5.0), B.COOLDOWN_FLOOR, 0.0001)
	# Économie : coffres coeff^1,25 × 1,04^(étage-1), capsules 20 × coeff^1,25, pas de réserve d'étage
	_near("petit coffre (coeff 2, étage 3)", B.chest_price(&"petit", 2.0, 3), 128.62, 0.05)
	_near("légendaire = 8 petits", B.chest_price(&"legendaire", 1.3, 2) / B.chest_price(&"petit", 1.3, 2), 8.0, 0.0001)
	_near("capsule (coeff 1)", B.capsule_gold(1.0), 20.0, 0.0001)
	# Changement d'étage : or restant -> XP (0,5 × ½ = 0,25 XP par or)
	_near("or->XP 470 or", B.gold_to_xp(470.0, 2.09), 117.5, 0.01)
	_near("or->XP 0 or", B.gold_to_xp(0.0, 1.5), 0.0, 0.0001)
	_near("prime boss d'étage (coeff 2)", B.boss_gold(&"etage", 2.0), 56.4, 0.001)
	_near("XP boss d'étage = ½ or", B.boss_xp(&"etage", 2.0), 28.2, 0.001)
	B.free()
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


func _near(label: String, got: float, want: float, tol: float) -> void:
	var ok: bool = abs(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s %s : %.4f (attendu %.4f)" % ["ok  " if ok else "FAIL", label, got, want])
