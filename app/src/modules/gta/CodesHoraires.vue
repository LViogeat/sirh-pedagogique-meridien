<!-- libelle: Codes horaires -->
<script setup>
/**
 * Les codes horaires : les plages de travail d'une journée (#130).
 * Exemple : MATIN, de 7 h à 15 h avec 30 min de pause, soit 7 h 30 travaillées.
 */
import { ref, computed, onMounted } from 'vue'
import { sql, insert, update, toast } from '@/socle/sdk'
import { preparerSchema, heure, dureeMinutes, formatDuree } from './_gta.js'

const codes = ref([])
const chargement = ref(true)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    codes.value = await sql('select * from codes_horaires order by heure_debut, code')
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)

// ── Création / modification ──────────────────────────────────────────────────

const formulaire = ref(null)
const enregistrement = ref(false)

function nouveau() {
  formulaire.value = { id: null, code: '', libelle: '', heure_debut: '', heure_fin: '', pause_minutes: 0 }
}

function modifier(c) {
  formulaire.value = {
    id: c.id, code: c.code, libelle: c.libelle,
    heure_debut: heure(c.heure_debut), heure_fin: heure(c.heure_fin),
    pause_minutes: c.pause_minutes,
  }
}

const dureeSaisie = computed(() => dureeMinutes(formulaire.value))
const passeMinuit = computed(() =>
  formulaire.value?.heure_debut && formulaire.value?.heure_fin &&
  formulaire.value.heure_fin <= formulaire.value.heure_debut)

const formulaireValide = computed(() => {
  const f = formulaire.value
  return f && f.code.trim() && f.libelle.trim() && f.heure_debut && f.heure_fin &&
    f.pause_minutes >= 0 && dureeSaisie.value > 0
})

async function enregistrer() {
  if (!formulaireValide.value) return
  enregistrement.value = true
  const f = formulaire.value
  const donnees = {
    code: f.code.trim().toUpperCase(),
    libelle: f.libelle.trim(),
    heure_debut: f.heure_debut,
    heure_fin: f.heure_fin,
    pause_minutes: Number(f.pause_minutes) || 0,
  }
  try {
    if (f.id) {
      await update('codes_horaires', f.id, donnees)
      toast.succes(`Code horaire ${donnees.code} modifié`)
    } else {
      await insert('codes_horaires', donnees)
      toast.succes(`Code horaire ${donnees.code} créé`)
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
  <PageHeader titre="Codes horaires"
              :sousTitre="`${codes.length} code(s) horaire(s) : les plages de travail d'une journée`" />

  <div class="actions">
    <Button label="Nouveau code horaire" icon="pi pi-plus" @click="nouveau" />
  </div>

  <DataTable :value="codes" :loading="chargement" dataKey="id"
             stripedRows size="small" rowHover removableSort
             @row-click="(e) => modifier(e.data)">
    <template #empty>Aucun code horaire pour l'instant. Créez le premier, par exemple MATIN.</template>

    <Column field="code" header="Code" sortable style="width: 8rem">
      <template #body="{ data }"><code>{{ data.code }}</code></template>
    </Column>
    <Column field="libelle" header="Libellé" sortable />
    <Column field="heure_debut" header="Début" sortable style="width: 7rem">
      <template #body="{ data }">{{ heure(data.heure_debut) }}</template>
    </Column>
    <Column field="heure_fin" header="Fin" sortable style="width: 7rem">
      <template #body="{ data }">
        {{ heure(data.heure_fin) }}
        <Tag v-if="data.heure_fin <= data.heure_debut" value="J+1" severity="info" />
      </template>
    </Column>
    <Column field="pause_minutes" header="Pause" sortable style="width: 7rem">
      <template #body="{ data }">{{ data.pause_minutes ? `${data.pause_minutes} min` : '—' }}</template>
    </Column>
    <Column header="Temps travaillé" style="width: 10rem">
      <template #body="{ data }"><strong>{{ formatDuree(dureeMinutes(data)) }}</strong></template>
    </Column>
    <Column style="width: 3rem">
      <template #body="{ data }">
        <Button icon="pi pi-pencil" text rounded size="small"
                aria-label="Modifier" @click.stop="modifier(data)" />
      </template>
    </Column>
  </DataTable>

  <Dialog :visible="!!formulaire" modal :style="{ width: '30rem' }"
          :header="formulaire?.id ? 'Modifier le code horaire' : 'Nouveau code horaire'"
          @update:visible="formulaire = null">
    <form v-if="formulaire" class="formulaire" @submit.prevent="enregistrer">
      <label for="code">Code</label>
      <InputText id="code" v-model="formulaire.code" placeholder="ex. MATIN" maxlength="12" />

      <label for="libelle">Libellé</label>
      <InputText id="libelle" v-model="formulaire.libelle" placeholder="ex. Équipe du matin" />

      <div class="plage">
        <div>
          <label for="debut">Début</label>
          <InputText id="debut" type="time" v-model="formulaire.heure_debut" />
        </div>
        <div>
          <label for="fin">Fin</label>
          <InputText id="fin" type="time" v-model="formulaire.heure_fin" />
        </div>
        <div>
          <label for="pause">Pause (min)</label>
          <InputNumber inputId="pause" v-model="formulaire.pause_minutes" :min="0" :max="240" :step="15" />
        </div>
      </div>

      <p class="resume" v-if="formulaire.heure_debut && formulaire.heure_fin">
        Temps travaillé : <strong>{{ formatDuree(dureeSaisie) }}</strong>
        <span v-if="passeMinuit"> — la plage passe minuit</span>
      </p>

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
.formulaire { display: grid; gap: .4rem; }
.formulaire label { display: block; font-size: .85rem; font-weight: 600; margin: .5rem 0 .3rem; }
.plage { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: .75rem; }
.plage :deep(input) { width: 100%; }
.resume { margin: .75rem 0 0; color: var(--p-text-muted-color); }
.boutons { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
