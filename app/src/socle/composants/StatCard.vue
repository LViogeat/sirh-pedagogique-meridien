<script setup>
defineProps({
  titre: { type: String, required: true },
  valeur: { type: [String, Number], default: '—' },
  icone: { type: String, default: '' },
  precision: { type: String, default: '' },
})
</script>

<template>
  <div class="stat">
    <div class="haut">
      <span class="titre">{{ titre }}</span>
      <i v-if="icone" :class="icone" />
    </div>
    <div class="valeur">{{ valeur }}</div>
    <div v-if="precision" class="precision">{{ precision }}</div>
  </div>
</template>

<style scoped>
.stat {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1.1rem 1.25rem;
}
.haut { display: flex; align-items: center; justify-content: space-between; gap: .5rem; }
.titre { font-size: .8rem; color: var(--p-text-muted-color); text-transform: uppercase; letter-spacing: .03em; }
.haut i { color: var(--p-primary-color); }
.valeur { font-size: 1.9rem; font-weight: 600; line-height: 1.2; margin-top: .35rem; }
.precision { font-size: .8rem; color: var(--p-text-muted-color); margin-top: .2rem; }
</style>
