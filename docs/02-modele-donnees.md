# Modèle de données Core HR

*SIRH pédagogique — Master SIRH, Université Paris 1 Panthéon-Sorbonne*

## Le principe : trois couches

C'est ce qui distingue un SIRH d'un fichier Excel, et c'est le principal enseignement du schéma.

| Couche | Table | Question à laquelle elle répond |
|---|---|---|
| **Identité** | `personnes` | *Qui est cette personne ?* — indépendamment de tout emploi |
| **Relation de travail** | `contrats` | *À quel titre juridique, de quand à quand ?* |
| **Termes négociés** | `avenants` | *Combien, à quel temps de travail, à quelle classification — et depuis quand ?* |
| **Affectation** | `affectations` | *Où travaille-t-elle, sous quelle autorité, depuis quand ?* |

Une personne existe **avant** d'être salariée (candidate), pendant (salariée), et après (ancienne salariée). Elle change de service ou de manager sans changer de contrat. Elle peut enchaîner un stage puis un CDI.

Séparer ces trois couches, c'est ce qui rend possible tout indicateur d'évolution — ancienneté, turnover, effectif à une date — et ce qui donne au module Recrutement un point d'accroche naturel dans le référentiel.

```
                         ┌─────────────┐
                         │  personnes  │  identité
                         └──────┬──────┘
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼───────┐      ┌────────▼────────┐
            │   contrats    │      │  affectations   │
            │  ce qui ne    │      │   (historisé)   │
            │  change pas   │      └────┬───────┬────┘
            └───┬───────┬───┘           │       │
                │       │               │       │
    ┌───────────▼──┐  ┌─▼──────────┐  ┌─▼─────┐ │
    │etablissements│  │  avenants  │  │postes │ │
    └──────────────┘  │  (datés)   │  └───┬───┘ │
                      │  salaire   │      │     │
                      │  ETP       │  ┌───▼───┐ │ ┌────────────────────┐
                      │  classif.  │  │emplois│ └►│ unites_organisa... │
                      └────────────┘  └───────┘   └─────────┬──────────┘
                                                            │ parent_id
                                                            └──► (arbre)
```

## Les tables

### `personnes` — l'identité

| Colonne | Type | Note |
|---|---|---|
| `id` | bigint | clé primaire |
| `matricule` | text | **NULL tant que la personne n'a jamais été salariée.** Sert de test « est-ce un salarié ? » |
| `civilite_code` | text → `ref_civilite` | |
| `nom`, `nom_usage`, `prenom` | text | `nom_usage` prime à l'affichage quand il est renseigné |
| `date_naissance` | date | |
| `email_perso`, `email_pro` | text | le professionnel n'existe qu'une fois salarié |
| `telephone`, `adresse`, `code_postal`, `ville` | text | |
| `nationalite` | text | |

### `contrats` — la relation de travail *(historisé)*

| Colonne | Type | Note |
|---|---|---|
| `personne_id` | → `personnes` | |
| `etablissement_id` | → `etablissements` | un contrat est toujours porté par un établissement |
| `numero` | text unique | |
| `type_contrat_code` | → `ref_type_contrat` | CDI, CDD, apprentissage, professionnalisation, stage, intérim |
| `date_debut` | date | |
| `date_fin_prevue` | date | terme prévu au contrat. **NULL pour un CDI** |
| `date_fin_reelle` | date | sortie effective. **Tant qu'elle est NULL, le contrat court** |
| `fin_periode_essai` | date | |
| `motif_cdd_code` | → `ref_motif_cdd` | obligatoire pour un CDD *(contrainte en base)* |
| `motif_sortie_code` | → `ref_motif_sortie` | obligatoire dès qu'il y a une sortie *(contrainte en base)* |
| `etp` | numeric | entre 0 exclus et 1 |
`contrats` ne porte **que ce qui ne change jamais**. Tout ce qui se négocie — salaire, temps de travail, classification — vit dans `avenants`.

### `avenants` — les termes négociés *(daté)*

Un salaire n'est pas un attribut du contrat : c'est l'**état courant d'une suite d'avenants datés**. Une augmentation, un passage à temps partiel, une promotion sont juridiquement des avenants, avec une date d'effet.

| Colonne | Type | Note |
|---|---|---|
| `contrat_id` | → `contrats` | |
| `numero_ordre` | int | unique par contrat |
| `type_avenant_code` | → `ref_type_avenant` | contrat initial, augmentation individuelle ou générale, promotion, changement de temps de travail, classification, mobilité |
| `date_effet` | date | **quand les nouveaux termes s'appliquent** |
| `date_signature` | date | peut précéder la date d'effet |
| `motif` | text | |
| `etp` | numeric | |
| `csp_code` | → `ref_csp` | |
| `classification`, `coefficient` | | |
| `salaire_base_brut_mensuel` | numeric | voir encadré |

> **Le contrat initial est lui-même un avenant** (n° 1). Les termes variables ne vivent donc **que** dans cette table, jamais en double sur le contrat. Pas de logique de repli « si pas d'avenant, prendre la valeur du contrat » — c'est exactement là que les erreurs se logent.

L'état courant d'un contrat, c'est le dernier avenant dont la date d'effet est passée. **Les étudiants ne font jamais ce calcul** : `v_employes_actifs` le fait pour eux.

> **Pourquoi le salaire est là, et pourquoi ce n'est pas de la paie.**
> Le salaire de base est une donnée **contractuelle**, donc du Core HR. Il permet des indicateurs utiles — masse salariale, écarts de rémunération, temps écoulé depuis la dernière augmentation — et donne de la matière aux modules Évaluation (campagnes d'augmentation) et Formation (budget). La paie au sens strict — bulletins, cotisations, net à payer — reste hors périmètre : elle est externalisée.

Ce que le modèle rend possible et qu'un salaire écrasé interdirait : reconstituer un effectif ou une masse salariale **à une date passée**, mesurer l'évolution d'une rémunération, savoir depuis combien de temps un salarié n'a pas été augmenté.

Deux limites assumées, à faire évoluer si un groupe en a besoin : le **type de contrat** et l'**établissement** restent sur `contrats` — une transformation de CDD en CDI est traitée comme un nouveau contrat, et une mobilité inter-établissements n'est pas modélisée.

### `affectations` — où et sous quelle autorité *(historisé)*

| Colonne | Type | Note |
|---|---|---|
| `personne_id` | → `personnes` | |
| `poste_id` | → `postes` | nullable |
| `unite_id` | → `unites_organisationnelles` | |
| `manager_personne_id` | → `personnes` | |
| `date_debut`, `date_fin` | date | `date_fin` NULL = affectation en cours |
| `taux_affectation` | numeric | pour une personne partagée entre deux unités |

C'est **le point de modélisation le plus important du schéma** : c'est parce que l'affectation est distincte du contrat qu'un salarié peut changer de service ou de manager sans qu'on touche à son contrat, et qu'on peut reconstituer son parcours.

### La structure

**`etablissements`** — 3 dans le jeu de démonstration : Paris (siège), Lyon (agence), Nantes (site industriel). Avec SIRET et adresse.

**`unites_organisationnelles`** — arbre auto-référencé sur 3 niveaux (`direction` > `departement` > `service`), rattaché à un établissement, avec un responsable désigné.

**`emplois` vs `postes`** — la distinction est volontaire et elle est un sujet de cours à part entière :

- un **emploi** est une entrée du référentiel métier (« Chargé de recrutement »). Il existe même si personne ne l'occupe.
- un **poste** est une position budgétée : un emploi, dans une unité, pour un ETP donné.

Un poste ouvert et non pourvu est une **vacance** — et c'est le crochet naturel du module Recrutement : *une offre pourvoit un poste vacant*. Le jeu de données en contient un par service, soit 13.

> En pratique il y en a **14** : le départ du responsable Qualité a libéré le sien. Un poste vacant ne se décrète pas, il se **calcule** — un poste ouvert auquel aucune affectation en cours n'est rattachée. C'est une découverte que le groupe Recrutement fera de lui-même, et c'est tant mieux.

### Les référentiels

Cinq tables `ref_*` de forme strictement identique : `(code, libelle, ordre, actif)`.

`ref_civilite` · `ref_type_contrat` · `ref_motif_cdd` (motifs de recours au CDD) · `ref_motif_sortie` · `ref_csp`

L'uniformité est délibérée : le SDK les lit toutes via `getRef('type_contrat')`, et une IA à qui l'on décrit une seule forme ne peut pas se tromper sur les autres.

## Les vues — le contrat d'interface

**C'est la pièce maîtresse du dispositif.** Les étudiants ne voient jamais les tables historisées : ils lisent des vues aplaties.

| Vue | Contenu | Usage |
|---|---|---|
| **`v_employes_actifs`** | **une ligne par salarié présent aujourd'hui** | la vue de référence |
| `v_historique_remuneration` | la carrière salariale, avenant par avenant, avec le % d'évolution | modules Évaluation et Formation |
| `v_personnes` | toutes les personnes + statut (Salarié / Ancien salarié / Externe) | module Recrutement |
| `v_effectif_par_service` | effectif et ETP agrégés | tableaux de bord |
| `v_mouvements` | entrées et sorties par mois sur 36 mois | turnover |
| `v_organigramme` | unité, parent, responsable, effectif | arbre organisationnel |

`v_employes_actifs` réunit en une ligne : identité, âge, contrat en cours, **termes de l'avenant en vigueur** (ETP, CSP, classification, coefficient, salaire), établissement, service, emploi, poste, manager, **date d'entrée dans l'entreprise**, **ancienneté en mois**, ainsi que `nb_avenants` et `date_derniere_augmentation`.

Trois subtilités qu'elle absorbe pour les étudiants :

- **le salaire affiché n'est pas stocké sur le contrat.** Il vient du dernier avenant dont la date d'effet est passée. Un avenant signé mais à effet futur n'apparaît pas — c'est voulu.

- **la date d'entrée n'est pas la date du contrat en cours.** Elle est le début du plus ancien contrat de la personne. Un salarié passé par un stage avant son CDI a donc une ancienneté supérieure à la durée de son contrat actuel.
- **si une personne a plusieurs contrats actifs**, la vue retient le principal : le plus fort ETP, puis le plus récent.

> **Une donnée manquante dans une vue est une demande d'évolution, pas une jointure.**
> Si un module a besoin d'une information du référentiel qui n'est pas dans `v_employes_actifs`, le groupe rédige une demande. On ne contourne pas le contrat d'interface.

Deux vues techniques, `v_contrats_actifs` et `v_affectations_actives`, servent uniquement à construire les autres. Elles ne sont pas exposées.

## Les habilitations

Une table **`profils`** associe chaque compte à son module. Le rôle vit dans une table, pas dans le jeton : l'attribution des groupes se décide en cours, et une cellule modifiée dans le dashboard prend effet **immédiatement**, sans reconnexion.

```sql
create function mon_module() returns text
language sql stable security definer
as 'select module from public.profils where user_id = auth.uid()';
```

Règles appliquées :

| Qui | Core HR et vues | Ses tables | Les tables des autres |
|---|---|---|---|
| Non connecté | ✗ | ✗ | ✗ |
| Compte étudiant | **lecture** | **lecture + écriture** | **lecture** seule |
| Intervenant | tout, via le dashboard | | |

La lecture ouverte entre modules est délibérée : c'est elle qui rend l'intégration possible.

Pour chaque nouvelle table de module, une fonction pose les deux politiques standard — et **refuse** une table dont le nom ne respecte pas le préfixe du groupe :

```sql
create table rec_offres ( ... );
select creer_politiques_module('rec_offres', 'rec');
```

Le Core HR, lui, n'a **aucune** politique d'écriture. Avec la RLS activée, l'absence de politique signifie « interdit ».

### Le point d'écriture contrôlé, à venir

Le jour où le module Recrutement voudra transformer un candidat en salarié, ce sera par une **fonction SQL dédiée** (`rpc_embaucher`), écrite par l'intervenant. C'est le seul chemin d'écriture vers le référentiel — et il illustre exactement pourquoi on n'écrit jamais en direct dans un Core HR.

À construire à la demande, pas d'avance.

## Le jeu de données

**Groupe Meridien**, PME industrielle et commerciale française. Le script est **déterministe** : aucun `random()`, rejoué deux fois il produit exactement les mêmes lignes. C'est une exigence de la recette — les étudiants doivent pouvoir écrire *« alors la liste affiche 22 salariés »* **avant** d'avoir codé l'écran.

### Chiffres de référence

| | |
|---|---|
| Établissements | 3 — Paris 99, Nantes 64, Lyon 16 |
| Unités | 19 (1 DG, 5 directions, 13 services) |
| Emplois / postes | 28 / 193, dont **13 vacants d'office** — 14 réellement non pourvus |
| Personnes | 222 |
| **Salariés présents** | **179** |
| Anciens salariés | 33 |
| Candidats externes | 10 |
| ETP total | 172,60 |
| Contrats | 213, dont CDI 153 · CDD 10 · apprentissage 9 · stage 7 présents |
| **Avenants** | **725** — 3,4 par contrat en moyenne, dont 427 augmentations et 84 promotions |
| CSP | Employé 56 · Cadre 55 · Ouvrier 40 · TAM 28 |
| Répartition | 98 hommes / 81 femmes |
| Temps partiels | 22 (à 0,80 · 0,60 · 0,50) |
| Masse salariale mensuelle brute | 589 532,70 € |

### Effectifs par service

| Service | Effectif | | Service | Effectif |
|---|---|---|---|---|
| Atelier | 33 | | Marketing | 9 |
| Ventes Île-de-France | 24 | | Comptabilité | 8 |
| Études et développement | 22 | | Paie et ADP | 6 |
| Logistique | 18 | | Contrôle de gestion | 5 |
| Ventes Rhône-Alpes | 16 | | Développement RH | 5 |
| Production et support | 14 | | Méthodes | 4 |
| Qualité | 9 | | | |

> **Effectifs stables, âges et anciennetés mobiles.** Les effectifs par service et les répartitions par contrat ne bougent pas. En revanche l'âge moyen, l'ancienneté et les mouvements par mois se recalculent par rapport à la date du jour — à ne pas figer dans un script de recette.

### Les cas tordus, volontaires

Chacun est un sujet de conception qui fera surface en sprint. Ils sont dans le jeu de données **exprès**.

| Cas | Où | Ce qu'il révèle |
|---|---|---|
| **Parcours en deux contrats** — stage puis CDI | service Études | La date d'entrée ≠ la date du contrat en cours. Piège classique du calcul d'ancienneté |
| **CDD qui expire demain** | service Logistique | Un effectif est toujours daté : présent aujourd'hui, absent demain |
| **Équipe orpheline** — le responsable Qualité est parti | service Qualité, 9 salariés | Leur manager n'apparaît dans aucune liste de salariés présents. Grand classique des reprises de données |
| **Passage à temps partiel** — 0,50 puis 0,60 ETP | service Comptabilité | Ce n'est pas une correction de donnée, c'est un **avenant daté**. Avant sa date d'effet, l'ETP était différent — un effectif au 31/12 dernier ne compte donc pas la même chose |
| **Unité sans responsable** | service Méthodes | Un affichage naïf de l'organigramme cassera dessus |

## Ordre d'exécution des scripts

```
db/01-schema.sql            tables, contraintes, index
db/02-referentiels.sql      alimentation des ref_*
db/03-vues.sql              les vues aplaties
db/04-profils-policies.sql  profils, mon_module(), RLS, générateur de politiques
db/05-seed.sql              le jeu de données (termine par un contrôle de cohérence)
```

`01` et `05` sont destructifs : ils ne se rejouent **jamais** en cours de session. `02`, `03` et `04` sont idempotents.

L'ensemble a été exécuté et vérifié sur PostgreSQL 14 : les cinq cas tordus sont présents, le seed est reproductible à l'identique, et la matrice d'habilitations se comporte comme spécifié.
