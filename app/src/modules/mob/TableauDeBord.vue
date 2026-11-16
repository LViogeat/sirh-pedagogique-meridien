<!-- libelle: Tableau de bord -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { getBesoins, getEtablissements, sql, toast } from '@/socle/sdk'
import { ETAPES } from './_commun'

const besoins = ref([])
const hotels = ref([])
const dossiers = ref([])
const mobilites = ref([])
const chargement = ref(true)

onMounted(async () => {
  try {
    ;[besoins.value, hotels.value, dossiers.value, mobilites.value] = await Promise.all([
      getBesoins({ typeBesoin: 'mobilite' }),
      getEtablissements(),
      sql(`select d.id, d.etape, d.issue, d.ouvert_le, d.clos_le, n.establishment_id
             from dossiers d join public.identified_needs n on n.id = d.besoin_id`),
      sql(`select m.id, n.establishment_id
             from mobilites m
             join dossiers d on d.id = m.dossier_id
             join public.identified_needs n on n.id = d.besoin_id`),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

// ── Les 4 chiffres clés ─────────────────────────────────────────────────────

const ouverts = computed(() => besoins.value.filter((b) => b.status === 'ouvert').length)
const enCours = computed(() => dossiers.value.filter((d) => d.etape !== 'termine').length)
const termines = computed(() => dossiers.value.filter((d) => d.etape === 'termine'))

/* Délai moyen de traitement : de l'ouverture à la clôture, sur les dossiers terminés. */
const delaiMoyen = computed(() => {
  const durees = termines.value
    .filter((d) => d.clos_le && d.ouvert_le)
    .map((d) => (new Date(d.clos_le) - new Date(d.ouvert_le)) / 86400000)
  return durees.length ? Math.round(durees.reduce((s, x) => s + x, 0) / durees.length) : 0
})

/* Taux de mobilités réalisées : parmi les dossiers terminés. */
const taux = computed(() =>
  termines.value.length ? Math.round((mobilites.value.length / termines.value.length) * 100) : 0)

// ── Par hôtel ───────────────────────────────────────────────────────────────

const parHotel = computed(() =>
  hotels.value.map((h) => {
    const ceux = besoins.value.filter((b) => b.establishment_id === h.id)
    return {
      id: h.id,
      hotel: h.name,
      detectes: ceux.length,
      pris: ceux.filter((b) => b.status === 'pris_en_charge').length,
      clotures: ceux.filter((b) => b.status === 'cloture').length,
      mobilites: mobilites.value.filter((m) => m.establishment_id === h.id).length,
    }
  }))

const totaux = computed(() => ({
  detectes: parHotel.value.reduce((s, l) => s + l.detectes, 0),
  pris: parHotel.value.reduce((s, l) => s + l.pris, 0),
  clotures: parHotel.value.reduce((s, l) => s + l.clotures, 0),
  mobilites: parHotel.value.reduce((s, l) => s + l.mobilites, 0),
}))

// ── Par étape ───────────────────────────────────────────────────────────────

const parEtape = computed(() =>
  ETAPES.map((e) => ({ ...e, nombre: dossiers.value.filter((d) => d.etape === e.code).length })))
const maxEtape = computed(() => Math.max(1, ...parEtape.value.map((e) => e.nombre)))
</script>

<template>
  <PageHeader titre="Tableau de bord" sousTitre="Piloter la mobilité interne, hôtel par hôtel" />

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <template v-else>
    <div class="chiffres">
      <StatCard titre="Besoins ouverts" :valeur="ouverts" icone="pi pi-inbox"
                precision="besoins de mobilité non pris en charge" />
      <StatCard titre="Dossiers en cours" :valeur="enCours" icone="pi pi-folder-open"
                precision="non terminés" />
      <StatCard titre="Délai moyen" :valeur="`${delaiMoyen} j`" icone="pi pi-clock"
                precision="de l'ouverture à la clôture" />
      <StatCard titre="Mobilités réalisées" :valeur="`${taux} %`" icone="pi pi-directions"
                :precision="`${mobilites.length} sur ${termines.length} dossier(s) terminé(s)`" />
    </div>

    <div class="grille">
      <Card>
        <template #title>Par hôtel</template>
        <template #content>
          <DataTable :value="parHotel" size="small" dataKey="id">
            <Column field="hotel" header="Hôtel">
              <template #footer><strong>Total</strong></template>
            </Column>
            <Column field="detectes" header="Détectés" style="width: 7rem">
              <template #footer><strong>{{ totaux.detectes }}</strong></template>
            </Column>
            <Column field="pris" header="Pris en charge" style="width: 8rem">
              <template #footer><strong>{{ totaux.pris }}</strong></template>
            </Column>
            <Column field="clotures" header="Clôturés" style="width: 7rem">
              <template #footer><strong>{{ totaux.clotures }}</strong></template>
            </Column>
            <Column field="mobilites" header="Mobilités" style="width: 7rem">
              <template #footer><strong>{{ totaux.mobilites }}</strong></template>
            </Column>
          </DataTable>
        </template>
      </Card>

      <Card>
        <template #title>Dossiers par étape</template>
        <template #content>
          <div v-for="e in parEtape" :key="e.code" class="etape">
            <span class="nom">{{ e.label }}</span>
            <div class="barre"><div class="rempli" :style="{ width: `${(e.nombre / maxEtape) * 100}%` }" /></div>
            <strong class="nombre">{{ e.nombre }}</strong>
          </div>
        </template>
      </Card>
    </div>
  </template>
</template>

<style scoped>
.attente { display: flex; justify-content: center; padding: 3rem; }
.chiffres { display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.grille { display: grid; grid-template-columns: 2fr 1fr; gap: 1.25rem; align-items: start; }
@media (max-width: 1100px) { .grille { grid-template-columns: 1fr; } }
.etape { display: grid; grid-template-columns: 7rem 1fr 2rem; align-items: center; gap: .75rem; margin-bottom: .8rem; }
.barre { height: .7rem; background: var(--p-surface-100); border-radius: 99px; overflow: hidden; }
.rempli { height: 100%; background: var(--p-primary-color); border-radius: 99px; }
.nombre { text-align: right; }
</style>
