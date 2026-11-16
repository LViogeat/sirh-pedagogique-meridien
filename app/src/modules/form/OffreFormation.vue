<!-- libelle: Formations et inscription -->
<script setup>
/**
 * L'écran du collaborateur. Il répond à trois stories qui se suivent :
 *
 *   #18 — consulter le descriptif détaillé d'une formation (objectifs,
 *         programme, durée, prérequis, lieu et modalités) ;
 *   #21 — voir les sessions ouvertes de cette formation, avec leurs dates,
 *         leurs horaires et le nombre de places disponibles ;
 *   #19 — demander son inscription à une session ouverte.
 *
 * On clique sur une formation : le descriptif s'ouvre, avec ses sessions en
 * dessous. La demande d'inscription part « en attente de validation » : c'est
 * le Responsable RH qui la valide (écran Inscriptions aux sessions).
 */
import { ref, computed, onMounted } from 'vue'
import { sql, insert, update, formatDate, formatNombre, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, MODALITES, STATUTS_INSCRIPTION,
  libelle, couleur, horaires, periode,
} from './_donnees'
import ChoixSalarie from './_ChoixSalarie.vue'

const formations = ref([])
const sessions = ref([])
const mesInscriptions = ref([])
const chargement = ref(true)

const salarie = ref(null)
const recherche = ref('')
const domaine = ref(null)
const avecSession = ref(false)

const formationOuverte = ref(null)
const envoi = ref(null)            // l'id de la session dont la demande part

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    formations.value = await sql(
      `select f.*, k.label as competence
       from   formations f
       left join public.skills k on k.id = f.skill_id
       where  f.actif
       order by f.domaine, f.intitule`,
    )
    sessions.value = (await chargerSessions()).filter((s) => s.statut === 'ouverte')
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

async function chargerMesInscriptions() {
  if (!salarie.value) {
    mesInscriptions.value = []
    return
  }
  try {
    mesInscriptions.value = await sql(
      'select * from inscriptions where employee_id = :salarie',
      { salarie: salarie.value.id },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

onMounted(charger)

async function changerSalarie(s) {
  salarie.value = s
  await chargerMesInscriptions()
}

// ── La liste des formations ──────────────────────────────────────────────────

const domaines = computed(() =>
  [...new Set(formations.value.map((f) => f.domaine))].sort())

/** Le nombre de sessions ouvertes par formation. */
const ouvertes = computed(() => {
  const compte = {}
  for (const s of sessions.value) {
    compte[s.formation_id] = (compte[s.formation_id] ?? 0) + 1
  }
  return compte
})

const visibles = computed(() => {
  const motif = recherche.value.trim().toLowerCase()
  return formations.value
    .map((f) => ({ ...f, sessions_ouvertes: ouvertes.value[f.id] ?? 0 }))
    .filter((f) =>
      (!domaine.value || f.domaine === domaine.value) &&
      (!avecSession.value || f.sessions_ouvertes > 0) &&
      (!motif || `${f.intitule} ${f.objectifs ?? ''}`.toLowerCase().includes(motif)))
})

// ── Le descriptif et ses sessions ────────────────────────────────────────────

const sessionsDeLaFormation = computed(() =>
  formationOuverte.value
    ? sessions.value.filter((s) => s.formation_id === formationOuverte.value.id)
    : [])

/** Mon inscription à une session, si j'en ai une. */
function monInscription(session) {
  return mesInscriptions.value.find((i) => i.session_id === session.id) ?? null
}

/** Une inscription refusée ou annulée n'empêche pas de refaire une demande. */
function inscriptionEnCours(session) {
  const i = monInscription(session)
  return i && ['demandee', 'validee'].includes(i.statut) ? i : null
}

async function demander(session) {
  if (!salarie.value) {
    toast.alerte('Choisissez d’abord votre nom en haut de l’écran.')
    return
  }
  envoi.value = session.id
  try {
    // On relit la session juste avant : une place a pu partir entre-temps.
    const fraiches = await chargerSessions()
    const actuelle = fraiches.find((s) => s.id === session.id)
    sessions.value = fraiches.filter((s) => s.statut === 'ouverte')

    if (!actuelle || actuelle.statut !== 'ouverte') {
      toast.alerte('Cette session n’est plus ouverte aux inscriptions.')
      return
    }
    if (actuelle.places_restantes < 1) {
      toast.alerte('Il n’y a plus de place disponible sur cette session.')
      return
    }

    const ancienne = monInscription(session)
    if (ancienne) {
      await update('inscriptions', ancienne.id, {
        statut: 'demandee', origine: 'collaborateur', presence: null,
      })
    } else {
      await insert('inscriptions', {
        session_id: session.id,
        employee_id: salarie.value.id,
        statut: 'demandee',
        origine: 'collaborateur',
      })
    }
    toast.succes('Votre demande d’inscription est envoyée. Elle attend la validation du service RH.')
    await chargerMesInscriptions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    envoi.value = null
  }
}

async function annulerMaDemande(session) {
  const i = inscriptionEnCours(session)
  if (!i) return
  try {
    await update('inscriptions', i.id, { statut: 'annulee' })
    toast.info('Votre demande d’inscription est annulée.')
    await chargerMesInscriptions()
    sessions.value = (await chargerSessions()).filter((s) => s.statut === 'ouverte')
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Formations et inscription"
    :sousTitre="`${visibles.length} formation(s) au catalogue · ${sessions.length} session(s) ouverte(s) aux inscriptions`"
  />

  <ChoixSalarie @change="changerSalarie" />

  <div class="filtres">
    <InputText v-model="recherche" placeholder="Rechercher une formation" />
    <Select v-model="domaine" :options="domaines"
            placeholder="Tous les domaines" showClear />
    <div class="bascule">
      <ToggleSwitch v-model="avecSession" inputId="avec-session" />
      <label for="avec-session">Seulement celles qui ont une session ouverte</label>
    </div>
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small" rowHover
             @row-click="(e) => (formationOuverte = e.data)">
    <template #empty>Aucune formation ne correspond à ces critères.</template>

    <Column field="intitule" header="Formation" sortable />
    <Column field="domaine" header="Domaine" sortable />

    <Column field="duree_heures" header="Durée" sortable style="width: 6rem">
      <template #body="{ data }">{{ formatNombre(data.duree_heures) }} h</template>
    </Column>

    <Column field="modalite" header="Modalité" sortable style="width: 8rem">
      <template #body="{ data }">{{ libelle(MODALITES, data.modalite) }}</template>
    </Column>

    <Column field="sessions_ouvertes" header="Sessions ouvertes" sortable style="width: 10rem">
      <template #body="{ data }">
        <Tag v-if="data.sessions_ouvertes > 0" severity="success"
             :value="`${data.sessions_ouvertes} session(s)`" />
        <span v-else class="discret">Aucune pour l’instant</span>
      </template>
    </Column>

    <Column style="width: 9rem">
      <template #body="{ data }">
        <Button label="Voir le détail" icon="pi pi-search" text size="small"
                @click.stop="formationOuverte = data" />
      </template>
    </Column>
  </DataTable>

  <!-- Le descriptif (#18), puis les sessions ouvertes (#21) et l'inscription (#19). -->
  <Dialog :visible="!!formationOuverte" modal :style="{ width: '58rem' }"
          :header="formationOuverte?.intitule" @update:visible="formationOuverte = null">
    <template v-if="formationOuverte">
      <p class="chapo">
        {{ formationOuverte.domaine }} · {{ formatNombre(formationOuverte.duree_heures) }} heures ·
        {{ libelle(MODALITES, formationOuverte.modalite) }}
      </p>

      <dl class="descriptif">
        <dt>Objectifs</dt>
        <dd>{{ formationOuverte.objectifs || 'Non renseigné' }}</dd>

        <dt>Programme</dt>
        <dd>{{ formationOuverte.programme || 'Non renseigné' }}</dd>

        <dt>Durée</dt>
        <dd>{{ formatNombre(formationOuverte.duree_heures) }} heures</dd>

        <dt>Prérequis</dt>
        <dd>{{ formationOuverte.prerequis || 'Aucun' }}</dd>

        <dt>Lieu</dt>
        <dd>{{ formationOuverte.lieu || 'Précisé sur chaque session' }}</dd>

        <dt>Modalités</dt>
        <dd>
          {{ libelle(MODALITES, formationOuverte.modalite) }}
          <template v-if="formationOuverte.periodicite_mois">
            · à refaire tous les {{ formationOuverte.periodicite_mois }} mois
          </template>
        </dd>

        <template v-if="formationOuverte.competence">
          <dt>Compétence développée</dt>
          <dd>{{ formationOuverte.competence }}</dd>
        </template>
      </dl>

      <h3>Sessions ouvertes aux inscriptions</h3>

      <Message v-if="!salarie" severity="info" :closable="false" class="rappel">
        Pour demander une inscription, choisissez votre nom en haut de l’écran.
      </Message>

      <DataTable :value="sessionsDeLaFormation" size="small" dataKey="id">
        <template #empty>
          Aucune session n’est ouverte pour cette formation en ce moment.
        </template>

        <Column header="Dates">
          <template #body="{ data }">{{ periode(data, formatDate) }}</template>
        </Column>

        <Column header="Horaires" style="width: 8rem">
          <template #body="{ data }">{{ horaires(data) }}</template>
        </Column>

        <Column header="Lieu">
          <template #body="{ data }">
            {{ data.etablissement }}<template v-if="data.salle"> · {{ data.salle }}</template>
          </template>
        </Column>

        <Column field="formateur" header="Formateur">
          <template #body="{ data }">{{ data.formateur || '—' }}</template>
        </Column>

        <Column header="Places disponibles" style="width: 10rem">
          <template #body="{ data }">
            <Tag :severity="data.places_restantes > 0 ? 'success' : 'danger'"
                 :value="data.places_restantes > 0
                           ? `${data.places_restantes} sur ${data.places}`
                           : 'Complet'" />
          </template>
        </Column>

        <Column header="Mon inscription" style="width: 15rem">
          <template #body="{ data }">
            <div v-if="inscriptionEnCours(data)" class="etat">
              <Tag :value="libelle(STATUTS_INSCRIPTION, inscriptionEnCours(data).statut)"
                   :severity="couleur(STATUTS_INSCRIPTION, inscriptionEnCours(data).statut)" />
              <Button v-if="inscriptionEnCours(data).statut === 'demandee'"
                      label="Annuler" text size="small" severity="secondary"
                      @click="annulerMaDemande(data)" />
            </div>
            <Button v-else label="Demander l’inscription" icon="pi pi-send" size="small"
                    :disabled="!salarie || data.places_restantes < 1"
                    :loading="envoi === data.id"
                    @click="demander(data)" />
          </template>
        </Column>
      </DataTable>
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-inputtext { min-width: 18rem; }
.filtres > .p-select { min-width: 14rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .9rem; }
.discret { color: var(--p-text-muted-color); font-size: .85rem; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }

.descriptif { display: grid; grid-template-columns: 11rem 1fr; gap: .6rem 1rem; margin: 0; }
.descriptif dt { font-weight: 600; font-size: .9rem; }
.descriptif dd { margin: 0; line-height: 1.45; }

h3 { font-size: .95rem; margin: 1.5rem 0 .5rem; }
.rappel { margin-bottom: .75rem; }
.etat { display: flex; align-items: center; gap: .25rem; flex-wrap: wrap; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
