<script setup>
/**
 * Les candidatures d'une DP, en colonnes du workflow (stories #7, #127, #147).
 *
 * Une colonne par étape, plus « Refusé ». Les boutons de chaque carte sont
 * ceux de la page candidat (_WorkflowActions) : mêmes règles partout.
 * Émet « change » après chaque mouvement, pour que la page parente se mette
 * à jour (compteurs, statut de l'offre après une embauche).
 */
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { sql, update, formatDate, toast } from '@/socle/sdk'
import { ETAPES, REFUS } from './_workflow.js'
import WorkflowActions from './_WorkflowActions.vue'

const props = defineProps({
  offreId: { type: Number, required: true },
  close: { type: Boolean, default: false }, // offre pourvue : plus d'action
})
const emit = defineEmits(['change'])
const router = useRouter()

const COLONNES = [...ETAPES, REFUS]
const candidatures = ref([])
const chargement = ref(true)

async function charger() {
  chargement.value = true
  try {
    candidatures.value = await sql(
      `select ca.*, c.prenom, c.nom, c.source,
              o.id as offre_id, o.intitule, o.besoin_id, o.establishment_id, o.position_id,
              (select e.avis from entretiens e
                where e.candidature_id = ca.id and e.avis is not null
                order by e.date_heure desc limit 1) as dernier_avis,
              (select min(e.date_heure) from entretiens e
                where e.candidature_id = ca.id and e.statut = 'planifie') as prochain_entretien
         from candidatures ca
         join candidats c on c.id = ca.candidat_id
         join offres o on o.id = ca.offre_id
        where ca.offre_id = :offre
        order by ca.maj_le desc, ca.id`,
      { offre: props.offreId },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
    candidatures.value = []
  } finally {
    chargement.value = false
  }
}

watch(() => props.offreId, charger, { immediate: true })
defineExpose({ charger })

async function apresMouvement() {
  await charger()
  emit('change')
}

const parEtape = computed(() =>
  Object.fromEntries(COLONNES.map((e) => [e.code, candidatures.value.filter((c) => c.etape === e.code)])))

/* Note et commentaire de la carte */
const fiche = ref(null)

async function enregistrerFiche() {
  try {
    await update('candidatures', fiche.value.id, {
      note: fiche.value.note || null,
      commentaire: fiche.value.commentaire?.trim() || null,
    })
    toast.succes('Évaluation enregistrée')
    fiche.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

const AVIS = {
  favorable: { label: 'Avis favorable', severite: 'success' },
  reserve: { label: 'Avis réservé', severite: 'warn' },
  defavorable: { label: 'Avis défavorable', severite: 'danger' },
}
const heure = (v) => `${formatDate(v)} à ${new Date(v).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`
</script>

<template>
  <div class="kanban">
    <section v-for="etape in COLONNES" :key="etape.code" class="colonne" :class="etape.code">
      <header>
        <i :class="etape.icone" /> <span>{{ etape.label }}</span>
        <span class="compte">{{ parEtape[etape.code].length }}</span>
      </header>

      <p v-if="!parEtape[etape.code].length" class="vide">{{ chargement ? '…' : '—' }}</p>

      <article v-for="c in parEtape[etape.code]" :key="c.id" class="carte">
        <div class="nom" @click="router.push(`/rec/candidat/${c.candidat_id}`)">{{ c.prenom }} {{ c.nom }}</div>
        <div class="meta">{{ c.source }} · reçue le {{ formatDate(c.recue_le) }}</div>
        <div v-if="c.prochain_entretien" class="rdv"><i class="pi pi-calendar" /> {{ heure(c.prochain_entretien) }}</div>
        <Tag v-if="c.dernier_avis" :value="AVIS[c.dernier_avis].label" :severity="AVIS[c.dernier_avis].severite" class="petit" />
        <div v-if="c.etape === 'refus'" class="motif">{{ c.motif_refus }}</div>
        <Rating v-if="c.note" :modelValue="c.note" readonly :stars="5" class="note" />
        <p v-if="c.commentaire" class="commentaire">{{ c.commentaire }}</p>

        <div v-if="!close && c.etape !== 'embauche'" class="actions">
          <WorkflowActions :candidature="c" compact @change="apresMouvement" />
          <Button icon="pi pi-pencil" size="small" text severity="secondary"
                  v-tooltip.top="'Noter et commenter'" @click="fiche = { ...c }" />
        </div>
      </article>
    </section>
  </div>

  <Dialog :visible="!!fiche" modal :style="{ width: '30rem' }"
          :header="fiche ? `${fiche.prenom} ${fiche.nom}` : ''" @update:visible="fiche = null">
    <form v-if="fiche" class="formulaire" @submit.prevent="enregistrerFiche">
      <label>Note</label>
      <Rating v-model="fiche.note" :stars="5" />
      <label for="fiche-commentaire">Commentaire</label>
      <Textarea id="fiche-commentaire" v-model="fiche.commentaire" rows="4" autoResize />
      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="fiche = null" />
        <Button label="Enregistrer" icon="pi pi-check" type="submit" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.kanban { display: grid; grid-template-columns: repeat(7, minmax(8.6rem, 1fr)); gap: .45rem; overflow-x: auto; }
.colonne { background: var(--p-surface-100); border-radius: 10px; padding: .45rem; min-height: 11rem; }
.colonne header { display: flex; align-items: flex-start; gap: .35rem; font-weight: 600; font-size: .8rem; margin-bottom: .6rem; line-height: 1.25; }
.colonne header i { margin-top: .1rem; }
.colonne.embauche header { color: var(--p-green-600); }
.colonne.refus header { color: var(--p-red-500); }
.compte { margin-left: auto; background: var(--p-surface-0); border-radius: 999px; padding: 0 .5rem; font-size: .75rem; }
.vide { color: var(--p-text-muted-color); text-align: center; font-size: .85rem; }
.carte { background: var(--p-surface-0); border: 1px solid var(--p-surface-200); border-radius: 8px; padding: .5rem; margin-bottom: .5rem; }
.nom { font-weight: 600; cursor: pointer; color: var(--p-primary-color); }
.nom:hover { text-decoration: underline; }
.meta { font-size: .75rem; color: var(--p-text-muted-color); margin-top: .15rem; }
.rdv { font-size: .75rem; margin-top: .3rem; color: var(--p-primary-color); }
.motif { font-size: .75rem; margin-top: .3rem; color: var(--p-red-500); }
.petit { margin-top: .35rem; font-size: .7rem; }
.note { margin-top: .35rem; }
.note :deep(.p-rating-icon) { width: .8rem; height: .8rem; }
.commentaire { font-size: .8rem; margin: .35rem 0 0; }
.actions { display: flex; flex-wrap: wrap; align-items: center; gap: .1rem; margin-top: .45rem; }
.actions > :first-child { display: contents; }
.actions :deep(.boutons) { display: contents; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
