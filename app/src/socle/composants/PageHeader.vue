<script setup>
defineProps({
  titre: { type: String, required: true },
  sousTitre: { type: String, default: '' },
})
</script>

<template>
  <header class="entete">
    <div>
      <h1>{{ titre }}</h1>
      <p v-if="sousTitre">{{ sousTitre }}</p>
    </div>
    <div class="actions"><slot /></div>
  </header>
</template>

<style scoped>
.entete {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem;
}
h1 { margin: 0; font-size: 1.5rem; font-weight: 600; }
p  { margin: .25rem 0 0; color: var(--p-text-muted-color); font-size: .9rem; }
.actions { display: flex; gap: .5rem; flex-wrap: wrap; }
</style>
