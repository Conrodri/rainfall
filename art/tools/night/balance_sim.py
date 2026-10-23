"""Simulateur d'équilibrage des personnages : lance les combats scriptés (Godot headless) et écrit
art/tools/night/balance_report.md + balance_report.csv (Ardent = référence, écarts > ±20 % signalés).

Usage (depuis la racine du dépôt) :
  python art/tools/night/balance_sim.py                 # tous les persos jouables, 2 graines
  python art/tools/night/balance_sim.py --chars ardent,rictus --seeds 1
  python art/tools/night/balance_sim.py --report-only   # régénère le rapport depuis les JSON existants

Un processus Godot par personnage, l'un après l'autre (RAM). Kit absent ou incomplet : sauté avec une note.
Scène : game/tests/balance_sim_run.tscn (code : game/tests/balance_sim/).
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GAME = ROOT / "game"
OUT_DIR = Path(__file__).resolve().parent / "balance_sim"
REPORT_MD = Path(__file__).resolve().parent / "balance_report.md"
REPORT_CSV = Path(__file__).resolve().parent / "balance_report.csv"
GODOT = r"C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
BASE = "ardent"
FLAG = 0.20
TAKEN_FLOOR = 5.0  # % PV/min : en dessous de cet écart absolu, un écart relatif de dégâts subis n'est pas signalé
SCEN_LABEL = {"swarm": "Essaim T1 (64)", "mixed": "Mixte + tireurs", "elite": "Élite T3", "miniboss": "Mini-boss"}
CFG_LABEL = {"L1": "Niv 1 · Moyen 0 min · sans objet", "L6": "Niv 6 · Moyen 6 min · 6 objets neutres",
             "L12": "Niv 12 · Difficile ét.3 4 min · 15 objets neutres"}


def roster() -> list[dict]:
    data = json.loads((GAME / "data" / "characters.json").read_text(encoding="utf-8"))
    return [c for c in data if c.get("playable", True)]


def run_godot(cid: str, seeds: int, k: int, timeout: int) -> dict:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"sim_{cid}.json"
    log = OUT_DIR / f"sim_{cid}.log"
    if out.exists():
        out.unlink()
    cmd = [GODOT, "--headless", "--path", str(GAME), "res://tests/balance_sim_run.tscn", "--",
           f"--chars={cid}", f"--out={out.as_posix()}", f"--seeds={seeds}", f"--k={k}"]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        text = (p.stdout or "") + "\n" + (p.stderr or "")
        code = p.returncode
    except subprocess.TimeoutExpired as e:
        text = (e.stdout or "") if isinstance(e.stdout, str) else ""
        code = -999
    log.write_text(text, encoding="utf-8")
    script_errors = [ln.strip() for ln in text.splitlines() if "SCRIPT ERROR" in ln or "Parse Error" in ln]
    res = {"char": cid, "ok": False, "skip": False, "note": "", "fights": [], "load_errors": []}
    if out.exists():
        try:
            res = json.loads(out.read_text(encoding="utf-8"))["characters"][0]
        except Exception as ex:  # JSON tronqué
            res["note"] = f"sortie illisible ({ex})"
    elif code == -999:
        res["note"] = f"délai dépassé ({timeout} s)"
    else:
        res["note"] = f"Godot a échoué (code {code}), voir {log.name}"
    res["script_errors"] = script_errors[:30]
    res["wall_s"] = round(time.time() - t0, 1)
    out.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    return res


def mean(xs):
    xs = [x for x in xs if x is not None]
    return statistics.fmean(xs) if xs else None


def aggregate(res: dict) -> dict:
    """(cfg, scen) -> métriques moyennes sur les graines."""
    groups: dict[tuple, list] = {}
    for f in res.get("fights", []):
        groups.setdefault((f["config"], f["scenario"]), []).append(f)
    out = {}
    for key, fs in groups.items():
        maxhp = mean([f.get("max_hp", 0) for f in fs]) or 1.0
        dur = mean([f["duration"] for f in fs])
        all_clear = all(f["cleared"] for f in fs)
        casts = {}
        for s in ("1", "2", "3", "4"):
            casts[s] = mean([f["casts"].get(s, 0) / f["duration"] * 60.0 for f in fs])
        out[key] = {
            "n": len(fs), "cleared": sum(1 for f in fs if f["cleared"]), "dur": dur,
            "ttk": mean([f["ttk"] for f in fs]) if all_clear else None,
            "dps": mean([f["dps"] for f in fs]), "kpm": mean([f["kpm"] for f in fs]),
            "kills": mean([f["kills"] for f in fs]), "total": fs[0].get("total", 0),
            "taken": mean([f["taken"] for f in fs]),
            "taken_pct_min": mean([f["taken"] / max(f.get("max_hp", maxhp), 1.0) * 100.0 / f["duration"] * 60.0 for f in fs]),
            "deaths": sum(f["deaths"] for f in fs), "hp_min": min(f["hp_min"] for f in fs),
            "dodges": mean([f["dodges"] for f in fs]), "max_hp": maxhp, "pref_u": fs[0].get("pref_u"),
            "casts": casts, "resource": fs[0].get("resource", ""),
            "res_mean": mean([f["res_mean"] for f in fs if f.get("res_mean", -1) >= 0]),
            "res_uptime": mean([f["res_uptime"] for f in fs if f.get("res_uptime", -1) >= 0]),
            "errors": sum(len(f.get("errors", [])) for f in fs),
        }
    return out


def ratio(v, b):
    if v is None or b is None or b == 0:
        return None
    return v / b


def fmt_ratio(r, higher_is_good=True, small=False):
    if r is None:
        return "n/a"
    pct = (r - 1.0) * 100.0
    s = f"{pct:+.0f} %"
    if abs(r - 1.0) > FLAG and not small:
        good = (r > 1.0) == higher_is_good
        s = f"**{s}** {'▲' if good else '▼'}"
    return s


def fnum(v, nd=1):
    return "n/a" if v is None else f"{v:.{nd}f}"


def summary_row(agg: dict, cfg: str) -> dict:
    g = lambda s, k: (agg.get((cfg, s)) or {}).get(k)
    single = [x for x in (g("elite", "dps"), g("miniboss", "dps")) if x is not None]
    ttks = {s: g(s, "ttk") for s in SCEN_LABEL}
    taken = [g(s, "taken_pct_min") for s in SCEN_LABEL if g(s, "taken_pct_min") is not None]
    deaths = sum((g(s, "deaths") or 0) for s in SCEN_LABEL)
    return {
        "aoe_dps": g("swarm", "dps"), "mixed_dps": g("mixed", "dps"),
        "st_dps": statistics.fmean(single) if single else None,
        "ttk": ttks, "taken": statistics.fmean(taken) if taken else None, "deaths": deaths,
        "kpm": g("swarm", "kpm"), "res": g("mixed", "res_uptime"), "res_name": g("mixed", "resource"),
    }


def write_reports(results: list[dict]) -> None:
    aggs = {r["char"]: aggregate(r) for r in results if r.get("ok")}
    base = aggs.get(BASE)
    cfgs = ["L1", "L6", "L12"]
    lines = []
    A = lines.append
    A("# Rapport d'équilibrage des personnages (simulateur automatique)")
    A("")
    A(f"Généré le {time.strftime('%d/%m/%Y %H:%M')} par `art/tools/night/balance_sim.py` "
      "(scène `game/tests/balance_sim_run.tscn`, code `game/tests/balance_sim/`). Référence : **Ardent** ; "
      f"écart > ±{int(FLAG*100)} % en **gras** (▲ favorable, ▼ défavorable au personnage).")
    A("")
    A("**Méthode** : arène vide, vrai joueur + vrai kit, pilote scripté identique pour tous (distance = portée utile "
      "du sort 1, va au contact pour lancer un sort 2-4 prêt à courte portée, kite, sort des télégraphes, roulade si "
      "l'impact est imminent ; sorts 2-4 en auto-cast du jeu, ciblage automatique mobile). Monstres réels du Director "
      "(IA, télégraphes, projectiles). D figé par config ; objets neutres sans proc (dégâts, vitesse d'attaque, PV, "
      "armure, recharge, critique). Morts : le joueur est relevé et la mort comptée. DPS = dégâts effectifs (sans "
      "overkill) / durée du combat. **DPS cible** = moyenne Élite + Mini-boss ; **DPS zone** = essaim de 64 T1.")
    A("")
    A("Limites : pilote moyen (réagit aux télégraphes après 0,2 s, en rate 25 %), pas de pickups ni de montée de "
      "niveau pendant le combat, pas de carte (ni murs ni goulets), **pas d'AmbianceManager** : pluie moyenne (repli du kit) "
      "pour Averse, or de poche fixe (0 / 150 / 400 selon la config, pour Avare), objets neutres seulement. "
      "L'essaim de 64 T1 arrive en ~5 s : au-delà d'un certain DPS le TTK essaim sature (arrivée des monstres). "
      f"Dégâts subis : écart signalé seulement s'il dépasse aussi {TAKEN_FLOOR:.0f} % PV/min en absolu. "
      "Les ratios valent plus que les valeurs absolues.")
    A("")
    # statut
    A("## Statut des personnages")
    A("")
    A("| Perso | Statut | Note | Erreurs de script | Autres erreurs moteur |")
    A("|---|---|---|---|---|")
    for r in results:
        st = "simulé" if r.get("ok") else ("sauté" if r.get("skip") else "**ÉCHEC**")
        ferr = [e for f in r.get("fights", []) for e in f.get("errors", [])] + r.get("load_errors", [])
        nscript = len(r.get("script_errors", [])) + sum(1 for e in ferr if e.get("type") == 2)
        nother = sum(1 for e in ferr if e.get("type") != 2)
        A(f"| {r['char']} | {st} | {r.get('note') or ''} | {nscript} | {nother} |")
    A("")
    if base is None:
        A("Ardent n'a pas été simulé : pas de comparaison possible.")
    # synthèse
    for cfg in cfgs:
        if base is None or not any((cfg, s) in base for s in SCEN_LABEL):
            continue
        b = summary_row(base, cfg)
        A(f"## Synthèse : {CFG_LABEL[cfg]}")
        A("")
        A("| Perso | DPS zone | DPS mixte | DPS cible | TTK essaim | TTK mixte | TTK élite | TTK mini-boss | Dégâts subis (% PV/min) | Morts | Kills/min essaim | Ressource ≥ 50 % |")
        A("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for cid, agg in aggs.items():
            s = summary_row(agg, cfg)

            def cell(v, bv, good=True, nd=0, unit="", floor=0.0):
                if v is None:
                    return "n/a"
                if cid == BASE:
                    return f"{v:.{nd}f}{unit}"
                small = bv is not None and abs(v - bv) < floor
                return f"{v:.{nd}f}{unit} ({fmt_ratio(ratio(v, bv), good, small)})"

            ttk = lambda sc: cell(s["ttk"][sc], b["ttk"][sc], False, 1, " s") if s["ttk"][sc] is not None else "non fini"
            res = "—" if s["res"] is None else f"{s['res']*100:.0f} %"
            A(f"| {cid} | {cell(s['aoe_dps'], b['aoe_dps'])} | {cell(s['mixed_dps'], b['mixed_dps'])} | "
              f"{cell(s['st_dps'], b['st_dps'])} | {ttk('swarm')} | {ttk('mixed')} | {ttk('elite')} | {ttk('miniboss')} | "
              f"{cell(s['taken'], b['taken'], False, 1, floor=TAKEN_FLOOR)} | {s['deaths']} | {cell(s['kpm'], b['kpm'])} | {res} |")
        A("")
    # alertes
    A("## Écarts signalés (> ±20 % vs Ardent)")
    A("")
    any_flag = False
    for cid, agg in aggs.items():
        if cid == BASE:
            continue
        for cfg in cfgs:
            if base is None:
                continue
            b, s = summary_row(base, cfg), summary_row(agg, cfg)
            items = []
            for k, lab, good in (("aoe_dps", "DPS zone", True), ("mixed_dps", "DPS mixte", True), ("st_dps", "DPS cible", True),
                                 ("taken", "dégâts subis", False), ("kpm", "kills/min", True)):
                r = ratio(s[k], b[k])
                if k == "taken" and s[k] is not None and b[k] is not None and abs(s[k] - b[k]) < TAKEN_FLOOR:
                    continue
                if r is not None and abs(r - 1) > FLAG:
                    items.append(f"{lab} {(r-1)*100:+.0f} %")
            for sc in SCEN_LABEL:
                r = ratio(s["ttk"][sc], b["ttk"][sc])
                if r is not None and abs(r - 1) > FLAG:
                    items.append(f"TTK {SCEN_LABEL[sc]} {(r-1)*100:+.0f} %")
                elif s["ttk"][sc] is None and b["ttk"][sc] is not None:
                    items.append(f"{SCEN_LABEL[sc]} non fini")
            if s["deaths"] > b["deaths"]:
                items.append(f"morts {s['deaths']} (Ardent {b['deaths']})")
            if items:
                any_flag = True
                A(f"- **{cid}**, {cfg} : " + " ; ".join(items))
    if not any_flag:
        A("Aucun écart au-delà du seuil.")
    A("")
    # détail
    A("## Détail par combat")
    A("")
    A("Moyennes sur les graines. Lancers par minute par slot (s1 auto / s2 / s3 / s4 ultime) ; esquives = roulades du pilote.")
    A("")
    A("| Perso | Config | Scénario | Fini | Durée s | TTK s | DPS | Kills | Subis | % PV/min | Morts | PV min | Lancers/min s1·s2·s3·s4 | Esquives | Dist. pilote u |")
    A("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for cid, agg in aggs.items():
        for cfg in cfgs:
            for sc in SCEN_LABEL:
                a = agg.get((cfg, sc))
                if not a:
                    continue
                c = a["casts"]
                A(f"| {cid} | {cfg} | {SCEN_LABEL[sc]} | {a['cleared']}/{a['n']} | {fnum(a['dur'])} | {fnum(a['ttk'])} | "
                  f"{fnum(a['dps'])} | {fnum(a['kills'],0)}/{a['total']} | {fnum(a['taken'],0)} | {fnum(a['taken_pct_min'])} | "
                  f"{a['deaths']} | {a['hp_min']*100:.0f} % | {fnum(c['1'],0)}·{fnum(c['2'],1)}·{fnum(c['3'],1)}·{fnum(c['4'],1)} | "
                  f"{fnum(a['dodges'],1)} | {fnum(a['pref_u'],1)} |")
    A("")
    errs = [(r["char"], e) for r in results for e in r.get("script_errors", [])]
    ferrs = [(r["char"], e) for r in results for f in r.get("fights", []) for e in f.get("errors", [])]
    lerrs = [(r["char"], e) for r in results for e in r.get("load_errors", [])]
    if errs or ferrs or lerrs:
        A("## Erreurs relevées")
        A("")
        seen = set()
        for cid, e in errs:
            if (cid, e) not in seen:
                seen.add((cid, e))
                A(f"- {cid} : `{e[:180]}`")
        per = {}
        for cid, e in ferrs + lerrs:
            key = (cid, e.get("where"), e.get("msg"))
            if key in seen:
                continue
            seen.add(key)
            per[cid] = per.get(cid, 0) + 1
            if per[cid] <= 8:
                kind = "script" if e.get("type") == 2 else "moteur"
                A(f"- {cid} ({kind}) : `{e.get('where')}` {str(e.get('msg'))[:160]}")
            elif per[cid] == 9:
                A(f"- {cid} : … (autres erreurs dans art/tools/night/balance_sim/sim_{cid}.json)")
        A("")
    rec = Path(__file__).resolve().parent / "balance_recommandations.md"
    if rec.exists():
        A(rec.read_text(encoding="utf-8").strip())
        A("")
    REPORT_MD.write_text("\n".join(lines), encoding="utf-8")

    # CSV
    with REPORT_CSV.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, delimiter=";")
        w.writerow(["char", "config", "scenario", "seeds", "cleared", "duration_s", "ttk_s", "dps", "kills", "total",
                    "kills_per_min", "damage_taken", "taken_pct_hp_per_min", "deaths", "hp_min_frac", "dodges",
                    "casts_min_s1", "casts_min_s2", "casts_min_s3", "casts_min_s4", "resource", "res_mean", "res_uptime",
                    "dps_vs_ardent", "ttk_vs_ardent", "taken_vs_ardent", "flags"])
        for cid, agg in aggs.items():
            for (cfg, sc), a in sorted(agg.items()):
                ba = (base or {}).get((cfg, sc), {})
                rd, rt, rk = ratio(a["dps"], ba.get("dps")), ratio(a["ttk"], ba.get("ttk")), ratio(a["taken_pct_min"], ba.get("taken_pct_min"))
                flags = [n for n, r in (("dps", rd), ("ttk", rt), ("taken", rk)) if r is not None and abs(r - 1) > FLAG]
                c = a["casts"]
                w.writerow([cid, cfg, sc, a["n"], a["cleared"], f"{a['dur']:.2f}", "" if a["ttk"] is None else f"{a['ttk']:.2f}",
                            f"{a['dps']:.2f}", f"{a['kills']:.1f}", a["total"], f"{a['kpm']:.1f}", f"{a['taken']:.1f}",
                            f"{a['taken_pct_min']:.2f}", a["deaths"], f"{a['hp_min']:.3f}", f"{a['dodges']:.1f}",
                            *(f"{c[s]:.2f}" for s in "1234"), a["resource"] or "",
                            "" if a["res_mean"] is None else f"{a['res_mean']:.3f}",
                            "" if a["res_uptime"] is None else f"{a['res_uptime']:.3f}",
                            "" if rd is None else f"{rd:.3f}", "" if rt is None else f"{rt:.3f}", "" if rk is None else f"{rk:.3f}",
                            ",".join(flags)])
        for r in results:
            if not r.get("ok"):
                w.writerow([r["char"], "", "", 0, 0, "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
                            "", "", "", ("skip: " if r.get("skip") else "fail: ") + (r.get("note") or "")])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chars", default="")
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--k", type=int, default=12)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--report-only", action="store_true")
    a = ap.parse_args()
    ids = [c["id"] for c in roster()]
    if a.chars:
        ids = [x for x in a.chars.split(",") if x]
    if BASE not in ids and not a.report_only:
        ids.insert(0, BASE) if not (OUT_DIR / f"sim_{BASE}.json").exists() else None
    results = []
    if not a.report_only:
        for cid in ids:
            print(f"== {cid}", flush=True)
            r = run_godot(cid, a.seeds, a.k, a.timeout)
            print(f"   ok={r.get('ok')} note={r.get('note')} fights={len(r.get('fights', []))} "
                  f"script_errors={len(r.get('script_errors', []))} ({r.get('wall_s')} s)", flush=True)
    # rapport : tous les JSON présents (permet de relancer un seul perso)
    for c in [x["id"] for x in roster()]:
        p = OUT_DIR / f"sim_{c}.json"
        if p.exists():
            results.append(json.loads(p.read_text(encoding="utf-8")))
        else:
            results.append({"char": c, "ok": False, "skip": True, "note": "pas encore simulé", "fights": []})
    write_reports(results)
    print(f"Rapport : {REPORT_MD}\nCSV : {REPORT_CSV}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
