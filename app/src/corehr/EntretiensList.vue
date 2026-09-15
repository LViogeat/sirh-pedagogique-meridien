<script setup>
/**
 * Les entretiens annuels, et le détail de l'un d'eux.
 *
 * C'est l'écran qui montre la matière première du dispositif : les objectifs,
 * les écarts de compétences et les aspirations dont sortent tous les besoins.
 */
import { ref, computed, onMounted, watch } from 'vue'
import {
  getEntretiens, getEntretien, getCampagnes, getEtablissements, getReferentiels,
  formatDate, toast,
} from '@/socle/sdk'

const entretiens = ref([])
const campagnes = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)

const campagneId = ref(null)
const etablissementId = ref(null)
const statut = ref(null)

const entretienOuvert = ref(null)

async function charger() {
  chargement.value = true
  try {
    entretiens.value = await getEntretiens({
      campagneId: campagneId.value,
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
  ;[campagnes.value, etablissements.value, referentiels.value] = await Promise.all([
    getCampagnes(), getEtablissements(), getReferentiels(),
  ])
  await charger()
})

watch([campagneId, etablissementId, statut], charger)

const ecartsTotaux = computed(() =>
  entretiens.value.reduce((t, e) => t + e.skill_gaps_count, 0))

async function ouvrir(entretien) {
  entretienOuvert.value = await getEntretien(entretien.id)
}

const severiteAtteinte = (taux) =>
  taux === null ? 'secondary' : taux >= 90 ? 'success' : taux >= 70 ? 'info' : 'warn'
</script>

<template>
  <PageHeader
    titre="Entretiens annuels"
    :sousTitre="`${entretiens.length} entretien(s) · ${ecartsTotaux} écart(s) de compétence constaté(s)`"
  />

  <div class="filtres">
    <Select v-model="campagneId" :options="campagnes"
            optionLabel="label" optionValue="id"
            placeholder="Toutes les campagnes" showClear />

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />

    <Select v-model="statut" :options="referentiels.statut_entretien"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
  </div>

  <DataTable :value="entretiens" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small" rowHover
             @row-click="(e) => ouvrir(e.data)">
    <template #empty>Aucun entretien ne correspond à ces critères.</template>

    <Column field="employee_name" header="Salarié" sortable />
    <Column field="position_title" header="Poste" sortable />
    <Column field="establishment_name" header="Établissement" sortable />
    <Column field="reviewer_name" header="Évaluateur" sortable />

    <Column field="review_date" header="Date" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.review_date) }}</template>
    </Column>

    <Column field="average_achievement_rate" header="Atteinte" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag v-if="data.average_achievement_rate !== null"
             :value="`${data.average_achievement_rate} %`"
             :severity="severiteAtteinte(data.average_achievement_rate)" />
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="skill_gaps_count" header="Écarts" sortable style="width: 6rem">
      <template #body="{ data }">
        <Tag v-if="data.skill_gaps_count" :value="data.skill_gaps_count" severity="warn" />
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="aspirations_count" header="Souhaits" sortable style="width: 7rem" />
    <Column field="status_label" header="Statut" sortable style="width: 8rem" />
  </DataTable>

  <Dialog :visible="!!entretienOuvert" modal :style="{ width: '46rem' }"
          :header="entretienOuvert?.employee_name"
          @update:visible="entretienOuvert = null">
    <template v-if="entretienOuvert">
      <p class="chapo">
        {{ entretienOuvert.campaign_label }} ·
        mené par {{ entretienOuvert.reviewer_name }} le
        {{ formatDate(entretienOuvert.review_date, 'long') }}
      </p>
      <Message v-if="entretienOuvert.summary" severity="secondary" :closable="false">
        {{ entretienOuvert.summary }}
      </Message>

      <h3>Objectifs</h3>
      <DataTable :value="entretienOuvert.goals" size="small" dataKey="id">
        <template #empty>Aucun objectif.</template>
        <Column field="label" header="Objectif" />
        <Column field="achievement_rate" header="Atteinte" style="width: 11rem">
          <template #body="{ data }">
            <ProgressBar :value="Math.min(data.achievement_rate, 100)"
                         :showValue="false" style="height: .5rem" />
            <small>{{ data.achievement_rate }} %</small>
          </template>
        </Column>
      </DataTable>

      <h3>Compétences évaluées</h3>
      <!-- L'écart entre le niveau attendu et le niveau constaté : c'est
           exactement lui qui produit un besoin de formation. -->
      <DataTable :value="entretienOuvert.skill_assessments" size="small" dataKey="id">
        <template #empty>Aucune compétence évaluée.</template>
        <Column field="skill_label" header="Compétence" />
        <Column field="required_level" header="Attendu" style="width: 6rem">
          <template #body="{ data }">{{ data.required_level ?? '—' }}</template>
        </Column>
        <Column field="assessed_level" header="Constaté" style="width: 6rem" />
        <Column field="gap" header="Écart" style="width: 6rem">
          <template #body="{ data }">
            <Tag v-if="data.gap > 0" :value="`-${data.gap}`" severity="danger" />
            <span v-else>—</span>
          </template>
        </Column>
      </DataTable>

      <h3>Souhaits exprimés</h3>
      <DataTable :value="entretienOuvert.aspirations" size="small" dataKey="id">
        <template #empty>Aucun souhait exprimé.</template>
        <Column field="aspiration_type_label" header="Souhait" />
        <Column field="target_position_title" header="Poste visé">
          <template #body="{ data }">{{ data.target_position_title || '—' }}</template>
        </Column>
        <Column field="target_establishment_name" header="Établissement visé">
          <template #body="{ data }">{{ data.target_establishment_name || '—' }}</template>
        </Column>
      </DataTable>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 14rem; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
h3 { font-size: .95rem; margin: 1.5rem 0 .5rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
