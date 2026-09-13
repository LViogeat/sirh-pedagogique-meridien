<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { getEmployes, getServices, getRef, useSession,
         formatDate, formatEuro, anciennete } from '@/socle/sdk'

const router = useRouter()
const session = useSession()

const salaries = ref([])
const services = ref([])
const typesContrat = ref([])
const chargement = ref(true)

const recherche = ref('')
const serviceId = ref(null)
const typeContrat = ref(null)

async function charger() {
  chargement.value = true
  try {
    salaries.value = await getEmployes({
      recherche: recherche.value,
      serviceId: serviceId.value || undefined,
      typeContrat: typeContrat.value || undefined,
    })
  } finally {
    chargement.value = false
  }
}

// Le profil simulé change CE QUI S'AFFICHE, jamais les droits.
// « Qu'est-ce qu'un manager doit voir ? » est une question de conception.
const visibles = computed(() => {
  if (session.profilRH === 'MANAGER' && session.employe) {
    return salaries.value.filter(e => e.manager_id === session.employe.personne_id)
  }
  if (session.profilRH === 'SALARIE' && session.employe) {
    return salaries.value.filter(e => e.personne_id === session.employe.personne_id)
  }
  return salaries.value
})

const etpTotal = computed(() =>
  visibles.value.reduce((t, e) => t + Number(e.etp || 0), 0).toFixed(2))

const severiteContrat = (code) =>
  ({ CDI: 'success', CDD: 'warn', APP: 'info', PRO: 'info', STAGE: 'secondary' }[code] || 'secondary')

onMounted(async () => {
  ;[services.value, typesContrat.value] = await Promise.all([getServices(), getRef('type_contrat')])
  await charger()
})
watch([serviceId, typeContrat], charger)
let minuteur
watch(recherche, () => { clearTimeout(minuteur); minuteur = setTimeout(charger, 300) })
</script>

<template>
  <PageHeader titre="Salariés"
              :sousTitre="`${visibles.length} personne(s) présente(s) · ${etpTotal} ETP`">
    <Button label="Exporter" icon="pi pi-download" severity="secondary" outlined
            @click="$refs.tableau.exportCSV()" />
  </PageHeader>

  <Message v-if="session.profilRH !== 'RH'" severity="info" :closable="false" class="bandeau">
    Vous consultez l’écran avec le profil <strong>{{ session.profilRH.toLowerCase() }}</strong>
    <template v-if="session.employe"> de {{ session.employe.nom_complet }}</template>.
    La liste est filtrée en conséquence.
  </Message>

  <div class="filtres">
    <IconField>
      <InputIcon class="pi pi-search" />
      <InputText v-model="recherche" placeholder="Nom, matricule ou e-mail…" />
    </IconField>
    <Select v-model="serviceId" :options="services" optionLabel="service" optionValue="service_id"
            placeholder="Tous les services" showClear />
    <Select v-model="typeContrat" :options="typesContrat" optionLabel="libelle" optionValue="code"
            placeholder="Tous les contrats" showClear />
  </div>

  <DataTable ref="tableau" :value="visibles" :loading="chargement" dataKey="personne_id"
             paginator :rows="25" :rowsPerPageOptions="[25, 50, 100]"
             removableSort stripedRows size="small"
             paginatorTemplate="FirstPageLink PrevPageLink CurrentPageReport NextPageLink LastPageLink RowsPerPageDropdown"
             currentPageReportTemplate="{first} à {last} sur {totalRecords}"
             @row-click="(e) => router.push(`/corehr/salaries/${e.data.personne_id}`)"
             rowHover>
    <template #empty>Aucun salarié ne correspond à ces critères.</template>

    <Column field="matricule" header="Matricule" sortable style="width: 7rem" />
    <Column field="nom_complet" header="Nom" sortable />
    <Column field="emploi" header="Emploi" sortable />
    <Column field="service" header="Service" sortable />
    <Column field="type_contrat" header="Contrat" sortable style="width: 9rem">
      <template #body="{ data }">
        <Tag :value="data.type_contrat_code" :severity="severiteContrat(data.type_contrat_code)" />
      </template>
    </Column>
    <Column field="etp" header="ETP" sortable style="width: 5rem" />
    <Column field="date_entree" header="Entrée" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.date_entree) }}</template>
    </Column>
    <Column field="anciennete_mois" header="Ancienneté" sortable style="width: 10rem">
      <template #body="{ data }">{{ anciennete(data.anciennete_mois) }}</template>
    </Column>
    <Column field="manager" header="Manager" sortable />
  </DataTable>
</template>

<style scoped>
.bandeau { margin-bottom: 1rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
