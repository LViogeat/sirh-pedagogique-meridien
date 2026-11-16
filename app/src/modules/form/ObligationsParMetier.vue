<!-- libelle: Obligations par métier et établissement -->
<script setup>
/**
 * Story #10 — Le Responsable Formation Groupe identifie les formations
 * obligatoires applicables aux différents métiers et établissements.
 *
 * Les obligations sont définies une fois pour le groupe, dans le catalogue,
 * par famille de métier (ou pour tous les métiers). Cet écran les croise avec
 * les postes réels de chaque hôtel : on voit, établissement par
 * établissement et métier par métier, quelles formations sont obligatoires
 * et combien de salariés sont concernés.
 */
import { ref, computed, onMounted } from 'vue'
import { sql, getPostes, getEtablissements, formatNombre, toast } from '@/socle/sdk'
import { preparerSchema, TOUS_LES_METIERS, telechargerCsv } from './_donnees'

const lignes = ref([])
const etablissements = ref([])
const chargement = ref(true)

const etablissementId = ref(null)
const famille = ref(null)
const formationId = ref(null)

onMounted(async () => {
  try {
    await preparerSchema()
    etablissements.value = await getEtablissements()
    const postes = await getPostes()
    const obligations = await sql(
      `select f.id as formation_id, f.code, f.intitule, f.domaine, f.duree_heures,
              f.periodicite_mois, o.famille_metier
       from   obligations o
       join   formations f on f.id = o.formation_id
       where  f.actif
       order by f.intitule`,
    )

    // 1. Les métiers présents dans chaque établissement, avec leur effectif.
    const metiers = new Map()
    for (const p of postes) {
      const cle = `${p.establishment_id}|${p.job_family}`
      const metier = metiers.get(cle) ?? {
        establishment_id: p.establishment_id,
        etablissement: p.establishment_name,
        famille_metier: p.job_family,
        salaries: 0,
      }
      metier.salaries += p.current_headcount
      metiers.set(cle, metier)
    }

    // 2. Pour chaque métier, les formations obligatoires qui s'y appliquent.
    const resultat = []
    for (const metier of metiers.values()) {
      const dejaVues = new Set()
      for (const o of obligations) {
        const applicable =
          o.famille_metier === TOUS_LES_METIERS || o.famille_metier === metier.famille_metier
        if (!applicable || dejaVues.has(o.formation_id)) continue
        dejaVues.add(o.formation_id)
        resultat.push({
          cle: `${metier.establishment_id}|${metier.famille_metier}|${o.formation_id}`,
          ...metier,
          formation_id: o.formation_id,
          formation: o.intitule,
          domaine: o.domaine,
          duree_heures: o.duree_heures,
          periodicite_mois: o.periodicite_mois,
          pour_tous: o.famille_metier === TOUS_LES_METIERS,
        })
      }
    }
    lignes.value = resultat.sort((a, b) =>
      a.etablissement.localeCompare(b.etablissement) ||
      a.famille_metier.localeCompare(b.famille_metier) ||
      a.formation.localeCompare(b.formation))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const familles = computed(() =>
  [...new Set(lignes.value.map((l) => l.famille_metier))].sort())

const formations = computed(() => {
  const vues = new Map()
  for (const l of lignes.value) vues.set(l.formation_id, l.formation)
  return [...vues].map(([id, intitule]) => ({ id, intitule }))
    .sort((a, b) => a.intitule.localeCompare(b.intitule))
})

const visibles = computed(() =>
  lignes.value.filter((l) =>
    (!etablissementId.value || l.establishment_id === etablissementId.value) &&
    (!famille.value || l.famille_metier === famille.value) &&
    (!formationId.value || l.formation_id === formationId.value)))

const totaux = computed(() => {
  const metiers = new Map()
  for (const l of visibles.value) {
    metiers.set(`${l.establishment_id}|${l.famille_metier}`, l.salaries)
  }
  return {
    formations: new Set(visibles.value.map((l) => l.formation_id)).size,
    metiers: new Set(visibles.value.map((l) => l.famille_metier)).size,
    salaries: [...metiers.values()].reduce((t, n) => t + n, 0),
  }
})

function exporter() {
  telechargerCsv('formations-obligatoires-par-metier.csv', [
    { titre: 'Établissement', champ: 'etablissement' },
    { titre: 'Famille de métier', champ: 'famille_metier' },
    { titre: 'Formation obligatoire', champ: 'formation' },
    { titre: 'Domaine', champ: 'domaine' },
    { titre: 'Durée (h)', champ: 'duree_heures' },
    { titre: 'Recyclage (mois)', champ: (l) => l.periodicite_mois ?? '' },
    { titre: 'Salariés concernés', champ: 'salaries' },
  ], visibles.value)
}
</script>

<template>
  <PageHeader
    titre="Obligations par métier et établissement"
    sousTitre="Quelles formations sont obligatoires, pour quels métiers, dans quel hôtel"
  >
    <Button label="Exporter" icon="pi pi-download" severity="secondary" outlined
            :disabled="!visibles.length" @click="exporter" />
  </PageHeader>

  <div class="stats">
    <StatCard titre="Formations obligatoires" :valeur="totaux.formations" icone="pi pi-shield" />
    <StatCard titre="Familles de métier concernées" :valeur="totaux.metiers" icone="pi pi-briefcase" />
    <StatCard titre="Salariés concernés" :valeur="formatNombre(totaux.salaries)" icone="pi pi-users"
              precision="par au moins une formation obligatoire" />
  </div>

  <div class="filtres">
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="famille" :options="familles"
            placeholder="Toutes les familles de métier" showClear />
    <Select v-model="formationId" :options="formations"
            optionLabel="intitule" optionValue="id"
            placeholder="Toutes les formations obligatoires" showClear />
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="cle"
             paginator :rows="25" removableSort stripedRows size="small">
    <template #empty>Aucune formation obligatoire ne correspond à ces critères.</template>

    <Column field="etablissement" header="Établissement" sortable />
    <Column field="famille_metier" header="Famille de métier" sortable />
    <Column field="formation" header="Formation obligatoire" sortable />
    <Column field="domaine" header="Domaine" sortable />

    <Column field="duree_heures" header="Durée" sortable style="width: 6rem">
      <template #body="{ data }">{{ formatNombre(data.duree_heures) }} h</template>
    </Column>

    <Column field="periodicite_mois" header="Recyclage" sortable style="width: 10rem">
      <template #body="{ data }">
        {{ data.periodicite_mois ? `Tous les ${data.periodicite_mois} mois` : 'Une seule fois' }}
      </template>
    </Column>

    <Column header="Périmètre" style="width: 10rem">
      <template #body="{ data }">
        <Tag :value="data.pour_tous ? 'Tous les métiers' : 'Ce métier'"
             :severity="data.pour_tous ? 'secondary' : 'warn'" />
      </template>
    </Column>

    <Column field="salaries" header="Salariés concernés" sortable style="width: 10rem" />
  </DataTable>

  <p class="note">
    Pour changer les métiers concernés par une formation, ouvrez sa fiche dans
    « Catalogue de formations ».
  </p>
</template>

<style scoped>
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.note { color: var(--p-text-muted-color); font-size: .85rem; margin-top: 1rem; }
</style>
