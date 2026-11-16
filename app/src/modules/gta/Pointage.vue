<!-- libelle: Pointer -->
<script setup>
/**
 * Pointer son arrivée, ses pauses et son départ (#133).
 * Un clic sur « Pointer » ajoute l'heure à la liste des pointages du jour.
 */
import { ref } from 'vue'
import ChoixSalarie from './_ChoixSalarie.vue'
import Pointeuse from './_Pointeuse.vue'

const salarie = ref(null)
</script>

<template>
  <PageHeader titre="Pointer"
              sousTitre="Votre arrivée, vos pauses et votre départ : un clic, l'heure est enregistrée." />

  <ChoixSalarie @salarie="salarie = $event" />

  <Pointeuse v-if="salarie" :salarieId="salarie.id" :key="salarie.id" />
  <Message v-else severity="info">Choisissez votre nom pour pointer.</Message>
</template>
