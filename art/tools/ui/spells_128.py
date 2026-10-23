"""Réduit les icônes de sorts (rendus bruts Blender) en 128 px pour le HUD. Pillow : réduction seulement."""
import sys, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image
D=ROOT/'game/assets/sprites/icons/spells'; B=ROOT/'art/renders/ui/spells_256'; R=ROOT/'art/renders/ui/spells'
for n in ['eclat_de_braise','nova_ardente','cendres','brasier','braises_errantes','pilier_de_flamme','pluie_de_meteores','phenix']:
    p=D/f'{n}.png'; b=B/f'{n}.png'
    im=Image.open(p)
    if im.size==(256,256) and not b.exists(): shutil.copy(p,b)
    src=Image.open(b).convert('RGBA') if b.exists() else im.convert('RGBA')
    src.resize((128,128),Image.Resampling.LANCZOS).save(p); print(n,Image.open(p).size)
