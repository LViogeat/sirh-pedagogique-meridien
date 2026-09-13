# Le socle applicatif

Vue 3 + PrimeVue, conçu pour StackBlitz. C'est le projet que les étudiants forkent.

## Démarrer

1. Renseigner `src/socle/config.js` avec l'URL et la clé `anon` du projet Supabase.
   **C'est le seul fichier à modifier pour connecter l'application.**
2. `npm install` puis `npm run dev`.

Sur StackBlitz, l'étape 2 est automatique : il ne reste que le fichier de configuration.

## Ce qu'un groupe a le droit de faire

Créer des fichiers dans **`src/modules/<son-code>/`** — et rien d'autre.

```
src/modules/rec/
  module.js          ← manifeste : code, label, icon, routes
  OffresList.vue     ← un fichier .vue = un écran
```

Ajouter une page = ajouter une ligne dans `routes` et créer le fichier.
Le menu et le routeur se mettent à jour seuls : **aucun fichier partagé n'est
jamais modifié**, ce qui rend les conflits impossibles et la fusion gratuite.

Le module `demo` est l'implémentation de référence à recopier :
`TachesList.vue` montre liste, formulaire, création, modification, suppression ;
`ExempleCoreHR.vue` montre chaque appel du SDK.

## Le SDK

```js
import { getEmployes, useTable, useSession, formatDate, toast } from '@/socle/sdk'
```

Les composants PrimeVue (`<DataTable>`, `<Dialog>`…) et ceux du socle
(`<PageHeader>`, `<StatCard>`, `<EmployeSelect>`, `<EmployeCard>`)
s'utilisent **sans import** : ils sont enregistrés globalement.

L'antisèche complète : [`../docs/04-sdk.md`](../docs/04-sdk.md).

## Deux points d'attention

**PrimeVue est verrouillé en 4.5.x.** La version 5 est passée sous licence
commerciale et affiche un bandeau « Invalid PrimeUI License » sur chaque écran.
Les versions sont donc épinglées avec `~` : ne pas les faire monter de majeure.

**L'overlay d'erreur de Vite est désactivé** (`vite.config.js`). Il recouvrait
toute l'application, menu compris. Une erreur s'affiche désormais dans l'écran
concerné, avec le détail technique à coller à l'IA — et le reste du SIRH
continue de fonctionner.

## Structure

```
src/
  socle/            jamais modifié par les étudiants
    config.js       ← l'URL et la clé Supabase
    sdk.js          ← le point d'entrée unique
    corehr.js       lecture du référentiel
    useTable.js     CRUD sur les tables du module
    session.js      compte réel + profil RH simulé
    modules.js      auto-découverte des manifestes
    router.js       routes construites depuis les manifestes
    composants/     shell, connexion, barrière d'erreur, composants partagés
  corehr/           les écrans du référentiel
  modules/          un dossier par groupe
```
