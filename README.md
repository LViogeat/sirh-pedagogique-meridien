# SIRH pédagogique — Groupe Meridien

Socle Core HR pour le cours de Master SIRH, Université Paris 1 Panthéon-Sorbonne.
Trois journées espacées d'un mois (octobre, novembre, décembre), sprints d'une heure,
étudiants non-développeurs travaillant avec une IA en conversation.

**État : phase 1 livrée** — architecture, modèle de données et base de données.
Le socle applicatif (phase 2) et les kits pédagogiques (phase 3) restent à construire.

## Documentation

| | |
|---|---|
| [`docs/01-architecture.md`](docs/01-architecture.md) | Les décisions et leurs raisons |
| [`docs/02-modele-donnees.md`](docs/02-modele-donnees.md) | Le modèle, les vues, le jeu de données |
| [`docs/03-conventions-modules.md`](docs/03-conventions-modules.md) | Ce qu'un groupe peut faire, et où |
| [`docs/04-sdk.md`](docs/04-sdk.md) | L'antisèche — future base du kit de prompts |
| [`db/06-comptes.md`](db/06-comptes.md) | Créer les comptes, attribuer les groupes, livrer une table |

## Installer la base

Dans le **SQL Editor** d'un projet Supabase neuf, dans cet ordre :

```
db/01-schema.sql            tables, contraintes, index
db/02-referentiels.sql      alimentation des ref_*
db/03-vues.sql              les vues aplaties
db/04-profils-policies.sql  profils, mon_module(), RLS
db/05-seed.sql              180 salariés — se termine par un contrôle de cohérence
```

⚠️ `01` et `05` sont **destructifs**. Ne jamais les rejouer en cours de session.
`02`, `03` et `04` sont idempotents.

Réglez l'authentification **avant** de créer les comptes : voir `db/06-comptes.md`.

## Le principe en une page

**Un référentiel unique, des modules branchés dessus.** L'intervenant tient le Core HR
et la base ; chaque groupe développe un module dans son propre dossier.

- Les étudiants n'écrivent **ni SQL ni appel Supabase** — un SDK d'une douzaine de fonctions suffit.
- Le modèle est **historisé** mais exposé **à plat** par des vues : la complexité reste en base.
- Un salaire n'est pas une colonne qu'on écrase : c'est une suite d'**avenants datés**.
- Personne ne crée de table : on rédige une **demande d'évolution**, l'intervenant la livre.
- Aucun étudiant ne modifie un fichier partagé : tout tient dans `src/modules/<code>/`,
  et la navigation est déduite des manifestes. **La fusion revient donc à copier des dossiers.**
- Les droits s'appliquent **dans la base** : lecture pour tous, écriture pour le seul propriétaire.

## Chiffres du jeu de données

179 salariés présents · 33 anciens · 10 candidats externes · 3 établissements ·
13 services · 14 postes non pourvus · 172,60 ETP · **725 avenants** retraçant
les carrières salariales (3,4 par contrat)

Le seed est **déterministe** : rejoué, il produit exactement les mêmes lignes.
C'est une exigence de la recette — on doit pouvoir écrire le résultat attendu avant de coder l'écran.

Cinq cas tordus y sont placés volontairement (parcours en deux contrats, CDD expirant demain,
équipe orpheline, passage à temps partiel par avenant, unité sans responsable) : ce sont
des sujets de conception.

## Vérifié

Scripts exécutés sur PostgreSQL 14 avec un schéma `auth` simulé :
seed reproductible à l'identique, cinq cas tordus présents, et matrice d'habilitations
conforme — un compte de groupe lit tout, n'écrit que chez lui, et un visiteur non
connecté n'accède à rien.

## À faire avant le premier cours

**Tester depuis un poste étudiant réel** que `*.supabase.co` et StackBlitz ne sont pas
filtrés par le réseau de l'université, et qu'un compte StackBlitz se crée avec une
adresse universitaire. C'est le seul test qui, s'il échoue, remet en cause le dispositif.
