#!/bin/sh
# Lance un lot Codex économe : run_codex.sh <consigne.txt> <journal.txt> [effort] [profil]
# Préambule commun _codex_eco.txt + consigne ; raisonnement bas, pas de résumé de raisonnement ;
# seul le dernier message est gardé à part (<journal>.last.txt) pour la relecture.
# Profil optionnel (fichiers ~/.codex/<profil>.config.toml, couche sur config.toml) :
#   eco      = sans serveur MCP Blender (audio, assemblages, scripts seuls ; Blender reste lançable en --background)
#   mini     = modèle léger gpt-6-luna (lots mécaniques)
#   eco-mini = les deux
# Défaut (sans 4e argument) : inchangé, MCP Blender + modèle par défaut.
cd "$(dirname "$0")/../.." || exit 1
EFFORT="${3:-low}"
PROFILE="-p ${CODEX_PROFILE:-eco-mini}" # défaut eco-mini (joueur, 29/10/2026) ; "full" = config de base
[ -n "$4" ] && PROFILE="-p $4"
[ "$4" = "full" ] && PROFILE=""
codex exec $PROFILE --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check \
	-c model_reasoning_effort="$EFFORT" -c model_reasoning_summary="none" -c model_verbosity="low" \
	-C "$(pwd -W 2>/dev/null || pwd)" -o "$2.last.txt" \
	"$(cat art/tools/_codex_eco.txt)

$(cat "$1")" < /dev/null > "$2" 2>&1
echo "exit $?"
