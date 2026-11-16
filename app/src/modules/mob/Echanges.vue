<!-- libelle: Échanges avec le salarié -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getDateReference, sql, insert, update, formatDate, toast } from '@/socle/sdk'
import { lireDossiers, libelleDossier, etapeDe, TYPES_ECHANGE, typeEchangeDe,
         enDate, enDateIso } from './_commun'

const dossiers = ref([])
const dossier = ref(null)
const echanges = ref([])
const dateReference = ref(null)
const enCours = ref(false)

// Le formulaire
const dateEchange = ref(null)
const typeEchange = ref('entretien_carriere')
const compteRendu = ref('')

onMounted(async () => {
  try {
    const [liste, dateRef] = await Promise.all([lireDossiers(), getDateReference()])
    dossiers.value = liste.map((d) => ({ ...d, libelle: libelleDossier(d) }))
    dateReference.value = dateRef
    dateEchange.value = enDate(dateRef)
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

async function chargerEchanges() {
  if (!dossier.value) { echanges.value = []; return }
  echanges.value = await sql(
    'select * from echanges where dossier_id = :id order by date_echange desc, id desc',
    { id: dossier.value.id })
}
watch(dossier, () => chargerEchanges().catch((e) => toast.erreur(e.message)))

const termine = computed(() => dossier.value?.etape === 'termine')

async function enregistrer() {
  if (!dateEchange.value || !typeEchange.value || !compteRendu.value.trim()) {
    toast.erreur('Renseignez la date, le type et le compte rendu.')
    return
  }
  enCours.value = true
  try {
    await insert('echanges', {
      dossier_id: dossier.value.id,
      date_echange: enDateIso(dateEchange.value),
      type_echange: typeEchange.value,
      compte_rendu: compteRendu.value.trim(),
    })
    // Un entretien de carrière fait passer le dossier de « propositions » à « entretien ».
    if (typeEchange.value === 'entretien_carriere' && dossier.value.etape === 'propositions') {
      await update('dossiers', dossier.value.id, { etape: 'entretien' })
      dossier.value.etape = 'entretien'
      toast.info('Le dossier passe à l\'étape « Entretien ».')
    }
    toast.succes('Échange enregistré.')
    compteRendu.value = ''
    dateEchange.value = enDate(dateReference.value)
    await chargerEchanges()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}
</script>

<template>
  <PageHeader titre="Échanges avec le salarié" sousTitre="Garder la trace de l'accompagnement" />

  <div class="entete">
    <Select v-model="dossier" :options="dossiers" optionLabel="libelle" filter showClear
            placeholder="Choisir un dossier" class="choix" />
    <Tag v-if="dossier" :value="etapeDe(dossier.etape).label" :severity="etapeDe(dossier.etape).severite" />
  </div>

  <Message v-if="!dossiers.length" severity="info" :closable="false">
    Aucun dossier : prenez d'abord en charge un besoin depuis l'écran Prise en charge.
  </Message>

  <div v-if="dossier" class="grille">
    <Card>
      <template #title>Nouvel échange</template>
      <template #content>
        <Message v-if="termine" severity="secondary" :closable="false">
          Ce dossier est terminé : il reste consultable, mais on ne peut plus y ajouter d'échange.
        </Message>
        <template v-else>
          <div class="champ">
            <label>Date</label>
            <DatePicker v-model="dateEchange" dateFormat="dd/mm/yy" showIcon />
          </div>
          <div class="champ">
            <label>Type</label>
            <SelectButton v-model="typeEchange" :options="TYPES_ECHANGE" optionLabel="label"
                          optionValue="code" :allowEmpty="false" />
          </div>
          <div class="champ">
            <label>Compte rendu</label>
            <Textarea v-model="compteRendu" rows="5" autoResize />
          </div>
          <Button label="Enregistrer l'échange" icon="pi pi-save" :loading="enCours" @click="enregistrer" />
        </template>
      </template>
    </Card>

    <Card>
      <template #title>Historique ({{ echanges.length }})</template>
      <template #content>
        <p v-if="!echanges.length" class="discret">Aucun échange pour ce dossier.</p>
        <div v-for="e in echanges" :key="e.id" class="echange">
          <div class="haut">
            <i :class="typeEchangeDe(e.type_echange).icone" />
            <strong>{{ typeEchangeDe(e.type_echange).label }}</strong>
            <span class="discret">· {{ formatDate(e.date_echange) }}</span>
          </div>
          <p>{{ e.compte_rendu }}</p>
        </div>
      </template>
    </Card>
  </div>
</template>

<style scoped>
.entete { display: flex; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
.choix { min-width: 30rem; }
.grille { display: grid; grid-template-columns: repeat(auto-fit, minmax(24rem, 1fr)); gap: 1.25rem; align-items: start; }
.champ { display: flex; flex-direction: column; gap: .35rem; margin-bottom: 1rem; }
.echange { border-left: 3px solid var(--p-primary-color); padding: .2rem 0 .2rem .8rem; margin-bottom: 1rem; }
.echange .haut { display: flex; align-items: center; gap: .5rem; }
.echange p { margin: .35rem 0 0; white-space: pre-line; }
.discret { color: var(--p-text-muted-color); }
</style>
