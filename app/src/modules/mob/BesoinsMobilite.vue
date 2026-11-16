<!-- libelle: Besoins de mobilité -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getBesoins, getEtablissements, getReferentiels, formatDate, toast } from '@/socle/sdk'

const besoins = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)

const statut = ref('ouvert')
const etablissementId = ref(null)
const priorite = ref(null)
const recherche = ref('')

const selection = ref(null)
const dialogueVisible = ref(false)

async function charger() {
  chargement.value = true
  try {
    besoins.value = await getBesoins({
      typeBesoin: 'mobilite',
      statut: statut.value,
      etablissementId: etablissementId.value,
      priorite: priorite.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
    besoins.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    ;[etablissements.value, referentiels.value] = await Promise.all([
      getEtablissements(),
      getReferentiels(),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch([statut, etablissementId, priorite], charger)

const ORDRE_PRIORITE = { haute: 0, moyenne: 1, basse: 2 }

/* Recherche par nom, puis priorités hautes en haut de la liste. */
const lignes = computed(() => {
  const motif = recherche.value.trim().toLowerCase()
  return besoins.value
    .filter((b) => !motif || (b.employee_name || '').toLowerCase().includes(motif))
    .slice()
    .sort((a, b) =>
      (ORDRE_PRIORITE[a.priority] ?? 9) - (ORDRE_PRIORITE[b.priority] ?? 9)
      || String(b.detected_on).localeCompare(String(a.detected_on)))
})

const nbOuverts = computed(() => besoins.value.filter((b) => b.status === 'ouvert').length)

const severitePriorite = (code) =>
  ({ haute: 'danger', moyenne: 'warn', basse: 'secondary' })[code] || 'secondary'
const severiteStatut = (code) =>
  ({ ouvert: 'info', pris_en_charge: 'warn', cloture: 'success' })[code] || 'secondary'

function ouvrir({ data }) {
  selection.value = data
  dialogueVisible.value = true
}
</script>

<template>
  <PageHeader
    titre="Besoins de mobilité"
    :sousTitre="`${lignes.length} besoin(s) affiché(s)`"
  />

  <div class="chiffres">
    <StatCard titre="Besoins ouverts" :valeur="nbOuverts" icone="pi pi-inbox"
              precision="dans la sélection actuelle" />
  </div>

  <div class="filtres">
    <IconField>
      <InputIcon class="pi pi-search" />
      <InputText v-model="recherche" placeholder="Chercher un salarié" />
    </IconField>

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les hôtels" showClear />

    <Select v-model="priorite" :options="referentiels.priorite_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Toutes les priorités" showClear />

    <Select v-model="statut" :options="referentiels.statut_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
  </div>

  <DataTable
    :value="lignes" :loading="chargement" dataKey="id"
    paginator :rows="20" :rowsPerPageOptions="[20, 50, 100]"
    stripedRows size="small" selectionMode="single"
    @rowClick="ouvrir"
    currentPageReportTemplate="{first} à {last} sur {totalRecords}"
    paginatorTemplate="FirstPageLink PrevPageLink CurrentPageReport NextPageLink LastPageLink RowsPerPageDropdown"
  >
    <template #empty>Aucun besoin de mobilité ne correspond à ces critères.</template>

    <Column field="employee_name" header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.employee_name }}</div>
        <small class="discret">{{ data.matricule }}</small>
      </template>
    </Column>
    <Column field="position_title" header="Poste visé" />
    <Column field="establishment_name" header="Hôtel visé" />
    <Column field="priority" header="Priorité" style="width: 7rem">
      <template #body="{ data }">
        <Tag :value="data.priority_label" :severity="severitePriorite(data.priority)" />
      </template>
    </Column>
    <Column field="origin" header="Origine">
      <template #body="{ data }">
        <span class="origine">{{ data.origin }}</span>
      </template>
    </Column>
    <Column field="detected_on" header="Détecté le" style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.detected_on) }}</template>
    </Column>
    <Column field="status" header="Statut" style="width: 9rem">
      <template #body="{ data }">
        <Tag :value="data.status_label" :severity="severiteStatut(data.status)" />
      </template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogueVisible" modal header="Détail du besoin"
          :style="{ width: '34rem' }">
    <dl v-if="selection" class="detail">
      <dt>Salarié</dt><dd>{{ selection.employee_name }} ({{ selection.matricule }})</dd>
      <dt>Poste visé</dt><dd>{{ selection.position_title }}</dd>
      <dt>Département</dt><dd>{{ selection.department_label || '—' }}</dd>
      <dt>Hôtel visé</dt><dd>{{ selection.establishment_name }}</dd>
      <dt>Priorité</dt>
      <dd><Tag :value="selection.priority_label" :severity="severitePriorite(selection.priority)" /></dd>
      <dt>Statut</dt>
      <dd><Tag :value="selection.status_label" :severity="severiteStatut(selection.status)" /></dd>
      <dt>Origine</dt><dd>{{ selection.origin }}</dd>
      <dt>Détecté le</dt><dd>{{ formatDate(selection.detected_on) }}</dd>
      <dt>Entretien d'origine</dt><dd>{{ selection.review_id ? `n° ${selection.review_id}` : '—' }}</dd>
      <dt>Commentaire</dt><dd>{{ selection.comment || '—' }}</dd>
    </dl>
  </Dialog>
</template>

<style scoped>
.chiffres { display: flex; gap: 1rem; margin-bottom: 1rem; max-width: 18rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.origine {
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden; font-size: .8rem; color: var(--p-text-muted-color);
}
.detail { display: grid; grid-template-columns: 11rem 1fr; gap: .5rem 1rem; margin: 0; }
.detail dt { font-weight: 600; color: var(--p-text-muted-color); }
.detail dd { margin: 0; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
