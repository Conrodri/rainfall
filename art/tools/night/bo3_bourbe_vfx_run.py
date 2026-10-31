from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/characters')]
import cel_style, bo3_build
cel_style.install('vfx',normals=False)
bo3_build.effects()
print('BOURBE VFX PASS: bog_zone, mud_slap, mud_splash',flush=True)
