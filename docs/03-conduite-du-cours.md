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

## 3. Avant chaque séance

Les séances : **5 octobre** (théorie, fait), **lundi 16 novembre**,
**lundi 14 décembre 2026**. Les six groupes ont leur branche, leur tableau,
leur formulaire de story et leur kit Copilot.

### J-7 — le test qui conditionne tout

**Depuis un poste de l'université**, pas depuis chez vous, et **avec un compte
étudiant** pour Copilot :

| À vérifier | Comment |
|---|---|
| StackBlitz n'est pas filtré | ouvrir le lien de la branche `recruitment`, lancer `npm install` |
| L'API n'est pas filtrée | ouvrir `https://sirh-api.govetia.com/docs` |
| StackBlitz commite sur la branche | connecté avec un compte GitHub invité : modifier un fichier, *Commit*, vérifier le commit sur GitHub |
| **Le `.env` ne part pas dans le commit** | dans le commit de test, seul le fichier modifié doit apparaître — sinon le jeton est public |
| Deux commits ne s'écrasent pas | deux StackBlitz ouverts sur la même branche, chacun modifie un fichier différent et commite : les deux modifications doivent rester |
| Copilot accepte le kit en pièce jointe | joindre `app/copilot/recruitment.md` (27 000 caractères), demander « prêt » |
| Copilot code une story | coller une story d'exemple : le fichier rendu doit s'afficher sans erreur |
| Copilot permet de créer un agent | Copilot Chat → *Agents* → *Créer un agent*. Si oui : un agent « Dev SIRH » avec les instructions du kit, et le kit en connaissance |

Si l'un des quatre premiers échoue, c'est l'environnement qu'il faut revoir,
pas l'architecture. Prévoyez le repli : GitHub Codespaces à la place de
StackBlitz, Claude.ai ou Le Chat à la place de Copilot.

### J-7 — GitHub

Une fois les identifiants GitHub des étudiants reçus, dans un
`comptes-github.csv` à la racine (ignoré par git) :

```
identifiant-github,branche
lea-meyer,recruitment
tom-dupont,time-and-attendance
```

```bash
gh auth refresh -h github.com -s project # une fois, dans un vrai terminal : le droit de créer les tableaux
bash scripts/github-setup.sh comptes-github.csv
```

Le script crée les étiquettes, les branches des groupes depuis `main`, les
protections (`main` n'est modifiable que par vous ; les branches des groupes
ne peuvent être ni supprimées ni réécrites), envoie les invitations et crée le
**un tableau par groupe** — son backlog et ses sprints, que le groupe tient
lui-même : ses membres y ont le droit d'écriture, et sur le sien seulement.
Les tableaux portent les numéros 2 (Recrutement), 3 (Gestion des temps et
activités), 4 (Formation), 5 (Mobilité & carrière), 6 (Portail RH) et
7 (Onboarding), sous `https://github.com/users/LViogeat/projects/<n°>`. Pour
un nouveau tableau, le script affiche à la fin les deux réglages à faire à la
main. Il se relance sans risque : chaque nouvel étudiant, on
l'ajoute au CSV et on relance.

**Les étudiants doivent accepter l'invitation** avant de pouvoir commiter.
Faites-le faire en début de séance, c'est la première panne du jour sinon.

### J-1 — caler la date de référence, changer les jetons

Tout le jeu de données est calculé à partir de `DATE_REFERENCE` : ancienneté,
contrats arrivant à échéance « sous trois mois », campagne d'entretiens en
cours. Le socle ne lit jamais l'horloge.

**Réglez-la sur le 16 novembre, et gardez-la pour le 14 décembre.** Avec la
même date, les données sont identiques aux deux séances : un critère
d'acceptation écrit en novembre (« l'écran affiche 27 besoins ») est encore
vrai en décembre. La changer entre les deux casserait toutes les recettes.

```bash
ssh sweet-waters-prod 'bash -s' -- 2026-11-16 rec gta < scripts/preparer-session.sh
```

Le script sauvegarde `/opt/sirh/.env`, cale la date, donne un nouveau jeton
aux groupes cités (ici `rec` et `gta`), redémarre l'API et remet le socle à
zéro. Ne citez des groupes que pour la première séance : en décembre, on
relance avec la date seule, et les jetons ne bougent pas.

Imprimez ensuite les fiches, qui portent les nouveaux jetons :

```bash
ssh sweet-waters-prod 'bash -s' < scripts/fiches-groupes.sh
```

Vérifier enfin que la matière est suffisante :

```bash
curl -s "https://sirh-api.govetia.com/besoins?statut=ouvert" \
     -H "Authorization: Bearer $JETON_REC" | grep -o '"need_type":"[a-z]*"' | sort | uniq -c
```

Comptez une quinzaine de besoins ouverts minimum par type consommé. Si un
groupe en manque, ajustez son seuil dans `api/socle/rules/seuils.py`, poussez,
et rejouez `/admin/besoins/generer`.

### Le matin de la séance

1. `curl https://sirh-api.govetia.com/` répond.
2. Les fiches sont distribuées.
3. Un StackBlitz de test, ouvert sur une branche de groupe, affiche l'écran **Besoins identifiés** avec des
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

### En-tête 0 — le kit, par défaut

`app/copilot/<branche>.md` contient tout : les règles, le SDK, le contrat et un
écran modèle. Il est **assemblé à partir du code** par
`bash scripts/kit-copilot.sh` : relancez-le et commitez dès que le SDK, le
contrat ou l'écran modèle changent.

Premier message : le kit en pièce jointe, et « Lis-le, puis réponds seulement
prêt ». Second message : la story copiée depuis GitHub, et leur `module.js`.
Le kit demande à Copilot de rendre le `.vue` **et** le `module.js` complets.

Les en-têtes A, B et C ci-dessous sont le repli, si leur Copilot refuse la
pièce jointe.

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

Environ une heure. À chaque sprint, le rôle de PO tourne : **le PO du sprint
est celui qui vous fait la démo**, et c'est lui qui a cadré ce qu'on livre.

| | |
|---|---|
| **~10 min** — cadrage | le PO choisit les stories du sprint dans le tableau du groupe, chacune assignée à quelqu'un |
| **~30 min** — production | conception, prompts, collage, essais |
| **~5 min** — recette | on vérifie sur le jeu de données, on note ce qui cloche |
| **~20 min** — passage groupe par groupe | vous passez devant chaque groupe, un par un : démo par le PO, puis rétro, trois minutes environ. Le PO la consigne dans un ticket « Rétro de sprint » |

C'est ce passage qui fixe la durée réelle d'un sprint. Avec six groupes, il
prend vingt minutes ; mieux vaut raccourcir la production que sauter un groupe.

La recette est la partie qu'on sacrifie quand on est en retard, et c'est
justement celle qui a le plus de valeur : le jeu de données étant déterministe,
un groupe peut écrire « l'écran doit afficher 12 besoins de formation ouverts à
Lyon » **avant** de coder, puis vérifier.

---

## 6. Le déroulé des trois jours

### Jour 1 — 5 octobre : la théorie

Fait. Aucun code : théorie agile et présentation du projet.

### Jour 2 — 16 novembre : le sprint 0, puis les premiers sprints

Le sprint 0 ouvre la journée. Il ne produit aucun écran, il installe les
postes et les outils :

1. chacun accepte son invitation GitHub (envoyée à J-7) ;
2. chacun se connecte à StackBlitz avec GitHub et ouvre la branche de son
   groupe, crée son `app/.env` à partir de la fiche, lance `npm install` puis
   `npm run dev` ;
3. le groupe ouvre sa première story dans GitHub, avec le formulaire de son
   groupe, même incomplète.

**Livrable** : sur chaque poste, l'écran **Besoins identifiés** affiche des
lignes et le module du groupe porte l'étiquette « votre groupe » ; chaque
groupe a au moins une story dans son tableau.

**Vous** : le passage groupe par groupe sert ici à vérifier chaque poste. En
clôture, chaque groupe désigne son PO du premier sprint.

### Jours 2 et 3 — environ cinq sprints par jour

Les étapes ci-dessous ne sont pas des sprints : chacune en occupe un ou
plusieurs, selon l'avancée du groupe. L'ordre compte : lire avant d'écrire,
écrire chez soi avant de toucher au socle, et l'intégration en dernier.

### Étape 1 — comprendre et modéliser

*Ils ne codent pas d'écran.* Ils parcourent le socle : salariés, postes,
entretiens, besoins. Ils en déduisent ce que leur module doit savoir faire,
puis écrivent leur modèle de données et l'exécutent dans la Console SQL.

**Livrable** : leur `schema.sql`, exécuté sans erreur, et leur `module.js`
présent — le module apparaît dans le menu.

**Vous** : rien. Vous circulez et vous posez une seule question à chaque
groupe : *« à quelle question métier cette table répond-elle ? »*

### Étape 2 — le premier écran, en lecture

Un écran qui lit le socle et affiche une liste filtrable. C'est la duplication
de `BesoinsList.vue`, et c'est l'étape où ils apprennent l'en-tête A.

**Livrable** : un écran dans leur menu, qui affiche de vraies données.

### Étape 3 — écrire chez soi

Créer, modifier, supprimer dans leurs propres tables. Un formulaire, une boîte
de dialogue, une liste qui se rafraîchit.

**Livrable** : une donnée saisie en salle, qui survit à un rechargement.

### Étape 4 — consommer les besoins

Pour Recrutement, Formation et Mobilité : lire les besoins de leur type, en
prendre un en charge, le traiter, le clôturer. Pour GTA, Portail RH et
Onboarding : croiser deux sources du socle — salariés et contrats, hiérarchie
managériale, arrivées et départs.

**Livrable** : un besoin passé de `ouvert` à `cloture`, visible depuis l'écran
du socle par toute la classe.

**Vous** : c'est le moment de relancer `/admin/besoins/generer` si un groupe
manque de matière.

### Étape 5 — intégration

Chaque groupe lit les tables d'un autre. Le module Formation affiche les
candidats recrutés, Mobilité montre les formations suivies.

**Livrable** : un écran qui joint le schéma d'un autre groupe au sien.

### Les deux grandes démos

Une en fin de jour 2, une en fin de jour 3, devant la classe : chaque PO
présente son module, cinq à six minutes par groupe.

**Juste avant une démo, fusionnez les branches dans `main`**, pour montrer le
SIRH assemblé depuis un seul StackBlitz :

```bash
git fetch origin
git switch main && git pull
git merge --no-ff origin/recruitment -m "Démo : module Recrutement"
git merge --no-ff origin/time-and-attendance -m "Démo : module Gestion des temps et activités"
git merge --no-ff origin/training -m "Démo : module Formation"
git merge --no-ff origin/career-and-mobility -m "Démo : module Mobilité & carrière"
git merge --no-ff origin/employee-self-service -m "Démo : module Portail RH & Self-Service"
git merge --no-ff origin/onboarding-and-offboarding -m "Démo : module Onboarding & Offboarding"
git push
```

Il n'y a pas de conflit possible : chaque groupe n'écrit que dans
`app/src/modules/<code>/`. Pour la démo, le `.env` du StackBlitz de démo prend
le code du module à ouvrir — un seul module est ouvrable à la fois, c'est le
principe du socle.

**La démonstration finale**, au jour 3, suit la chaîne, pas les groupes : un
entretien annuel → le besoin qu'il a produit → le module qui l'a traité → la
trace dans le socle. Six modules, un seul récit.

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
| « Il manque votre fichier de configuration » | pas de `app/.env` | leur fiche, section 2 |
| `Could not read package.json` | ils sont dans le mauvais dossier | `npm install` marche depuis la racine ou `app/` — sinon ils ont une version du dépôt antérieure au 15/09 |
| Le `.env` est créé mais rien ne change | Vite lit `.env` au démarrage | relancer `npm run dev` |
| `Jeton inconnu` | jeton mal recopié | comparer à la fiche, attention aux espaces |
| `L'API ne répond pas` | réseau, ou API arrêtée | `curl $API/` depuis votre poste |
| `permission denied for table …` | ils écrivent hors de leur schéma | c'est le cours : la base arbitre |
| `relation "…" does not exist` | la table n'a pas été créée | Console SQL |
| `Ce besoin est de type « … »` | ils prennent le besoin d'un autre | chaque module ne traite que son type |
| L'écran affiche « n'a pas pu être chargé » | erreur de syntaxe dans leur `.vue` | console du navigateur, puis en-tête C |
| Le module d'un autre groupe est grisé | c'est voulu | un groupe, un module |
| StackBlitz propose *Fork* au lieu de *Commit* | invitation GitHub pas acceptée, ou StackBlitz pas connecté avec GitHub | `github.com/LViogeat/sirh-pedagogique-meridien/invitations`, puis se reconnecter |
| Commit refusé sur `main` | ils ont ouvert le lien de `main`, pas celui de leur branche | rouvrir le lien de leur fiche ; recoller les fichiers |
| Le travail d'un camarade a disparu après un commit | deux StackBlitz anciens sur la même branche | `git log` sur GitHub : le fichier est dans le commit précédent. Rappeler : rouvrir le lien avant chaque story |
| Copilot rend un fichier qui importe `axios` ou appelle `fetch` | le kit n'a pas été joint | nouvelle conversation, kit d'abord |

Aucune de ces pannes ne demande d'intervenir sur le serveur. Si vous devez y
toucher pendant un sprint, c'est le signe que quelque chose n'a pas été prévu —
notez-le pour l'édition suivante.

---

## 9. Fin de journée

**Non négociable**, et c'est ce qui protège une journée de travail :

1. Chaque groupe a **commité** tout ce qui marche, `schema.sql` compris
   (dans `app/src/modules/<code>/`). Vérifiez-le sur GitHub, dans la liste
   des branches : la date du dernier commit doit être celle du jour.
2. Sauvegarde des schémas des groupes :

```bash
ssh <serveur> 'docker exec sirh-db-1 pg_dump -U sirh \
  -n rec -n form -n mob -n gta -n portail -n onb sirh' > groupes-$(date +%F).sql
```

Le socle, lui, n'a pas besoin d'être sauvegardé : il se régénère à l'identique.

Si un groupe perd son StackBlitz, il rouvre le lien de sa branche : tout ce
qui a été commité est là. Ce qui ne l'a pas été est perdu — c'est la leçon,
et elle ne s'oublie pas.

---

## 10. Suivre qui fait quoi

Chaque étudiant commite depuis son propre compte, et chaque story a un
assigné : la contribution de chacun se lit dans GitHub, sans rien demander.

```bash
git fetch origin

# Les commits de chacun, sur la branche d'un groupe
git shortlog -sn main..origin/recruitment

# Le détail : qui, quand, quoi
git log main..origin/recruitment --format='%an · %ad · %s' --date=format:'%d/%m %H:%M'

# Les stories : qui les a écrites, qui les a prises, où elles en sont
gh issue list --label recruitment --state all --limit 100 \
   --json number,title,author,assignees,state \
   --jq '.[] | "#\(.number) \(.state) · écrite par \(.author.login) · prise par \([.assignees[].login] | join(", ")) · \(.title)"'
```

Sur GitHub, l'onglet *Insights → Contributors* donne la même chose en
graphique, et le tableau de chaque groupe, groupé par *Assignees*, montre qui porte
quoi à tout moment.

Un étudiant sans commit ni story n'a pas forcément rien fait — il a pu
écrire les critères ou faire la recette. Le ticket de rétro dit qui était PO
de chaque sprint : c'est la troisième trace.

### Ajouter un groupe

Les six modules du socle sont ouverts. Si un jour il en faut un septième, ou
qu'on renomme une branche :

1. ajouter sa ligne dans `GROUPES` de `scripts/github-setup.sh`,
   `scripts/kit-copilot.sh` et `branche_de` de `scripts/fiches-groupes.sh` ;
2. copier un formulaire `.github/ISSUE_TEMPLATE/story-*.yml` et adapter les
   données cochables ;
3. ajouter le groupe aux menus déroulants de `bug.yml` et `retro.yml` ;
4. relancer `kit-copilot.sh` puis `github-setup.sh`, commiter.
