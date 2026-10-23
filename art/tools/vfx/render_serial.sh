#!/bin/bash
# UNE seule instance Blender, tous les effets l'un apres l'autre. usage: render_serial.sh eff1 eff2 ...
BL="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
cd "$(dirname "$0")"
"$BL" --background --python run_fx.py -- "$@" > /tmp/fx_serial.log 2>&1
echo SERIAL_DONE >> /tmp/fx_serial.log
