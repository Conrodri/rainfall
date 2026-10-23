#!/bin/sh
# Lance un lot Codex économe : run_codex.sh <consigne.txt> <journal.txt> [effort]
# Préambule commun _codex_eco.txt + consigne ; raisonnement bas, pas de résumé de raisonnement ;
# seul le dernier message est gardé à part (<journal>.last.txt) pour la relecture.
cd "$(dirname "$0")/../.." || exit 1
EFFORT="${3:-low}"
codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
	-c model_reasoning_effort="$EFFORT" -c model_reasoning_summary="none" -c model_verbosity="low" \
	-C "$(pwd -W 2>/dev/null || pwd)" -o "$2.last.txt" \
	"$(cat art/tools/_codex_eco.txt)

$(cat "$1")" < /dev/null > "$2" 2>&1
echo "exit $?"
