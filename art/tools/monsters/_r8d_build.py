import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
assert '--build-only' in sys.argv
from frost_bear_build import build as bear
from stone_colossus_build import build as stone
bear()
stone()
