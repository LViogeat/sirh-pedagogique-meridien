# État de la préparation — édition 2026-27

> Où en est la préparation des séances de code, ce qui a été vérifié, et ce
> qu'il reste à faire. À tenir à jour : c'est le point de reprise quand on
> change d'ordinateur. Dernière mise à jour : **13 novembre 2026**.

## Les dates

| Séance | Contenu |
|---|---|
| 5 octobre 2026 | Théorie seule, aucun code. Miro et Whiteboard ont mal fonctionné. |
| **Lundi 16 novembre 2026** | Première séance de code |
| **Lundi 14 décembre 2026** | Seconde séance de code |

`DATE_REFERENCE` est calée sur **2026-11-16** en production, et doit **le
rester pour le 14 décembre** : les données, et donc les chiffres des critères
d'acceptation, restent les mêmes d'une séance à l'autre.

## Ce qui est en place

| Élément | État |
|---|---|
| API `https://sirh-api.govetia.com` | En ligne (VPS, alias ssh `sweet-waters-prod`, dossier `/opt/sirh`) |
| Six groupes | `rec`, `gta`, `form`, `mob`, `portail`, `onb` — un schéma PostgreSQL et un jeton chacun |
| Six branches | `recruitment`, `time-and-attendance`, `training`, `career-and-mobility`, `employee-self-service`, `onboarding-and-offboarding`, alignées sur `main`, protégées contre la suppression et la réécriture |
| `main` | Réservée à l'intervenant (règle de protection, contournement admin) |
| Six tableaux GitHub Projects | n° 2 à 7, même ordre que les branches. Champ *Sprint*, vues *Backlog* (groupée par sprint) et *Sprint en cours*, ajout automatique des tickets par étiquette |
| Formulaires de tickets | Une story par groupe, *Bug*, *Rétro*. Une story est prête quand le PO l'a relue et qu'elle tient en un écran |
| Kits Copilot | `app/copilot/<branche>.md`, régénérés par `bash scripts/kit-copilot.sh` |
| App GitHub StackBlitz | **Installée** le 13/11 sur ce seul dépôt : c'est elle qui permet *Commit & Push* depuis StackBlitz |
| Branche `test-copilot` | Jetable : contient le commit de test du 13/11. À garder pour le test avec un compte étudiant, puis à supprimer |

## Ce que les tests du 13 novembre ont établi

**Copilot M365** (compte Paris 1, *Copilot Chat (de base)*) :

- Le kit en **pièce jointe** (trombone) ne marche pas : Copilot le traite comme
  une source documentaire, ignore les consignes et rend un store Vuex au mauvais
  chemin, avec des imports inventés.
- Le kit **collé** dans le message, avec la story et `module.js` en dessous
  (environ 27 500 caractères), est accepté sans troncature. Copilot rend un
  écran conforme du premier coup : SDK seul, toasts, `formatDate`, `PageHeader`,
  `StatCard`, `module.js` dans la forme imposée.
- L'écran rendu (story « Besoins de recrutement ») tourne sans retouche :
  27 besoins, filtre par établissement juste (Bellecour → 3).

**StackBlitz :**

- Le lien `stackblitz.com/github/…/tree/<branche>/app` n'ouvre qu'une **copie
  en lecture seule** : seul *Fork* est proposé, et Cmd+S crée un fork **public,
  `.env` compris**. Le jeton du groupe est alors visible de tous.
- Le bon lien est
  `https://stackblitz.com/~/github.com/LViogeat/sirh-pedagogique-meridien/tree/<branche>` :
  mode Git, bouton *Commit & Push*, nom de la branche affiché.
- Le commit n'embarque **pas** le `.env` (vérifié sur `test-copilot`, commit
  `d9debaf`).
- Dans ce mode, le projet s'ouvre à la racine du dépôt : le `.env` se met
  **à la racine** (réglage `envDir` dans `app/vite.config.js`), plus dans `app/`.
- Il faut coller le `.vue` **avant** `module.js`, sinon l'aperçu plante le
  temps du collage. Le kit demande à Copilot de les rendre dans cet ordre.
- Le premier chargement reste parfois bloqué sur *Cloning repo from GitHub* :
  recharger la page, le second essai prend une vingtaine de secondes.
- Le npm de StackBlitz réécrit `package-lock.json`. Le lockfile de `main` est
  donc au format StackBlitz, pour que les branches ne le modifient plus.

## Ce qu'il reste à faire

### Avant le 16 novembre

1. **Comptes étudiants.** Recueillir l'identifiant GitHub de chaque étudiant
   dans `comptes-github.csv`, à la racine (jamais commité) :

   ```
   identifiant-github,branche
   alice-dupont,recruitment
   ```

   Puis : `bash scripts/github-setup.sh comptes-github.csv`. Ce script envoie
   les invitations au dépôt et donne à chacun le droit d'écrire sur le tableau
   de son groupe. Chaque étudiant doit accepter l'invitation reçue par mail.

2. **Test avec un vrai compte étudiant invité** (le seul point non vérifié) :
   - il se connecte à StackBlitz avec GitHub et accepte l'autorisation, **sans
     rien installer** ;
   - il pousse un commit sur `test-copilot`, à son nom ;
   - avec le rôle WRITER, il déplace une carte dans le tableau et choisit un
     sprint.

   Ensuite : `git push origin --delete test-copilot`.

3. **La veille (J-1)** : caler la date et **changer le jeton `rec`**. Il a été
   public une vingtaine de minutes le 13/11 dans un fork StackBlitz, supprimé
   depuis.

   ```
   ssh sweet-waters-prod 'bash -s' -- 2026-11-16 rec < scripts/preparer-session.sh
   ```

4. **Imprimer les fiches** (jetons compris, lus sur le serveur) :

   ```
   ssh sweet-waters-prod 'bash -s' < scripts/fiches-groupes.sh
   ```

5. Facultatif : dans `/opt/sirh/.env`, ligne `GROUPES`, le libellé du groupe
   `gta` est encore « Gestion des temps ». La fiche GTA en hérite.
   L'application affiche déjà « Gestion des temps et activités ».

### Avant le 14 décembre

- Relancer `preparer-session.sh` avec **la même date** (2026-11-16), et
  changer les jetons qui auraient fuité.
- Fusionner les branches dans `main` avant la démo : voir
  [`03-conduite-du-cours.md`](03-conduite-du-cours.md), section 6,
  paragraphe « Juste avant une démo ».

## Les règles à ne pas oublier

- **Ne jamais versionner un vrai jeton.** Ils vivent seulement dans
  `/opt/sirh/.env`, sur le serveur. Le jeton `rec` publié dans le README en
  novembre a été changé le 9/11.
- `comptes-github.csv`, `.env` et `etudiants.csv` sont ignorés par git : ils
  ne doivent jamais être commités.
- Tout ajout de groupe passe par `scripts/github-setup.sh`,
  `scripts/kit-copilot.sh`, `scripts/fiches-groupes.sh` et les formulaires de
  `.github/ISSUE_TEMPLATE/`.

## Reprendre sur un autre ordinateur

```bash
git clone https://github.com/LViogeat/sirh-pedagogique-meridien.git
cd sirh-pedagogique-meridien
cp .env.example .env      # à la racine ; jeton et code d'un groupe pour tester l'app
npm install && npm run dev
gh auth login && gh auth refresh -s project   # pour github-setup.sh
```

Il faut aussi l'alias ssh `sweet-waters-prod` (root sur 194.164.76.215) dans
`~/.ssh/config`, avec la clé correspondante, pour lancer les scripts serveur.
