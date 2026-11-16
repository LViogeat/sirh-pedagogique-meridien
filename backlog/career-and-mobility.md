# Mobilité & carrière — backlog et sprints

Copie des Issues et du tableau GitHub Projects n°5 (https://github.com/users/LViogeat/projects/5), branche `career-and-mobility`.
Généré le 2026-11-16 par `scripts/export-backlog.sh` — la source de vérité reste GitHub.

**15 stories**

## Sommaire

- #15 [Mobilité] Souhaits d'évolution — Sprint 1 · Todo
- #49 [Mobilité] Besoins de mobilité — Sprint 1 · Todo
- #69 [Mobilité] Opportunités de postes — Sprint 1 · Todo
- #126 [Mobilité]   Dossiers de mobilité — Sprint 1 · Todo
- #78 [Mobilité] Échanges avec le salarié  — Sprint 2 · Todo
- #79 [Mobilité]  Prise en charge des besoins — Sprint 2 · Todo
- #83 [Mobilité] Fiche carrière — Sprint 2 · Todo
- #84 [Mobilité] Propositions de postes — Sprint 2 · Todo
- #82 [Mobilité]  Clôturer des dossiers — Sprint 3 · Todo
- #94 [Mobilité] Adéquation au poste visé — Sprint 3 · Todo
- #96 [@Mobilité] Tableau de bord — Sprint 3 · Todo
- #125 [Mobilité] Mobilités réalisées — Sprint 3 · Todo
- #54 [Mobilité]  Analyser les besoins de mobilité — sans sprint · sans statut
- #66 [Mobilité] Analyser les données salariés et entretiens — sans sprint · sans statut
- #85 [Mobilité] Prendre en charge et relâcher un besoin — sans sprint · sans statut

## Sprint 1

### #15 [Mobilité] Souhaits d'évolution

- Statut : Todo · issue ouverte
- Assignée à : @LDY03
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/15

### La story 

En tant que conseiller RH, je veux voir les souhaits d'évolution exprimés en entretien afin de comprendre ce que demandent les salariés.

### Comment je saurai que c'est bon

- Je vois chaque souhait (getAspirations()) : le salarié, le type de souhait, le poste visé, l'hôtel visé et le commentaire.
- Je peux filtrer par type de souhait et par hôtel.
- Quand je clique sur un souhait, je vois l'entretien d'origine (getEntretien(review_id)) : la date, le manager, les objectifs avec leur taux d'atteinte, et le taux moyen.
- Le taux moyen est en vert à partir de 70 %, le seuil qui déclenche un besoin de mobilité.

### #49 [Mobilité] Besoins de mobilité

- Statut : Todo · issue ouverte
- Assignée à : @marwaibr23-tech
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/49

### La story

En tant que conseiller RH, je veux voir la liste des besoins de mobilité afin de savoir quels salariés accompagner..


### Comment je saurai que c'est bon

- Je vois les besoins de type mobilité (getBesoins({ typeBesoin: 'mobilite' })) : le salarié et son matricule, le poste visé, l'hôtel visé, la priorité en badge, l'origine, la date de détection et le statut.
- Je peux filtrer par hôtel, par priorité et par statut (« ouvert » par défaut), et chercher un salarié par son nom.
- Les priorités hautes sont en haut de la liste.
- En haut de l'écran, je vois le nombre de besoins ouverts.
- Quand je clique sur une ligne, je vois le détail du besoin dans une boîte de dialogue.

### #69 [Mobilité] Opportunités de postes

- Statut : Todo · issue ouverte
- Assignée à : @Nicx0-x
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/69

### La story

En tant que conseiller RH, je veux voir les postes à pourvoir dans la chaîne afin de repérer les opportunités de mobilité interne.

### Comment je saurai que c'est bon

•⁠  ⁠Je vois les postes (⁠ getPostes ⁠) : l'intitulé, la famille, le niveau hiérarchique, le département, l'hôtel, l'effectif cible, l'effectif réel et les places à pourvoir.
•⁠  ⁠Un interrupteur « Seulement les postes à pourvoir » est activé par défaut.
•⁠  ⁠Je peux filtrer par hôtel, par famille de métier et par niveau.
•⁠  ⁠Quand je clique sur un poste, je vois ses compétences attendues (⁠ getPoste(id) ⁠).

### #126 [Mobilité]   Dossiers de mobilité

- Statut : Todo · issue ouverte
- Assignée à : @angemer95
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/126

### La story

En tant que conseiller RH, je veux voir la liste des dossiers de mobilité afin de suivre où en est chaque accompagnement.


### Comment je saurai que c'est bon

	•	Je vois les dossiers de la table dossiers, avec le nom du salarié, le poste visé et l'hôtel visé. Ces informations viennent d'une jointure avec public.identified_needs, public.employees, public.positions et public.establishments.
	•	Je vois l'étape en badge, le conseiller, la date d'ouverture et le nombre de jours écoulés depuis l'ouverture, calculé à partir de getDateReference().
	•	Je peux filtrer par étape. Les dossiers terminés sont masqués par défaut.
	•	S'il n'y a aucun dossier, je vois : « Aucun dossier : prenez en charge un besoin depuis l'écran Prise en charge ».

## Sprint 2

### #78 [Mobilité] Échanges avec le salarié 

- Statut : Todo · issue ouverte
- Assignée à : @angemer95
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/78

### La story

En tant que conseiller RH, je veux noter mes échanges avec le salarié afin de garder une trace de l'accompagnement.

### Comment je saurai que c'est bon

Je choisis un dossier.
	•	J'enregistre un échange : la date (date de référence par défaut), le type (entretien de carrière, appel ou mail) et le compte rendu.
	•	Je vois l'historique des échanges du dossier, le plus récent en haut.
	•	Un échange de type « entretien de carrière » fait passer le dossier de l'étape « propositions » à l'étape « entretien ». Une étape ne recule jamais.
	•	Un dossier terminé reste consultable, mais je ne peux plus y ajouter d'échange.

### #79 [Mobilité]  Prise en charge des besoins

- Statut : Todo · issue ouverte
- Assignée à : @marwaibr23-tech
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/79

### La story

En tant que conseiller RH, je veux prendre en charge un besoin de mobilité afin d'ouvrir le dossier du salarié


### Comment je saurai que c'est bon

- Je vois les besoins de mobilité ouverts, et ceux déjà pris en charge par notre module.
- Sur un besoin ouvert, le bouton « Prendre en charge » me demande mon nom et un commentaire. Ensuite :
  1. il appelle prendreEnChargeBesoin(id, commentaire) ;
  2. il crée une ligne dans dossiers avec besoin_id, employee_id, le conseiller, l'étape « analyse » et la date d'ouverture (ouvert_le) égale à la date de référence.
- Si un dossier existe déjà pour ce besoin, il n'est pas recréé.
- Sur un besoin pris en charge dont le dossier est encore à l'étape « analyse », le bouton « Relâcher » appelle relacherBesoin(id) et supprime le dossier.
- Si l'API refuse, je vois son message et rien n'est créé

### #83 [Mobilité] Fiche carrière

- Statut : Todo · issue ouverte
- Assignée à : @LDY03
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/83

### La story

En tant que conseiller RH, 
je veux consulter la fiche carrière d'un salarié afin de préparer son entretien de mobilité.


### Comment je saurai que c'est bon

- Première ligne du fichier : <!-- libelle: Fiche carrière -->.
  - Une liste déroulante propose les salariés qui ont un besoin de mobilité.
  - Choisir un salarié affiche les blocs suivants :
    - Identité : poste et hôtel actuels, manager, contrat, anciennete().
    - Parcours contractuel, le plus récent en haut.
    - Dernier entretien, via getEntretien(review_id) : synthèse et taux moyen.
    - Objectifs, avec leur taux d'atteinte.
    - Compétences : niveau constaté, niveau attendu, écart.
    - Souhait d'évolution.
    - Poste visé, via getPoste(position_id).
  - Cas particuliers : « Souhait non précisé » s'il n'y a pas de poste visé, « Besoin non pris en charge » s'il n'y a pas de dossier.
  - L'écran ne fait que lire.

### #84 [Mobilité] Propositions de postes

- Statut : Todo · issue ouverte
- Assignée à : @Nicx0-x
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/84

### La story

En tant que conseiller RH, je veux proposer des postes à un salarié afin de lui ouvrir des opportunités concrètes.


### Comment je saurai que c'est bon

•⁠  ⁠Je choisis un dossier en cours.
•⁠  ⁠Je vois d'abord le poste visé, avec un bouton « Proposer ce poste ».
•⁠  ⁠Je vois aussi les postes à pourvoir (⁠ getPostes({ vacants: true }) ⁠) et je peux en proposer d'autres.
•⁠  ⁠Proposer un poste crée une ligne dans ⁠ propositions ⁠. Un même poste ne peut pas être proposé deux fois au même dossier.
•⁠  ⁠Je peux marquer une proposition comme acceptée ou refusée. Le commentaire est obligatoire en cas de refus. Un dossier ne peut avoir qu'une seule proposition acceptée.
•⁠  ⁠La première proposition fait passer le dossier à l'étape « propositions ». Une proposition acceptée le fait passer à « décision ».

## Sprint 3

### #82 [Mobilité]  Clôturer des dossiers

- Statut : Todo · issue ouverte
- Assignée à : @angemer95
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/82

### La story

En tant que conseiller RH, je veux clôturer un dossier avec son issue afin de terminer l'accompagnement.

### Comment je saurai que c'est bon

	•	Je vois les dossiers qui ne sont pas terminés.
	•	Le bouton « Clôturer » me demande l'issue (réalisée, refusée, reportée ou abandonnée) et un commentaire. Les deux sont obligatoires.
	•	L'issue « Réalisée » n'est possible que si une proposition a été acceptée. Le poste et l'hôtel d'arrivée sont alors préremplis avec cette proposition, et je saisis la date d'effet.
	•	La validation fait trois choses, dans cet ordre :
	1.	elle appelle cloturerBesoin(besoin_id, commentaire) ;
	2.	elle passe le dossier à « terminé », avec l'issue et la date de clôture (date de référence) ;
	3.	si la mobilité est réalisée, elle crée une ligne dans mobilites, avec le poste actuel du salarié (getSalarie) comme poste de départ.
	•	Si l'API refuse, rien n'est modifié dans nos tables.

### #94 [Mobilité] Adéquation au poste visé

- Statut : Todo · issue ouverte
- Assignée à : @LDY03
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/94

### La story

En tant que conseiller RH, 
je veux noter mes échanges avec le salarié 
afin de garder une trace de l'accompagnement.

### Comment je saurai que c'est bon

 - Première ligne du fichier : <!-- libelle: Échanges -->.
  - Une liste déroulante propose les dossiers.
  - Un formulaire enregistre la date (aujourd'hui par défaut), le type (entretien de carrière, appel ou mail) et le compte rendu, avec insert('echanges', …).
  - L'historique du dossier s'affiche, le plus récent en haut.
  - Un dossier terminé est consultable mais ne reçoit plus de nouvel échange.

### #96 [@Mobilité] Tableau de bord

- Statut : Todo · issue ouverte
- Assignée à : @Nicx0-x
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/96

### La story

En tant que DRH, je veux un tableau de bord de la mobilité afin de piloter l'activité par hôtel.


### Comment je saurai que c'est bon

•⁠  ⁠Je vois 4 chiffres clés, chacun dans une ⁠ StatCard ⁠ : les besoins de mobilité ouverts, les dossiers en cours, le délai moyen de traitement en jours et le taux de mobilités réalisées.
•⁠  ⁠Je vois un tableau par hôtel : besoins détectés, pris en charge, clôturés, et mobilités réalisées.
•⁠  ⁠Je vois combien de dossiers sont à chaque étape.
•⁠  ⁠Quand les tables sont vides, je vois 0 partout, sans erreur.

### #125 [Mobilité] Mobilités réalisées

- Statut : Todo · issue ouverte
- Assignée à : @marwaibr23-tech
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/125

### La story

En tant que DRH, je veux voir les mobilités réalisées afin de mesurer ce que le module a permis.


### Comment je saurai que c'est bon

- Je vois chaque mobilité de la table mobilites : le salarié, le poste et l'hôtel de départ, le poste et l'hôtel d'arrivée, et la date d'effet.
- Je peux filtrer par hôtel d'arrivée.
- Quand je clique sur une mobilité, je vois le dossier correspondant : le conseiller, la durée de l'accompagnement, les propositions faites et les échanges

## Backlog (sans sprint)

### #54 [Mobilité]  Analyser les besoins de mobilité

- Statut : sans statut · issue ouverte
- Assignée à : @marwaibr23-tech
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/54

### La story

En tant qu'équipe RH, je veux connaître les besoins mobilite existants afin de construire l'écran Besoins et de choisir notre cas de démo.


### Comment je saurai que c'est bon

Le nombre de besoins mobilite est noté, par statut et par hôtel.
  - Vérifier que position_id est bien le poste visé, en comparant avec l'aspiration du salarié.
  - Vérifier que review_id est renseigné.
  - Un cas de démo est choisi et noté : Théo Roux s'il a un besoin ouvert, sinon un autre.
  - Le résultat est noté en commentaire de l'issue.

### #66 [Mobilité] Analyser les données salariés et entretiens

- Statut : sans statut · issue ouverte
- Assignée à : @LDY03
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/66

### La story

En tant qu'équipe RH, je veux vérifier les données disponibles sur un salarié afin de préparer la fiche carrière.
 Critères :
  - Sur le salarié du cas de démo, noter ce que renvoient getSalarie (en particulier le parcours contractuel), getEntretien (objectifs, compétences, souhaits) et getAspirations.
  - Noter les champs vides ou absents.
  - Le résultat est noté en commentaire de l'issue.

### Comment je saurai que c'est bon

- La fonctionnalité sera considérée comme valide si la fonction `getSalarie` retourne correctement l'identité et l'historique complet du parcours contractuel du salarié du cas de démo.
- La fonctionnalité sera considérée comme valide si la fonction `getEntretien` permet d'accéder aux objectifs, aux compétences évaluées et aux souhaits enregistrés.
- La fonctionnalité sera considérée comme valide si la fonction `getAspirations` liste clairement les souhaits de mobilité.
- La fonctionnalité sera considérée comme valide si les champs vides ou absents sont explicitement listés et documentés en commentaire de l'issue.

### #85 [Mobilité] Prendre en charge et relâcher un besoin

- Statut : sans statut · issue ouverte
- Assignée à : @marwaibr23-tech
- Lien : https://github.com/LViogeat/sirh-pedagogique-meridien/issues/85

### La story

En tant que conseiller RH, je veux prendre en charge un besoin de mobilité afin de lancer l'accompagnement du salarié.


### Comment je saurai que c'est bon

 Le bouton « Prendre en charge » n'apparaît que sur un besoin ouvert. Il ouvre une boîte de dialogue qui demande le conseiller et un commentaire.
  - L'ordre des appels est imposé (RG2) :
    1. prendreEnChargeBesoin(id, commentaire) ;
    2. insert('dossiers', { besoin_id, employee_id, conseiller, etape: 'analyse' }) ;
    3. toast.succes, puis rafraîchissement.
  - Si un dossier existe déjà pour ce besoin, on ne le recrée pas (RG1).
  - Le bouton « Relâcher » n'apparaît que sur un besoin pris_en_charge dont le dossier est à l'étape « analyse » et sans proposition (RG4). Après confirmation : relacherBesoin(id), puis remove('dossiers', id).
  - Si l'API refuse, son message s'affiche tel quel et rien n'est écrit dans nos tables.
