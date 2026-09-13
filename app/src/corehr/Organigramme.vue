<script setup>
import { ref, computed, onMounted } from 'vue'
import { getServices, formatNombre } from '@/socle/sdk'

const unites = ref([])
const chargement = ref(true)

// L'arbre se reconstruit à partir de parent_id : trois niveaux —
// direction générale, directions, services.
const arbre = computed(() => {
  const parEnfants = new Map()
  for (const u of unites.value) {
    const cle = u.parent_id ?? 'racine'
    if (!parEnfants.has(cle)) parEnfants.set(cle, [])
    parEnfants.get(cle).push(u)
  }
  const construire = (cle) =>
    (parEnfants.get(cle) || [])
      .sort((a, b) => a.service.localeCompare(b.service, 'fr'))
      .map(u => ({
        key: String(u.service_id),
        data: u,
        children: construire(u.service_id),
      }))
  return construire('racine')
})

const effectifTotal = computed(() =>
  unites.value.reduce((t, u) => t + Number(u.effectif || 0), 0))

onMounted(async () => {
  try {
    unites.value = await getServices({ toutesUnites: true })
  } finally {
    chargement.value = false
  }
})
</script>

<template>
  <PageHeader titre="Organigramme"
              :sousTitre="`${unites.length} unités · ${formatNombre(effectifTotal)} salariés rattachés`" />

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <TreeTable v-else :value="arbre" size="small" class="arbre">
    <template #empty>Aucune unité.</template>
    <Column field="service" header="Unité" expander />
    <Column field="type_unite" header="Type" style="width: 9rem">
      <template #body="{ node }">
        <Tag :value="node.data.type_unite"
             :severity="node.data.type_unite === 'direction' ? 'info' : 'secondary'" />
      </template>
    </Column>
    <Column field="responsable" header="Responsable">
      <template #body="{ node }">
        <span v-if="node.data.responsable">{{ node.data.responsable }}</span>
        <Tag v-else value="poste non pourvu" severity="warn" />
      </template>
    </Column>
    <Column field="etablissement" header="Établissement" style="width: 14rem" />
    <Column field="effectif" header="Effectif" style="width: 7rem">
      <template #body="{ node }">{{ formatNombre(node.data.effectif) }}</template>
    </Column>
  </TreeTable>

  <Message severity="info" :closable="false" class="note">
    Une unité peut n’avoir <strong>aucun responsable désigné</strong> — c’est le cas ici,
    et c’est fréquent dans un vrai référentiel. Un affichage qui suppose le contraire casse.
  </Message>
</template>

<style scoped>
.attente { display: grid; place-items: center; min-height: 12rem; }
.arbre { background: var(--p-surface-0); border-radius: 12px; overflow: hidden; }
.note { margin-top: 1rem; }
</style>
