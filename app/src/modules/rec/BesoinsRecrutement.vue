<!-- libelle: Besoins à traiter -->
<script setup>
/**
 * Les besoins de recrutement du socle, et leur prise en charge (story #1).
 *
 * « Prendre en charge » fait deux choses, dans cet ordre :
 *   1. le besoin passe à « pris en charge » dans le socle (prendreEnChargeBesoin) ;
 *   2. une offre est créée en brouillon dans notre table `offres`.
 * Si la création de l'offre échoue, le besoin est relâché : on ne laisse
 * jamais un besoin pris sans offre derrière.
 */
import { ref, computed, onMounted, watch } from 'vue'
import {
  getBesoins, getEtablissements, getReferentiels,
  prendreEnChargeBesoin, relacherBesoin,
  sql, insert, formatDate, toast,
} from '@/socle/sdk'
import { assurerSchema } from './_schema.js'

const besoins = ref([])
const offres = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)
const enCours = ref(null) // id du besoin en cours de prise en charge

const statut = ref(null)
const priorite = ref(null)
const etablissementId = ref(null)
const origine = ref(null)

const ORIGINES = [
  { code: 'contrat', label: 'Fin de contrat' },
  { code: 'effectif', label: 'Sous-effectif' },
]

/* L'origine n'est pas un champ du socle : on la lit dans le texte de la règle. */
const origineDe = (b) => (/effectif/i.test(b.origin) ? 'effectif' : 'contrat')

async function charger() {
  chargement.value = true
  try {
    ;[besoins.value, offres.value] = await Promise.all([
      getBesoins({
        typeBesoin: 'recrutement',
        statut: statut.value,
        priorite: priorite.value,
        etablissementId: etablissementId.value,
      }),
      sql('select id, besoin_id, statut from offres'),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
    besoins.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  await assurerSchema()
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

watch([statut, priorite, etablissementId], charger)

const lignes = computed(() =>
  origine.value ? besoins.value.filter((b) => origineDe(b) === origine.value) : besoins.value)

const offreDu = computed(() => Object.fromEntries(offres.value.map((o) => [o.besoin_id, o])))

const compteurs = computed(() => ({
  ouverts: besoins.value.filter((b) => b.status === 'ouvert').length,
  hautes: besoins.value.filter((b) => b.priority === 'haute' && b.status === 'ouvert').length,
  pris: besoins.value.filter((b) => b.status === 'pris_en_charge').length,
  clotures: besoins.value.filter((b) => b.status === 'cloture').length,
}))

/* « Sorbonne-Hôtel Mont-Blanc » → « Mont-Blanc » */
const hotel = (nom) => (nom || '').replace(/^Sorbonne-Hôtel\s+/, '')

async function prendreEnCharge(besoin) {
  enCours.value = besoin.id
  try {
    await prendreEnChargeBesoin(besoin.id, 'Offre en préparation')
    try {
      const offre = await insert('offres', {
        besoin_id: besoin.id,
        position_id: besoin.position_id,
        establishment_id: besoin.establishment_id,
        intitule: `${besoin.position_title} — ${hotel(besoin.establishment_name)}`,
      })
      toast.succes(`Offre n° ${offre.id} créée en brouillon : ${offre.intitule}`)
    } catch (erreur) {
      await relacherBesoin(besoin.id).catch(() => {})
      throw erreur
    }
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}

const severitePriorite = (code) =>
  ({ haute: 'danger', moyenne: 'warn', basse: 'secondary' })[code] || 'secondary'
const severiteStatut = (code) =>
  ({ ouvert: 'info', pris_en_charge: 'warn', cloture: 'success' })[code] || 'secondary'
const LIBELLES_OFFRE = { brouillon: 'Brouillon', publiee: 'Publiée', pourvue: 'Pourvue', annulee: 'Annulée' }
</script>

<template>
  <PageHeader
    titre="Besoins à traiter"
    :sousTitre="`${lignes.length} besoin(s) de recrutement affiché(s)`"
  />

  <div class="stats">
    <StatCard titre="À traiter" :valeur="compteurs.ouverts" icone="pi pi-inbox" precision="besoins ouverts" />
    <StatCard titre="Priorité haute" :valeur="compteurs.hautes" icone="pi pi-exclamation-triangle" precision="parmi les besoins ouverts" />
    <StatCard titre="Pris en charge" :valeur="compteurs.pris" icone="pi pi-briefcase" precision="offre en cours" />
    <StatCard titre="Clôturés" :valeur="compteurs.clotures" icone="pi pi-check-circle" precision="postes pourvus" />
  </div>

  <div class="filtres">
    <Select v-model="statut" :options="referentiels.statut_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
    <Select v-model="priorite" :options="referentiels.priorite_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Toutes les priorités" showClear />
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="origine" :options="ORIGINES"
            optionLabel="label" optionValue="code"
            placeholder="Toutes les origines" showClear />
  </div>

  <DataTable :value="lignes" :loading="chargement" dataKey="id"
             paginator :rows="20" removableSort stripedRows size="small"
             sortField="priority" :sortOrder="1">
    <template #empty>Aucun besoin de recrutement ne correspond à ces critères.</template>

    <Column field="priority" header="Priorité" sortable style="width: 7rem">
      <template #body="{ data }">
        <Tag :value="data.priority_label" :severity="severitePriorite(data.priority)" />
      </template>
    </Column>

    <Column field="position_title" header="Poste" sortable />

    <Column field="establishment_name" header="Établissement" sortable>
      <template #body="{ data }">
        {{ hotel(data.establishment_name) }}
        <span class="ville">{{ data.establishment_city }}</span>
      </template>
    </Column>

    <Column header="Origine">
      <template #body="{ data }">
        <Tag :value="origineDe(data) === 'effectif' ? 'Sous-effectif' : 'Fin de contrat'"
             severity="secondary" />
        <div class="origine" v-tooltip.top="data.origin">{{ data.origin }}</div>
      </template>
    </Column>

    <Column field="detected_on" header="Détecté le" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.detected_on) }}</template>
    </Column>

    <Column field="status" header="Statut" sortable style="width: 9rem">
      <template #body="{ data }">
        <Tag :value="data.status_label" :severity="severiteStatut(data.status)" />
      </template>
    </Column>

    <Column header="Action" style="width: 13rem">
      <template #body="{ data }">
        <Button v-if="data.status === 'ouvert'"
                label="Prendre en charge" icon="pi pi-plus" size="small"
                :loading="enCours === data.id" :disabled="enCours !== null"
                @click="prendreEnCharge(data)" />
        <span v-else-if="offreDu[data.id]" class="offre">
          <i class="pi pi-file" /> Offre n° {{ offreDu[data.id].id }} ·
          {{ LIBELLES_OFFRE[offreDu[data.id].statut] }}
        </span>
        <span v-else-if="data.handled_by_module && data.handled_by_module !== 'rec'" class="muet">
          Pris par un autre module
        </span>
        <span v-else class="muet">—</span>
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
.ville { display: block; font-size: .8rem; color: var(--p-text-muted-color); }
.origine {
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden; font-size: .78rem; color: var(--p-text-muted-color); margin-top: .25rem;
}
.offre { font-size: .85rem; }
.muet { color: var(--p-text-muted-color); font-size: .85rem; }
</style>
