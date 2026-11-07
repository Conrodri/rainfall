#!/bin/sh
# Lance les tests UX : run_tests.sh <test...> ; une ligne RESULT par test, journaux dans art/tools/ux/_t_<test>.txt
cd "$(dirname "$0")/../../.." || exit 1
for t in "$@"; do
	sh art/tools/vfx_test/godot_locked.sh --headless "res://tests/$t.tscn" > "art/tools/ux/_t_$t.txt" 2>&1
	echo "$t: $(grep -a 'RESULT' "art/tools/ux/_t_$t.txt" | tail -1) $(grep -a -c 'SCRIPT ERROR\|ERROR:' "art/tools/ux/_t_$t.txt") err"
done
