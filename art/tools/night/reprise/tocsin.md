# Reprise lot 6 variantes Tocsin (arrêt quota, 23/10/2026)
FAIT : 4 variantes codées + déclarées. tocsin_variants_test OK, tocsin_test OK.
- game/scripts/spells/tocsin_kit.gd : V_VAPEUR/V_HARPON/V_RESSORTS/V_FUMIGENE, variant(), _cast_vapeur, begin_pull/_pull_step, _cast_spring/_jump_step/_land_spring, shockwave, compteurs tocsin.imprisoned / tocsin.pushed / tocsin.headless_boss_kills.
- game/scripts/spells/tocsin_limb.gd : flags harpoon (HOOKED, câble) et smoke (SMOKE, 10 ticks) ; _push devenu static.
- game/scripts/spells/tocsin_steam_fx.gd (nouveau, placeholder code), game/tests/tocsin_variants_test.gd/.tscn, game/data/characters.json (entrée tocsin : 4 variants).
VALEURS DE DÉPART (NON MESURÉES) : VAPEUR_COEF 0,55 ; HARPON_COEF 1,8 ; RESSORTS_COEF 3,0 ; FUMI_COEF 1,25 par tick (10 ticks). HEAD_COEF 10 et PICKUP_CD_REFUND 0,5 inchangés.
RESTE : 1) balance_sim --chars ardent,tocsin --seeds 3, base vs --loadout=1:tocsin_vapeur etc. ; chaque variante ±15 % du sort de base, sinon ajuster le coef (jamais le style). Harpon (1 cible) risque d'être très sous le base : coef à monter. 2) brief art/tools/night/_tocv.txt (steam_cone, steam_ring TOP 5 ; head_smoke_zone TOP 8 boucle + end 4 ; stomp_ring ; câble harpon ; format _ricv.txt, cel, sans _n, _e demi-rés.) + ligne en fin de queue.txt (groupe max+1, relire). 3) boss_pace_test, integration_test, test_balance non relancés.
ÉCART : « sans tête 5 s de plus » de la Tête-fumigène non codé (recharge 22 s inchangée, ambigu).
CONTRAT : aucun ajout dans player.gd / spell_caster.gd (move_swept, grant_invulnerability, Visual.position.y suffisent). Compteurs en clés pointées « tocsin.* » (Annexe B disait tocsin_*).
