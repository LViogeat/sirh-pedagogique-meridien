<!-- libelle: Motifs d'absence -->
<script setup>
/**
 * Les motifs d'absence, regroupés par famille (#128),
 * et leur création ou modification (#129).
 */
import { ref, computed, onMounted } from 'vue'
import { sql, insert, update, toast } from '@/socle/sdk'
import { preparerSchema } from './_gta.js'

const familles = ref([])
const motifs = ref([])
const chargement = ref(true)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    familles.value = await sql('select * from familles_absence order by ordre, libelle')
    motifs.value = await sql(`
      select m.*, f.libelle as famille_libelle, f.ordre as famille_ordre
      from motifs_absence m
      join familles_absence f on f.id = m.famille_id
      order by f.ordre, m.libelle`)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)

/** Chaque famille avec ses motifs, dans l'ordre des familles. */
const parFamille = computed(() =>
  familles.value.map((f) => ({
    ...f,
    motifs: motifs.value.filter((m) => m.famille_id === f.id),
  })))

// ── Création / modification ──────────────────────────────────────────────────

const formulaire = ref(null)   // null = boîte fermée
const enregistrement = ref(false)

function nouveau(familleId = null) {
  formulaire.value = { id: null, code: '', libelle: '', famille_id: familleId }
}

function modifier(motif) {
  formulaire.value = {
    id: motif.id, code: motif.code, libelle: motif.libelle, famille_id: motif.famille_id,
  }
}

const formulaireValide = computed(() =>
  formulaire.value?.code.trim() && formulaire.value?.libelle.trim() && formulaire.value?.famille_id)

async function enregistrer() {
  if (!formulaireValide.value) return
  enregistrement.value = true
  const { id, ...valeurs } = formulaire.value
  const donnees = {
    code: valeurs.code.trim().toUpperCase(),
    libelle: valeurs.libelle.trim(),
    famille_id: valeurs.famille_id,
  }
  try {
    if (id) {
      await update('motifs_absence', id, donnees)
      toast.succes(`Motif ${donnees.code} modifié`)
    } else {
      await insert('motifs_absence', donnees)
      toast.succes(`Motif ${donnees.code} créé`)
    }
    formulaire.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(/unique|duplicate/i.test(erreur.message)
      ? `Le code ${donnees.code} est déjà utilisé par un autre motif.`
      : erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <PageHeader
    titre="Motifs d'absence"
    :sousTitre="`${familles.length} famille(s) · ${motifs.length} motif(s) que les salariés pourront demander`"
  />

  <div class="actions">
    <Button label="Nouveau motif" icon="pi pi-plus" @click="nouveau()" />
  </div>

  <div v-if="chargement" class="vide"><ProgressSpinner style="width: 2rem; height: 2rem" /></div>
  <p v-else-if="!familles.length" class="vide">Aucune famille d'absence n'est définie.</p>

  <div v-else class="familles">
    <Card v-for="f in parFamille" :key="f.id" class="famille">
      <template #title>
        <div class="titre-famille">
          <span>{{ f.libelle }}</span>
          <Tag :value="`${f.motifs.length} motif(s)`" severity="secondary" />
        </div>
      </template>
      <template #content>
        <DataTable :value="f.motifs" dataKey="id" size="small" rowHover
                   @row-click="(e) => modifier(e.data)">
          <template #empty>Aucun motif dans cette famille.</template>
          <Column field="code" header="Code" style="width: 6rem">
            <template #body="{ data }"><code>{{ data.code }}</code></template>
          </Column>
          <Column field="libelle" header="Libellé" />
          <Column style="width: 3rem">
            <template #body="{ data }">
              <Button icon="pi pi-pencil" text rounded size="small"
                      aria-label="Modifier" @click.stop="modifier(data)" />
            </template>
          </Column>
        </DataTable>
        <Button label="Ajouter un motif" icon="pi pi-plus" text size="small"
                class="ajout" @click="nouveau(f.id)" />
      </template>
    </Card>
  </div>

  <Dialog :visible="!!formulaire" modal :style="{ width: '30rem' }"
          :header="formulaire?.id ? 'Modifier le motif' : 'Nouveau motif d\'absence'"
          @update:visible="formulaire = null">
    <form v-if="formulaire" class="formulaire" @submit.prevent="enregistrer">
      <label for="code">Code</label>
      <InputText id="code" v-model="formulaire.code" placeholder="ex. CP" maxlength="10" />

      <label for="libelle">Libellé</label>
      <InputText id="libelle" v-model="formulaire.libelle" placeholder="ex. Congés payés" />

      <label for="famille">Famille</label>
      <Select inputId="famille" v-model="formulaire.famille_id" :options="familles"
              optionLabel="libelle" optionValue="id" placeholder="Choisir une famille" />

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
.familles { display: grid; grid-template-columns: repeat(auto-fill, minmax(22rem, 1fr)); gap: 1rem; }
.titre-famille { display: flex; justify-content: space-between; align-items: center; gap: .5rem; font-size: 1.05rem; }
.ajout { margin-top: .5rem; }
.vide { color: var(--p-text-muted-color); text-align: center; padding: 2rem; }
.formulaire { display: grid; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .5rem; }
.boutons { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
