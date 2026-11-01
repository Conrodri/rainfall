"""Simulation rapide du multijoueur 1-4 joueurs (modèle champ moyen, estimé, non mesuré en jeu).

Étude docs/multi/Scaling_Multi.md. Ne touche ni à docs/simulateur_scaling.py (modèle v3 historique)
ni au jeu : les constantes ci-dessous sont recopiées de game/scripts/core/balance.gd (01/11/2026).

Principe
--------
- Une run de 5 étages en Moyen (diff 2), rythme visé de docs/Ateliers_Chiffres.md §0 : étages 1-4 =
  exploration 15 s, mini A, trajet 30 s, mini B, trajet 25 s, gros pilier max(charge 60 s, combat du boss),
  sortie et achats 30 s ; étage 5 = 45 s puis boss final.
- Le DPS solo est CALIBRÉ par étage pour retrouver les TTK visés en solo (mini 25 s, boss d'étage 70 s,
  boss final 135 s) : il encode « les objets moyens réalistes » mesurés en jeu. Le multijoueur modifie
  ensuite ce DPS par le niveau (dégât de base 12 + 2,4/niv) et par les points d'objets du joueur.
- Or des kills = 2 × D × crédits dépensés × R, partagé à parts égales ; XP = D × crédits × R, entière
  pour chaque joueur (RoR2). Coffres achetés dans l'ordre petit puis grand, limités par l'or du joueur et
  par sa part des coffres posés. Coffre de boss : un par joueur.
- Pression : rho = PV de monstres apparus par seconde / capacité de nettoyage de l'équipe. Gravité d'un
  coup = dégât de contact d'un essaim / PV max du joueur. Les deux sont rapportés au solo.

Usage : python docs/multi/sim_multi.py [variante]   (ror2, boss_demi, boss_demi_pf02, boss_04, reco, sens ; défaut : toutes + sens)
"""
import math
import sys

# --- Constantes du jeu (balance.gd) ---
TIME_SLOPE, TIME_COMPRESSION, K_STAGE, DIFF = 0.0506, 1.5, 1.15, 2.0  # Moyen
CREDIT_K = 0.894
ZONE = {"": 1.0, "mini": 1.5, "etage": 2.33}
RAMP_TIME_S, RAMP_CREDITS_MIN = 480.0, 0.2
RAMP_ALIVE_MIN, RAMP_ALIVE_MAX = 8, 150
MEAN_COST_SLOPE = 0.55
REWARD = 0.235
ELITE_SLOPE, ELITE_MAX = 0.06, 0.25
BOSS_BASE_HP = {"mini": 1000.0, "etage": 3300.0}
BOSS_FOCUS = {"mini": 0.55, "etage": 0.5}
FINAL_MULT = 1.35
BOSS_VALUE = {"mini": 25.0, "etage": 60.0}
LEVEL_HP_GROWTH, LEVEL_DMG_GROWTH = 0.30, 0.20
CHEST_BASE = {"petit": 50.0, "large": 100.0, "legendaire": 400.0}
CHEST_STAGE = 1.04
CAPSULES, CAPSULE_GOLD = 4, 40.0
LEVEL_K, LEVEL_GROWTH = 0.076, 1.55
GOLD_TO_XP = 0.25
PILLAR_CHARGE_S = 60.0

# --- Hypothèses du modèle (estimées) ---
HP_PER_CREDIT = 19.0        # PV par crédit au niveau 1 (essaim 18/1, tireur 90/5, brute 360/16)
HP_GROWTH_MIX = 0.35        # croissance moyenne des PV par niveau ambiant (0,33 / 0,36 / 0,40)
AOE_FACTOR = 2.0            # DPS de nettoyage de foule / DPS mono-cible (Maths §9 : zone ≈ ×2,5)
DPS_SHARE = 0.6             # part des points d'objets qui va au DPS (le reste : survie)
PTS = {"petit": 13.2, "large": 29.0, "boss": 26.2, "legendaire": 120.0}  # Items_Catalog §1
KILL_FRAC_SOLO = 0.95
TTK_TARGET = {"mini": 25.0, "etage": 70.0, "final": 135.0}
OVERHEAD_1_4 = 15 + 30 + 25 + 30  # exploration, trajets, sortie (hors combats)
SWARM_DMG = 5.0             # dégât de contact d'un essaim (TIER_STATS[1].dmg)
SWARM_HP = 18.0
AUTO_COEF = 0.8             # coefficient du sort 1


def monster_level(D):
    return 1 + math.floor((D - 1.0) / 0.33)


def monster_level_f(D):  # version continue pour les moyennes
    return 1 + (D - 1.0) / 0.33


def player_level(xp):
    return 1 + math.log(1 + LEVEL_K * xp, LEVEL_GROWTH)


def base_dmg(L):
    return 12.0 + 2.4 * (L - 1)


def max_hp(L):
    return 100.0 + 30.0 * (L - 1)


def ramp(t):
    return min(1.0, max(RAMP_CREDITS_MIN, RAMP_CREDITS_MIN + (1 - RAMP_CREDITS_MIN) * t / (RAMP_TIME_S * 0.5)))


def alive_cap(t, n, v):
    base = RAMP_ALIVE_MIN + (RAMP_ALIVE_MAX - RAMP_ALIVE_MIN) * min(1.0, t / RAMP_TIME_S)
    return base * v["alive_mult"](n)


# --- Variantes de transposition ---
ROR2 = {
    # RoR2 tel quel : playerFactor 1 + 0,3 (n-1), temps × n^0,2, crédits × (n+1)/2, coffres +50 %/joueur,
    # boss (mini compris) PV × n vivants, or partagé, XP entière, un coffre de boss par joueur.
    "player_factor": lambda n: 1 + 0.3 * (n - 1),
    "time_mult": lambda n: n ** 0.2,
    "credit_mult": lambda n: (n + 1) / 2,
    "chest_mult": lambda n: 1 + 0.5 * (n - 1),
    "boss_hp_mult": lambda n: n,
    "mini_hp_mult": lambda n: n,
    "capsule_mult": lambda n: 1 + 0.5 * (n - 1),
    "bounty_mult": lambda n: 1.0,
    "alive_mult": lambda n: 1.0,
    "charge_s": lambda n: PILLAR_CHARGE_S,
}


def variant(**over):
    v = dict(ROR2)
    v.update(over)
    return v


HALF = lambda n: (n + 1) / 2  # noqa: E731
VARIANTS = {
    "ror2": variant(),
    # B : PV des boss et mini-boss × (n+1)/2 au lieu de × n (même facteur que les crédits du director)
    "boss_demi": variant(boss_hp_mult=HALF, mini_hp_mult=HALF, bounty_mult=HALF, alive_mult=lambda n: 1 + 0.2 * (n - 1)),
    # C : B + facteur joueur 1 + 0,2 (n-1) (au lieu de 0,3)
    "boss_demi_pf02": variant(player_factor=lambda n: 1 + 0.2 * (n - 1), boss_hp_mult=HALF, mini_hp_mult=HALF,
                              bounty_mult=HALF, alive_mult=lambda n: 1 + 0.2 * (n - 1)),
    # D : RoR2 pour D, director, coffres ; tous les boss × (1 + 0,4 (n-1))
    "boss_04": variant(boss_hp_mult=lambda n: 1 + 0.4 * (n - 1), mini_hp_mult=lambda n: 1 + 0.4 * (n - 1),
                       bounty_mult=HALF, alive_mult=lambda n: 1 + 0.2 * (n - 1)),
    # E (recommandée) : D avec mini-boss × (1 + 0,3 (n-1)) et boss final × (1 + 0,35 (n-1))
    "reco": variant(boss_hp_mult=lambda n: 1 + 0.4 * (n - 1), mini_hp_mult=lambda n: 1 + 0.3 * (n - 1),
                    final_hp_mult=lambda n: 1 + 0.35 * (n - 1),
                    bounty_mult=HALF, alive_mult=lambda n: 1 + 0.2 * (n - 1),
                    # les joueurs démarrent au niveau ambiant du départ (monster_level(D(0, 1, n)))
                    start_level=lambda n: monster_level(1 + 0.3 * (n - 1))),
}


def difficulty(t_s, stage, n, v):
    return (v["player_factor"](n) + t_s / 60.0 * TIME_SLOPE * DIFF * TIME_COMPRESSION * v["time_mult"](n)) * K_STAGE ** (stage - 1)


def boss_hp(kind, D, stage, n, v):
    k = "etage" if kind in ("etage", "final") else "mini"
    hp = BOSS_BASE_HP[k] * BOSS_FOCUS[k] * (1 + LEVEL_HP_GROWTH * (monster_level(D) - 1)) * math.sqrt(D)
    if kind == "final":
        hp *= FINAL_MULT
    if kind == "final":
        return hp * v.get("final_hp_mult", v["boss_hp_mult"])(n)
    return hp * (v["mini_hp_mult"](n) if k == "mini" else v["boss_hp_mult"](n))


def hp_per_credit(D):
    pe = min(ELITE_MAX, max(0.0, ELITE_SLOPE * (D - 1)))
    # une élite : PV ×4 pour un coût ×6 -> 0,67 PV par crédit relatif
    return HP_PER_CREDIT * (1 + HP_GROWTH_MIX * (monster_level_f(D) - 1)) * (1 - pe + pe * 4 / 6)


def mean_cost(D):
    pe = min(ELITE_MAX, max(0.0, ELITE_SLOPE * (D - 1)))
    return (1 + MEAN_COST_SLOPE * (D - 1)) * (1 + 5 * pe)


class Phase:
    def __init__(self, name, dur, zone, boss=None):
        self.name, self.dur, self.zone, self.boss = name, dur, zone, boss


def run(n, v, calib=None, active=None):
    """Une run. `calib` = DPS mono solo de référence par (étage, combat) ; None = mode calibration solo.
    `active` = joueurs qui jouent vraiment (les autres sont comptés dans le scaling mais ne font rien : AFK)."""
    act = n if active is None else active
    t = 0.0
    # niveau de départ (option « niveau ambiant de départ ») : XP cumulée jusqu'à ce niveau
    L0 = v.get("start_level", lambda k: 1)(n)
    xp = sum((LEVEL_GROWTH - 1) / LEVEL_K * LEVEL_GROWTH ** (k - 1) for k in range(1, L0))
    items_pts = 0.0          # points d'objets d'UN joueur
    items_cnt = 0.0
    out = {"floors": [], "calib": {}}
    for s in range(1, 6):
        gold = 0.0           # or d'UN joueur (bourse individuelle)
        D0 = difficulty(t, s, n, v)
        P = CHEST_BASE["petit"] * D0 ** 1.25 * CHEST_STAGE ** (s - 1)
        cm = v["chest_mult"](n)
        avail_small = 8 * cm / n
        avail_large = 2 * cm / n
        bought = {"petit": 0.0, "large": 0.0}
        floor_t0 = t
        fights = ["mini", "mini", "etage"] if s < 5 else ["final"]
        fight_ttk = {}
        rho_acc = sev_acc = dur_acc = alive_max = 0.0
        swarm_hits = []
        # capsules au début de l'étage (D figé), part de l'équipe
        gold += CAPSULES * v["capsule_mult"](n) * CAPSULE_GOLD * D0 ** 1.25 / n
        seq = []
        if s < 5:
            seq = [("explo", 15, ""), ("mini", None, "mini"), ("trajet", 30, ""), ("mini", None, "mini"),
                   ("trajet", 25, ""), ("etage", None, "etage"), ("sortie", 30, "")]
        else:
            seq = [("explo", 45, ""), ("final", None, "etage")]
        fi = 0
        for name, dur, zone in seq:
            # puissance du joueur à ce moment : niveau courant, objets possédés
            L = player_level(xp)
            dmg_mult = 1 + DPS_SHARE * items_pts / 100.0
            ehp_mult = 1 + (1 - DPS_SHARE) * items_pts / 100.0
            D_mid = difficulty(t + (dur or 30) / 2, s, n, v)
            if name in ("mini", "etage", "final"):
                hp = boss_hp(name, D_mid, s, n, v)
                key = (s, fi)
                if calib is None:
                    ttk = TTK_TARGET[name]
                    out["calib"][key] = (hp / ttk, base_dmg(L) * dmg_mult)  # DPS mono solo visé, puissance brute
                    dps_mono = hp / ttk
                else:
                    ref_dps, ref_pow = calib[key]
                    dps_mono = ref_dps * base_dmg(L) * dmg_mult / ref_pow
                    ttk = hp / (act * dps_mono)
                fight_ttk[name + str(fi)] = ttk
                fi += 1
                dur = max(ttk, v["charge_s"](n)) if name == "etage" else ttk
                # prime du boss (partagée), XP entière
                bkind = "mini" if name == "mini" else "etage"
                bgold = 2 * D_mid * BOSS_VALUE[bkind] * REWARD * v["bounty_mult"](n)
                gold += bgold / n
                xp += 0.5 * bgold / v["bounty_mult"](n)
            else:
                # DPS mono hors combat : celui du dernier combat calibré, à défaut le premier
                key = (s, 0)
                if calib is None:
                    dps_mono = out["calib"].get(key, (base_dmg(L) * dmg_mult * 1.0,))[0] if key in out["calib"] else None
                    if dps_mono is None:
                        hpm = boss_hp("mini", D_mid, s, n, v)
                        dps_mono = hpm / TTK_TARGET["mini"]
                else:
                    ref_dps, ref_pow = calib[key]
                    dps_mono = ref_dps * base_dmg(L) * dmg_mult / ref_pow
            # flux de monstres pendant la phase (pas de 1 s)
            steps = int(math.ceil(dur))
            for i in range(steps):
                dt = min(1.0, dur - i)
                D = difficulty(t, s, n, v)
                credits = CREDIT_K * (1 + 0.4 * D) * ZONE[zone] * ramp(t) * v["credit_mult"](n)
                inc_hp = credits * hp_per_credit(D)
                clear = act * dps_mono * AOE_FACTOR * (0.5 if zone in ("mini", "etage") else 1.0)
                rho = inc_hp / clear
                kill_frac = KILL_FRAC_SOLO if rho <= 1.0 else KILL_FRAC_SOLO / rho
                # vivants estimés : apparitions/s × durée de vie (8 s au rho de référence 1)
                alive = credits / mean_cost(D) * 8.0 * max(rho, 0.3)
                alive_max = max(alive_max, min(alive, alive_cap(t, n, v)) / n)
                gold += 2 * D * credits * REWARD * kill_frac * dt / n
                xp += D * credits * REWARD * kill_frac * dt
                L = player_level(xp)
                sev = SWARM_DMG * (1 + LEVEL_DMG_GROWTH * (monster_level(D) - 1)) / (max_hp(L) * ehp_mult)
                rho_acc += rho * dt
                sev_acc += sev * dt
                dur_acc += dt
                hit = AUTO_COEF * base_dmg(L) * dmg_mult
                swarm_hits.append(SWARM_HP * (1 + 0.33 * (monster_level(D) - 1)) / hit)
                t += dt
            # achats (espérance, fractionnaire) : petits jusqu'à épuisement de la part du joueur, puis grands
            n_small = min(gold / P, avail_small - bought["petit"])
            if n_small > 0:
                gold -= n_small * P; bought["petit"] += n_small
                items_pts += n_small * PTS["petit"]; items_cnt += n_small
            n_large = min(gold / (2 * P), avail_large - bought["large"])
            if n_large > 0:
                gold -= n_large * 2 * P; bought["large"] += n_large
                items_pts += n_large * PTS["large"]; items_cnt += n_large
            if name == "etage":
                items_pts += PTS["boss"]; items_cnt += 1  # un coffre de boss par joueur
        # fin d'étage : or restant -> XP (part du joueur)
        left_P = gold / P
        if s < 5:
            xp += GOLD_TO_XP * gold
        L = player_level(xp)
        out["floors"].append({
            "stage": s, "dur": t - floor_t0, "D_in": D0, "D_out": difficulty(t, s, n, v), "P": P,
            "ttk": fight_ttk, "items": items_cnt, "pts": items_pts, "level": L,
            "bought": bought["petit"] + bought["large"], "left_P": left_P,
            "rho": rho_acc / dur_acc, "sev": sev_acc / dur_acc, "alive_pp": alive_max,
            "swarm_hits": sum(swarm_hits) / len(swarm_hits),
        })
    out["run_s"] = t
    return out


def table(vname):
    v = VARIANTS[vname]
    solo = run(1, v)
    calib = solo["calib"]
    res = {n: run(n, v, calib) for n in range(1, 5)}
    print(f"\n=== Variante {vname} ===")
    print("n | run (min) | D fin | niv. fin | objets/j | TTK mini (é1/é3) | TTK boss (é1/é2/é3/é4) | final | rho/solo | gravité/solo | coups essaim | vivants/j max")
    base = res[1]
    for n, r in res.items():
        f = r["floors"]
        rho = sum(x["rho"] for x in f) / 5 / (sum(x["rho"] for x in base["floors"]) / 5)
        sev = sum(x["sev"] for x in f) / 5 / (sum(x["sev"] for x in base["floors"]) / 5)
        hits = sum(x["swarm_hits"] for x in f) / 5
        print(f"{n} | {r['run_s'] / 60:.1f} | {f[-1]['D_out']:.2f} | {f[-1]['level']:.1f} | {f[-1]['items']:.1f} | "
              f"{f[0]['ttk']['mini0']:.0f}/{f[2]['ttk']['mini0']:.0f} | "
              f"{'/'.join(str(round(f[i]['ttk']['etage2'])) for i in range(4))} | {f[4]['ttk']['final0']:.0f} | "
              f"{rho:.2f} | {sev:.2f} | {hits:.2f} | {max(x['alive_pp'] for x in f):.0f}")
    print("Par étage (n : durée s, D entrée, P, objets cumulés, niveau, reste en P)")
    for n, r in res.items():
        print(f"  n={n}: " + " ; ".join(
            f"é{x['stage']} {x['dur']:.0f}s D{x['D_in']:.2f} P{x['P']:.0f} obj{x['items']:.1f} niv{x['level']:.1f} r{x['left_P']:.1f}"
            for x in r["floors"]))
    return res


def summary(r, base):
    f, b = r["floors"], base["floors"]
    rho = sum(x["rho"] for x in f) / sum(x["rho"] for x in b)
    sev = sum(x["sev"] for x in f) / sum(x["sev"] for x in b)
    boss = sum(f[i]["ttk"]["etage2"] for i in range(4)) / 4
    return (f"run {r['run_s'] / 60:.1f} min | boss moy. {boss:.0f} s | final {f[4]['ttk']['final0']:.0f} s | "
            f"rho {rho:.2f} | gravité {sev:.2f} | objets/j {f[-1]['items']:.1f} | niv. {f[-1]['level']:.1f}")


def sensitivity():
    """Tests de robustesse de la variante reco (estimé, non mesuré en jeu)."""
    global AOE_FACTOR, DPS_SHARE
    v = VARIANTS["reco"]
    calib = run(1, v)["calib"]
    base = run(1, v, calib)
    print()
    print("=== Sensibilité (variante reco) ===")
    for n in (2, 3, 4):
        print(f"n={n} tous actifs      : " + summary(run(n, v, calib), base))
        print(f"n={n} un joueur AFK    : " + summary(run(n, v, calib, active=n - 1), base))
    print("n=4 deux joueurs AFK  : " + summary(run(4, v, calib, active=2), base))
    for name, val in (("AOE_FACTOR", 1.5), ("AOE_FACTOR", 2.5), ("DPS_SHARE", 0.45), ("DPS_SHARE", 0.75)):
        old = globals()[name]
        globals()[name] = val
        c = run(1, v)["calib"]
        b = run(1, v, c)
        print(f"n=4 {name}={val}: " + summary(run(4, v, c), b))
        globals()[name] = old


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "toutes"
    if which == "sens":
        sensitivity()
    else:
        for name in (VARIANTS if which == "toutes" else [which]):
            table(name)
        sensitivity()
