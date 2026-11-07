"""LANCZOS resize and compact RGBA delivery for Forge icons."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image
Image.open(sys.argv[1]).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(sys.argv[2],optimize=True)
