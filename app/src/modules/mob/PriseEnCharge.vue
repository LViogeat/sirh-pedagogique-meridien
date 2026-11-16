<!-- libelle: Prise en charge -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { getBesoins, prendreEnChargeBesoin, relacherBesoin, getDateReference,
         sql, insert, remove, formatDate, toast } from '@/socle/sdk'
import { etapeDe } from './_commun'

const besoins = ref([])
const dossiers = ref([])          // nos dossiers, pour savoir qui en a un
const dateReference = ref(null)
const chargement = ref(true)
const enCours = ref(false)

const vue = ref('ouvert')
const VUES = [
  { code: 'ouvert', label: 'Besoins ouverts' },
  { code: 'pris', label: 'Pris en charge par notre module' },
]

async function charger() {
  chargement.value = true
  try {
    const [tous, nos, dateRef] = await Promise.all([
      getBesoins({ typeBesoin: 'mobilite' }),
      sql('select id, besoin_id, etape from dossiers'),
      getDateReference(),
    ])
    besoins.value = tous
    dossiers.value = nos
    dateReference.value = dateRef
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}
onMounted(charger)

const dossierDu = (besoinId) => dossiers.value.find((d) => d.besoin_id === besoinId)

const ORDRE = { haute: 0, moyenne: 1, basse: 2 }
const lignes = computed(() =>
  besoins.value
    .filter((b) => vue.value === 'ouvert'
      ? b.status === 'ouvert'
      : b.status === 'pris_en_charge' && b.handled_by_module === 'mob')
    .sort((a, b) => (ORDRE[a.priority] ?? 9) - (ORDRE[b.priority] ?? 9)))

const nbOuverts = computed(() => besoins.value.filter((b) => b.status === 'ouvert').length)
const nbPris = computed(() => besoins.value.filter((b) => b.status === 'pris_en_charge' && b.handled_by_module === 'mob').length)

const severitePriorite = (code) => ({ haute: 'danger', moyenne: 'warn', basse: 'secondary' })[code] || 'secondary'

// ── Prendre en charge ───────────────────────────────────────────────────────

const dialogue = ref(false)
const besoinChoisi = ref(null)
const conseiller = ref('')
const commentaire = ref('')

function ouvrirPriseEnCharge(besoin) {
  besoinChoisi.value = besoin
  commentaire.value = ''
  dialogue.value = true
}

async function confirmerPriseEnCharge() {
  if (!conseiller.value.trim()) {
    toast.erreur('Indiquez le nom du conseiller.')
    return
  }
  const besoin = besoinChoisi.value
  enCours.value = true
  try {
    // 1. Le socle d'abord : s'il refuse, on s'arrête là et rien n'est créé.
    await prendreEnChargeBesoin(besoin.id, commentaire.value || null)

    // 2. Le dossier, s'il n'existe pas déjà pour ce besoin.
    const existants = await sql('select id from dossiers where besoin_id = :id', { id: besoin.id })
    if (!existants.length) {
      try {
        await insert('dossiers', {
          besoin_id: besoin.id,
          employee_id: besoin.employee_id,
          conseiller: conseiller.value.trim(),
          etape: 'analyse',
          ouvert_le: dateReference.value,
        })
      } catch (erreur) {
        // Le dossier n'a pas pu être créé : on rend le besoin, pour rester cohérent.
        await relacherBesoin(besoin.id).catch(() => {})
        throw erreur
      }
    }
    toast.succes(`Dossier ouvert pour ${besoin.employee_name}.`)
    dialogue.value = false
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}

// ── Relâcher ────────────────────────────────────────────────────────────────

const peutRelacher = (besoin) => {
  const dossier = dossierDu(besoin.id)
  return !dossier || dossier.etape === 'analyse'
}

async function relacher(besoin) {
  enCours.value = true
  try {
    await relacherBesoin(besoin.id)
    const dossier = dossierDu(besoin.id)
    if (dossier) await remove('dossiers', dossier.id)
    toast.succes(`Besoin de ${besoin.employee_name} relâché.`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}
</script>

<template>
  <PageHeader titre="Prise en charge"
              sousTitre="Prendre un besoin de mobilité ouvre le dossier du salarié" />

  <div class="chiffres">
    <StatCard titre="Besoins ouverts" :valeur="nbOuverts" icone="pi pi-inbox" />
    <StatCard titre="Pris en charge par nous" :valeur="nbPris" icone="pi pi-briefcase" />
  </div>

  <SelectButton v-model="vue" :options="VUES" optionLabel="label" optionValue="code"
                :allowEmpty="false" class="vues" />

  <DataTable :value="lignes" :loading="chargement" dataKey="id"
             paginator :rows="15" stripedRows size="small">
    <template #empty>Aucun besoin dans cette liste.</template>

    <Column header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.employee_name }}</div>
        <small class="discret">{{ data.matricule }}</small>
      </template>
    </Column>
    <Column field="position_title" header="Poste visé" />
    <Column field="establishment_name" header="Hôtel visé" />
    <Column header="Priorité" style="width: 7rem">
      <template #body="{ data }">
        <Tag :value="data.priority_label" :severity="severitePriorite(data.priority)" />
      </template>
    </Column>
    <Column header="Détecté le" style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.detected_on) }}</template>
    </Column>
    <Column header="Dossier" style="width: 9rem">
      <template #body="{ data }">
        <Tag v-if="dossierDu(data.id)" :value="etapeDe(dossierDu(data.id).etape).label"
             :severity="etapeDe(dossierDu(data.id).etape).severite" />
        <span v-else class="discret">—</span>
      </template>
    </Column>
    <Column style="width: 11rem">
      <template #body="{ data }">
        <Button v-if="data.status === 'ouvert'" label="Prendre en charge" icon="pi pi-check"
                size="small" :disabled="enCours" @click="ouvrirPriseEnCharge(data)" />
        <Button v-else-if="peutRelacher(data)" label="Relâcher" icon="pi pi-undo"
                size="small" severity="secondary" outlined :disabled="enCours"
                @click="relacher(data)" />
        <small v-else class="discret">Dossier avancé</small>
      </template>
    </Column>
  </DataTable>

  <Dialog v-model:visible="dialogue" modal header="Prendre en charge" :style="{ width: '30rem' }">
    <p v-if="besoinChoisi">
      <strong>{{ besoinChoisi.employee_name }}</strong> — {{ besoinChoisi.position_title }},
      {{ besoinChoisi.establishment_name }}
    </p>
    <div class="champ">
      <label for="conseiller">Conseiller RH</label>
      <InputText id="conseiller" v-model="conseiller" placeholder="Votre nom" />
    </div>
    <div class="champ">
      <label for="commentaire">Commentaire</label>
      <Textarea id="commentaire" v-model="commentaire" rows="3" autoResize />
    </div>
    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="dialogue = false" />
      <Button label="Ouvrir le dossier" icon="pi pi-folder-open" :loading="enCours"
              @click="confirmerPriseEnCharge" />
    </template>
  </Dialog>
</template>

<style scoped>
.chiffres { display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 18rem)); gap: 1rem; margin-bottom: 1rem; }
.vues { margin-bottom: 1rem; }
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.champ { display: flex; flex-direction: column; gap: .35rem; margin-top: 1rem; }
</style>
