# Reprise lot 5 variantes Averse (23/10/2026, arrêt quota)
Fait : averse_kit.gd (variant(), Bruine/Geyser/Gouttière/Mousson, compteurs averse.soaked / averse.puddle_water / averse.full_crues), averse_rivulet.gd, averse_geyser_fx.gd (placeholders code), 4 variantes dans characters.json (entrée averse), tests/averse_variants_test.tscn RESULT: OK, brief art/tools/night/_avsv.txt + groupe 35 dans queue.txt.
Pas fait : mesure balance_sim (±15 % DPS cible/zone, L1/L6/L12, avec/sans variantes) ; coefs NON ajustés. averse_test, test_balance, boss_pace_test, integration_test non relancés après les modifs (averse_test lancé en fond, sortie vide).
Valeurs de départ (design brut) : BRUINE_COEF_MIN 0.30 + 0.15 x eau/100 (x3) ; GEYSER_COEF 3.5, rayon 2 u ; GOUTTIERE_COEF 0.45 (comme Flaque de base), ligne 6x1 u ; MOUSSON_TOTAL_MULT 1.0 (total = crue_coef(eau), réparti en 13 coups).
Mesure à faire : game/tests/_tmp_averse_dps.gd (+ _tmp_averse_dps_kit.gd, _tmp_sim.gd) avec sim.loadout = {slot: id} avant load_character ; comparer dmg par slot (slot_dps) variante vs base ; ajuster seulement les coefs.
Supprimer en fin de lot : game/tests/_tmp_sim.gd, _tmp_averse_dps.gd/.tscn, _tmp_averse_dps_kit.gd (+ .uid), _tmp_averse_cap.* ; supprimer ce fichier.
Branchement visuel restant (après lot AVSV) : rivulet_tile (tuile UV non branchée), vérifier geyser/monsoon_zone/droplet_small (chemins variants/<nom>/<nom>.tres déjà lus par le kit).
Notes : boss non projeté par le Geyser (trempe 30 % 4 s seulement) ; Mousson garde CRUE_CD 12 s (anti-boucle).
