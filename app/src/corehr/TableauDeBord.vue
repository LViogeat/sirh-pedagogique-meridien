<script setup>
import { ref, computed, onMounted } from 'vue'
import { getEmployes, getEffectifParService, getMouvements,
         formatEuro, formatNombre, anciennete } from '@/socle/sdk'

// Palette catégorielle validée : deux teintes seulement, car aucun graphique
// ici ne porte plus de deux séries. Écart perceptif contrôlé (ΔE 24,7 en
// protanopie, 33,6 en vision normale sur fond blanc).
const SERIE_1 = '#2a78d6'   // bleu
const SERIE_2 = '#eb6834'   // orange
const ENCRE   = '#52514e'   // les textes portent une couleur de texte,
const GRILLE  = '#ececeb'   // jamais celle d'une série
const FOND    = '#ffffff'   // le fond des cartes, pour séparer deux aplats

const salaries = ref([])
const parService = ref([])
const mouvements = ref([])
const chargement = ref(true)
const vueTableau = ref(false)

onMounted(async () => {
  try {
    ;[salaries.value, parService.value, mouvements.value] =
      await Promise.all([getEmployes(), getEffectifParService(), getMouvements()])
  } finally {
    chargement.value = false
  }
})

// ---- Indicateurs ------------------------------------------------------------

const effectif = computed(() => salaries.value.length)
const etp = computed(() => salaries.value.reduce((t, e) => t + Number(e.etp || 0), 0))
const masse = computed(() =>
  salaries.value.reduce((t, e) => t + Number(e.salaire_base_brut_mensuel || 0), 0))
const ageMoyen = computed(() => moyenne(salaries.value.map(e => e.age)))
const ancMoyenne = computed(() => moyenne(salaries.value.map(e => e.anciennete_mois)))

function moyenne(valeurs) {
  const v = valeurs.filter(x => x !== null && x !== undefined)
  return v.length ? v.reduce((a, b) => a + Number(b), 0) / v.length : 0
}

/** Turnover = sorties des 12 derniers mois rapportées à l'effectif moyen. */
const turnover = computed(() => {
  const douze = mouvements.value.slice(-12)
  const sorties = douze.reduce((t, m) => t + Number(m.sorties || 0), 0)
  const entrees = douze.reduce((t, m) => t + Number(m.entrees || 0), 0)
  const moyen = effectif.value - (entrees - sorties) / 2
  return moyen > 0 ? (sorties / moyen) * 100 : 0
})

// ---- Données des graphiques -------------------------------------------------

const tronquer = (texte, max = 26) =>
  String(texte).length > max ? String(texte).slice(0, max - 1) + '…' : String(texte)

const optionsCommunes = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { padding: 10, boxPadding: 4 },
  },
  scales: {
    x: { grid: { color: GRILLE, drawBorder: false }, ticks: { color: ENCRE, precision: 0 } },
    y: { grid: { display: false },
         ticks: { color: ENCRE, autoSkip: false,
                  callback(v) { return tronquer(this.getLabelForValue(v)) } } },
  },
}

// Effectif par service — une seule série, donc une seule teinte et pas de légende.
const graphServices = computed(() => {
  const lignes = [...parService.value].sort((a, b) => b.effectif - a.effectif)
  return {
    labels: lignes.map(l => l.service),
    datasets: [{
      label: 'Effectif',
      data: lignes.map(l => l.effectif),
      backgroundColor: SERIE_1,
      borderRadius: 4,
      borderSkipped: false,
      barThickness: 14,
    }],
  }
})
const optionsServices = { ...optionsCommunes, indexAxis: 'y' }

// Répartition par type de contrat — une seule série également.
const graphContrats = computed(() => {
  const compte = {}
  for (const e of salaries.value) compte[e.type_contrat] = (compte[e.type_contrat] || 0) + 1
  const lignes = Object.entries(compte).sort((a, b) => b[1] - a[1])
  return {
    labels: lignes.map(l => l[0]),
    datasets: [{
      label: 'Salariés',
      data: lignes.map(l => l[1]),
      backgroundColor: SERIE_1,
      borderRadius: 4,
      borderSkipped: false,
      barThickness: 18,
    }],
  }
})
const optionsContrats = { ...optionsCommunes, indexAxis: 'y' }

// Pyramide des âges — deux séries, donc légende obligatoire.
const TRANCHES = ['moins de 25', '25–29', '30–34', '35–39', '40–44',
                  '45–49', '50–54', '55–59', '60 et plus']
function trancheDe(age) {
  if (age < 25) return TRANCHES[0]
  if (age >= 60) return TRANCHES[8]
  return TRANCHES[Math.floor((age - 25) / 5) + 1]
}
const pyramide = computed(() => {
  const h = Object.fromEntries(TRANCHES.map(t => [t, 0]))
  const f = Object.fromEntries(TRANCHES.map(t => [t, 0]))
  for (const e of salaries.value) {
    if (e.age === null || e.age === undefined) continue
    const t = trancheDe(e.age)
    if (e.civilite_code === 'MME') f[t]++ ; else h[t]++
  }
  return { h, f }
})
// On n'affiche pas les tranches vides : une ligne à zéro n'apprend rien.
const tranchesPeuplees = computed(() =>
  TRANCHES.filter(t => pyramide.value.h[t] + pyramide.value.f[t] > 0))

const graphPyramide = computed(() => ({
  labels: tranchesPeuplees.value,
  datasets: [
    { label: 'Hommes', data: tranchesPeuplees.value.map(t => -pyramide.value.h[t]),
      backgroundColor: SERIE_1, borderRadius: 4, borderSkipped: false, barThickness: 16,
      // 2 px de fond au point de rencontre : deux aplats ne se touchent jamais.
      borderColor: FOND, borderWidth: { top: 0, bottom: 0, left: 0, right: 2 } },
    { label: 'Femmes', data: tranchesPeuplees.value.map(t => pyramide.value.f[t]),
      backgroundColor: SERIE_2, borderRadius: 4, borderSkipped: false, barThickness: 16,
      borderColor: FOND, borderWidth: { top: 0, bottom: 0, left: 2, right: 0 } },
  ],
}))
const optionsPyramide = {
  responsive: true, maintainAspectRatio: false, indexAxis: 'y',
  plugins: {
    legend: { display: true, position: 'bottom',
              labels: { color: ENCRE, usePointStyle: true, pointStyle: 'circle', boxWidth: 8 } },
    tooltip: { callbacks: { label: (c) => `${c.dataset.label} : ${Math.abs(c.raw)}` } },
  },
  scales: {
    x: { stacked: true, grid: { color: GRILLE, drawBorder: false },
         ticks: { color: ENCRE, callback: (v) => Math.abs(v) } },
    y: { stacked: true, grid: { display: false },
         ticks: { color: ENCRE, autoSkip: false } },
  },
}

// Entrées et sorties — deux séries dans le temps.
const graphMouvements = computed(() => {
  const douze = mouvements.value.slice(-24)
  const mois = (d) => {
    const x = new Date(d)
    return x.toLocaleDateString('fr-FR', { month: 'short', year: '2-digit' })
  }
  return {
    labels: douze.map(m => mois(m.mois)),
    datasets: [
      { label: 'Entrées', data: douze.map(m => m.entrees), borderColor: SERIE_1,
        backgroundColor: SERIE_1, borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, tension: .3 },
      { label: 'Sorties', data: douze.map(m => m.sorties), borderColor: SERIE_2,
        backgroundColor: SERIE_2, borderWidth: 2, pointRadius: 0, pointHoverRadius: 5, tension: .3 },
    ],
  }
})
const optionsMouvements = {
  responsive: true, maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  plugins: {
    legend: { display: true, position: 'bottom',
              labels: { color: ENCRE, usePointStyle: true, pointStyle: 'circle', boxWidth: 8 } },
  },
  scales: {
    x: { grid: { display: false }, ticks: { color: ENCRE, maxRotation: 0, autoSkipPadding: 12 } },
    y: { beginAtZero: true, grid: { color: GRILLE, drawBorder: false },
         ticks: { color: ENCRE, precision: 0 } },
  },
}

// Vue tableau — l'équivalent textuel de chaque graphique.
const lignesPyramide = computed(() =>
  tranchesPeuplees.value.map(t => ({
    tranche: t,
    hommes: pyramide.value.h[t],
    femmes: pyramide.value.f[t],
    total:  pyramide.value.h[t] + pyramide.value.f[t],
  })))
</script>

<template>
  <PageHeader titre="Tableau de bord" sousTitre="Effectif présent au jour de consultation">
    <Button :label="vueTableau ? 'Voir les graphiques' : 'Voir les chiffres'"
            :icon="vueTableau ? 'pi pi-chart-bar' : 'pi pi-table'"
            severity="secondary" outlined @click="vueTableau = !vueTableau" />
  </PageHeader>

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <template v-else>
    <div class="grille-stats">
      <StatCard titre="Effectif présent" :valeur="formatNombre(effectif)" icone="pi pi-users"
                precision="personnes physiques" />
      <StatCard titre="ETP" :valeur="formatNombre(etp, 2)" icone="pi pi-percentage"
                precision="équivalents temps plein" />
      <StatCard titre="Masse salariale" :valeur="formatEuro(masse, { decimales: 0 })"
                icone="pi pi-euro" precision="brut contractuel mensuel" />
      <StatCard titre="Âge moyen" :valeur="`${formatNombre(ageMoyen, 1)} ans`" icone="pi pi-calendar" />
      <StatCard titre="Ancienneté moyenne" :valeur="anciennete(Math.round(ancMoyenne))"
                icone="pi pi-clock" />
      <StatCard titre="Turnover" :valeur="`${formatNombre(turnover, 1)} %`" icone="pi pi-sync"
                precision="sorties sur 12 mois glissants" />
    </div>

    <!-- Vue chiffrée : l'équivalent textuel de chaque graphique. -->
    <div v-if="vueTableau" class="tableaux">
      <div class="bloc">
        <h2>Effectif par service</h2>
        <DataTable :value="[...parService].sort((a,b) => b.effectif - a.effectif)" size="small" stripedRows>
          <Column field="service" header="Service" />
          <Column field="effectif" header="Effectif" />
          <Column field="etp" header="ETP" />
        </DataTable>
      </div>
      <div class="bloc">
        <h2>Pyramide des âges</h2>
        <DataTable :value="lignesPyramide" size="small" stripedRows>
          <Column field="tranche" header="Tranche d’âge" />
          <Column field="hommes" header="Hommes" />
          <Column field="femmes" header="Femmes" />
          <Column field="total" header="Total" />
        </DataTable>
      </div>
      <div class="bloc large">
        <h2>Entrées et sorties</h2>
        <DataTable :value="[...mouvements].slice(-24).reverse()" size="small" stripedRows
                   paginator :rows="12">
          <Column field="mois" header="Mois" />
          <Column field="entrees" header="Entrées" />
          <Column field="sorties" header="Sorties" />
        </DataTable>
      </div>
    </div>

    <div v-else class="graphiques">
      <div class="bloc">
        <h2>Effectif par service</h2>
        <div class="zone haute"><Chart type="bar" :data="graphServices" :options="optionsServices" /></div>
      </div>

      <div class="bloc">
        <h2>Pyramide des âges</h2>
        <div class="zone haute"><Chart type="bar" :data="graphPyramide" :options="optionsPyramide" /></div>
      </div>

      <div class="bloc">
        <h2>Répartition par type de contrat</h2>
        <div class="zone"><Chart type="bar" :data="graphContrats" :options="optionsContrats" /></div>
      </div>

      <div class="bloc large">
        <h2>Entrées et sorties sur 24 mois</h2>
        <div class="zone haute-mi"><Chart type="line" :data="graphMouvements" :options="optionsMouvements" /></div>
      </div>
    </div>

    <Message severity="info" :closable="false" class="note">
      Le turnover et les mouvements ne sont calculables que parce que le modèle est
      <strong>historisé</strong>. Sur un référentiel « un salarié = une ligne », ces
      indicateurs n’existeraient tout simplement pas.
    </Message>
  </template>
</template>

<style scoped>
.attente { display: grid; place-items: center; min-height: 14rem; }
.graphiques, .tableaux {
  display: grid; gap: 1rem; align-items: start;
  grid-template-columns: repeat(auto-fit, minmax(26rem, 1fr));
}
.bloc {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1.1rem 1.25rem; min-width: 0;
}
.bloc.large { grid-column: 1 / -1; }
.zone.haute-mi { height: 19rem; }
h2 { margin: 0 0 1rem; font-size: .95rem; font-weight: 600; }
.zone { height: 15rem; position: relative; }
.zone.haute { height: 25rem; }

/* PrimeVue enveloppe le canvas dans un div : sans cette règle, le graphique
   ne remplit pas la hauteur réservée et laisse un grand vide sous lui. */
.zone :deep(.p-chart) { height: 100%; width: 100%; }
.zone :deep(canvas) { height: 100% !important; width: 100% !important; }
.note { margin-top: 1.25rem; }
</style>
