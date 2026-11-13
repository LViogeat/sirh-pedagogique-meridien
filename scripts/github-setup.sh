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
# Chaque groupe a SON tableau (backlog + sprints), qu'il gère lui-même : ses
# membres y ont le droit d'écriture, et seulement sur le sien.
#
# Le tableau de sprint demande un droit de plus au jeton gh, une seule fois :
#   gh auth refresh -s project
#
# Le script peut être relancé : ce qui existe déjà est laissé tel quel.
# =============================================================================
set -euo pipefail

REPO="LViogeat/sirh-pedagogique-meridien"
PROPRIETAIRE="${REPO%%/*}"
SPRINTS="Sprint 1,Sprint 2,Sprint 3,Sprint 4,Sprint 5,Sprint 6,Sprint 7,Sprint 8,Sprint 9,Sprint 10"

# branche | libellé | couleur de l'étiquette
GROUPES=(
  "recruitment|Recrutement|0E8A16"
  "time-and-attendance|Gestion des temps et activités|1D76DB"
  "training|Formation|5319E7"
  "career-and-mobility|Mobilité & carrière|D93F0B"
  "employee-self-service|Portail RH & Self-Service|006B75"
  "onboarding-and-offboarding|Onboarding & Offboarding|B60205"
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

# ── 5. Un tableau par groupe ─────────────────────────────────────────────────
etape "Tableaux des groupes"
if ! gh project list --owner "$PROPRIETAIRE" --limit 1 >/dev/null 2>&1; then
  echo "  ⚠ Le jeton gh n'a pas le droit « project ». Lancez :"
  echo "      gh auth refresh -h github.com -s project"
  echo "    puis relancez ce script."
  exit 0
fi

LISEZMOI='Le backlog et les sprints du groupe. **C'"'"'est vous qui le tenez.**

- **Backlog** : toutes les stories du groupe. Une story sans sprint attend.
- **Sprint** : au cadrage, le PO choisit les stories du sprint et leur donne
  le champ *Sprint* ; chacune est assignée à celui qui la code.
- **Status** : *Todo* → *In Progress* → *Done*. Une story n'\''est *Done* que
  si ses critères d'\''acceptation ont été vérifiés par un autre membre.

Une story se crée depuis le dépôt : *Issues → New issue*, le formulaire de
votre groupe. Elle arrive toute seule ici.'

A_FAIRE=""
for g in "${GROUPES[@]}"; do
  IFS='|' read -r branche libelle _ <<<"$g"
  titre="$libelle — backlog et sprints"

  numero=$(gh project list --owner "$PROPRIETAIRE" --format json --limit 100 \
    --jq ".projects[] | select(.title == \"$titre\") | .number")
  if [ -z "$numero" ]; then
    numero=$(gh project create --owner "$PROPRIETAIRE" --title "$titre" \
      --format json --jq .number)
    echo "  $titre : tableau n°$numero créé"
  else
    echo "  $titre : tableau n°$numero existe déjà"
  fi

  gh project link "$numero" --owner "$PROPRIETAIRE" --repo "$REPO" >/dev/null 2>&1 || true
  gh project edit "$numero" --owner "$PROPRIETAIRE" --visibility PUBLIC \
    --description "Module $libelle · branche $branche" --readme "$LISEZMOI" >/dev/null

  if ! gh project field-list "$numero" --owner "$PROPRIETAIRE" --format json \
       --jq '.fields[].name' | grep -qx "Sprint"; then
    gh project field-create "$numero" --owner "$PROPRIETAIRE" --name "Sprint" \
      --data-type SINGLE_SELECT --single-select-options "$SPRINTS" >/dev/null
    echo "    champ « Sprint » créé"
  fi

  # Deux vues : « Backlog » (table, tout) et « Sprint en cours » (colonnes).
  id_projet=$(gh project view "$numero" --owner "$PROPRIETAIRE" --format json --jq .id)
  vues=$(gh api graphql -f query='query($p: ID!) { node(id: $p) { ... on ProjectV2 {
           views(first: 20) { nodes { id name } } } } }' -f p="$id_projet" \
         --jq '.data.node.views.nodes[] | "\(.id)|\(.name)"')
  if ! grep -q '|Backlog$' <<<"$vues"; then
    premiere=$(head -1 <<<"$vues" | cut -d'|' -f1)
    gh api graphql -f query='mutation($v: ID!) { updateProjectV2View(input: {
        viewId: $v, name: "Backlog", layout: TABLE_LAYOUT }) { clientMutationId } }' \
      -f v="$premiere" >/dev/null
    echo "    vue « Backlog » prête"
  fi
  if ! grep -q '|Sprint en cours$' <<<"$vues"; then
    gh api graphql -f query='mutation($p: ID!) { createProjectV2View(input: {
        projectId: $p, name: "Sprint en cours", layout: BOARD_LAYOUT }) {
        projectV2View { id } } }' -f p="$id_projet" \
      --jq .data.createProjectV2View.projectV2View.id \
      | xargs -I{} gh api graphql -f query='mutation($v: ID!) { updateProjectV2View(input: {
          viewId: $v, filter: "sprint:\"Sprint 1\"" }) { clientMutationId } }' -f v={} >/dev/null
    echo "    vue « Sprint en cours » créée, filtrée sur Sprint 1"
  fi

  # Les membres du groupe, d'après le CSV : droit d'écriture sur CE tableau.
  if [ -n "${1:-}" ]; then
    while IFS=, read -r login b; do
      login=$(echo "$login" | tr -d '[:space:]'); b=$(echo "$b" | tr -d '[:space:]')
      [ "$b" = "$branche" ] && [ -n "$login" ] || continue
      id_user=$(gh api "users/$login" --jq .node_id 2>/dev/null) \
        || { echo "    ⚠ $login : identifiant introuvable"; continue; }
      gh api graphql -f query='
        mutation($p: ID!, $u: ID!) {
          updateProjectV2Collaborators(input: {
            projectId: $p, collaborators: [{ userId: $u, role: WRITER }]
          }) { clientMutationId }
        }' -f p="$id_projet" -f u="$id_user" >/dev/null \
        && echo "    $login peut écrire dans ce tableau" \
        || echo "    ⚠ $login : accès au tableau refusé"
    done < "$1"
  fi

  A_FAIRE="$A_FAIRE
  $titre — https://github.com/users/$PROPRIETAIRE/projects/$numero
    1. Workflows → « Auto-add to project » : activer, filtre
         is:issue label:$branche
    2. Vue « Backlog » : Group by → Sprint, puis Save.
"
done

cat <<FIN

  Reste à faire à la main, une fois par tableau (l'API GitHub ne le permet pas) :
$A_FAIRE
FIN
