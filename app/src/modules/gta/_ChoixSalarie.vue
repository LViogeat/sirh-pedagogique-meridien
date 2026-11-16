<script setup>
/**
 * « Qui êtes-vous ? » — l'application n'a pas de connexion : le collaborateur
 * se choisit dans la liste. Le choix est partagé par tous les écrans du module
 * et retenu par le navigateur. Émet `salarie` avec la fiche choisie.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, toast } from '@/socle/sdk'
import { salarieCourantId } from './_gta.js'

const emit = defineEmits(['salarie'])
const salaries = ref([])
const chargement = ref(true)

onMounted(async () => {
  try {
    salaries.value = await getSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const options = computed(() => salaries.value.map((s) => ({
  ...s,
  etiquette: `${s.full_name} · ${s.matricule} · ${s.establishment_name ?? ''}`,
})))

const salarie = computed(() => salaries.value.find((s) => s.id === salarieCourantId.value) ?? null)
watch(salarie, (s) => emit('salarie', s), { immediate: true })
</script>

<template>
  <div class="choix">
    <label for="salarie-courant"><i class="pi pi-user" /> Je suis</label>
    <Select inputId="salarie-courant" v-model="salarieCourantId" :options="options"
            optionLabel="etiquette" optionValue="id" filter :loading="chargement"
            filterPlaceholder="Nom ou matricule" placeholder="Choisissez votre nom" />
  </div>
</template>

<style scoped>
.choix { display: flex; align-items: center; gap: .75rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.choix label { font-weight: 600; font-size: .9rem; }
.choix .p-select { min-width: 22rem; max-width: 100%; }
</style>
