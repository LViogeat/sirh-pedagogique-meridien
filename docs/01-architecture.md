# Architecture

*Socle SIRH Sorbonne-Hôtel — Master 2 SIRH, Université Paris 1 Panthéon-Sorbonne*

## Le problème à résoudre

Faire produire six modules d'un SIRH par dix-neuf étudiants **non-développeurs**,
en trois jours, par sprints d'environ deux heures de production réelle, avec
pour seul outil une IA en conversation et du copier-coller. Ils n'installent
rien : le dépôt s'ouvre dans StackBlitz, et l'API du socle est déployée.

Le code n'est pas l'objectif : c'est le support. Ce que les étudiants doivent
emporter, c'est la capacité à lire un modèle de données, exprimer un besoin
exploitable, piloter une IA, recetter et démontrer.

**Chaque minute passée à déboguer un import est volée à la conception.**
Toute l'architecture découle de cette phrase.

## Vue d'ensemble

```
┌────────────────────────────────────────────────────────────────────┐
│  StackBlitz ×6 — un fork par groupe, Vite dans leur navigateur      │
│                                                                     │
│   app/src/socle/      app/src/corehr/      app/src/modules/rec/     │
│   ├ SDK               ├ Besoins            ├ module.js              │
│   ├ menu auto         ├ Salariés           ├ schema.sql             │
│   └ barrière d'erreur ├ Postes             └ OffresList.vue         │
│                       ├ Entretiens               ↑                  │
│                       └ Console SQL      seule zone étudiante       │
└───────────────────────────┬─────────────────────────────────────────┘
                            │  HTTPS · Authorization: Bearer <jeton>
┌───────────────────────────▼─────────────────────────────────────────┐
│  API FastAPI                                                         │
│   /etablissements /salaries /postes /entretiens /besoins   lecture   │
│   PATCH /besoins/{id}                              la seule écriture │
│   POST /sql                         sous le rôle PostgreSQL du groupe│
│   /admin/*                                    réservé à l'intervenant│
└───────────────────────────┬─────────────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────────────┐
│  PostgreSQL                                                          │
│                                                                      │
│   schéma public              schémas rec · form · mob · gta ·        │
│   Core HR + Évaluation       portail · onb                           │
│   + identified_needs         propriété de chaque groupe              │
│                                                                      │
│   grp_all lit public et tous les schémas ; chaque groupe n'écrit     │
│   que chez lui. C'est la base qui arbitre.                           │
└──────────────────────────────────────────────────────────────────────┘
```

## Les décisions

### Un socle figé, et des groupes propriétaires de leur schéma

C'est la décision structurante. Elle règle d'un coup deux problèmes qui, dans
un dispositif de trois jours, coûtent très cher.

Le premier : **l'intervenant en goulot d'étranglement.** Si c'est lui qui crée
les tables des groupes, chaque sprint commence par une file d'attente. En
donnant à chaque groupe un schéma PostgreSQL dont il est propriétaire, le
rituel de demande d'évolution disparaît : un groupe écrit son `create table`
dans la console SQL du socle et travaille.

Le second : **la modélisation comme objet de cours.** Un consultant SIRH doit
savoir lire et critiquer un modèle de données. Créer ses propres tables, se
tromper, et devoir les reprendre est exactement l'exercice visé. Un magasin de
données générique le leur aurait retiré.

Corollaire : le socle n'a plus besoin de bouger, et il ne bougera pas.

### Un groupe, un module, un menu

Le menu affiche le SIRH entier — le socle et les six modules — mais **un seul
est ouvrable : celui du groupe**, désigné par `VITE_MODULE_CODE`. Les cinq
autres apparaissent grisés, et le routeur refuse d'y aller même par une URL
tapée à la main.

Montrer les six plutôt que masquer les autres est délibéré : chaque groupe voit
où son module s'inscrit dans l'ensemble, et ce que les autres construisent à
côté. C'est la même raison qui fait qu'il n'y a qu'une seule base.

Les écrans du socle, eux, sont **en consultation stricte**. Aucun bouton
d'action n'y figure, pas même sur les besoins identifiés : prendre un besoin en
charge est une opération de module, elle appartient aux écrans du groupe. Un
bouton « Prendre en charge » posé sur un écran du socle brouillerait
exactement la frontière que le cours cherche à enseigner.

### Chaque module ne prend que son type de besoin

Tout le monde lit tous les besoins — c'est ce qui rend la chaîne lisible en
démonstration. Mais le module Recrutement ne prend en charge que les besoins
de recrutement, Formation que ceux de formation, Mobilité que ceux de
mobilité. Les trois autres modules n'en consomment aucun.

Le lien est porté par la configuration, quatrième champ de la variable
`GROUPES` : `rec:Recrutement:jeton:recrutement`. Ajouter ou retirer ce champ
suffit à changer ce qu'un groupe peut traiter — sans toucher au code.

### PostgreSQL applique les droits, pas le code

Chaque groupe a un rôle PostgreSQL. À chaque requête, l'API lit le jeton et
bascule sur ce rôle le temps d'une transaction :

```sql
begin;
  set local role grp_rec;
  set local search_path = rec, public;
  set local statement_timeout = '5s';
  -- la requête du groupe
commit;
```

Le groupe est propriétaire de son schéma, lecteur du socle et des cinq autres
schémas, et rien d'autre. Il n'y a rien à vérifier côté Python, donc rien à
oublier de vérifier. Une requête qui tenterait d'écrire dans le socle reçoit
`permission denied for table employees` — un message que l'étudiant lit,
comprend, et n'oublie pas.

`SET LOCAL` ne vaut que jusqu'à la fin de la transaction : la connexion rendue
au pool repart avec les droits du compte applicatif, sans remise en état.

### Deux chemins d'accès, et la frontière est pédagogique

Le socle se lit par son API REST, décrite dans une spécification OpenAPI. Les
données d'un groupe se manipulent en SQL. Ce n'est pas une incohérence, c'est
la leçon : **on consomme un produit par son contrat d'interface, on possède son
propre schéma.**

Et comme tout vit dans la même base, une requête d'un groupe peut joindre ses
tables au socle. C'est ce qui rend l'intégration inter-modules possible dès que
chacun a de la matière.

### FastAPI plutôt qu'un générateur d'API

La spécification OpenAPI est **le livrable le plus important pour les
étudiants** : c'est ce qu'ils collent dans Copilot pour qu'il écrive du code
juste. Elle doit donc être exacte, lisible et stable.

Avec FastAPI, elle est engendrée depuis les modèles de réponse : elle ne peut
pas diverger du code. Un même langage porte l'API, le jeu de données, les
règles de génération des besoins et la commande de remise à zéro.

Deux fichiers en sortent, versionnés dans le dépôt :

- `openapi.json` — la spécification complète, qui fait foi ;
- `contrat-api.md` — la même chose en dix fois moins de place, parce qu'une
  spécification de 90 Ko sature le contexte d'un chat IA gratuit.

### Un modèle plat, exposé à plat

Un SIRH de production historise les affectations et les avenants. Ici, non :
l'historique d'un salarié tient dans la suite de ses contrats, et cela suffit
au périmètre du cours.

Ce choix a un coût — on ne saura pas dire qui occupait quel poste au 31
décembre — et un bénéfice qui l'emporte largement : **chaque jointure épargnée
est une requête juste de plus.** Une requête récursive sur un organigramme, ou
une jointure temporelle sur un avenant en vigueur, est exactement ce qu'une IA
rate, et ce qu'un étudiant non-développeur ne saura pas corriger.

Pour la même raison, les énumérations sont des colonnes `text` avec une
contrainte `CHECK`, pas des types PostgreSQL dédiés : on écrit
`where contract_type = 'CDI'` et ça marche.

### Les besoins identifiés, et leur clé naturelle

Trois règles produisent les besoins. Leurs seuils vivent dans un seul fichier,
`api/socle/rules/seuils.py`, écrit pour être lu par les étudiants et ajusté par
l'intervenant entre deux sprints.

Chaque besoin porte une clé naturelle : `(type, salarié, poste, compétence)`.
La commande de génération est donc **rejouable en plein cours** : elle crée les
besoins nouveaux, rafraîchit ceux qui sont encore ouverts, et ne touche jamais
à ceux qu'un groupe a pris en charge ou clôturés.

### Des données déterministes, calées sur une date de référence

Le jeu de données est engendré par un générateur semé sur une graine fixe, et
toutes les dates se calculent à partir de `DATE_REFERENCE` — jamais de
l'horloge. Remis à zéro deux fois, il produit exactement les mêmes lignes, avec
les mêmes identifiants.

Deux raisons, et la seconde est la plus importante :

1. La recette devient possible avant le code : un groupe peut écrire « alors
   l'écran affiche 12 besoins de formation ouverts à Lyon » puis vérifier.
2. Les groupes stockent des identifiants du socle dans leurs tables
   (`besoin_id`, `employee_id`). Si une remise à zéro les décalait, leurs
   données pointeraient dans le vide.

### Pas de migrations

Le socle est figé au jour 1 et les données sont fictives : il n'y aura jamais
de migration en place à jouer. Les modèles sont la source de vérité, les tables
en sont créées au démarrage, et toute évolution passe par une remise à zéro.

Un outil de migration aurait ajouté un mode de défaillance au déploiement sans
rien résoudre.

### Aucun fichier partagé entre groupes

Le menu global n'existe dans aucun fichier : il est déduit des manifestes
trouvés dans `app/src/modules/<code>/module.js`. Un dossier déposé apparaît, un
dossier retiré disparaît.

Conséquences : le fork d'un groupe tourne en autonome, la fusion consiste à
copier des dossiers, et un module cassé n'emporte pas les autres — chaque écran
est chargé paresseusement derrière une barrière d'erreur, si bien que la
démonstration finale ne peut plus être prise en otage par un groupe.

### Une seule instance, partagée

Les six groupes tapent la même base. C'est délibéré : c'est ce qui rend les
dépendances entre modules visibles, et ce qui rend la démonstration finale
crédible — tout le monde parle des mêmes salariés.

Les jetons ne protègent rien, et ne cherchent pas à le faire : les données sont
entièrement fictives. Ils identifient l'appelant et empêchent une collision
entre groupes.
