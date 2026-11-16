<!-- libelle: Page carrière -->
<script setup>
/**
 * La page carrière, côté candidat (story #108).
 *
 * Elle montre les offres PUBLIÉES comme sur un site carrière, et permet d'y
 * postuler avec son CV. Une candidature reçue ici :
 *   - crée le candidat (source « Site carrière »), ou retrouve celui qui a
 *     déjà postulé avec la même adresse e-mail ;
 *   - enregistre la date de son consentement au traitement des données ;
 *   - crée la candidature à l'étape « Nouvelle », sans doublon possible ;
 *   - range le CV dans ses pièces jointes.
 */
import { ref, computed, onMounted } from 'vue'
import { getEtablissements, getReferentiels, sql, insert, update, formatDate, toast } from '@/socle/sdk'
import { ajouterPiece, verifierFichier, formatTaille } from './_fichiers.js'

const offres = ref([])
const hotels = ref({})
const contrats = ref({})
const chargement = ref(true)
const ville = ref(null)
const ouverte = ref(null) // offre dont on lit le détail

async function charger() {
  chargement.value = true
  try {
    const [liste, etabs, refs] = await Promise.all([
      sql(`select id, intitule, type_contrat, description, establishment_id, publiee_le
             from offres where statut = 'publiee' order by publiee_le desc nulls last, id desc`),
      getEtablissements(),
      getReferentiels(),
    ])
    offres.value = liste
    hotels.value = Object.fromEntries(etabs.map((e) => [e.id, e]))
    contrats.value = Object.fromEntries((refs.type_contrat || []).map((t) => [t.code, t.label]))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)

const villes = computed(() =>
  [...new Set(offres.value.map((o) => hotels.value[o.establishment_id]?.city).filter(Boolean))].sort())
const affichees = computed(() =>
  offres.value.filter((o) => !ville.value || hotels.value[o.establishment_id]?.city === ville.value))

const extrait = (texte) => {
  const t = (texte || '').replace(/\s+/g, ' ').trim()
  return t.length > 180 ? `${t.slice(0, 180)}…` : t || 'Description à venir.'
}

/* ── Postuler ───────────────────────────────────────────────────────────── */

const candidature = ref(null) // { offre, prenom, nom, email, telephone, fichier, consentement }
const envoi = ref(false)
const confirmation = ref(null)
const champFichier = ref(null)

function postuler(offre) {
  ouverte.value = null
  confirmation.value = null
  candidature.value = { offre, prenom: '', nom: '', email: '', telephone: '', fichier: null, consentement: false }
}

function choisirFichier(evenement) {
  const fichier = evenement.target.files?.[0] || null
  const probleme = fichier && verifierFichier(fichier, { pdfSeulement: true })
  if (probleme) {
    toast.erreur(probleme)
    evenement.target.value = ''
    candidature.value.fichier = null
    return
  }
  candidature.value.fichier = fichier
}

const emailValide = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)

async function envoyer() {
  const c = candidature.value
  if (!c.prenom.trim() || !c.nom.trim() || !emailValide(c.email.trim())) {
    toast.alerte('Indiquez votre prénom, votre nom et une adresse e-mail valide.')
    return
  }
  if (!c.fichier) {
    toast.alerte('Joignez votre CV au format PDF.')
    return
  }
  if (!c.consentement) {
    toast.alerte('Votre consentement au traitement de vos données est nécessaire pour postuler.')
    return
  }
  envoi.value = true
  try {
    const email = c.email.trim().toLowerCase()

    // 1. Le candidat : celui qui a déjà postulé avec cette adresse, ou un nouveau.
    let [candidat] = await sql(
      'select id from candidats where lower(email) = :email order by id limit 1', { email })
    if (candidat) {
      const [deja] = await sql(
        'select id from candidatures where offre_id = :offre and candidat_id = :candidat',
        { offre: c.offre.id, candidat: candidat.id })
      if (deja) {
        toast.alerte('Vous avez déjà postulé à cette offre avec cette adresse e-mail.', 'Candidature déjà reçue')
        return
      }
      await sql('update candidats set consentement_le = current_date, telephone = coalesce(:tel, telephone) where id = :id',
        { id: candidat.id, tel: c.telephone.trim() || null })
    } else {
      candidat = await insert('candidats', {
        prenom: c.prenom.trim(),
        nom: c.nom.trim(),
        email,
        telephone: c.telephone.trim() || null,
        source: 'Site carrière',
        consentement_le: new Date().toISOString().slice(0, 10),
      })
    }

    // 2. La candidature, puis 3. le CV.
    await insert('candidatures', { offre_id: c.offre.id, candidat_id: candidat.id })
    await ajouterPiece(candidat.id, c.fichier, 'cv')

    confirmation.value = { prenom: c.prenom.trim(), intitule: c.offre.intitule }
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    envoi.value = false
  }
}

function fermer() {
  candidature.value = null
  confirmation.value = null
}

const hotel = (o) => hotels.value[o.establishment_id]
</script>

<template>
  <section class="hero">
    <p class="surtitre">Sorbonne-Hôtel · carrières</p>
    <h1>Rejoignez nos équipes</h1>
    <p>Cinq hôtels 4 et 5 étoiles, de Paris à Annecy. Découvrez nos offres et postulez en deux minutes.</p>
  </section>

  <div class="barre">
    <span class="compte">{{ affichees.length }} offre(s) ouverte(s)</span>
    <Select v-model="ville" :options="villes" placeholder="Toutes les villes" showClear />
  </div>

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!affichees.length" severity="info" :closable="false">
    Aucune offre n'est publiée pour le moment. Revenez bientôt !
  </Message>

  <div v-else class="offres">
    <article v-for="o in affichees" :key="o.id" class="offre">
      <div class="lieu"><i class="pi pi-map-marker" /> {{ hotel(o)?.city }} · {{ hotel(o)?.name }}</div>
      <h2>{{ o.intitule }}</h2>
      <div class="etiquettes">
        <Tag :value="contrats[o.type_contrat] || o.type_contrat" severity="secondary" />
        <span v-if="o.publiee_le" class="date">Publiée le {{ formatDate(o.publiee_le) }}</span>
      </div>
      <p class="extrait">{{ extrait(o.description) }}</p>
      <div class="boutons">
        <Button label="Voir l'offre" text size="small" @click="ouverte = o" />
        <Button label="Postuler" icon="pi pi-send" size="small" @click="postuler(o)" />
      </div>
    </article>
  </div>

  <!-- Détail d'une offre -->
  <Dialog :visible="!!ouverte" modal :style="{ width: '40rem' }" :header="ouverte?.intitule"
          @update:visible="ouverte = null">
    <template v-if="ouverte">
      <p class="lieu"><i class="pi pi-map-marker" /> {{ hotel(ouverte)?.name }}, {{ hotel(ouverte)?.address }},
        {{ hotel(ouverte)?.postal_code }} {{ hotel(ouverte)?.city }} · {{ contrats[ouverte.type_contrat] }}</p>
      <p class="description">{{ ouverte.description || 'Description à venir.' }}</p>
      <div class="pied">
        <Button label="Postuler à cette offre" icon="pi pi-send" @click="postuler(ouverte)" />
      </div>
    </template>
  </Dialog>

  <!-- Formulaire de candidature -->
  <Dialog :visible="!!candidature" modal :style="{ width: '34rem' }"
          :header="candidature ? `Postuler · ${candidature.offre.intitule}` : ''"
          @update:visible="fermer">
    <div v-if="confirmation" class="merci">
      <i class="pi pi-check-circle" />
      <h3>Merci {{ confirmation.prenom }} !</h3>
      <p>Votre candidature au poste « {{ confirmation.intitule }} » a bien été envoyée.
        Notre équipe recrutement revient vers vous rapidement.</p>
      <Button label="Fermer" @click="fermer" />
    </div>

    <form v-else-if="candidature" class="formulaire" @submit.prevent="envoyer">
      <div class="deux">
        <div><label for="c-prenom">Prénom *</label><InputText id="c-prenom" v-model="candidature.prenom" fluid /></div>
        <div><label for="c-nom">Nom *</label><InputText id="c-nom" v-model="candidature.nom" fluid /></div>
      </div>
      <label for="c-email">E-mail *</label>
      <InputText id="c-email" v-model="candidature.email" type="email" />
      <label for="c-telephone">Téléphone</label>
      <InputText id="c-telephone" v-model="candidature.telephone" />

      <label>CV au format PDF * <span class="leger">(500 Ko maximum)</span></label>
      <div class="fichier">
        <input ref="champFichier" type="file" accept="application/pdf,.pdf" class="cache" @change="choisirFichier" />
        <Button :label="candidature.fichier ? 'Changer de fichier' : 'Choisir mon CV'" icon="pi pi-upload"
                outlined size="small" type="button" @click="champFichier.click()" />
        <span v-if="candidature.fichier" class="nom-fichier">
          <i class="pi pi-file-pdf" /> {{ candidature.fichier.name }} · {{ formatTaille(candidature.fichier.size) }}
        </span>
      </div>

      <div class="consentement">
        <Checkbox v-model="candidature.consentement" inputId="c-consentement" binary />
        <label for="c-consentement">
          J'accepte que Sorbonne-Hôtel traite mes données pour étudier ma candidature et me recontacter.
          Elles sont conservées deux ans au plus, et je peux demander leur suppression à tout moment. *
        </label>
      </div>

      <div class="pied">
        <Button label="Annuler" severity="secondary" text type="button" @click="fermer" />
        <Button label="Envoyer ma candidature" icon="pi pi-send" type="submit" :loading="envoi" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.hero {
  background: linear-gradient(135deg, var(--p-primary-700), var(--p-primary-500));
  color: #fff; border-radius: 14px; padding: 2rem 2.25rem; margin-bottom: 1.5rem;
}
.hero h1 { margin: .25rem 0 .5rem; font-size: 1.9rem; }
.hero p { margin: 0; opacity: .92; }
.surtitre { text-transform: uppercase; letter-spacing: .08em; font-size: .75rem; }
.barre { display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; }
.compte { font-weight: 600; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.offres { display: grid; grid-template-columns: repeat(auto-fill, minmax(19rem, 1fr)); gap: 1rem; }
.offre {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200); border-radius: 12px;
  padding: 1.1rem 1.25rem; display: flex; flex-direction: column;
}
.offre h2 { font-size: 1.1rem; margin: .35rem 0 .5rem; }
.lieu { font-size: .8rem; color: var(--p-text-muted-color); }
.etiquettes { display: flex; align-items: center; gap: .5rem; }
.date { font-size: .78rem; color: var(--p-text-muted-color); }
.extrait { font-size: .88rem; color: var(--p-text-color); flex: 1; margin: .75rem 0; }
.boutons { display: flex; justify-content: flex-end; gap: .25rem; }
.description { white-space: pre-line; line-height: 1.5; }
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire > label, .deux label { font-size: .85rem; font-weight: 600; margin-top: .6rem; display: block; margin-bottom: .25rem; }
.leger { font-weight: 400; color: var(--p-text-muted-color); }
.deux { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.fichier { display: flex; align-items: center; gap: .75rem; flex-wrap: wrap; }
.nom-fichier { font-size: .85rem; }
.cache { display: none; }
.consentement { display: flex; gap: .6rem; align-items: flex-start; margin-top: 1rem; font-size: .82rem; line-height: 1.4; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
.merci { text-align: center; padding: 1rem; }
.merci > i { font-size: 2.5rem; color: var(--p-green-500); }
.merci h3 { margin: .5rem 0; }
</style>
