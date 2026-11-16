<!-- libelle: Propositions de postes -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getPostes, getDateReference, sql, insert, update, formatDate, toast } from '@/socle/sdk'
import { lireDossiers, libelleDossier, avancerEtape, etapeDe, STATUTS_PROPOSITION } from './_commun'

const dossiers = ref([])
const dossier = ref(null)
const propositions = ref([])
const vacants = ref([])
const dateReference = ref(null)
const enCours = ref(false)

async function chargerDossiers() {
  dossiers.value = (await lireDossiers("d.etape <> 'termine'"))
    .map((d) => ({ ...d, libelle: libelleDossier(d) }))
}

onMounted(async () => {
  try {
    const [postes, dateRef] = await Promise.all([getPostes({ vacants: true }), getDateReference()])
    vacants.value = postes
    dateReference.value = dateRef
    await chargerDossiers()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

async function chargerPropositions() {
  if (!dossier.value) { propositions.value = []; return }
  propositions.value = await sql(`
    select pr.*, p.title as poste, s.name as hotel
      from propositions pr
      join public.positions      p on p.id = pr.position_id
      left join public.establishments s on s.id = pr.establishment_id
     where pr.dossier_id = :id
     order by pr.id`, { id: dossier.value.id })
}
watch(dossier, () => chargerPropositions().catch((e) => toast.erreur(e.message)))

const dejaPropose = (positionId) => propositions.value.some((p) => p.position_id === positionId)
const aUneAcceptee = computed(() => propositions.value.some((p) => p.statut === 'acceptee'))

/* Les postes à pourvoir, hors poste visé (il a sa propre carte). */
const autresPostes = computed(() =>
  vacants.value.filter((p) => p.id !== dossier.value?.poste_vise_id))

// ── Proposer ────────────────────────────────────────────────────────────────

async function proposer(positionId, establishmentId) {
  if (dejaPropose(positionId)) {
    toast.alerte('Ce poste a déjà été proposé dans ce dossier.')
    return
  }
  enCours.value = true
  try {
    await insert('propositions', {
      dossier_id: dossier.value.id,
      position_id: positionId,
      establishment_id: establishmentId,
      statut: 'proposee',
      proposee_le: dateReference.value,
    })
    await avancerEtape(dossier.value, 'propositions')
    toast.succes('Poste proposé.')
    await chargerPropositions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}

// ── Accepter / refuser ──────────────────────────────────────────────────────

async function accepter(proposition) {
  if (aUneAcceptee.value) {
    toast.alerte('Ce dossier a déjà une proposition acceptée.')
    return
  }
  enCours.value = true
  try {
    await update('propositions', proposition.id, { statut: 'acceptee', decidee_le: dateReference.value })
    await avancerEtape(dossier.value, 'decision')
    toast.succes('Proposition acceptée : le dossier passe en décision.')
    await chargerPropositions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}

const dialogueRefus = ref(false)
const aRefuser = ref(null)
const motif = ref('')

function ouvrirRefus(proposition) {
  aRefuser.value = proposition
  motif.value = ''
  dialogueRefus.value = true
}

async function confirmerRefus() {
  if (!motif.value.trim()) {
    toast.erreur('Le commentaire est obligatoire en cas de refus.')
    return
  }
  enCours.value = true
  try {
    await update('propositions', aRefuser.value.id, {
      statut: 'refusee', commentaire: motif.value.trim(), decidee_le: dateReference.value,
    })
    dialogueRefus.value = false
    toast.succes('Proposition refusée.')
    await chargerPropositions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}
</script>

<template>
  <PageHeader titre="Propositions de postes" sousTitre="Ouvrir des opportunités concrètes au salarié" />

  <div class="entete">
    <Select v-model="dossier" :options="dossiers" optionLabel="libelle" filter showClear
            placeholder="Choisir un dossier en cours" class="choix" />
    <Tag v-if="dossier" :value="etapeDe(dossier.etape).label" :severity="etapeDe(dossier.etape).severite" />
  </div>

  <Message v-if="!dossiers.length" severity="info" :closable="false">
    Aucun dossier en cours : prenez d'abord en charge un besoin depuis l'écran Prise en charge.
  </Message>

  <template v-if="dossier">
    <!-- Le poste visé -->
    <Card class="vise">
      <template #title>Poste visé</template>
      <template #content>
        <div class="ligne">
          <div><strong>{{ dossier.poste_vise }}</strong> — {{ dossier.hotel_vise }}</div>
          <Button label="Proposer ce poste" icon="pi pi-send" size="small"
                  :disabled="enCours || dejaPropose(dossier.poste_vise_id)"
                  @click="proposer(dossier.poste_vise_id, dossier.hotel_vise_id)" />
        </div>
      </template>
    </Card>

    <!-- Les propositions du dossier -->
    <h3>Propositions faites ({{ propositions.length }})</h3>
    <DataTable :value="propositions" size="small" dataKey="id">
      <template #empty>Aucune proposition pour l'instant.</template>
      <Column field="poste" header="Poste" />
      <Column field="hotel" header="Hôtel" />
      <Column header="Proposé le" style="width: 8rem">
        <template #body="{ data }">{{ formatDate(data.proposee_le) }}</template>
      </Column>
      <Column header="Statut" style="width: 8rem">
        <template #body="{ data }">
          <Tag :value="STATUTS_PROPOSITION[data.statut]?.label" :severity="STATUTS_PROPOSITION[data.statut]?.severite" />
        </template>
      </Column>
      <Column field="commentaire" header="Commentaire" />
      <Column style="width: 13rem">
        <template #body="{ data }">
          <div v-if="data.statut === 'proposee'" class="actions">
            <Button label="Acceptée" icon="pi pi-check" size="small" severity="success" outlined
                    :disabled="enCours || aUneAcceptee" @click="accepter(data)" />
            <Button label="Refusée" icon="pi pi-times" size="small" severity="danger" outlined
                    :disabled="enCours" @click="ouvrirRefus(data)" />
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Les autres postes à pourvoir -->
    <h3>Autres postes à pourvoir ({{ autresPostes.length }})</h3>
    <DataTable :value="autresPostes" size="small" dataKey="id" paginator :rows="8">
      <Column field="title" header="Poste" />
      <Column field="job_family" header="Famille" />
      <Column field="hierarchy_level" header="Niveau" style="width: 6rem" />
      <Column field="establishment_name" header="Hôtel" />
      <Column field="vacancies" header="Places" style="width: 6rem" />
      <Column style="width: 9rem">
        <template #body="{ data }">
          <Button v-if="!dejaPropose(data.id)" label="Proposer" icon="pi pi-send" size="small" text
                  :disabled="enCours" @click="proposer(data.id, data.establishment_id)" />
          <small v-else class="discret">Déjà proposé</small>
        </template>
      </Column>
    </DataTable>
  </template>

  <Dialog v-model:visible="dialogueRefus" modal header="Proposition refusée" :style="{ width: '28rem' }">
    <p v-if="aRefuser">{{ aRefuser.poste }} — {{ aRefuser.hotel }}</p>
    <label for="motif">Commentaire (obligatoire)</label>
    <Textarea id="motif" v-model="motif" rows="3" autoResize class="plein" />
    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="dialogueRefus = false" />
      <Button label="Enregistrer le refus" severity="danger" :loading="enCours" @click="confirmerRefus" />
    </template>
  </Dialog>
</template>

<style scoped>
.entete { display: flex; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
.choix { min-width: 30rem; }
.vise { margin-bottom: 1rem; }
.ligne { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
.actions { display: flex; gap: .4rem; }
.discret { color: var(--p-text-muted-color); }
.plein { width: 100%; margin-top: .35rem; }
h3 { font-size: 1rem; margin: 1.5rem 0 .5rem; }
</style>
