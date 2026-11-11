#!/bin/sh
# Lance Codex dans CE worktree (lot G12 : audio des étages 4-5).
cd "$(dirname "$0")/../../.." || exit 1
W="$(pwd -W)"
codex exec -p eco-mini --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
	-c model_reasoning_effort="medium" -c model_reasoning_summary="none" -c model_verbosity="low" \
	-C "$W" -o "art/tools/audio/_logg12.txt.last.txt" \
	"Travaille uniquement dans $W (Set-Location d'abord). Lis art/briefs/audio_cryptes_source.md et exécute-le.

$(cat art/tools/_codex_eco.txt)" < /dev/null > art/tools/audio/_logg12.txt 2>&1
echo "exit $?"
