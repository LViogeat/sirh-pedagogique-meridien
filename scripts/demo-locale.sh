#!/usr/bin/env bash
# =============================================================================
# Monte tout le SIRH en local : base, données, comptes, application.
# Sert à tester une évolution avant de la pousser sur le vrai projet Supabase.
#
#   ./scripts/demo-locale.sh          démarre
#   ./scripts/demo-locale.sh stop     arrête et libère Docker
#
# Prérequis : Docker en marche, Node, psql.
# =============================================================================
set -euo pipefail
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
TRAVAIL=/tmp/sirh-supa
DB="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
PORT=5199

# Clés de développement local de Supabase — publiques et identiques pour tout
# le monde. Elles n'ont rien à voir avec celles de votre vrai projet.
ANON='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
SERVICE='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'

if [ "${1:-}" = "stop" ]; then
  pkill -f "vite --port $PORT" 2>/dev/null || true
  (cd "$TRAVAIL" && npx --yes supabase stop >/dev/null 2>&1) || true
  rm -f "$RACINE/app/.env.local"
  echo "Arrêté."
  exit 0
fi

echo "→ Base de données"
mkdir -p "$TRAVAIL" && cd "$TRAVAIL"
npx --yes supabase init --force >/dev/null 2>&1
npx --yes supabase start >/dev/null 2>&1

echo "→ Schéma, vues, habilitations, données"
for f in 01-schema 02-referentiels 03-vues 04-profils-policies 05-seed 07-module-demo; do
  psql "$DB" -v ON_ERROR_STOP=1 -q -f "$RACINE/db/$f.sql" >/dev/null
done

echo "→ Comptes de démonstration"
for c in "prof@meridien.fr:corehr:Viogeat:Louis" \
         "lea@meridien.fr:rec:Dupont:Léa" \
         "paul@meridien.fr:gta:Nguyen:Paul"; do
  IFS=: read -r mail mod nom prenom <<< "$c"
  curl -s -X POST "http://127.0.0.1:54321/auth/v1/admin/users" \
    -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$mail\",\"password\":\"meridien\",\"email_confirm\":true}" >/dev/null
  psql "$DB" -q -c "insert into profils (user_id, nom, prenom, module)
    select id, '$nom', '$prenom', '$mod' from auth.users where email = '$mail'
    on conflict (user_id) do update set module = excluded.module;"
done

echo "→ Application"
# On écrit un .env.local — que git ignore — plutôt que de modifier config.js,
# qui est un fichier suivi : sinon la configuration locale finirait committée.
cat > "$RACINE/app/.env.local" <<EOF
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=$ANON
EOF
cd "$RACINE/app"
[ -d node_modules ] || npm install --no-audit --no-fund >/dev/null 2>&1
pkill -f "vite --port $PORT" 2>/dev/null || true
nohup npx vite --port $PORT --strictPort > /tmp/vite-sirh.log 2>&1 &
sleep 5

cat <<EOF

  ┌──────────────────────────────────────────────────────────┐
  │  SIRH Meridien  →  http://localhost:$PORT                 │
  ├──────────────────────────────────────────────────────────┤
  │  prof@meridien.fr   mot de passe : meridien   (Core HR)  │
  │  lea@meridien.fr    mot de passe : meridien   (groupe rec)│
  │  paul@meridien.fr   mot de passe : meridien   (groupe gta)│
  ├──────────────────────────────────────────────────────────┤
  │  Console Supabase  →  http://localhost:54323             │
  │  Arrêter           →  ./scripts/demo-locale.sh stop      │
  └──────────────────────────────────────────────────────────┘

EOF
