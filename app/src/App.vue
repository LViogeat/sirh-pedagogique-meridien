<script setup>
import { useToast } from 'primevue/usetoast'
import { _enregistrerToast } from '@/socle/format'
import { CONFIGURATION_INCOMPLETE } from '@/socle/config'
import AppLayout from '@/socle/composants/AppLayout.vue'
import ConfigurationRequise from '@/socle/composants/ConfigurationRequise.vue'

_enregistrerToast(useToast())
</script>

<template>
  <Toast />
  <ConfirmDialog />

  <!-- Sans jeton ni code de module, rien ne peut fonctionner : on le dit
       clairement plutôt que de laisser tomber un appel réseau en erreur. -->
  <ConfigurationRequise v-if="CONFIGURATION_INCOMPLETE" />
  <AppLayout v-else />
</template>
