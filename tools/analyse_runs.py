#!/usr/bin/env python3
"""Analyse des journaux de run de Rainfall (équilibrage par les données, décision du 28/10/2026).

Lit des journaux produits par le jeu (autoload RunLog, schéma 1) : dossiers, fichiers .json ou archives .zip
exportées depuis Réglages > Jeu > « Exporter les journaux ». Sort un rapport Markdown :
  - TTK des boss et mini-boss par catégorie, étage, mode et boss (médiane, p25, p75) contre les cibles ;
  - DPS par personnage, minute par minute (et part de chaque sort) ;
  - taux de prise et taux de victoire par objet ;
  - causes de mort ;
  - courbe or / objets / niveau par minute ;
  - dégâts reçus par source et recharges effectives par sort.

Usage :
  python tools/analyse_runs.py <dossier|fichier.json|archive.zip> [...] [-o rapport.md] [--min-n 3]
  python tools/analyse_runs.py --synth 40 --synth-out <dossier>   # journaux synthétiques (test de l'outil)

Les journaux synthétiques suivent le schéma réel mais leurs chiffres sont tirés au hasard autour des cibles :
ils servent à vérifier l'outil, pas l'équilibrage.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import zipfile
from collections import Counter, defaultdict

SCHEMA = 1
# Cibles de TTK (docs/Audit_PV_Boss_2026-10-28.md) : secondes
TTK_TARGETS = {"mini": (21, 30), "etage": (65, 75), "raid": (75, 90), "final": (120, 150)}
CAT_LABEL = {"mini": "Mini-boss", "etage": "Boss d'étage", "raid": "Raid", "final": "Boss final"}
MINUTES_SHOWN = [1, 2, 3, 5, 8, 10, 12, 15, 18, 20]


# --- Lecture -------------------------------------------------------------------------------------

def _accept(d, origin, out, skipped):
    if isinstance(d, dict) and d.get("schema") == SCHEMA and "floors" in d:
        d["_origin"] = origin
        out.append(d)
    else:
        skipped.append(origin)


def load_logs(paths):
    out, skipped = [], []
    for p in paths:
        if os.path.isdir(p):
            for root, _dirs, files in os.walk(p):
                for f in sorted(files):
                    full = os.path.join(root, f)
                    if f.endswith(".zip"):
                        out_z, sk = load_logs([full])
                        out += out_z
                        skipped += sk
                    elif f.startswith("run_") and f.endswith(".json"):
                        _read_json_file(full, out, skipped)
        elif p.endswith(".zip"):
            with zipfile.ZipFile(p) as z:
                for name in z.namelist():
                    if name.endswith(".json"):
                        try:
                            _accept(json.loads(z.read(name).decode("utf-8")), f"{p}:{name}", out, skipped)
                        except (ValueError, UnicodeDecodeError):
                            skipped.append(f"{p}:{name}")
        elif p.endswith(".json"):
            _read_json_file(p, out, skipped)
    # dédoublonnage (le même journal peut venir de plusieurs exports)
    seen, uniq = set(), []
    for d in out:
        key = d.get("id")
        if key in seen:
            continue
        seen.add(key)
        uniq.append(d)
    return uniq, skipped


def _read_json_file(path, out, skipped):
    try:
        with open(path, encoding="utf-8") as fh:
            _accept(json.load(fh), path, out, skipped)
    except (OSError, ValueError):
        skipped.append(path)


# --- Statistiques --------------------------------------------------------------------------------

def quantile(xs, q):
    xs = sorted(xs)
    if not xs:
        return float("nan")
    k = (len(xs) - 1) * q
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def qtrio(xs):
    return quantile(xs, 0.25), quantile(xs, 0.5), quantile(xs, 0.75)


def fmt(x, nd=0):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return "–"
    return f"{x:,.{nd}f}".replace(",", " ")


def pct(x):
    return "–" if x is None or math.isnan(x) else f"{100 * x:.0f} %"


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        lines.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(lines)


def verdict(med, target):
    lo, hi = target
    if math.isnan(med):
        return "–"
    if med < lo:
        return f"trop court ({med - lo:+.1f} s)"
    if med > hi:
        return f"trop long ({med - hi:+.1f} s)"
    return "dans la cible"


# --- Sections du rapport -------------------------------------------------------------------------

def section_summary(logs):
    ended = [d for d in logs if d.get("end")]
    wins = [d for d in ended if d["end"]["result"] == "victory"]
    lines = ["## Résumé", ""]
    lines.append(f"- Journaux lus : **{len(logs)}** (terminés : {len(ended)}, en cours ou quittés : {len(logs) - len(ended)})")
    lines.append(f"- Victoires : **{len(wins)}** ({pct(len(wins) / len(ended) if ended else float('nan'))} des runs terminées)")
    versions = Counter(d.get("game_version", "?") for d in logs)
    plats = Counter(d.get("platform", "?") for d in logs)
    lines.append("- Versions : " + ", ".join(f"{k} ({v})" for k, v in versions.most_common()))
    lines.append("- Plateformes : " + ", ".join(f"{k} ({v})" for k, v in plats.most_common()))
    rows = []
    by = defaultdict(list)
    for d in ended:
        by[(d.get("character", "?"), d.get("mode", "?"))].append(d)
    for (ch, mode), ds in sorted(by.items()):
        w = sum(1 for d in ds if d["end"]["result"] == "victory")
        dur = [d["end"]["active_s"] / 60 for d in ds]
        stg = [d["end"]["stage"] for d in ds]
        rows.append([ch, mode, len(ds), pct(w / len(ds)), fmt(quantile(dur, 0.5), 1), fmt(quantile(stg, 0.5), 1)])
    lines += ["", table(["Personnage", "Mode", "Runs", "Victoires", "Durée médiane (min)", "Étage atteint (méd.)"], rows)]
    return "\n".join(lines)


def section_ttk(logs, min_n):
    fights = []
    for d in logs:
        for f in d.get("fights", []):
            if f.get("outcome") == "kill" and f.get("ttk", -1) > 0:
                fights.append((d, f))
    lines = ["## TTK des boss et mini-boss", "",
             "TTK = mort du boss − premier coup porté (secondes de jeu actif). Cibles : mini 21-30 s, boss d'étage "
             "65-75 s, raids 75-90 s, final 120-150 s. Seuls les combats gagnés comptent.", ""]
    if not fights:
        return "\n".join(lines + ["_Aucun combat de boss terminé._"])
    # par catégorie
    rows = []
    by_cat = defaultdict(list)
    for _d, f in fights:
        by_cat[f.get("cat", "?")].append(f["ttk"])
    for cat in ["mini", "etage", "raid", "final"] + sorted(set(by_cat) - set(TTK_TARGETS)):
        xs = by_cat.get(cat, [])
        if not xs:
            continue
        p25, med, p75 = qtrio(xs)
        tgt = TTK_TARGETS.get(cat)
        rows.append([CAT_LABEL.get(cat, cat), len(xs), fmt(p25), fmt(med), fmt(p75),
                     f"{tgt[0]}-{tgt[1]}" if tgt else "–", verdict(med, tgt) if tgt else "–"])
    lines += ["### Par catégorie", "", table(["Catégorie", "n", "p25", "Médiane", "p75", "Cible", "Verdict"], rows), ""]
    # par catégorie, étage et mode
    rows = []
    by = defaultdict(list)
    for d, f in fights:
        by[(f.get("cat", "?"), int(f.get("stage", 0)), d.get("mode", "?"))].append(f["ttk"])
    for (cat, stage, mode), xs in sorted(by.items(), key=lambda kv: (list(TTK_TARGETS).index(kv[0][0]) if kv[0][0] in TTK_TARGETS else 9, kv[0][1], kv[0][2])):
        p25, med, p75 = qtrio(xs)
        tgt = TTK_TARGETS.get(cat)
        flag = "" if len(xs) >= min_n else " (n faible)"
        rows.append([CAT_LABEL.get(cat, cat), stage, mode, len(xs), fmt(p25), fmt(med), fmt(p75),
                     (verdict(med, tgt) if tgt else "–") + flag])
    lines += ["### Par étage et mode", "", table(["Catégorie", "Étage", "Mode", "n", "p25", "Médiane", "p75", "Verdict"], rows), ""]
    # par boss
    rows = []
    by = defaultdict(list)
    extra = defaultdict(lambda: defaultdict(list))
    for d, f in fights:
        k = (f.get("cat", "?"), f.get("id", "?"))
        by[k].append(f["ttk"])
        extra[k]["taken"].append(f.get("dmg_taken", 0))
        extra[k]["shield"].append(f.get("shield_s", 0))
        extra[k]["enrage"].append(1 if f.get("enrage_s", 0) > 0 else 0)
    for (cat, bid), xs in sorted(by.items()):
        p25, med, p75 = qtrio(xs)
        e = extra[(cat, bid)]
        rows.append([bid, CAT_LABEL.get(cat, cat), len(xs), fmt(p25), fmt(med), fmt(p75),
                     fmt(quantile(e["taken"], 0.5)), fmt(quantile(e["shield"], 0.5), 1), pct(sum(e["enrage"]) / len(e["enrage"]))])
    lines += ["### Par boss", "", table(["Boss", "Catégorie", "n", "p25", "Médiane", "p75", "Dégâts reçus (méd.)",
                                          "Sous bouclier (s, méd.)", "Enrage atteint"], rows), ""]
    # morts pendant un combat
    deaths = Counter()
    total = Counter()
    for d in logs:
        for f in d.get("fights", []):
            total[f.get("id", "?")] += 1
            if f.get("player_died"):
                deaths[f.get("id", "?")] += 1
    if deaths:
        rows = [[bid, n, total[bid], pct(n / total[bid])] for bid, n in deaths.most_common()]
        lines += ["### Morts du joueur pendant un combat", "", table(["Boss", "Morts", "Combats", "Taux"], rows)]
    return "\n".join(lines)


def section_dps(logs, min_n):
    lines = ["## DPS par personnage (minute par minute)", "",
             "DPS = dégâts infligés pendant la minute / 60 (sorts + « other » : brûlures, poisons, objets). "
             "Médiane sur les runs encore en vie à cette minute.", ""]
    per_char = defaultdict(lambda: defaultdict(list))
    spell_share = defaultdict(Counter)
    for d in logs:
        ch = d.get("character", "?")
        for m in d.get("minutes", []):
            tot = sum(m.get("dmg", {}).values())
            per_char[ch][int(m["m"]) + 1].append(tot / 60.0)
            for sp, v in m.get("dmg", {}).items():
                spell_share[ch][sp] += v
    if not per_char:
        return "\n".join(lines + ["_Aucune minute enregistrée._"])
    shown = [m for m in MINUTES_SHOWN if any(m in per_char[c] for c in per_char)]
    rows = []
    for ch in sorted(per_char):
        row = [ch]
        for m in shown:
            xs = per_char[ch].get(m, [])
            row.append(fmt(quantile(xs, 0.5)) + ("*" if 0 < len(xs) < min_n else "") if xs else "–")
        rows.append(row)
    lines += [table(["Personnage"] + [f"min {m}" for m in shown], rows), "", "_* : moins de %d runs._" % min_n, ""]
    rows = []
    for ch in sorted(spell_share):
        tot = sum(spell_share[ch].values()) or 1
        parts = ", ".join(f"{sp} {100 * v / tot:.0f} %" for sp, v in spell_share[ch].most_common())
        rows.append([ch, parts])
    lines += ["### Part des dégâts par sort", "", table(["Personnage", "Répartition"], rows)]
    # recharges effectives
    cds = defaultdict(list)
    for d in logs:
        for m in d.get("minutes", []):
            for sp, cd in m.get("cd", {}).items():
                if cd > 0:
                    cds[(d.get("character", "?"), sp)].append(cd)
    if cds:
        rows = [[ch, sp, len(xs), fmt(quantile(xs, 0.5), 2), fmt(min(xs), 2)] for (ch, sp), xs in sorted(cds.items())]
        lines += ["", "### Recharges effectives (s)", "", table(["Personnage", "Sort", "Minutes", "Médiane", "Min"], rows)]
    return "\n".join(lines)


def section_items(logs, min_n):
    offered, taken = Counter(), Counter()
    for d in logs:
        for fl in d.get("floors", []):
            for c in fl.get("chests", []):
                for it in c.get("offered", []):
                    offered[it] += 1
                if c.get("taken"):
                    taken[c["taken"]] += 1
    ended = [d for d in logs if d.get("end")]
    base_win = sum(1 for d in ended if d["end"]["result"] == "victory") / len(ended) if ended else float("nan")
    with_item, win_with = Counter(), Counter()
    for d in ended:
        for it in d["end"].get("items", {}):
            with_item[it] += 1
            if d["end"]["result"] == "victory":
                win_with[it] += 1
    lines = ["## Objets", "",
             f"Taux de prise = pris / proposés dans un coffre. Taux de victoire = runs terminées gagnées parmi celles qui "
             f"finissent avec l'objet (référence toutes runs : {pct(base_win)}). Corrélation, pas causalité.", ""]
    ids = sorted(set(offered) | set(with_item), key=lambda i: (-with_item[i], i))
    if not ids:
        return "\n".join(lines + ["_Aucun objet._"])
    rows = []
    for it in ids:
        pr = taken[it] / offered[it] if offered[it] else float("nan")
        wr = win_with[it] / with_item[it] if with_item[it] else float("nan")
        delta = "–" if math.isnan(wr) or math.isnan(base_win) else f"{100 * (wr - base_win):+.0f} pts"
        flag = "" if with_item[it] >= min_n else " (n faible)"
        rows.append([it, offered[it], taken[it], pct(pr), with_item[it], pct(wr), delta + flag])
    lines.append(table(["Objet", "Proposé", "Pris", "Taux de prise", "Runs avec", "Victoires avec", "Écart"], rows))
    return "\n".join(lines)


def section_deaths(logs):
    deaths = [d for d in logs if d.get("end") and d["end"]["result"] == "death"]
    lines = ["## Causes de mort", ""]
    if not deaths:
        return "\n".join(lines + ["_Aucune mort._"])
    by_cause = Counter(d["end"].get("cause") or "inconnu" for d in deaths)
    rows = [[c, n, pct(n / len(deaths))] for c, n in by_cause.most_common()]
    lines += [table(["Dernière source de dégâts", "Morts", "Part"], rows), ""]
    by_stage = defaultdict(list)
    for d in deaths:
        by_stage[d["end"]["stage"]].append(d["end"]["minute"])
    rows = [[s, len(xs), fmt(quantile(xs, 0.5), 1)] for s, xs in sorted(by_stage.items())]
    lines += ["### Par étage", "", table(["Étage", "Morts", "Minute médiane"], rows)]
    return "\n".join(lines)


def section_economy(logs):
    gold, items, lvl, dd = (defaultdict(list) for _ in range(4))
    for d in logs:
        for m in d.get("minutes", []):
            k = int(m["m"]) + 1
            gold[k].append(m.get("gold", 0))
            items[k].append(m.get("items", 0))
            lvl[k].append(m.get("lvl", 1))
            dd[k].append(m.get("d", 1))
    lines = ["## Or, objets et niveau par minute", "", "Or = or gagné cumulé depuis le début de la run (médiane).", ""]
    if not gold:
        return "\n".join(lines + ["_Aucune minute._"])
    rows = []
    for k in sorted(gold):
        rows.append([k, len(gold[k]), fmt(quantile(gold[k], 0.5)), fmt(quantile(items[k], 0.5), 1),
                     fmt(quantile(lvl[k], 0.5), 1), fmt(quantile(dd[k], 0.5), 2)])
    lines.append(table(["Minute", "Runs", "Or gagné", "Objets", "Niveau", "D"], rows))
    # par étage
    fl = defaultdict(lambda: defaultdict(list))
    for d in logs:
        for f in d.get("floors", []):
            if f.get("t_out", -1) > 0:
                s = f["stage"]
                fl[s]["dur"].append((f["t_out"] - f["t_in"]) / 60)
                fl[s]["earn"].append(f.get("gold_earned", 0))
                fl[s]["spent"].append(f.get("gold_spent", 0))
                fl[s]["chests"].append(len(f.get("chests", [])))
                fl[s]["d"].append(f.get("d_out", 0))
    if fl:
        rows = [[s, len(v["dur"]), fmt(quantile(v["dur"], 0.5), 1), fmt(quantile(v["earn"], 0.5)), fmt(quantile(v["spent"], 0.5)),
                 fmt(quantile(v["chests"], 0.5), 1), fmt(quantile(v["d"], 0.5), 2)] for s, v in sorted(fl.items())]
        lines += ["", "### Par étage", "", table(["Étage", "n", "Durée (min)", "Or gagné", "Or dépensé", "Coffres", "D de sortie"], rows)]
    return "\n".join(lines)


def section_taken(logs):
    src = Counter()
    for d in logs:
        for m in d.get("minutes", []):
            for k, v in m.get("taken", {}).items():
                src[k] += v
    lines = ["## Dégâts reçus par source", ""]
    if not src:
        return "\n".join(lines + ["_Aucun dégât reçu._"])
    tot = sum(src.values()) or 1
    rows = [[k, fmt(v), pct(v / tot)] for k, v in src.most_common(20)]
    return "\n".join(lines + [table(["Source", "Dégâts", "Part"], rows)])


def report(logs, skipped, min_n):
    parts = ["# Rapport des journaux de run Rainfall", ""]
    if skipped:
        parts.append(f"_{len(skipped)} fichier(s) ignoré(s) (schéma inconnu ou illisible)._\n")
    if not logs:
        parts.append("Aucun journal lisible.")
        return "\n".join(parts)
    for sec in (section_summary(logs), section_ttk(logs, min_n), section_dps(logs, min_n), section_items(logs, min_n),
                section_deaths(logs), section_economy(logs), section_taken(logs)):
        parts += [sec, ""]
    return "\n".join(parts)


# --- Journaux synthétiques (test de l'outil) ------------------------------------------------------

def synth_logs(n, seed=1):
    rng = random.Random(seed)
    chars = {"ardent": ["eclat_de_braise", "pluie_de_cendres", "nova", "meteore"],
             "rictus": ["couteau", "toupie", "doublures", "levee"],
             "vigie": ["fleche", "salve", "piege", "pluie_de_fleches"]}
    plan = [("terrasses_noyees", "eclusier", ["scarecrow_reaper", "vat_toad"]), ("foret_brume", "cerf", ["moss_mantis", "mist_wolf"]),
            ("cite_rouille", "salt_king", ["rust_archon", "ash_lord"]), ("cryptes_noyees", "crystal_mother", ["blind_swarm", "salt_golem"]),
            ("la_source", "rain_sower", [])]
    items = ["braises", "eclat_d_experience", "faveur_du_marchand", "rune_de_portee", "couronne_d_echo", "phenix_de_poche",
             "bouclier_reactif", "lame_rapide"]
    out = []
    for i in range(n):
        ch = rng.choice(list(chars))
        mode = rng.choice(["facile", "moyen", "moyen", "difficile"])
        skill = rng.uniform(0.7, 1.3) * (1.15 if mode == "facile" else 0.85 if mode == "difficile" else 1.0)
        t = 0.0
        floors, fights, minutes = [], [], []
        gold_cum, owned = 0, Counter()
        died_at, cause = None, ""
        for s, (mp, boss, minis) in enumerate(plan, start=1):
            fl = {"stage": s, "map": mp, "t_in": round(t, 1), "t_clear": -1, "t_out": -1, "d_in": round(1 + t / 200, 2),
                  "d_out": 0, "lvl_in": 1 + int(t / 60), "lvl_out": 0, "gold_earned": 0, "gold_spent": 0, "gold_converted": 0,
                  "xp_from_gold": 0, "kills": 0, "dmg_taken": 0, "chests": [], "items": [], "pillars": []}
            dur = rng.uniform(170, 260)
            for c in range(rng.randint(3, 6)):
                offer = rng.sample(items, 2)
                pick = offer[0] if rng.random() < 0.6 else offer[1]
                ct = round(t + rng.uniform(10, dur), 1)
                fl["chests"].append({"t": ct, "q": rng.choice(["commun", "rare", "legendaire"]), "offered": offer, "taken": pick})
                fl["items"].append({"t": ct, "id": pick, "src": "coffre"})
                owned[pick] += 1
            for mini in minis:
                ttk = rng.gauss(26 / skill, 4)
                fights.append({"id": mini, "cat": "mini", "stage": s, "hp_max": 1000 * s, "t_spawn": round(t + 40, 1),
                               "t_hit": round(t + 41, 1), "t_end": round(t + 41 + ttk, 1), "ttk": round(ttk, 1), "outcome": "kill",
                               "dmg_dealt": 1000 * s, "dmg_taken": rng.randint(20, 200), "dmg_from_boss": rng.randint(10, 150),
                               "shield_s": 0, "enrage_s": 0, "player_died": False})
            cat = "final" if s == 5 else ("raid" if boss == "salt_king" else "etage")
            base = {"etage": 70, "raid": 82, "final": 135}[cat]
            ttk = rng.gauss(base / skill, base * 0.12)
            dies = rng.random() < 0.08 * s / skill
            fights.append({"id": boss, "cat": cat, "stage": s, "hp_max": 3300 * s, "t_spawn": round(t + dur - ttk - 5, 1),
                           "t_hit": round(t + dur - ttk, 1), "t_end": round(t + dur, 1), "ttk": -1 if dies else round(ttk, 1),
                           "outcome": "death" if dies else "kill", "dmg_dealt": 3300 * s, "dmg_taken": rng.randint(100, 900),
                           "dmg_from_boss": rng.randint(50, 600), "shield_s": round(rng.uniform(0, 20), 1) if cat == "raid" else 0,
                           "enrage_s": round(max(0, ttk - 90), 1), "player_died": dies})
            for m in range(int(t // 60), int((t + dur) // 60)):
                spells = chars[ch]
                dps = (40 + 22 * m) * skill * rng.uniform(0.8, 1.2)
                share = [0.4, 0.25, 0.2, 0.1]
                gold_cum += int(rng.uniform(60, 120) * (1 + m * 0.15))
                minutes.append({"m": m, "dmg": {**{sp: round(dps * 60 * w) for sp, w in zip(spells, share)}, "other": round(dps * 3)},
                                "casts": {sp: rng.randint(4, 90) for sp in spells}, "cd": {sp: round(rng.uniform(0.5, 12), 2) for sp in spells},
                                "taken": {rng.choice(["t1", "t2_tir", "t3", "boss:" + boss]): rng.randint(10, 120)},
                                "kills": [rng.randint(5, 40), rng.randint(0, 10), rng.randint(0, 4), rng.randint(0, 2)],
                                "gold": gold_cum, "items": sum(owned.values()), "lvl": 1 + m, "d": round(1 + m * 0.3, 2)})
            t += dur
            fl.update({"t_out": round(t, 1), "t_clear": round(t - 20, 1), "d_out": round(1 + t / 200, 2), "lvl_out": 1 + int(t / 60),
                       "gold_earned": rng.randint(400, 900) * s, "gold_spent": rng.randint(200, 800) * s})
            floors.append(fl)
            if dies:
                died_at, cause = s, "boss:" + boss
                break
        res = "death" if died_at else "victory"
        out.append({"schema": SCHEMA, "id": f"synth-{i:04d}", "game_version": "synth", "platform": "Synth", "debug": True,
                    "started_at": 0, "ended_at": 0, "character": ch, "skin": "", "loadout": {}, "mode": mode, "seed": i,
                    "plan": [{"stage": s, "map": p[0], "boss": p[1], "minis": p[2]} for s, p in enumerate(plan, 1)],
                    "resumes": 0, "floors": floors, "fights": fights, "minutes": minutes,
                    "end": {"result": res, "cause": cause, "stage": died_at or 5, "minute": round(t / 60, 2), "active_s": round(t, 1),
                            "level": 1 + int(t / 60), "kills": 500, "gold_earned": gold_cum, "gold_spent": 0,
                            "items": dict(owned)}})
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description="Rapport Markdown des journaux de run de Rainfall.")
    ap.add_argument("paths", nargs="*", help="dossiers, .json ou .zip exportés")
    ap.add_argument("-o", "--out", help="fichier Markdown de sortie (défaut : sortie standard)")
    ap.add_argument("--min-n", type=int, default=3, help="effectif sous lequel une ligne est marquée « n faible »")
    ap.add_argument("--synth", type=int, default=0, help="génère N journaux synthétiques (test de l'outil)")
    ap.add_argument("--synth-out", help="dossier où écrire les journaux synthétiques")
    a = ap.parse_args(argv)
    if a.synth:
        logs = synth_logs(a.synth)
        if a.synth_out:
            os.makedirs(a.synth_out, exist_ok=True)
            for d in logs:
                with open(os.path.join(a.synth_out, f"run_{d['id']}.json"), "w", encoding="utf-8") as fh:
                    json.dump(d, fh, ensure_ascii=False, separators=(",", ":"))
            print(f"{len(logs)} journaux synthétiques écrits dans {a.synth_out}", file=sys.stderr)
        if not a.paths:
            a.paths = [a.synth_out] if a.synth_out else []
            if not a.synth_out:
                text = report(logs, [], a.min_n)
                _emit(text, a.out)
                return 0
    if not a.paths:
        ap.error("indique au moins un dossier, .json ou .zip")
    logs, skipped = load_logs(a.paths)
    _emit(report(logs, skipped, a.min_n), a.out)
    return 0 if logs else 1


def _emit(text, out):
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print(f"Rapport écrit : {out}", file=sys.stderr)
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(text)


if __name__ == "__main__":
    sys.exit(main())
