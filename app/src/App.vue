<script setup>
import { useToast } from 'primevue/usetoast'
import { _enregistrerToast } from '@/socle/format'
import AppLayout from '@/socle/composants/AppLayout.vue'

_enregistrerToast(useToast())
</script>

<template>
  <Toast />
  <ConfirmDialog />
  <AppLayout />
</template>
