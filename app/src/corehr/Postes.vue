<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getPostes, getServices, formatNombre } from '@/socle/sdk'

const postes = ref([])
const services = ref([])
const serviceId = ref(null)
const seulementVacants = ref(false)
const chargement = ref(true)

async function charger() {
  chargement.value = true
  try {
    postes.value = await getPostes({
      vacants: seulementVacants.value,
      serviceId: serviceId.value || undefined,
    })
  } finally {
    chargement.value = false
  }
}

const vacants = computed(() => postes.value.filter(p => p.vacant).length)

onMounted(async () => {
  services.value = await getServices()
  await charger()
})
watch([serviceId, seulementVacants], charger)
</script>

<template>
  <PageHeader titre="Postes"
              :sousTitre="`${postes.length} position(s) · ${vacants} vacante(s)`" />

  <Message severity="info" :closable="false" class="note">
    Un <strong>emploi</strong> est une entrée du référentiel métier ; un <strong>poste</strong>
    est une position budgétée dans une unité. Un poste ouvert sans titulaire est une
    <strong>vacance</strong> — c’est le point d’accroche naturel d’un module Recrutement.
  </Message>

  <div class="filtres">
    <Select v-model="serviceId" :options="services" optionLabel="service" optionValue="service_id"
            placeholder="Tous les services" showClear />
    <div class="bascule">
      <ToggleSwitch v-model="seulementVacants" inputId="vacants" />
      <label for="vacants">Postes vacants uniquement</label>
    </div>
  </div>

  <DataTable :value="postes" :loading="chargement" dataKey="poste_id"
             paginator :rows="25" removableSort stripedRows size="small">
    <template #empty>Aucun poste ne correspond à ces critères.</template>
    <Column field="code" header="Code" sortable style="width: 8rem" />
    <Column field="libelle" header="Poste" sortable />
    <Column field="emploi" header="Emploi" sortable />
    <Column field="famille_metier" header="Famille" sortable />
    <Column field="service" header="Service" sortable />
    <Column field="etp_budgete" header="ETP budgété" sortable style="width: 8rem" />
    <Column header="Titulaire" sortable field="titulaire">
      <template #body="{ data }">
        <span v-if="data.titulaire">{{ data.titulaire }}</span>
        <Tag v-else-if="data.ouvert" value="vacant" severity="warn" />
        <Tag v-else value="fermé" severity="secondary" />
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.note { margin-bottom: 1rem; }
.filtres { display: flex; gap: 1.25rem; align-items: center; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > :first-child { min-width: 14rem; }
.bascule { display: flex; align-items: center; gap: .5rem; }
.bascule label { font-size: .9rem; }
</style>
