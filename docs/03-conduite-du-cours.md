# Conduite du cours

*Votre document. Ce que vous faites, quand, et ce que vous distribuez.*

Les étudiants ne lisent pas cette page : la leur est
[`README-ETUDIANTS.md`](../README-ETUDIANTS.md).

---

## 1. Qui tient quoi

| | Vous | Eux |
|---|---|---|
| Le socle et l'API | ✅ | lecture seule |
| Les données de démonstration | ✅ | lecture seule |
| Les besoins identifiés | vous les générez | ils en font avancer le statut |
| Leur schéma PostgreSQL | — | ✅ propriétaires |
| Leurs écrans | — | ✅ |
| Les jetons | ✅ | ils reçoivent le leur |

Le socle est **figé pour les trois jours**. Il n'y a pas de rituel de demande
d'évolution : chaque groupe crée ses tables lui-même, vous n'êtes jamais dans
la boucle. Les deux seuls leviers que vous gardez sont la remise à zéro des
données et les seuils de génération des besoins.

---

## 2. Les jetons

### D'où ils sortent

Ils ont été engendrés une fois, sur le serveur, et vivent dans `/opt/sirh/.env`
— un fichier en `chmod 600`, jamais versionné :

```bash
for g in rec form mob gta portail onb admin; do openssl rand -hex 12; done
```

Ils sont recopiés dans la variable `GROUPES`, au format
`code:Libellé:jeton[:type_besoin]`. Le quatrième champ dit quel type de besoin
identifié le module a le droit de prendre en charge — trois modules seulement
en ont un.

### Les relire, et imprimer les fiches

```bash
ssh <serveur> 'bash -s' < scripts/fiches-groupes.sh
```

Le script sort six fiches prêtes à coller dans un canal Teams ou à imprimer :
lien du projet, les deux lignes de `.env`, le nom du schéma, le type de besoin.
Il affiche aussi le jeton intervenant — **celui-là ne se distribue pas**, il
ouvre `/admin`.

### En changer un

Modifier la ligne `GROUPES` dans `/opt/sirh/.env`, puis :

```bash
cd /opt/sirh && docker compose -f docker-compose.prod.yml up -d
```

Aucune donnée n'est perdue : le jeton n'identifie que l'appelant. Le groupe met
son nouveau jeton dans son `.env` et relance `npm run dev`.

### Ce qu'ils ne protègent pas

Rien. Les données sont fictives, et un jeton voyage en clair dans le navigateur.
Ils servent à savoir qui appelle quoi, et à ce qu'un groupe ne puisse pas écrire
dans le schéma d'un autre par inadvertance — ce que PostgreSQL refuserait de
toute façon. Ne les présentez pas comme une mesure de sécurité : c'est un
excellent point de cours, justement.

---

## 3. Avant le premier jour

### J-7 — le test qui conditionne tout

**Depuis un poste de l'université**, pas depuis chez vous :

| À vérifier | Comment |
|---|---|
| StackBlitz n'est pas filtré | ouvrir le lien du projet, lancer `npm install` |
| L'API n'est pas filtrée | ouvrir `https://sirh-api.govetia.com/docs` |
| Un compte StackBlitz se crée | avec une adresse universitaire |
| Copilot est accessible | avec leur compte Microsoft 365 |

Si l'un des quatre échoue, c'est l'environnement qu'il faut revoir, pas
l'architecture. Prévoyez le repli : GitHub Codespaces à la place de StackBlitz,
Claude.ai ou Le Chat à la place de Copilot.

### J-1 — caler la date de référence

**C'est l'oubli qui coûte le plus cher.** Tout le jeu de données est calculé à
partir de `DATE_REFERENCE` : ancienneté, contrats arrivant à échéance, campagne
d'entretiens en cours. Réglez-la sur le **premier jour du cours**, puis n'y
touchez plus de la semaine.

```bash
ssh <serveur>
cd /opt/sirh
sed -i 's/^DATE_REFERENCE=.*/DATE_REFERENCE=2026-10-05/' .env
docker compose -f docker-compose.prod.yml up -d
curl -X POST https://sirh-api.govetia.com/admin/reset \
     -H "Authorization: Bearer $JETON_ADMIN"
```

Vérifier ensuite que la matière est suffisante :

```bash
curl -s "https://sirh-api.govetia.com/besoins?statut=ouvert" \
     -H "Authorization: Bearer $JETON_REC" | grep -o '"need_type":"[a-z]*"' | sort | uniq -c
```

Comptez une quinzaine de besoins ouverts minimum par type consommé. Si un
groupe en manque, ajustez son seuil dans `api/socle/rules/seuils.py`, poussez,
et rejouez `/admin/besoins/generer`.

### Le matin du jour 1

1. `curl https://sirh-api.govetia.com/` répond.
2. Les six fiches sont distribuées.
3. Un fork StackBlitz de test affiche l'écran **Besoins identifiés** avec des
   lignes. Si oui, l'API, le jeton, le CORS et le réseau sont bons tous les
   quatre.

---

## 4. Ce qu'ils paramètrent dans Copilot

C'est la question la plus importante du dispositif, et la réponse tient en une
phrase : **Copilot ne connaît pas leur projet.**

Chaque nouvelle conversation démarre à froid. Une IA à qui l'on ne donne pas le
contrat d'API invente des endpoints qui n'existent pas, et le code rendu ne
marche jamais. Le collage du contexte n'est pas une politesse : c'est la
condition pour que le code fonctionne du premier coup.

### La règle

> **Une conversation = un écran.** On ouvre une conversation neuve, on colle
> l'en-tête, on demande, on colle le fichier rendu dans le projet.
> On ne réutilise pas une conversation pour un autre écran.

### En-tête A — un écran qui lit le socle

À coller **en premier message** de la conversation :

```
Je développe un module dans une application Vue 3 + PrimeVue.

Voici le contrat de l'API que je consomme :
[coller tout app/contrat-api.md]

Voici un écran existant du projet, qui me sert de modèle :
[coller tout app/src/corehr/BesoinsList.vue]

Réponds toujours par un fichier .vue complet, sans explication et sans
commentaire d'introduction.
```

Puis, en second message, la demande :

```
Écris-moi l'écran qui affiche la liste des besoins de formation ouverts,
filtrable par établissement et par priorité.
```

### En-tête B — un écran sur leurs propres tables

```
Voici mon schéma de base de données :
[coller leur schema.sql]

J'y accède avec ces fonctions, importées de '@/socle/sdk' :
  sql(requete, params)       exécute une requête, renvoie les lignes
  insert(table, objet)       insère et renvoie la ligne créée
  update(table, id, objet)   modifie et renvoie la ligne
  remove(table, id)          supprime
  useQuery(requete, params)  réactif : .rows .loading .error .refresh()
Les paramètres s'écrivent :nom et se passent dans un objet.

Voici un écran existant du projet, qui me sert de modèle :
[coller tout app/src/corehr/BesoinsList.vue]

Réponds par un fichier .vue complet, sans explication.
```

### En-tête C — corriger une erreur

```
Cet écran remonte cette erreur :
[coller le message EXACT, sans le reformuler]

Voici le fichier complet :
[coller le fichier]

Corrige-le. Rends uniquement le fichier complet corrigé.
```

### Les quatre erreurs à corriger en salle

| Ce qu'ils font | Ce que ça donne | Ce qu'on leur dit |
|---|---|---|
| Ne pas coller le contrat d'API | Copilot invente `/api/employees` | « Recommence, colle le contrat d'abord » |
| Demander « la partie qui manque » | Un fragment à recoller au bon endroit | « Demande le fichier complet » |
| Reformuler le message d'erreur | Copilot corrige autre chose | « Colle-le tel quel, sans le traduire » |
| Enchaîner cinq écrans dans une conversation | Copilot mélange les contextes | « Une conversation, un écran » |

> Copilot gratuit est plafonné à 50 requêtes de chat par mois. Un groupe
> l'épuise en une demi-journée s'il tâtonne. Prévoyez le repli : Claude.ai,
> ChatGPT ou Le Chat fonctionnent avec les mêmes en-têtes.

---

## 5. Le rythme d'un sprint

Deux heures de production réelle, cadrées :

| | |
|---|---|
| **15 min** — cadrage | ce qu'on livre à la fin, écrit au tableau |
| **80 min** — production | conception, prompts, collage, essais |
| **15 min** — recette | on vérifie sur le jeu de données, on note ce qui cloche |
| **10 min** — démonstration | trois minutes par groupe, écran partagé |

La recette est la partie qu'on sacrifie quand on est en retard, et c'est
justement celle qui a le plus de valeur : le jeu de données étant déterministe,
un groupe peut écrire « l'écran doit afficher 12 besoins de formation ouverts à
Lyon » **avant** de coder, puis vérifier.

---

## 6. Les cinq sprints

À adapter, mais l'ordre compte : lire avant d'écrire, écrire chez soi avant de
toucher au socle, et l'intégration en dernier.

### Sprint 1 — comprendre et modéliser

*Ils ne codent pas d'écran.* Ils parcourent le socle : salariés, postes,
entretiens, besoins. Ils en déduisent ce que leur module doit savoir faire,
puis écrivent leur modèle de données et l'exécutent dans la Console SQL.

**Livrable** : leur `schema.sql`, exécuté sans erreur, et leur `module.js`
présent — le module apparaît dans le menu.

**Vous** : rien. Vous circulez et vous posez une seule question à chaque
groupe : *« à quelle question métier cette table répond-elle ? »*

### Sprint 2 — le premier écran, en lecture

Un écran qui lit le socle et affiche une liste filtrable. C'est la duplication
de `BesoinsList.vue`, et c'est le sprint où ils apprennent l'en-tête A.

**Livrable** : un écran dans leur menu, qui affiche de vraies données.

### Sprint 3 — écrire chez soi

Créer, modifier, supprimer dans leurs propres tables. Un formulaire, une boîte
de dialogue, une liste qui se rafraîchit.

**Livrable** : une donnée saisie en salle, qui survit à un rechargement.

### Sprint 4 — consommer les besoins

Pour Recrutement, Formation et Mobilité : lire les besoins de leur type, en
prendre un en charge, le traiter, le clôturer. Pour GTA, Portail RH et
Onboarding : croiser deux sources du socle — salariés et contrats, hiérarchie
managériale, arrivées et départs.

**Livrable** : un besoin passé de `ouvert` à `cloture`, visible depuis l'écran
du socle par toute la classe.

**Vous** : c'est le moment de relancer `/admin/besoins/generer` si un groupe
manque de matière.

### Sprint 5 — intégration et démonstration

Chaque groupe lit les tables d'un autre. Le module Formation affiche les
candidats recrutés, Mobilité montre les formations suivies. Puis préparation de
la démonstration finale.

**Livrable** : un écran qui joint le schéma d'un autre groupe au sien.

**La démonstration finale** suit la chaîne, pas les groupes : un entretien
annuel → le besoin qu'il a produit → le module qui l'a traité → la trace dans
le socle. Six modules, un seul récit.

---

## 7. Vos commandes pendant le cours

```bash
API=https://sirh-api.govetia.com
JETON=... # /opt/sirh/.env, variable JETON_ADMIN

# Un groupe a saccagé ses données de test : on repart propre.
# Il rejouera son schema.sql depuis la Console SQL.
curl -X POST $API/admin/modules/rec/reset -H "Authorization: Bearer $JETON"

# Remettre les données du socle à zéro, entre deux sprints.
# Les schémas des groupes ne sont PAS touchés, les identifiants sont stables.
curl -X POST $API/admin/reset -H "Authorization: Bearer $JETON"

# Après avoir ajusté un seuil : rejouer les règles.
# Les besoins déjà pris en charge ne bougent pas.
curl -X POST $API/admin/besoins/generer -H "Authorization: Bearer $JETON"

# Le contrôle de cohérence.
curl $API/admin/etat -H "Authorization: Bearer $JETON"
```

**Ajuster un seuil** se fait dans `api/socle/rules/seuils.py`, puis :

```bash
git add -A && git commit -m "Seuils" && git push
ssh <serveur> 'cd /opt/sirh && git pull && docker compose -f docker-compose.prod.yml up -d --build'
curl -X POST $API/admin/besoins/generer -H "Authorization: Bearer $JETON"
```

---

## 8. Les pannes, et quoi répondre

| Symptôme | Cause | Réponse |
|---|---|---|
| « Il manque votre fichier de configuration » | pas de `.env` | leur fiche, section 2 |
| Le `.env` est créé mais rien ne change | Vite lit `.env` au démarrage | relancer `npm run dev` |
| `Jeton inconnu` | jeton mal recopié | comparer à la fiche, attention aux espaces |
| `L'API ne répond pas` | réseau, ou API arrêtée | `curl $API/` depuis votre poste |
| `permission denied for table …` | ils écrivent hors de leur schéma | c'est le cours : la base arbitre |
| `relation "…" does not exist` | la table n'a pas été créée | Console SQL |
| `Ce besoin est de type « … »` | ils prennent le besoin d'un autre | chaque module ne traite que son type |
| L'écran affiche « n'a pas pu être chargé » | erreur de syntaxe dans leur `.vue` | console du navigateur, puis en-tête C |
| Le module d'un autre groupe est grisé | c'est voulu | un groupe, un module |

Aucune de ces pannes ne demande d'intervenir sur le serveur. Si vous devez y
toucher pendant un sprint, c'est le signe que quelque chose n'a pas été prévu —
notez-le pour l'édition suivante.

---

## 9. Fin de journée

**Non négociable**, et c'est ce qui protège une journée de travail :

1. Chaque groupe dépose dans son canal Teams son dossier
   `app/src/modules/<code>/` **et** son `schema.sql`.
2. Sauvegarde des schémas des groupes :

```bash
ssh <serveur> 'docker exec sirh-db-1 pg_dump -U sirh \
  -n rec -n form -n mob -n gta -n portail -n onb sirh' > groupes-$(date +%F).sql
```

Le socle, lui, n'a pas besoin d'être sauvegardé : il se régénère à l'identique.

Si un groupe perd son fork StackBlitz, on reforke le projet et on redépose son
dossier — deux minutes. C'est de facto leur gestion de versions, sans une
notion de git à leur apprendre.
