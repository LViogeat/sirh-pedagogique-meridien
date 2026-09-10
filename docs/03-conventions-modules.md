# Conventions de module

*SIRH pédagogique — Master SIRH, Université Paris 1 Panthéon-Sorbonne*

> Ce document décrit les règles auxquelles se conforme le socle (à développer en phase 2). C'est la spécification, pas encore le code.

## La règle unique

**Aucun étudiant ne modifie jamais un fichier partagé.**

Ni le routeur, ni le menu, ni le layout, ni la configuration, ni le SDK, ni le Core HR. Tout le module d'un groupe tient dans un seul dossier :

```
src/modules/rec/
  module.js          ← le manifeste (seul fichier de forme imposée)
  OffresList.vue
  OffreForm.vue
  Pipeline.vue
```

Tout le reste en découle. C'est une règle de rigueur, mais elle est **portée par le socle** : les étudiants n'ont rien à retenir, juste à travailler dans leur dossier.

## Le manifeste

```js
// src/modules/rec/module.js
export default {
  code:  'rec',                      // préfixe des tables ET segment d'URL
  label: 'Recrutement',              // libellé dans la sidebar
  icon:  'pi pi-user-plus',          // icône PrimeIcons
  routes: [
    { path: 'offres',   label: 'Offres',   component: () => import('./OffresList.vue') },
    { path: 'pipeline', label: 'Pipeline', component: () => import('./Pipeline.vue')  },
  ],
}
```

Au démarrage, le socle balaie `import.meta.glob('./modules/*/module.js')` et construit la navigation et les routes tout seul. La route ci-dessus devient `/rec/offres`.

**Ajouter une page = ajouter une ligne dans `routes` et créer le fichier `.vue`.** C'est tout.

## La sidebar

Un seul principe : **le premier niveau appartient au socle, les sous-niveaux appartiennent aux groupes.**

```
Core HR                    ← socle, jamais modifié
  Salariés
  Organigramme
  Tableau de bord
Recrutement                ← 1er niveau = 1 module = 1 dossier
  Offres                   ← sous-niveaux : le groupe les ajoute librement
  Pipeline
Gestion des temps
  Demandes de congés
Formation
  Catalogue
```

Le menu global **n'existe dans aucun fichier** : il est déduit des manifestes. Deux groupes ne peuvent donc pas entrer en conflit dessus, puisqu'il n'y a rien à partager.

C'est aussi ce qui rend les dossiers interchangeables : un dossier déposé apparaît, un dossier retiré disparaît, sans qu'aucune autre ligne ne bouge.

## Ce que cela permet

**En autonome.** Le fork d'un groupe ne contient que son dossier : la sidebar affiche le Core HR et son module. Il tourne, il se démontre.

**En fusion.** Copier les six dossiers dans un projet unique suffit. Aucun conflit possible, puisque aucun fichier commun n'a jamais été touché par personne.

**Module cassé.** Chargement paresseux et barrière d'erreur par route : l'onglet du module fautif affiche un message d'erreur, le reste du SIRH continue de fonctionner. La démonstration finale ne peut plus être prise en otage par un groupe.

**Récupération.** L'unité de sauvegarde est le dossier. Si un groupe perd son fork entre deux sessions, on reforke le socle et on redépose son dossier — deux minutes, rien n'est perdu.

## Les tables

Le préfixe découle du `code` du manifeste. Le groupe `rec` appelle :

```js
const offres = useTable('offres')   // → résout vers la table rec_offres
```

Un groupe **ne peut pas** atteindre les tables d'un autre, à deux niveaux :

- le SDK refuse un nom qui n'est pas celui du module appelant, avec un message lisible ;
- la base refuserait de toute façon l'écriture, par les politiques RLS.

La double barrière est volontaire : la première donne une erreur compréhensible tout de suite, la seconde garantit qu'aucun contournement n'est possible.

**Lire les tables d'un autre module est en revanche autorisé.** C'est délibéré : c'est ce qui rend l'intégration inter-modules possible à partir de novembre, quand chaque groupe repart du projet consolidé.

## Le rituel de demande d'évolution

Un groupe a besoin d'une table, d'une colonne, ou d'une donnée absente d'une vue ? **Il ne la crée pas.** Il rédige une expression de besoin — entité, champs, liens vers le Core HR, règles de gestion — déposée dans Planner. L'intervenant la traite avec Claude Code.

Deux régimes, selon l'ampleur :

| Régime | Pour quoi | Délai |
|---|---|---|
| **Intra-journée** | ajouter une colonne, corriger un type | traité pendant une pause, livré au sprint suivant |
| **Inter-journée** | nouvelles entités structurantes | collecté en fin de journée, livré à l'ouverture de la session suivante |

Le second simule un vrai cycle de livraison d'éditeur, avec son délai. C'est pédagogiquement plus juste que le service immédiat : les étudiants découvrent qu'un besoin mal exprimé revient mal servi — et qu'il faudra attendre un mois pour le corriger.

Côté intervenant, la livraison tient en deux instructions :

```sql
create table rec_offres ( ... );
select creer_politiques_module('rec_offres', 'rec');
```

## Ce qu'un groupe peut et ne peut pas

| | |
|---|---|
| ✅ Créer des écrans dans `src/modules/<code>/` | |
| ✅ Ajouter des entrées dans son `routes` | |
| ✅ Lire tout le Core HR par le SDK | |
| ✅ Lire et écrire ses propres tables | |
| ✅ Lire les tables des autres modules | |
| ❌ Modifier le socle, le Core HR ou un autre module | *rien ne l'en empêche dans StackBlitz, mais rien n'en sera conservé* |
| ❌ Écrire dans le Core HR | *refusé par la base* |
| ❌ Écrire dans les tables d'un autre module | *refusé par la base* |
| ❌ Créer une table | *c'est une demande d'évolution* |

## Le rituel de fin de journée

**Non négociable**, et c'est ce qui protège un mois de travail :

1. Chaque groupe dépose son dossier `src/modules/<code>/` dans son canal Teams.
2. L'intervenant collecte les dossiers et met à jour le projet consolidé.
3. `pg_dump` de la base, déposé dans SharePoint.

C'est de facto leur gestion de versions — et ils n'ont aucune notion de git à apprendre pour en bénéficier.
