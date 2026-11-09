#!/usr/bin/env bash
# =============================================================================
# Prépare le dépôt GitHub pour une session : étiquettes, branches des groupes,
# protections, collaborateurs et tableau de sprint.
#
#   bash scripts/github-setup.sh                      # tout sauf les invitations
#   bash scripts/github-setup.sh comptes-github.csv   # + invite les étudiants
#
# Le CSV (jamais versionné, voir .gitignore) a une ligne par étudiant :
#   identifiant-github,branche
#   lea-meyer,recruitment
#   tom-dupont,time-and-attendance
#
# Le tableau de sprint demande un droit de plus au jeton gh, une seule fois :
#   gh auth refresh -s project
#
# Le script peut être relancé : ce qui existe déjà est laissé tel quel.
# =============================================================================
set -euo pipefail

REPO="LViogeat/sirh-pedagogique-meridien"
PROPRIETAIRE="${REPO%%/*}"
PROJET="Sorbonne-Hôtel — sprints"
SPRINTS="Sprint 1,Sprint 2,Sprint 3,Sprint 4,Sprint 5,Sprint 6,Sprint 7,Sprint 8,Sprint 9,Sprint 10"

# branche | libellé | couleur de l'étiquette
GROUPES=(
  "recruitment|Recrutement|0E8A16"
  "time-and-attendance|Gestion des temps et activités|1D76DB"
)

etape() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }

# ── 1. Étiquettes ────────────────────────────────────────────────────────────
etape "Étiquettes"
gh label create user-story --repo "$REPO" --color FBCA04 --force \
  --description "Une fonctionnalité, un écran"
gh label create retro --repo "$REPO" --color C5DEF5 --force \
  --description "Rétro de fin de sprint"
for g in "${GROUPES[@]}"; do
  IFS='|' read -r branche libelle couleur <<<"$g"
  gh label create "$branche" --repo "$REPO" --color "$couleur" --force \
    --description "Module $libelle"
done

# ── 2. Branches des groupes, partant de main ────────────────────────────────
etape "Branches"
SHA_MAIN=$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha)
for g in "${GROUPES[@]}"; do
  IFS='|' read -r branche _ _ <<<"$g"
  if gh api "repos/$REPO/git/ref/heads/$branche" >/dev/null 2>&1; then
    echo "  $branche existe déjà"
  else
    gh api "repos/$REPO/git/refs" -f ref="refs/heads/$branche" -f sha="$SHA_MAIN" >/dev/null
    echo "  $branche créée depuis main"
  fi
done

# ── 3. Protections ───────────────────────────────────────────────────────────
# main : personne n'y écrit, sauf l'administrateur du dépôt (vous). C'est vous
# qui fusionnez les branches des groupes avant une démo.
# Branches des groupes : on y pousse librement, mais on ne peut ni les
# supprimer ni réécrire leur historique — c'est ce qui garde la trace de qui a
# fait quoi.
etape "Protections"
regle() {  # regle <nom> <json des refs> <json des règles>
  local nom="$1" refs="$2" regles="$3" id
  id=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$nom\") | .id")
  local corps
  corps=$(cat <<JSON
{
  "name": "$nom",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": $refs, "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": $regles
}
JSON
)
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$REPO/rulesets/$id" --input - <<<"$corps" >/dev/null
    echo "  « $nom » mise à jour"
  else
    gh api -X POST "repos/$REPO/rulesets" --input - <<<"$corps" >/dev/null
    echo "  « $nom » créée"
  fi
}

regle "main réservée à l'intervenant" '["refs/heads/main"]' \
  '[{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]'

refs_groupes=$(for g in "${GROUPES[@]}"; do IFS='|' read -r b _ _ <<<"$g"; printf '"refs/heads/%s",' "$b"; done)
regle "branches des groupes" "[${refs_groupes%,}]" \
  '[{"type":"deletion"},{"type":"non_fast_forward"}]'

# ── 4. Collaborateurs ────────────────────────────────────────────────────────
if [ -n "${1:-}" ]; then
  etape "Invitations"
  [ -r "$1" ] || { echo "Fichier introuvable : $1" >&2; exit 1; }
  while IFS=, read -r login branche; do
    login=$(echo "$login" | tr -d '[:space:]')
    [ -n "$login" ] && [ "$login" != "identifiant-github" ] || continue
    gh api -X PUT "repos/$REPO/collaborators/$login" -f permission=push >/dev/null \
      && echo "  $login invité ($branche)" \
      || echo "  ⚠ $login : identifiant introuvable"
  done < "$1"
  echo "  Chaque étudiant doit ACCEPTER l'invitation, reçue par mail ou sur"
  echo "  https://github.com/$REPO/invitations"
fi

# ── 5. Tableau de sprint ─────────────────────────────────────────────────────
etape "Tableau de sprint"
if ! gh project list --owner "$PROPRIETAIRE" --limit 1 >/dev/null 2>&1; then
  echo "  ⚠ Le jeton gh n'a pas le droit « project ». Lancez :"
  echo "      gh auth refresh -s project"
  echo "    puis relancez ce script."
  exit 0
fi

NUMERO=$(gh project list --owner "$PROPRIETAIRE" --format json \
  --jq ".projects[] | select(.title == \"$PROJET\") | .number")
if [ -z "$NUMERO" ]; then
  NUMERO=$(gh project create --owner "$PROPRIETAIRE" --title "$PROJET" \
    --format json --jq .number)
  echo "  projet n°$NUMERO créé"
else
  echo "  projet n°$NUMERO existe déjà"
fi
gh project link "$NUMERO" --owner "$PROPRIETAIRE" --repo "$REPO" >/dev/null 2>&1 || true
gh project edit "$NUMERO" --owner "$PROPRIETAIRE" --visibility PUBLIC >/dev/null

if ! gh project field-list "$NUMERO" --owner "$PROPRIETAIRE" --format json \
     --jq '.fields[].name' | grep -qx "Sprint"; then
  gh project field-create "$NUMERO" --owner "$PROPRIETAIRE" --name "Sprint" \
    --data-type SINGLE_SELECT --single-select-options "$SPRINTS" >/dev/null
  echo "  champ « Sprint » créé"
fi

URL_PROJET="https://github.com/users/$PROPRIETAIRE/projects/$NUMERO"
cat <<FIN

  Reste à faire à la main, une seule fois (l'API GitHub ne le permet pas) :
    $URL_PROJET

  1. Workflows → « Auto-add to project » : activer, filtre
       is:issue,open repo:$REPO
     Chaque ticket ouvert arrive tout seul dans le tableau.
  2. Une vue par groupe : dupliquer la vue Board, la renommer, et filtrer
       label:recruitment            → « Recrutement »
       label:time-and-attendance    → « Temps et activités »
  3. Dans chaque vue : Group by → Sprint.

FIN
