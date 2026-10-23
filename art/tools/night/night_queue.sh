#!/bin/sh
# File de nuit Codex : groupes de lots lancés en parallèle (périmètres disjoints), groupe après groupe.
# Chaque ligne de queue.txt : <groupe> <consigne> <journal> <effort>. Un lot déjà fini (.last.txt présent et
# journal sans « usage limit ») est sauté : la file peut être relancée sans refaire le travail.
# Quota Codex épuisé : on lit « try again at H:MM AM » dans le journal, on attend l'heure (+3 min) et on relance.
cd "$(dirname "$0")/../../.." || exit 1
QUEUE=art/tools/night/queue.txt
REPORT=art/tools/night/night_report.md
GODOT="/c/Users/const/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
PY="C:/Users/const/AppData/Local/Python/bin/python.exe"

log() { echo "- $(date '+%d/%m %H:%M') $*" >> "$REPORT"; }

wait_quota() { # $1 = journal
	t=$(grep -o "try again at [0-9]*:[0-9]* [AP]M" "$1" | tail -1 | sed 's/try again at //')
	now=$(date +%s)
	if [ -n "$t" ]; then
		target=$(date -d "$t" +%s 2>/dev/null || echo 0)
		[ "$target" -le "$now" ] && target=$((target + 86400))
		target=$((target + 180))
	else
		target=$((now + 1800))
	fi
	[ $((target - now)) -gt 43200 ] && target=$((now + 1800)) # garde-fou : jamais plus de 12 h
	log "quota Codex épuisé ($1), reprise vers $(date -d "@$target" '+%H:%M')"
	wait_s=$((target - now))
	[ "$wait_s" -lt 60 ] && wait_s=60 # garde-fou : heure non parsée ou passée -> jamais de sleep négatif
	sleep "$wait_s"
}

run_one() { # $1 consigne, $2 journal, $3 effort
	tries=0
	while [ $tries -lt 10 ]; do
		if [ -s "$2.last.txt" ] && [ -f "$2" ] && ! grep -q "usage limit" "$2"; then
			return 0
		fi
		log "lancement $1"
		sh art/tools/run_codex.sh "$1" "$2" "$3" > /dev/null 2>&1
		if grep -q "usage limit" "$2" 2>/dev/null; then
			wait_quota "$2"
			tries=$((tries + 1))
			continue
		fi
		log "fin $1 : $(tail -c 300 "$2.last.txt" 2>/dev/null | tr '\n' ' ')"
		return 0
	done
	log "ABANDON $1 après $tries essais"
}

echo "# Rapport de la file de nuit Codex" > "$REPORT"
for g in $(awk '!/^#/ && NF {print $1}' "$QUEUE" | uniq); do
	log "== groupe $g"
	awk -v g="$g" '$1 == g {print $2, $3, $4}' "$QUEUE" > "/tmp/night_g$g.txt"
	todo=0
	while read -r brief journal effort; do
		if ! { [ -s "$journal.last.txt" ] && [ -f "$journal" ] && ! grep -q "usage limit" "$journal"; }; then todo=1; fi
	done < "/tmp/night_g$g.txt"
	if [ $todo -eq 0 ]; then log "groupe $g déjà fini, sauté"; continue; fi
	while read -r brief journal effort; do
		run_one "$brief" "$journal" "$effort" &
		sleep 20 # décale les démarrages (Blender, import)
	done < "/tmp/night_g$g.txt"
	wait
	"$PY" art/tools/texture_budget.py --apply-policy > /dev/null 2>&1 # compression/mipmaps des nouvelles planches
	"$GODOT" --headless --path game --import > /dev/null 2>&1
	log "sprites_test après groupe $g : $("$GODOT" --headless --path game res://tests/sprites_test.tscn 2>&1 | grep -E 'RESULT' | tail -1)"
done
log "FILE TERMINÉE"
