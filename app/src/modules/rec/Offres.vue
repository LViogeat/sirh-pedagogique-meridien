<!-- libelle: Offres d'emploi -->
<script setup>
/**
 * Les offres d'emploi du module (story #5).
 *
 * Une offre naît en brouillon depuis l'écran « Besoins à traiter », ou avec
 * « Nouvelle offre ». Un clic sur une offre ouvre sa page DP (story #147), où
 * l'on complète tous ses détails. Ici, on peut aussi la publier ou l'annuler. Annuler une offre relâche son besoin dans le socle : il redevient
 * disponible et pourra être repris.
 *
 * « Nouvelle offre » (story #104) crée une offre de toutes pièces, sur n'importe
 * quel poste : la description est pré-remplie avec les compétences attendues
 * du poste, et le rattachement à un besoin ouvert est facultatif.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import {
  getEtablissements, getReferentiels, getPostes, getPoste, getBesoins,
  prendreEnChargeBesoin, relacherBesoin,
  sql, insert, update, formatDate, toast,
} from '@/socle/sdk'

const router = useRouter()
const offres = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)
const statut = ref(null)

const STATUTS = [
  { code: 'brouillon', label: 'Brouillon', severite: 'secondary' },
  { code: 'publiee', label: 'Publiée', severite: 'success' },
  { code: 'pourvue', label: 'Pourvue', severite: 'info' },
  { code: 'annulee', label: 'Annulée', severite: 'danger' },
]
const statutDe = (code) => STATUTS.find((s) => s.code === code) || { label: code, severite: 'secondary' }

async function charger() {
  chargement.value = true
  try {
    offres.value = await sql(
      `select o.*, count(c.id)::int as nb_candidatures
         from offres o
         left join candidatures c on c.offre_id = o.id
        where (cast(:statut as text) is null or o.statut = :statut)
        group by o.id
        order by o.id desc`,
      { statut: statut.value },
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
    offres.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    ;[etablissements.value, referentiels.value] = await Promise.all([
      getEtablissements(),
      getReferentiels(),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch(statut, charger)

const hotelDe = computed(() => Object.fromEntries(etablissements.value.map((e) => [e.id, e])))
const libelleContrat = (code) =>
  (referentiels.value.type_contrat || []).find((t) => t.code === code)?.label || code

const compteurs = computed(() => ({
  brouillons: offres.value.filter((o) => o.statut === 'brouillon').length,
  publiees: offres.value.filter((o) => o.statut === 'publiee').length,
  pourvues: offres.value.filter((o) => o.statut === 'pourvue').length,
}))

const enregistrement = ref(false)

/* ── Nouvelle offre (story #104) ───────────────────────────────────────── */

const creation = ref(null)
const postesHotel = ref([])
const posteDetail = ref(null)
const besoinsPoste = ref([])

const hotelCourt = (nom) => (nom || '').replace(/^Sorbonne-Hôtel\s+/, '')
const NIVEAUX = { 1: 'notions', 2: 'opérationnel', 3: 'confirmé', 4: 'expert' }

function ouvrirCreation() {
  creation.value = {
    etablissementId: null, posteId: null, typeContrat: 'CDI',
    intitule: '', description: '', besoinId: null,
  }
  postesHotel.value = []
  posteDetail.value = null
  besoinsPoste.value = []
}

watch(() => creation.value?.etablissementId, async (id) => {
  if (!creation.value) return
  creation.value.posteId = null
  posteDetail.value = null
  besoinsPoste.value = []
  postesHotel.value = []
  if (!id) return
  try {
    postesHotel.value = (await getPostes({ etablissementId: id }))
      .sort((a, b) => a.title.localeCompare(b.title))
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

watch(() => creation.value?.posteId, async (id) => {
  if (!creation.value) return
  posteDetail.value = null
  besoinsPoste.value = []
  creation.value.besoinId = null
  if (!id) return
  try {
    const [poste, besoins] = await Promise.all([
      getPoste(id),
      getBesoins({ typeBesoin: 'recrutement', statut: 'ouvert', posteId: id }),
    ])
    posteDetail.value = poste
    besoinsPoste.value = besoins
    creation.value.intitule = `${poste.title} — ${hotelCourt(poste.establishment_name)}`
    creation.value.description = descriptionDe(poste)
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

function descriptionDe(poste) {
  const lignes = [
    `${poste.establishment_name} (${poste.establishment_city}) recrute un(e) ${poste.title} ` +
    `pour son département ${poste.department_label}.`,
  ]
  if (poste.required_skills?.length) {
    lignes.push('', 'Compétences attendues :')
    for (const c of poste.required_skills) {
      lignes.push(`- ${c.skill_label} : niveau ${c.required_level} sur 4 (${NIVEAUX[c.required_level]})`)
    }
  }
  lignes.push('', 'Missions, horaires et rémunération : à compléter.')
  return lignes.join('\n')
}

const libelleBesoin = (b) => `n° ${b.id} · priorité ${b.priority_label.toLowerCase()} · ${b.origin}`

async function creer() {
  const c = creation.value
  if (!c.posteId || !c.intitule.trim()) {
    toast.alerte("Choisissez un hôtel et un poste, et vérifiez l'intitulé.")
    return
  }
  enregistrement.value = true
  let besoinPris = false
  try {
    if (c.besoinId) {
      await prendreEnChargeBesoin(c.besoinId, 'Offre créée depuis « Nouvelle offre »')
      besoinPris = true
    }
    const offre = await insert('offres', {
      besoin_id: c.besoinId || null,
      position_id: c.posteId,
      establishment_id: c.etablissementId,
      intitule: c.intitule.trim(),
      type_contrat: c.typeContrat,
      description: c.description.trim() || null,
    })
    toast.succes(`Offre n° ${offre.id} créée en brouillon : ${offre.intitule}`)
    creation.value = null
    router.push(`/rec/offre/${offre.id}`)
  } catch (erreur) {
    if (besoinPris) await relacherBesoin(c.besoinId).catch(() => {})
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/* ── Changer le statut ──────────────────────────────────────────────────── */

const enCours = ref(null)

async function publier(offre) {
  enCours.value = offre.id
  try {
    await sql(
      "update offres set statut = 'publiee', publiee_le = current_date where id = :id",
      { id: offre.id },
    )
    toast.succes(`Offre n° ${offre.id} publiée`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}

async function annuler(offre) {
  enCours.value = offre.id
  try {
    await update('offres', offre.id, { statut: 'annulee' })
    if (offre.besoin_id) {
      await relacherBesoin(offre.besoin_id)
    }
    toast.info(`Offre n° ${offre.id} annulée. Le besoin redevient disponible.`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enCours.value = null
  }
}
</script>

<template>
  <PageHeader
    titre="Offres d'emploi"
    :sousTitre="`${offres.length} offre(s) · ${compteurs.publiees} publiée(s)`"
  />

  <div class="stats">
    <StatCard titre="Brouillons" :valeur="compteurs.brouillons" icone="pi pi-pencil" precision="à compléter et publier" />
    <StatCard titre="Publiées" :valeur="compteurs.publiees" icone="pi pi-megaphone" precision="ouvertes aux candidatures" />
    <StatCard titre="Pourvues" :valeur="compteurs.pourvues" icone="pi pi-check-circle" precision="recrutement abouti" />
  </div>

  <div class="filtres">
    <Select v-model="statut" :options="STATUTS"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />
    <Button label="Nouvelle offre" icon="pi pi-plus" class="nouvelle" @click="ouvrirCreation" />
  </div>

  <DataTable :value="offres" :loading="chargement" dataKey="id"
             paginator :rows="20" removableSort stripedRows size="small" rowHover
             @row-click="(e) => router.push(`/rec/offre/${e.data.id}`)">
    <template #empty>
      Aucune offre. Créez-en une avec « Nouvelle offre », ou en prenant en charge un besoin
      dans l'écran « Besoins à traiter ».
    </template>

    <Column field="id" header="N°" sortable style="width: 4rem" />
    <Column field="intitule" header="Intitulé" sortable>
      <template #body="{ data }"><span class="lien">{{ data.intitule }}</span></template>
    </Column>

    <Column header="Établissement">
      <template #body="{ data }">
        {{ hotelDe[data.establishment_id]?.name || '—' }}
        <span class="ville">{{ hotelDe[data.establishment_id]?.city }}</span>
      </template>
    </Column>

    <Column field="type_contrat" header="Contrat" sortable style="width: 9rem">
      <template #body="{ data }">{{ libelleContrat(data.type_contrat) }}</template>
    </Column>

    <Column field="besoin_id" header="Besoin" style="width: 6rem">
      <template #body="{ data }">{{ data.besoin_id ? `n° ${data.besoin_id}` : '—' }}</template>
    </Column>

    <Column field="statut" header="Statut" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="statutDe(data.statut).label" :severity="statutDe(data.statut).severite" />
      </template>
    </Column>

    <Column field="publiee_le" header="Publiée le" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.publiee_le) }}</template>
    </Column>

    <Column field="nb_candidatures" header="Candidatures" sortable style="width: 8rem" />

    <Column header="Actions" style="width: 15rem">
      <template #body="{ data }">
        <div class="actions" @click.stop>
          <Button v-if="data.statut === 'brouillon'" label="Publier" icon="pi pi-send"
                  size="small" :loading="enCours === data.id" :disabled="enCours !== null"
                  @click="publier(data)" />
          <Button v-if="['brouillon', 'publiee'].includes(data.statut)" label="Annuler"
                  icon="pi pi-times" size="small" severity="secondary" text
                  :disabled="enCours !== null" @click="annuler(data)" />
        </div>
      </template>
    </Column>
  </DataTable>

  <!-- Nouvelle offre (story #104) -->
  <Dialog :visible="!!creation" modal header="Nouvelle offre d'emploi" :style="{ width: '44rem' }"
          @update:visible="creation = null">
    <form v-if="creation" class="formulaire" @submit.prevent="creer">
      <div class="deux">
        <div>
          <label for="hotel">Hôtel</label>
          <Select inputId="hotel" v-model="creation.etablissementId" :options="etablissements"
                  optionLabel="name" optionValue="id" placeholder="Choisir un hôtel" fluid />
        </div>
        <div>
          <label for="poste">Poste</label>
          <Select inputId="poste" v-model="creation.posteId" :options="postesHotel"
                  optionLabel="title" optionValue="id" filter
                  :placeholder="creation.etablissementId ? 'Choisir un poste' : 'Choisir d’abord un hôtel'"
                  :disabled="!creation.etablissementId" fluid />
        </div>
      </div>

      <p v-if="posteDetail" class="aide">
        Département {{ posteDetail.department_label }} · effectif {{ posteDetail.current_headcount }}
        sur {{ posteDetail.target_headcount }} · {{ posteDetail.required_skills.length }} compétence(s) attendue(s)
      </p>

      <div class="deux">
        <div>
          <label for="nouveau-contrat">Type de contrat</label>
          <Select inputId="nouveau-contrat" v-model="creation.typeContrat"
                  :options="referentiels.type_contrat" optionLabel="label" optionValue="code" fluid />
        </div>
        <div>
          <label for="besoin">Besoin rattaché (facultatif)</label>
          <Select inputId="besoin" v-model="creation.besoinId" :options="besoinsPoste"
                  :optionLabel="libelleBesoin" optionValue="id" showClear fluid
                  :placeholder="besoinsPoste.length ? 'Aucun' : 'Aucun besoin ouvert sur ce poste'"
                  :disabled="!besoinsPoste.length" />
        </div>
      </div>

      <label for="nouvel-intitule">Intitulé</label>
      <InputText id="nouvel-intitule" v-model="creation.intitule" />

      <label for="nouvelle-description">Description du poste</label>
      <Textarea id="nouvelle-description" v-model="creation.description" rows="9" autoResize />

      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="creation = null" />
        <Button label="Créer l'offre" icon="pi pi-check" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
.ville { display: block; font-size: .8rem; color: var(--p-text-muted-color); }
.actions { display: flex; gap: .25rem; }
.nouvelle { margin-left: auto; }
.lien { color: var(--p-primary-color); font-weight: 500; }
.deux { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.deux label { display: block; margin-bottom: .3rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: .4rem 0 0; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
