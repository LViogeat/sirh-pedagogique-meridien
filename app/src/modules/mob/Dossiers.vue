<!-- libelle: Dossiers de mobilité -->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { sql, getDateReference, formatDate, toast } from '@/socle/sdk'

const ETAPES = [
  { code: 'analyse', label: 'Analyse', severite: 'info' },
  { code: 'propositions', label: 'Propositions', severite: 'warn' },
  { code: 'entretien', label: 'Entretien', severite: 'warn' },
  { code: 'decision', label: 'Décision', severite: 'contrast' },
  { code: 'termine', label: 'Terminé', severite: 'success' },
]
const etapeDe = (code) => ETAPES.find((e) => e.code === code) || { label: code, severite: 'secondary' }

const dossiers = ref([])
const dateReference = ref(null)
const chargement = ref(true)

const etape = ref(null)
const afficherTermines = ref(false)

async function charger() {
  chargement.value = true
  try {
    const [lignes, dateRef] = await Promise.all([
      sql(`
        select d.id, d.besoin_id, d.employee_id, d.conseiller, d.etape, d.issue,
               d.ouvert_le, d.clos_le,
               e.first_name || ' ' || e.last_name as salarie,
               e.matricule,
               p.title as poste_vise,
               s.name  as hotel_vise
          from dossiers d
          join public.identified_needs n on n.id = d.besoin_id
          join public.employees        e on e.id = d.employee_id
          join public.positions        p on p.id = n.position_id
          join public.establishments   s on s.id = n.establishment_id
         order by d.ouvert_le desc, d.id desc
      `),
      getDateReference(),
    ])
    dossiers.value = lignes
    dateReference.value = dateRef
  } catch (erreur) {
    toast.erreur(erreur.message)
    dossiers.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(charger)

/* Nombre de jours entre l'ouverture et la date de référence (jamais l'horloge). */
function joursEcoules(ouvertLe) {
  if (!dateReference.value || !ouvertLe) return null
  const ms = new Date(dateReference.value) - new Date(ouvertLe)
  return Math.max(0, Math.round(ms / 86400000))
}

const lignes = computed(() =>
  dossiers.value.filter((d) => {
    if (etape.value) return d.etape === etape.value
    return afficherTermines.value || d.etape !== 'termine'
  }))

const enCours = computed(() => dossiers.value.filter((d) => d.etape !== 'termine').length)
</script>

<template>
  <PageHeader
    titre="Dossiers de mobilité"
    :sousTitre="`${enCours} dossier(s) en cours · date de référence ${formatDate(dateReference)}`"
  />

  <div class="filtres">
    <Select v-model="etape" :options="ETAPES" optionLabel="label" optionValue="code"
            placeholder="Toutes les étapes" showClear />
    <label class="interrupteur">
      <ToggleSwitch v-model="afficherTermines" :disabled="!!etape" />
      <span>Afficher les dossiers terminés</span>
    </label>
  </div>

  <DataTable
    :value="lignes" :loading="chargement" dataKey="id"
    paginator :rows="20" stripedRows size="small"
  >
    <template #empty>
      <div class="vide">
        <i class="pi pi-folder-open" />
        Aucun dossier : prenez en charge un besoin depuis l'écran Prise en charge.
      </div>
    </template>

    <Column field="salarie" header="Salarié">
      <template #body="{ data }">
        <div class="salarie">{{ data.salarie }}</div>
        <small class="discret">{{ data.matricule }}</small>
      </template>
    </Column>
    <Column field="poste_vise" header="Poste visé" />
    <Column field="hotel_vise" header="Hôtel visé" />
    <Column field="etape" header="Étape" style="width: 9rem">
      <template #body="{ data }">
        <Tag :value="etapeDe(data.etape).label" :severity="etapeDe(data.etape).severite" />
      </template>
    </Column>
    <Column field="conseiller" header="Conseiller" />
    <Column field="ouvert_le" header="Ouvert le" style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.ouvert_le) }}</template>
    </Column>
    <Column header="Jours écoulés" style="width: 8rem">
      <template #body="{ data }">{{ joursEcoules(data.ouvert_le) ?? '—' }} j</template>
    </Column>
  </DataTable>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 13rem; }
.interrupteur { display: flex; align-items: center; gap: .5rem; }
.salarie { font-weight: 600; }
.discret { color: var(--p-text-muted-color); }
.vide { display: flex; align-items: center; gap: .6rem; padding: 1.5rem; color: var(--p-text-muted-color); }
</style>
