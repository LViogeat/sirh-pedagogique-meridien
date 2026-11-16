<script setup>
/**
 * La page d'une DP — demande de poste, ou offre d'emploi (story #147).
 *
 * Deux parties :
 *   1. les candidats, en colonnes du workflow de recrutement (_KanbanCandidatures) ;
 *   2. les détails du poste : description, recruteur et manager recruteur,
 *      localisation (déduite de l'hôtel), conditions du job, compétences
 *      attendues (socle). Tout se modifie ici, avec « Modifier ».
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getEtablissements, getPoste, getSalaries, getReferentiels, relacherBesoin,
  sql, update, formatDate, formatNombre, toast,
} from '@/socle/sdk'
import { localisationDe } from './_localisation.js'
import KanbanCandidatures from './_KanbanCandidatures.vue'

const route = useRoute()
const router = useRouter()
const offreId = computed(() => Number(route.params.id))

const offre = ref(null)
const hotel = ref(null)
const poste = ref(null)
const salariesHotel = ref([])
const chargesRh = ref([])
const contrats = ref([])
const chargement = ref(true)

const STATUTS = {
  brouillon: { label: 'Brouillon', severite: 'secondary' },
  publiee: { label: 'Publiée', severite: 'success' },
  pourvue: { label: 'Pourvue', severite: 'info' },
  annulee: { label: 'Annulée', severite: 'danger' },
}
const NIVEAUX = { 1: 'Notions', 2: 'Opérationnel', 3: 'Confirmé', 4: 'Expert' }

async function charger() {
  if (!Number.isInteger(offreId.value) || offreId.value <= 0) {
    chargement.value = false
    return
  }
  chargement.value = true
  try {
    const [[ligne], etabs, refs, tous] = await Promise.all([
      sql('select * from offres where id = :id', { id: offreId.value }),
      getEtablissements(),
      getReferentiels(),
      getSalaries(),
    ])
    offre.value = ligne || null
    contrats.value = refs.type_contrat || []
    chargesRh.value = tous.filter((s) => /chargé\s+rh/i.test(s.position_title || ''))
    if (!ligne) return
    hotel.value = etabs.find((e) => e.id === ligne.establishment_id) || null
    salariesHotel.value = tous
      .filter((s) => s.establishment_id === ligne.establishment_id)
      .sort((a, b) => (b.hierarchy_level ?? 0) - (a.hierarchy_level ?? 0) || a.last_name.localeCompare(b.last_name))
    poste.value = await getPoste(ligne.position_id)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)
watch(offreId, () => { edition.value = null; charger() })

const localisation = computed(() => localisationDe(hotel.value))

/* Le manager proposé : le responsable du département du poste. */
const managerPropose = computed(() => {
  if (!poste.value) return null
  return salariesHotel.value
    .filter((s) => s.department_id === poste.value.department_id)
    .sort((a, b) => (b.hierarchy_level ?? 0) - (a.hierarchy_level ?? 0))[0] || null
})
const manager = computed(() => {
  if (offre.value?.manager_id) {
    const s = salariesHotel.value.find((x) => x.id === offre.value.manager_id)
    return { nom: offre.value.manager_nom, poste: s?.position_title, propose: false }
  }
  return managerPropose.value
    ? { nom: managerPropose.value.full_name, poste: managerPropose.value.position_title, propose: true }
    : null
})
const recruteurPoste = computed(() =>
  chargesRh.value.find((s) => s.id === offre.value?.recruteur_id)?.position_title || 'Chargé RH')

const libelleContrat = (code) => contrats.value.find((t) => t.code === code)?.label || code
const k = (v) => (v === null || v === undefined ? null : formatNombre(Number(v), Number(v) % 1 ? 1 : 0))
const remuneration = computed(() => {
  const o = offre.value
  if (!o || (o.salaire_min_k == null && o.salaire_max_k == null)) return null
  if (o.salaire_min_k != null && o.salaire_max_k != null && Number(o.salaire_min_k) !== Number(o.salaire_max_k)) {
    return `${k(o.salaire_min_k)} – ${k(o.salaire_max_k)} k€ brut annuel`
  }
  return `${k(o.salaire_min_k ?? o.salaire_max_k)} k€ brut annuel`
})
const tempsTravail = computed(() =>
  offre.value?.temps_travail === 'temps_partiel'
    ? `Temps partiel (${offre.value.quotite} %)` : 'Temps plein')

/* ── Modifier les détails ───────────────────────────────────────────────── */

const edition = ref(null)
const enregistrement = ref(false)
const TEMPS = [
  { code: 'temps_plein', label: 'Temps plein' },
  { code: 'temps_partiel', label: 'Temps partiel' },
]
const libelleSalarie = (s) => `${s.full_name} · ${s.position_title || '—'}`

function modifier() {
  const o = offre.value
  edition.value = {
    intitule: o.intitule,
    description: o.description || '',
    recruteur_id: o.recruteur_id,
    manager_id: o.manager_id ?? managerPropose.value?.id ?? null,
    type_contrat: o.type_contrat,
    temps_travail: o.temps_travail || 'temps_plein',
    quotite: o.quotite ?? 80,
    salaire_min_k: o.salaire_min_k != null ? Number(o.salaire_min_k) : null,
    salaire_max_k: o.salaire_max_k != null ? Number(o.salaire_max_k) : null,
    date_prise_poste: o.date_prise_poste ? new Date(`${o.date_prise_poste}T00:00:00`) : null,
    nb_postes: o.nb_postes ?? 1,
  }
}

function enDate(d) {
  if (!(d instanceof Date)) return null
  const z = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${z(d.getMonth() + 1)}-${z(d.getDate())}`
}

async function enregistrer() {
  const e = edition.value
  if (!e.intitule?.trim()) return toast.alerte("L'intitulé est obligatoire.")
  if (e.temps_travail === 'temps_partiel' && !(e.quotite >= 10 && e.quotite <= 99)) {
    return toast.alerte('Pour un temps partiel, la quotité doit être comprise entre 10 et 99 %.')
  }
  if (e.salaire_min_k != null && e.salaire_max_k != null && e.salaire_min_k > e.salaire_max_k) {
    return toast.alerte('Le salaire minimum doit être inférieur ou égal au salaire maximum.')
  }
  if (!(e.nb_postes >= 1)) return toast.alerte('Il faut au moins 1 poste à pourvoir.')

  const recruteur = chargesRh.value.find((s) => s.id === e.recruteur_id)
  const mgr = salariesHotel.value.find((s) => s.id === e.manager_id)
  enregistrement.value = true
  try {
    await update('offres', offre.value.id, {
      intitule: e.intitule.trim(),
      description: e.description.trim() || null,
      recruteur_id: recruteur?.id ?? null,
      recruteur_nom: recruteur?.full_name ?? null,
      manager_id: mgr?.id ?? null,
      manager_nom: mgr?.full_name ?? null,
      type_contrat: e.type_contrat,
      temps_travail: e.temps_travail,
      quotite: e.temps_travail === 'temps_partiel' ? e.quotite : null,
      salaire_min_k: e.salaire_min_k,
      salaire_max_k: e.salaire_max_k,
      date_prise_poste: enDate(e.date_prise_poste),
      nb_postes: e.nb_postes,
    })
    toast.succes('Détails du poste enregistrés')
    edition.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/* ── Statut de l'offre ──────────────────────────────────────────────────── */

const enCours = ref(false)

async function publier() {
  enCours.value = true
  try {
    await sql("update offres set statut = 'publiee', publiee_le = current_date where id = :id", { id: offre.value.id })
    toast.succes(`DP n° ${offre.value.id} publiée`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}

const confirmationAnnulation = ref(false)

async function annuler() {
  enCours.value = true
  try {
    await update('offres', offre.value.id, { statut: 'annulee' })
    if (offre.value.besoin_id) await relacherBesoin(offre.value.besoin_id)
    toast.info(`DP n° ${offre.value.id} annulée${offre.value.besoin_id ? ' : le besoin redevient disponible' : ''}.`)
    confirmationAnnulation.value = false
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = false
  }
}
</script>

<template>
  <div class="retour">
    <Button label="Retour aux offres" icon="pi pi-arrow-left" text size="small"
            @click="router.push('/rec/offres')" />
  </div>

  <div v-if="chargement && !offre" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!offre" severity="info" :closable="false">
    Aucune DP à afficher. Ouvrez une offre en cliquant dessus dans l'écran « Offres d'emploi » ou « Pipeline ».
  </Message>

  <template v-else>
    <div class="entete">
      <PageHeader :titre="offre.intitule"
                  :sousTitre="`DP n° ${offre.id} · ${hotel?.name || ''} · créée le ${formatDate(offre.creee_le)}${offre.publiee_le ? ` · publiée le ${formatDate(offre.publiee_le)}` : ''}`" />
      <div class="actions-offre">
        <Tag :value="STATUTS[offre.statut].label" :severity="STATUTS[offre.statut].severite" />
        <Button v-if="offre.statut === 'brouillon'" label="Publier" icon="pi pi-send" size="small"
                :loading="enCours" @click="publier" />
        <Button v-if="['brouillon', 'publiee'].includes(offre.statut)" label="Annuler la DP" icon="pi pi-times"
                size="small" severity="secondary" text @click="confirmationAnnulation = true" />
      </div>
    </div>

    <!-- Partie 1 : les candidats par étape du workflow -->
    <Card>
      <template #title>Candidats par étape du workflow</template>
      <template #content>
        <Message v-if="offre.statut === 'brouillon'" severity="secondary" :closable="false" size="small" class="info">
          DP en brouillon : publiez-la pour qu'elle apparaisse sur la page carrière et reçoive des candidatures.
        </Message>
        <KanbanCandidatures :offreId="offre.id" :close="offre.statut !== 'publiee'" @change="charger" />
      </template>
    </Card>

    <!-- Partie 2 : les détails du poste -->
    <Card class="bloc">
      <template #title>
        <div class="titre-carte">
          <span>Détails du poste</span>
          <Button v-if="!edition" label="Modifier" icon="pi pi-pencil" size="small" outlined
                  :disabled="offre.statut === 'annulee'" @click="modifier" />
        </div>
      </template>
      <template #content>
        <!-- Lecture -->
        <div v-if="!edition" class="details">
          <section class="zone large">
            <h3>Description</h3>
            <p class="description">{{ offre.description || 'Aucune description. Cliquez sur « Modifier » pour la rédiger.' }}</p>
          </section>

          <section class="zone">
            <h3>Recrutement</h3>
            <dl>
              <dt>Recruteur</dt>
              <dd>
                <template v-if="offre.recruteur_nom">{{ offre.recruteur_nom }} <span class="muet">· {{ recruteurPoste }}</span></template>
                <span v-else class="muet">À désigner</span>
              </dd>
              <dt>Manager recruteur</dt>
              <dd>
                <template v-if="manager">
                  {{ manager.nom }} <span class="muet">· {{ manager.poste }}</span>
                  <Tag v-if="manager.propose" value="proposé" severity="secondary" class="petit" />
                </template>
                <span v-else class="muet">À désigner</span>
              </dd>
            </dl>
          </section>

          <section class="zone">
            <h3>Localisation</h3>
            <dl v-if="localisation">
              <dt>Pays</dt><dd>{{ localisation.pays }}</dd>
              <dt>Région</dt><dd>{{ localisation.region }}</dd>
              <dt>Ville</dt><dd>{{ localisation.ville }}</dd>
              <dt>Adresse</dt><dd>{{ localisation.adresse }}, {{ localisation.codePostal }} {{ localisation.ville }}</dd>
            </dl>
          </section>

          <section class="zone">
            <h3>Le job</h3>
            <dl>
              <dt>Département</dt><dd>{{ poste?.department_label || '—' }}</dd>
              <dt>Contrat</dt><dd>{{ libelleContrat(offre.type_contrat) }}</dd>
              <dt>Temps de travail</dt><dd>{{ tempsTravail }}</dd>
              <dt>Rémunération</dt><dd>{{ remuneration || '—' }}</dd>
              <dt>Prise de poste</dt><dd>{{ offre.date_prise_poste ? formatDate(offre.date_prise_poste, 'long') : '—' }}</dd>
              <dt>Nombre de postes</dt><dd>{{ offre.nb_postes }}</dd>
            </dl>
          </section>

          <section class="zone">
            <h3>Compétences attendues</h3>
            <p v-if="!poste?.required_skills?.length" class="muet">Aucune compétence définie pour ce poste dans le socle.</p>
            <ul v-else class="competences">
              <li v-for="s in poste.required_skills" :key="s.skill_id">
                <span>{{ s.skill_label }}</span>
                <span class="niveau">
                  <Rating :modelValue="s.required_level" :stars="4" readonly />
                  {{ NIVEAUX[s.required_level] }}
                </span>
              </li>
            </ul>
          </section>
        </div>

        <!-- Modification -->
        <form v-else class="formulaire" @submit.prevent="enregistrer">
          <label for="d-intitule">Intitulé</label>
          <InputText id="d-intitule" v-model="edition.intitule" />

          <label for="d-description">Description</label>
          <Textarea id="d-description" v-model="edition.description" rows="8" autoResize />

          <div class="deux">
            <div>
              <label for="d-recruteur">Recruteur (Chargé RH)</label>
              <Select inputId="d-recruteur" v-model="edition.recruteur_id" :options="chargesRh"
                      :optionLabel="libelleSalarie" optionValue="id" showClear fluid placeholder="À désigner" />
            </div>
            <div>
              <label for="d-manager">Manager recruteur</label>
              <Select inputId="d-manager" v-model="edition.manager_id" :options="salariesHotel"
                      :optionLabel="libelleSalarie" optionValue="id" filter showClear fluid placeholder="À désigner" />
            </div>
          </div>

          <div class="trois">
            <div>
              <label for="d-contrat">Type de contrat</label>
              <Select inputId="d-contrat" v-model="edition.type_contrat" :options="contrats"
                      optionLabel="label" optionValue="code" fluid />
            </div>
            <div>
              <label>Temps de travail</label>
              <SelectButton v-model="edition.temps_travail" :options="TEMPS" optionLabel="label" optionValue="code"
                            :allowEmpty="false" />
            </div>
            <div v-if="edition.temps_travail === 'temps_partiel'">
              <label for="d-quotite">Quotité</label>
              <InputNumber inputId="d-quotite" v-model="edition.quotite" suffix=" %" :min="10" :max="99" fluid />
            </div>
          </div>

          <div class="trois">
            <div>
              <label for="d-min">Salaire minimum</label>
              <InputNumber inputId="d-min" v-model="edition.salaire_min_k" suffix=" k€" :min="0" :max="999"
                           :minFractionDigits="0" :maxFractionDigits="1" locale="fr-FR" fluid placeholder="ex. 24 k€" />
            </div>
            <div>
              <label for="d-max">Salaire maximum</label>
              <InputNumber inputId="d-max" v-model="edition.salaire_max_k" suffix=" k€" :min="0" :max="999"
                           :minFractionDigits="0" :maxFractionDigits="1" locale="fr-FR" fluid placeholder="ex. 27 k€" />
            </div>
            <div>
              <label for="d-postes">Nombre de postes</label>
              <InputNumber inputId="d-postes" v-model="edition.nb_postes" :min="1" :max="99" showButtons fluid />
            </div>
          </div>
          <p class="aide">Rémunération en k€ brut annuel.</p>

          <label for="d-date">Date de prise de poste souhaitée</label>
          <DatePicker inputId="d-date" v-model="edition.date_prise_poste" dateFormat="dd/mm/yy" showIcon
                      showButtonBar placeholder="jj/mm/aaaa" class="date" />

          <p class="aide">
            <i class="pi pi-map-marker" /> Localisation déduite de l'hôtel :
            {{ localisation?.pays }} · {{ localisation?.region }} · {{ localisation?.ville }}
          </p>

          <div class="pied">
            <Button label="Annuler" severity="secondary" text type="button" @click="edition = null" />
            <Button label="Enregistrer" icon="pi pi-check" type="submit" :loading="enregistrement" />
          </div>
        </form>
      </template>
    </Card>

    <Dialog :visible="confirmationAnnulation" modal header="Annuler la DP" :style="{ width: '30rem' }"
            @update:visible="confirmationAnnulation = false">
      <p>Annuler la DP « {{ offre.intitule }} » ? Elle disparaîtra de la page carrière.</p>
      <p v-if="offre.besoin_id" class="aide">Le besoin n° {{ offre.besoin_id }} redeviendra disponible dans le socle.</p>
      <div class="pied">
        <Button label="Garder la DP" severity="secondary" text @click="confirmationAnnulation = false" />
        <Button label="Annuler la DP" icon="pi pi-times" severity="danger" :loading="enCours" @click="annuler" />
      </div>
    </Dialog>
  </template>
</template>

<style scoped>
.retour { margin: -.5rem 0 .5rem -.75rem; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.entete { display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; }
.actions-offre { display: flex; align-items: center; gap: .5rem; padding-top: .4rem; }
.info { margin-bottom: .75rem; }
.bloc { margin-top: 1rem; }
.titre-carte { display: flex; justify-content: space-between; align-items: center; }
.details { display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem 2rem; }
.zone.large { grid-column: 1 / -1; }
.zone h3 { font-size: .8rem; text-transform: uppercase; letter-spacing: .04em; color: var(--p-text-muted-color); margin: 0 0 .5rem; }
.description { white-space: pre-line; line-height: 1.5; margin: 0; }
dl { display: grid; grid-template-columns: 9.5rem 1fr; gap: .4rem .75rem; margin: 0; font-size: .92rem; }
dt { color: var(--p-text-muted-color); }
dd { margin: 0; }
.competences { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: .4rem; font-size: .92rem; }
.competences li { display: flex; justify-content: space-between; gap: 1rem; }
.niveau { display: flex; align-items: center; gap: .5rem; color: var(--p-text-muted-color); font-size: .8rem; }
.niveau :deep(.p-rating-icon) { width: .8rem; height: .8rem; }
.petit { font-size: .7rem; margin-left: .35rem; }
.muet { color: var(--p-text-muted-color); }
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; display: block; margin-bottom: .25rem; }
.deux { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.trois { display: grid; grid-template-columns: repeat(3, 1fr); gap: .75rem; align-items: end; }
.date { max-width: 14rem; }
.aide { font-size: .82rem; color: var(--p-text-muted-color); margin: .4rem 0 0; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-card-title) { font-size: 1rem; }
@media (max-width: 1000px) { .details { grid-template-columns: 1fr; } }
</style>
