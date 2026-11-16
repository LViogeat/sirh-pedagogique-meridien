<!-- libelle: Affectation des profils -->
<script setup>
/**
 * Affecter un profil horaire aux salariés d'un hôtel (#132).
 *
 * Les salariés sont lus dans le Core RH (getSalaries) ; l'affectation est
 * enregistrée chez nous (affectations_profil). Le profil affiché sur la ligne
 * est la dernière affectation du salarié.
 */
import { ref, computed, onMounted, watch } from 'vue'
import {
  getEtablissements, getSalaries, getDateReference, sql, insert,
  formatDate, formatNombre, toast,
} from '@/socle/sdk'
import { preparerSchema, dureeMinutes, formatDuree, JOURS, versDateIso } from './_gta.js'

const etablissements = ref([])
const etablissementId = ref(null)
const salaries = ref([])
const profils = ref([])
const codes = ref([])
const affectations = ref([])
const dateReference = ref(null)
const chargement = ref(true)
const recherche = ref('')
const selection = ref([])

/** Durée hebdomadaire légale d'un temps plein, pour comparer au contrat. */
const TEMPS_PLEIN_MINUTES = 35 * 60

async function chargerReferentiels() {
  try {
    await preparerSchema()
    const [etabs, dateRef, lesCodes, lesProfils] = await Promise.all([
      getEtablissements(),
      getDateReference(),
      sql('select * from codes_horaires'),
      sql('select * from profils_horaires order by code'),
    ])
    etablissements.value = etabs
    dateReference.value = dateRef
    codes.value = lesCodes
    profils.value = lesProfils
    etablissementId.value = etabs[0]?.id ?? null
  } catch (erreur) {
    toast.erreur(erreur.message)
    chargement.value = false
  }
}

async function chargerSalaries() {
  if (!etablissementId.value) return
  chargement.value = true
  selection.value = []
  try {
    const [lesSalaries, lesAffectations] = await Promise.all([
      getSalaries({ etablissementId: etablissementId.value }),
      // La dernière affectation de chaque salarié.
      sql(`select distinct on (employee_id) *
           from affectations_profil
           order by employee_id, date_debut desc, id desc`),
    ])
    salaries.value = lesSalaries
    affectations.value = lesAffectations
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  await chargerReferentiels()
  await chargerSalaries()
})

watch(etablissementId, chargerSalaries)

const codeParId = computed(() => Object.fromEntries(codes.value.map((c) => [c.id, c])))
const profilParId = computed(() => Object.fromEntries(profils.value.map((p) => [p.id, p])))
const affectationParSalarie = computed(() =>
  Object.fromEntries(affectations.value.map((a) => [a.employee_id, a])))

const minutesProfil = (profil) =>
  profil ? JOURS.reduce((t, j) => t + dureeMinutes(codeParId.value[profil[j.cle]]), 0) : 0

/** Chaque salarié avec son profil, prêt pour le tableau. */
const lignes = computed(() => {
  const motif = recherche.value.trim().toLowerCase()
  return salaries.value
    .filter((s) => !motif ||
      `${s.full_name} ${s.matricule} ${s.position_title ?? ''}`.toLowerCase().includes(motif))
    .map((s) => {
      const affectation = affectationParSalarie.value[s.id]
      const profil = affectation ? profilParId.value[affectation.profil_id] : null
      const minutesContrat = (s.work_time_ratio ?? 1) * TEMPS_PLEIN_MINUTES
      const minutes = minutesProfil(profil)
      return {
        ...s,
        affectation,
        profil,
        minutesProfil: minutes,
        minutesContrat,
        aVenir: affectation && dateReference.value && affectation.date_debut > dateReference.value,
        ecart: profil && Math.abs(minutes - minutesContrat) >= 30,
      }
    })
})

const nbAffectes = computed(() => lignes.value.filter((l) => l.profil).length)

// ── Affectation ──────────────────────────────────────────────────────────────

const formulaire = ref(null)
const enregistrement = ref(false)

function affecter(salariesChoisis) {
  if (!salariesChoisis.length) return
  formulaire.value = {
    salaries: salariesChoisis,
    profil_id: salariesChoisis.length === 1 ? salariesChoisis[0].affectation?.profil_id ?? null : null,
    date_debut: dateReference.value ? new Date(`${dateReference.value}T00:00:00`) : new Date(),
  }
}

const formulaireValide = computed(() => formulaire.value?.profil_id && formulaire.value?.date_debut)

async function enregistrer() {
  if (!formulaireValide.value) return
  enregistrement.value = true
  const f = formulaire.value
  const profil = profilParId.value[f.profil_id]
  try {
    for (const s of f.salaries) {
      await insert('affectations_profil', {
        employee_id: s.id,
        profil_id: f.profil_id,
        date_debut: versDateIso(f.date_debut),
      })
    }
    toast.succes(f.salaries.length === 1
      ? `Profil ${profil.code} affecté à ${f.salaries[0].full_name}`
      : `Profil ${profil.code} affecté à ${f.salaries.length} salariés`)
    formulaire.value = null
    await chargerSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <PageHeader titre="Affectation des profils horaires"
              :sousTitre="`${salaries.length} salarié(s) présent(s) · ${nbAffectes} avec un profil horaire`" />

  <Message v-if="!chargement && !profils.length" severity="warn" class="avertissement">
    Aucun profil horaire n'existe encore : créez-en un dans l'écran « Profils horaires ».
  </Message>

  <div class="filtres">
    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id" placeholder="Choisir un hôtel" />
    <IconField>
      <InputIcon class="pi pi-search" />
      <InputText v-model="recherche" placeholder="Nom, matricule, poste…" />
    </IconField>
    <span class="espace" />
    <Button :label="`Affecter un profil${selection.length ? ` (${selection.length})` : ''}`"
            icon="pi pi-calendar-plus"
            :disabled="!selection.length || !profils.length"
            @click="affecter(selection)" />
  </div>

  <DataTable :value="lignes" :loading="chargement" dataKey="id"
             v-model:selection="selection"
             paginator :rows="25" removableSort stripedRows size="small" rowHover>
    <template #empty>Aucun salarié ne correspond.</template>

    <Column selectionMode="multiple" style="width: 3rem" />
    <Column field="matricule" header="Matricule" sortable style="width: 7rem" />
    <Column field="full_name" header="Salarié" sortable />
    <Column field="position_title" header="Poste" sortable />
    <Column field="department_label" header="Département" sortable />
    <Column field="work_time_ratio" header="Temps contrat" sortable style="width: 9rem">
      <template #body="{ data }">
        {{ formatNombre((data.work_time_ratio ?? 1) * 100) }} %
        <div class="detail">{{ formatDuree(data.minutesContrat) }} / sem.</div>
      </template>
    </Column>
    <Column header="Profil horaire" style="width: 14rem">
      <template #body="{ data }">
        <template v-if="data.profil">
          <Tag :value="data.profil.code" :severity="data.aVenir ? 'info' : 'success'" />
          <span class="heures">{{ formatDuree(data.minutesProfil) }}</span>
          <i v-if="data.ecart" class="pi pi-exclamation-triangle ecart"
             v-tooltip.top="`Le profil ne correspond pas au temps de travail du contrat (${formatDuree(data.minutesContrat)})`" />
          <div class="detail">
            {{ data.aVenir ? 'à partir du' : 'depuis le' }} {{ formatDate(data.affectation.date_debut) }}
          </div>
        </template>
        <span v-else class="detail">Aucun profil</span>
      </template>
    </Column>
    <Column style="width: 3rem">
      <template #body="{ data }">
        <Button icon="pi pi-calendar-plus" text rounded size="small"
                aria-label="Affecter un profil" v-tooltip.left="'Affecter un profil'"
                :disabled="!profils.length" @click="affecter([data])" />
      </template>
    </Column>
  </DataTable>

  <Dialog :visible="!!formulaire" modal :style="{ width: '30rem' }"
          header="Affecter un profil horaire" @update:visible="formulaire = null">
    <form v-if="formulaire" class="formulaire" @submit.prevent="enregistrer">
      <p class="chapo">
        <template v-if="formulaire.salaries.length === 1">
          {{ formulaire.salaries[0].full_name }} · {{ formulaire.salaries[0].position_title }}
        </template>
        <template v-else>{{ formulaire.salaries.length }} salariés sélectionnés</template>
      </p>

      <label for="profil">Profil horaire</label>
      <Select inputId="profil" v-model="formulaire.profil_id" :options="profils"
              :optionLabel="(p) => `${p.code} — ${p.libelle} (${formatDuree(minutesProfil(p))})`"
              optionValue="id" placeholder="Choisir un profil" />

      <label for="debut">Date de début</label>
      <DatePicker inputId="debut" v-model="formulaire.date_debut" dateFormat="dd/mm/yy" showIcon />

      <div class="boutons">
        <Button label="Annuler" severity="secondary" text @click="formulaire = null" />
        <Button type="submit" label="Affecter" icon="pi pi-check"
                :disabled="!formulaireValide" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.avertissement { margin-bottom: 1rem; }
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.espace { flex: 1; }
.detail { color: var(--p-text-muted-color); font-size: .8rem; }
.heures { margin-left: .5rem; font-size: .9rem; }
.ecart { margin-left: .4rem; color: var(--p-orange-500); }
.chapo { color: var(--p-text-muted-color); margin-top: 0; }
.formulaire { display: grid; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .5rem; }
.boutons { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
