<script setup>
// Le composant le plus réutilisé du socle : une autocomplétion sur les
// salariés présents, qui renvoie un personne_id.
//
// N'écrivez JAMAIS un nom de personne dans vos tables — stockez le personne_id.
import { ref, watch, onMounted } from 'vue'
import { getEmployes } from '../corehr'

const props = defineProps({
  modelValue: { type: [Number, String, null], default: null },
  label: { type: String, default: '' },
  placeholder: { type: String, default: 'Rechercher un salarié…' },
  serviceId: { type: [Number, String, null], default: null },
  disabled: { type: Boolean, default: false },
})
const emit = defineEmits(['update:modelValue', 'change'])

const selection = ref(null)
const options = ref([])
const chargement = ref(false)

async function rechercher(evenement) {
  chargement.value = true
  try {
    options.value = await getEmployes({
      recherche: evenement?.query ?? '',
      serviceId: props.serviceId || undefined,
    })
  } catch (e) {
    console.error('[SIRH] EmployeSelect :', e)
    options.value = []
  } finally {
    chargement.value = false
  }
}

async function chargerSelection(id) {
  if (!id) { selection.value = null; return }
  if (selection.value?.personne_id === id) return
  const [trouve] = await getEmployes({ recherche: '' }).then(t => t.filter(e => e.personne_id === id))
  selection.value = trouve ?? null
}

function choisir(evenement) {
  const valeur = evenement.value?.personne_id ?? null
  emit('update:modelValue', valeur)
  emit('change', evenement.value ?? null)
}

function vider() {
  selection.value = null
  emit('update:modelValue', null)
  emit('change', null)
}

onMounted(() => chargerSelection(props.modelValue))
watch(() => props.modelValue, (v) => { if (!v) selection.value = null; else chargerSelection(v) })
</script>

<template>
  <div class="employe-select">
    <label v-if="label">{{ label }}</label>
    <div class="ligne">
      <AutoComplete
        v-model="selection"
        :suggestions="options"
        optionLabel="nom_complet"
        :placeholder="placeholder"
        :disabled="disabled"
        :loading="chargement"
        dropdown
        forceSelection
        fluid
        @complete="rechercher"
        @item-select="choisir"
      >
        <template #option="{ option }">
          <div class="option">
            <span class="nom">{{ option.nom_complet }}</span>
            <small>{{ option.matricule }} · {{ option.service || 'sans service' }}</small>
          </div>
        </template>
      </AutoComplete>
      <Button v-if="selection && !disabled" icon="pi pi-times" severity="secondary"
              text aria-label="Effacer" @click="vider" />
    </div>
  </div>
</template>

<style scoped>
.employe-select { display: flex; flex-direction: column; gap: .4rem; }
label { font-size: .85rem; font-weight: 500; }
.ligne { display: flex; gap: .25rem; align-items: center; }
.ligne :deep(.p-autocomplete) { flex: 1; }
.option { display: flex; flex-direction: column; }
.nom { font-weight: 500; }
.option small { color: var(--p-text-muted-color); }
</style>
