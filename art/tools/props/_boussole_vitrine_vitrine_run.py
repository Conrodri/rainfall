import sys
from pathlib import Path
sys.argv.append('--vitrine')
script=Path(__file__).with_name('boussole_vitrine_build.py')
exec(compile(script.read_text(encoding='utf-8'),str(script),'exec'),{'__name__':'__main__','__file__':str(script)})
