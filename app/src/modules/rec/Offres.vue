<!-- libelle: Offres d'emploi -->
<script setup>
/**
 * Les offres d'emploi du module (story #5).
 *
 * Une offre naît en brouillon depuis l'écran « Besoins à traiter ». Ici on la
 * complète (intitulé, type de contrat, description), on la publie, ou on
 * l'annule. Annuler une offre relâche son besoin dans le socle : il redevient
 * disponible et pourra être repris.
 */
import { ref, computed, onMounted, watch } from 'vue'
import {
  getEtablissements, getReferentiels, relacherBesoin,
  sql, update, formatDate, toast,
} from '@/socle/sdk'

const offres = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)
const statut = ref(null)

const STATUTS = [
  { code: 'brouillon', label: 'Brouillon', severite: 'secondary' },
  { code: 'publiee', label: 'Publiée', severite: 'success' },
  { code: 'pourvue', label: 'Pourvue', severite: 'info' },
  { code: 'annulee', label: 'Annulée', severite: 'danger' },
]
const statutDe = (code) => STATUTS.find((s) => s.code === code) || { label: code, severite: 'secondary' }

async function charger() {
  chargement.value = true
  try {
    offres.value = await sql(
      `select o.*, count(c.id)::int as nb_candidatures
         from offres o
         left join candidatures c on c.offre_id = o.id
        where (cast(:statut as text) is null or o.statut = :statut)
        group by o.id
        order by o.id desc`,
      { statut: statut.value },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
    offres.value = []
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

watch(statut, charger)

const hotelDe = computed(() => Object.fromEntries(etablissements.value.map((e) => [e.id, e])))
const libelleContrat = (code) =>
  (referentiels.value.type_contrat || []).find((t) => t.code === code)?.label || code

const compteurs = computed(() => ({
  brouillons: offres.value.filter((o) => o.statut === 'brouillon').length,
  publiees: offres.value.filter((o) => o.statut === 'publiee').length,
  pourvues: offres.value.filter((o) => o.statut === 'pourvue').length,
}))

/* ── Modifier une offre ─────────────────────────────────────────────────── */

const edition = ref(null)      // copie de l'offre en cours de modification
const enregistrement = ref(false)

function ouvrir(offre) {
  edition.value = {
    id: offre.id,
    intitule: offre.intitule,
    type_contrat: offre.type_contrat,
    description: offre.description || '',
    statut: offre.statut,
  }
}

async function enregistrer() {
  if (!edition.value.intitule?.trim()) {
    toast.alerte("L'intitulé est obligatoire.")
    return
  }
  enregistrement.value = true
  try {
    await update('offres', edition.value.id, {
      intitule: edition.value.intitule.trim(),
      type_contrat: edition.value.type_contrat,
      description: edition.value.description.trim() || null,
    })
    toast.succes(`Offre n° ${edition.value.id} enregistrée`)
    edition.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/* ── Changer le statut ──────────────────────────────────────────────────── */

const enCours = ref(null)

async function publier(offre) {
  enCours.value = offre.id
  try {
    await sql(
      "update offres set statut = 'publiee', publiee_le = current_date where id = :id",
      { id: offre.id },
    )
    toast.succes(`Offre n° ${offre.id} publiée`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}

async function annuler(offre) {
  enCours.value = offre.id
  try {
    await update('offres', offre.id, { statut: 'annulee' })
    if (offre.besoin_id) {
      await relacherBesoin(offre.besoin_id)
    }
    toast.info(`Offre n° ${offre.id} annulée. Le besoin redevient disponible.`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}
</script>

<template>
  <PageHeader
    titre="Offres d'emploi"
    :sousTitre="`${offres.length} offre(s) · ${compteurs.publiees} publiée(s)`"
  />

  <div class="stats">
    <StatCard titre="Brouillons" :valeur="compteurs.brouillons" icone="pi pi-pencil" precision="à compléter et publier" />
    <StatCard titre="Publiées" :valeur="compteurs.publiees" icone="pi pi-megaphone" precision="ouvertes aux candidatures" />
    <StatCard titre="Pourvues" :valeur="compteurs.pourvues" icone="pi pi-check-circle" precision="recrutement abouti" />
  </div>

  <div class="filtres">
    <Select v-model="statut" :options="STATUTS"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
  </div>

  <DataTable :value="offres" :loading="chargement" dataKey="id"
             paginator :rows="20" removableSort stripedRows size="small" rowHover
             @row-click="(e) => ouvrir(e.data)">
    <template #empty>
      Aucune offre. Une offre se crée en prenant en charge un besoin dans l'écran « Besoins à traiter ».
    </template>

    <Column field="id" header="N°" sortable style="width: 4rem" />
    <Column field="intitule" header="Intitulé" sortable />

    <Column header="Établissement">
      <template #body="{ data }">
        {{ hotelDe[data.establishment_id]?.name || '—' }}
        <span class="ville">{{ hotelDe[data.establishment_id]?.city }}</span>
      </template>
    </Column>

    <Column field="type_contrat" header="Contrat" sortable style="width: 9rem">
      <template #body="{ data }">{{ libelleContrat(data.type_contrat) }}</template>
    </Column>

    <Column field="besoin_id" header="Besoin" style="width: 6rem">
      <template #body="{ data }">{{ data.besoin_id ? `n° ${data.besoin_id}` : '—' }}</template>
    </Column>

    <Column field="statut" header="Statut" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="statutDe(data.statut).label" :severity="statutDe(data.statut).severite" />
      </template>
    </Column>

    <Column field="publiee_le" header="Publiée le" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.publiee_le) }}</template>
    </Column>

    <Column field="nb_candidatures" header="Candidatures" sortable style="width: 8rem" />

    <Column header="Actions" style="width: 15rem">
      <template #body="{ data }">
        <div class="actions" @click.stop>
          <Button v-if="data.statut === 'brouillon'" label="Publier" icon="pi pi-send"
                  size="small" :loading="enCours === data.id" :disabled="enCours !== null"
                  @click="publier(data)" />
          <Button v-if="['brouillon', 'publiee'].includes(data.statut)" label="Annuler"
                  icon="pi pi-times" size="small" severity="secondary" text
                  :disabled="enCours !== null" @click="annuler(data)" />
        </div>
      </template>
    </Column>
  </DataTable>

  <Dialog :visible="!!edition" modal :style="{ width: '36rem' }"
          :header="edition ? `Offre n° ${edition.id}` : ''"
          @update:visible="edition = null">
    <form v-if="edition" class="formulaire" @submit.prevent="enregistrer">
      <label for="intitule">Intitulé</label>
      <InputText id="intitule" v-model="edition.intitule" />

      <label for="contrat">Type de contrat</label>
      <Select inputId="contrat" v-model="edition.type_contrat"
              :options="referentiels.type_contrat" optionLabel="label" optionValue="code" />

      <label for="description">Description du poste</label>
      <Textarea id="description" v-model="edition.description" rows="6" autoResize
                placeholder="Missions, profil recherché, horaires, rémunération…" />

      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="edition = null" />
        <Button label="Enregistrer" icon="pi pi-check" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
.ville { display: block; font-size: .8rem; color: var(--p-text-muted-color); }
.actions { display: flex; gap: .25rem; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
