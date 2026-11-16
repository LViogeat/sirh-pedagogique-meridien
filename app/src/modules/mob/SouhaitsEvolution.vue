<!-- libelle: Souhaits d'évolution -->
<script setup>
import { ref, onMounted, watch } from 'vue'
import { getAspirations, getEntretien, getEtablissements, getReferentiels,
         getPostes, getSalaries, formatDate, toast } from '@/socle/sdk'

/* Le seuil qui déclenche un besoin de mobilité. */
const SEUIL_MOBILITE = 70

const souhaits = ref([])
/* Pour compléter les souhaits : l'hôtel de chaque poste, et l'hôtel actuel de chaque salarié. */
const hotelDuPoste = ref({})
const hotelDuSalarie = ref({})
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)

const typeAspiration = ref(null)
const etablissementId = ref(null)

const entretien = ref(null)
const souhaitChoisi = ref(null)
const dialogueVisible = ref(false)
const chargementEntretien = ref(false)

async function charger() {
  chargement.value = true
  try {
    souhaits.value = await getAspirations({
      typeAspiration: typeAspiration.value,
      etablissementId: etablissementId.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
    souhaits.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    const [hotels, refs, postes, salaries] = await Promise.all([
      getEtablissements(),
      getReferentiels(),
      getPostes(),
      getSalaries(),
    ])
    etablissements.value = hotels
    referentiels.value = refs
    hotelDuPoste.value = Object.fromEntries(postes.map((p) => [p.id, p.establishment_name]))
    hotelDuSalarie.value = Object.fromEntries(salaries.map((s) => [s.id, s.establishment_name]))
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch([typeAspiration, etablissementId], charger)

async function ouvrir({ data }) {
  souhaitChoisi.value = data
  entretien.value = null
  dialogueVisible.value = true
  chargementEntretien.value = true
  try {
    entretien.value = await getEntretien(data.review_id)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargementEntretien.value = false
  }
}

/*
 * L'hôtel visé : celui que le salarié a indiqué (mobilité géographique),
 * sinon celui du poste visé (changement de poste). Les souhaits d'évolution
 * hiérarchique et de montée en compétences ne visent ni poste ni hôtel.
 */
const hotelVise = (s) =>
  s.target_establishment_name || hotelDuPoste.value[s.target_position_id] || null

const severiteTaux = (taux) => (taux >= SEUIL_MOBILITE ? 'success' : 'secondary')
</script>

<template>
  <PageHeader
    titre="Souhaits d'évolution"
    :sousTitre="`${souhaits.length} souhait(s) exprimé(s) en entretien annuel`"
  />

  <div class="filtres">
    <Select v-model="typeAspiration" :options="referentiels.type_aspiration"
            optionLabel="label" optionValue="code"
            placeholder="Tous les types de souhait" showClear />

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Hôtel actuel du salarié" showClear />
  </div>

  <DataTable
    :value="souhaits" :loading="chargement" dataKey="id"
    paginator :rows="20" :rowsPerPageOptions="[20, 50, 100]"
    stripedRows size="small" selectionMode="single" @rowClick="ouvrir"
  >
    <template #empty>Aucun souhait ne correspond à ces critères.</template>

    <Column field="employee_name" header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.employee_name }}</div>
        <small class="discret">{{ hotelDuSalarie[data.employee_id] || '' }}</small>
      </template>
    </Column>
    <Column field="aspiration_type_label" header="Type de souhait">
      <template #body="{ data }">
        <Tag :value="data.aspiration_type_label" severity="info" />
      </template>
    </Column>
    <Column field="target_position_title" header="Poste visé">
      <template #body="{ data }">
        <span v-if="data.target_position_title">{{ data.target_position_title }}</span>
        <span v-else class="discret">Non précisé</span>
      </template>
    </Column>
    <Column field="target_establishment_name" header="Hôtel visé">
      <template #body="{ data }">
        <span v-if="hotelVise(data)">{{ hotelVise(data) }}</span>
        <span v-else class="discret">Non précisé</span>
      </template>
    </Column>
    <Column field="comment" header="Commentaire">
      <template #body="{ data }">
        <span class="discret">{{ data.comment || '—' }}</span>
      </template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogueVisible" modal :style="{ width: '44rem' }"
          :header="souhaitChoisi ? `Entretien d'origine — ${souhaitChoisi.employee_name}` : 'Entretien'">
    <div v-if="chargementEntretien" class="attente">
      <ProgressSpinner style="width: 2.5rem; height: 2.5rem" />
    </div>

    <template v-else-if="entretien">
      <dl class="detail">
        <dt>Date</dt><dd>{{ formatDate(entretien.review_date) }}</dd>
        <dt>Manager</dt><dd>{{ entretien.reviewer_name }}</dd>
        <dt>Campagne</dt><dd>{{ entretien.campaign_label }}</dd>
        <dt>Taux moyen</dt>
        <dd>
          <Tag :value="`${entretien.average_achievement_rate ?? '—'} %`"
               :severity="severiteTaux(entretien.average_achievement_rate)" />
          <small class="discret"> seuil de mobilité : {{ SEUIL_MOBILITE }} %</small>
        </dd>
      </dl>

      <h3>Objectifs</h3>
      <DataTable :value="entretien.goals" size="small" dataKey="id">
        <template #empty>Aucun objectif enregistré.</template>
        <Column field="label" header="Objectif" />
        <Column field="achievement_rate" header="Taux d'atteinte" style="width: 9rem">
          <template #body="{ data }">{{ data.achievement_rate }} %</template>
        </Column>
      </DataTable>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 14rem; }
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.attente { display: flex; justify-content: center; padding: 2rem; }
.detail { display: grid; grid-template-columns: 8rem 1fr; gap: .5rem 1rem; margin: 0 0 1rem; }
.detail dt { font-weight: 600; color: var(--p-text-muted-color); }
.detail dd { margin: 0; }
h3 { font-size: 1rem; margin: 1rem 0 .5rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
