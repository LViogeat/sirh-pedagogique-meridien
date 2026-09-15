<script setup>
/**
 * Les postes de la chaîne, avec leur effectif cible et leur effectif réel.
 *
 * L'écart entre les deux est ce qui déclenche un besoin de recrutement :
 * c'est l'écran qui explique d'où viennent les lignes du groupe Recrutement.
 *
 * Il montre aussi le patron du DÉTAIL DANS UNE BOÎTE DE DIALOGUE : un second
 * appel au socle au moment du clic, plutôt qu'un écran de plus.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { getPostes, getPoste, getEtablissements, toast } from '@/socle/sdk'

const postes = ref([])
const etablissements = ref([])
const chargement = ref(true)

const etablissementId = ref(null)
const famille = ref(null)
const vacants = ref(false)

const posteOuvert = ref(null)

async function charger() {
  chargement.value = true
  try {
    postes.value = await getPostes({
      etablissementId: etablissementId.value,
      famille: famille.value,
      vacants: vacants.value || null,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  etablissements.value = await getEtablissements()
  await charger()
})

watch([etablissementId, famille, vacants], charger)

/* Les familles de métier ne sont pas un référentiel : on les déduit des
   postes reçus. Un `Set` supprime les doublons. */
const familles = computed(() =>
  [...new Set(postes.value.map((p) => p.job_family))].sort())

const totaux = computed(() => ({
  cible: postes.value.reduce((t, p) => t + p.target_headcount, 0),
  reel: postes.value.reduce((t, p) => t + p.current_headcount, 0),
  manquants: postes.value.reduce((t, p) => t + p.vacancies, 0),
}))

async function ouvrir(poste) {
  posteOuvert.value = await getPoste(poste.id)
}

const NIVEAUX = { 1: 'Exécution', 2: 'Qualifié', 3: 'Encadrement', 4: 'Direction' }
</script>

<template>
  <PageHeader
    titre="Postes"
    :sousTitre="`${postes.length} poste(s) · ${totaux.reel} pourvu(s) sur ${totaux.cible} · ${totaux.manquants} à pourvoir`"
  />

  <div class="filtres">
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />

    <Select v-model="famille" :options="familles"
            placeholder="Toutes les familles de métier" showClear />

    <div class="bascule">
      <ToggleSwitch v-model="vacants" inputId="vacants" />
      <label for="vacants">Seulement les postes à pourvoir</label>
    </div>
  </div>

  <DataTable :value="postes" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small" rowHover
             @row-click="(e) => ouvrir(e.data)">
    <template #empty>Aucun poste ne correspond à ces critères.</template>

    <Column field="title" header="Intitulé" sortable />
    <Column field="job_family" header="Famille de métier" sortable />
    <Column field="department_label" header="Département" sortable />
    <Column field="establishment_name" header="Établissement" sortable />

    <Column field="hierarchy_level" header="Niveau" sortable style="width: 9rem">
      <template #body="{ data }">{{ NIVEAUX[data.hierarchy_level] }}</template>
    </Column>

    <Column field="target_headcount" header="Cible" sortable style="width: 6rem" />
    <Column field="current_headcount" header="Réel" sortable style="width: 6rem" />

    <Column field="vacancies" header="À pourvoir" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag v-if="data.vacancies > 0" :value="data.vacancies" severity="danger" />
        <span v-else>—</span>
      </template>
    </Column>
  </DataTable>

  <!-- Le détail : chargé au clic, pas avant. -->
  <Dialog :visible="!!posteOuvert" modal :style="{ width: '34rem' }"
          :header="posteOuvert?.title" @update:visible="posteOuvert = null">
    <template v-if="posteOuvert">
      <p class="chapo">
        {{ posteOuvert.department_label }} · {{ posteOuvert.establishment_name }} ·
        effectif cible {{ posteOuvert.target_headcount }},
        réel {{ posteOuvert.current_headcount }}
      </p>

      <h3>Compétences attendues</h3>
      <DataTable :value="posteOuvert.required_skills" size="small" dataKey="skill_id">
        <template #empty>Aucune compétence attendue sur ce poste.</template>
        <Column field="skill_label" header="Compétence" />
        <Column field="category_label" header="Catégorie" />
        <Column field="required_level" header="Niveau attendu" style="width: 9rem">
          <template #body="{ data }">
            <Rating :modelValue="data.required_level" :stars="4" readonly />
          </template>
        </Column>
      </DataTable>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 14rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .9rem; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
h3 { font-size: .95rem; margin: 1.25rem 0 .5rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
