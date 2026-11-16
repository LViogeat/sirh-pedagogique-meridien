<!-- libelle: Obligatoires hors délai -->
<script setup>
/**
 * Story #65 — Le Responsable RH d'établissement identifie les collaborateurs
 * qui n'ont pas effectué leurs formations obligatoires dans les délais
 * impartis, pour déclencher les relances.
 *
 * L'écran ne montre que les formations dont l'échéance est dépassée :
 *   - jamais suivie plus de six mois après l'arrivée du collaborateur ;
 *   - ou à recycler, avec une validité expirée.
 * On peut relancer par mail le collaborateur (son manager en copie) et
 * extraire la liste pour un suivi dans Excel.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, getEtablissements, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSuiviObligations, ETATS_OBLIGATION, DELAI_INITIAL_MOIS,
  libelle, couleur, telechargerCsv, etablissementCourantId,
} from './_donnees'

const etablissements = ref([])
const salaries = ref([])
const lignes = ref([])
const chargement = ref(true)

const formationId = ref(null)
const managerId = ref(null)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    salaries.value = await getSalaries({ etablissementId: etablissementCourantId.value })
    const suivi = await chargerSuiviObligations(salaries.value)
    lignes.value = suivi.filter((l) => l.en_retard)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    etablissements.value = await getEtablissements()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch(etablissementCourantId, () => {
  formationId.value = null
  managerId.value = null
  charger()
})

const formations = computed(() => {
  const vues = new Map()
  for (const l of lignes.value) vues.set(l.formation_id, l.formation)
  return [...vues].map(([id, intitule]) => ({ id, intitule }))
    .sort((a, b) => a.intitule.localeCompare(b.intitule))
})

const managers = computed(() => {
  const vus = new Map()
  for (const l of lignes.value) if (l.manager_id) vus.set(l.manager_id, l.manager)
  return [...vus].map(([id, nom]) => ({ id, nom }))
    .sort((a, b) => a.nom.localeCompare(b.nom))
})

const visibles = computed(() =>
  lignes.value
    .filter((l) =>
      (!formationId.value || l.formation_id === formationId.value) &&
      (!managerId.value || l.manager_id === managerId.value))
    .sort((a, b) => b.jours_de_retard - a.jours_de_retard))

const totaux = computed(() => ({
  formations: visibles.value.length,
  collaborateurs: new Set(visibles.value.map((l) => l.employee_id)).size,
  sansSession: visibles.value.filter((l) => !l.prochaine_session).length,
  pire: visibles.value[0]?.jours_de_retard ?? 0,
}))

/** Le lien qui ouvre un mail de relance déjà rédigé, manager en copie. */
function mailDeRelance(ligne) {
  const manager = salaries.value.find((s) => s.id === ligne.manager_id)
  const autres = visibles.value.filter((l) => l.employee_id === ligne.employee_id)
  const sujet = 'Formations obligatoires à régulariser'
  const corps = [
    `Bonjour ${ligne.salarie.split(' ')[0]},`,
    '',
    'Sauf erreur de notre part, les formations obligatoires suivantes n’ont pas été réalisées dans les délais :',
    ...autres.map((l) => `- ${l.formation} (échéance le ${formatDate(l.echeance)})`),
    '',
    'Merci de vous inscrire à une session depuis l’écran « Formations et inscription », ou de revenir vers nous.',
    '',
    'Le service RH',
  ].join('\n')
  const copie = manager?.email_pro ? `cc=${encodeURIComponent(manager.email_pro)}&` : ''
  return `mailto:${ligne.email ?? ''}?${copie}subject=${encodeURIComponent(sujet)}` +
         `&body=${encodeURIComponent(corps)}`
}

function exporter() {
  telechargerCsv('formations-obligatoires-hors-delai.csv', [
    { titre: 'Établissement', champ: 'etablissement' },
    { titre: 'Collaborateur', champ: 'salarie' },
    { titre: 'Matricule', champ: 'matricule' },
    { titre: 'E-mail', champ: 'email' },
    { titre: 'Poste', champ: 'poste' },
    { titre: 'Manager', champ: (l) => l.manager ?? '' },
    { titre: 'Formation obligatoire', champ: 'formation' },
    { titre: 'Situation', champ: (l) => libelle(ETATS_OBLIGATION, l.etat) },
    { titre: 'Dernière réalisation', champ: (l) => (l.realisee_le ? formatDate(l.realisee_le) : '') },
    { titre: 'Échéance', champ: (l) => formatDate(l.echeance) },
    { titre: 'Jours de retard', champ: 'jours_de_retard' },
    { titre: 'Session prévue', champ: (l) => (l.prochaine_session ? formatDate(l.prochaine_session) : '') },
  ], visibles.value)
}
</script>

<template>
  <PageHeader
    titre="Formations obligatoires hors délai"
    sousTitre="Les collaborateurs à relancer : leur formation obligatoire n’a pas été faite à temps"
  >
    <Button label="Extraire la liste de relance" icon="pi pi-download"
            :disabled="!visibles.length" @click="exporter" />
  </PageHeader>

  <div class="filtres">
    <Select v-model="etablissementCourantId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="formationId" :options="formations"
            optionLabel="intitule" optionValue="id"
            placeholder="Toutes les formations" showClear />
    <Select v-model="managerId" :options="managers"
            optionLabel="nom" optionValue="id"
            placeholder="Tous les managers" showClear />
  </div>

  <div class="stats">
    <StatCard titre="Collaborateurs à relancer" :valeur="totaux.collaborateurs" icone="pi pi-users" />
    <StatCard titre="Formations hors délai" :valeur="totaux.formations" icone="pi pi-clock" />
    <StatCard titre="Sans session prévue" :valeur="totaux.sansSession" icone="pi pi-calendar-times"
              precision="ni inscription ni demande en cours" />
    <StatCard titre="Plus gros retard" :valeur="`${totaux.pire} j`" icone="pi pi-exclamation-triangle" />
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="cle"
             paginator :rows="25" stripedRows size="small" removableSort>
    <template #empty>
      Aucun retard : toutes les formations obligatoires sont faites dans les délais.
    </template>

    <Column field="salarie" header="Collaborateur" sortable />
    <Column field="poste" header="Poste" sortable />
    <Column field="manager" header="Manager" sortable>
      <template #body="{ data }">{{ data.manager || '—' }}</template>
    </Column>
    <Column field="formation" header="Formation obligatoire" sortable />

    <Column field="etat" header="Situation" sortable style="width: 14rem">
      <template #body="{ data }">
        <Tag :value="libelle(ETATS_OBLIGATION, data.etat)"
             :severity="couleur(ETATS_OBLIGATION, data.etat)" />
      </template>
    </Column>

    <Column field="echeance" header="Échéance" sortable style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.echeance) }}</template>
    </Column>

    <Column field="jours_de_retard" header="Retard" sortable style="width: 7rem">
      <template #body="{ data }">
        <span class="retard">{{ data.jours_de_retard }} j</span>
      </template>
    </Column>

    <Column field="prochaine_session" header="Session prévue" sortable style="width: 9rem">
      <template #body="{ data }">{{ formatDate(data.prochaine_session) }}</template>
    </Column>

    <Column style="width: 8rem">
      <template #body="{ data }">
        <a class="relance" :href="mailDeRelance(data)">
          <i class="pi pi-envelope" /> Relancer
        </a>
      </template>
    </Column>
  </DataTable>

  <p class="note">
    Délais appliqués : {{ DELAI_INITIAL_MOIS }} mois après l’arrivée pour une formation jamais
    suivie, et la fin de la période de validité pour une formation à recycler.
  </p>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 15rem; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.retard { color: var(--p-red-500); font-weight: 600; }
.relance { color: var(--p-primary-color); text-decoration: none; font-size: .9rem; white-space: nowrap; }
.relance:hover { text-decoration: underline; }
.note { color: var(--p-text-muted-color); font-size: .85rem; margin-top: 1rem; }
</style>
