<!-- libelle: Budget formation -->
<script setup>
/**
 * Story #48 — Le Responsable RH d'établissement suit le budget formation de
 * son établissement, pour maîtriser les dépenses engagées et consommées.
 *
 *   Budget alloué  : le montant saisi pour l'établissement et l'année.
 *   Engagé         : le coût des sessions planifiées, pas encore terminées.
 *   Consommé       : le coût des sessions terminées.
 *   Disponible     : alloué − engagé − consommé.
 *
 * Le coût d'une session est rattaché à l'établissement où elle se tient et à
 * l'année de sa date de début. Les sessions annulées ne coûtent rien.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, insert, update, getEtablissements, formatDate, formatNombre, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSessions, STATUTS_SESSION, libelle, couleur, periode,
  etablissementCourantId,
} from './_donnees'

const etablissements = ref([])
const sessions = ref([])
const budget = ref(null)          // la ligne de la table budgets, ou null
const montantSaisi = ref(null)
const chargement = ref(true)
const enregistrement = ref(false)

const annee = ref(new Date().getFullYear())

const euros = (valeur) => `${formatNombre(valeur)} €`
const anneeDe = (session) => Number(String(session.date_debut).slice(0, 4))

async function chargerBudget() {
  budget.value = null
  montantSaisi.value = null
  if (!etablissementCourantId.value) return
  const lignes = await sql(
    'select * from budgets where establishment_id = :etablissement and annee = :annee',
    { etablissement: etablissementCourantId.value, annee: annee.value },
  )
  budget.value = lignes[0] ?? null
  montantSaisi.value = budget.value?.montant ?? null
}

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    sessions.value = await chargerSessions()
    await chargerBudget()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    etablissements.value = await getEtablissements()
    // Le budget se suit établissement par établissement : on en choisit un d'office.
    if (!etablissementCourantId.value && etablissements.value.length) {
      etablissementCourantId.value = etablissements.value[0].id
    }
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch([etablissementCourantId, annee], async () => {
  try {
    await preparerSchema()
    await chargerBudget()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

/** Les années proposées : celles des sessions, plus l'année en cours. */
const annees = computed(() => {
  const vues = new Set([new Date().getFullYear(), annee.value])
  for (const s of sessions.value) vues.add(anneeDe(s))
  return [...vues].sort()
})

/** Les sessions de l'établissement sur l'année, hors sessions annulées. */
const lignes = computed(() =>
  sessions.value
    .filter((s) =>
      s.establishment_id === etablissementCourantId.value &&
      anneeDe(s) === annee.value &&
      s.statut !== 'annulee')
    .map((s) => ({
      ...s,
      cout: Number(s.cout ?? 0),
      nature: s.statut === 'terminee' ? 'Consommé' : 'Engagé',
    })))

const totaux = computed(() => {
  const alloue = Number(budget.value?.montant ?? 0)
  const consomme = lignes.value
    .filter((s) => s.statut === 'terminee').reduce((t, s) => t + s.cout, 0)
  const engage = lignes.value
    .filter((s) => s.statut !== 'terminee').reduce((t, s) => t + s.cout, 0)
  const disponible = alloue - consomme - engage
  const part = (montant) => (alloue ? Math.min(100, Math.round((montant / alloue) * 100)) : 0)
  return {
    alloue, consomme, engage, disponible,
    partConsomme: part(consomme),
    partEngage: Math.min(100 - part(consomme), part(engage)),
    taux: alloue ? Math.round(((consomme + engage) / alloue) * 100) : null,
  }
})

async function enregistrerBudget() {
  if (montantSaisi.value === null || montantSaisi.value < 0) {
    toast.alerte('Saisissez le montant du budget.')
    return
  }
  enregistrement.value = true
  try {
    if (budget.value) {
      await update('budgets', budget.value.id, { montant: montantSaisi.value })
    } else {
      await insert('budgets', {
        establishment_id: etablissementCourantId.value,
        annee: annee.value,
        montant: montantSaisi.value,
      })
    }
    toast.succes('Budget enregistré')
    await chargerBudget()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

async function changerCout(session, valeur) {
  const cout = Math.max(0, Math.round(Number(valeur ?? 0)))
  if (cout === session.cout) return
  try {
    await update('sessions', session.id, { cout })
    const ligne = sessions.value.find((s) => s.id === session.id)
    if (ligne) ligne.cout = cout
    toast.succes('Coût de la session mis à jour')
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Budget formation"
    sousTitre="Le budget de mon établissement : ce qui est alloué, engagé, consommé et disponible"
  />

  <div class="filtres">
    <Select v-model="etablissementCourantId" :options="etablissements"
            optionLabel="name" optionValue="id" placeholder="Choisir un établissement" />
    <Select v-model="annee" :options="annees" />
  </div>

  <Message v-if="!etablissementCourantId" severity="info" :closable="false">
    Choisissez un établissement pour voir son budget formation.
  </Message>

  <template v-else>
    <div class="stats">
      <StatCard titre="Budget alloué" :valeur="budget ? euros(totaux.alloue) : 'Non saisi'"
                icone="pi pi-wallet" :precision="`année ${annee}`" />
      <StatCard titre="Engagé" :valeur="euros(totaux.engage)" icone="pi pi-calendar"
                precision="sessions planifiées" />
      <StatCard titre="Consommé" :valeur="euros(totaux.consomme)" icone="pi pi-check-circle"
                precision="sessions terminées" />
      <StatCard titre="Disponible" :valeur="budget ? euros(totaux.disponible) : '—'"
                icone="pi pi-euro"
                :precision="totaux.taux === null ? '' : `${totaux.taux} % du budget utilisé`" />
    </div>

    <Message v-if="budget && totaux.disponible < 0" severity="error" :closable="false" class="bloc">
      Le budget est dépassé de {{ euros(-totaux.disponible) }}.
    </Message>

    <Card class="bloc">
      <template #title>Budget alloué pour {{ annee }}</template>
      <template #content>
        <div v-if="budget" class="jauge">
          <span class="piste">
            <span class="consomme" :style="{ width: `${totaux.partConsomme}%` }" />
            <span class="engage" :style="{ width: `${totaux.partEngage}%` }" />
          </span>
          <span class="legende">
            <i class="pastille consomme" /> Consommé
            <i class="pastille engage" /> Engagé
            <i class="pastille reste" /> Disponible
          </span>
        </div>
        <div class="saisie">
          <label for="b-montant">Montant du budget (€)</label>
          <InputNumber inputId="b-montant" v-model="montantSaisi" :min="0" :step="500"
                       placeholder="Pas encore de budget pour cette année" />
          <Button :label="budget ? 'Modifier le budget' : 'Enregistrer le budget'"
                  icon="pi pi-check" :loading="enregistrement" @click="enregistrerBudget" />
        </div>
      </template>
    </Card>

    <h3>Les dépenses de formation de l’année</h3>
    <DataTable :value="lignes" :loading="chargement" dataKey="id"
               stripedRows size="small" removableSort>
      <template #empty>
        Aucune session de formation dans cet établissement pour {{ annee }}.
      </template>

      <Column field="formation" header="Formation" sortable />

      <Column field="date_debut" header="Dates" sortable>
        <template #body="{ data }">{{ periode(data, formatDate) }}</template>
      </Column>

      <Column field="inscrits" header="Inscrits" sortable style="width: 7rem">
        <template #body="{ data }">{{ data.inscrits }} / {{ data.places }}</template>
      </Column>

      <Column field="statut" header="Statut de la session" sortable style="width: 14rem">
        <template #body="{ data }">
          <Tag :value="libelle(STATUTS_SESSION, data.statut)"
               :severity="couleur(STATUTS_SESSION, data.statut)" />
        </template>
      </Column>

      <Column field="nature" header="Dépense" sortable style="width: 8rem">
        <template #body="{ data }">
          <Tag :value="data.nature" :severity="data.nature === 'Consommé' ? 'success' : 'info'" />
        </template>
      </Column>

      <Column field="cout" header="Coût de la session (€)" sortable style="width: 13rem">
        <template #body="{ data }">
          <InputNumber :modelValue="data.cout" :min="0" :step="100" size="small" fluid
                       @update:modelValue="(valeur) => changerCout(data, valeur)" />
        </template>
      </Column>
    </DataTable>

    <p class="note">
      Le coût se modifie directement dans le tableau. Une session passe de « Engagé » à
      « Consommé » quand elle est terminée.
    </p>
  </template>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 10rem; }
.filtres > .p-select:first-child { min-width: 18rem; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.bloc { margin-bottom: 1.25rem; }
.jauge { margin-bottom: 1.25rem; }
.piste {
  display: flex; height: 1.1rem; border-radius: 8px; overflow: hidden;
  background: var(--p-surface-200);
}
.piste .consomme, .pastille.consomme { background: var(--p-green-500); }
.piste .engage, .pastille.engage { background: var(--p-blue-400); }
.pastille.reste { background: var(--p-surface-200); }
.legende { display: flex; gap: .5rem; align-items: center; font-size: .8rem; margin-top: .5rem;
           color: var(--p-text-muted-color); }
.pastille { display: inline-block; width: .7rem; height: .7rem; border-radius: 3px; margin-left: .75rem; }
.saisie { display: flex; gap: .75rem; align-items: center; flex-wrap: wrap; }
.saisie label { font-size: .85rem; font-weight: 600; }
h3 { font-size: 1rem; margin: 1.5rem 0 .6rem; }
.note { color: var(--p-text-muted-color); font-size: .85rem; margin-top: 1rem; }
</style>
