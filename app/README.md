# Le front du socle

Vue 3 + PrimeVue. C'est l'application que chaque groupe fait tourner dans son
instance de code-server, et dans laquelle il ajoute son module.

```bash
npm install
npm run dev
```

## Configuration

Copiez `.env.example` en `.env`, dans ce dossier, et remplissez les deux lignes
avec ce que l'intervenant vous a remis :

```
VITE_API_TOKEN=le-jeton-de-votre-groupe
VITE_MODULE_CODE=rec
```

Puis **relancez `npm run dev`** : une variable d'environnement n'est lue qu'au
démarrage.

L'URL de l'API du cours est déjà connue de l'application. Ajoutez
`VITE_API_URL=http://localhost:8000` uniquement si vous faites tourner l'API
sur votre propre machine.

## Structure

```
src/
  socle/              ← ne jamais modifier
    sdk.js               tout ce qu'un écran a le droit d'appeler
    corehr.js            la lecture du socle
    sql.js               vos propres tables : sql, insert, update, useQuery
    api.js               le transport
    format.js            formatDate, anciennete, toast
    modules.js           découverte automatique des modules
    router.js            routes + barrière d'erreur par écran
    groupes.js           les six modules du cours : nom, périmètre, type de besoin
    composants/
      AccueilGeneral.vue   la page d'accueil du logiciel
      AccueilModule.vue    la page d'accueil de VOTRE module — fournie par le socle
      AppLayout, PageHeader, StatCard…

  corehr/             ← les écrans de référence, à lire et à copier
    BesoinsList.vue      L'ÉCRAN DE RÉFÉRENCE, commenté ligne à ligne
    SalariesList.vue     liste + recherche + filtres liés
    SalarieFiche.vue     le patron d'un écran de détail
    PostesList.vue       liste + détail en boîte de dialogue
    EntretiensList.vue   liste + détail imbriqué
    ConsoleSql.vue       votre console SQL

  modules/            ← LA SEULE ZONE ÉTUDIANTE, vide au départ
    <votre code>/
      module.js          le manifeste : le menu en découle
      schema.sql         le SQL de vos tables, pour pouvoir le rejouer
      *.vue              vos écrans
```

## Deux pages que vous n'écrivez pas

**L'accueil du logiciel** (`/accueil`) et **l'accueil de votre module**
(`/<votre code>/accueil`) sont fournis par le socle. Le second dit simplement
où vous en êtes : vos écrans, vos tables.

Toutes les autres pages de votre module sont les vôtres — il n'y en a aucune
au départ.

## Ajouter un écran

1. Créer le fichier `.vue` dans `src/modules/<votre code>/`.
2. Ajouter une ligne dans le `routes` de votre `module.js`.

Le menu et l'URL se construisent tout seuls. Rien d'autre à toucher.

## Par où commencer

Ouvrez [`src/corehr/BesoinsList.vue`](src/corehr/BesoinsList.vue). Il est
commenté section par section, et il fait tout ce que fait un écran de liste
d'un SIRH. C'est le fichier à copier dans votre chat IA quand vous demandez
le vôtre.

Le guide complet : [`../README-ETUDIANTS.md`](../README-ETUDIANTS.md).
