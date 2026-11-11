"""Génère les profils d'ambiance .tres des Ciels v1 (apres_midi_d_orage, canicule_de_cendres, maree_haute).

Chaque profil est la copie du profil de la carte (game/data/ambiance/<map_id>.tres) dont on change les réglages du
brief art/briefs/cosmetics/ciels.md §3 : lumière, brume, pluie, ciel reflété, particules. Les paliers de D
(tier_overrides) sont conservés ; leurs couleurs et énergies de lumière sont rééchelonnées sur le nouveau palier Calme.
Ce ne sont pas des assets visuels : réglages de données. Usage : python ciels_profils_build.py (depuis la racine).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AMB = ROOT / "game/data/ambiance"
SCALED_COLORS = ("ambient_color", "ambient_low", "sun_color")


def parse_color(s):
    m = re.search(r"Color\(([^)]*)\)", s)
    return [float(v) for v in m.group(1).split(",")]


def fmt(v):
    return ("%.6g" % v)


def col(c, a=1.0):
    return "Color(%s, %s, %s, %s)" % (fmt(c[0]), fmt(c[1]), fmt(c[2]), fmt(a))


def particle_block(defs):
    out = ["particle_defs = Array[Dictionary]([{"]
    for i, d in enumerate(defs):
        keys = sorted(d)
        out += ['"%s": %s' % (k, d[k]) + ("," if j < len(keys) - 1 else "") for j, k in enumerate(keys)]
        out.append("}, {" if i < len(defs) - 1 else "}])")
    return "\n".join(out)


def pdef(additive, alpha, behavior, color, name, size, speed, texture, **extra):
    d = {
        "additive": "true" if additive else "false",
        "alpha": fmt(alpha),
        "behavior": '&"%s"' % behavior,
        "color": col(color),
        "name": '"%s"' % name,
        "size_u": "Vector2(%s, %s)" % (fmt(size[0]), fmt(size[1])),
        "speed_u": fmt(speed),
        "texture": '&"%s"' % texture,
    }
    for k, v in extra.items():
        d[k] = fmt(v)
    return d


def split(text):
    i = text.index("tier_overrides = {")
    return text[:i], text[i:]


def set_key(head, key, value):
    pat = re.compile(r"^%s = .*$" % re.escape(key), re.M)
    if pat.search(head):
        return pat.sub(lambda m: "%s = %s" % (key, value), head, count=1)
    return head.rstrip("\n") + "\n%s = %s\n" % (key, value)


def get_key(head, key):
    m = re.search(r"^%s = (.*)$" % re.escape(key), head, re.M)
    return m.group(1) if m else None


def build(base_id, ciel_id, cfg):
    text = (AMB / (base_id + ".tres")).read_text(encoding="utf-8")
    head, tiers = split(text)
    base_top = {k: parse_color(get_key(head, k)) for k in SCALED_COLORS if get_key(head, k)}
    base_energy = float(get_key(head, "sun_energy") or 0.4)
    # Palier Calme : réglages du Ciel.
    for k, v in cfg["set"].items():
        head = set_key(head, k, v)
    head = re.sub(r"^mood = .*$", lambda m: 'mood = "%s"' % cfg["mood"], head, count=1, flags=re.M)
    head = re.sub(r"particle_defs = Array\[Dictionary\]\(\[\{.*?\n\}\]\)", lambda m: particle_block(cfg["particles"]), head, count=1, flags=re.S)
    new_top = {k: parse_color(get_key(head, k)) for k in SCALED_COLORS if get_key(head, k)}
    new_energy = float(get_key(head, "sun_energy"))
    # Paliers : couleurs/énergie de lumière rééchelonnées, clés retirées selon la config.
    lines = []
    tier = None
    for ln in tiers.split("\n"):
        m = re.match(r'^&"(\w+)": \{', ln)
        if m:
            tier = m.group(1)
        km = re.match(r'^&"(\w+)": (.*?)(,?)$', ln)
        if km and tier:
            key, val, comma = km.group(1), km.group(2), km.group(3)
            if tier in cfg.get("drop_tiers", ()) and re.match(cfg["drop_keys"], key):
                continue
            if key in SCALED_COLORS and key in base_top:
                c = parse_color(val)
                r = [min(1.0, c[i] * new_top[key][i] / max(base_top[key][i], 1e-3)) for i in range(3)]
                ln = '&"%s": %s%s' % (key, col(r), comma)
            elif key == "sun_energy":
                ln = '&"sun_energy": %s%s' % (fmt(float(val) * new_energy / max(base_energy, 1e-3)), comma)
        lines.append(ln)
    tiers = "\n".join(lines)
    # La dernière clé d'un palier ne doit pas porter de virgule orpheline : on nettoie.
    tiers = re.sub(r",\n\}", "\n}", tiers)
    out = AMB / ("%s_%s.tres" % (base_id, ciel_id))
    out.write_text(head + tiers, encoding="utf-8", newline="\n")
    print("écrit", out.relative_to(ROOT))


NOTE = "Palier Calme du Ciel ; au-delà, les paliers de D de la carte reprennent."

ORAGE = {
    "mood": "Après-midi d'orage (16 h) : rayons chauds entre les cèdres, feuilles qui tombent, tonnerre au loin. " + NOTE,
    "set": {
        "ambient_color": col([0.52, 0.47, 0.39]), "ambient_low": col([0.52, 0.47, 0.39]),
        "sun_color": col([1.0, 0.78, 0.55]), "sun_energy": "1.3",
        "fill_color": col([0.78, 0.74, 0.7]),
        "rain_intensity": "0.35", "rain_opacity": "0.07", "rain_layers": "1.0", "rain_tint": col([0.86, 0.82, 0.74]),
        "splash_rate": "40.0",
        "fog_low_color": col([0.86, 0.74, 0.58]), "fog_low_opacity": "0.2",
        "rays_count": "6.0", "rays_opacity": "0.16", "rays_color": col([1.0, 0.8, 0.55]),
        "lightning_interval_min": "20.0", "lightning_interval_max": "45.0", "lightning_flash": "0.3", "lightning_sun": "0.0",
        "sky_texture": '&"sky_apres_midi_d_orage_256x64"', "sky_reflect": "0.4", "puddle_reflect": "0.55", "water_reflect": "0.6",
        "p1_amount": "14.0", "p2_amount": "0.0", "p3_amount": "0.0",
    },
    "particles": [pdef(False, 0.8, "fall", [1.0, 0.9, 0.72], "feuilles de cèdre", (0.2, 0.32), 0.9, "leaf_cedar_32", drift_u=0.5, spin_dps=60.0)],
}
CANICULE = {
    "mood": "Midi de canicule : ciel ocre brûlé, brume de chaleur, cendres qui montent des fonderies, sans pluie. La pluie revient quand D atteint le palier Hostile. " + NOTE,
    "set": {
        "ambient_color": col([0.58, 0.5, 0.41]), "ambient_low": col([0.58, 0.5, 0.41]),
        "sun_color": col([1.0, 0.85, 0.62]), "sun_energy": "1.5",
        "fill_color": col([0.82, 0.74, 0.62]),
        "rain_intensity": "0.0", "splash_rate": "0.0", "drops_amount": "0.0", "rain_tint": col([0.9, 0.8, 0.65]),
        "fog_low_color": col([0.93, 0.78, 0.55]), "fog_low_opacity": "0.3",
        "lightning_interval_min": "0.0", "lightning_interval_max": "0.0", "lightning_flash": "0.0",
        "horizon_interval_min": "0.0", "horizon_interval_max": "0.0",
        "sky_texture": '&"sky_canicule_de_cendres_256x64"', "sky_reflect": "0.3", "puddle_reflect": "0.25", "water_reflect": "0.4",
        "p1_amount": "40.0",
    },
    "particles": [pdef(False, 0.55, "rise", [0.62, 0.56, 0.5], "cendres montantes", (0.08, 0.14), 0.6, "ash_16")],
    "drop_tiers": ("Tendu",),
    "drop_keys": r"(rain_|lightning_|horizon_|splash_rate|drops_amount)",
}
MAREE = {
    "mood": "Marée haute : l'eau monte, reflets plus hauts, bulles qui remontent, lumière verte filtrée par la marée. " + NOTE,
    "set": {
        "ambient_color": col([0.42, 0.53, 0.5]), "ambient_low": col([0.45, 0.56, 0.53]),
        "sun_color": col([0.6, 0.78, 0.72]), "sun_energy": "0.8",
        "fill_color": col([0.6, 0.76, 0.72]),
        "fog_low_color": col([0.55, 0.8, 0.72]), "fog_low_opacity": "0.3",
        "sky_texture": '&"sky_maree_haute_256x64"', "sky_reflect": "0.15", "puddle_reflect": "0.5", "water_reflect": "0.45",
        "p3_amount": "28.0",
    },
    "particles": None,  # base + bulles, voir plus bas
}

if __name__ == "__main__":
    for base in ("foret_brume", "foret_mangrove_lanternes"):
        build(base, "apres_midi_d_orage", ORAGE)
    for base in ("cite_rouille", "cite_fonderie_canal"):
        build(base, "canicule_de_cendres", CANICULE)
    bubble = pdef(True, 0.6, "rise", [0.8, 1.0, 0.9], "bulles de marée", (0.06, 0.12), 0.35, "bubble_16", lifetime=6.0)
    gouttes = pdef(False, 0.45, "fall", [0.749, 0.898, 0.961], "gouttes des voûtes", (0.06, 0.12), 6.0, "drop_32")
    sel = pdef(True, 0.5, "drift", [0.749, 0.957, 1.0], "poussière de sel", (0.04, 0.08), 0.15, "ash_16")
    MAREE["particles"] = [gouttes, sel, bubble]
    for base in ("cryptes_noyees", "cryptes_ossuaire_pluies"):
        build(base, "maree_haute", MAREE)
