#!/usr/bin/env bash
# =============================================================================
# À lancer la veille d'une session, SUR LE SERVEUR, depuis votre poste :
#
#   ssh sweet-waters-prod 'bash -s' -- 2026-11-16 rec < scripts/preparer-session.sh
#
#   1er argument  : la date de référence (le premier jour du cours)
#   suivants      : les codes de groupe dont le jeton doit changer (facultatif)
#
# Ce que fait le script :
#   1. sauvegarde /opt/sirh/.env
#   2. y cale DATE_REFERENCE
#   3. engendre un nouveau jeton pour chaque groupe demandé
#   4. redémarre l'API et remet les données du socle à zéro
#   5. affiche la date prise en compte et les besoins ouverts par type
#
# Les schémas des groupes ne sont pas touchés. Les nouveaux jetons se relisent
# ensuite avec scripts/fiches-groupes.sh.
# =============================================================================
set -euo pipefail

DATE_REF="${1:?Donnez la date de référence, par exemple 2026-11-16}"
shift
[[ "$DATE_REF" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "Date invalide : $DATE_REF" >&2; exit 1; }

cd /opt/sirh
cp -p .env ".env.bak-$(date +%Y%m%d-%H%M%S)"

# ── Date de référence ────────────────────────────────────────────────────────
sed -i "s/^DATE_REFERENCE=.*/DATE_REFERENCE=$DATE_REF/" .env
echo "DATE_REFERENCE=$DATE_REF"

# ── Jetons ───────────────────────────────────────────────────────────────────
# GROUPES=code:Libellé:jeton[:type_besoin],code:…
for code in "$@"; do
  nouveau=$(openssl rand -hex 12)
  ligne=$(grep '^GROUPES=' .env | cut -d= -f2-)
  remplacee=$(echo "$ligne" | tr ',' '\n' | awk -F: -v OFS=: -v c="$code" -v j="$nouveau" \
    '$1 == c { $3 = j; trouve = 1 } { print } END { exit !trouve }' | paste -sd, -) \
    || { echo "Groupe inconnu : $code" >&2; exit 1; }
  # Le jeton est hexadécimal : aucun caractère à échapper pour sed.
  sed -i "s|^GROUPES=.*|GROUPES=$remplacee|" .env
  echo "Jeton du groupe $code : changé"
done

# ── Redémarrage, puis remise à zéro du socle ─────────────────────────────────
docker compose -f docker-compose.prod.yml up -d

API=$(grep '^API_PUBLIQUE=' .env | cut -d= -f2- || true)
API=${API:-https://sirh-api.govetia.com}
ADMIN=$(grep '^JETON_ADMIN=' .env | cut -d= -f2-)

for _ in $(seq 30); do
  curl -sf "$API/" >/dev/null && break
  sleep 2
done

curl -sf -X POST "$API/admin/reset" -H "Authorization: Bearer $ADMIN" >/dev/null
echo "Socle remis à zéro"

echo
curl -s "$API/" ; echo
curl -s "$API/admin/etat" -H "Authorization: Bearer $ADMIN" | head -c 2000; echo
