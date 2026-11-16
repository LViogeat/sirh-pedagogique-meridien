<!-- libelle: Pipeline -->
<script setup>
/**
 * Le pipeline des candidatures d'une offre (stories #7, #106, #107, #127).
 *
 * Une colonne par étape du workflow de recrutement, plus « Refusé ». Les
 * boutons de chaque carte sont ceux de la page candidat (_WorkflowActions) :
 * mêmes règles partout — une étape à la fois, commentaire pour revenir,
 * entretien planifié pour passer à « Entretien à réaliser », motif pour
 * refuser, confirmation pour embaucher. Chaque mouvement est historisé.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { sql, update, formatDate, toast } from '@/socle/sdk'
import { ETAPES, REFUS } from './_workflow.js'
import WorkflowActions from './_WorkflowActions.vue'

const route = useRoute()
const router = useRouter()

const COLONNES = [...ETAPES, REFUS]

const offres = ref([])
const offreId = ref(Number(route.query.offre) || null)
const candidatures = ref([])
const chargement = ref(true)

const offre = computed(() => offres.value.find((o) => o.id === offreId.value) || null)
const close = computed(() => offre.value?.statut === 'pourvue')

async function chargerOffres() {
  try {
    offres.value = await sql(
      `select o.id, o.intitule, o.statut, o.besoin_id, o.establishment_id, o.position_id,
              count(c.id)::int as nb
         from offres o left join candidatures c on c.offre_id = o.id
        where o.statut in ('publiee', 'pourvue')
        group by o.id order by o.statut, o.id`,
    )
    if (!offres.value.some((o) => o.id === offreId.value)) {
      offreId.value = offres.value[0]?.id ?? null
    }
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

async function chargerCandidatures() {
  if (!offreId.value) {
    candidatures.value = []
    chargement.value = false
    return
  }
  chargement.value = true
  try {
    candidatures.value = await sql(
      `select ca.*, c.prenom, c.nom, c.source, c.email,
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
      { offre: offreId.value },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
    candidatures.value = []
  } finally {
    chargement.value = false
  }
}

async function toutRecharger() {
  await chargerOffres()
  await chargerCandidatures()
}

onMounted(toutRecharger)
watch(offreId, (id) => {
  router.replace({ query: id ? { offre: id } : {} })
  chargerCandidatures()
})

const parEtape = computed(() =>
  Object.fromEntries(COLONNES.map((e) => [e.code, candidatures.value.filter((c) => c.etape === e.code)])))

/* ── Note et commentaire de la carte ────────────────────────────────────── */

const fiche = ref(null)

function ouvrirFiche(candidature) {
  fiche.value = { ...candidature, commentaire: candidature.commentaire || '' }
}

async function enregistrerFiche() {
  try {
    await update('candidatures', fiche.value.id, {
      note: fiche.value.note || null,
      commentaire: fiche.value.commentaire.trim() || null,
    })
    toast.succes('Évaluation enregistrée')
    fiche.value = null
    await chargerCandidatures()
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
  <PageHeader
    titre="Pipeline des candidatures"
    :sousTitre="offre ? `${offre.intitule} · ${candidatures.length} candidature(s)` : 'Aucune offre publiée'"
  />

  <div class="barre">
    <Select v-model="offreId" :options="offres" optionValue="id" placeholder="Choisir une offre"
            :optionLabel="(o) => `${o.intitule}${o.statut === 'pourvue' ? ' (pourvue)' : ''} · ${o.nb} candidature(s)`" />
    <Tag v-if="close" value="Offre pourvue" severity="info" icon="pi pi-lock" />
  </div>

  <Message v-if="!offres.length && !chargement" severity="info" :closable="false">
    Aucune offre publiée. Publiez une offre dans l'écran « Offres d'emploi », puis positionnez
    des candidats depuis l'écran « Candidats » ou la page carrière.
  </Message>

  <div v-else class="kanban">
    <section v-for="etape in COLONNES" :key="etape.code" class="colonne" :class="etape.code">
      <header>
        <i :class="etape.icone" /> <span>{{ etape.label }}</span>
        <span class="compte">{{ parEtape[etape.code].length }}</span>
      </header>

      <p v-if="!parEtape[etape.code].length" class="vide">—</p>

      <article v-for="c in parEtape[etape.code]" :key="c.id" class="carte">
        <div class="nom" @click="router.push(`/rec/candidat/${c.candidat_id}`)">{{ c.prenom }} {{ c.nom }}</div>
        <div class="meta">{{ c.source }} · reçue le {{ formatDate(c.recue_le) }}</div>
        <div v-if="c.prochain_entretien" class="rdv"><i class="pi pi-calendar" /> {{ heure(c.prochain_entretien) }}</div>
        <Tag v-if="c.dernier_avis" :value="AVIS[c.dernier_avis].label" :severity="AVIS[c.dernier_avis].severite" class="petit" />
        <div v-if="c.etape === 'refus'" class="motif">{{ c.motif_refus }}</div>
        <Rating v-if="c.note" :modelValue="c.note" readonly :stars="5" class="note" />
        <p v-if="c.commentaire" class="commentaire">{{ c.commentaire }}</p>

        <div v-if="!close || c.etape === 'embauche'" class="actions">
          <WorkflowActions :candidature="c" compact @change="toutRecharger" />
          <Button v-if="c.etape !== 'embauche'" icon="pi pi-pencil" size="small" text severity="secondary"
                  v-tooltip.top="'Noter et commenter'" @click="ouvrirFiche(c)" />
        </div>
      </article>
    </section>
  </div>

  <Dialog :visible="!!fiche" modal :style="{ width: '30rem' }"
          :header="fiche ? `${fiche.prenom} ${fiche.nom}` : ''" @update:visible="fiche = null">
    <form v-if="fiche" class="formulaire" @submit.prevent="enregistrerFiche">
      <label>Note</label>
      <Rating v-model="fiche.note" :stars="5" />
      <label for="commentaire">Commentaire</label>
      <Textarea id="commentaire" v-model="fiche.commentaire" rows="4" autoResize />
      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="fiche = null" />
        <Button label="Enregistrer" icon="pi pi-check" type="submit" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.barre { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.barre > .p-select { min-width: 26rem; }
.kanban { display: grid; grid-template-columns: repeat(7, minmax(10rem, 1fr)); gap: .6rem; overflow-x: auto; }
.colonne { background: var(--p-surface-100); border-radius: 10px; padding: .55rem; min-height: 14rem; }
.colonne header { display: flex; align-items: flex-start; gap: .35rem; font-weight: 600; font-size: .8rem; margin-bottom: .6rem; line-height: 1.25; }
.colonne header i { margin-top: .1rem; }
.colonne.embauche header { color: var(--p-green-600); }
.colonne.refus header { color: var(--p-red-500); }
.compte { margin-left: auto; background: var(--p-surface-0); border-radius: 999px; padding: 0 .5rem; font-size: .75rem; }
.vide { color: var(--p-text-muted-color); text-align: center; font-size: .85rem; }
.carte { background: var(--p-surface-0); border: 1px solid var(--p-surface-200); border-radius: 8px; padding: .55rem; margin-bottom: .5rem; }
.nom { font-weight: 600; cursor: pointer; color: var(--p-primary-color); }
.nom:hover { text-decoration: underline; }
.meta { font-size: .75rem; color: var(--p-text-muted-color); margin-top: .15rem; }
.rdv { font-size: .75rem; margin-top: .3rem; color: var(--p-primary-color); }
.motif { font-size: .75rem; margin-top: .3rem; color: var(--p-red-500); }
.petit { margin-top: .35rem; font-size: .7rem; }
.note { margin-top: .35rem; }
.note :deep(.p-rating-icon) { width: .8rem; height: .8rem; }
.commentaire { font-size: .8rem; margin: .35rem 0 0; }
.actions { display: flex; flex-wrap: wrap; align-items: flex-start; gap: .15rem; margin-top: .5rem; }
.actions :deep(.p-button-label) { font-size: .75rem; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
