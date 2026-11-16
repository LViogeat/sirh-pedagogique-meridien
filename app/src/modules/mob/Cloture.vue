<!-- libelle: Clôture des dossiers -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { cloturerBesoin, getSalarie, getDateReference, sql, insert, update,
         formatDate, toast } from '@/socle/sdk'
import { lireDossiers, etapeDe, ISSUES, joursEntre, enDate, enDateIso } from './_commun'

const dossiers = ref([])
const acceptees = ref({})         // dossier_id → proposition acceptée
const dateReference = ref(null)
const chargement = ref(true)
const enCours = ref(false)

async function charger() {
  chargement.value = true
  try {
    const [liste, props, dateRef] = await Promise.all([
      lireDossiers("d.etape <> 'termine'"),
      sql(`select pr.*, p.title as poste, s.name as hotel
             from propositions pr
             join public.positions p on p.id = pr.position_id
             left join public.establishments s on s.id = pr.establishment_id
            where pr.statut = 'acceptee'`),
      getDateReference(),
    ])
    dossiers.value = liste
    acceptees.value = Object.fromEntries(props.map((p) => [p.dossier_id, p]))
    dateReference.value = dateRef
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}
onMounted(charger)

// ── Le formulaire de clôture ────────────────────────────────────────────────

const dialogue = ref(false)
const dossier = ref(null)
const issue = ref(null)
const commentaire = ref('')
const dateEffet = ref(null)

const propositionAcceptee = computed(() => (dossier.value ? acceptees.value[dossier.value.id] : null))

/* « Réalisée » n'est possible que si une proposition a été acceptée. */
const issuesPossibles = computed(() =>
  ISSUES.map((i) => ({ ...i, desactivee: i.code === 'realisee' && !propositionAcceptee.value })))

function ouvrir(d) {
  dossier.value = d
  issue.value = null
  commentaire.value = ''
  dateEffet.value = enDate(dateReference.value)
  dialogue.value = true
}

async function valider() {
  if (!issue.value || !commentaire.value.trim()) {
    toast.erreur('L\'issue et le commentaire sont obligatoires.')
    return
  }
  const realisee = issue.value === 'realisee'
  if (realisee && (!propositionAcceptee.value || !dateEffet.value)) {
    toast.erreur('Une mobilité réalisée demande une proposition acceptée et une date d\'effet.')
    return
  }
  const d = dossier.value
  enCours.value = true
  try {
    // Le poste actuel du salarié, lu AVANT toute écriture (c'est le poste de départ).
    const salarie = realisee ? await getSalarie(d.employee_id) : null

    // 1. Le socle d'abord : s'il refuse, nos tables ne sont pas touchées.
    await cloturerBesoin(d.besoin_id, commentaire.value.trim())

    // 2. Le dossier passe à « terminé ».
    await update('dossiers', d.id, {
      etape: 'termine',
      issue: issue.value,
      commentaire: commentaire.value.trim(),
      clos_le: dateReference.value,
    })

    // 3. La mobilité, si elle est réalisée.
    if (realisee) {
      await insert('mobilites', {
        dossier_id: d.id,
        position_depart_id: salarie.position_id,
        establishment_depart_id: salarie.establishment_id,
        position_arrivee_id: propositionAcceptee.value.position_id,
        establishment_arrivee_id: propositionAcceptee.value.establishment_id,
        date_effet: enDateIso(dateEffet.value),
      })
    }
    toast.succes(`Dossier de ${d.salarie} clôturé.`)
    dialogue.value = false
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}
</script>

<template>
  <PageHeader titre="Clôture des dossiers"
              :sousTitre="`${dossiers.length} dossier(s) non terminé(s)`" />

  <DataTable :value="dossiers" :loading="chargement" dataKey="id" stripedRows size="small">
    <template #empty>Aucun dossier à clôturer.</template>
    <Column header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.salarie }}</div>
        <small class="discret">{{ data.matricule }}</small>
      </template>
    </Column>
    <Column field="poste_vise" header="Poste visé" />
    <Column field="hotel_vise" header="Hôtel visé" />
    <Column header="Étape" style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="etapeDe(data.etape).label" :severity="etapeDe(data.etape).severite" />
      </template>
    </Column>
    <Column header="Proposition acceptée">
      <template #body="{ data }">
        <span v-if="acceptees[data.id]">{{ acceptees[data.id].poste }} — {{ acceptees[data.id].hotel }}</span>
        <span v-else class="discret">Aucune</span>
      </template>
    </Column>
    <Column field="conseiller" header="Conseiller" />
    <Column header="Ouvert depuis" style="width: 8rem">
      <template #body="{ data }">{{ joursEntre(data.ouvert_le, dateReference) }} j</template>
    </Column>
    <Column style="width: 8rem">
      <template #body="{ data }">
        <Button label="Clôturer" icon="pi pi-flag" size="small" @click="ouvrir(data)" />
      </template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogue" modal header="Clôturer le dossier" :style="{ width: '32rem' }">
    <p v-if="dossier"><strong>{{ dossier.salarie }}</strong> — vise {{ dossier.poste_vise }}</p>

    <div class="champ">
      <label>Issue</label>
      <Select v-model="issue" :options="issuesPossibles" optionLabel="label" optionValue="code"
              optionDisabled="desactivee" placeholder="Choisir l'issue" />
      <small v-if="!propositionAcceptee" class="discret">
        « Réalisée » demande une proposition acceptée (écran Propositions de postes).
      </small>
    </div>

    <template v-if="issue === 'realisee' && propositionAcceptee">
      <div class="champ">
        <label>Poste et hôtel d'arrivée</label>
        <InputText :modelValue="`${propositionAcceptee.poste} — ${propositionAcceptee.hotel}`" disabled />
      </div>
      <div class="champ">
        <label>Date d'effet</label>
        <DatePicker v-model="dateEffet" dateFormat="dd/mm/yy" showIcon />
      </div>
    </template>

    <div class="champ">
      <label>Commentaire</label>
      <Textarea v-model="commentaire" rows="3" autoResize />
    </div>

    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="dialogue = false" />
      <Button label="Clôturer" icon="pi pi-flag" :loading="enCours" @click="valider" />
    </template>
  </Dialog>
</template>

<style scoped>
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.champ { display: flex; flex-direction: column; gap: .35rem; margin-top: 1rem; }
</style>
