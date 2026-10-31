"""Applique à data/maps/foret_brume.json et foret_mangrove_lanternes.json UNIQUEMENT les textes de l'étage 2 « Le Gouffre luisant »
(nom, noms d'événements, événement ambiant, habillage et gardiens du secret), sans régénérer la grille ni le reste.

Utile quand un autre chantier (rendu du sol, cartes) a modifié les JSON à la main et qu'un `python tools/gen_maps.py`
complet les écraserait. Les valeurs viennent de tools/gen_maps.py, lancé vers un dossier temporaire (variable GEN_MAPS_OUT).

    C:/Users/const/AppData/Local/Python/bin/python.exe tools/patch_gouffre_texts.py

Idempotent. Conserve le format (indent 1, UTF-8, fin de ligne d'origine).
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "game")  # argument : dossier game/ alternatif (essai)
IDS = ["foret_brume", "foret_mangrove_lanternes"]
PY = sys.executable


def read(path):
    raw = open(path, encoding="utf-8", newline="").read()
    return json.loads(raw), "\r\n" if "\r\n" in raw else "\n"


def main():
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, GEN_MAPS_OUT=tmp)
        subprocess.run([PY, os.path.join(ROOT, "tools", "gen_maps.py")], env=env, check=True, stdout=subprocess.DEVNULL)
        for mid in IDS:
            src, _ = read(os.path.join(tmp, "data", "maps", mid + ".json"))
            dst_path = os.path.join(GAME, "data", "maps", mid + ".json")
            dst, nl = read(dst_path)
            dst["name"] = src["name"]
            dst["events"]["types"] = src["events"]["types"]
            dst["ambient_event"] = src["ambient_event"]
            for ds, ss in zip(dst.get("secrets", []), src.get("secrets", [])):
                ds["skin"] = ss["skin"]
                ds["guardian_names"] = ss["guardian_names"]
            text = json.dumps(dst, ensure_ascii=False, indent=1) + "\n"
            open(dst_path, "w", encoding="utf-8", newline="").write(text.replace("\n", nl))
            print("texte appliqué :", mid)


if __name__ == "__main__":
    main()
