<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import {
  getBesoins,
  getEtablissements,
  prendreEnChargeBesoin,
  formatDate,
  toast,
} from '@/socle/sdk'

const besoins = ref([])
const etablissements = ref([])
const chargement = ref(true)
const priseEnChargeEnCours = ref(null)

const etablissementId = ref(null)
const statut = ref(null)

async function charger() {
  chargement.value = true

  try {
    besoins.value = await getBesoins({
      typeBesoin: 'recrutement',
      etablissementId: etablissementId.value,
      statut: statut.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    etablissements.value = await getEtablissements()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }

  await charger()
})

watch([etablissementId, statut], charger)

const statuts = [
  { label: 'Ouvert', value: 'ouvert' },
  { label: 'Pris en charge', value: 'pris_en_charge' },
  { label: 'Clôturé', value: 'cloture' },
]

const totalBesoins = computed(() => besoins.value.length)

const besoinsOuverts = computed(() =>
  besoins.value.filter((b) => b.status === 'ouvert').length,
)

async function prendreEnCharge(besoin) {
  priseEnChargeEnCours.value = besoin.id

  try {
    await prendreEnChargeBesoin(besoin.id)
    toast.succes('Besoin pris en charge avec succès.')
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    priseEnChargeEnCours.value = null
  }
}
</script>

<template>
  <PageHeader
    titre="Besoins de recrutement"
    :sousTitre="`${totalBesoins} besoin(s) · ${besoinsOuverts} non pris en charge`"
  />

  <div class="stats">
    <StatCard
      titre="Total des besoins"
      :valeur="totalBesoins"
      icone="pi pi-briefcase"
    />

    <StatCard
      titre="À traiter"
      :valeur="besoinsOuverts"
      icone="pi pi-exclamation-circle"
    />
  </div>

  <div class="filtres">
    <Select
      v-model="etablissementId"
      :options="etablissements"
      optionLabel="name"
      optionValue="id"
      placeholder="Tous les établissements"
      showClear
    />

    <Select
      v-model="statut"
      :options="statuts"
      optionLabel="label"
      optionValue="value"
      placeholder="Tous les statuts"
      showClear
    />
  </div>

  <DataTable
    :value="besoins"
    :loading="chargement"
    dataKey="id"
    paginator
    :rows="25"
    stripedRows
    rowHover
    size="small"
  >
    <template #empty>
      Aucun besoin de recrutement ne correspond à ces critères.
    </template>

    <Column field="position_title" header="Poste" sortable />

    <Column field="establishment_name" header="Établissement" sortable />

    <Column field="department_label" header="Département" sortable />

    <Column field="detected_on" header="Date" sortable style="width: 10rem">
      <template #body="{ data }">
        {{ formatDate(data.detected_on, 'court') }}
      </template>
    </Column>

    <Column field="status_label" header="Statut" sortable style="width: 12rem">
      <template #body="{ data }">
        <Tag
          :value="data.status_label"
          :severity="
            data.status === 'ouvert'
              ? 'warn'
              : data.status === 'pris_en_charge'
                ? 'info'
                : 'success'
          "
        />
      </template>
    </Column>

    <Column header="" style="width: 14rem">
      <template #body="{ data }">
        <Button
          v-if="data.status === 'ouvert'"
          label="Prendre en charge"
          icon="pi pi-check"
          size="small"
          :loading="priseEnChargeEnCours === data.id"
          @click="prendreEnCharge(data)"
        />

        <span v-else>—</span>
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.filtres {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 1rem;
}

.filtres > .p-select {
  min-width: 16rem;
}
</style>
