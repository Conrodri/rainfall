#!/usr/bin/env sh
# Lance Godot sur le projet game/ sous un verrou partagé (plusieurs agents en parallèle :
# un seul import / une seule capture à la fois, sinon le cache .godot se corrompt).
# Usage : sh art/tools/vfx_test/godot_locked.sh <arguments godot...>   (ex. --headless --import)
GODOT="/c/Users/const/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
LOCK="/c/Users/const/AppData/Local/Temp/rf_godot.lock"
n=0
until mkdir "$LOCK" 2>/dev/null; do
  n=$((n+1))
  # verrou orphelin (> 15 min) : on le casse
  if [ $n -gt 450 ]; then rmdir "$LOCK" 2>/dev/null; n=0; fi
  sleep 2
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
cd "$(dirname "$0")/../../../game" && "$GODOT" --path . "$@"
