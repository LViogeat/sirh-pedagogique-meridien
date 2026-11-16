<!-- libelle: Demande d'absence -->
<script setup>
/* =============================================================================
   Story #41 — Demande d'absence (collaborateur)

   En tant que collaborateur, je choisis un type d'absence dans une liste
   déroulante, mes dates, et j'envoie la demande à mon manager.

   Le collaborateur est choisi en haut de l'écran (il n'y a pas de connexion
   dans le socle). Son manager vient du socle : `manager_id` sur le salarié.
   La demande est enregistrée dans notre table `demandes_absence`.
   ========================================================================== */

import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, insert, useQuery, formatDate, toast } from '@/socle/sdk'

/* ── Les types d'absence que l'on peut demander ───────────────────────────── */
const TYPES_ABSENCE = [
  { code: 'conges_annuels', label: 'Congés annuels' },
  { code: 'rtt', label: 'RTT' },
  { code: 'evenement_familial', label: 'Événement familial' },
  { code: 'conge_sans_solde', label: 'Congé sans solde' },
  { code: 'absence_remuneree', label: 'Absence rémunérée' },
  { code: 'absence_non_remuneree', label: 'Absence non rémunérée' },
]
const libelleType = (code) => TYPES_ABSENCE.find((t) => t.code === code)?.label || code

const STATUTS = {
  envoyee: { label: 'Envoyée au manager', severite: 'info' },
  validee: { label: 'Validée', severite: 'success' },
  refusee: { label: 'Refusée', severite: 'danger' },
}

/* ── L'état de l'écran ─────────────────────────────────────────────────────── */
const salaries = ref([])
const salarieId = ref(null)

const typeAbsence = ref(null)
const dates = ref(null)          // [début, fin] choisis dans le calendrier
const commentaire = ref('')
const envoi = ref(false)

const salarie = computed(() => salaries.value.find((s) => s.id === salarieId.value))

/* Les demandes déjà faites par le collaborateur choisi. */
const demandes = useQuery(
  'select * from demandes_absence where salarie_id = :id order by envoyee_le desc',
  () => ({ id: salarieId.value ?? 0 }),
)
watch(salarieId, demandes.refresh)

onMounted(async () => {
  try {
    salaries.value = await getSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

/* ── L'envoi ───────────────────────────────────────────────────────────────── */
const formulaireComplet = computed(() =>
  salarie.value && typeAbsence.value && dates.value?.[0] && dates.value?.[1],
)

/** Date du calendrier → « 2026-11-16 », sans décalage de fuseau horaire. */
function enIso(d) {
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

async function envoyer() {
  if (!formulaireComplet.value) return
  envoi.value = true
  try {
    await insert('demandes_absence', {
      salarie_id: salarie.value.id,
      manager_id: salarie.value.manager_id,
      type_absence: typeAbsence.value,
      date_debut: enIso(dates.value[0]),
      date_fin: enIso(dates.value[1]),
      commentaire: commentaire.value.trim() || null,
    })
    toast.succes(
      salarie.value.manager_name
        ? `Demande transmise à ${salarie.value.manager_name}.`
        : 'Demande enregistrée.',
      'Demande envoyée',
    )
    typeAbsence.value = null
    dates.value = null
    commentaire.value = ''
    await demandes.refresh()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    envoi.value = false
  }
}
</script>

<template>
  <PageHeader
    titre="Demande d'absence"
    sousTitre="Choisissez le type d'absence et vos dates, puis envoyez la demande à votre manager."
  />

  <!-- Qui fait la demande -->
  <div class="carte">
    <label class="champ">
      <span>Collaborateur</span>
      <Select v-model="salarieId" :options="salaries" optionLabel="full_name" optionValue="id"
              filter placeholder="Choisir le collaborateur" class="large" />
    </label>
    <p v-if="salarie" class="manager">
      <i class="pi pi-user" />
      Manager destinataire :
      <strong>{{ salarie.manager_name || 'aucun manager renseigné' }}</strong>
      · {{ salarie.position_title }} · {{ salarie.establishment_name }}
    </p>
  </div>

  <!-- Le formulaire -->
  <div v-if="salarie" class="carte">
    <h2>Nouvelle demande</h2>
    <div class="grille">
      <label class="champ">
        <span>Type d'absence</span>
        <Select v-model="typeAbsence" :options="TYPES_ABSENCE" optionLabel="label"
                optionValue="code" placeholder="Choisir un type d'absence" />
      </label>
      <label class="champ">
        <span>Du … au …</span>
        <DatePicker v-model="dates" selectionMode="range" dateFormat="dd/mm/yy"
                    :manualInput="false" showIcon placeholder="Choisir les dates" />
      </label>
    </div>
    <label class="champ">
      <span>Commentaire (facultatif)</span>
      <Textarea v-model="commentaire" rows="2" autoResize />
    </label>
    <div class="actions">
      <Button label="Envoyer" icon="pi pi-send" :loading="envoi"
              :disabled="!formulaireComplet" @click="envoyer" />
    </div>
  </div>

  <!-- Les demandes déjà envoyées -->
  <div v-if="salarie" class="carte">
    <h2>Mes demandes</h2>
    <DataTable :value="demandes.rows" :loading="demandes.loading" dataKey="id"
               stripedRows size="small">
      <template #empty>Aucune demande d'absence pour l'instant.</template>
      <Column header="Type">
        <template #body="{ data }">{{ libelleType(data.type_absence) }}</template>
      </Column>
      <Column header="Du">
        <template #body="{ data }">{{ formatDate(data.date_debut) }}</template>
      </Column>
      <Column header="Au">
        <template #body="{ data }">{{ formatDate(data.date_fin) }}</template>
      </Column>
      <Column field="commentaire" header="Commentaire">
        <template #body="{ data }">{{ data.commentaire || '—' }}</template>
      </Column>
      <Column header="Envoyée le">
        <template #body="{ data }">{{ formatDate(data.envoyee_le) }}</template>
      </Column>
      <Column header="Statut">
        <template #body="{ data }">
          <Tag :value="STATUTS[data.statut]?.label || data.statut"
               :severity="STATUTS[data.statut]?.severite || 'secondary'" />
        </template>
      </Column>
    </DataTable>
  </div>
</template>

<style scoped>
.carte {
  background: var(--p-content-background, #fff);
  border: 1px solid var(--p-content-border-color, #e2e8f0);
  border-radius: 8px;
  padding: 1rem 1.25rem;
  margin-bottom: 1rem;
}
h2 { font-size: 1.05rem; margin: 0 0 0.75rem; }
.grille { display: grid; grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr)); gap: 1rem; }
.champ { display: flex; flex-direction: column; gap: 0.35rem; margin-bottom: 0.75rem; }
.champ > span { font-size: 0.85rem; font-weight: 600; }
.large { max-width: 28rem; }
.manager { margin: 0.25rem 0 0; color: var(--p-text-muted-color, #64748b); }
.manager .pi { margin-right: 0.35rem; }
.actions { display: flex; justify-content: flex-end; }
</style>
