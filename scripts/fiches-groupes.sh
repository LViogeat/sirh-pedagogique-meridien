#!/usr/bin/env bash
#
# Imprime les six fiches à remettre aux groupes, jetons compris.
#
# À lancer SUR LE SERVEUR, où vivent les jetons :
#   ssh <serveur> 'bash -s' < scripts/fiches-groupes.sh
#   ou, depuis /opt/sirh : bash scripts/fiches-groupes.sh
#
# Les jetons ne sont écrits nulle part dans le dépôt : ce script les lit dans
# /opt/sirh/.env, qui n'est pas versionné.

set -euo pipefail

ENV_FILE="${1:-/opt/sirh/.env}"
DEPOT="LViogeat/sirh-pedagogique-meridien"

# Le code du module → la branche du groupe. Un groupe sans branche n'a pas de
# fiche : créez sa branche dans scripts/github-setup.sh, puis ajoutez-le ici.
branche_de() {
  case "$1" in
    rec) echo recruitment ;;
    gta) echo time-and-attendance ;;
    form) echo training ;;
    mob) echo career-and-mobility ;;
    portail) echo employee-self-service ;;
    onb) echo onboarding-and-offboarding ;;
    *)   echo "" ;;
  esac
}

[ -r "$ENV_FILE" ] || { echo "Fichier introuvable : $ENV_FILE" >&2; exit 1; }

GROUPES=$(grep '^GROUPES=' "$ENV_FILE" | cut -d= -f2-)
API=$(grep '^API_PUBLIQUE=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
API=${API:-https://sirh-api.govetia.com}

# « code:Libellé:jeton[:type_besoin] », séparés par des virgules.
echo "$GROUPES" | tr ',' '\n' | while IFS=: read -r code libelle jeton besoin; do
  [ -n "$code" ] || continue
  branche=$(branche_de "$code")
  [ -n "$branche" ] || continue
  cat <<FICHE

────────────────────────────────────────────────────────────────────────
  MODULE $(echo "$libelle" | tr '[:lower:]' '[:upper:]')
────────────────────────────────────────────────────────────────────────

  1. Chacun crée son compte GitHub, donne son identifiant à l'intervenant,
     puis accepte l'invitation reçue par mail.

  2. Ouvrez StackBlitz, connectez-vous avec GitHub, puis ouvrez VOTRE branche :
     https://stackblitz.com/~/github.com/$DEPOT/tree/$branche
     En haut à gauche : bouton « Commit ». Si vous voyez « Fork », stop.

  3. Créez un fichier « .env » À LA RACINE du projet (à côté de
     README.md, PAS dans app/), avec ces deux lignes :

     VITE_API_TOKEN=$jeton
     VITE_MODULE_CODE=$code

  4. Si l'aperçu ne redémarre pas : terminal, Ctrl+C, puis  npm run dev

  5. Pour coder une story avec Copilot : ouvrez app/copilot/$branche.md,
     copiez TOUT, collez-le dans Copilot (pas de trombone), puis collez la
     story et votre module.js dessous, dans le même message. Collez le
     .vue rendu AVANT le module.js.

  Votre branche : $branche
  Créer une story : https://github.com/$DEPOT/issues/new?template=story-$branche.yml
  Vos tickets : https://github.com/$DEPOT/issues?q=label%3A$branche

  Votre schéma de base de données : $code
  Besoins que vous prenez en charge : ${besoin:-aucun}
  Documentation de l'API : $API/docs

FICHE
done

echo "────────────────────────────────────────────────────────────────────────"
echo "  Jeton intervenant (à NE PAS distribuer) : $(grep '^JETON_ADMIN=' "$ENV_FILE" | cut -d= -f2-)"
echo "────────────────────────────────────────────────────────────────────────"
