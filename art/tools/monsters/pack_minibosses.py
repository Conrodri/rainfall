"""Emballe les 6 mini-boss (170 px): run en 4 directions e/s/w/n, le reste en s. Python systeme (PIL vendor)."""
import subprocess,sys
from pathlib import Path
here=Path(__file__).resolve().parent
SPECS=['idle:10','run:12','attack:12','cast_a:12','cast_b:12','phase2:8:noloop','death:12:noloop']
names=sys.argv[1:] or ['stone_colossus','frost_bear','rust_archon','bramble_queen','brood_mother','ash_lord']
for n in names:
    subprocess.run([sys.executable,str(here/'pack_monsters.py'),'bosses/mini',n,'170',*SPECS,'--anim-dirs','run=e,s,w,n',*(['--preserve-tres'] if n in ('ash_lord','bramble_queen','brood_mother','rust_archon','frost_bear','stone_colossus') else [])],check=True)
