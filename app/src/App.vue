<script setup>
import { useToast } from 'primevue/usetoast'
import { useRoute } from 'vue-router'
import { _enregistrerToast } from '@/socle/format'
import { useSession } from '@/socle/session'
import AppLayout from '@/socle/composants/AppLayout.vue'

// Le service de notification n'existe que dans un setup() : on le capture ici
// pour que toast.succes() soit appelable depuis n'importe quel fichier.
_enregistrerToast(useToast())

const session = useSession()
const route = useRoute()
</script>

<template>
  <Toast />
  <ConfirmDialog />

  <div v-if="session.chargement" class="attente">
    <ProgressSpinner />
  </div>

  <RouterView v-else-if="route.meta.public" />

  <AppLayout v-else />
</template>

<style scoped>
.attente { min-height: 100vh; display: grid; place-items: center; }
</style>
