# Architecture

*SIRH pédagogique — Master SIRH, Université Paris 1 Panthéon-Sorbonne*

## Le problème à résoudre

Faire produire un logiciel SIRH par des étudiants **non-développeurs**, en trois journées espacées d'un mois (octobre, novembre, décembre), par sprints d'une heure, avec pour seul outil de développement une IA en conversation et du copier/coller.

Le code n'est pas l'objectif : c'est le support. Ce que les étudiants doivent emporter, c'est la capacité à lire un modèle de données, exprimer un besoin exploitable, piloter une IA, recetter et démontrer. **Chaque minute passée à déboguer un import est volée à la conception.**

Toute l'architecture découle de cette phrase.

## Vue d'ensemble

```
┌──────────────────────────────────────────────────────────┐
│  StackBlitz — Vue 3 + PrimeVue                           │
│                                                          │
│   socle/          corehr/         modules/rec/  gta/ ... │
│   ├ sidebar       ├ salariés      ├ module.js            │
│   ├ SDK           ├ organigramme  ├ OffresList.vue       │
│   ├ session       └ tableau bord  └ Pipeline.vue         │
│   └ erreurs                            ↑                 │
│        │                        seule zone étudiante     │
└────────┼─────────────────────────────────────────────────┘
         │  supabase-js (HTTPS)
┌────────▼─────────────────────────────────────────────────┐
│  Supabase — PostgreSQL                                   │
│                                                          │
│   Vues aplaties ← le contrat d'interface                 │
│        ↑                                                 │
│   Core HR historisé          Tables de module            │
│   personnes · contrats       rec_* · gta_* · form_* ...  │
│   avenants · affectations                                │
│   postes · emplois                                       │
│                                                          │
│   RLS : lecture pour tous, écriture pour le propriétaire │
└──────────────────────────────────────────────────────────┘
```

## Les décisions

### Supabase plutôt qu'un backend

Un backend Node classique aurait coûté un sprint entier au premier bug, et ses données n'auraient pas survécu à un rechargement de page — encore moins à quatre semaines d'intervalle. Supabase fournit Postgres hébergé et une API REST auto-générée : **zéro ligne de backend à écrire, à déboguer ou à héberger**.

C'est aussi la seule option où les données saisies en octobre existent encore en décembre. Avec du `localStorage` ou un fichier JSON, chaque session repartirait de zéro.

### L'intervenant seul fait le DDL

Les étudiants ne créent jamais de table. Ils rédigent une demande d'évolution ; l'intervenant la traite avec Claude Code et la livre.

C'est plus simple, c'est plus sûr, et c'est surtout **conforme à leur futur métier** : dans un vrai SIRH, un consultant fonctionnel n'écrit pas de DDL — il spécifie, et découvre qu'un besoin mal exprimé revient mal servi.

### Une seule base partagée

Tous les groupes lisent le **même** référentiel de 180 salariés. Les modules ajoutent leurs tables, préfixées par leur code (`rec_`, `gta_`, `form_`, `eval_`).

C'est ce qui rend la démonstration finale crédible — tout le monde parle des mêmes personnes — et c'est littéralement la leçon du cours : *un référentiel unique, des modules branchés dessus*.

### Un modèle historisé, exposé à plat

`contrats`, `avenants` et `affectations` sont datés, parce qu'un SIRH doit savoir où était un salarié au 31 décembre — et combien il gagnait. Un salaire n'est pas une colonne qu'on écrase : c'est l'état courant d'une suite d'avenants. Mais exposer ce modèle temporel brut à des non-développeurs garantirait des requêtes fausses à chaque sprint.

Les étudiants consomment donc des **vues aplaties** : une ligne par salarié, état du jour. Ils voient l'historisation en théorie et dans le schéma ; ils codent sur du plat. La complexité reste côté base.

→ voir [`02-modele-donnees.md`](02-modele-donnees.md)

### Un SDK, pas le client Supabase

Les étudiants n'écrivent ni SQL ni appel Supabase. Une douzaine de fonctions documentées suffisent, et tiennent sur une page.

L'enjeu n'est pas le confort : c'est la **taille du prompt**. Une IA à qui l'on donne une liste fermée de fonctions ne peut quasiment plus inventer de code faux.

→ voir [`04-sdk.md`](04-sdk.md)

### La fusion par construction

Aucun étudiant ne modifie jamais un fichier partagé — ni le routeur, ni le menu, ni le layout. Tout son module tient dans `src/modules/<code>/`, décrit par un manifeste. Le socle découvre les modules au démarrage et construit la navigation seul.

Conséquences : leur fork tourne en autonome ; la fusion consiste à copier des dossiers ; un module cassé n'emporte pas les autres.

→ voir [`03-conventions-modules.md`](03-conventions-modules.md)

### Les droits s'appliquent dans la base, pas dans le code

L'intervenant crée tous les comptes et attribue à chacun un rôle égal au code de son module. Ce rôle vit dans une table, pas dans le jeton : les groupes s'attribuent en cours, et une cellule modifiée prend effet immédiatement.

Chaque table de module reçoit deux politiques : **lecture pour tout compte connecté**, écriture pour le seul groupe propriétaire. Le Core HR est en lecture seule pour tous.

La lecture ouverte est délibérée : c'est elle qui rend l'intégration inter-modules possible — le groupe Formation peut afficher les entretiens du groupe Évaluation.

> **StackBlitz ne permet aucun verrouillage de fichier.** Rien n'empêche techniquement un étudiant d'éditer le dossier d'un autre groupe dans son propre fork. C'est sans conséquence : seul son dossier sera collecté en fin de journée, et la base refusera l'écriture. C'est même un excellent sujet de cours — la sécurité applicative ne se joue jamais dans l'interface.

### Une IA interchangeable

Le kit de prompts ne vise aucun outil en particulier : il fonctionne avec Copilot Chat, Claude.ai, ChatGPT ou Le Chat. Copilot en version gratuite est plafonné à 50 requêtes de chat par mois — un groupe épuiserait ce quota en une demi-journée. Aucun point de défaillance unique n'est acceptable le jour J : si un groupe atteint une limite, il change d'onglet.

## Ce que la cadence mensuelle impose

Trois journées séparées par un mois, c'est la contrainte la plus structurante du dispositif.

**La base doit rester debout.** Un projet Supabase gratuit se met en pause après 7 jours sans appel API, et reste restaurable 90 jours — un intervalle d'un mois passe donc sans danger. Deux précautions : un ping périodique pour qu'il ne s'endorme jamais, et surtout un `pg_dump` à chaque fin de journée, car **l'offre gratuite ne conserve aucune sauvegarde**.

**Le travail étudiant doit survivre.** Un groupe qui perd son fork perd un mois. La parade est structurelle : l'unité récupérable est un **dossier**. Chaque fin de journée, chaque groupe dépose son `src/modules/<code>/` dans son canal Teams. En cas de perte, on reforke le socle et on redépose le dossier — deux minutes. C'est leur gestion de versions, sans une notion de git à apprendre.

**La fusion devient incrémentale.** Puisque les dossiers sont collectés chaque mois, le projet consolidé se maintient au fil de l'eau. Novembre et décembre redémarrent depuis lui : chaque groupe forke une application contenant déjà les modules des autres. La sidebar montre le SIRH entier, l'intégration inter-modules devient possible, et la démonstration finale cesse d'être un pari.

## Ce qui reste à valider avant tout développement

Un seul test conditionne l'ensemble du dispositif, et il doit être fait **depuis un poste étudiant réel** : vérifier que `*.supabase.co` et StackBlitz ne sont pas filtrés par le réseau de l'université, et qu'un compte StackBlitz se crée avec une adresse universitaire.

S'il échoue, c'est l'environnement qu'il faut revoir — pas l'architecture.
