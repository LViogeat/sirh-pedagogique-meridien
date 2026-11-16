<!-- libelle: Inscriptions aux sessions -->
<script setup>
/**
 * Story #53 — Le Responsable RH d'établissement inscrit lui-même un
 * collaborateur à une session quand celui-ci ne s'est pas inscrit.
 *
 * On choisit une session, on voit qui y est inscrit, et on ajoute un
 * collaborateur à la main. Une inscription faite par le RH est validée tout
 * de suite. C'est aussi ici que le RH valide ou refuse les demandes envoyées
 * par les collaborateurs : c'est le circuit de validation.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, insert, update, getSalaries, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, STATUTS_SESSION, STATUTS_INSCRIPTION,
  libelle, couleur, horaires, periode, sessionCouranteId,
} from './_donnees'

const sessions = ref([])
const salaries = ref([])
const inscriptions = ref([])
const chargement = ref(true)
const chargementInscrits = ref(false)

const salarieAInscrire = ref(null)
const commentaire = ref('')
const toutLeGroupe = ref(false)
const ajout = ref(false)

async function chargerLesSessions() {
  const toutes = await chargerSessions()
  sessions.value = toutes
    .filter((s) => s.statut !== 'annulee')
    .map((s) => ({
      ...s,
      affichage: `${s.formation} — ${periode(s, formatDate)} — ${s.etablissement ?? ''}`,
    }))
}

async function chargerInscriptions() {
  if (!sessionCouranteId.value) {
    inscriptions.value = []
    return
  }
  chargementInscrits.value = true
  try {
    // Le poste et l'établissement viennent de la liste des salariés du socle,
    // déjà chargée : pas besoin de les rejoindre en SQL.
    const lignes = await sql(
      `select i.*,
              e.first_name || ' ' || e.last_name as salarie,
              e.matricule
       from   inscriptions i
       join   public.employees e on e.id = i.employee_id
       where  i.session_id = :session
       order by i.cree_le, i.id`,
      { session: sessionCouranteId.value },
    )
    inscriptions.value = lignes
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargementInscrits.value = false
  }
}

async function recharger() {
  try {
    await chargerLesSessions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await chargerInscriptions()
}

onMounted(async () => {
  try {
    await preparerSchema()
    await chargerLesSessions()
    // Si la session gardée en mémoire n'existe plus, on l'oublie.
    if (!sessions.value.some((s) => s.id === sessionCouranteId.value)) {
      sessionCouranteId.value = null
    }
    const liste = await getSalaries()
    salaries.value = liste.map((s) => ({
      ...s,
      affichage: `${s.full_name} — ${s.position_title ?? 'sans poste'} (${s.establishment_city ?? '—'})`,
    }))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
  await chargerInscriptions()
})

watch(sessionCouranteId, () => {
  salarieAInscrire.value = null
  commentaire.value = ''
  chargerInscriptions()
})

/** Les inscriptions, complétées du poste et de l'établissement du salarié. */
const inscrits = computed(() =>
  inscriptions.value.map((i) => {
    const s = salaries.value.find((x) => x.id === i.employee_id)
    return {
      ...i,
      poste: s?.position_title ?? '—',
      etablissement: s?.establishment_name ?? '—',
    }
  }))

const session = computed(
  () => sessions.value.find((s) => s.id === sessionCouranteId.value) ?? null,
)

const modifiable = computed(
  () => session.value && ['ouverte', 'fermee'].includes(session.value.statut),
)

/**
 * Les collaborateurs qu'on peut encore inscrire : ceux de l'établissement de
 * la session (ou de tout le groupe si on coche la case), moins ceux qui ont
 * déjà une inscription en cours.
 */
const candidats = computed(() => {
  if (!session.value) return []
  const dejaLa = new Set(
    inscriptions.value
      .filter((i) => ['demandee', 'validee'].includes(i.statut))
      .map((i) => i.employee_id),
  )
  return salaries.value.filter((s) =>
    !dejaLa.has(s.id) &&
    (toutLeGroupe.value || s.establishment_id === session.value.establishment_id))
})

const compte = computed(() => ({
  valides: inscriptions.value.filter((i) => i.statut === 'validee').length,
  demandes: inscriptions.value.filter((i) => i.statut === 'demandee').length,
}))

const placesRestantes = computed(() =>
  session.value ? Math.max(0, session.value.places - compte.value.valides) : 0)

// ── Inscrire un collaborateur à la main (#53) ────────────────────────────────

async function inscrire() {
  if (!salarieAInscrire.value) {
    toast.alerte('Choisissez le collaborateur à inscrire.')
    return
  }
  ajout.value = true
  try {
    // On relit avant d'écrire : quelqu'un d'autre a pu prendre la dernière place.
    await chargerInscriptions()
    if (placesRestantes.value < 1) {
      toast.alerte('La session est complète : il n’y a plus de place.')
      return
    }

    const note = commentaire.value.trim() || null
    const ancienne = inscriptions.value.find(
      (i) => i.employee_id === salarieAInscrire.value,
    )
    if (ancienne) {
      await update('inscriptions', ancienne.id, {
        statut: 'validee', origine: 'rh', presence: null, commentaire: note,
      })
    } else {
      await insert('inscriptions', {
        session_id: session.value.id,
        employee_id: salarieAInscrire.value,
        statut: 'validee',
        origine: 'rh',
        commentaire: note,
      })
    }
    toast.succes('Collaborateur inscrit à la session')
    salarieAInscrire.value = null
    commentaire.value = ''
    await recharger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    ajout.value = false
  }
}

// ── Valider, refuser, annuler ────────────────────────────────────────────────

async function valider(inscription) {
  if (placesRestantes.value < 1) {
    toast.alerte('La session est complète : impossible de valider une demande de plus.')
    return
  }
  await changer(inscription, 'validee', 'Demande validée, le collaborateur est inscrit')
}

async function changer(inscription, statut, message) {
  try {
    await update('inscriptions', inscription.id, { statut })
    toast.succes(message)
    await recharger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Inscriptions aux sessions"
    sousTitre="Inscrire un collaborateur à une session, valider ou refuser les demandes"
  />

  <div class="filtres">
    <Select v-model="sessionCouranteId" :options="sessions"
            optionLabel="affichage" optionValue="id" filter showClear
            :loading="chargement" placeholder="Choisir une session de formation"
            emptyMessage="Aucune session : créez-en une dans « Sessions de formation »" />
  </div>

  <Message v-if="!session && !chargement" severity="info" :closable="false">
    Choisissez une session pour voir ses inscrits et ajouter un collaborateur.
  </Message>

  <template v-if="session">
    <div class="stats">
      <StatCard titre="Session" :valeur="periode(session, formatDate)" icone="pi pi-calendar"
                :precision="`${horaires(session)} · ${session.etablissement ?? ''} · ${session.salle ?? ''}`" />
      <StatCard titre="Inscrits" :valeur="`${compte.valides} / ${session.places}`"
                icone="pi pi-users" :precision="`${placesRestantes} place(s) disponible(s)`" />
      <StatCard titre="Demandes à valider" :valeur="compte.demandes" icone="pi pi-inbox" />
      <StatCard titre="Statut" :valeur="libelle(STATUTS_SESSION, session.statut)"
                icone="pi pi-flag" :precision="session.formateur ?? ''" />
    </div>

    <Card v-if="modifiable" class="ajout">
      <template #title>Inscrire un collaborateur</template>
      <template #content>
        <div class="ligne">
          <Select v-model="salarieAInscrire" :options="candidats"
                  optionLabel="affichage" optionValue="id" filter
                  placeholder="Choisir un collaborateur"
                  emptyMessage="Tous les collaborateurs sont déjà inscrits"
                  emptyFilterMessage="Aucun collaborateur à ce nom" />
          <InputText v-model="commentaire" placeholder="Commentaire (facultatif)" />
          <Button label="Inscrire" icon="pi pi-user-plus" :loading="ajout"
                  :disabled="!salarieAInscrire || placesRestantes < 1" @click="inscrire" />
        </div>
        <div class="bascule">
          <ToggleSwitch v-model="toutLeGroupe" inputId="tout-le-groupe" />
          <label for="tout-le-groupe">
            Proposer aussi les collaborateurs des autres établissements
          </label>
        </div>
        <Message v-if="placesRestantes < 1" severity="warn" :closable="false" class="complet">
          La session est complète. Pour inscrire quelqu’un de plus, augmentez le nombre
          de places dans « Sessions de formation ».
        </Message>
      </template>
    </Card>

    <Message v-else severity="secondary" :closable="false" class="complet">
      Cette session est terminée : on ne peut plus y inscrire de collaborateur.
    </Message>

    <DataTable :value="inscrits" :loading="chargementInscrits" dataKey="id"
               stripedRows size="small" removableSort>
      <template #empty>Personne n’est encore inscrit à cette session.</template>

      <Column field="salarie" header="Collaborateur" sortable />
      <Column field="matricule" header="Matricule" style="width: 8rem" />
      <Column field="poste" header="Poste" sortable />
      <Column field="etablissement" header="Établissement" sortable />

      <Column field="origine" header="Inscrit par" sortable style="width: 10rem">
        <template #body="{ data }">
          {{ data.origine === 'rh' ? 'Le service RH' : 'Le collaborateur' }}
        </template>
      </Column>

      <Column field="cree_le" header="Le" sortable style="width: 7rem">
        <template #body="{ data }">{{ formatDate(data.cree_le) }}</template>
      </Column>

      <Column field="statut" header="Statut" sortable style="width: 13rem">
        <template #body="{ data }">
          <Tag :value="libelle(STATUTS_INSCRIPTION, data.statut)"
               :severity="couleur(STATUTS_INSCRIPTION, data.statut)" />
        </template>
      </Column>

      <Column field="commentaire" header="Commentaire">
        <template #body="{ data }">{{ data.commentaire || '—' }}</template>
      </Column>

      <Column style="width: 15rem">
        <template #body="{ data }">
          <template v-if="modifiable">
            <template v-if="data.statut === 'demandee'">
              <Button label="Valider" icon="pi pi-check" size="small" text
                      severity="success" @click="valider(data)" />
              <Button label="Refuser" icon="pi pi-times" size="small" text
                      severity="danger"
                      @click="changer(data, 'refusee', 'Demande refusée')" />
            </template>
            <Button v-else-if="data.statut === 'validee'"
                    label="Désinscrire" icon="pi pi-user-minus" size="small" text
                    severity="secondary"
                    @click="changer(data, 'annulee', 'Inscription annulée')" />
          </template>
        </template>
      </Column>
    </DataTable>
  </template>
</template>

<style scoped>
.filtres { margin-bottom: 1rem; }
.filtres > .p-select { min-width: 34rem; max-width: 100%; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.stats :deep(.valeur) { font-size: 1.3rem; }
.ajout { margin-bottom: 1.25rem; }
.ligne { display: flex; gap: .75rem; flex-wrap: wrap; align-items: center; }
.ligne > .p-select { min-width: 24rem; }
.ligne > .p-inputtext { flex: 1; min-width: 14rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .9rem; margin-top: .75rem; }
.complet { margin: .75rem 0 1.25rem; }
</style>
