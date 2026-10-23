#!/usr/bin/env python3
# REMPLACÉ en partie (21/10/2026) : les formules de difficulté, director, monstres, boss, économie et
# niveau suivent désormais docs/Maths_Scaling.md §14 (Alignement RoR2, game/scripts/core/balance.gd).
# Ce simulateur garde l'ancien modèle v3 pour l'historique.
"""
Simulateur "champ moyen" v2 : étages avec coffres posés au départ et système de piliers.

Déroulé d'un étage (joueur efficace) :
  explorer et acheter des coffres -> pilier A (mini-boss + zone de combat, sans jauge) -> pilier B (idem)
  -> gros pilier (boss d'étage + zone, jauge de 90 s) -> option : farmer l'or restant -> étage suivant.
Un petit pilier est terminé à la mort de son mini-boss ; le gros pilier quand sa zone est chargée
(la jauge n'avance que si le joueur est dedans) ET que le boss d'étage est mort.

Le script estime seconde par seconde : difficulté D, kills, or, XP, achats de coffres, DPS du joueur,
durée des combats de boss, durée de l'étage et de la run.

Usage :
    python3 simulateur_scaling.py                 # config par défaut + tableau des durées de run
    python3 simulateur_scaling.py 1.5             # palier de difficulté d = 1.5
"""
import sys

# ----------------------------------------------------------------- constantes à calibrer
K_TEMPS = 0.30            # pente de D par minute de jeu actif
K_STAGE = 1.15            # multiplicateur de D à chaque nouvel étage
CRED_A, CRED_B = 4.0, 2.5 # crédits/s du director = A + B x D
COST_GROWTH = 0.5         # coût moyen d'un monstre = 1 + COST_GROWTH x (D-1)
KILL_EFF = 0.85           # part des monstres spawnés effectivement tués
MIX_GAIN = 0.30           # multiplicateur moyen or/xp du mix de tiers et d'élites = 1 + MIX_GAIN x (D-1)
XP_BASE = 0.16            # XP d'un monstre tier 1 à D=1
OR_EXPO, XP_EXPO, PV_EXPO = 1.25, 0.80, 1.15
BOSS_EXPO = 1.60          # exposant de D pour les PV des boss (la puissance du joueur monte plus vite que celle des monstres normaux)

# piliers et étages
STAGES = 3                # étages de la run "terminer" (au boss d'étage 3 : terminer ou continuer en sans fin)
CHARGE_PETIT = 0          # petits piliers : pas de jauge, terminés à la mort du mini-boss (zone active pendant le combat)
CHARGE_GROS = 90          # charge du gros pilier (s)
START_DELAY = 30          # temps avant d'activer le premier pilier (explorer, acheter)
WALK_S = 15               # trajet entre deux piliers
FARM_S = 0                # temps passé à farmer après le boss d'étage (0 = on passe directement)
EXIT_S = 5                # interaction + chargement du niveau suivant
ZONE_SPAWN_MULT = 1.5     # multiplicateur de crédits du director dans une zone active

# coffres posés au départ de chaque étage (coût de base à D=1)
COUT = {"petit": 150, "large": 300}     # large = 2x petit ; coffre légendaire = 1 200 (8x petit), non simulé
COFFRES_PAR_ETAGE = {"petit": 8, "large": 2}   # + coffre légendaire 25 % du temps (non simulé) + coffre du boss d'étage
PRICE_STAGE = 1.05        # surcoût par étage en plus de D (D inclut déjà temps et x1.15/étage)
ACHAT_DELAI = 6           # temps de trajet/interaction entre deux achats (s)

# boss : PV = base x D^1.15
BOSS_BASE = {"mini": 1300, "etage": 2200}
BOUNTY_OR = {"mini": 100, "etage": 250}        # en équivalents de kills tier 1 : x D^1.25
BOUNTY_XP = {"mini": 40, "etage": 100}         # en équivalents de kills tier 1 : x XP_BASE x D^0.8


# modes de jeu = vitesse de scaling du temps (d). Plus de Fureur : la pression de fin de run vient du scaling seul.
MODES = {"facile": 0.7, "moyen": 1.0, "difficile": 1.5}
ENDLESS_FROM = 4          # à partir de l'étage 4 (sans fin), le scaling s'accélère
ENDLESS_TIME_X = 1.5      # pente de temps x1.5
ENDLESS_STAGE = 1.25      # multiplicateur par étage 1.25 au lieu de 1.15


def difficulte(t_s, stage, d=1.0):
    pente = K_TEMPS * d * (ENDLESS_TIME_X if stage >= ENDLESS_FROM else 1.0)
    k_stage = ENDLESS_STAGE if stage >= ENDLESS_FROM else K_STAGE
    return (1 + pente * t_s / 60) * k_stage ** (stage - 1)


def xp_requis(niveau):
    return 10 + 8 * niveau + 0.5 * niveau ** 2


def kills_par_seconde(D):
    return (CRED_A + CRED_B * D) / (1 + COST_GROWTH * (D - 1)) * KILL_EFF


def mix(D):
    return 1 + MIX_GAIN * (D - 1)


def dps_mono_cible(niveau, nb_items):
    """DPS théorique sur une cible : auto 0.8/0.6s + mono 6/8s + zone 3/6s + ultime 10/20s."""
    degat = 12 + 2.4 * (niveau - 1)
    return 3.08 * degat * (1 + 0.12 * nb_items) * (1 + 0.03 * nb_items)


def simuler(d=1.0, stages=None, charge=None, farm=None, verbose=False):
    """charge = None (45 s petits / 90 s gros) ou (petit, gros) en secondes."""
    stages = STAGES if stages is None else stages
    charge_p, charge_g = (CHARGE_PETIT, CHARGE_GROS) if charge is None else charge
    farm = FARM_S if farm is None else farm
    t = 0.0
    or_, xp, niveau, kills, items = 0.0, 0.0, 1, 0.0, 0
    journal, etages, snaps = [], [], {}
    prochain_achat = 0.0
    for stage in range(1, stages + 1):
        t_debut = t
        file_coffres = sorted(["petit"] * COFFRES_PAR_ETAGE["petit"] + ["large"] * COFFRES_PAR_ETAGE["large"],
                              key=lambda k: COUT[k])
        acheves = 0
        # phases : (nom, durée fixe ou None si dépend du boss, zone active ?, boss)
        phases = [("explorer", START_DELAY, False, None),
                  ("pilier A", None, True, "mini"), ("trajet", WALK_S, False, None),
                  ("pilier B", None, True, "mini"), ("trajet", WALK_S, False, None),
                  ("gros pilier", None, True, "etage")]
        if farm > 0: phases.append(("farm", farm, False, None))
        phases.append(("sortie", EXIT_S, False, None))
        boss_infos = []
        for nom, duree, zone, boss in phases:
            if boss:
                D0 = difficulte(t, stage, d)
                pv = BOSS_BASE[boss] * D0 ** BOSS_EXPO
                ttk = pv / dps_mono_cible(niveau, items)
                duree = max(charge_g if boss == "etage" else charge_p, ttk)
                boss_infos.append((nom, boss, t, D0, pv, dps_mono_cible(niveau, items), ttk))
                t_kill = t + ttk
                tue = False
            fin = t + duree
            while t < fin:
                D = difficulte(t, stage, d)
                k = kills_par_seconde(D) * (ZONE_SPAWN_MULT if zone else 1.0)
                kills += k
                or_ += k * D ** OR_EXPO * mix(D)
                xp += k * XP_BASE * D ** XP_EXPO * mix(D)
                if boss and not tue and t >= t_kill:
                    tue = True
                    or_ += BOUNTY_OR[boss] * D ** OR_EXPO
                    xp += BOUNTY_XP[boss] * XP_BASE * D ** XP_EXPO
                    if boss == "etage": items += 1          # coffre du boss d'étage (Rare ou mieux)
                while xp >= xp_requis(niveau):
                    xp -= xp_requis(niveau); niveau += 1
                if file_coffres and t >= prochain_achat:
                    prix = COUT[file_coffres[0]] * D ** OR_EXPO * mix(D) * PRICE_STAGE ** (stage - 1)
                    if or_ >= prix:
                        or_ -= prix; file_coffres.pop(0); items += 1; acheves += 1
                        prochain_achat = t + ACHAT_DELAI
                        journal.append((round(t), stage, "achat", file_coffres and 1 or 0))
                t += 1.0
                for rep in (150, 300, 450, 600):
                    if int(t) == rep: snaps[rep] = (D, kills, niveau, items, dps_mono_cible(niveau, items))
        t += 0
        etages.append(dict(stage=stage, debut=t_debut, fin=t, duree=t - t_debut, niveau=niveau, items=items,
                           or_restant=or_, coffres_achetes=acheves, coffres_total=sum(COFFRES_PAR_ETAGE.values()),
                           bosses=boss_infos, D_fin=difficulte(t, stage, d)))
    return dict(duree=t, etages=etages, kills=kills, niveau=niveau, items=items, snaps=snaps, journal=journal)


def fmt(t):
    return f"{int(t // 60)}:{int(t % 60):02d}"


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "moyen"
    d = MODES.get(arg) or float(arg)
    r = simuler(d)
    print(f"Mode {arg} (d = {d}) | {STAGES} étages | charge {CHARGE_PETIT} s (petits) / {CHARGE_GROS} s (gros) | farm {FARM_S} s | zone x{ZONE_SPAWN_MULT} spawn")
    print(f"Durée de la run : {fmt(r['duree'])} | kills : {r['kills']:.0f} | niveau final : {r['niveau']} | items : {r['items']}")
    for e in r["etages"]:
        print(f"\nÉtage {e['stage']} : {fmt(e['debut'])} -> {fmt(e['fin'])} ({fmt(e['duree'])}) | "
              f"coffres achetés {e['coffres_achetes']}/{e['coffres_total']} | or restant {e['or_restant']:.0f} | "
              f"niveau {e['niveau']} | items {e['items']} | D en fin d'étage {e['D_fin']:.2f}")
        for nom, boss, t0, D0, pv, dps, ttk in e["bosses"]:
            print(f"   {nom:12s} ({boss:5s}) actif à {fmt(t0)} | D {D0:5.2f} | PV {pv:7.0f} | DPS {dps:5.0f} | combat {ttk:5.1f} s")
    print("\nRepères (pour le classeur d'items) : t(s) -> D, kills, niveau, items, DPS mono")
    for rep, (D, k, n, it, dps) in sorted(r["snaps"].items()):
        print(f"  {rep:4d} s : D {D:5.2f} | kills {k:6.0f} | niveau {n:2d} | items {it:2d} | DPS {dps:5.0f}")
    print("\nDurée de run selon la configuration (farm 0 s) :")
    print(f"{'étages':>7} {'charge petit/gros':>18} {'durée':>8}")
    for st in (2, 3):
        for ch in ((0, 90), (30, 90), (45, 90), (60, 90), (90, 90)):
            rr = simuler(d, stages=st, charge=ch, farm=0)
            print(f"{st:7d} {ch[0]:>8d}s /{ch[1]:>4d}s {fmt(rr['duree']):>8}")
