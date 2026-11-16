<!-- libelle: Mobilités réalisées -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { getEtablissements, sql, formatDate, toast } from '@/socle/sdk'
import { joursEntre, typeEchangeDe, STATUTS_PROPOSITION } from './_commun'

const mobilites = ref([])
const etablissements = ref([])
const hotelArrivee = ref(null)
const chargement = ref(true)

onMounted(async () => {
  try {
    const [hotels, lignes] = await Promise.all([
      getEtablissements(),
      sql(`
        select m.*, d.conseiller, d.ouvert_le, d.clos_le,
               e.first_name || ' ' || e.last_name as salarie, e.matricule,
               pd.title as poste_depart,  sd.name as hotel_depart,
               pa.title as poste_arrivee, sa.name as hotel_arrivee
          from mobilites m
          join dossiers d               on d.id = m.dossier_id
          join public.employees e       on e.id = d.employee_id
          left join public.positions pd      on pd.id = m.position_depart_id
          left join public.establishments sd on sd.id = m.establishment_depart_id
          join public.positions pa           on pa.id = m.position_arrivee_id
          left join public.establishments sa on sa.id = m.establishment_arrivee_id
         order by m.date_effet desc, m.id desc`),
    ])
    etablissements.value = hotels
    mobilites.value = lignes
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const lignes = computed(() =>
  hotelArrivee.value == null
    ? mobilites.value
    : mobilites.value.filter((m) => m.establishment_arrivee_id === hotelArrivee.value))

// ── Le dossier d'une mobilité ───────────────────────────────────────────────

const dialogue = ref(false)
const choisie = ref(null)
const propositions = ref([])
const echanges = ref([])

async function ouvrir({ data }) {
  choisie.value = data
  dialogue.value = true
  try {
    ;[propositions.value, echanges.value] = await Promise.all([
      sql(`select pr.*, p.title as poste, s.name as hotel
             from propositions pr
             join public.positions p on p.id = pr.position_id
             left join public.establishments s on s.id = pr.establishment_id
            where pr.dossier_id = :id order by pr.id`, { id: data.dossier_id }),
      sql('select * from echanges where dossier_id = :id order by date_echange desc, id desc',
          { id: data.dossier_id }),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader titre="Mobilités réalisées"
              :sousTitre="`${lignes.length} mobilité(s) réalisée(s)`" />

  <div class="filtres">
    <Select v-model="hotelArrivee" :options="etablissements" optionLabel="name" optionValue="id"
            placeholder="Tous les hôtels d'arrivée" showClear />
  </div>

  <DataTable :value="lignes" :loading="chargement" dataKey="id" stripedRows size="small"
             selectionMode="single" @rowClick="ouvrir">
    <template #empty>Aucune mobilité réalisée pour l'instant : elles apparaissent à la clôture d'un dossier.</template>
    <Column header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.salarie }}</div>
        <small class="discret">{{ data.matricule }}</small>
      </template>
    </Column>
    <Column header="Départ">
      <template #body="{ data }">
        {{ data.poste_depart || '—' }}<br /><small class="discret">{{ data.hotel_depart || '' }}</small>
      </template>
    </Column>
    <Column header="" style="width: 2rem"><template #body><i class="pi pi-arrow-right discret" /></template></Column>
    <Column header="Arrivée">
      <template #body="{ data }">
        {{ data.poste_arrivee }}<br /><small class="discret">{{ data.hotel_arrivee || '' }}</small>
      </template>
    </Column>
    <Column header="Date d'effet" style="width: 9rem">
      <template #body="{ data }">{{ formatDate(data.date_effet) }}</template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogue" modal :style="{ width: '44rem' }"
          :header="choisie ? `Dossier de ${choisie.salarie}` : 'Dossier'">
    <template v-if="choisie">
      <dl class="detail">
        <dt>Conseiller</dt><dd>{{ choisie.conseiller }}</dd>
        <dt>Accompagnement</dt>
        <dd>{{ joursEntre(choisie.ouvert_le, choisie.clos_le) ?? '—' }} jours
            (du {{ formatDate(choisie.ouvert_le) }} au {{ formatDate(choisie.clos_le) }})</dd>
      </dl>

      <h4>Propositions faites</h4>
      <DataTable :value="propositions" size="small" dataKey="id">
        <template #empty>Aucune proposition.</template>
        <Column field="poste" header="Poste" />
        <Column field="hotel" header="Hôtel" />
        <Column header="Statut">
          <template #body="{ data }">
            <Tag :value="STATUTS_PROPOSITION[data.statut]?.label" :severity="STATUTS_PROPOSITION[data.statut]?.severite" />
          </template>
        </Column>
        <Column field="commentaire" header="Commentaire" />
      </DataTable>

      <h4>Échanges</h4>
      <p v-if="!echanges.length" class="discret">Aucun échange.</p>
      <div v-for="e in echanges" :key="e.id" class="echange">
        <strong>{{ typeEchangeDe(e.type_echange).label }}</strong>
        <span class="discret"> · {{ formatDate(e.date_echange) }}</span>
        <div>{{ e.compte_rendu }}</div>
      </div>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { margin-bottom: 1rem; }
.filtres > * { min-width: 15rem; }
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.detail { display: grid; grid-template-columns: 9rem 1fr; gap: .45rem 1rem; margin: 0; }
.detail dt { font-weight: 600; color: var(--p-text-muted-color); }
.detail dd { margin: 0; }
.echange { border-left: 3px solid var(--p-primary-color); padding-left: .7rem; margin-bottom: .7rem; }
h4 { margin: 1.2rem 0 .4rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
