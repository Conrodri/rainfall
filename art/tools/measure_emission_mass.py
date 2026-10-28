"""Mesure la masse émissive de chaque masque <f>_e.png des boss et mini-boss (lecture seule des PNG).

masse = moyenne de (luminance Rec.709 x alpha) sur l'image entière.
Écrit game/data/boss_emission_mass.json {"res://...<f>_e.png": masse}, lu par NormalMaps.boss_gain
(normalisation automatique de l'énergie d'émission des boss : plafond, voir normal_maps.gd).
Écrit aussi game/data/boss_albedo_lum.json {"<id>": {"mean", "p90"}} : luminance (Rec.709) des pixels opaques
de idle.png de chaque mini-boss/boss ; lu par NormalMaps.albedo_p90 (le gain de corps des mini-boss est plafonné
pour qu'un sprite clair, sel ou os, ne grille pas : Balance.MINI_BODY_MEAN_MAX).
À relancer après chaque re-rendu de boss (le test boss_glow_cap_test signale les masques absents de la table).
  C:/Users/const/AppData/Local/Python/bin/python.exe art/tools/measure_emission_mass.py
"""
import glob
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game")
ROOT = os.path.normpath(ROOT)
out = {}
for p in sorted(glob.glob(os.path.join(ROOT, "assets", "sprites", "bosses", "**", "*_e.png"), recursive=True)):
    a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255.0
    lum = (a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722) * a[..., 3]
    rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
    out["res://" + rel] = round(float(lum.mean()), 5)
dst = os.path.join(ROOT, "data", "boss_emission_mass.json")
with open(dst, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=0, sort_keys=True)
print(len(out), "masques ->", dst)

alb = {}
for p in sorted(glob.glob(os.path.join(ROOT, "assets", "sprites", "bosses", "*", "*", "idle.png"))):
    a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255.0
    m = a[..., 3] > 0.5
    if not m.any():
        continue
    lum = (a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722)[m]
    alb[os.path.basename(os.path.dirname(p))] = {"mean": round(float(lum.mean()), 4), "p90": round(float(np.percentile(lum, 90)), 4)}
dst = os.path.join(ROOT, "data", "boss_albedo_lum.json")
with open(dst, "w", encoding="utf-8") as f:
    json.dump(alb, f, indent=0, sort_keys=True)
print(len(alb), "albédos ->", dst)
