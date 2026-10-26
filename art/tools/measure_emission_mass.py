"""Mesure la masse émissive de chaque masque <f>_e.png des boss et mini-boss (lecture seule des PNG).

masse = moyenne de (luminance Rec.709 x alpha) sur l'image entière.
Écrit game/data/boss_emission_mass.json {"res://...<f>_e.png": masse}, lu par NormalMaps.boss_gain
(normalisation automatique de l'énergie d'émission des boss : plafond, voir normal_maps.gd).
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
