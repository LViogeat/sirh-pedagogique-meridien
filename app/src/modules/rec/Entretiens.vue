<!-- libelle: Entretiens -->
<script setup>
/**
 * Le planning des entretiens de recrutement (story #106).
 *
 * Les entretiens à venir d'abord, puis les passés. Chaque ligne mène au
 * compte rendu (story #107). Un entretien se planifie d'ici ou depuis une
 * carte du Pipeline.
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { sql, update, formatDate, toast } from '@/socle/sdk'
import { assurerSchema } from './_schema.js'
import PlanifierEntretien from './_PlanifierEntretien.vue'

const router = useRouter()

const entretiens = ref([])
const chargement = ref(true)
const recruteur = ref(null)
const statut = ref(null)
const planification = ref(false)

const STATUTS = [
  { code: 'planifie', label: 'Planifié', severite: 'info' },
  { code: 'realise', label: 'Réalisé', severite: 'success' },
  { code: 'annule', label: 'Annulé', severite: 'secondary' },
]
const AVIS = {
  favorable: { label: 'Favorable', severite: 'success' },
  reserve: { label: 'Réservé', severite: 'warn' },
  defavorable: { label: 'Défavorable', severite: 'danger' },
}
const statutDe = (code) => STATUTS.find((s) => s.code === code)

async function charger() {
  chargement.value = true
  try {
    entretiens.value = await sql(
      `select e.id, e.date_heure, e.lieu, e.recruteur_id, e.recruteur_nom, e.statut, e.avis,
              c.id as candidat_id, c.prenom, c.nom, o.intitule
         from entretiens e
         join candidatures ca on ca.id = e.candidature_id
         join candidats c on c.id = ca.candidat_id
         join offres o on o.id = ca.offre_id
        order by (e.statut = 'planifie') desc,
                 case when e.statut = 'planifie' then e.date_heure end asc,
                 e.date_heure desc`,
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
    entretiens.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => { await assurerSchema(); await charger() })

const recruteurs = computed(() =>
  [...new Map(entretiens.value.map((e) => [e.recruteur_id, { id: e.recruteur_id, nom: e.recruteur_nom }])).values()]
    .sort((a, b) => a.nom.localeCompare(b.nom)))

const lignes = computed(() => entretiens.value.filter((e) =>
  (!recruteur.value || e.recruteur_id === recruteur.value) && (!statut.value || e.statut === statut.value)))

const aVenir = computed(() => entretiens.value.filter((e) => e.statut === 'planifie').length)

const heure = (v) => new Date(v).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })

async function annuler(entretien) {
  try {
    await update('entretiens', entretien.id, { statut: 'annule' })
    toast.info(`Entretien de ${entretien.prenom} ${entretien.nom} annulé`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader titre="Entretiens"
              :sousTitre="`${entretiens.length} entretien(s) · ${aVenir} à venir`" />

  <div class="barre">
    <Select v-model="recruteur" :options="recruteurs" optionLabel="nom" optionValue="id"
            placeholder="Tous les recruteurs" showClear />
    <Select v-model="statut" :options="STATUTS" optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
    <Button label="Planifier un entretien" icon="pi pi-calendar-plus" class="droite"
            @click="planification = true" />
  </div>

  <DataTable :value="lignes" :loading="chargement" dataKey="id" size="small" stripedRows rowHover
             @row-click="(e) => router.push(`/rec/entretien/${e.data.id}`)">
    <template #empty>Aucun entretien. Planifiez-en un ici ou depuis une carte du Pipeline.</template>

    <Column header="Date" style="width: 11rem">
      <template #body="{ data }">
        <strong>{{ formatDate(data.date_heure) }}</strong> à {{ heure(data.date_heure) }}
      </template>
    </Column>
    <Column header="Candidat">
      <template #body="{ data }">
        <a href="#" class="lien" @click.stop.prevent="router.push(`/rec/candidat/${data.candidat_id}`)">
          {{ data.prenom }} {{ data.nom }}
        </a>
      </template>
    </Column>
    <Column field="intitule" header="Offre" />
    <Column field="recruteur_nom" header="Recruteur" />
    <Column field="lieu" header="Lieu">
      <template #body="{ data }">{{ data.lieu || '—' }}</template>
    </Column>
    <Column header="Statut" style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="statutDe(data.statut).label" :severity="statutDe(data.statut).severite" />
      </template>
    </Column>
    <Column header="Avis" style="width: 8rem">
      <template #body="{ data }">
        <Tag v-if="data.avis" :value="AVIS[data.avis].label" :severity="AVIS[data.avis].severite" />
        <span v-else class="muet">—</span>
      </template>
    </Column>
    <Column style="width: 12rem">
      <template #body="{ data }">
        <div class="actions" @click.stop>
          <Button :label="data.statut === 'realise' ? 'Compte rendu' : 'Rédiger le compte rendu'"
                  icon="pi pi-file-edit" size="small" text :disabled="data.statut === 'annule'"
                  @click="router.push(`/rec/entretien/${data.id}`)" />
          <Button v-if="data.statut === 'planifie'" icon="pi pi-times" size="small" text severity="danger"
                  v-tooltip.top="'Annuler l’entretien'" @click="annuler(data)" />
        </div>
      </template>
    </Column>
  </DataTable>

  <PlanifierEntretien v-model:visible="planification" @planifie="charger" />
</template>

<style scoped>
.barre { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.barre > .p-select { min-width: 13rem; }
.droite { margin-left: auto; }
.lien { color: var(--p-primary-color); text-decoration: none; font-weight: 500; }
.lien:hover { text-decoration: underline; }
.actions { display: flex; }
.muet { color: var(--p-text-muted-color); }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
