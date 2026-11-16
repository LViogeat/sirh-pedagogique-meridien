<!-- libelle: Pipeline -->
<script setup>
/**
 * Le pipeline des candidatures d'une offre, et l'embauche (story #7).
 *
 * Une colonne par étape. Chaque candidature avance d'une étape à la fois ;
 * « Refuser » la sort du processus sans toucher à l'offre.
 *
 * « Embaucher » termine le recrutement, dans cet ordre :
 *   1. le besoin d'origine est clôturé dans le socle (cloturerBesoin) ;
 *   2. la candidature passe à « embauche » ;
 *   3. l'offre passe à « pourvue ».
 * La clôture d'un besoin est définitive : l'écran demande confirmation.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { cloturerBesoin, sql, update, formatDate, toast } from '@/socle/sdk'

const ETAPES = [
  { code: 'nouvelle', label: 'Nouvelle', icone: 'pi pi-inbox' },
  { code: 'preselection', label: 'Présélection', icone: 'pi pi-filter' },
  { code: 'entretien', label: 'Entretien', icone: 'pi pi-comments' },
  { code: 'proposition', label: 'Proposition', icone: 'pi pi-file-edit' },
  { code: 'embauche', label: 'Embauche', icone: 'pi pi-check-circle' },
  { code: 'refus', label: 'Refus', icone: 'pi pi-times-circle' },
]
const SUIVANTE = { nouvelle: 'preselection', preselection: 'entretien', entretien: 'proposition' }
const libelleEtape = (code) => ETAPES.find((e) => e.code === code)?.label || code

const offres = ref([])
const offreId = ref(null)
const candidatures = ref([])
const chargement = ref(true)
const enCours = ref(null)

const offre = computed(() => offres.value.find((o) => o.id === offreId.value) || null)
const close = computed(() => offre.value?.statut === 'pourvue')

async function chargerOffres() {
  try {
    offres.value = await sql(
      `select o.id, o.intitule, o.statut, o.besoin_id, count(c.id)::int as nb
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
      `select ca.*, c.prenom, c.nom, c.source, c.email
         from candidatures ca join candidats c on c.id = ca.candidat_id
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
watch(offreId, chargerCandidatures)

const parEtape = computed(() =>
  Object.fromEntries(ETAPES.map((e) => [e.code, candidatures.value.filter((c) => c.etape === e.code)])))

/* ── Changer d'étape ────────────────────────────────────────────────────── */

async function changerEtape(candidature, etape) {
  enCours.value = candidature.id
  try {
    await sql(
      'update candidatures set etape = :etape, maj_le = current_date where id = :id',
      { etape, id: candidature.id },
    )
    toast.succes(`${candidature.prenom} ${candidature.nom} : ${libelleEtape(etape)}`)
    await toutRecharger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}

/* ── Note et commentaire ────────────────────────────────────────────────── */

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

/* ── Embaucher ──────────────────────────────────────────────────────────── */

const aEmbaucher = ref(null) // candidature en attente de confirmation

async function embaucher() {
  const candidature = aEmbaucher.value
  enCours.value = candidature.id
  try {
    const nom = `${candidature.prenom} ${candidature.nom}`
    if (offre.value.besoin_id) {
      await cloturerBesoin(offre.value.besoin_id, `Poste pourvu : ${nom} (offre n° ${offre.value.id})`)
    }
    await sql(
      "update candidatures set etape = 'embauche', maj_le = current_date where id = :id",
      { id: candidature.id },
    )
    await update('offres', offre.value.id, { statut: 'pourvue' })
    toast.succes(
      offre.value.besoin_id
        ? `${nom} est embauché(e). L'offre est pourvue et le besoin n° ${offre.value.besoin_id} est clôturé.`
        : `${nom} est embauché(e). L'offre est pourvue.`,
      'Recrutement terminé',
    )
    aEmbaucher.value = null
    await toutRecharger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}
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
    des candidats depuis l'écran « Candidats ».
  </Message>

  <div v-else class="kanban">
    <section v-for="etape in ETAPES" :key="etape.code" class="colonne" :class="etape.code">
      <header>
        <i :class="etape.icone" /> {{ etape.label }}
        <span class="compte">{{ parEtape[etape.code].length }}</span>
      </header>

      <p v-if="!parEtape[etape.code].length" class="vide">—</p>

      <article v-for="c in parEtape[etape.code]" :key="c.id" class="carte">
        <div class="nom" @click="ouvrirFiche(c)">{{ c.prenom }} {{ c.nom }}</div>
        <div class="meta">{{ c.source }} · reçue le {{ formatDate(c.recue_le) }}</div>
        <Rating v-if="c.note" :modelValue="c.note" readonly :stars="5" class="note" />
        <p v-if="c.commentaire" class="commentaire">{{ c.commentaire }}</p>

        <div v-if="!close && !['embauche', 'refus'].includes(c.etape)" class="boutons">
          <Button v-if="SUIVANTE[c.etape]" :label="libelleEtape(SUIVANTE[c.etape])"
                  icon="pi pi-arrow-right" iconPos="right" size="small"
                  :loading="enCours === c.id" :disabled="enCours !== null"
                  @click="changerEtape(c, SUIVANTE[c.etape])" />
          <Button v-if="c.etape === 'proposition'" label="Embaucher" icon="pi pi-check"
                  size="small" severity="success" :disabled="enCours !== null"
                  @click="aEmbaucher = c" />
          <Button icon="pi pi-pencil" size="small" text severity="secondary"
                  v-tooltip.top="'Noter et commenter'" @click="ouvrirFiche(c)" />
          <Button icon="pi pi-times" size="small" text severity="danger"
                  v-tooltip.top="'Refuser'" :disabled="enCours !== null"
                  @click="changerEtape(c, 'refus')" />
        </div>
      </article>
    </section>
  </div>

  <!-- Note et commentaire -->
  <Dialog :visible="!!fiche" modal :style="{ width: '30rem' }"
          :header="fiche ? `${fiche.prenom} ${fiche.nom}` : ''" @update:visible="fiche = null">
    <form v-if="fiche" class="formulaire" @submit.prevent="enregistrerFiche">
      <p class="aide">Étape : <strong>{{ libelleEtape(fiche.etape) }}</strong> · {{ fiche.email || 'pas d’e-mail' }}</p>
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

  <!-- Confirmation d'embauche -->
  <Dialog :visible="!!aEmbaucher" modal header="Confirmer l'embauche" :style="{ width: '32rem' }"
          @update:visible="aEmbaucher = null">
    <template v-if="aEmbaucher && offre">
      <p>
        Embaucher <strong>{{ aEmbaucher.prenom }} {{ aEmbaucher.nom }}</strong>
        sur <strong>{{ offre.intitule }}</strong> ?
      </p>
      <ul class="effets">
        <li>l'offre passera à « Pourvue » ;</li>
        <li v-if="offre.besoin_id">
          le besoin n° {{ offre.besoin_id }} sera <strong>clôturé</strong> dans le socle,
          visible par toute la classe. Un besoin clôturé ne peut pas être rouvert.
        </li>
      </ul>
      <div class="pied">
        <Button label="Annuler" severity="secondary" text @click="aEmbaucher = null" />
        <Button label="Embaucher" icon="pi pi-check" severity="success"
                :loading="enCours === aEmbaucher.id" @click="embaucher" />
      </div>
    </template>
  </Dialog>
</template>

<style scoped>
.barre { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.barre > .p-select { min-width: 26rem; }
.kanban { display: grid; grid-template-columns: repeat(6, minmax(10.5rem, 1fr)); gap: .75rem; overflow-x: auto; }
.colonne { background: var(--p-surface-100); border-radius: 10px; padding: .6rem; min-height: 14rem; }
.colonne header { display: flex; align-items: center; gap: .4rem; font-weight: 600; font-size: .85rem; margin-bottom: .6rem; }
.colonne.embauche header { color: var(--p-green-600); }
.colonne.refus header { color: var(--p-red-500); }
.compte { margin-left: auto; background: var(--p-surface-0); border-radius: 999px; padding: 0 .5rem; font-size: .75rem; }
.vide { color: var(--p-text-muted-color); text-align: center; font-size: .85rem; }
.carte { background: var(--p-surface-0); border: 1px solid var(--p-surface-200); border-radius: 8px; padding: .6rem; margin-bottom: .5rem; }
.nom { font-weight: 600; cursor: pointer; }
.meta { font-size: .75rem; color: var(--p-text-muted-color); margin-top: .15rem; }
.note { margin-top: .35rem; }
.note :deep(.p-rating-icon) { width: .8rem; height: .8rem; }
.commentaire { font-size: .8rem; margin: .35rem 0 0; color: var(--p-text-color); }
.boutons { display: flex; flex-wrap: wrap; gap: .2rem; margin-top: .5rem; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: 0; }
.effets { font-size: .9rem; padding-left: 1.2rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
