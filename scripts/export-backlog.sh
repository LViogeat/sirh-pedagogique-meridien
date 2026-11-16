#!/usr/bin/env bash
# =============================================================================
# Exporte les backlogs et sprints des 6 groupes dans le dépôt, en Markdown :
#
#   bash scripts/export-backlog.sh
#
# Écrit backlog/<branche>.md (une page par groupe, stories en entier, triées par
# sprint) et backlog/README.md (l'index). Le dépôt étant public, ces fichiers
# se lisent partout : Claude Code en ligne, ChatGPT, un simple navigateur.
#
# Source de vérité : les Issues et les tableaux GitHub Projects. Ces fichiers
# n'en sont qu'une COPIE, à régénérer (puis commiter) quand on veut la mettre à
# jour. Prérequis : gh connecté avec le droit « project » (voir github-setup.sh).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="LViogeat/sirh-pedagogique-meridien"
PROPRIETAIRE="${REPO%%/*}"
SORTIE="backlog"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# branche | libellé | n° du tableau
GROUPES=(
  "recruitment|Recrutement|2"
  "time-and-attendance|Gestion des temps et activités|3"
  "training|Formation|4"
  "career-and-mobility|Mobilité & carrière|5"
  "employee-self-service|Portail RH & Self-Service|6"
  "onboarding-and-offboarding|Onboarding & Offboarding|7"
)

mkdir -p "$SORTIE"
gh api "repos/$REPO/issues/comments" --paginate > "$TMP/commentaires.json"
echo "[]" > "$TMP/index.json"

for g in "${GROUPES[@]}"; do
  IFS='|' read -r branche libelle numero <<<"$g"
  gh issue list -R "$REPO" --label "$branche" --state all --limit 500 \
    --json number,title,state,body,assignees,url,createdAt,closedAt > "$TMP/issues.json"
  gh project item-list "$numero" --owner "$PROPRIETAIRE" --limit 500 --format json > "$TMP/items.json"

  python3 - "$branche" "$libelle" "$numero" "$TMP" "$SORTIE" <<'PY'
import json, sys, datetime
branche, libelle, numero, tmp, sortie = sys.argv[1:6]
lire = lambda f: json.load(open(f"{tmp}/{f}", encoding="utf-8"))
issues, items, coms = lire("issues.json"), lire("items.json")["items"], lire("commentaires.json")

champs = {}  # n° d'issue -> (sprint, statut)
for it in items:
    c = it.get("content") or {}
    if c.get("number"):
        champs[c["number"]] = (it.get("sprint") or "", it.get("status") or "")

par_issue = {}
for c in coms:
    n = int(c["issue_url"].rsplit("/", 1)[1])
    par_issue.setdefault(n, []).append(c)

def cle_sprint(s):
    return (0, int(s.split()[-1])) if s.startswith("Sprint ") and s.split()[-1].isdigit() else (1, 0)

lignes = []
for i in issues:
    sprint, statut = champs.get(i["number"], ("", ""))
    lignes.append((sprint, statut, i))
lignes.sort(key=lambda x: (cle_sprint(x[0]), x[2]["number"]))

out = [f"# {libelle} — backlog et sprints", "",
       f"Copie des Issues et du tableau GitHub Projects n°{numero} "
       f"(https://github.com/users/LViogeat/projects/{numero}), branche `{branche}`.",
       f"Généré le {datetime.date.today().isoformat()} par `scripts/export-backlog.sh` — "
       "la source de vérité reste GitHub.", "",
       f"**{len(issues)} stories**", "", "## Sommaire", ""]
for sprint, statut, i in lignes:
    out.append(f"- #{i['number']} {i['title']} — {sprint or 'sans sprint'} · "
               f"{statut or 'sans statut'}{' · fermée' if i['state'] == 'CLOSED' else ''}")
sprint_courant = object()
for sprint, statut, i in lignes:
    if sprint != sprint_courant:
        sprint_courant = sprint
        out += ["", f"## {sprint or 'Backlog (sans sprint)'}"]
    qui = ", ".join("@" + a["login"] for a in i["assignees"]) or "personne"
    out += ["", f"### #{i['number']} {i['title']}", "",
            f"- Statut : {statut or 'sans statut'} · issue {'fermée' if i['state'] == 'CLOSED' else 'ouverte'}",
            f"- Assignée à : {qui}", f"- Lien : {i['url']}", "",
            (i["body"] or "").strip() or "_(pas de description)_"]
    for c in par_issue.get(i["number"], []):
        out += ["", f"> **Commentaire de @{c['user']['login']}** ({c['created_at'][:10]}) :",
                *["> " + l for l in c["body"].strip().splitlines()]]
open(f"{sortie}/{branche}.md", "w", encoding="utf-8").write("\n".join(out) + "\n")

idx = json.load(open(f"{tmp}/index.json"))
idx.append({"branche": branche, "libelle": libelle, "tableau": numero, "stories": len(issues),
            "sans_sprint": sum(1 for s, _, _ in lignes if not s)})
json.dump(idx, open(f"{tmp}/index.json", "w"))
print(f"  {branche}: {len(issues)} stories")
PY
done

python3 - "$TMP" "$SORTIE" <<'PY'
import json, sys, datetime
tmp, sortie = sys.argv[1:3]
idx = json.load(open(f"{tmp}/index.json"))
out = ["# Backlogs et sprints des groupes", "",
       "Copie en Markdown des Issues et des tableaux GitHub Projects, lisible par n'importe quel outil "
       "(Claude Code en ligne, ChatGPT, navigateur). Source de vérité : GitHub. "
       f"Régénéré le {datetime.date.today().isoformat()} avec `bash scripts/export-backlog.sh`.", "",
       "| Groupe | Stories | Sans sprint | Fichier | Tableau |", "|---|---|---|---|---|"]
for g in idx:
    out.append(f"| {g['libelle']} | {g['stories']} | {g['sans_sprint']} | [{g['branche']}.md]({g['branche']}.md) | "
               f"[n°{g['tableau']}](https://github.com/users/LViogeat/projects/{g['tableau']}) |")
open(f"{sortie}/README.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
PY
echo "Écrit dans $SORTIE/"
