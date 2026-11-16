<script setup>
/**
 * La page d'un candidat (story #105).
 *
 * On y arrive en cliquant sur un nom dans l'écran « Candidats » ou sur une
 * carte du Pipeline. Elle rassemble les coordonnées, toutes les candidatures
 * (et l'étape de chacune), les entretiens et les pièces jointes.
 *
 * Story #127 : sous chaque DP (demande de poste = offre), la frise du
 * workflow de recrutement, les boutons pour avancer, revenir, refuser ou
 * réactiver (_WorkflowActions), et l'historique de chaque changement.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getEtablissements, sql, update, remove, formatDate, toast } from '@/socle/sdk'
import {
  TYPES_DOCUMENT, libelleType, formatTaille, verifierFichier,
  ajouterPiece, listerPieces, ouvrirPiece, telechargerPiece,
} from './_fichiers.js'
import {
  ETAPES, rangDe, libelleEtape, SEVERITES, MOUVEMENTS, chargerHistorique,
} from './_workflow.js'
import WorkflowActions from './_WorkflowActions.vue'

const route = useRoute()
const router = useRouter()
const candidatId = computed(() => Number(route.params.id))

const candidat = ref(null)
const fiche = ref(null)
const candidatures = ref([])
const entretiens = ref([])
const pieces = ref([])
const hotels = ref({})
const chargement = ref(true)
const enregistrement = ref(false)

const SOURCES = ['Spontanée', 'Site carrière', 'Indeed', 'LinkedIn', 'France Travail', 'Cooptation', 'École / alternance']
const historique = ref([])
const AVIS = {
  favorable: { label: 'Favorable', severite: 'success' },
  reserve: { label: 'Réservé', severite: 'warn' },
  defavorable: { label: 'Défavorable', severite: 'danger' },
}
const STATUTS_ENTRETIEN = { planifie: 'Planifié', realise: 'Réalisé', annule: 'Annulé' }

async function charger() {
  if (!Number.isInteger(candidatId.value) || candidatId.value <= 0) {
    chargement.value = false
    return
  }
  chargement.value = true
  try {
    const [lignes, liste, rdv, docs, etabs] = await Promise.all([
      sql(
        `select id, nom, prenom, email, telephone, source, cree_le, consentement_le
           from candidats where id = :id`,
        { id: candidatId.value },
      ),
      sql(
        `select ca.id, ca.etape, ca.etape_avant_refus, ca.motif_refus, ca.note, ca.recue_le, ca.maj_le,
                c.prenom, c.nom,
                o.id as offre_id, o.intitule, o.statut as statut_offre, o.establishment_id,
                o.position_id, o.besoin_id
           from candidatures ca
           join offres o on o.id = ca.offre_id
           join candidats c on c.id = ca.candidat_id
          where ca.candidat_id = :id order by ca.recue_le desc, ca.id desc`,
        { id: candidatId.value },
      ),
      sql(
        `select e.id, e.date_heure, e.lieu, e.recruteur_nom, e.statut, e.avis, o.intitule
           from entretiens e
           join candidatures ca on ca.id = e.candidature_id
           join offres o on o.id = ca.offre_id
          where ca.candidat_id = :id order by e.date_heure desc`,
        { id: candidatId.value },
      ),
      listerPieces(candidatId.value),
      getEtablissements(),
    ])
    candidat.value = lignes[0] || null
    fiche.value = candidat.value ? { ...candidat.value } : null
    candidatures.value = liste
    historique.value = await chargerHistorique(liste.map((c) => c.id))
    entretiens.value = rdv
    pieces.value = docs
    hotels.value = Object.fromEntries(etabs.map((e) => [e.id, e]))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)
watch(candidatId, charger)

const modifie = computed(() =>
  candidat.value && ['nom', 'prenom', 'email', 'telephone', 'source']
    .some((k) => (fiche.value[k] || '') !== (candidat.value[k] || '')))

async function enregistrer() {
  if (!fiche.value.prenom?.trim() || !fiche.value.nom?.trim()) {
    toast.alerte('Le prénom et le nom sont obligatoires.')
    return
  }
  enregistrement.value = true
  try {
    await update('candidats', candidat.value.id, {
      prenom: fiche.value.prenom.trim(),
      nom: fiche.value.nom.trim(),
      email: fiche.value.email?.trim() || null,
      telephone: fiche.value.telephone?.trim() || null,
      source: fiche.value.source || 'Spontanée',
    })
    toast.succes('Coordonnées enregistrées')
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/* ── Pièces jointes ─────────────────────────────────────────────────────── */

const typeDocument = ref('cv')
const champFichier = ref(null)
const envoi = ref(false)

async function deposer(evenement) {
  const fichier = evenement.target.files?.[0]
  evenement.target.value = '' // pour pouvoir redéposer le même fichier
  const probleme = verifierFichier(fichier)
  if (probleme) {
    toast.erreur(probleme)
    return
  }
  envoi.value = true
  try {
    await ajouterPiece(candidat.value.id, fichier, typeDocument.value)
    toast.succes(`« ${fichier.name} » ajouté`)
    pieces.value = await listerPieces(candidat.value.id)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    envoi.value = false
  }
}

async function ouvrir(piece) {
  try { await ouvrirPiece(piece.id) } catch (erreur) { toast.erreur(erreur.message) }
}

async function telecharger(piece) {
  try { await telechargerPiece(piece.id) } catch (erreur) { toast.erreur(erreur.message) }
}

const aSupprimer = ref(null)

async function supprimer() {
  try {
    await remove('pieces_jointes', aSupprimer.value.id)
    toast.info(`« ${aSupprimer.value.nom_fichier} » supprimé`)
    aSupprimer.value = null
    pieces.value = await listerPieces(candidat.value.id)
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

const historiqueDe = (candidatureId) => historique.value.filter((h) => h.candidature_id === candidatureId)
const quand = (v) => `${formatDate(v)} à ${new Date(v).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`
const etatEtape = (candidature, code) => {
  const actuel = rangDe(candidature.etape === 'refus' ? candidature.etape_avant_refus : candidature.etape)
  const rang = rangDe(code)
  if (rang < actuel) return 'faite'
  if (rang === actuel) return candidature.etape === 'refus' ? 'refusee' : 'actuelle'
  return 'a-venir'
}

const hotelCourt = (id) => (hotels.value[id]?.name || '').replace(/^Sorbonne-Hôtel\s+/, '')
const dateHeure = (v) =>
  v ? `${formatDate(v)} à ${new Date(v).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}` : '—'
</script>

<template>
  <div class="retour">
    <Button label="Retour aux candidats" icon="pi pi-arrow-left" text size="small"
            @click="router.push('/rec/candidats')" />
  </div>

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!candidat" severity="info" :closable="false">
    Aucun candidat à afficher. Ouvrez une page candidat en cliquant sur un nom dans l'écran
    « Candidats ».
  </Message>

  <template v-else>
    <PageHeader :titre="`${candidat.prenom} ${candidat.nom}`"
                :sousTitre="`Candidat n° ${candidat.id} · ajouté le ${formatDate(candidat.cree_le)} · source : ${candidat.source}`" />

    <div class="grille">
      <!-- Coordonnées -->
      <Card>
        <template #title>Coordonnées</template>
        <template #content>
          <form class="formulaire" @submit.prevent="enregistrer">
            <div class="deux">
              <div><label for="prenom">Prénom</label><InputText id="prenom" v-model="fiche.prenom" fluid /></div>
              <div><label for="nom">Nom</label><InputText id="nom" v-model="fiche.nom" fluid /></div>
            </div>
            <label for="email">E-mail</label>
            <InputText id="email" v-model="fiche.email" type="email" />
            <label for="telephone">Téléphone</label>
            <InputText id="telephone" v-model="fiche.telephone" />
            <label for="source">Source</label>
            <Select inputId="source" v-model="fiche.source" :options="SOURCES" editable />
            <p v-if="candidat.consentement_le" class="aide">
              <i class="pi pi-shield" /> Consentement au traitement des données donné le
              {{ formatDate(candidat.consentement_le) }}
            </p>
            <div class="pied">
              <Button label="Enregistrer" icon="pi pi-check" type="submit" size="small"
                      :disabled="!modifie" :loading="enregistrement" />
            </div>
          </form>
        </template>
      </Card>

      <!-- Pièces jointes -->
      <Card>
        <template #title>Pièces jointes</template>
        <template #content>
          <div class="depot">
            <Select v-model="typeDocument" :options="TYPES_DOCUMENT" optionLabel="label" optionValue="code" />
            <input ref="champFichier" type="file" class="cache"
                   accept=".pdf,.doc,.docx,.odt,.png,.jpg,.jpeg" @change="deposer" />
            <Button label="Ajouter un document" icon="pi pi-paperclip" size="small" outlined
                    :loading="envoi" @click="champFichier.click()" />
          </div>
          <p class="aide">PDF, Word ou image · 500 Ko maximum par fichier.</p>

          <DataTable :value="pieces" dataKey="id" size="small">
            <template #empty>Aucun document. Ajoutez le CV du candidat.</template>
            <Column header="Document">
              <template #body="{ data }">
                <a href="#" class="lien" @click.prevent="ouvrir(data)">
                  <i :class="data.type_mime === 'application/pdf' ? 'pi pi-file-pdf' : 'pi pi-file'" />
                  {{ data.nom_fichier }}
                </a>
                <span class="detail">{{ libelleType(data.type_document) }} · {{ formatTaille(data.taille) }}</span>
              </template>
            </Column>
            <Column field="ajoutee_le" header="Ajouté le" style="width: 7rem">
              <template #body="{ data }">{{ formatDate(data.ajoutee_le) }}</template>
            </Column>
            <Column style="width: 7rem">
              <template #body="{ data }">
                <Button icon="pi pi-download" text size="small" v-tooltip.top="'Télécharger'"
                        @click="telecharger(data)" />
                <Button icon="pi pi-trash" text size="small" severity="danger" v-tooltip.top="'Supprimer'"
                        @click="aSupprimer = data" />
              </template>
            </Column>
          </DataTable>
        </template>
      </Card>

      <!-- Candidatures : une DP par bloc, avec son workflow et son historique -->
      <Card class="large">
        <template #title>Candidatures</template>
        <template #content>
          <p v-if="!candidatures.length" class="muet">Ce candidat n'est positionné sur aucune offre.</p>

          <section v-for="ca in candidatures" :key="ca.id" class="dp">
            <header class="dp-entete">
              <div>
                <a href="#" class="lien titre-dp"
                   @click.prevent="router.push({ path: '/rec/pipeline', query: { offre: ca.offre_id } })">
                  {{ ca.intitule }}
                </a>
                <span class="detail">
                  DP n° {{ ca.offre_id }} · {{ hotelCourt(ca.establishment_id) }} · candidature reçue le {{ formatDate(ca.recue_le) }}
                </span>
              </div>
              <Tag :value="ca.etape === 'refus' ? `Refusé · ${ca.motif_refus}` : libelleEtape(ca.etape)"
                   :severity="SEVERITES[ca.etape]" />
            </header>

            <ol class="frise">
              <li v-for="(e, i) in ETAPES" :key="e.code" :class="etatEtape(ca, e.code)">
                <span class="pastille">
                  <i v-if="etatEtape(ca, e.code) === 'faite'" class="pi pi-check" />
                  <i v-else-if="etatEtape(ca, e.code) === 'refusee'" class="pi pi-times" />
                  <template v-else>{{ i + 1 }}</template>
                </span>
                <span class="libelle">{{ e.label }}</span>
              </li>
            </ol>

            <WorkflowActions :candidature="ca" @change="charger" />

            <details class="historique" :open="historiqueDe(ca.id).length > 0 && historiqueDe(ca.id).length <= 5">
              <summary>Historique du workflow · {{ historiqueDe(ca.id).length }} mouvement(s)</summary>
              <p v-if="!historiqueDe(ca.id).length" class="muet">Aucun mouvement depuis la réception de la candidature.</p>
              <ul v-else>
                <li v-for="h in historiqueDe(ca.id)" :key="h.id" :class="h.mouvement">
                  <i :class="MOUVEMENTS[h.mouvement].icone" />
                  <span class="date">{{ quand(h.fait_le) }}</span>
                  <span>{{ libelleEtape(h.etape_depart) }} → <strong>{{ libelleEtape(h.etape_arrivee) }}</strong></span>
                  <Tag v-if="h.mouvement !== 'avance'" :value="MOUVEMENTS[h.mouvement].label"
                       :severity="h.mouvement === 'retour' ? 'warn' : h.mouvement === 'refus' ? 'danger' : 'info'" class="petit" />
                  <span v-if="h.motif" class="texte">Motif : {{ h.motif }}</span>
                  <span v-if="h.commentaire" class="texte">« {{ h.commentaire }} »</span>
                </li>
              </ul>
            </details>
          </section>
        </template>
      </Card>

      <!-- Entretiens -->
      <Card class="large">
        <template #title>Entretiens</template>
        <template #content>
          <DataTable :value="entretiens" dataKey="id" size="small" rowHover
                     @row-click="(e) => router.push(`/rec/entretien/${e.data.id}`)">
            <template #empty>Aucun entretien planifié. Planifiez-en un depuis le Pipeline.</template>
            <Column header="Date">
              <template #body="{ data }">{{ dateHeure(data.date_heure) }}</template>
            </Column>
            <Column field="intitule" header="Offre" />
            <Column field="recruteur_nom" header="Recruteur" />
            <Column header="Statut" style="width: 8rem">
              <template #body="{ data }">{{ STATUTS_ENTRETIEN[data.statut] }}</template>
            </Column>
            <Column header="Avis" style="width: 9rem">
              <template #body="{ data }">
                <Tag v-if="data.avis" :value="AVIS[data.avis].label" :severity="AVIS[data.avis].severite" />
                <span v-else class="muet">—</span>
              </template>
            </Column>
          </DataTable>
        </template>
      </Card>
    </div>
  </template>

  <Dialog :visible="!!aSupprimer" modal header="Supprimer le document" :style="{ width: '28rem' }"
          @update:visible="aSupprimer = null">
    <p v-if="aSupprimer">Supprimer définitivement « {{ aSupprimer.nom_fichier }} » ?</p>
    <div class="pied">
      <Button label="Annuler" severity="secondary" text @click="aSupprimer = null" />
      <Button label="Supprimer" icon="pi pi-trash" severity="danger" @click="supprimer" />
    </div>
  </Dialog>
</template>

<style scoped>
.retour { margin: -.5rem 0 .5rem -.75rem; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.grille { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.grille .large { grid-column: 1 / -1; }
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .5rem; display: block; margin-bottom: .25rem; }
.deux { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1rem; }
.depot { display: flex; gap: .5rem; align-items: center; flex-wrap: wrap; }
.cache { display: none; }
.aide { font-size: .8rem; color: var(--p-text-muted-color); margin: .5rem 0; }
.lien { color: var(--p-primary-color); text-decoration: none; font-weight: 500; }
.lien:hover { text-decoration: underline; }
.lien i { margin-right: .25rem; }
.detail { display: block; font-size: .78rem; color: var(--p-text-muted-color); }
.muet { color: var(--p-text-muted-color); }
:deep(.p-card-title) { font-size: 1rem; }
.dp { border: 1px solid var(--p-surface-200); border-radius: 10px; padding: .9rem 1rem; margin-bottom: .9rem; }
.dp-entete { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; margin-bottom: .75rem; }
.titre-dp { font-size: 1rem; font-weight: 600; }
.frise { display: grid; grid-template-columns: repeat(6, 1fr); list-style: none; padding: 0; margin: 0 0 .9rem; }
.frise li { display: flex; flex-direction: column; align-items: center; text-align: center; gap: .3rem; position: relative; }
.frise li:not(:first-child)::before {
  content: ''; position: absolute; top: .8rem; right: 50%; width: 100%; height: 2px;
  background: var(--p-surface-300); z-index: 0;
}
.frise li.faite::before, .frise li.actuelle::before, .frise li.refusee::before { background: var(--p-primary-color); }
.pastille {
  width: 1.65rem; height: 1.65rem; border-radius: 50%; display: grid; place-items: center; z-index: 1;
  font-size: .75rem; font-weight: 600; background: var(--p-surface-0); border: 2px solid var(--p-surface-300);
  color: var(--p-text-muted-color);
}
.faite .pastille { background: var(--p-primary-color); border-color: var(--p-primary-color); color: #fff; }
.actuelle .pastille { border-color: var(--p-primary-color); color: var(--p-primary-color); box-shadow: 0 0 0 4px var(--p-primary-100); }
.refusee .pastille { background: var(--p-red-500); border-color: var(--p-red-500); color: #fff; }
.frise .libelle { font-size: .75rem; color: var(--p-text-muted-color); max-width: 7rem; line-height: 1.2; }
.actuelle .libelle { color: var(--p-text-color); font-weight: 600; }
.historique { margin-top: .9rem; font-size: .85rem; }
.historique summary { cursor: pointer; font-weight: 600; color: var(--p-text-muted-color); }
.historique ul { list-style: none; padding: 0; margin: .5rem 0 0; display: flex; flex-direction: column; gap: .35rem; }
.historique li { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; padding: .35rem .5rem; border-radius: 6px; background: var(--p-surface-50); }
.historique li.retour { background: var(--p-yellow-50); }
.historique li.refus { background: var(--p-red-50); }
.historique .date { color: var(--p-text-muted-color); min-width: 8.5rem; }
.historique .texte { color: var(--p-text-muted-color); font-style: italic; }
.petit { font-size: .7rem; }
:deep(.p-rating-icon) { width: .8rem; height: .8rem; }
@media (max-width: 1000px) { .grille { grid-template-columns: 1fr; } }
</style>
