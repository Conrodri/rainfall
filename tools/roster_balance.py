#!/usr/bin/env python3
"""Audit d'équilibrage du roster de Rainfall (11/11/2026) : lance les combats scriptés et agrège leurs mesures.

Deux sous-commandes :

  run     lance le simulateur Godot (tests/balance_sim_run.tscn), un processus par personnage, sous le verrou partagé
          art/tools/vfx_test/godot_locked.sh ; les rencontres de boss avec adds passent par
          tests/balance_sim_fullrun.tscn (--inject_cfg=E1..E5).
  report  lit les JSON produits et écrit un rapport Markdown : DPS mono-cible et de zone par niveau (L1, L6, L12m, L18),
          ratios contre Ardent et contre la médiane du roster, TTK des mini-boss et des boss d'étage aux moments visés
          (E1-E5, duel sans adds), rencontres avec adds, survie (PV effectifs, dégâts subis, morts).

Exemples (depuis la racine du dépôt ; sorties hors dépôt) :

  python tools/roster_balance.py run --out <dossier> --set levels --seeds 2
  python tools/roster_balance.py run --out <dossier> --set bosses --seeds 2
  python tools/roster_balance.py run --out <dossier> --set encounters --chars ardent,vigie --cfg E1,E3,E5
  python tools/roster_balance.py run --out <dossier> --set probe --chars arpenteuse --cfg L12m --items eclair_en_bouteille:3
  python tools/roster_balance.py report <dossier> [-o rapport.md]

Jeux de combats (--set) :
  levels      swarm, mixed, elite, miniboss  x  L1, L6, L12m, L18
  bosses      elite, miniboss, floorboss     x  E1, E2, E3, E4, E5
  encounters  boss d'étage avec flux de monstres et zone de charge (balance_sim_fullrun, une rencontre par processus)
  probe       comme levels, avec --items en plus (sondes de synergies objets x personnage), fichiers suffixés par --tag
              (--noslot=4 retire un sort : ablation, pour lire la part d'un sort dans le DPS)

Méthode : le pilote du simulateur est un « joueur moyen » en sorts automatiques (BotPilot), arène plate sans carte.
Ratio contre Ardent = durée du combat d'Ardent / durée du personnage (> 1 : plus rapide), comme dans
docs/Equilibrage_Personnages.md. Mono = moyenne géométrique élite + mini-boss ; zone = essaim + mixte.
"""
from __future__ import annotations

import argparse
import glob
import json
import math
import os
import statistics
import subprocess
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WRAPPER = os.path.join(ROOT, "art", "tools", "vfx_test", "godot_locked.sh")
ROSTER = ["ardent", "rictus", "tocsin", "averse", "arpenteuse", "rainette", "avare", "bourbe", "vigie", "morfil",
          "gresille"]
NAMES = {"ardent": "Ardent", "rictus": "Rictus", "tocsin": "Tocsin", "averse": "Averse", "arpenteuse": "Arpenteuse",
         "rainette": "Rainette", "avare": "Avare", "bourbe": "Bourbe", "vigie": "Vigie", "morfil": "Taliant",
         "gresille": "Grésille"}
SETS = {
    "levels": (["swarm", "mixed", "elite", "miniboss"], ["L1", "L6", "L12m", "L18"]),
    "bosses": (["elite", "miniboss", "floorboss"], ["E1", "E2", "E3", "E4", "E5"]),
    "probe": (["swarm", "mixed", "elite", "miniboss"], ["L12m"]),
}
LEVEL_CFGS = ["L1", "L6", "L12m", "L18"]
BOSS_CFGS = ["E1", "E2", "E3", "E4", "E5"]
# Cibles (docs/Maths_Scaling.md §14 et §14.0) : TTK en jeu, adds compris.
TTK_TARGET = {"mini": (21, 30), "etage": (65, 75), "final": (120, 150)}
BAND = (0.80, 1.20)  # ±20 % autour de la référence


# --- Lancement -----------------------------------------------------------------------------------

def _godot_cmd(scene: str, user_args: list[str], fixed_fps: bool) -> list[str]:
    base = ["sh", WRAPPER, "--headless"]
    if fixed_fps:
        base += ["--fixed-fps", "60"]
    return base + [scene, "--"] + user_args


def cmd_run(a: argparse.Namespace) -> int:
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    chars = ROSTER if a.chars in ("", "all") else a.chars.split(",")
    fails = 0
    if a.set == "encounters":
        cfgs = (a.cfg or ",".join(BOSS_CFGS)).split(",")
        for c in chars:
            for cfg in cfgs:
                f = os.path.join(out, f"enc_{c}_{cfg}.json")
                if os.path.exists(f) and not a.force:
                    continue
                seeds = ",".join(str(i) for i in range(a.seeds))
                cmd = _godot_cmd("res://tests/balance_sim_fullrun.tscn",
                                 [f"--char={c}", f"--inject_cfg={cfg}", f"--seeds={seeds}", f"--out={f}"], True)
                fails += _launch(cmd, os.path.join(out, f"enc_{c}_{cfg}.log"))
        return 1 if fails else 0
    scens, cfgs = SETS[a.set]
    if a.scen:
        scens = a.scen.split(",")
    if a.cfg:
        cfgs = a.cfg.split(",")
    tag = a.tag or a.set
    groups = [chars] if a.batch else [[c] for c in chars]
    for grp in groups:
        c = "+".join(grp) if a.batch else grp[0]
        f = os.path.join(out, f"sim_{tag}_{c}.json")
        if os.path.exists(f) and not a.force:
            continue
        args = [f"--chars={','.join(grp)}", f"--scen={','.join(scens)}", f"--cfg={','.join(cfgs)}", f"--seeds={a.seeds}",
                f"--out={f}"]
        if a.items:
            args.append(f"--items={a.items}")
        if a.noslot:
            args.append(f"--noslot={a.noslot}")
        cmd = _godot_cmd("res://tests/balance_sim_run.tscn", args, not a.realtime)
        fails += _launch(cmd, os.path.join(out, f"sim_{tag}_{c}.log"))
    return 1 if fails else 0


def _launch(cmd: list[str], log: str) -> int:
    print(" ".join(cmd), flush=True)
    with open(log, "w", encoding="utf-8", errors="replace") as lf:
        r = subprocess.run(cmd, cwd=ROOT, stdout=lf, stderr=subprocess.STDOUT)
    ok = False
    with open(log, encoding="utf-8", errors="replace") as lf:
        ok = "RESULT: OK" in lf.read()
    print(("  OK " if ok else "  ECHEC ") + log, flush=True)
    return 0 if (ok and r.returncode == 0) else 1


# --- Lecture -------------------------------------------------------------------------------------

def gmean(xs):
    xs = [x for x in xs if x and x > 0 and math.isfinite(x)]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else float("nan")


def load_fights(folder: str, prefix: str = "sim_") -> dict:
    """{(tag, char, cfg, scen): [fight, ...]} ; tag = jeu de combats (nom de fichier sim_<tag>_<char>.json)."""
    out = defaultdict(list)
    for f in sorted(glob.glob(os.path.join(folder, prefix + "*.json"))):
        base = os.path.basename(f)[len(prefix):-5]
        tag = base.rsplit("_", 1)[0] if "_" in base else "" # sim_<tag>_<perso ou perso+perso>.json
        with open(f, encoding="utf-8") as fh:
            data = json.load(fh)
        for ch in data.get("characters", []):
            for fi in ch.get("fights", []):
                out[(tag, fi["char"], fi["config"], fi["scenario"])].append(fi)
    return out


def load_encounters(folder: str) -> dict:
    """{(char, cfg): [boss, ...]} depuis enc_<char>_<cfg>.json (balance_sim_fullrun --inject_cfg)."""
    out = defaultdict(list)
    for f in sorted(glob.glob(os.path.join(folder, "enc_*.json"))):
        base = os.path.basename(f)[4:-5]
        c, cfg = base.rsplit("_", 1)
        with open(f, encoding="utf-8") as fh:
            data = json.load(fh)
        for r in data.get("runs", []):
            for b in r.get("bosses", []):
                b = dict(b)
                b["deaths_run"] = r.get("deaths", 0)
                out[(c, cfg)].append(b)
    return out


def mean(xs):
    xs = [x for x in xs if x is not None and math.isfinite(x)]
    return sum(xs) / len(xs) if xs else float("nan")


def agg(fights: list) -> dict:
    """Moyenne sur les graines. ttk : durée du combat (plafond si non fini)."""
    if not fights:
        return {}
    keys = ["duration", "dps", "taken", "deaths", "hp_min", "max_hp", "armor", "regen", "kills", "boss_hp"]
    d = {k: mean([float(f.get(k, float("nan"))) for f in fights]) for k in keys}
    d["cleared"] = sum(1 for f in fights if f.get("cleared")) / len(fights)
    d["n"] = len(fights)
    d["boss_ids"] = sorted({f.get("boss_id", "") for f in fights if f.get("boss_id")})
    slots = defaultdict(float)
    tot = 0.0
    for f in fights:
        for k, v in (f.get("by_slot") or {}).items():
            slots[str(k)] += float(v)
            tot += float(v)
    d["slot_share"] = {k: v / tot for k, v in slots.items()} if tot > 0 else {}
    return d


# --- Rapport -------------------------------------------------------------------------------------

def fmt(x, nd=0):
    if x is None or (isinstance(x, float) and not math.isfinite(x)):
        return "-"
    return f"{x:.{nd}f}".replace(".", ",")


def mark(r):
    if not math.isfinite(r):
        return "-"
    s = fmt(r, 2)
    return f"**{s}**" if (r < BAND[0] or r > BAND[1]) else s


def ehp(d):
    """PV effectifs contre les coups bruts : PV max × (100 + armure) / 100 (Balance.armor_reduction)."""
    if not d or not math.isfinite(d.get("max_hp", float("nan"))):
        return float("nan")
    return d["max_hp"] * (100.0 + max(d.get("armor", 0.0), 0.0)) / 100.0


def cmd_report(a: argparse.Namespace) -> int:
    F = load_fights(a.folder)
    E = load_encounters(a.folder)
    tags = sorted({k[0] for k in F})
    lines: list[str] = []
    w = lines.append
    chars = [c for c in ROSTER if any(k[1] == c for k in F)]

    def A(tag, c, cfg, scen):
        return agg(F.get((tag, c, cfg, scen), []))

    # 1. Niveaux
    if "levels" in tags:
        w("## DPS par niveau (jeu « levels »)\n")
        w("DPS effectif mesuré (sans overkill), moyenne des graines. Mono = élite + mini-boss (moyenne géométrique), "
          "zone = scénario mixte (paquets de 3-6 + tireurs) ; l'essaim, dominé par l'approche des monstres, est à part.\n")
        w("| Perso | " + " | ".join(f"{c} mono | {c} zone | {c} essaim" for c in LEVEL_CFGS) + " |")
        w("|---|" + "---|---|---|" * len(LEVEL_CFGS))
        for c in chars:
            row = [NAMES.get(c, c)]
            for cfg in LEVEL_CFGS:
                mono = gmean([A("levels", c, cfg, s).get("dps") for s in ("elite", "miniboss")])
                zone = A("levels", c, cfg, "mixed").get("dps")
                row += [fmt(mono), fmt(zone), fmt(A("levels", c, cfg, "swarm").get("dps"))]
            w("| " + " | ".join(row) + " |")
        w("")
        for ref_name in ("ardent", "median"):
            w(f"### Ratios de vitesse contre {'Ardent' if ref_name == 'ardent' else 'la médiane du roster'} "
              "(durée de la référence / durée du perso)\n")
            w("| Perso | " + " | ".join(f"{c} mono | {c} zone" for c in LEVEL_CFGS) + " | Global L6+ | Mono L6+ | Zone L6+ |")
            w("|---|" + "---|---|" * len(LEVEL_CFGS) + "---|---|---|")
            for c in chars:
                row = [NAMES.get(c, c)]
                monos, zones = [], []
                for cfg in LEVEL_CFGS:
                    rm, rz = [], []
                    for s in ("elite", "miniboss", "mixed"):
                        dur = A("levels", c, cfg, s).get("duration")
                        if ref_name == "ardent":
                            ref = A("levels", "ardent", cfg, s).get("duration")
                        else:
                            ref = statistics.median([A("levels", x, cfg, s).get("duration", float("nan")) for x in chars
                                                     if A("levels", x, cfg, s)])
                        r = ref / dur if dur and ref else float("nan")
                        (rm if s in ("elite", "miniboss") else rz).append(r)
                    m, z = gmean(rm), gmean(rz)
                    row += [mark(m), mark(z)]
                    if cfg != "L1":
                        monos += rm
                        zones += rz
                row += [mark(gmean(monos + zones)), mark(gmean(monos)), mark(gmean(zones))]
                w("| " + " | ".join(row) + " |")
            w("")
        w("### Survie (jeu « levels », mixte + mini-boss)\n")
        w("| Perso | " + " | ".join(f"{c} PV / armure / PV eff." for c in LEVEL_CFGS) + " | Subis mixte L6/L12m/L18 | Subis mini-boss L6/L12m/L18 | Morts (tous combats) |")
        w("|---|" + "---|" * len(LEVEL_CFGS) + "---|---|---|")
        for c in chars:
            row = [NAMES.get(c, c)]
            for cfg in LEVEL_CFGS:
                d = A("levels", c, cfg, "mixed")
                row.append(f"{fmt(d.get('max_hp'))} / {fmt(d.get('armor'))} / {fmt(ehp(d))}")
            row.append(" / ".join(fmt(A("levels", c, cfg, "mixed").get("taken")) for cfg in ("L6", "L12m", "L18")))
            row.append(" / ".join(fmt(A("levels", c, cfg, "miniboss").get("taken")) for cfg in ("L6", "L12m", "L18")))
            deaths = sum(sum(int(f.get("deaths", 0)) for f in F.get(("levels", c, cfg, s), []))
                         for cfg in LEVEL_CFGS for s in ("swarm", "mixed", "elite", "miniboss"))
            row.append(str(deaths))
            w("| " + " | ".join(row) + " |")
        w("")

    # 2. Boss
    if "bosses" in tags:
        w("## TTK aux moments des boss (jeu « bosses », duels sans adds)\n")
        for scen, label in (("elite", "Élite T3 (brûlure)"), ("miniboss", "Mini-boss (frost_bear)"),
                            ("floorboss", "Boss d'étage (duel)")):
            w(f"### {label}\n")
            w("| Perso | " + " | ".join(BOSS_CFGS) + " | Ratio méd. (géo) | Subis (moy.) | Morts |")
            w("|---|" + "---|" * len(BOSS_CFGS) + "---|---|---|")
            meds = {}
            for cfg in BOSS_CFGS:
                vals = [A("bosses", x, cfg, scen).get("duration") for x in chars if A("bosses", x, cfg, scen)]
                meds[cfg] = statistics.median(vals) if vals else float("nan")
            for c in chars:
                row = [NAMES.get(c, c)]
                rs, tk, de = [], [], 0
                for cfg in BOSS_CFGS:
                    d = A("bosses", c, cfg, scen)
                    if not d:
                        row.append("-")
                        continue
                    flag = "" if d["cleared"] >= 1.0 else " (non fini)"
                    row.append(fmt(d["duration"], 1) + flag)
                    rs.append(meds[cfg] / d["duration"] if d["duration"] else float("nan"))
                    tk.append(d["taken"])
                    de += sum(int(f.get("deaths", 0)) for f in F.get(("bosses", c, cfg, scen), []))
                row += [mark(gmean(rs)), fmt(mean(tk)), str(de)]
                w("| " + " | ".join(row) + " |")
            w("| **Médiane** | " + " | ".join(fmt(meds[c], 1) for c in BOSS_CFGS) + " | | | |")
            if scen == "floorboss":
                ids = {cfg: sorted({b for c in chars for b in A("bosses", c, cfg, scen).get("boss_ids", [])})
                       for cfg in BOSS_CFGS}
                hp = {cfg: statistics.median([A("bosses", c, cfg, scen).get("boss_hp", float("nan")) for c in chars
                                              if A("bosses", c, cfg, scen)] or [float("nan")]) for cfg in BOSS_CFGS}
                w("| Boss | " + " | ".join(", ".join(ids[c]) for c in BOSS_CFGS) + " | | | |")
                w("| PV (méd.) | " + " | ".join(fmt(hp[c]) for c in BOSS_CFGS) + " | | | |")
            w("")

    # 3. Rencontres avec adds
    if E:
        w("## Rencontres de boss avec adds (balance_sim_fullrun --inject_cfg)\n")
        w("TTK du boss (s), flux de monstres et zone de charge actifs ; « part » = part des dégâts portés au boss.\n")
        cfgs = sorted({k[1] for k in E})
        w("| Perso | " + " | ".join(f"{c} TTK / part" for c in cfgs) + " |")
        w("|---|" + "---|" * len(cfgs))
        for c in [x for x in ROSTER if any(k[0] == x for k in E)]:
            row = [NAMES.get(c, c)]
            for cfg in cfgs:
                bs = [b for b in E.get((c, cfg), []) if b.get("kind") in ("etage", "final")]
                if not bs:
                    row.append("-")
                    continue
                t = mean([float(b["ttk"]) if b.get("killed") else float(b.get("ttk", 0)) for b in bs])
                nk = sum(1 for b in bs if not b.get("killed"))
                part = mean([float(b.get("focus", float("nan"))) for b in bs])
                row.append(f"{fmt(t)}{' (' + str(nk) + ' non tué)' if nk else ''} / {fmt(part, 2)} ({','.join(b['id'] for b in bs)})")
            w("| " + " | ".join(row) + " |")
        w("")

    # 4. Sondes
    probe_tags = [t for t in tags if t not in ("levels", "bosses")]
    for t in probe_tags:
        w(f"## Sonde « {t} »\n")
        w("| Perso | Config | Essaim | Mixte | Élite | Mini-boss | vs même perso sans sonde (L12m, géo) |")
        w("|---|---|---|---|---|---|---|")
        for (tg, c, cfg, _s) in sorted({(k[0], k[1], k[2], "") for k in F if k[0] == t}):
            row = [NAMES.get(c, c), cfg]
            rr = []
            for s in ("swarm", "mixed", "elite", "miniboss"):
                d = A(t, c, cfg, s)
                # référence : mêmes graines que la sonde (la sonde tourne souvent sur 1 graine, la référence sur 2)
                seeds = {f.get("seed") for f in F.get((t, c, cfg, s), [])}
                base = agg([f for f in F.get(("levels", c, cfg, s), []) if f.get("seed") in seeds])
                row.append(f"{fmt(d.get('dps'))} DPS / {fmt(d.get('duration'), 1)} s" if d else "-")
                if d and base:
                    rr.append(base["duration"] / d["duration"])
            row.append(fmt(gmean(rr), 2))
            w("| " + " | ".join(row) + " |")
        w("")

    # 5. Part des sorts
    if "levels" in tags:
        w("## Part des dégâts par sort (L12m, élite + mini-boss)\n")
        w("Part de chaque emplacement dans les coups de sort (signal spell_hit, overkill compris ; procs d'objets non comptés).\n")
        w("| Perso | Sort 1 | Sort 2 | Sort 3 | Sort 4 |")
        w("|---|---|---|---|---|")
        for c in chars:
            fs = F.get(("levels", c, "L12m", "elite"), []) + F.get(("levels", c, "L12m", "miniboss"), [])
            sh = agg(fs).get("slot_share", {})
            w("| " + " | ".join([NAMES.get(c, c)] + [fmt(100 * sh.get(str(i), 0.0)) + " %" for i in (1, 2, 3, 4)]) + " |")
        w("")
    text = "\n".join(lines) + "\n"
    if a.o:
        with open(a.o, "wb") as fh:
            fh.write(text.encode("utf-8"))
    else:
        sys.stdout.buffer.write(text.encode("utf-8"))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run", help="lancer les combats (Godot)")
    r.add_argument("--out", required=True, help="dossier de sortie (hors dépôt)")
    r.add_argument("--set", choices=["levels", "bosses", "encounters", "probe"], default="levels")
    r.add_argument("--chars", default="all")
    r.add_argument("--scen", default="")
    r.add_argument("--cfg", default="")
    r.add_argument("--seeds", type=int, default=2)
    r.add_argument("--items", default="", help="objets ajoutés (id:n,id:n), pour --set probe")
    r.add_argument("--noslot", default="", help="ablation : emplacements retirés du kit (ex. 4 ou 2,3)")
    r.add_argument("--tag", default="", help="nom du jeu de combats dans les fichiers (défaut : --set)")
    r.add_argument("--force", action="store_true", help="relancer même si le JSON existe")
    r.add_argument("--realtime", action="store_true",
                   help="balance_sim_run cadencé sur le temps réel × K (sinon --fixed-fps 60 : pas d'attente réelle)")
    r.add_argument("--batch", action="store_true",
                   help="tous les personnages dans un seul processus Godot (plus rapide ; un plantage arrête tout)")
    r.set_defaults(fn=cmd_run)
    q = sub.add_parser("report", help="agréger les JSON en rapport Markdown")
    q.add_argument("folder")
    q.add_argument("-o", default="")
    q.set_defaults(fn=cmd_report)
    a = p.parse_args()
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
