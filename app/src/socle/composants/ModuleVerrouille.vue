<script setup>
/** Affiché quand on tente d'ouvrir le module d'un autre groupe. */
import { useRouter } from 'vue-router'
import { monModule } from '../modules'

defineProps({
  groupe: { type: Object, required: true },
})

const router = useRouter()
</script>

<template>
  <div class="verrou">
    <i class="pi pi-lock" />
    <h2>{{ groupe.label }}</h2>
    <p>
      Ce module appartient à un autre groupe. Vous n'y avez pas accès, et la
      base de données refuserait de toute façon toute écriture dans son schéma.
    </p>
    <p v-if="monModule" class="votre">
      Votre module est <strong>{{ monModule.label }}</strong>.
    </p>
    <Button v-if="monModule && monModule.routes.length"
            :label="`Aller à ${monModule.label}`" icon="pi pi-arrow-right"
            @click="router.push(`/${monModule.code}/${monModule.routes[0].path}`)" />
    <Button v-else label="Retour au socle" icon="pi pi-arrow-left" severity="secondary"
            @click="router.push('/corehr/besoins')" />
  </div>
</template>

<style scoped>
.verrou {
  max-width: 34rem; margin: 4rem auto; text-align: center;
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 2.5rem 2rem;
}
.verrou i { font-size: 2rem; color: var(--p-text-muted-color); }
h2 { margin: .75rem 0 .5rem; font-size: 1.25rem; }
p { color: var(--p-text-muted-color); margin: 0 0 .5rem; }
.votre { margin-bottom: 1.25rem; }
</style>
