<!-- libelle: Suivi réglementaire et habilitations -->
<script setup>
/**
 * Story #63 — Le Responsable RH d'établissement suit les formations
 * réglementaires et les habilitations obligatoires, pour s'assurer que les
 * collaborateurs concernés répondent aux exigences de leur poste.
 *
 * En haut, une ligne par formation obligatoire : combien de salariés sont
 * concernés, combien sont à jour, combien arrivent à échéance. En dessous,
 * le détail nominatif. Une habilitation est une formation obligatoire qui a
 * une durée de validité (elle est « à recycler » tous les N mois).
 */
import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, getEtablissements, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSuiviObligations, ETATS_OBLIGATION, ALERTE_ECHEANCE_JOURS,
  libelle, couleur, telechargerCsv, etablissementCourantId,
} from './_donnees'

const etablissements = ref([])
const lignes = ref([])
const chargement = ref(true)

const formationId = ref(null)
const etat = ref(null)
const habilitationsSeules = ref(false)
const echeancesProches = ref(false)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    const salaries = await getSalaries({ etablissementId: etablissementCourantId.value })
    lignes.value = await chargerSuiviObligations(salaries)
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

watch(etablissementCourantId, charger)

/** La synthèse : une ligne par formation obligatoire. */
const synthese = computed(() => {
  const parFormation = new Map()
  for (const l of lignes.value) {
    const f = parFormation.get(l.formation_id) ?? {
      id: l.formation_id, formation: l.formation, domaine: l.domaine,
      periodicite_mois: l.periodicite_mois,
      concernes: 0, aJour: 0, bientot: 0, enRetard: 0,
    }
    f.concernes += 1
    if (l.etat === 'a_jour') f.aJour += 1
    if (l.bientot) f.bientot += 1
    if (l.en_retard) f.enRetard += 1
    parFormation.set(l.formation_id, f)
  }
  return [...parFormation.values()]
    .filter((f) => !habilitationsSeules.value || f.periodicite_mois)
    .map((f) => ({ ...f, taux: Math.round((f.aJour / f.concernes) * 100) }))
    .sort((a, b) => a.taux - b.taux)
})

const visibles = computed(() =>
  lignes.value
    .filter((l) =>
      (!formationId.value || l.formation_id === formationId.value) &&
      (!etat.value || l.etat === etat.value) &&
      (!habilitationsSeules.value || l.periodicite_mois) &&
      (!echeancesProches.value || l.bientot || l.en_retard))
    .sort((a, b) =>
      String(a.echeance ?? '9999').localeCompare(String(b.echeance ?? '9999')) ||
      a.salarie.localeCompare(b.salarie)))

const totaux = computed(() => {
  const base = lignes.value.filter((l) => !habilitationsSeules.value || l.periodicite_mois)
  const aJour = base.filter((l) => l.etat === 'a_jour').length
  return {
    total: base.length,
    aJour,
    taux: base.length ? Math.round((aJour / base.length) * 100) : null,
    bientot: base.filter((l) => l.bientot).length,
    enRetard: base.filter((l) => l.en_retard).length,
  }
})

function exporter() {
  telechargerCsv('suivi-formations-reglementaires.csv', [
    { titre: 'Établissement', champ: 'etablissement' },
    { titre: 'Collaborateur', champ: 'salarie' },
    { titre: 'Matricule', champ: 'matricule' },
    { titre: 'Poste', champ: 'poste' },
    { titre: 'Formation obligatoire', champ: 'formation' },
    { titre: 'Validité (mois)', champ: (l) => l.periodicite_mois ?? '' },
    { titre: 'Situation', champ: (l) => libelle(ETATS_OBLIGATION, l.etat) },
    { titre: 'Dernière réalisation', champ: (l) => (l.realisee_le ? formatDate(l.realisee_le) : '') },
    { titre: 'Échéance', champ: (l) => (l.echeance ? formatDate(l.echeance) : '') },
    { titre: 'Session prévue', champ: (l) => (l.prochaine_session ? formatDate(l.prochaine_session) : '') },
  ], visibles.value)
}
</script>

<template>
  <PageHeader
    titre="Suivi réglementaire et habilitations"
    sousTitre="Les formations obligatoires de mon établissement : qui est à jour, qui arrive à échéance"
  >
    <Button label="Exporter" icon="pi pi-download" severity="secondary" outlined
            :disabled="!visibles.length" @click="exporter" />
  </PageHeader>

  <div class="filtres">
    <Select v-model="etablissementCourantId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <div class="bascule">
      <ToggleSwitch v-model="habilitationsSeules" inputId="habilitations" />
      <label for="habilitations">Seulement les habilitations (formations à durée de validité)</label>
    </div>
  </div>

  <div class="stats">
    <StatCard titre="Taux de conformité"
              :valeur="totaux.taux === null ? '—' : `${totaux.taux} %`"
              icone="pi pi-shield" :precision="`${totaux.aJour} à jour sur ${totaux.total}`" />
    <StatCard titre="Échéances proches" :valeur="totaux.bientot" icone="pi pi-calendar"
              :precision="`à renouveler dans les ${ALERTE_ECHEANCE_JOURS} jours`" />
    <StatCard titre="Hors délai" :valeur="totaux.enRetard" icone="pi pi-clock"
              precision="échéance dépassée" />
  </div>

  <h3>Par formation</h3>
  <DataTable :value="synthese" :loading="chargement" dataKey="id"
             size="small" stripedRows rowHover
             @row-click="(e) => (formationId = formationId === e.data.id ? null : e.data.id)">
    <template #empty>Aucune formation obligatoire ne concerne cet établissement.</template>

    <Column field="formation" header="Formation obligatoire" />
    <Column field="domaine" header="Domaine" />
    <Column header="Validité" style="width: 9rem">
      <template #body="{ data }">
        {{ data.periodicite_mois ? `${data.periodicite_mois} mois` : 'Sans limite' }}
      </template>
    </Column>
    <Column field="concernes" header="Concernés" style="width: 7rem" />
    <Column field="aJour" header="À jour" style="width: 6rem" />
    <Column header="Conformité" style="width: 14rem">
      <template #body="{ data }">
        <div class="jauge">
          <span class="piste"><span class="plein" :class="{ bas: data.taux < 50 }"
                                    :style="{ width: `${data.taux}%` }" /></span>
          <span class="taux">{{ data.taux }} %</span>
        </div>
      </template>
    </Column>
    <Column header="Échéances proches" style="width: 10rem">
      <template #body="{ data }">
        <Tag v-if="data.bientot" :value="data.bientot" severity="warn" />
        <span v-else>—</span>
      </template>
    </Column>
    <Column header="Hors délai" style="width: 7rem">
      <template #body="{ data }">
        <Tag v-if="data.enRetard" :value="data.enRetard" severity="danger" />
        <span v-else>—</span>
      </template>
    </Column>
  </DataTable>

  <h3>Par collaborateur</h3>
  <div class="filtres">
    <Select v-model="formationId" :options="synthese"
            optionLabel="formation" optionValue="id"
            placeholder="Toutes les formations obligatoires" showClear />
    <Select v-model="etat" :options="ETATS_OBLIGATION"
            optionLabel="label" optionValue="code"
            placeholder="Toutes les situations" showClear />
    <div class="bascule">
      <ToggleSwitch v-model="echeancesProches" inputId="echeances" />
      <label for="echeances">Seulement les échéances proches ou dépassées</label>
    </div>
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="cle"
             paginator :rows="25" stripedRows size="small" removableSort>
    <template #empty>Aucune ligne ne correspond à ces critères.</template>

    <Column field="salarie" header="Collaborateur" sortable />
    <Column field="poste" header="Poste" sortable />
    <Column field="etablissement" header="Établissement" sortable />
    <Column field="formation" header="Formation obligatoire" sortable />

    <Column field="etat" header="Situation" sortable style="width: 15rem">
      <template #body="{ data }">
        <Tag :value="libelle(ETATS_OBLIGATION, data.etat)"
             :severity="couleur(ETATS_OBLIGATION, data.etat)" />
      </template>
    </Column>

    <Column field="realisee_le" header="Dernière réalisation" sortable style="width: 11rem">
      <template #body="{ data }">{{ formatDate(data.realisee_le) }}</template>
    </Column>

    <Column field="echeance" header="Échéance" sortable style="width: 12rem">
      <template #body="{ data }">
        <span :class="{ retard: data.en_retard }">{{ formatDate(data.echeance) }}</span>
        <Tag v-if="data.en_retard" value="Dépassée" severity="danger" class="marge" />
        <Tag v-else-if="data.bientot" value="Bientôt" severity="warn" class="marge" />
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .9rem; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
h3 { font-size: 1rem; margin: 1.5rem 0 .6rem; }
.jauge { display: flex; align-items: center; gap: .5rem; }
.piste { flex: 1; background: var(--p-surface-200); border-radius: 6px; height: .7rem; overflow: hidden; }
.plein { display: block; height: 100%; background: var(--p-green-500); }
.plein.bas { background: var(--p-red-500); }
.taux { width: 3.2rem; text-align: right; font-size: .85rem; }
.retard { color: var(--p-red-500); font-weight: 600; }
.marge { margin-left: .4rem; }
</style>
