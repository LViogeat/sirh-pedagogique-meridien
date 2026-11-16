<!-- libelle: Opportunités de postes -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getPostes, getPoste, getEtablissements, toast } from '@/socle/sdk'

const postes = ref([])
const etablissements = ref([])
const chargement = ref(true)

const seulementVacants = ref(true)
const etablissementId = ref(null)
const famille = ref(null)
const niveau = ref(null)

/* Les familles et niveaux possibles, lus une fois sur la liste complète. */
const familles = ref([])
const niveaux = ref([])

const poste = ref(null)
const dialogueVisible = ref(false)
const chargementPoste = ref(false)

async function charger() {
  chargement.value = true
  try {
    postes.value = await getPostes({
      vacants: seulementVacants.value || null,
      etablissementId: etablissementId.value,
      famille: famille.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
    postes.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    const [hotels, tous] = await Promise.all([getEtablissements(), getPostes()])
    etablissements.value = hotels
    familles.value = [...new Set(tous.map((p) => p.job_family))].sort()
      .map((f) => ({ label: f, value: f }))
    niveaux.value = [...new Set(tous.map((p) => p.hierarchy_level))].sort((a, b) => a - b)
      .map((n) => ({ label: `Niveau ${n}`, value: n }))
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch([seulementVacants, etablissementId, famille], charger)

/* Le niveau n'est pas un filtre de l'API : on le filtre ici. */
const lignes = computed(() =>
  niveau.value == null ? postes.value : postes.value.filter((p) => p.hierarchy_level === niveau.value))

const placesTotal = computed(() => lignes.value.reduce((s, p) => s + Math.max(p.vacancies, 0), 0))

async function ouvrir({ data }) {
  poste.value = { ...data, required_skills: null }
  dialogueVisible.value = true
  chargementPoste.value = true
  try {
    poste.value = await getPoste(data.id)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargementPoste.value = false
  }
}
</script>

<template>
  <PageHeader
    titre="Opportunités de postes"
    :sousTitre="`${lignes.length} poste(s) · ${placesTotal} place(s) à pourvoir`"
  />

  <div class="filtres">
    <label class="interrupteur">
      <ToggleSwitch v-model="seulementVacants" inputId="vacants" />
      <span>Seulement les postes à pourvoir</span>
    </label>

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les hôtels" showClear />

    <Select v-model="famille" :options="familles"
            optionLabel="label" optionValue="value"
            placeholder="Toutes les familles" showClear />

    <Select v-model="niveau" :options="niveaux"
            optionLabel="label" optionValue="value"
            placeholder="Tous les niveaux" showClear />
  </div>

  <DataTable
    :value="lignes" :loading="chargement" dataKey="id"
    paginator :rows="20" :rowsPerPageOptions="[20, 50, 100]"
    removableSort stripedRows size="small" selectionMode="single" @rowClick="ouvrir"
  >
    <template #empty>Aucun poste ne correspond à ces critères.</template>

    <Column field="title" header="Intitulé" sortable />
    <Column field="job_family" header="Famille" sortable />
    <Column field="hierarchy_level" header="Niveau" sortable style="width: 6rem" />
    <Column field="department_label" header="Département" sortable />
    <Column field="establishment_name" header="Hôtel" sortable />
    <Column field="target_headcount" header="Effectif cible" style="width: 7rem" />
    <Column field="current_headcount" header="Effectif réel" style="width: 7rem" />
    <Column field="vacancies" header="À pourvoir" sortable style="width: 7rem">
      <template #body="{ data }">
        <Tag v-if="data.vacancies > 0" :value="data.vacancies" severity="warn" />
        <span v-else class="discret">0</span>
      </template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogueVisible" modal :style="{ width: '40rem' }"
          :header="poste ? poste.title : 'Poste'">
    <template v-if="poste">
      <p class="discret">
        {{ poste.department_label }} · {{ poste.establishment_name }} ·
        niveau {{ poste.hierarchy_level }}
      </p>
      <h3>Compétences attendues</h3>
      <div v-if="chargementPoste" class="attente">
        <ProgressSpinner style="width: 2.5rem; height: 2.5rem" />
      </div>
      <DataTable v-else :value="poste.required_skills" size="small" dataKey="skill_id">
        <template #empty>Aucune compétence attendue n'est renseignée.</template>
        <Column field="skill_label" header="Compétence" />
        <Column field="category_label" header="Catégorie" />
        <Column field="required_level" header="Niveau attendu" style="width: 9rem" />
      </DataTable>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 13rem; }
.interrupteur { display: flex; align-items: center; gap: .5rem; margin-right: .5rem; }
.discret { color: var(--p-text-muted-color); }
.attente { display: flex; justify-content: center; padding: 2rem; }
h3 { font-size: 1rem; margin: 1rem 0 .5rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
