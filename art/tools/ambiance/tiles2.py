import sys; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))
from amb_lib import *
for n in ['fog_volume_tile_1024','fog_volume_tile_1024_2','canopy_shadow_2048','canopy_shadow_2048_2','water_caustics_512','water_caustics_512_2']:
    tile2x2(OUT/f'{n}.png', RAW/f'tile2x2_{n}.png', 512)
montage([RAW/f'tile2x2_{n}.png' for n in ['fog_volume_tile_1024','canopy_shadow_2048','water_caustics_512']], 'C:/Users/const/AppData/Local/Temp/t2.png', cell=512, cols=3)
