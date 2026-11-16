<!-- libelle: Situation du jour -->
<script setup>
/**
 * La vision de la journée d'un établissement, pour le manager (#134).
 *
 * Chaque salarié avec son horaire prévu, ses pointages et un statut :
 *   Présent           — a pointé sur site
 *   Télétravail       — a pointé en télétravail
 *   Absent            — devait travailler, n'a pas pointé, et son heure de
 *                       début est dépassée de plus de TOLERANCE minutes
 *   Pas encore pointé — devait travailler, son heure de début n'est pas passée
 *   Repos             — jour de repos dans son profil horaire
 *   Sans horaire      — aucun profil horaire affecté : rien à attendre
 */
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { getEtablissements, getSalaries, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, aujourdhui, heureActuelle, horairesDuJour, pointagesDuJour,
  libellerPointages, heure, versDateIso, jourDeSemaine,
} from './_gta.js'

/** Retard toléré avant de compter quelqu'un comme absent, en minutes. */
const TOLERANCE = 15

const etablissements = ref([])
const etablissementId = ref(null)
const date = ref(new Date())
const salaries = ref([])
const horaires = ref({})
const pointages = ref({})
const chargement = ref(true)
const filtreStatut = ref(null)
const maintenant = ref(heureActuelle())

let minuteur = null
onMounted(async () => {
  minuteur = setInterval(() => { maintenant.value = heureActuelle() }, 30000)
  try {
    await preparerSchema()
    etablissements.value = await getEtablissements()
    etablissementId.value = etablissements.value[0]?.id ?? null
  } catch (erreur) {
    toast.erreur(erreur.message)
    chargement.value = false
  }
})
onUnmounted(() => clearInterval(minuteur))

const jour = computed(() => versDateIso(date.value) ?? aujourdhui())

async function charger() {
  if (!etablissementId.value) return
  chargement.value = true
  try {
    const lesSalaries = await getSalaries({ etablissementId: etablissementId.value })
    const ids = lesSalaries.map((s) => s.id)
    const [h, p] = await Promise.all([horairesDuJour(ids, jour.value), pointagesDuJour(ids, jour.value)])
    // Tout est remplacé d'un coup : jamais une liste affichée sans ses horaires.
    horaires.value = h
    pointages.value = p
    salaries.value = lesSalaries
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

watch([etablissementId, jour], charger)

const enMinutes = (h) => { const [hh, mm] = heure(h).split(':').map(Number); return hh * 60 + mm }

const STATUTS = {
  present: { libelle: 'Présent', severite: 'success', icone: 'pi pi-check-circle' },
  teletravail: { libelle: 'Télétravail', severite: 'info', icone: 'pi pi-home' },
  absent: { libelle: 'Absent', severite: 'danger', icone: 'pi pi-times-circle' },
  attendu: { libelle: 'Pas encore pointé', severite: 'warn', icone: 'pi pi-hourglass' },
  repos: { libelle: 'Repos', severite: 'secondary', icone: 'pi pi-moon' },
  sans_horaire: { libelle: 'Sans horaire', severite: 'secondary', icone: 'pi pi-question-circle' },
}

function statutDe(horaire, lesPointages) {
  if (lesPointages.length) {
    return lesPointages.some((p) => p.lieu === 'teletravail') ? 'teletravail' : 'present'
  }
  if (!horaire) return 'sans_horaire'
  if (!horaire.code) return 'repos'
  if (jour.value < aujourdhui()) return 'absent'
  if (jour.value > aujourdhui()) return 'attendu'
  return enMinutes(maintenant.value) > enMinutes(horaire.code.heure_debut) + TOLERANCE
    ? 'absent' : 'attendu'
}

const lignes = computed(() => salaries.value.map((s) => {
  const horaire = horaires.value[s.id] ?? null
  const lesPointages = libellerPointages(pointages.value[s.id] ?? [])
  const statut = statutDe(horaire, lesPointages)
  const dernier = lesPointages.at(-1)
  return {
    ...s,
    horaire,
    pointages: lesPointages,
    statut,
    parti: dernier?.libelle === 'Départ' ? heure(dernier.heure) : null,
    ordre: Object.keys(STATUTS).indexOf(statut),
  }
}))

const compte = computed(() => Object.fromEntries(
  Object.keys(STATUTS).map((k) => [k, lignes.value.filter((l) => l.statut === k).length])))

const affichees = computed(() => (filtreStatut.value
  ? lignes.value.filter((l) => l.statut === filtreStatut.value)
  : lignes.value))

const basculerFiltre = (k) => { filtreStatut.value = filtreStatut.value === k ? null : k }
</script>

<template>
  <PageHeader titre="Situation du jour"
              :sousTitre="`${jourDeSemaine(jour).libelle} ${formatDate(jour, 'long')} · ${salaries.length} salarié(s)`" />

  <div class="filtres">
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id" placeholder="Choisir un hôtel" />
    <DatePicker v-model="date" dateFormat="dd/mm/yy" showIcon />
    <Button icon="pi pi-refresh" text rounded aria-label="Actualiser" v-tooltip="'Actualiser'" @click="charger" />
  </div>

  <div class="compteurs">
    <button v-for="(s, k) in STATUTS" :key="k" type="button" class="compteur"
            :class="[k, { actif: filtreStatut === k }]" @click="basculerFiltre(k)">
      <i :class="s.icone" />
      <span class="nombre">{{ compte[k] }}</span>
      <span class="libelle">{{ s.libelle }}</span>
    </button>
  </div>

  <DataTable :value="affichees" :loading="chargement" dataKey="id"
             sortField="ordre" :sortOrder="1" removableSort stripedRows size="small" rowHover
             paginator :rows="30">
    <template #empty>Aucun salarié ne correspond.</template>

    <Column field="full_name" header="Salarié" sortable>
      <template #body="{ data }">
        <div>{{ data.full_name }}</div>
        <div class="detail">{{ data.position_title }} · {{ data.department_label }}</div>
      </template>
    </Column>

    <Column header="Horaire prévu" style="width: 12rem">
      <template #body="{ data }">
        <template v-if="data.horaire?.code">
          <Tag :value="data.horaire.code.code" />
          <span class="plage">{{ heure(data.horaire.code.heure_debut) }}–{{ heure(data.horaire.code.heure_fin) }}</span>
        </template>
        <span v-else-if="data.horaire" class="detail">Repos ({{ data.horaire.profil.code }})</span>
        <span v-else class="detail">Aucun profil</span>
      </template>
    </Column>

    <Column header="Pointages">
      <template #body="{ data }">
        <div v-if="data.pointages.length" class="puces">
          <span v-for="p in data.pointages" :key="p.id" class="puce" :title="p.libelle">
            <i :class="p.sens === 'entree' ? 'pi pi-sign-in entree' : 'pi pi-sign-out sortie'" />
            {{ heure(p.heure) }}
          </span>
        </div>
        <span v-else class="detail">—</span>
      </template>
    </Column>

    <Column field="ordre" header="Statut" sortable style="width: 13rem">
      <template #body="{ data }">
        <Tag :value="STATUTS[data.statut].libelle" :severity="STATUTS[data.statut].severite"
             :icon="STATUTS[data.statut].icone" />
        <div v-if="data.parti" class="detail">parti à {{ data.parti }}</div>
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.compteurs { display: grid; grid-template-columns: repeat(6, 1fr); gap: .75rem; margin-bottom: 1rem; }
.compteur { display: grid; grid-template-columns: auto 1fr; grid-template-rows: auto auto; column-gap: .75rem;
            align-items: center; text-align: left; cursor: pointer; font: inherit; color: inherit;
            padding: .75rem 1rem; border-radius: .75rem; background: var(--p-content-background);
            border: 1px solid var(--p-content-border-color); }
.compteur i { grid-row: span 2; font-size: 1.4rem; }
.compteur .nombre { font-size: 1.5rem; font-weight: 700; line-height: 1.1; }
.compteur .libelle { font-size: .8rem; color: var(--p-text-muted-color); }
.compteur.actif { outline: 2px solid var(--p-primary-color); }
.present i { color: var(--p-green-500); }
.teletravail i { color: var(--p-sky-500); }
.absent i { color: var(--p-red-500); }
.attendu i { color: var(--p-orange-500); }
.repos i, .sans_horaire i { color: var(--p-surface-400); }
.detail { color: var(--p-text-muted-color); font-size: .8rem; }
.plage { margin-left: .5rem; font-variant-numeric: tabular-nums; }
.puces { display: flex; flex-wrap: wrap; gap: .4rem; }
.puce { display: inline-flex; align-items: center; gap: .3rem; padding: .15rem .5rem; border-radius: 1rem;
        background: var(--p-content-hover-background); font-size: .85rem; font-variant-numeric: tabular-nums; }
.entree { color: var(--p-green-500); }
.sortie { color: var(--p-orange-500); }
@media (max-width: 900px) { .compteurs { grid-template-columns: repeat(2, 1fr); } }
</style>
