<!-- libelle: Sessions de formation -->
<script setup>
/**
 * Story #38 — Le Responsable RH d'établissement crée les sessions de
 * formation : dates, heures de début et de fin, site, salle, formateur et
 * nombre de places. Une session créée est ouverte aux inscriptions.
 * Le coût de la session sert au suivi du budget (story #48).
 *
 * L'écran liste aussi les sessions existantes, permet de les modifier, de
 * fermer les inscriptions ou d'annuler une session.
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  sql, insert, update, getEtablissements, formatDate, toast, MODULE_CODE,
} from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, STATUTS_SESSION, libelle, couleur,
  enIso, enDate, heure, horaires, periode, sessionCouranteId,
} from './_donnees'

const router = useRouter()

const sessions = ref([])
const formations = ref([])
const etablissements = ref([])
const chargement = ref(true)

const etablissementId = ref(null)
const statut = ref(null)

const fiche = ref(null)
const enregistrement = ref(false)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    sessions.value = await chargerSessions()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  await charger()
  try {
    etablissements.value = await getEtablissements()
    formations.value = await sql(
      'select id, code, intitule, duree_heures from formations where actif order by intitule',
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

const visibles = computed(() =>
  sessions.value.filter((s) =>
    (!etablissementId.value || s.establishment_id === etablissementId.value) &&
    (!statut.value || s.statut === statut.value)))

const totaux = computed(() => ({
  ouvertes: visibles.value.filter((s) => s.statut === 'ouverte').length,
  places: visibles.value
    .filter((s) => s.statut === 'ouverte')
    .reduce((t, s) => t + s.places_restantes, 0),
  demandes: visibles.value.reduce((t, s) => t + s.demandes, 0),
}))

// ── La fiche : création et modification ──────────────────────────────────────

function nouvelle() {
  fiche.value = {
    id: null,
    formation_id: null,
    date_debut: null,
    date_fin: null,
    heure_debut: '09:00',
    heure_fin: '17:00',
    establishment_id: etablissementId.value,
    salle: '',
    formateur: '',
    places: 10,
    cout: 0,
    statut: 'ouverte',
    inscrits: 0,
  }
}

function modifier(session) {
  fiche.value = {
    id: session.id,
    formation_id: session.formation_id,
    date_debut: enDate(session.date_debut),
    date_fin: enDate(session.date_fin),
    heure_debut: heure(session.heure_debut),
    heure_fin: heure(session.heure_fin),
    establishment_id: session.establishment_id,
    salle: session.salle ?? '',
    formateur: session.formateur ?? '',
    places: session.places,
    cout: Number(session.cout ?? 0),
    statut: session.statut,
    inscrits: session.inscrits,
  }
}

/** Renvoie le premier problème de saisie, ou null si tout est bon. */
function probleme(f) {
  if (!f.formation_id) return 'Choisissez la formation.'
  if (!f.date_debut || !f.date_fin) return 'Renseignez la date de début et la date de fin.'
  if (enIso(f.date_fin) < enIso(f.date_debut)) return 'La date de fin est avant la date de début.'
  if (!f.heure_debut || !f.heure_fin) return 'Renseignez l’heure de début et l’heure de fin.'
  if (f.heure_fin <= f.heure_debut) return 'L’heure de fin doit être après l’heure de début.'
  if (!f.establishment_id) return 'Choisissez le site où se tient la session.'
  if (!f.salle.trim()) return 'Indiquez la salle.'
  if (!f.formateur.trim()) return 'Indiquez le formateur.'
  if (!f.places || f.places < 1) return 'Il faut au moins une place.'
  if (f.places < f.inscrits) {
    return `Il y a déjà ${f.inscrits} inscrit(s) : le nombre de places ne peut pas être plus petit.`
  }
  return null
}

async function enregistrer() {
  const f = fiche.value
  const souci = probleme(f)
  if (souci) {
    toast.alerte(souci)
    return
  }

  const donnees = {
    formation_id: f.formation_id,
    date_debut: enIso(f.date_debut),
    date_fin: enIso(f.date_fin),
    heure_debut: f.heure_debut,
    heure_fin: f.heure_fin,
    establishment_id: f.establishment_id,
    salle: f.salle.trim(),
    formateur: f.formateur.trim(),
    places: f.places,
    cout: Math.max(0, Math.round(Number(f.cout ?? 0))),
    statut: f.statut,
  }

  enregistrement.value = true
  try {
    if (f.id) {
      await update('sessions', f.id, donnees)
      toast.succes('Session modifiée')
    } else {
      await insert('sessions', donnees)
      toast.succes('Session créée, elle est ouverte aux inscriptions')
    }
    fiche.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/** Quand on choisit la date de début, la date de fin suit si elle est vide. */
function suivreDateDebut(date) {
  if (fiche.value && (!fiche.value.date_fin || fiche.value.date_fin < date)) {
    fiche.value.date_fin = date
  }
}

async function changerStatut(session, nouveau) {
  try {
    await update('sessions', session.id, { statut: nouveau })
    toast.succes(`Session : ${libelle(STATUTS_SESSION, nouveau).toLowerCase()}`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

function voirInscriptions(session) {
  sessionCouranteId.value = session.id
  router.push(`/${MODULE_CODE}/inscriptions-sessions`)
}
</script>

<template>
  <PageHeader
    titre="Sessions de formation"
    :sousTitre="`${visibles.length} session(s) · ${totaux.ouvertes} ouverte(s) aux inscriptions · ${totaux.places} place(s) disponible(s) · ${totaux.demandes} demande(s) à valider`"
  >
    <Button label="Nouvelle session" icon="pi pi-plus" @click="nouvelle" />
  </PageHeader>

  <div class="filtres">
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="statut" :options="STATUTS_SESSION"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small" rowHover
             @row-click="(e) => modifier(e.data)">
    <template #empty>
      Aucune session pour l’instant. Créez la première avec « Nouvelle session ».
    </template>

    <Column field="formation" header="Formation" sortable />

    <Column field="date_debut" header="Dates" sortable>
      <template #body="{ data }">{{ periode(data, formatDate) }}</template>
    </Column>

    <Column header="Horaires" style="width: 8rem">
      <template #body="{ data }">{{ horaires(data) }}</template>
    </Column>

    <Column field="etablissement" header="Site" sortable />
    <Column field="salle" header="Salle" />
    <Column field="formateur" header="Formateur" />

    <Column field="inscrits" header="Inscrits" sortable style="width: 8rem">
      <template #body="{ data }">
        {{ data.inscrits }} / {{ data.places }}
        <Tag v-if="data.demandes > 0" severity="warn" :value="`+${data.demandes}`"
             v-tooltip.top="`${data.demandes} demande(s) en attente de validation`" />
      </template>
    </Column>

    <Column field="statut" header="Statut" sortable style="width: 13rem">
      <template #body="{ data }">
        <Tag :value="libelle(STATUTS_SESSION, data.statut)"
             :severity="couleur(STATUTS_SESSION, data.statut)" />
      </template>
    </Column>

    <Column style="width: 11rem">
      <template #body="{ data }">
        <Button icon="pi pi-users" text rounded aria-label="Inscriptions"
                v-tooltip.left="'Voir les inscriptions'"
                @click.stop="voirInscriptions(data)" />
        <Button v-if="data.statut === 'ouverte'" icon="pi pi-lock" text rounded
                severity="secondary" aria-label="Fermer les inscriptions"
                v-tooltip.left="'Fermer les inscriptions'"
                @click.stop="changerStatut(data, 'fermee')" />
        <Button v-if="data.statut === 'fermee'" icon="pi pi-lock-open" text rounded
                severity="secondary" aria-label="Rouvrir les inscriptions"
                v-tooltip.left="'Rouvrir les inscriptions'"
                @click.stop="changerStatut(data, 'ouverte')" />
        <Button v-if="data.statut === 'ouverte' || data.statut === 'fermee'"
                icon="pi pi-times" text rounded severity="danger"
                aria-label="Annuler la session"
                v-tooltip.left="'Annuler la session'"
                @click.stop="changerStatut(data, 'annulee')" />
      </template>
    </Column>
  </DataTable>

  <!-- La fiche d'une session : la même pour créer et pour modifier. -->
  <Dialog :visible="!!fiche" modal :style="{ width: '42rem' }"
          :header="fiche?.id ? 'Modifier la session' : 'Nouvelle session de formation'"
          @update:visible="fiche = null">
    <div v-if="fiche" class="formulaire">
      <div class="champ large">
        <label for="s-formation">Formation *</label>
        <Select inputId="s-formation" v-model="fiche.formation_id" :options="formations"
                optionLabel="intitule" optionValue="id" filter
                placeholder="Choisir une formation du catalogue" />
      </div>

      <div class="champ">
        <label for="s-debut">Date de début *</label>
        <DatePicker inputId="s-debut" v-model="fiche.date_debut" dateFormat="dd/mm/yy"
                    showIcon @update:modelValue="suivreDateDebut" />
      </div>
      <div class="champ">
        <label for="s-fin">Date de fin *</label>
        <DatePicker inputId="s-fin" v-model="fiche.date_fin" dateFormat="dd/mm/yy"
                    showIcon :minDate="fiche.date_debut" />
      </div>

      <div class="champ">
        <label for="s-heure-debut">Heure de début *</label>
        <InputText id="s-heure-debut" v-model="fiche.heure_debut" type="time" />
      </div>
      <div class="champ">
        <label for="s-heure-fin">Heure de fin *</label>
        <InputText id="s-heure-fin" v-model="fiche.heure_fin" type="time" />
      </div>

      <div class="champ">
        <label for="s-site">Site *</label>
        <Select inputId="s-site" v-model="fiche.establishment_id" :options="etablissements"
                optionLabel="name" optionValue="id" placeholder="Choisir un établissement" />
      </div>
      <div class="champ">
        <label for="s-salle">Salle *</label>
        <InputText id="s-salle" v-model="fiche.salle" placeholder="Salon Soufflot" />
      </div>

      <div class="champ">
        <label for="s-formateur">Formateur *</label>
        <InputText id="s-formateur" v-model="fiche.formateur"
                   placeholder="Nom du formateur ou de l’organisme" />
      </div>
      <div class="champ">
        <label for="s-places">Nombre de places *</label>
        <InputNumber inputId="s-places" v-model="fiche.places" :min="1" :max="200" showButtons />
      </div>

      <div class="champ">
        <label for="s-cout">Coût de la session (€)</label>
        <InputNumber inputId="s-cout" v-model="fiche.cout" :min="0" :step="100" />
      </div>

      <div v-if="fiche.id" class="champ">
        <label for="s-statut">Statut</label>
        <Select inputId="s-statut" v-model="fiche.statut" :options="STATUTS_SESSION"
                optionLabel="label" optionValue="code" />
      </div>
    </div>

    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="fiche = null" />
      <Button :label="fiche?.id ? 'Enregistrer' : 'Créer la session'" icon="pi pi-check"
              :loading="enregistrement" @click="enregistrer" />
    </template>
  </Dialog>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }

.formulaire { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.champ { display: flex; flex-direction: column; gap: .35rem; min-width: 0; }
.champ.large { grid-column: 1 / -1; }
.champ label { font-size: .85rem; font-weight: 600; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
