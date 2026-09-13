<script setup>
// Intercepte les erreurs survenues PENDANT le rendu d'un écran.
// (Les erreurs de CHARGEMENT du fichier sont prises par defineAsyncComponent
//  dans le routeur : il faut bien les deux.)
import { ref, onErrorCaptured, watch } from 'vue'
import { useRoute } from 'vue-router'
import ModuleEnErreur from './ModuleEnErreur.vue'

const erreur = ref(null)
const route = useRoute()

onErrorCaptured((e) => {
  erreur.value = e
  console.error('[SIRH] Erreur dans un écran :', e)
  return false // on arrête la propagation : le reste de l'application survit
})

watch(() => route.fullPath, () => { erreur.value = null })
</script>

<template>
  <ModuleEnErreur
    v-if="erreur"
    :message="`L’écran « ${route.meta.label} » du module « ${route.meta.moduleLabel} » `
              + `n’a pas pu s’afficher. Le fichier est introuvable, ou il contient une erreur.`"
    :detail="erreur?.stack || erreur?.message || String(erreur)"
  />
  <slot v-else />
</template>
