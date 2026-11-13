#!/usr/bin/env bash
# =============================================================================
# Fabrique le kit Copilot de chaque groupe : app/copilot/<groupe>.md
#
# Copilot ne voit pas le projet. Ce fichier lui donne d'un coup tout ce qu'il
# doit savoir : les règles, le SDK, le contrat de données et un écran modèle.
# Les étudiants le COLLENT en entier dans le message, puis leur user story
# en dessous. Testé le 13/11/2026 : en pièce jointe, Copilot Chat le traite
# comme une source documentaire et ignore les consignes.
#
# Le kit est ASSEMBLÉ à partir du code : relancez ce script dès que le SDK,
# le contrat ou l'écran modèle changent, et commitez le résultat.
#
#   bash scripts/kit-copilot.sh
# =============================================================================
set -euo pipefail

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
APP="$RACINE/app"
SORTIE="$APP/copilot"
mkdir -p "$SORTIE"

# nom de branche | code module | libellé | type de besoin | ce que le module consomme
GROUPES=(
  "recruitment|rec|Recrutement|recrutement|les besoins de recrutement, les postes (effectif cible et réel), les contrats et leurs échéances"
  "time-and-attendance|gta|Gestion des temps et activités||les salariés et leur temps de travail (work_time_ratio), les contrats actifs, les établissements et les départements"
  "training|form|Formation|formation|les besoins de formation (un salarié + une compétence), le référentiel de compétences, les entretiens et leurs écarts de niveau, les salariés"
  "career-and-mobility|mob|Mobilité & carrière|mobilite|les besoins de mobilité, les souhaits d'évolution exprimés en entretien (aspirations), les postes et leur niveau hiérarchique, le parcours contractuel des salariés"
  "employee-self-service|portail|Portail RH & Self-Service||la fiche salarié, la hiérarchie managériale (manager_id, manager_name, direct_reports_count) qui sert de circuit de validation, les référentiels"
  "onboarding-and-offboarding|onb|Onboarding & Offboarding||les arrivées (joined_on, contrats à venir) et les départs (left_on), les postes et leurs compétences attendues, les départements"
)

bloc() {  # bloc <langage> <fichier>
  printf '```%s\n' "$1"
  cat "$2"
  printf '\n```\n'
}

for ligne in "${GROUPES[@]}"; do
  IFS='|' read -r branche code libelle besoin consomme <<<"$ligne"
  fichier="$SORTIE/$branche.md"

  if [ -n "$besoin" ]; then
    regle_besoins="- Le module traite les besoins identifiés de type « $besoin », et seulement ceux-là : \`getBesoins({ typeBesoin: '$besoin' })\`, puis \`prendreEnChargeBesoin(id)\` et \`cloturerBesoin(id)\`."
  else
    regle_besoins="- Le module ne traite AUCUN besoin identifié : n'appelle jamais \`prendreEnChargeBesoin\`, \`cloturerBesoin\` ni \`relacherBesoin\`."
  fi

  {
    cat <<EOF
# Kit Copilot — Module $libelle

> **Mode d'emploi.** Ouvrez une conversation neuve. Copiez **tout** ce
> fichier (Cmd+A, Cmd+C) et **collez-le** dans le message — ne le joignez pas
> avec le trombone, Copilot ignorerait les consignes. Sous le kit, dans le
> **même message**, collez votre user story telle qu'elle est écrite dans
> GitHub, **et votre \`module.js\` actuel**. Envoyez. Une conversation par
> story : pour la story suivante, on recommence.

---

## Instructions pour l'assistant

Tu es le développeur d'un groupe d'étudiants en RH qui ne savent pas coder. Ils
te donnent une user story, tu leur rends du code qu'ils collent tel quel dans
leur projet. Ils ne liront pas ton code : il doit marcher du premier coup.

### Le projet

- Application **Vue 3** (\`<script setup>\`, Composition API) avec **PrimeVue 4**,
  thème Aura, icônes PrimeIcons (\`pi pi-…\`).
- Les composants PrimeVue (DataTable, Column, Button, Dialog, InputText,
  Select, DatePicker, Tag, Card…) sont **importés automatiquement** : ne les
  importe jamais.
- Deux composants du projet sont disponibles partout, sans import :
  \`<PageHeader titre="…" sous-titre="…" />\` en haut de chaque écran, et
  \`<StatCard titre="…" :valeur="…" icone="pi pi-…" precision="…" />\`.
- Toutes les données passent par le SDK : \`import { … } from '@/socle/sdk'\`.
  **Aucun \`fetch\`, aucun \`axios\`, aucune URL d'API dans le code.** Une
  fonction qui n'est pas dans le SDK ci-dessous n'existe pas.
- Aucune nouvelle dépendance npm.

### Le module de ce groupe

- Module **$libelle**, code \`$code\`.
- Tous ses fichiers vivent dans \`app/src/modules/$code/\`, et nulle part ailleurs.
- Il consomme : $consomme.
$regle_besoins
- Le socle RH est en **lecture seule**. Les seules écritures possibles se font
  dans les tables du groupe, avec \`insert\`, \`update\`, \`remove\` ou \`sql\`.
- Les tables du groupe sont dans le schéma PostgreSQL \`$code\` : on les nomme
  sans préfixe (\`offres\`, pas \`$code.offres\`). Le socle se lit en SQL avec le
  préfixe \`public.\` (\`public.employees\`).
- En SQL, **jamais de valeur concaténée** : toujours des paramètres \`:nom\`.
- Une référence au socle dans une table du groupe est une simple colonne
  \`integer\` (\`employee_id\`, \`position_id\`), sans clé étrangère.

### Le manifeste du module

Le fichier \`app/src/modules/$code/module.js\` déclare les écrans. Sa forme est
imposée :

\`\`\`js
export default {
  code: '$code',
  routes: [
    { path: 'mon-ecran', label: 'Mon écran',
      component: () => import('./MonEcran.vue') },
  ],
}
\`\`\`

Un écran de détail qui ne doit pas apparaître dans le menu prend
\`masque: true\` et un paramètre : \`{ path: 'offres/:id', label: 'Offre', masque: true, component: … }\`.

### Comment tu réponds

1. **Un fichier complet par bloc de code**, jamais un extrait à insérer.
   Au-dessus de chaque bloc, une seule ligne : le chemin du fichier
   (\`app/src/modules/$code/MonEcran.vue\`).
2. Si la story crée un écran, rends **d'abord le fichier \`.vue\`**, **puis le
   \`module.js\` complet** mis à jour, à partir de celui que l'étudiant t'a
   collé. Dans cet ordre : l'étudiant les colle dans l'ordre où tu les donnes.
3. Si la story demande des tables qui n'existent pas encore, rends d'abord le
   SQL (\`create table if not exists\`, une colonne \`id serial primary key\`),
   à exécuter dans la Console SQL de l'application.
4. Les textes de l'écran sont **en français**. Les dates passent par
   \`formatDate\`, les nombres par \`formatNombre\`.
5. Chaque appel au SDK est dans un \`try / catch\` qui affiche
   \`toast.erreur(erreur.message)\`. Chaque liste montre un état de chargement
   et un message quand elle est vide.
6. Pas d'explication, pas de résumé. Si la story est ambiguë ou demande
   quelque chose que le SDK ne permet pas, **ne code rien** : pose une seule
   question, courte.

---

## Le SDK — tout ce qu'un écran a le droit d'appeler

EOF
    bloc js "$APP/src/socle/sdk.js"
    echo
    echo "### Lire le socle"
    echo
    bloc js "$APP/src/socle/corehr.js"
    cat <<'EOF'

### Les tables du groupe

```js
sql(requete, params)            // exécute une requête, renvoie les lignes
sqlComplet(requete, params)     // idem, avec { columns, rows, row_count }
sqlScript(script)               // plusieurs instructions d'un coup
insert(table, objet)            // insère, renvoie la ligne créée (id compris)
update(table, id, objet)        // modifie la ligne d'identifiant id, la renvoie
remove(table, id)               // supprime
useQuery(requete, params)       // réactif : .rows .loading .error .refresh()

// Exemples
const offres = await sql('select * from offres where statut = :s', { s: 'ouverte' })
const offre  = await insert('offres', { titre: 'Réceptionniste', position_id: 12 })

// Paramètres qui changent : passer une FONCTION, puis rafraîchir
const liste = useQuery('select * from offres where statut = :s', () => ({ s: statut.value }))
watch(statut, liste.refresh)
```

### Mise en forme et messages

```js
formatDate(valeur, 'court' | 'long')   // '12/03/2026' · '12 mars 2026'
formatNombre(valeur, decimales = 0)
formatPourcent(valeur, decimales = 1)
anciennete(mois)                        // '3 ans et 2 mois'
toast.succes(message) · toast.erreur(message) · toast.info(message) · toast.alerte(message)
```

---

## Le contrat de données — ce que renvoie chaque fonction

EOF
    sed '1,/^## Endpoints/{/^## Endpoints/!d;}' "$APP/contrat-api.md"
    cat <<'EOF'

---

## Un écran du projet, à prendre pour modèle

Liste filtrable, détail dans une boîte de dialogue. Reprends sa structure et
son style.

EOF
    bloc vue "$APP/src/corehr/PostesList.vue"
  } > "$fichier"

  echo "$fichier — $(wc -c < "$fichier" | tr -d ' ') caractères"
done
