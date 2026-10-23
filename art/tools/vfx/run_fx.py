"""Rendu des effets. Usage : blender --background --python run_fx.py -- nom[:anim] ..."""
import sys, importlib
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy, vfx_lib as L
import fx_all as fx_defs
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for spec in argv:
    name, _, only = spec.partition(':')
    E = fx_defs.EFFECTS[name]
    w, h = E['size']
    L.setup(w, h, tz=E.get('tz', 0.0), ty=E.get('ty', 0.0), samples=E.get('samples', 24), ppu=E.get('ppu', 64.0))
    for anim, A in E['anims'].items():
        if only and anim != only: continue
        n = A['n']
        for f in range(n):
            L.clear()
            A['build'](f, n)
            L.render(name, anim, f, 6.283185307 * f / n)
            print('frame', name, anim, f, flush=True)
    out = L.ROOT / 'art/blender/vfx'; out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / (name + '.blend')))
