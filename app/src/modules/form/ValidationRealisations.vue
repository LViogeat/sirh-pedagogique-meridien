<!-- libelle: Validation des réalisations -->
<script setup>
/**
 * Deux stories du Responsable RH d'établissement, qui se suivent :
 *
 *   #62 — après la session, enregistrer les présences et les absences à
 *         partir de la feuille d'émargement ;
 *   #64 — valider la réalisation effective de la formation pour chaque
 *         participant, une fois l'émargement vérifié.
 *
 * On choisit une session. Pour chaque participant, on reporte d'abord ce que
 * dit la feuille d'émargement (colonne Présence), puis on valide ou non la
 * réalisation (colonne Réalisation). Seule une réalisation validée entre
 * dans l'historique du collaborateur et compte pour ses formations
 * obligatoires.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, update, getSalaries, getEtablissements, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, STATUTS_SESSION, PRESENCES, REALISATIONS,
  libelle, couleur, horaires, periode, enIso, sessionCouranteId, etablissementCourantId,
} from './_donnees'

const etablissements = ref([])
const sessions = ref([])
const salaries = ref([])
const lignes = ref([])
const chargement = ref(true)
const chargementParticipants = ref(false)

async function chargerLesSessions() {
  const toutes = await chargerSessions()
  sessions.value = toutes
    .filter((s) => s.statut !== 'annulee')
    .map((s) => ({
      ...s,
      affichage: `${s.formation} — ${periode(s, formatDate)} — ${s.etablissement ?? ''}`,
    }))
}

async function chargerParticipants() {
  if (!sessionCouranteId.value) {
    lignes.value = []
    return
  }
  chargementParticipants.value = true
  try {
    lignes.value = await sql(
      `select i.id, i.employee_id, i.presence, i.realisation, i.realisation_le,
              e.first_name || ' ' || e.last_name as salarie,
              e.matricule
       from   inscriptions i
       join   public.employees e on e.id = i.employee_id
       where  i.session_id = :session
       and    i.statut = 'validee'
       order by e.last_name, e.first_name`,
      { session: sessionCouranteId.value },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargementParticipants.value = false
  }
}

onMounted(async () => {
  try {
    await preparerSchema()
    etablissements.value = await getEtablissements()
    await chargerLesSessions()
    if (!sessions.value.some((s) => s.id === sessionCouranteId.value)) {
      sessionCouranteId.value = null
    }
    salaries.value = await getSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
  await chargerParticipants()
})

watch(sessionCouranteId, chargerParticipants)

/** Les sessions de l'établissement choisi (toutes si aucun n'est choisi). */
const sessionsProposees = computed(() =>
  sessions.value.filter((s) =>
    !etablissementCourantId.value || s.establishment_id === etablissementCourantId.value))

const session = computed(
  () => sessions.value.find((s) => s.id === sessionCouranteId.value) ?? null,
)

const participants = computed(() =>
  lignes.value.map((p) => {
    const s = salaries.value.find((x) => x.id === p.employee_id)
    return { ...p, poste: s?.position_title ?? '—', etablissement: s?.establishment_name ?? '—' }
  }))

const compte = computed(() => ({
  inscrits: lignes.value.length,
  presents: lignes.value.filter((p) => p.presence === 'present').length,
  absents: lignes.value.filter((p) => p.presence && p.presence !== 'present').length,
  sansPresence: lignes.value.filter((p) => !p.presence).length,
  validees: lignes.value.filter((p) => p.realisation === 'validee').length,
  aValider: lignes.value.filter((p) => p.presence === 'present' && !p.realisation).length,
}))

function ligneDe(participant) {
  return lignes.value.find((p) => p.id === participant.id)
}

// ── #62 : reporter la feuille d'émargement ───────────────────────────────────

async function noterPresence(participant, presence) {
  const ligne = ligneDe(participant)
  const avant = { presence: ligne.presence, realisation: ligne.realisation,
                  realisation_le: ligne.realisation_le }
  // Si la présence change, la validation déjà donnée ne vaut plus.
  const donnees = { presence, realisation: null, realisation_le: null }
  Object.assign(ligne, donnees)
  try {
    await update('inscriptions', participant.id, donnees)
  } catch (erreur) {
    Object.assign(ligne, avant)
    toast.erreur(erreur.message)
  }
}

// ── #64 : valider la réalisation ─────────────────────────────────────────────

async function noterRealisation(participant, realisation) {
  const ligne = ligneDe(participant)
  if (realisation === 'validee' && ligne.presence !== 'present') {
    toast.alerte('On ne peut valider la réalisation que d’un participant noté présent.')
    return
  }
  const avant = { realisation: ligne.realisation, realisation_le: ligne.realisation_le }
  const donnees = {
    realisation,
    realisation_le: realisation ? enIso(new Date()) : null,
  }
  Object.assign(ligne, donnees)
  try {
    await update('inscriptions', participant.id, donnees)
  } catch (erreur) {
    Object.assign(ligne, avant)
    toast.erreur(erreur.message)
  }
}

async function validerLesPresents() {
  try {
    await sql(
      `update inscriptions
       set    realisation = 'validee', realisation_le = current_date
       where  session_id = :session
       and    statut = 'validee'
       and    presence = 'present'
       and    realisation is null`,
      { session: sessionCouranteId.value },
    )
    // Les absents ne peuvent pas avoir réalisé la formation.
    await sql(
      `update inscriptions
       set    realisation = 'non_validee', realisation_le = current_date
       where  session_id = :session
       and    statut = 'validee'
       and    presence in ('absent', 'absent_justifie')
       and    realisation is null`,
      { session: sessionCouranteId.value },
    )
    toast.succes('Réalisation validée pour tous les participants présents')
    await chargerParticipants()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

async function terminerSession() {
  try {
    await update('sessions', session.value.id, { statut: 'terminee' })
    toast.succes('La session est terminée')
    await chargerLesSessions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Validation des réalisations"
    sousTitre="Reporter la feuille d’émargement, puis valider la formation de chaque participant"
  >
    <template v-if="session && participants.length">
      <Button label="Valider tous les présents" icon="pi pi-check-circle"
              :disabled="compte.sansPresence > 0 || (compte.aValider === 0 && compte.absents === 0)"
              v-tooltip.bottom="compte.sansPresence > 0
                ? 'Renseignez d’abord la présence de tous les participants' : null"
              @click="validerLesPresents" />
      <Button v-if="session.statut !== 'terminee'" label="Terminer la session"
              icon="pi pi-lock" severity="secondary" outlined @click="terminerSession" />
    </template>
  </PageHeader>

  <div class="filtres">
    <Select v-model="etablissementCourantId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="sessionCouranteId" :options="sessionsProposees"
            optionLabel="affichage" optionValue="id" filter showClear
            :loading="chargement" placeholder="Choisir une session de formation"
            emptyMessage="Aucune session pour cet établissement" class="large" />
    <Tag v-if="session" :value="libelle(STATUTS_SESSION, session.statut)"
         :severity="couleur(STATUTS_SESSION, session.statut)" />
  </div>

  <Message v-if="!session && !chargement" severity="info" :closable="false">
    Choisissez une session pour reporter sa feuille d’émargement et valider les réalisations.
  </Message>

  <template v-if="session">
    <p class="chapo">
      {{ session.formation }} · {{ periode(session, formatDate) }} · {{ horaires(session) }} ·
      {{ session.etablissement }}<template v-if="session.salle"> · {{ session.salle }}</template>
      <template v-if="session.formateur"> · formateur : {{ session.formateur }}</template>
    </p>

    <div class="stats">
      <StatCard titre="Participants inscrits" :valeur="compte.inscrits" icone="pi pi-users" />
      <StatCard titre="Présents" :valeur="compte.presents" icone="pi pi-check"
                :precision="`${compte.absents} absent(s) · ${compte.sansPresence} non renseigné(s)`" />
      <StatCard titre="Réalisations validées" :valeur="compte.validees" icone="pi pi-verified" />
      <StatCard titre="En attente de validation" :valeur="compte.aValider" icone="pi pi-hourglass" />
    </div>

    <DataTable :value="participants" :loading="chargementParticipants" dataKey="id"
               stripedRows size="small">
      <template #empty>
        Aucun participant inscrit à cette session.
      </template>

      <Column field="salarie" header="Participant" />
      <Column field="matricule" header="Matricule" style="width: 8rem" />
      <Column field="poste" header="Poste" />

      <Column header="1. Présence (feuille d’émargement)" style="width: 24rem">
        <template #body="{ data }">
          <SelectButton :modelValue="data.presence" :options="PRESENCES"
                        optionLabel="label" optionValue="code" size="small"
                        @update:modelValue="(valeur) => noterPresence(data, valeur)" />
        </template>
      </Column>

      <Column header="2. Réalisation" style="width: 19rem">
        <template #body="{ data }">
          <div class="realisation">
            <template v-if="data.realisation">
              <Tag :value="libelle(REALISATIONS, data.realisation)"
                   :severity="couleur(REALISATIONS, data.realisation)" />
              <span class="discret">le {{ formatDate(data.realisation_le) }}</span>
              <Button icon="pi pi-undo" text rounded size="small" severity="secondary"
                      aria-label="Revenir sur la validation"
                      v-tooltip.left="'Revenir sur la validation'"
                      @click="noterRealisation(data, null)" />
            </template>
            <template v-else-if="data.presence">
              <Button label="Valider" icon="pi pi-check" size="small" severity="success"
                      :disabled="data.presence !== 'present'"
                      @click="noterRealisation(data, 'validee')" />
              <Button label="Ne pas valider" size="small" text severity="danger"
                      @click="noterRealisation(data, 'non_validee')" />
            </template>
            <span v-else class="discret">Renseignez d’abord la présence</span>
          </div>
        </template>
      </Column>
    </DataTable>
  </template>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.filtres > .p-select.large { min-width: 32rem; max-width: 100%; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.realisation { display: flex; align-items: center; gap: .4rem; flex-wrap: wrap; }
.discret { color: var(--p-text-muted-color); font-size: .85rem; }
</style>
