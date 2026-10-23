import sys
sys.dont_write_bytecode=True
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from cd_cd1_common import run
run('averse')
