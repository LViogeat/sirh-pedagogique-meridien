<script setup>
/**
 * La pointeuse d'un salarié pour aujourd'hui : le bouton « Pointer » et la
 * liste des pointages du jour. Chaque clic enregistre l'heure du poste ; le
 * sens (entrée ou sortie) alterne tout seul. Utilisée par l'écran de pointage
 * et par l'accueil collaborateur.
 */
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { insert, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, aujourdhui, heureActuelle, heure, pointagesDuJour,
  libellerPointages, prochainSens, presenceMinutes, formatDuree,
} from './_gta.js'

const props = defineProps({
  salarieId: { type: Number, required: true },
  compact: { type: Boolean, default: false },
})
const emit = defineEmits(['pointe'])

const pointages = ref([])
const chargement = ref(true)
const enregistrement = ref(false)
const teletravail = ref(false)
const maintenant = ref(heureActuelle())

let horloge = null
onMounted(() => { horloge = setInterval(() => { maintenant.value = heureActuelle() }, 1000) })
onUnmounted(() => clearInterval(horloge))

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    pointages.value = (await pointagesDuJour([props.salarieId], aujourdhui()))[props.salarieId] ?? []
    // Si la journée a commencé en télétravail, on garde ce choix.
    teletravail.value = pointages.value.at(-1)?.lieu === 'teletravail'
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

watch(() => props.salarieId, charger, { immediate: true })

const liste = computed(() => libellerPointages(pointages.value))
const sens = computed(() => prochainSens(pointages.value))
const present = computed(() => sens.value === 'sortie')
const consigne = computed(() => {
  if (!pointages.value.length) return 'Prochain pointage : votre arrivée'
  return present.value
    ? 'Prochain pointage : une pause ou votre départ'
    : 'Prochain pointage : votre retour'
})
const presence = computed(() => presenceMinutes(pointages.value, maintenant.value))

async function pointer() {
  enregistrement.value = true
  try {
    const p = await insert('pointages', {
      employee_id: props.salarieId,
      jour: aujourdhui(),
      heure: heureActuelle(),
      sens: sens.value,
      lieu: teletravail.value ? 'teletravail' : 'site',
    })
    pointages.value = [...pointages.value, p]
    const dernier = liste.value.at(-1)
    const feminin = ['Arrivée', 'Fin de pause'].includes(dernier.libelle)
    toast.succes(`${dernier.libelle} enregistré${feminin ? 'e' : ''} à ${heure(p.heure)}`)
    emit('pointe', pointages.value)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

defineExpose({ charger })
</script>

<template>
  <div class="pointeuse" :class="{ compact }">
    <div class="borne">
      <div v-if="!compact" class="date">{{ formatDate(aujourdhui(), 'long') }}</div>
      <div class="horloge">{{ maintenant }}</div>
      <Button label="Pointer" icon="pi pi-clock" :size="compact ? undefined : 'large'"
              :loading="enregistrement" :disabled="chargement" @click="pointer" />
      <div class="consigne">{{ consigne }}</div>
      <div class="bascule">
        <ToggleSwitch v-model="teletravail" inputId="teletravail" />
        <label for="teletravail">Je travaille en télétravail</label>
      </div>
    </div>

    <div class="journal">
      <div class="entete">
        <strong v-if="!compact">Mes pointages du jour</strong>
        <Tag v-if="pointages.length" :value="`Présence : ${formatDuree(presence)}`"
             :severity="present ? 'success' : 'secondary'" />
      </div>
      <div v-if="chargement" class="vide"><ProgressSpinner style="width: 1.5rem; height: 1.5rem" /></div>
      <p v-else-if="!liste.length" class="vide">Aucun pointage aujourd'hui.</p>
      <ul v-else>
        <li v-for="p in liste" :key="p.id">
          <span class="heure">{{ heure(p.heure) }}</span>
          <i :class="p.sens === 'entree' ? 'pi pi-sign-in entree' : 'pi pi-sign-out sortie'" />
          <span>{{ p.libelle }}</span>
          <Tag v-if="p.lieu === 'teletravail'" value="Télétravail" severity="info" />
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.pointeuse { display: grid; grid-template-columns: minmax(16rem, 1fr) 2fr; gap: 1.5rem; }
.pointeuse.compact { grid-template-columns: 1fr; gap: 1rem; }
.borne { display: flex; flex-direction: column; align-items: center; gap: .6rem; text-align: center;
         padding: 1.25rem; border: 1px solid var(--p-content-border-color); border-radius: .75rem;
         background: var(--p-content-background); }
.compact .borne { padding: .75rem; border: none; background: none; }
.date { color: var(--p-text-muted-color); text-transform: capitalize; }
.horloge { font-size: 2.6rem; font-weight: 700; font-variant-numeric: tabular-nums; letter-spacing: .02em; }
.compact .horloge { font-size: 1.8rem; }
.consigne { color: var(--p-text-muted-color); font-size: .85rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .85rem; }
.entete { display: flex; justify-content: space-between; gap: .5rem; min-height: 1rem; align-items: center; margin-bottom: .5rem; }
.journal ul { list-style: none; padding: 0; margin: 0; }
.journal li { display: flex; align-items: center; gap: .75rem; padding: .55rem .25rem;
              border-bottom: 1px solid var(--p-content-border-color); }
.heure { font-weight: 700; font-variant-numeric: tabular-nums; width: 3.5rem; }
.entree { color: var(--p-green-500); }
.sortie { color: var(--p-orange-500); }
.vide { color: var(--p-text-muted-color); padding: 1rem 0; }
@media (max-width: 720px) { .pointeuse { grid-template-columns: 1fr; } }
</style>
