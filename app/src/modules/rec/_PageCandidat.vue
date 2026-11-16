<script setup>
/**
 * La page d'un candidat (story #105).
 *
 * On y arrive en cliquant sur un nom dans l'écran « Candidats » ou sur une
 * carte du Pipeline. Elle rassemble les coordonnées, toutes les candidatures
 * (et l'étape de chacune), les entretiens et les pièces jointes.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getEtablissements, sql, update, remove, formatDate, toast } from '@/socle/sdk'
import {
  TYPES_DOCUMENT, libelleType, formatTaille, verifierFichier,
  ajouterPiece, listerPieces, ouvrirPiece, telechargerPiece,
} from './_fichiers.js'

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
const ETAPES = {
  nouvelle: { label: 'Nouvelle', severite: 'secondary' },
  preselection: { label: 'Présélection', severite: 'info' },
  entretien: { label: 'Entretien', severite: 'info' },
  proposition: { label: 'Proposition', severite: 'warn' },
  embauche: { label: 'Embauche', severite: 'success' },
  refus: { label: 'Refus', severite: 'danger' },
}
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
        `select ca.id, ca.etape, ca.note, ca.recue_le, ca.maj_le,
                o.id as offre_id, o.intitule, o.statut as statut_offre, o.establishment_id
           from candidatures ca join offres o on o.id = ca.offre_id
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

      <!-- Candidatures -->
      <Card class="large">
        <template #title>Candidatures</template>
        <template #content>
          <DataTable :value="candidatures" dataKey="id" size="small">
            <template #empty>Ce candidat n'est positionné sur aucune offre.</template>
            <Column header="Offre">
              <template #body="{ data }">
                <a href="#" class="lien" @click.prevent="router.push({ path: '/rec/pipeline', query: { offre: data.offre_id } })">
                  {{ data.intitule }}
                </a>
              </template>
            </Column>
            <Column header="Hôtel">
              <template #body="{ data }">{{ hotelCourt(data.establishment_id) }}</template>
            </Column>
            <Column header="Étape" style="width: 9rem">
              <template #body="{ data }">
                <Tag :value="ETAPES[data.etape]?.label" :severity="ETAPES[data.etape]?.severite" />
              </template>
            </Column>
            <Column header="Note" style="width: 8rem">
              <template #body="{ data }">
                <Rating v-if="data.note" :modelValue="data.note" readonly :stars="5" />
                <span v-else class="muet">—</span>
              </template>
            </Column>
            <Column header="Reçue le" style="width: 7rem">
              <template #body="{ data }">{{ formatDate(data.recue_le) }}</template>
            </Column>
            <Column header="Dernier mouvement" style="width: 9rem">
              <template #body="{ data }">{{ formatDate(data.maj_le) }}</template>
            </Column>
          </DataTable>
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
:deep(.p-rating-icon) { width: .8rem; height: .8rem; }
@media (max-width: 1000px) { .grille { grid-template-columns: 1fr; } }
</style>
