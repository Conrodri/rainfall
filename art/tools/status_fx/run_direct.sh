#!/bin/sh
# Lance Codex avec la consigne $1 en tête (Set-Location d'abord), journal $2.
cd "$(dirname "$0")/../../.." || exit 1
W="$(pwd -W)"
codex exec --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
	-c model_reasoning_effort="medium" -c model_reasoning_summary="none" -c model_verbosity="low" \
	-C "$W" -o "$2.last.txt" \
	"$(cat "$1")

$(cat art/tools/_codex_eco.txt)" < /dev/null > "$2" 2>&1
echo "exit $?"
