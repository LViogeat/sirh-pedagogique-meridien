<!-- libelle: Candidats -->
<script setup>
/**
 * Le vivier de candidats et leur positionnement sur les offres (story #6).
 *
 * - « Nouveau candidat » enregistre une personne dans le vivier.
 * - « Positionner » crée une candidature sur une offre PUBLIÉE, à l'étape
 *   « nouvelle ». La table interdit les doublons (un candidat, une offre).
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { sql, insert, formatDate, toast } from '@/socle/sdk'
import { assurerSchema } from './_schema.js'

const router = useRouter()

const SOURCES = ['Spontanée', 'Indeed', 'LinkedIn', 'France Travail', 'Site carrière', 'Cooptation', 'École / alternance']

const candidats = ref([])
const offresPubliees = ref([])
const chargement = ref(true)
const recherche = ref('')

async function charger() {
  chargement.value = true
  try {
    ;[candidats.value, offresPubliees.value] = await Promise.all([
      sql(
        `select c.*,
                count(ca.id)::int as nb_candidatures,
                coalesce(json_agg(json_build_object('id', o.id, 'intitule', o.intitule) order by ca.id)
                         filter (where o.id is not null), '[]') as offres
           from candidats c
           left join candidatures ca on ca.candidat_id = c.id
           left join offres o on o.id = ca.offre_id
          where :q = '' or c.nom ilike :motif or c.prenom ilike :motif or c.email ilike :motif
          group by c.id
          order by c.id desc`,
        { q: recherche.value.trim(), motif: `%${recherche.value.trim()}%` },
      ),
      sql("select id, intitule from offres where statut = 'publiee' order by id"),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
    candidats.value = []
  } finally {
    chargement.value = false
  }
}

onMounted(async () => { await assurerSchema(); await charger() })

let minuterie = null
watch(recherche, () => {
  clearTimeout(minuterie)
  minuterie = setTimeout(charger, 300)
})

const nbPositionnes = computed(() => candidats.value.filter((c) => c.nb_candidatures > 0).length)

/* ── Nouveau candidat ───────────────────────────────────────────────────── */

const nouveau = ref(null)
const enregistrement = ref(false)

function ouvrirNouveau() {
  nouveau.value = { prenom: '', nom: '', email: '', telephone: '', source: 'Spontanée' }
}

async function creer() {
  const c = nouveau.value
  if (!c.prenom.trim() || !c.nom.trim()) {
    toast.alerte('Le prénom et le nom sont obligatoires.')
    return
  }
  enregistrement.value = true
  try {
    const cree = await insert('candidats', {
      prenom: c.prenom.trim(),
      nom: c.nom.trim(),
      email: c.email.trim() || null,
      telephone: c.telephone.trim() || null,
      source: c.source || 'Spontanée',
    })
    toast.succes(`${cree.prenom} ${cree.nom} ajouté(e) au vivier`)
    nouveau.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}

/* ── Positionner sur une offre ──────────────────────────────────────────── */

const positionnement = ref(null) // { candidat, offreId }

function ouvrirPositionnement(candidat) {
  positionnement.value = { candidat, offreId: offresPubliees.value[0]?.id ?? null }
}

async function positionner() {
  const { candidat, offreId } = positionnement.value
  if (!offreId) {
    toast.alerte('Choisissez une offre.')
    return
  }
  enregistrement.value = true
  try {
    await insert('candidatures', { offre_id: offreId, candidat_id: candidat.id })
    const offre = offresPubliees.value.find((o) => o.id === offreId)
    toast.succes(`${candidat.prenom} ${candidat.nom} positionné(e) sur « ${offre?.intitule} »`)
    positionnement.value = null
    await charger()
  } catch (erreur) {
    if (/duplicate|unique|existe déjà/i.test(erreur.message)) {
      toast.erreur(`${candidat.prenom} ${candidat.nom} est déjà positionné(e) sur cette offre.`)
    } else {
      toast.erreur(erreur.message)
    }
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <PageHeader
    titre="Candidats"
    :sousTitre="`${candidats.length} candidat(s) dans le vivier · ${nbPositionnes} positionné(s) sur une offre`"
  />

  <div class="barre">
    <IconField>
      <InputIcon class="pi pi-search" />
      <InputText v-model="recherche" placeholder="Rechercher un nom ou un e-mail" />
    </IconField>
    <Button label="Nouveau candidat" icon="pi pi-user-plus" @click="ouvrirNouveau" />
  </div>

  <DataTable :value="candidats" :loading="chargement" dataKey="id"
             paginator :rows="20" removableSort stripedRows size="small">
    <template #empty>Aucun candidat. Ajoutez-en un avec « Nouveau candidat ».</template>

    <Column header="Candidat" sortField="nom" sortable>
      <template #body="{ data }">
        <a href="#" class="nom" @click.prevent="router.push(`/rec/candidat/${data.id}`)">
          {{ data.prenom }} {{ data.nom }}
        </a>
        <span class="detail">{{ [data.email, data.telephone].filter(Boolean).join(' · ') || '—' }}</span>
      </template>
    </Column>

    <Column field="source" header="Source" sortable style="width: 10rem" />

    <Column field="cree_le" header="Ajouté le" sortable style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.cree_le) }}</template>
    </Column>

    <Column field="nb_candidatures" header="Offres" sortable>
      <template #body="{ data }">
        <span v-if="data.nb_candidatures" class="offres">
          <template v-for="(o, i) in data.offres" :key="o.id">
            <span v-if="i" class="separateur"> · </span>
            <a href="#" class="offre" @click.prevent="router.push(`/rec/offre/${o.id}`)">{{ o.intitule }}</a>
          </template>
        </span>
        <span v-else class="muet">Aucune</span>
      </template>
    </Column>

    <Column header="Action" style="width: 11rem">
      <template #body="{ data }">
        <Button label="Positionner" icon="pi pi-briefcase" size="small" outlined
                :disabled="!offresPubliees.length"
                v-tooltip.top="offresPubliees.length ? null : 'Aucune offre publiée'"
                @click="ouvrirPositionnement(data)" />
      </template>
    </Column>
  </DataTable>

  <!-- Nouveau candidat -->
  <Dialog :visible="!!nouveau" modal header="Nouveau candidat" :style="{ width: '32rem' }"
          @update:visible="nouveau = null">
    <form v-if="nouveau" class="formulaire" @submit.prevent="creer">
      <div class="deux">
        <div>
          <label for="prenom">Prénom</label>
          <InputText id="prenom" v-model="nouveau.prenom" fluid />
        </div>
        <div>
          <label for="nom">Nom</label>
          <InputText id="nom" v-model="nouveau.nom" fluid />
        </div>
      </div>
      <label for="email">E-mail</label>
      <InputText id="email" v-model="nouveau.email" type="email" />
      <label for="telephone">Téléphone</label>
      <InputText id="telephone" v-model="nouveau.telephone" />
      <label for="source">Source</label>
      <Select inputId="source" v-model="nouveau.source" :options="SOURCES" editable />
      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="nouveau = null" />
        <Button label="Ajouter au vivier" icon="pi pi-check" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>

  <!-- Positionner sur une offre publiée -->
  <Dialog :visible="!!positionnement" modal :style="{ width: '32rem' }"
          :header="positionnement ? `Positionner ${positionnement.candidat.prenom} ${positionnement.candidat.nom}` : ''"
          @update:visible="positionnement = null">
    <form v-if="positionnement" class="formulaire" @submit.prevent="positionner">
      <label for="offre">Offre publiée</label>
      <Select inputId="offre" v-model="positionnement.offreId" :options="offresPubliees"
              optionLabel="intitule" optionValue="id" placeholder="Choisir une offre" />
      <p class="aide">La candidature démarre à l'étape « Candidature externe reçue » ; elle se suit ensuite sur la page du candidat et dans le Pipeline.</p>
      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="positionnement = null" />
        <Button label="Positionner" icon="pi pi-check" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.barre { display: flex; justify-content: space-between; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.barre :deep(input) { min-width: 18rem; }
.nom { font-weight: 600; color: var(--p-primary-color); text-decoration: none; }
.nom:hover { text-decoration: underline; }
.offre { color: var(--p-primary-color); text-decoration: none; }
.offre:hover { text-decoration: underline; }
.separateur { color: var(--p-text-muted-color); }
.detail { display: block; font-size: .8rem; color: var(--p-text-muted-color); }
.muet { color: var(--p-text-muted-color); }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; display: block; margin-bottom: .3rem; }
.deux { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: .5rem 0 0; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
