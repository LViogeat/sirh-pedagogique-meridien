<!-- libelle: Pipeline -->
<script setup>
/**
 * Le pipeline : la vue d'ensemble des DP (story #147).
 *
 * Une ligne par DP publiée ou pourvue, avec le nombre de candidats à chaque
 * étape du workflow. Un clic ouvre la page de la DP, où l'on fait avancer les
 * candidats (colonnes du workflow, _KanbanCandidatures).
 *
 * Les anciens liens « pipeline?offre=12 » mènent directement à la DP 12.
 */
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getEtablissements, sql, formatDate, toast } from '@/socle/sdk'
import { assurerSchema } from './_schema.js'
import { ETAPES, REFUS } from './_workflow.js'

const route = useRoute()
const router = useRouter()

if (Number(route.query.offre)) router.replace(`/rec/offre/${Number(route.query.offre)}`)

const COLONNES = [...ETAPES, REFUS]
const offres = ref([])
const hotels = ref({})
const chargement = ref(true)
const statut = ref('publiee')

const STATUTS = [
  { code: 'publiee', label: 'Publiées' },
  { code: 'pourvue', label: 'Pourvues' },
]

onMounted(async () => {
  await assurerSchema()
  try {
    const [lignes, etabs] = await Promise.all([
      sql(
        `select o.id, o.intitule, o.statut, o.establishment_id, o.publiee_le, o.recruteur_nom,
                count(c.id)::int as total,
                ${COLONNES.map((e) => `count(c.id) filter (where c.etape = '${e.code}')::int as "${e.code}"`).join(',\n                ')}
           from offres o left join candidatures c on c.offre_id = o.id
          where o.statut in ('publiee', 'pourvue')
          group by o.id
          order by o.statut, o.publiee_le desc nulls last, o.id desc`,
      ),
      getEtablissements(),
    ])
    offres.value = lignes
    hotels.value = Object.fromEntries(etabs.map((e) => [e.id, e]))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const lignes = computed(() => offres.value.filter((o) => !statut.value || o.statut === statut.value))
const totaux = computed(() => Object.fromEntries(
  COLONNES.map((e) => [e.code, lignes.value.reduce((t, o) => t + o[e.code], 0)])))
const hotelCourt = (id) => (hotels.value[id]?.name || '').replace(/^Sorbonne-Hôtel\s+/, '')
</script>

<template>
  <PageHeader titre="Pipeline"
              :sousTitre="`${lignes.length} DP · ${lignes.reduce((t, o) => t + o.total, 0)} candidature(s) · cliquez sur une DP pour faire avancer ses candidats`" />

  <div class="barre">
    <SelectButton v-model="statut" :options="STATUTS" optionLabel="label" optionValue="code" />
  </div>

  <DataTable :value="lignes" :loading="chargement" dataKey="id" size="small" rowHover stripedRows
             @row-click="(e) => router.push(`/rec/offre/${e.data.id}`)">
    <template #empty>Aucune DP {{ statut === 'pourvue' ? 'pourvue' : 'publiée' }}.</template>

    <Column header="DP">
      <template #body="{ data }">
        <strong class="lien">{{ data.intitule }}</strong>
        <span class="detail">n° {{ data.id }} · {{ hotelCourt(data.establishment_id) }}
          <template v-if="data.recruteur_nom"> · {{ data.recruteur_nom }}</template></span>
      </template>
    </Column>
    <Column v-for="e in COLONNES" :key="e.code" style="width: 7.5rem" :class="`col-${e.code}`">
      <template #header><span class="entete" v-tooltip.top="e.label">{{ e.court }}</span></template>
      <template #body="{ data }">
        <span v-if="data[e.code]" class="nombre" :class="e.code">{{ data[e.code] }}</span>
        <span v-else class="muet">·</span>
      </template>
      <template #footer><span class="total">{{ totaux[e.code] }}</span></template>
    </Column>
    <Column header="Total" style="width: 5rem">
      <template #body="{ data }"><strong>{{ data.total }}</strong></template>
    </Column>
  </DataTable>
</template>

<style scoped>
.barre { margin-bottom: 1rem; }
.lien { color: var(--p-primary-color); }
.detail { display: block; font-size: .78rem; color: var(--p-text-muted-color); }
.entete { font-size: .78rem; }
.nombre {
  display: inline-grid; place-items: center; min-width: 1.6rem; height: 1.6rem; padding: 0 .35rem;
  border-radius: 999px; background: var(--p-primary-100); color: var(--p-primary-700); font-weight: 600; font-size: .85rem;
}
.nombre.embauche { background: var(--p-green-100); color: var(--p-green-700); }
.nombre.refus { background: var(--p-red-100); color: var(--p-red-700); }
.muet { color: var(--p-text-muted-color); }
.total { font-weight: 600; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
