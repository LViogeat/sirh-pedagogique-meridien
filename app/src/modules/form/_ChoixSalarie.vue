<script setup>
/**
 * « Je suis… » : le choix du salarié sur les écrans du collaborateur.
 *
 * L'application n'a pas de connexion. Pour qu'un collaborateur voie SES
 * formations, on lui fait choisir son nom ici. Le choix est partagé entre
 * les écrans du module (voir salarieCourantId dans _donnees.js).
 *
 * Le composant prévient l'écran avec l'évènement « change », qui donne la
 * ligne complète du salarié (poste, famille de métier, établissement…).
 */
import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, toast } from '@/socle/sdk'
import { salarieCourantId } from './_donnees'

const emit = defineEmits(['change'])

const salaries = ref([])
const chargement = ref(true)

onMounted(async () => {
  try {
    const liste = await getSalaries()
    salaries.value = liste.map((s) => ({
      ...s,
      affichage: `${s.full_name} — ${s.position_title ?? 'sans poste'} (${s.establishment_city ?? '—'})`,
    }))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const salarie = computed(
  () => salaries.value.find((s) => s.id === salarieCourantId.value) ?? null,
)

watch(salarie, (s) => emit('change', s))
</script>

<template>
  <div class="choix">
    <label for="choix-salarie"><i class="pi pi-user" /> Je suis</label>
    <Select v-model="salarieCourantId" inputId="choix-salarie"
            :options="salaries" optionLabel="affichage" optionValue="id"
            :loading="chargement" filter showClear
            placeholder="Choisir mon nom dans la liste"
            emptyFilterMessage="Aucun salarié à ce nom" />
    <span v-if="salarie" class="poste">
      {{ salarie.position_title }} · {{ salarie.department_label }} ·
      {{ salarie.establishment_name }}
    </span>
  </div>
</template>

<style scoped>
.choix {
  display: flex; align-items: center; gap: .75rem; flex-wrap: wrap;
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: .75rem 1rem; margin-bottom: 1.25rem;
}
.choix label { font-weight: 600; font-size: .9rem; }
.choix .p-select { min-width: 22rem; }
.poste { color: var(--p-text-muted-color); font-size: .85rem; }
</style>
