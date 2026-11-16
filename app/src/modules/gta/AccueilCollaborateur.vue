<!-- libelle: Mon accueil -->
<script setup>
/**
 * La page d'accueil du collaborateur : sa journée en un coup d'œil (#135).
 * Horaire du jour et pointages du jour ; les encadrés Compteurs (sprint 4)
 * et Anomalies (sprint 5) sont en place et seront remplis plus tard.
 */
import { ref, watch } from 'vue'
import { formatDate, toast } from '@/socle/sdk'
import ChoixSalarie from './_ChoixSalarie.vue'
import Pointeuse from './_Pointeuse.vue'
import {
  preparerSchema, aujourdhui, jourDeSemaine, horairesDuJour, heure,
  dureeMinutes, formatDuree,
} from './_gta.js'

const salarie = ref(null)
const horaire = ref(null)        // { profil, code } · null = aucun profil
const chargement = ref(false)

async function chargerHoraire(s) {
  horaire.value = null
  if (!s) return
  chargement.value = true
  try {
    await preparerSchema()
    horaire.value = (await horairesDuJour([s.id], aujourdhui()))[s.id] ?? null
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

watch(salarie, chargerHoraire)

const jour = jourDeSemaine(aujourdhui()).libelle
</script>

<template>
  <PageHeader :titre="salarie ? `Bonjour ${salarie.first_name}` : 'Mon accueil'"
              :sousTitre="`${jour} ${formatDate(aujourdhui(), 'long')}`" />

  <ChoixSalarie @salarie="salarie = $event" />

  <Message v-if="!salarie" severity="info">Choisissez votre nom pour voir votre journée.</Message>

  <div v-else class="grille">
    <Card class="encadre">
      <template #title><i class="pi pi-calendar" /> Mon horaire du jour</template>
      <template #content>
        <div v-if="chargement" class="vide"><ProgressSpinner style="width: 1.5rem; height: 1.5rem" /></div>
        <template v-else-if="horaire?.code">
          <div class="plage">{{ heure(horaire.code.heure_debut) }} – {{ heure(horaire.code.heure_fin) }}</div>
          <div class="detail">
            <Tag :value="horaire.code.code" /> {{ horaire.code.libelle }}
          </div>
          <div class="detail">
            Pause {{ horaire.code.pause_minutes }} min ·
            {{ formatDuree(dureeMinutes(horaire.code)) }} de travail prévues
          </div>
          <div class="detail profil">Profil {{ horaire.profil.code }} — {{ horaire.profil.libelle }}</div>
        </template>
        <template v-else-if="horaire">
          <div class="plage repos">Repos</div>
          <div class="detail profil">Profil {{ horaire.profil.code }} — {{ horaire.profil.libelle }}</div>
        </template>
        <p v-else class="vide">Aucun profil horaire ne vous est encore affecté.</p>
      </template>
    </Card>

    <Card class="encadre pointages">
      <template #title><i class="pi pi-clock" /> Mes pointages du jour</template>
      <template #content>
        <Pointeuse :salarieId="salarie.id" :key="salarie.id" compact />
      </template>
    </Card>

    <Card class="encadre a-venir">
      <template #title><i class="pi pi-chart-bar" /> Compteurs</template>
      <template #content>
        <p class="vide">Vos soldes de congés et de RTT s'afficheront ici.</p>
        <Tag value="Sprint 4" severity="secondary" />
      </template>
    </Card>

    <Card class="encadre a-venir">
      <template #title><i class="pi pi-exclamation-triangle" /> Anomalies</template>
      <template #content>
        <p class="vide">Les oublis de pointage et les écarts d'horaire s'afficheront ici.</p>
        <Tag value="Sprint 5" severity="secondary" />
      </template>
    </Card>
  </div>
</template>

<style scoped>
.grille { display: grid; grid-template-columns: 1fr 1.6fr; gap: 1rem; }
.encadre :deep(.p-card-title) { display: flex; align-items: center; gap: .5rem; font-size: 1.05rem; }
.plage { font-size: 2rem; font-weight: 700; font-variant-numeric: tabular-nums; margin-bottom: .5rem; }
.plage.repos { color: var(--p-text-muted-color); }
.detail { color: var(--p-text-muted-color); font-size: .9rem; margin-top: .35rem; display: flex; gap: .5rem; align-items: center; }
.profil { font-size: .8rem; }
.a-venir { border: 1px dashed var(--p-content-border-color); box-shadow: none; }
.vide { color: var(--p-text-muted-color); margin: 0 0 .5rem; }
@media (max-width: 900px) {
  .grille { grid-template-columns: 1fr; }
}
</style>
