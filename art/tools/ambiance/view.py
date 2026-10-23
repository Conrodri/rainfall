"""Planche de controle : blender --background --python view.py -- out.png cell cols file1 file2 ..."""
import sys; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))
from amb_lib import *
a = sys.argv[sys.argv.index('--') + 1:]
out, cell, cols = a[0], int(a[1]), int(a[2])
files = [OUT / f if not Path(f).is_absolute() else Path(f) for f in a[3:]]
montage(files, out, cell=cell, cols=cols)
