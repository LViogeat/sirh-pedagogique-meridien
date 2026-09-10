# Le SDK — l'antisèche

*SIRH pédagogique — Master SIRH, Université Paris 1 Panthéon-Sorbonne*

> **Spécification** de la surface que le socle exposera (phase 2). C'est aussi, mot pour mot, le contenu du kit de prompts : une IA à qui l'on donne cette page ne peut quasiment plus inventer de code faux.

Les étudiants n'écrivent **ni SQL, ni appel Supabase**. Douze fonctions et quatre composants suffisent.

---

## Lire le référentiel

```js
import { getEmployes, getEmploye, getServices, getPostes,
         getEtablissements, getRef } from '@/socle/sdk'
```

### `getEmployes(filtres?)` → `Employe[]`

Les salariés présents aujourd'hui. Tous les filtres sont facultatifs et se combinent.

```js
const tous     = await getEmployes()
const duSvc    = await getEmployes({ serviceId: 12 })
const lesCDD   = await getEmployes({ typeContrat: 'CDD' })
const trouves  = await getEmployes({ recherche: 'martin' })   // nom, prénom ou matricule
```

Chaque `Employe` contient :

| | | |
|---|---|---|
| `personne_id` | `matricule` | `civilite_code` |
| `nom` | `prenom` | `nom_complet` |
| `date_naissance` | `age` | `email_pro` |
| `telephone` | `ville` | |
| `type_contrat_code` | `type_contrat` | `date_debut_contrat` |
| `date_fin_prevue` | `etp` | `salaire_base_brut_mensuel` |
| `csp_code` | `csp` | `classification` · `coefficient` |
| `nb_avenants` | `date_dernier_avenant` | `date_derniere_augmentation` |
| `etablissement_id` | `etablissement` | |
| `service_id` | `service` | |
| `emploi_id` | `emploi` | `famille_metier` · `poste_id` |
| `manager_id` | `manager` | |
| `date_entree` | `anciennete_mois` | |

> **`date_entree`** est le début du **plus ancien** contrat de la personne, pas celui du contrat en cours. Un salarié passé par un stage avant son CDI a donc une ancienneté supérieure à la durée de son contrat actuel. C'est voulu, et il y a un cas dans le jeu de données.
>
> **Le salaire et l'ETP ne sont pas stockés sur le contrat.** Ils viennent du dernier *avenant* dont la date d'effet est passée — une augmentation, un passage à temps partiel et une promotion sont des avenants datés. La vue fait ce calcul pour vous ; vous lisez simplement `salaire_base_brut_mensuel` et `etp`.

### `getEmploye(id)` → `Employe & { contrats, affectations }`

Un salarié, avec **tout son historique** — la seule fonction qui donne accès aux contrats et affectations successifs.

### `getHistoriqueRemuneration(personneId)` → `Avenant[]`

La carrière salariale, avenant par avenant : contrat initial, augmentations, promotions, changements de temps de travail.

```js
const carriere = await getHistoriqueRemuneration(42)
// [ { numero_ordre: 1, type_avenant: 'Contrat initial',
//     date_effet: '2018-09-03', etp: 1, salaire: 2410.00,
//     salaire_precedent: null, evolution_pct: null, ... },
//   { numero_ordre: 2, type_avenant: 'Augmentation individuelle',
//     date_effet: '2021-02-01', salaire: 2494.35, evolution_pct: 3.50, ... } ]
```

C'est le matériau des campagnes d'augmentation et des budgets. `evolution_pct` est déjà calculé.

### Les autres

```js
await getServices()          // { id, code, service, type_unite, parent_id, parent,
                             //   etablissement, responsable, effectif }
await getPostes()            // { id, code, libelle, emploi, service, etp_budgete, ouvert }
await getPostes({ vacants: true })   // les postes ouverts non pourvus
await getEtablissements()    // { id, code, nom, ville }
await getRef('type_contrat') // { code, libelle }[] — trié
```

`getRef` accepte : `civilite`, `type_contrat`, `motif_cdd`, `motif_sortie`, `csp`, `type_avenant`.

> **Une donnée qui manque est une demande d'évolution, pas une jointure.** Si votre module a besoin d'une information du référentiel absente de cette liste, rédigez une demande. On ne contourne pas le contrat d'interface.

---

## Les données de votre module

### `useTable(nom)`

Le CRUD complet sur une de vos tables. Le préfixe de votre module est ajouté automatiquement : pour le groupe `rec`, `useTable('offres')` travaille sur `rec_offres`.

```vue
<script setup>
import { useTable } from '@/socle/sdk'

const offres = useTable('offres')
</script>

<template>
  <DataTable :value="offres.rows" :loading="offres.loading" paginator :rows="10">
    <Column field="intitule" header="Intitulé" sortable />
    <Column field="statut"   header="Statut"   sortable />
  </DataTable>
</template>
```

Ce que `useTable` renvoie :

| | |
|---|---|
| `rows` | les lignes, réactives, chargées automatiquement |
| `loading` | `true` pendant le chargement |
| `error` | message d'erreur lisible, ou `null` |
| `create(objet)` | insère et rafraîchit |
| `update(id, objet)` | met à jour et rafraîchit |
| `remove(id)` | supprime et rafraîchit |
| `refresh()` | recharge |

```js
await offres.create({ intitule: 'Développeur H/F', poste_id: 42, statut: 'brouillon' })
await offres.update(3, { statut: 'publiee' })
await offres.remove(7)
```

Vous pouvez **lire** les tables d'un autre module (`useTable('gta_absences', { lectureSeule: true })`) — c'est ainsi que les modules s'intègrent. Vous ne pouvez pas y écrire : la base refuse.

---

## Le contexte

### `useSession()`

```js
const { utilisateur, module, profilRH, employe, equipe } = useSession()
```

**Deux axes de rôles, à ne pas confondre :**

| | | |
|---|---|---|
| `module` | **réel**, issu de votre compte (`'rec'`, `'gta'`…) | détermine vos droits d'écriture **en base** |
| `profilRH` | **simulé**, choisi dans la barre du haut : `'RH'`, `'MANAGER'`, `'SALARIE'` | détermine ce que votre écran **affiche** |

`profilRH` n'a **aucun** effet sur les droits. C'est un outil de conception : *« qu'est-ce qu'un manager doit voir, au juste ? »* — à vous d'en décider et de le coder.

`employe` est le salarié auquel le profil simulé correspond ; `equipe` est la liste de ceux qui l'ont pour manager.

```js
const visibles = profilRH === 'RH'      ? await getEmployes()
               : profilRH === 'MANAGER' ? equipe
               :                          [employe]
```

---

## Les composants

```vue
<EmployeSelect v-model="form.personne_id" label="Salarié concerné" />
<EmployeCard   :id="form.personne_id" />
<PageHeader    titre="Offres d'emploi" sous-titre="Recrutement">
  <Button label="Nouvelle offre" icon="pi pi-plus" @click="ouvrir" />
</PageHeader>
<StatCard      titre="Offres ouvertes" :valeur="12" icone="pi pi-briefcase" />
```

`EmployeSelect` est de loin le plus réutilisé : autocomplétion sur les 179 salariés, renvoie un `personne_id`. **Utilisez-le partout où votre module désigne une personne** — n'écrivez jamais un nom en clair dans vos tables, stockez le `personne_id`.

---

## Les formats

```js
formatDate(d)          // 2026-03-14        → 14/03/2026
formatDate(d, 'long')  //                   → 14 mars 2026
anciennete(mois)       // 79                → 6 ans et 7 mois
formatEuro(n)          // 2450.5            → 2 450,50 €
toast.succes('Offre enregistrée')
toast.erreur('La date de fin doit suivre la date de début')
```

---

## Les cinq règles

1. **Un fichier `.vue` = un écran.** Demandez toujours le fichier complet à l'IA, jamais un fragment.
2. **Travaillez uniquement dans `src/modules/<votre-code>/`.**
3. **N'écrivez jamais un nom de personne dans vos tables** — stockez le `personne_id`.
4. **Le Core HR est en lecture seule.** Toute tentative d'écriture sera refusée par la base.
5. **Une donnée manquante est une demande d'évolution**, pas un contournement.

---

## Ce qui n'existe pas et qu'une IA pourrait inventer

Une IA qui ne connaît pas ce SDK proposera spontanément du code qui ne marchera pas ici. Si vous voyez apparaître l'un de ces éléments, **c'est le signe que l'IA a perdu le contexte** — recollez-lui le kit de prompts.

- `supabase.from(...)`, `createClient(...)`, une clé d'API, un `fetch` ou un `axios`
- `import { ref } from 'vue'` pour recharger des données à la main *(c'est le rôle de `useTable`)*
- un `<router-link>` ou une modification de `router.js` *(la navigation est déduite du manifeste)*
- du SQL, un `select`, une jointure
- l'Options API (`export default { data() { ... } }`) — ce projet est en `<script setup>`
- des composants qui ne sont pas de PrimeVue
