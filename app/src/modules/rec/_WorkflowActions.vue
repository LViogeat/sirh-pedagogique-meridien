<script setup>
/**
 * Les boutons du workflow d'une candidature (story #127).
 *
 * Utilisé sous chaque DP de la page candidat (mode complet) et sur chaque
 * carte du Pipeline (mode compact) : mêmes règles aux deux endroits.
 *
 * La candidature reçue doit porter : id, etape, etape_avant_refus, prenom,
 * nom, offre_id, besoin_id, intitule, establishment_id, position_id.
 */
import { ref, computed } from 'vue'
import { toast } from '@/socle/sdk'
import {
  suivante, precedente, libelleEtape, MOTIFS_REFUS,
  avancer, reculer, refuser, reactiver, embaucher,
} from './_workflow.js'
import PlanifierEntretien from './_PlanifierEntretien.vue'

const props = defineProps({
  candidature: { type: Object, required: true },
  compact: { type: Boolean, default: false },
})
const emit = defineEmits(['change'])

const c = computed(() => props.candidature)
const versSuivante = computed(() => suivante(c.value.etape))
const versPrecedente = computed(() => precedente(c.value.etape))
const refusable = computed(() => !['embauche', 'refus'].includes(c.value.etape))

const commentaire = ref('')
const enCours = ref(false)

async function executer(action, message) {
  enCours.value = true
  try {
    await action()
    toast.succes(message)
    commentaire.value = ''
    emit('change')
    return true
  } catch (erreur) {
    toast.erreur(erreur.message)
    return false
  } finally {
    enCours.value = false
  }
}

/* ── Avancer ────────────────────────────────────────────────────────────── */

const planification = ref(false)
const confirmationEmbauche = ref(false)

function clicSuivante() {
  if (versSuivante.value === 'entretien') planification.value = true
  else if (versSuivante.value === 'embauche') confirmationEmbauche.value = true
  else {
    executer(() => avancer(c.value, commentaire.value),
      `${c.value.prenom} ${c.value.nom} : ${libelleEtape(versSuivante.value)}`)
  }
}

async function confirmerEmbauche() {
  const ok = await executer(() => embaucher(c.value, commentaire.value),
    `${c.value.prenom} ${c.value.nom} est embauché(e). L'offre est pourvue`
    + (c.value.besoin_id ? ` et le besoin n° ${c.value.besoin_id} est clôturé.` : '.'))
  if (ok) confirmationEmbauche.value = false
}

function apresPlanification() {
  commentaire.value = ''
  emit('change')
}

/* ── Reculer (commentaire obligatoire) ──────────────────────────────────── */

const retour = ref(null) // { commentaire }

async function confirmerRetour() {
  if (!retour.value.commentaire.trim()) {
    toast.alerte('Un commentaire est obligatoire pour revenir en arrière.')
    return
  }
  const vers = versPrecedente.value
  const ok = await executer(() => reculer(c.value, retour.value.commentaire),
    `${c.value.prenom} ${c.value.nom} : retour à « ${libelleEtape(vers)} »`)
  if (ok) retour.value = null
}

/* ── Refuser (motif obligatoire) et réactiver ───────────────────────────── */

const refus = ref(null) // { motif, commentaire }

async function confirmerRefus() {
  if (!refus.value.motif) {
    toast.alerte('Choisissez un motif de refus.')
    return
  }
  if (refus.value.motif === 'Autre' && !refus.value.commentaire.trim()) {
    toast.alerte('Précisez le motif « Autre » dans le commentaire.')
    return
  }
  const ok = await executer(() => refuser(c.value, refus.value.motif, refus.value.commentaire),
    `Candidature de ${c.value.prenom} ${c.value.nom} refusée : ${refus.value.motif}`)
  if (ok) refus.value = null
}

function clicReactiver() {
  const vers = c.value.etape_avant_refus || 'nouvelle'
  executer(() => reactiver(c.value, commentaire.value),
    `${c.value.prenom} ${c.value.nom} réactivé(e) à « ${libelleEtape(vers)} »`)
}

const libelleSuivante = computed(() =>
  versSuivante.value === 'embauche' ? 'Embaucher' : `Passer à : ${libelleEtape(versSuivante.value)}`)
</script>

<template>
  <div class="workflow-actions" :class="{ compact }">
    <InputText v-if="!compact && c.etape !== 'embauche'" v-model="commentaire" size="small" class="commentaire"
               placeholder="Commentaire (facultatif pour avancer)" />

    <div class="boutons">
      <Button v-if="versPrecedente" size="small" outlined severity="secondary" icon="pi pi-arrow-left"
              :label="compact ? null : `Revenir à : ${libelleEtape(versPrecedente)}`"
              v-tooltip.top="compact ? `Revenir à : ${libelleEtape(versPrecedente)}` : null"
              :disabled="enCours" @click="retour = { commentaire: commentaire }" />

      <Button v-if="versSuivante" size="small" iconPos="right"
              :icon="versSuivante === 'embauche' ? 'pi pi-check' : versSuivante === 'entretien' ? 'pi pi-calendar-plus' : 'pi pi-arrow-right'"
              :severity="versSuivante === 'embauche' ? 'success' : null"
              :label="compact ? (versSuivante === 'embauche' ? 'Embaucher' : libelleEtape(versSuivante)) : libelleSuivante"
              :loading="enCours" @click="clicSuivante" />

      <Button v-if="c.etape === 'entretien'" size="small" text severity="secondary" icon="pi pi-calendar-plus"
              :label="compact ? null : 'Planifier un autre entretien'"
              v-tooltip.top="compact ? 'Planifier un autre entretien' : null"
              @click="planification = true" />

      <Button v-if="refusable" size="small" text severity="danger" icon="pi pi-times"
              :label="compact ? null : 'Refuser'" v-tooltip.top="compact ? 'Refuser' : null"
              :disabled="enCours" @click="refus = { motif: null, commentaire: commentaire }" />

      <Button v-if="c.etape === 'refus'" size="small" outlined icon="pi pi-replay"
              :label="`Réactiver (${libelleEtape(c.etape_avant_refus || 'nouvelle')})`"
              :loading="enCours" @click="clicReactiver" />
    </div>

    <!-- Revenir en arrière -->
    <Dialog :visible="!!retour" modal :style="{ width: '30rem' }"
            :header="`Revenir à « ${libelleEtape(versPrecedente)} »`" @update:visible="retour = null">
      <form v-if="retour" class="formulaire" @submit.prevent="confirmerRetour">
        <p class="aide">{{ c.prenom }} {{ c.nom }} · {{ c.intitule }}</p>
        <label for="retour-commentaire">Pourquoi revenir en arrière ? *</label>
        <Textarea id="retour-commentaire" v-model="retour.commentaire" rows="3" autoResize
                  placeholder="Ex. : entretien reporté à la demande du candidat" />
        <div class="pied">
          <Button label="Annuler" severity="secondary" text type="button" @click="retour = null" />
          <Button label="Revenir en arrière" icon="pi pi-arrow-left" type="submit" :loading="enCours" />
        </div>
      </form>
    </Dialog>

    <!-- Refuser -->
    <Dialog :visible="!!refus" modal :style="{ width: '30rem' }" header="Refuser la candidature"
            @update:visible="refus = null">
      <form v-if="refus" class="formulaire" @submit.prevent="confirmerRefus">
        <p class="aide">{{ c.prenom }} {{ c.nom }} · {{ c.intitule }}</p>
        <label for="motif">Motif du refus *</label>
        <Select inputId="motif" v-model="refus.motif" :options="MOTIFS_REFUS" placeholder="Choisir un motif" />
        <label for="refus-commentaire">Commentaire {{ refus.motif === 'Autre' ? '*' : '(facultatif)' }}</label>
        <Textarea id="refus-commentaire" v-model="refus.commentaire" rows="3" autoResize />
        <div class="pied">
          <Button label="Annuler" severity="secondary" text type="button" @click="refus = null" />
          <Button label="Refuser" icon="pi pi-times" severity="danger" type="submit" :loading="enCours" />
        </div>
      </form>
    </Dialog>

    <!-- Embaucher -->
    <Dialog :visible="confirmationEmbauche" modal header="Confirmer l'embauche" :style="{ width: '32rem' }"
            @update:visible="confirmationEmbauche = false">
      <p>Embaucher <strong>{{ c.prenom }} {{ c.nom }}</strong> sur <strong>{{ c.intitule }}</strong> ?</p>
      <ul class="effets">
        <li>l'offre passera à « Pourvue » ;</li>
        <li v-if="c.besoin_id">le besoin n° {{ c.besoin_id }} sera <strong>clôturé</strong> dans le socle, visible
          par toute la classe ;</li>
        <li>l'embauche est définitive : plus aucun retour arrière ne sera possible.</li>
      </ul>
      <div class="pied">
        <Button label="Annuler" severity="secondary" text @click="confirmationEmbauche = false" />
        <Button label="Embaucher" icon="pi pi-check" severity="success" :loading="enCours" @click="confirmerEmbauche" />
      </div>
    </Dialog>

    <!-- Planifier l'entretien : obligatoire pour passer à « Entretien à réaliser » -->
    <PlanifierEntretien v-model:visible="planification" :candidature="c" :commentaire="commentaire"
                        @planifie="apresPlanification" />
  </div>
</template>

<style scoped>
.workflow-actions { display: flex; flex-direction: column; gap: .5rem; }
.commentaire { max-width: 32rem; }
.boutons { display: flex; flex-wrap: wrap; gap: .35rem; align-items: center; }
.compact .boutons { gap: .15rem; }
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: 0; }
.effets { font-size: .9rem; padding-left: 1.2rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
