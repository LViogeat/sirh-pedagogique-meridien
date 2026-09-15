# Socle SIRH — Sorbonne-Hôtel

Support de cours de méthodologies agiles, Master 2 SIRH,
Université Paris 1 Panthéon-Sorbonne.

Trois jours, cinq sprints, dix-neuf étudiants non-développeurs répartis en six
groupes. Chaque groupe développe un module RH qui se branche sur ce socle.

| | |
|---|---|
| **Domaine** | Sorbonne-Hôtel, chaîne hôtelière fictive · 5 hôtels · 150 salariés |
| **Socle** | Core HR + Évaluation / gestion des talents |
| **Pivot** | les **besoins identifiés** — recrutement, formation, mobilité |
| **API** | FastAPI + PostgreSQL, spécification OpenAPI complète |
| **Front** | Vue 3 + PrimeVue, six écrans de référence |
| **Déploiement** | API sur un VPS · postes étudiants dans StackBlitz |

---

## Deux environnements, à ne pas confondre

**Votre poste**, pour faire évoluer le socle et tester avant de déployer :

```bash
docker compose up -d --build     # base + API, données chargées au premier démarrage
cd app && npm install && npm run dev
```

- API et documentation interactive : <http://localhost:8000/docs>
- Application : <http://localhost:5173>

Le premier démarrage crée les tables, prépare les six schémas de groupe et
charge le jeu de démonstration. Il n'y a aucune commande à lancer ensuite.

Ajoutez `app/.env` avec `VITE_API_URL=http://localhost:8000` pour que le front
local tape votre API locale plutôt que celle du serveur.

**Le poste d'un groupe** : pas de Docker, pas de base de données, rien à
installer. StackBlitz exécute Vite dans le navigateur et le dépôt s'y ouvre
directement sur le dossier de l'application :

```
https://stackblitz.com/github/LViogeat/sirh-pedagogique-meridien/tree/main/app
```

Chaque groupe fait son fork, puis crée un fichier `.env` à partir de
`.env.example`, avec deux lignes — son jeton et le code de son module :

```
VITE_API_TOKEN=667c885ab05157e879711b66
VITE_MODULE_CODE=rec
```

Puis `npm install && npm run dev`. L'URL de l'API est déjà compilée dans
l'application. Tant que ce fichier manque, un écran dit exactement quoi créer,
au lieu d'une erreur réseau.

> Les commandes `docker` ci-dessus sont les vôtres, pas les leurs. StackBlitz
> n'a ni Docker ni noyau Linux, et les groupes n'en ont pas besoin : l'API est
> déployée, ils ne lancent que l'interface.

---

## Les commandes du cours

```bash
# Remettre les données du socle à zéro, entre deux sprints
docker compose exec api python -m socle.reset

# Ou, sans accès au serveur, avec le jeton intervenant
curl -X POST https://sirh-api.exemple.fr/admin/reset \
     -H "Authorization: Bearer $JETON_ADMIN"

# Rejouer les règles après avoir ajusté un seuil
curl -X POST https://sirh-api.exemple.fr/admin/besoins/generer \
     -H "Authorization: Bearer $JETON_ADMIN"

# Repartir propre sur le schéma d'un groupe qui s'est mis en difficulté
curl -X POST https://sirh-api.exemple.fr/admin/modules/rec/reset \
     -H "Authorization: Bearer $JETON_ADMIN"

# Régénérer les livrables de documentation après une modification de l'API
docker compose exec -T api python -m socle.export_openapi > openapi.json
docker compose exec -T api python -m socle.export_contrat > contrat-api.md
```

**La remise à zéro du socle ne touche pas les schémas des groupes.** Le travail
des étudiants survit à toutes les remises à zéro, et les identifiants du socle
sont stables — les références qu'ils stockent restent valables.

---

## Documentation

| | |
|---|---|
| [`README-ETUDIANTS.md`](README-ETUDIANTS.md) | **Le guide des groupes** : modèle, endpoints, SDK, kit de prompts |
| [`contrat-api.md`](contrat-api.md) | Le contrat d'API compact — celui qu'on colle dans Copilot |
| [`openapi.json`](openapi.json) | La spécification complète, en un fichier |
| [`docs/01-architecture.md`](docs/01-architecture.md) | Les décisions et leurs raisons |
| [`docs/02-deploiement.md`](docs/02-deploiement.md) | Le serveur, les jetons, le DNS, les postes étudiants |

---

## Le dispositif en une page

**Un socle, six modules, une seule base.**

L'intervenant tient le socle : Core HR, Évaluation, et la commande qui en
déduit les **besoins identifiés**. Ces besoins sont ce que trois groupes
consomment directement, et ce qui rend visible, lors des démonstrations, la
chaîne complète entre un entretien annuel et l'action RH.

**Le socle est figé au jour 1.** Aucune demande d'évolution n'est nécessaire,
parce que chaque groupe est propriétaire de son propre schéma PostgreSQL : il y
crée ses tables lui-même, sans passer par l'intervenant.

**PostgreSQL arbitre les droits, pas le code.** Un groupe est propriétaire de
son schéma, lit le socle et les schémas des cinq autres, et ne peut rien écrire
ailleurs. Une requête qui tenterait de modifier le socle est refusée par la
base. Rien à contourner, rien à surveiller.

**Le socle RH est en consultation stricte.** Ses écrans n'ont aucun bouton
d'action. La seule écriture ouverte aux groupes est le statut d'un besoin
identifié, et elle se fait depuis leurs propres écrans — chaque module ne
traitant que son type de besoin : Recrutement le recrutement, Formation la
formation, Mobilité la mobilité, les trois autres aucun.

**Un groupe, un module, un menu.** Le menu montre le SIRH entier, mais un seul
module est ouvrable : celui du groupe. Les cinq autres sont grisés, et le
routeur refuse d'y aller. Un module tient dans `app/src/modules/<code>/`, et la
fusion des six consiste à copier six dossiers.

**Deux pages d'accueil, et rien d'autre.** Celle du logiciel présente
l'entreprise et la chaîne évaluation → besoin → action. Celle d'un module dit
où en est le groupe : ses écrans, ses tables. C'est la seule page de son module
que le socle lui donne — aucune table n'est pré-créée, aucun écran n'est
pré-nommé. Ce que le module doit contenir est précisément ce que le groupe a à
concevoir, en partant de ce qu'il aura compris en parcourant le socle.

**Les données sont déterministes.** Remises à zéro deux fois, elles produisent
exactement les mêmes lignes, avec les mêmes identifiants. C'est une exigence de
la recette : un groupe doit pouvoir écrire « alors l'écran affiche 12 besoins
de formation » avant d'avoir codé l'écran.

---

## Le jeu de données

150 salariés présents · 12 anciens salariés · 5 hôtels · 37 départements ·
112 postes pour un effectif cible de 160 · 30 compétences · 170 contrats ·
119 entretiens annuels · 269 objectifs · 445 évaluations de compétences ·
38 souhaits d'évolution · **178 besoins identifiés**
(126 formation, 27 recrutement, 25 mobilité)

Placés volontairement pour donner de la matière aux groupes : 10 postes en
sous-effectif, 20 contrats arrivant à échéance sous trois mois, des parcours en
deux contrats, des temps partiels en housekeeping, des saisonniers concentrés à
Annecy et à Nice, des apprentis en cuisine et des extras en restauration.

Toutes les dates sont calculées à partir de `DATE_REFERENCE`, jamais de
l'horloge. Réglez cette variable sur le premier jour du cours, et n'y touchez
plus.

---

## Les six modules

| Code | Module | Ce qu'il consomme du socle | Besoins pris en charge |
|---|---|---|---|
| `rec` | Recrutement | postes, établissements, contrats | `recrutement` |
| `form` | Formation | compétences, salariés, entretiens | `formation` |
| `mob` | Mobilité & carrière | aspirations, postes, contrats | `mobilite` |
| `gta` | Gestion des temps | salariés, contrats, établissements, départements | *aucun* |
| `portail` | Portail RH & Self-Service | salariés, contrats, hiérarchie managériale | *aucun* |
| `onb` | Onboarding & Offboarding | salariés, contrats, postes, départements | *aucun* |

La paie est hors périmètre : elle est considérée comme externalisée. Le socle
ne porte aucun objet de rémunération.
