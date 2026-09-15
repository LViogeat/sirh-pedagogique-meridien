<script setup>
/**
 * Les salariés présents, filtrables. Même structure que BesoinsList.vue,
 * avec en plus une recherche libre et le passage vers une fiche de détail.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  getSalaries, getEtablissements, getDepartements, getReferentiels,
  formatDate, anciennete, toast,
} from '@/socle/sdk'

const router = useRouter()

const salaries = ref([])
const etablissements = ref([])
const departements = ref([])
const referentiels = ref({})
const chargement = ref(true)

const recherche = ref('')
const etablissementId = ref(null)
const departementId = ref(null)
const typeContrat = ref(null)
const statut = ref('actif')

async function charger() {
  chargement.value = true
  try {
    salaries.value = await getSalaries({
      q: recherche.value,
      etablissementId: etablissementId.value,
      departementId: departementId.value,
      typeContrat: typeContrat.value,
      statut: statut.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

/* Les départements dépendent de l'établissement choisi : quand il change, on
   recharge la liste et on oublie le département sélectionné. */
watch(etablissementId, async (id) => {
  departementId.value = null
  departements.value = await getDepartements({ etablissementId: id })
})

watch([etablissementId, departementId, typeContrat, statut], charger)

/* La recherche libre attend 300 ms après la dernière frappe : sans cela, on
   appellerait l'API à chaque lettre. */
let minuteur
watch(recherche, () => {
  clearTimeout(minuteur)
  minuteur = setTimeout(charger, 300)
})

onMounted(async () => {
  ;[etablissements.value, departements.value, referentiels.value] = await Promise.all([
    getEtablissements(), getDepartements(), getReferentiels(),
  ])
  await charger()
})

const equivalentTempsPlein = computed(() =>
  salaries.value.reduce((total, s) => total + Number(s.work_time_ratio || 0), 0).toFixed(2))

const severiteContrat = (code) => ({
  CDI: 'success', CDD: 'warn', APPRENTISSAGE: 'info',
  SAISONNIER: 'secondary', EXTRA: 'contrast',
}[code] || 'secondary')
</script>

<template>
  <PageHeader titre="Salariés"
              :sousTitre="`${salaries.length} personne(s) · ${equivalentTempsPlein} ETP`" />

  <div class="filtres">
    <IconField>
      <InputIcon class="pi pi-search" />
      <InputText v-model="recherche" placeholder="Nom, matricule ou e-mail…" />
    </IconField>

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />

    <Select v-model="departementId" :options="departements"
            optionLabel="label" optionValue="id"
            placeholder="Tous les départements" showClear />

    <Select v-model="typeContrat" :options="referentiels.type_contrat"
            optionLabel="label" optionValue="code"
            placeholder="Tous les contrats" showClear />

    <Select v-model="statut" :options="referentiels.statut_salarie"
            optionLabel="label" optionValue="code"
            placeholder="Présents et sortis" showClear />
  </div>

  <DataTable
    :value="salaries" :loading="chargement" dataKey="id"
    paginator :rows="25" :rowsPerPageOptions="[25, 50, 100]"
    removableSort stripedRows size="small" rowHover
    paginatorTemplate="FirstPageLink PrevPageLink CurrentPageReport NextPageLink LastPageLink RowsPerPageDropdown"
    currentPageReportTemplate="{first} à {last} sur {totalRecords}"
    @row-click="(e) => router.push(`/corehr/salaries/${e.data.id}`)"
  >
    <template #empty>Aucun salarié ne correspond à ces critères.</template>

    <Column field="matricule" header="Matricule" sortable style="width: 7rem" />
    <Column field="full_name" header="Nom" sortable />
    <Column field="position_title" header="Poste" sortable />
    <Column field="department_label" header="Département" sortable />
    <Column field="establishment_name" header="Établissement" sortable />

    <Column field="contract_type" header="Contrat" sortable style="width: 9rem">
      <template #body="{ data }">
        <Tag v-if="data.contract_type" :value="data.contract_type"
             :severity="severiteContrat(data.contract_type)" />
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="work_time_ratio" header="Temps" sortable style="width: 6rem">
      <template #body="{ data }">
        {{ data.work_time_ratio ? `${Math.round(data.work_time_ratio * 100)} %` : '—' }}
      </template>
    </Column>

    <Column field="joined_on" header="Entrée" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.joined_on) }}</template>
    </Column>

    <Column field="seniority_months" header="Ancienneté" sortable style="width: 10rem">
      <template #body="{ data }">{{ anciennete(data.seniority_months) }}</template>
    </Column>

    <Column field="manager_name" header="Manager" sortable>
      <template #body="{ data }">{{ data.manager_name || '—' }}</template>
    </Column>
  </DataTable>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
