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
DEPOT="https://stackblitz.com/github/LViogeat/sirh-pedagogique-meridien/tree/main/app"

[ -r "$ENV_FILE" ] || { echo "Fichier introuvable : $ENV_FILE" >&2; exit 1; }

GROUPES=$(grep '^GROUPES=' "$ENV_FILE" | cut -d= -f2-)
API=$(grep '^API_PUBLIQUE=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || true)
API=${API:-https://sirh-api.govetia.com}

# « code:Libellé:jeton[:type_besoin] », séparés par des virgules.
echo "$GROUPES" | tr ',' '\n' | while IFS=: read -r code libelle jeton besoin; do
  [ -n "$code" ] || continue
  cat <<FICHE

────────────────────────────────────────────────────────────────────────
  MODULE $(echo "$libelle" | tr '[:lower:]' '[:upper:]')
────────────────────────────────────────────────────────────────────────

  1. Ouvrez le projet, et faites-en votre fork :
     $DEPOT

  2. Créez un fichier « .env » à la racine, avec ces deux lignes :

     VITE_API_TOKEN=$jeton
     VITE_MODULE_CODE=$code

  3. Dans le terminal :  npm install  puis  npm run dev

  Votre schéma de base de données : $code
  Besoins que vous prenez en charge : ${besoin:-aucun}
  Documentation de l'API : $API/docs

FICHE
done

echo "────────────────────────────────────────────────────────────────────────"
echo "  Jeton intervenant (à NE PAS distribuer) : $(grep '^JETON_ADMIN=' "$ENV_FILE" | cut -d= -f2-)"
echo "────────────────────────────────────────────────────────────────────────"
