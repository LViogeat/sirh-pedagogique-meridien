<!-- libelle: Présences et absences -->
<script setup>
/**
 * Story #39 — Le formateur interne renseigne les présences et les absences
 * des participants, pour garder la trace de qui a suivi la formation.
 *
 * On choisit une session : la liste des participants inscrits s'affiche, et
 * on coche pour chacun Présent, Absent ou Absent justifié. Chaque choix est
 * enregistré tout de suite. Une présence compte ensuite comme « formation
 * réalisée » sur l'écran des formations obligatoires.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, update, getSalaries, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, STATUTS_SESSION, PRESENCES,
  libelle, couleur, horaires, periode, sessionCouranteId,
} from './_donnees'

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
      `select i.id, i.employee_id, i.presence, i.commentaire,
              e.first_name || ' ' || e.last_name as salarie,
              e.last_name, e.matricule
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

const session = computed(
  () => sessions.value.find((s) => s.id === sessionCouranteId.value) ?? null,
)

/** Les participants, complétés de leur poste et de leur établissement. */
const participants = computed(() =>
  lignes.value.map((p) => {
    const s = salaries.value.find((x) => x.id === p.employee_id)
    return {
      ...p,
      poste: s?.position_title ?? '—',
      etablissement: s?.establishment_name ?? '—',
    }
  }))

const compte = computed(() => ({
  inscrits: lignes.value.length,
  presents: lignes.value.filter((p) => p.presence === 'present').length,
  absents: lignes.value.filter((p) => p.presence === 'absent').length,
  justifies: lignes.value.filter((p) => p.presence === 'absent_justifie').length,
  aRenseigner: lignes.value.filter((p) => !p.presence).length,
}))

// ── Renseigner les présences ─────────────────────────────────────────────────

async function noter(participant, presence) {
  const ligne = lignes.value.find((p) => p.id === participant.id)
  const avant = ligne.presence
  ligne.presence = presence          // on affiche tout de suite…
  try {
    await update('inscriptions', participant.id, { presence })
  } catch (erreur) {
    ligne.presence = avant           // …et on revient en arrière si ça échoue
    toast.erreur(erreur.message)
  }
}

async function noterCommentaire(participant, texte) {
  const propre = (texte ?? '').trim() || null
  if (propre === (participant.commentaire ?? null)) return
  try {
    await update('inscriptions', participant.id, { commentaire: propre })
    const ligne = lignes.value.find((p) => p.id === participant.id)
    if (ligne) ligne.commentaire = propre
    toast.succes('Commentaire enregistré')
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

async function tousPresents() {
  try {
    await sql(
      `update inscriptions set presence = 'present'
       where  session_id = :session and statut = 'validee' and presence is null`,
      { session: sessionCouranteId.value },
    )
    toast.succes('Les participants non renseignés sont notés présents')
    await chargerParticipants()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

async function terminer() {
  if (compte.value.aRenseigner > 0) {
    toast.alerte(`Il reste ${compte.value.aRenseigner} participant(s) sans présence renseignée.`)
    return
  }
  try {
    await update('sessions', session.value.id, { statut: 'terminee' })
    toast.succes('Feuille de présence clôturée, la session est terminée')
    await chargerLesSessions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Présences et absences"
    sousTitre="La feuille de présence d’une session, remplie par le formateur"
  >
    <template v-if="session && participants.length">
      <Button label="Tous présents" icon="pi pi-check-circle" severity="secondary" outlined
              :disabled="compte.aRenseigner === 0" @click="tousPresents" />
      <Button v-if="session.statut !== 'terminee'" label="Clôturer la feuille"
              icon="pi pi-lock" @click="terminer" />
    </template>
  </PageHeader>

  <div class="filtres">
    <Select v-model="sessionCouranteId" :options="sessions"
            optionLabel="affichage" optionValue="id" filter showClear
            :loading="chargement" placeholder="Choisir une session de formation"
            emptyMessage="Aucune session : créez-en une dans « Sessions de formation »" />
    <Tag v-if="session" :value="libelle(STATUTS_SESSION, session.statut)"
         :severity="couleur(STATUTS_SESSION, session.statut)" />
  </div>

  <Message v-if="!session && !chargement" severity="info" :closable="false">
    Choisissez une session pour remplir sa feuille de présence.
  </Message>

  <template v-if="session">
    <p class="chapo">
      {{ session.formation }} · {{ periode(session, formatDate) }} · {{ horaires(session) }} ·
      {{ session.etablissement }}<template v-if="session.salle"> · {{ session.salle }}</template>
      <template v-if="session.formateur"> · formateur : {{ session.formateur }}</template>
    </p>

    <div class="stats">
      <StatCard titre="Participants inscrits" :valeur="compte.inscrits" icone="pi pi-users" />
      <StatCard titre="Présents" :valeur="compte.presents" icone="pi pi-check" />
      <StatCard titre="Absents" :valeur="compte.absents + compte.justifies" icone="pi pi-times"
                :precision="compte.justifies ? `dont ${compte.justifies} justifié(s)` : ''" />
      <StatCard titre="À renseigner" :valeur="compte.aRenseigner" icone="pi pi-question-circle" />
    </div>

    <DataTable :value="participants" :loading="chargementParticipants" dataKey="id"
               stripedRows size="small">
      <template #empty>
        Aucun participant inscrit à cette session. Les inscriptions se font dans
        « Inscriptions aux sessions ».
      </template>

      <Column field="salarie" header="Participant" />
      <Column field="matricule" header="Matricule" style="width: 8rem" />
      <Column field="poste" header="Poste" />
      <Column field="etablissement" header="Établissement" />

      <Column header="Présence" style="width: 24rem">
        <template #body="{ data }">
          <SelectButton :modelValue="data.presence" :options="PRESENCES"
                        optionLabel="label" optionValue="code" size="small"
                        @update:modelValue="(valeur) => noter(data, valeur)" />
        </template>
      </Column>

      <Column header="Résultat" style="width: 9rem">
        <template #body="{ data }">
          <Tag v-if="data.presence" :value="libelle(PRESENCES, data.presence)"
               :severity="couleur(PRESENCES, data.presence)" />
          <span v-else class="discret">Non renseigné</span>
        </template>
      </Column>

      <Column header="Commentaire">
        <template #body="{ data }">
          <InputText :modelValue="data.commentaire ?? ''" size="small" fluid
                     placeholder="Motif de l’absence, retard…"
                     @change="(e) => noterCommentaire(data, e.target.value)" />
        </template>
      </Column>
    </DataTable>
  </template>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 34rem; max-width: 100%; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.discret { color: var(--p-text-muted-color); font-size: .85rem; }
</style>
