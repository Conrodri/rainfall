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
	_near("PV boss d'étage (coeff 1,5, étage 1)", B.boss_hp(&"etage", 1.5, 1), 2627.1, 1.0) # base 3300 × BOSS_FOCUS_HP_MULT 0,5 (audit runs complètes 31/10 ; était 5254,2)
	_near("PV mini-boss (coeff 2, étage 3)", B.boss_hp(&"mini", 2.0, 3), 1477.9, 1.0) # × 0,55, BOSS_STAGE_K 1,0 (BOSS_FOCUS_HP_MULT ; audit 31/10, était 3869,3 à 1,20)
	_near("BOSS_STAGE_K", B.BOSS_STAGE_K, 1.0, 0.0) # audit runs complètes 31/10/2026 (était 1,20)
	_near("boss final × 1,35", B.FINAL_BOSS_HP_MULT, 1.35, 0.0) # audit runs complètes 31/10/2026 (était 1,55)
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
	# Économie : coffres coeff^1,25 × 1,04^(étage-1), capsules CAPSULE_GOLD (40) × coeff^1,25, pas de réserve d'étage
	_near("petit coffre (coeff 2, étage 3)", B.chest_price(&"petit", 2.0, 3), 128.62, 0.05)
	_near("légendaire = 8 petits", B.chest_price(&"legendaire", 1.3, 2) / B.chest_price(&"petit", 1.3, 2), 8.0, 0.0001)
	_near("capsule (coeff 1)", B.capsule_gold(1.0), B.CAPSULE_GOLD, 0.0001)
	# Changement d'étage : or restant -> XP (0,5 × ½ = 0,25 XP par or)
	_near("or->XP 470 or", B.gold_to_xp(470.0, 2.09), 117.5, 0.01)
	_near("or->XP 0 or", B.gold_to_xp(0.0, 1.5), 0.0, 0.0001)
	_near("prime boss d'étage (coeff 2)", B.boss_gold(&"etage", 2.0), 56.4, 0.001)
	_near("XP boss d'étage = ½ or", B.boss_xp(&"etage", 2.0), 28.2, 0.001)
	_multi(B)
	B.free()
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


## Coop 1-4 (docs/multi/Scaling_Multi.md §2.13, docs/Design_Multijoueur.md §4) : n = 1 rend exactement le solo.
func _multi(B) -> void:
	# n = 1 : égalité stricte avec les appels sans n (tolérance 0).
	for t in [0.0, 150.0, 600.0]:
		for st in [1, 3, 5]:
			for d in [1.0, 2.0, 3.0]:
				_near("D n=1 identique (t %d, étage %d, d %d)" % [t, st, d], B.difficulty(t, st, d, 1), B.difficulty(t, st, d), 0.0)
	for D in [1.0, 1.5, 3.33]:
		for z in [&"", &"mini", &"etage"]:
			_near("crédits n=1 identiques (D %.2f, %s)" % [D, z], B.director_credits_per_s(D, z, 1), B.director_credits_per_s(D, z), 0.0)
		for k in [&"mini", &"etage"]:
			_near("PV boss n=1 identiques (%s, D %.2f)" % [k, D], B.boss_hp(k, D, 3, 1), B.boss_hp(k, D, 3), 0.0)
	for t in [0.0, 240.0, 480.0, 900.0]:
		_near("plafond de vivants n=1 identique (t %d)" % t, B.director_alive_cap(t, 1), B.director_alive_cap(t), 0.0)
	_near("rubis n=1 identiques", B.run_rubies(18.0, &"moyen", 13, true, 1800.0, 1, 1.0), B.run_rubies(18.0, &"moyen", 13, true, 1800.0), 0.0)
	_near("coffres n=1 = base", B.coop_chest_count(8, 1), 8.0, 0.0)
	_near("or n=1 × 1", B.coop_gold_mult(1), 1.0, 0.0)
	_near("niveau de départ n=1", B.player_start_level(1), 1.0, 0.0)
	_near("participation solo = 1", B.ruby_participation(0.0, 1000.0, 1), 1.0, 0.0)
	# Facteurs (§2.2)
	_near("pf(2)", B.party_factor(2), 1.3, 0.0001)
	_near("pf(4)", B.party_factor(4), 1.9, 0.0001)
	_near("n^0,2 (4)", B.party_time_mult(4), 1.3195, 0.0001)
	_near("g(4) = 2,5", B.party_credit_mult(4), 2.5, 0.0)
	_near("pf borné à 4 joueurs", B.party_factor(9), 1.9, 0.0001)
	# D (§2.3) : entrée d'étage 1 = 1,3 / 1,6 / 1,9 ; 4 joueurs, Moyen, 10 min, étage 3 = 5,16
	_near("D départ 2 joueurs", B.difficulty(0.0, 1, 2.0, 2), 1.3, 0.0001)
	_near("D départ 3 joueurs", B.difficulty(0.0, 1, 2.0, 3), 1.6, 0.0001)
	_near("D 4 joueurs 10 min étage 3", B.difficulty(600.0, 3, 2.0, 4), 5.16, 0.005)
	_near("D 1 joueur 10 min étage 3", B.difficulty(600.0, 3, 2.0, 1), 3.33, 0.005)
	# Niveau de départ (§2.4) : 1 / 1 / 2 / 3
	_near("niveau de départ 2", B.player_start_level(2), 1.0, 0.0)
	_near("niveau de départ 3", B.player_start_level(3), 2.0, 0.0)
	_near("niveau de départ 4", B.player_start_level(4), 3.0, 0.0)
	_near("XP cumulée niveau 3", B.xp_total_for_level(3), B.xp_required(1) + B.xp_required(2), 0.0001)
	# Director (§2.5) : 6,85 crédits/s à D 5,16 hors zone à 4 ; plafond 150 -> 240
	_near("crédits/s 4 joueurs D 5,16", B.director_credits_per_s(5.16, &"", 4), 6.85, 0.01)
	_near("plafond 2 joueurs (pleine rampe)", B.director_alive_cap(480.0, 2), 180.0, 0.0)
	_near("plafond 4 joueurs (pleine rampe)", B.director_alive_cap(480.0, 4), 240.0, 0.0)
	_near("plafond 4 joueurs qualité Basse", B.director_alive_cap(480.0, 4, true), 150.0, 0.0)
	# Boss (décision du joueur §4) : étage × 1,4 / 2,2 ; mini × 1,3 / 1,9 ; final × 1,35 / 2,05
	var e1: float = B.boss_hp(&"etage", 2.0, 2)
	_near("boss d'étage 2 joueurs × 1,4", B.boss_hp(&"etage", 2.0, 2, 2) / e1, 1.4, 0.0001)
	_near("boss d'étage 4 joueurs × 2,2", B.boss_hp(&"etage", 2.0, 2, 4) / e1, 2.2, 0.0001)
	var m1: float = B.boss_hp(&"mini", 2.0, 2)
	_near("mini-boss 2 joueurs × 1,3", B.boss_hp(&"mini", 2.0, 2, 2) / m1, 1.3, 0.0001)
	_near("mini-boss 4 joueurs × 1,9", B.boss_hp(&"mini", 2.0, 2, 4) / m1, 1.9, 0.0001)
	_near("boss final 2 joueurs × 1,35", B.boss_hp(&"etage", 2.0, 5, 2, &"final") / B.boss_hp(&"etage", 2.0, 5), 1.35, 0.0001)
	_near("boss final 4 joueurs × 2,05", B.boss_party_hp_mult(&"final", 4), 2.05, 0.0001)
	_near("exemple §2.7 : 37 900 PV", B.boss_hp(&"etage", 5.16, 3, 4), 37900.0, 150.0)
	# Coffres +50 % par joueur en plus (provisoire) : 8 petits -> 12 / 16 / 20 ; 2 grands -> 3 / 4 / 5
	_near("petits coffres 2 joueurs", B.coop_chest_count(8, 2), 13.0, 0.0)
	_near("petits coffres 4 joueurs", B.coop_chest_count(8, 4), 22.0, 0.0)
	_near("grands coffres 3 joueurs", B.coop_chest_count(2, 3), 4.0, 0.0)
	_near("grands coffres 4 joueurs", B.coop_chest_count(2, 4), 6.0, 0.0)
	_near("1 coffre 2 joueurs (arrondi)", B.coop_chest_count(1, 2), 2.0, 0.0)
	_near("chance de légendaire 4 joueurs", B.party_chance(0.25, 4), 0.7, 0.0001)
	# Or : même montant crédité à chacun × coop_gold_mult = 2 / (n + 1) (or des kills par joueur = solo)
	for n in range(1, 5):
		_near("or × %d joueurs" % n, B.coop_gold_mult(n), 2.0 / (n + 1.0), 0.0001)
	# Rubis (§2.12) : exemple 152 à 4 joueurs ; participation
	_near("rubis 4 joueurs exemple §2.12", B.run_rubies(18.0, &"moyen", 13, true, 3000.0, 4, 1.0), 152.0, 0.0)
	_near("participation 25 % de la moyenne = 1", B.ruby_participation(250.0, 4000.0, 4), 1.0, 0.0001)
	_near("participation 10 % de la moyenne = 0,4", B.ruby_participation(100.0, 4000.0, 4), 0.4, 0.0001)
	_near("rubis AFK = 0", B.run_rubies(18.0, &"moyen", 13, true, 3000.0, 4, 0.0), 0.0, 0.0)
	_near("épreuves × 0,76 à 4", B.epreuve_target_party_mult(4), 0.76, 0.0001)
	_epreuves(B)


## Épreuves généralisées (docs/Design_Epreuves.md §8) : constantes, notes, PV de la cloche, dégâts du geyser, rubis.
func _epreuves(B) -> void:
	_near("épreuves : 2 par étage", B.EPREUVES_PER_STAGE, 2.0, 0.0)
	_near("épreuves : sans fin activé", 1.0 if B.EPREUVE_IN_ENDLESS else 0.0, 1.0, 0.0)
	_near("épreuves : drapeau global encore faux", 1.0 if not B.EPREUVES_ENABLED else 0.0, 1.0, 0.0)
	_near("épreuves : --no-epreuves coupe le drapeau", 1.0 if B.EPREUVES_OFF_ARG == "--no-epreuves" else 0.0, 1.0, 0.0)
	_near("épreuves : verbe partageable (rituel seul)", 1.0 if B.EPREUVE_SHARED_VERBS == [&"rituel"] else 0.0, 1.0, 0.0)
	for v in [&"escorte", &"rituel", &"poursuite", &"veine", &"tenue"]:
		_near("épreuves : dégagement du gros pilier [%s] présent" % v, 1.0 if float(B.EPREUVE_BIG_AVOID_U.get(v, 0.0)) > 0.0 else 0.0, 1.0, 0.0)
		_near("épreuves : cible de durée [%s] présente" % v, 1.0 if float(B.EPREUVE_TARGET_S.get(v, 0.0)) > 0.0 else 0.0, 1.0, 0.0)
	_near("dégagement gros pilier : veine 10 u", B.EPREUVE_BIG_AVOID_U[&"veine"], 10.0, 0.0)
	_near("dégagement gros pilier : poursuite 6 u", B.EPREUVE_BIG_AVOID_U[&"poursuite"], 6.0, 0.0)
	_near("dégagement gros pilier : tenue 12 u", B.EPREUVE_BIG_AVOID_U[&"tenue"], 12.0, 0.0)
	_near("coffres : 3 par épreuve, 3 arène, 1 départ", B.EPREUVE_CHEST_SPLIT[&"epreuve"] * 100 + B.EPREUVE_CHEST_SPLIT[&"arene"] * 10 + B.EPREUVE_CHEST_SPLIT[&"depart"], 331.0, 0.0)
	_near("rubis : 1 par parfait", B.EPREUVE_RUBIES_PARFAIT, 1.0, 0.0)
	_near("rubis : plafond 8", B.EPREUVE_RUBIES_CAP, 8.0, 0.0)
	_near("rubis : 5 parfaits = 5", B.epreuve_rubies(5), 5.0, 0.0)
	_near("rubis : 12 parfaits plafonnés à 8", B.epreuve_rubies(12), 8.0, 0.0)
	_near("rubis : négatif = 0", B.epreuve_rubies(-3), 0.0, 0.0)
	# Poursuite
	_near("poursuite : 6 bornes, 5 points", B.CHASE_POSTS * 10 + B.CHASE_POINTS, 65.0, 0.0)
	_near("poursuite : saut 8 s", B.CHASE_JUMP_S, 8.0, 0.0)
	_near("poursuite : portée de saut 9-17 u", B.CHASE_JUMP_MIN_U * 100 + B.CHASE_JUMP_MAX_U, 917.0, 0.0)
	_near("poursuite : borne 2 u, vacillement 1,5 s", B.CHASE_REACH_U * 10 + B.CHASE_WARN_S, 21.5, 0.0001)
	_near("poursuite : vacillement < saut", 1.0 if B.CHASE_WARN_S < B.CHASE_JUMP_S else 0.0, 1.0, 0.0)
	_near("poursuite : cible 40 s >= CHASE_POINTS x CHASE_JUMP_S", 1.0 if float(B.EPREUVE_TARGET_S[&"poursuite"]) >= float(B.CHASE_POINTS) * B.CHASE_JUMP_S and is_equal_approx(float(B.EPREUVE_TARGET_S[&"poursuite"]), 40.0) else 0.0, 1.0, 0.0)
	_near("épreuves : or 0,8 / 0,5 / 0,2 P, kills en zone x 0,4", float(B.EPREUVE_GOLD_P[&"parfait"]) * 1000 + float(B.EPREUVE_GOLD_P[&"bien"]) * 100 + float(B.EPREUVE_GOLD_P[&"fait"]) * 10 + B.EPREUVE_ZONE_GOLD_MULT, 852.4, 0.0001)
	_near("épreuves : coffres >= 3 u d'un objet d'épreuve", B.EPREUVE_CHEST_MIN_U, 3.0, 0.0)
	# Veine
	_near("veine : disque 6 u à 1,5 u/s, charge 30 s", B.VEIN_RADIUS_U * 10000 + B.VEIN_SPEED_U * 100 + B.VEIN_CHARGE_S, 60180.0, 0.0001)
	_near("veine : tracé 40-70 u", B.VEIN_LOOP_MIN_U * 100 + B.VEIN_LOOP_MAX_U, 4070.0, 0.0)
	_near("veine : geyser toutes les 6 s", B.VEIN_GEYSER_EVERY_S, 6.0, 0.0)
	_near("veine : télégraphe du geyser >= 0,8 s", 1.0 if B.VEIN_GEYSER_TELEGRAPH_S >= 0.8 else 0.0, 1.0, 0.0)
	_near("veine : geyser rayon 2 u, 0,75 u devant, télégraphe 1,2 s, sous le joueur", B.VEIN_GEYSER_RADIUS_U * 100 + B.VEIN_GEYSER_AHEAD_U * 100 + B.VEIN_GEYSER_TELEGRAPH_S * 10 + (1.0 if B.VEIN_GEYSER_ON_PLAYER else 0.0), 288.0, 0.0001)
	_near("veine : dégât du geyser = coup de mini-boss", B.vein_geyser_damage(2.0), B.mini_attack_damage(B.boss_damage(&"mini", 2.0), B.VEIN_GEYSER_COEF), 0.0001)
	_near("veine : dégât croît avec D", 1.0 if B.vein_geyser_damage(3.0) > B.vein_geyser_damage(2.0) else 0.0, 1.0, 0.0)
	# Tenue
	_near("tenue : 40 s, paquet de 4 toutes les 8 s, annonce 2 s", B.HOLD_DURATION_S * 100 + B.HOLD_PACKET * 10 + B.HOLD_WAVE_EVERY_S, 4048.0, 0.0001)
	_near("tenue : 3 côtés, annonce >= 0,8 s", B.HOLD_SIDES + (1.0 if B.HOLD_ANNOUNCE_S >= 0.8 else 0.0), 4.0, 0.0)
	_near("tenue : apparition 10 u, leurre rompu à 3 u", B.HOLD_SPAWN_DIST_U * 10 + B.HOLD_LURE_BREAK_U, 103.0, 0.0001)
	_near("tenue : PV de la cloche = 0,5 x mini-boss", B.hold_hp(2.0, 3), 0.5 * B.boss_hp(&"mini", 2.0, 3), 0.0001)
	_near("tenue : PV x1,3 à 2 joueurs", B.hold_hp(2.0, 1, 2) / B.hold_hp(2.0, 1, 1), 1.3, 0.0001)
	_near("tenue : PV x1,6 à 3 joueurs", B.hold_hp(2.0, 1, 3) / B.hold_hp(2.0, 1, 1), 1.6, 0.0001)
	_near("tenue : PV x1,9 à 4 joueurs", B.hold_hp(2.0, 1, 4) / B.hold_hp(2.0, 1, 1), 1.9, 0.0001)
	_near("tenue : PV croissants avec D", 1.0 if B.hold_hp(3.0) > B.hold_hp(2.0) else 0.0, 1.0, 0.0)
	_near("tenue : 100 % des PV = parfait", 1.0 if B.epreuve_grade_hold(1.0) == &"parfait" else 0.0, 1.0, 0.0)
	_near("tenue : 70 % des PV = parfait", 1.0 if B.epreuve_grade_hold(0.7) == &"parfait" else 0.0, 1.0, 0.0)
	_near("tenue : 69 % des PV = bien", 1.0 if B.epreuve_grade_hold(0.69) == &"bien" else 0.0, 1.0, 0.0)
	_near("tenue : cloche éteinte = fait", 1.0 if B.epreuve_grade_hold(0.0) == &"fait" else 0.0, 1.0, 0.0)


func _near(label: String, got: float, want: float, tol: float) -> void:
	var ok: bool = abs(got - want) <= tol
	if not ok:
		_fails += 1
	print("%s %s : %.4f (attendu %.4f)" % ["ok  " if ok else "FAIL", label, got, want])
