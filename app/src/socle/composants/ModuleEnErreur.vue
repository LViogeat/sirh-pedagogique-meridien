<script setup>
// Affiché à la place d'un écran qui n'a pas pu se charger ou qui a planté.
// Le reste du SIRH continue de fonctionner : un module cassé ne peut plus
// prendre la démonstration en otage.
const props = defineProps({
  titre: { type: String, default: 'Cet écran n’a pas pu s’afficher' },
  message: { type: String, default: '' },
  detail: { type: String, default: '' },
})
</script>

<template>
  <div class="erreur-ecran">
    <i class="pi pi-exclamation-triangle" />
    <h2>{{ titre }}</h2>
    <p v-if="message">{{ message }}</p>
    <p class="conseil">
      Le reste de l’application fonctionne normalement — changez d’écran dans le menu.
    </p>
    <details v-if="detail">
      <summary>Détail technique (à coller à l’IA pour qu’elle corrige)</summary>
      <pre>{{ detail }}</pre>
    </details>
  </div>
</template>

<style scoped>
.erreur-ecran {
  max-width: 46rem; margin: 3rem auto; padding: 2rem;
  border: 1px solid var(--p-red-200); border-radius: 12px;
  background: var(--p-red-50); color: var(--p-red-900);
}
.erreur-ecran i { font-size: 2rem; color: var(--p-red-500); }
.erreur-ecran h2 { margin: .75rem 0 .5rem; font-size: 1.25rem; }
.conseil { color: var(--p-text-muted-color); font-size: .9rem; }
details { margin-top: 1rem; }
summary { cursor: pointer; font-size: .9rem; }
pre {
  white-space: pre-wrap; word-break: break-word; font-size: .8rem;
  background: #fff; padding: .75rem; border-radius: 8px; margin-top: .5rem;
}
</style>
