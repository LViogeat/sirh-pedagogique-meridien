<!-- libelle: Profils horaires -->
<script setup>
/**
 * Les profils horaires : un code horaire par jour, du lundi au dimanche,
 * et le total d'heures de la semaine (#131). Un jour sans code est un repos.
 */
import { ref, computed, onMounted } from 'vue'
import { sql, insert, update, toast } from '@/socle/sdk'
import { preparerSchema, heure, dureeMinutes, formatDuree, JOURS } from './_gta.js'

const profils = ref([])
const codes = ref([])
const chargement = ref(true)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    codes.value = await sql('select * from codes_horaires order by heure_debut, code')
    profils.value = await sql('select * from profils_horaires order by code')
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)

const codeParId = computed(() => Object.fromEntries(codes.value.map((c) => [c.id, c])))

/** Total hebdomadaire d'un profil, en minutes. */
const totalMinutes = (profil) =>
  JOURS.reduce((t, j) => t + dureeMinutes(codeParId.value[profil[j.cle]]), 0)

const joursTravailles = (profil) => JOURS.filter((j) => profil[j.cle]).length

/** Les options du choix d'un jour : « Repos », puis chaque code avec sa plage. */
const options = computed(() => [
  { id: null, etiquette: 'Repos' },
  ...codes.value.map((c) => ({
    id: c.id,
    etiquette: `${c.code} · ${heure(c.heure_debut)}–${heure(c.heure_fin)} (${formatDuree(dureeMinutes(c))})`,
  })),
])

// ── Création / modification ──────────────────────────────────────────────────

const formulaire = ref(null)
const enregistrement = ref(false)

function nouveau() {
  formulaire.value = { id: null, code: '', libelle: '', ...Object.fromEntries(JOURS.map((j) => [j.cle, null])) }
}

function modifier(p) {
  formulaire.value = { ...p }
}

const totalSaisi = computed(() => (formulaire.value ? totalMinutes(formulaire.value) : 0))

const formulaireValide = computed(() =>
  formulaire.value?.code.trim() && formulaire.value?.libelle.trim())

async function enregistrer() {
  if (!formulaireValide.value) return
  enregistrement.value = true
  const f = formulaire.value
  const donnees = {
    code: f.code.trim().toUpperCase(),
    libelle: f.libelle.trim(),
    ...Object.fromEntries(JOURS.map((j) => [j.cle, f[j.cle] ?? null])),
  }
  try {
    if (f.id) {
      await update('profils_horaires', f.id, donnees)
      toast.succes(`Profil ${donnees.code} modifié`)
    } else {
      await insert('profils_horaires', donnees)
      toast.succes(`Profil ${donnees.code} créé`)
    }
    formulaire.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(/unique|duplicate/i.test(erreur.message)
      ? `Le code ${donnees.code} existe déjà.`
      : erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <PageHeader titre="Profils horaires"
              :sousTitre="`${profils.length} profil(s) : le rythme de travail d'une semaine type`" />

  <Message v-if="!chargement && !codes.length" severity="warn" class="avertissement">
    Aucun code horaire n'existe encore : créez-les d'abord dans l'écran « Codes horaires ».
  </Message>

  <div class="actions">
    <Button label="Nouveau profil" icon="pi pi-plus" :disabled="!codes.length" @click="nouveau" />
  </div>

  <DataTable :value="profils" :loading="chargement" dataKey="id"
             stripedRows size="small" rowHover
             @row-click="(e) => modifier(e.data)">
    <template #empty>Aucun profil horaire pour l'instant.</template>

    <Column field="code" header="Code" style="width: 8rem">
      <template #body="{ data }"><code>{{ data.code }}</code></template>
    </Column>
    <Column field="libelle" header="Libellé" />
    <Column v-for="j in JOURS" :key="j.cle" :header="j.court" style="width: 5.5rem">
      <template #body="{ data }">
        <Tag v-if="data[j.cle]" :value="codeParId[data[j.cle]]?.code" />
        <span v-else class="repos">repos</span>
      </template>
    </Column>
    <Column header="Total / semaine" style="width: 9rem">
      <template #body="{ data }">
        <strong>{{ formatDuree(totalMinutes(data)) }}</strong>
        <div class="detail">{{ joursTravailles(data) }} jour(s)</div>
      </template>
    </Column>
    <Column style="width: 3rem">
      <template #body="{ data }">
        <Button icon="pi pi-pencil" text rounded size="small"
                aria-label="Modifier" @click.stop="modifier(data)" />
      </template>
    </Column>
  </DataTable>

  <Dialog :visible="!!formulaire" modal :style="{ width: '36rem' }"
          :header="formulaire?.id ? 'Modifier le profil horaire' : 'Nouveau profil horaire'"
          @update:visible="formulaire = null">
    <form v-if="formulaire" class="formulaire" @submit.prevent="enregistrer">
      <div class="entete">
        <div>
          <label for="code">Code</label>
          <InputText id="code" v-model="formulaire.code" placeholder="ex. 35H-SEMAINE" maxlength="16" />
        </div>
        <div>
          <label for="libelle">Libellé</label>
          <InputText id="libelle" v-model="formulaire.libelle" placeholder="ex. 35 h du lundi au vendredi" />
        </div>
      </div>

      <div class="semaine">
        <template v-for="j in JOURS" :key="j.cle">
          <label :for="j.cle">{{ j.libelle }}</label>
          <Select :inputId="j.cle" v-model="formulaire[j.cle]" :options="options"
                  optionLabel="etiquette" optionValue="id" />
        </template>
      </div>

      <p class="resume">Total de la semaine : <strong>{{ formatDuree(totalSaisi) }}</strong></p>

      <div class="boutons">
        <Button label="Annuler" severity="secondary" text @click="formulaire = null" />
        <Button type="submit" label="Enregistrer" icon="pi pi-check"
                :disabled="!formulaireValide" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.actions { display: flex; justify-content: flex-end; margin-bottom: 1rem; }
.avertissement { margin-bottom: 1rem; }
.repos { color: var(--p-text-muted-color); font-size: .8rem; font-style: italic; }
.detail { color: var(--p-text-muted-color); font-size: .8rem; }
.formulaire label { display: block; font-size: .85rem; font-weight: 600; }
.entete { display: grid; grid-template-columns: 1fr 2fr; gap: .75rem; margin-bottom: 1rem; }
.entete label { margin-bottom: .3rem; }
.entete :deep(input) { width: 100%; }
.semaine { display: grid; grid-template-columns: 6rem 1fr; gap: .5rem .75rem; align-items: center; }
.resume { margin: 1rem 0 0; font-size: 1.05rem; }
.boutons { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
