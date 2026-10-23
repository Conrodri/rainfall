#!/bin/sh
# Sequentiel, une seule instance Blender a la fois.
cd "C:/Users/const/Documents/Rainfall/art/tools/monsters"
for n in stone_colossus frost_bear rust_archon bramble_queen brood_mother ash_lord; do
 "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python lowcam_boss.py -- $n > ../_log_lowcam_$n.txt 2>&1
done
