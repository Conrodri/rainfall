#!/bin/sh
# Sequentiel, une seule instance Blender a la fois.
cd "C:/Users/const/Documents/Rainfall/art/tools/monsters"
for n in swarm_tier1 shooter_tier2 leaper_tier2 brute_tier3; do
 "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python lowcam_monster.py -- $n > ../_log_lowcam_$n.txt 2>&1
done
