<script setup>
import { ref, watch, onMounted } from 'vue'
import { getEmployes } from '../corehr'
import { formatDate, anciennete } from '../format'

const props = defineProps({
  id: { type: [Number, String, null], default: null },
  employe: { type: Object, default: null },
  compact: { type: Boolean, default: false },
})

const donnees = ref(props.employe)

async function charger() {
  if (props.employe) { donnees.value = props.employe; return }
  if (!props.id) { donnees.value = null; return }
  const tous = await getEmployes()
  donnees.value = tous.find(e => e.personne_id === Number(props.id)) ?? null
}

onMounted(charger)
watch(() => [props.id, props.employe], charger)

const initiales = (e) => `${e.prenom?.[0] ?? ''}${e.nom?.[0] ?? ''}`.toUpperCase()
</script>

<template>
  <div v-if="donnees" class="fiche" :class="{ compact }">
    <div class="avatar">{{ initiales(donnees) }}</div>
    <div class="infos">
      <div class="nom">{{ donnees.nom_complet }}</div>
      <div class="meta">{{ donnees.emploi || '—' }} · {{ donnees.service || 'sans service' }}</div>
      <div v-if="!compact" class="details">
        <span><i class="pi pi-id-card" /> {{ donnees.matricule }}</span>
        <span><i class="pi pi-briefcase" /> {{ donnees.type_contrat }}</span>
        <span><i class="pi pi-clock" /> {{ anciennete(donnees.anciennete_mois) }}</span>
        <span v-if="donnees.manager"><i class="pi pi-user" /> {{ donnees.manager }}</span>
        <span v-if="donnees.email_pro"><i class="pi pi-envelope" /> {{ donnees.email_pro }}</span>
        <span v-if="donnees.date_entree"><i class="pi pi-calendar" /> entré le {{ formatDate(donnees.date_entree) }}</span>
      </div>
    </div>
  </div>
  <div v-else class="fiche vide">Aucun salarié sélectionné</div>
</template>

<style scoped>
.fiche {
  display: flex; gap: 1rem; align-items: flex-start;
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1rem;
}
.fiche.vide { color: var(--p-text-muted-color); font-size: .9rem; justify-content: center; }
.avatar {
  width: 2.75rem; height: 2.75rem; flex: none; border-radius: 50%;
  display: grid; place-items: center; font-weight: 600;
  background: var(--p-primary-100); color: var(--p-primary-700);
}
.compact .avatar { width: 2rem; height: 2rem; font-size: .8rem; }
.nom { font-weight: 600; }
.meta { color: var(--p-text-muted-color); font-size: .85rem; }
.details {
  display: flex; flex-wrap: wrap; gap: .25rem 1rem;
  margin-top: .6rem; font-size: .82rem; color: var(--p-text-color);
}
.details i { color: var(--p-text-muted-color); margin-right: .25rem; }
</style>
