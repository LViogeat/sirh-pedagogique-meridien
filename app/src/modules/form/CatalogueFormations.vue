<!-- libelle: Catalogue de formations -->
<script setup>
/**
 * Story #9 — Le catalogue de formations, commun à tous les établissements.
 *
 * Le Responsable Formation Groupe y voit la liste complète des formations,
 * peut en ajouter, les modifier, et les retirer du catalogue (une formation
 * retirée n'est pas supprimée : ses sessions passées restent consultables).
 *
 * C'est aussi ici qu'on dit pour quels métiers une formation est obligatoire.
 */
import { ref, computed, onMounted } from 'vue'
import {
  sql, insert, update, getCompetences, getPostes, formatNombre, toast,
} from '@/socle/sdk'
import { preparerSchema, MODALITES, TOUS_LES_METIERS, libelle } from './_donnees'

const formations = ref([])
const competences = ref([])
const familles = ref([])
const chargement = ref(true)

const recherche = ref('')
const domaine = ref(null)
const seulementActives = ref(true)

const fiche = ref(null)          // la formation en cours de saisie, ou null
const enregistrement = ref(false)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    formations.value = await sql(
      `select f.*,
              k.label as competence,
              (select string_agg(o.famille_metier, ', ' order by o.famille_metier)
                 from obligations o where o.formation_id = f.id) as obligatoire_pour,
              (select count(*) from sessions s
                where s.formation_id = f.id and s.statut = 'ouverte') as sessions_ouvertes
       from   formations f
       left join public.skills k on k.id = f.skill_id
       order by f.domaine, f.intitule`,
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  await charger()
  try {
    competences.value = await getCompetences()
    const postes = await getPostes()
    familles.value = [
      TOUS_LES_METIERS,
      ...[...new Set(postes.map((p) => p.job_family))].sort(),
    ]
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

const domaines = computed(() =>
  [...new Set(formations.value.map((f) => f.domaine))].sort())

const visibles = computed(() => {
  const motif = recherche.value.trim().toLowerCase()
  return formations.value.filter((f) =>
    (!seulementActives.value || f.actif) &&
    (!domaine.value || f.domaine === domaine.value) &&
    (!motif || `${f.code} ${f.intitule}`.toLowerCase().includes(motif)))
})

const totaux = computed(() => ({
  actives: formations.value.filter((f) => f.actif).length,
  obligatoires: formations.value.filter((f) => f.actif && f.obligatoire_pour).length,
  domaines: domaines.value.length,
  sessions: formations.value.reduce((t, f) => t + Number(f.sessions_ouvertes), 0),
}))

// ── La fiche : création et modification ──────────────────────────────────────

function nouvelle() {
  fiche.value = {
    id: null, code: '', intitule: '', domaine: '', objectifs: '', programme: '',
    duree_heures: 7, prerequis: '', modalite: 'presentiel', lieu: '',
    periodicite_mois: null, skill_id: null, actif: true, obligations: [],
  }
}

function modifier(formation) {
  fiche.value = {
    ...formation,
    obligations: formation.obligatoire_pour
      ? formation.obligatoire_pour.split(', ')
      : [],
  }
}

function texte(valeur) {
  const propre = (valeur ?? '').trim()
  return propre || null
}

async function enregistrer() {
  const f = fiche.value
  if (!texte(f.code) || !texte(f.intitule) || !texte(f.domaine)) {
    toast.alerte('Le code, l’intitulé et le domaine sont obligatoires.')
    return
  }
  if (!f.duree_heures || f.duree_heures < 1) {
    toast.alerte('La durée doit être d’au moins une heure.')
    return
  }

  const donnees = {
    code: f.code.trim().toUpperCase(),
    intitule: f.intitule.trim(),
    domaine: f.domaine.trim(),
    objectifs: texte(f.objectifs),
    programme: texte(f.programme),
    duree_heures: f.duree_heures,
    prerequis: texte(f.prerequis),
    modalite: f.modalite,
    lieu: texte(f.lieu),
    periodicite_mois: f.periodicite_mois || null,
    skill_id: f.skill_id || null,
    actif: f.actif,
  }

  enregistrement.value = true
  try {
    const ligne = f.id
      ? await update('formations', f.id, donnees)
      : await insert('formations', donnees)

    // Les métiers pour lesquels la formation est obligatoire : on remplace
    // l'ancienne liste par la nouvelle.
    await sql('delete from obligations where formation_id = :id', { id: ligne.id })
    for (const famille of f.obligations) {
      await insert('obligations', { formation_id: ligne.id, famille_metier: famille })
    }

    toast.succes(f.id ? 'Formation modifiée' : 'Formation ajoutée au catalogue')
    fiche.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message.includes('formations_code_key')
      ? `Le code ${donnees.code} est déjà utilisé par une autre formation.`
      : erreur.message)
  } finally {
    enregistrement.value = false
  }
}

async function basculer(formation) {
  try {
    await update('formations', formation.id, { actif: !formation.actif })
    toast.succes(formation.actif
      ? 'Formation retirée du catalogue'
      : 'Formation remise au catalogue')
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Catalogue de formations"
    sousTitre="L’offre de formation du groupe, la même pour les cinq établissements"
  >
    <Button label="Nouvelle formation" icon="pi pi-plus" @click="nouvelle" />
  </PageHeader>

  <div class="stats">
    <StatCard titre="Formations au catalogue" :valeur="totaux.actives" icone="pi pi-book" />
    <StatCard titre="Dont obligatoires" :valeur="totaux.obligatoires" icone="pi pi-shield"
              precision="pour au moins un métier" />
    <StatCard titre="Domaines" :valeur="totaux.domaines" icone="pi pi-tags" />
    <StatCard titre="Sessions ouvertes" :valeur="totaux.sessions" icone="pi pi-calendar" />
  </div>

  <div class="filtres">
    <InputText v-model="recherche" placeholder="Rechercher un intitulé ou un code" />
    <Select v-model="domaine" :options="domaines"
            placeholder="Tous les domaines" showClear />
    <div class="bascule">
      <ToggleSwitch v-model="seulementActives" inputId="actives" />
      <label for="actives">Seulement les formations au catalogue</label>
    </div>
  </div>

  <DataTable :value="visibles" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small" rowHover
             @row-click="(e) => modifier(e.data)">
    <template #empty>Aucune formation ne correspond à ces critères.</template>

    <Column field="code" header="Code" sortable style="width: 10rem" />
    <Column field="intitule" header="Intitulé" sortable />
    <Column field="domaine" header="Domaine" sortable />

    <Column field="duree_heures" header="Durée" sortable style="width: 6rem">
      <template #body="{ data }">{{ formatNombre(data.duree_heures) }} h</template>
    </Column>

    <Column field="modalite" header="Modalité" sortable style="width: 8rem">
      <template #body="{ data }">{{ libelle(MODALITES, data.modalite) }}</template>
    </Column>

    <Column field="obligatoire_pour" header="Obligatoire pour" sortable>
      <template #body="{ data }">
        <Tag v-if="data.obligatoire_pour" severity="warn"
             :value="data.obligatoire_pour === TOUS_LES_METIERS
                       ? 'Tous les métiers' : data.obligatoire_pour" />
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="sessions_ouvertes" header="Sessions ouvertes" sortable style="width: 9rem" />

    <Column field="actif" header="Au catalogue" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="data.actif ? 'Oui' : 'Retirée'"
             :severity="data.actif ? 'success' : 'secondary'" />
      </template>
    </Column>

    <Column style="width: 7rem">
      <template #body="{ data }">
        <Button icon="pi pi-pencil" text rounded aria-label="Modifier"
                v-tooltip.left="'Modifier'" @click.stop="modifier(data)" />
        <Button :icon="data.actif ? 'pi pi-eye-slash' : 'pi pi-eye'" text rounded
                severity="secondary"
                :aria-label="data.actif ? 'Retirer du catalogue' : 'Remettre au catalogue'"
                v-tooltip.left="data.actif ? 'Retirer du catalogue' : 'Remettre au catalogue'"
                @click.stop="basculer(data)" />
      </template>
    </Column>
  </DataTable>

  <!-- La fiche d'une formation : la même pour créer et pour modifier. -->
  <Dialog :visible="!!fiche" modal :style="{ width: '46rem' }"
          :header="fiche?.id ? 'Modifier la formation' : 'Nouvelle formation'"
          @update:visible="fiche = null">
    <div v-if="fiche" class="formulaire">
      <div class="champ court">
        <label for="f-code">Code *</label>
        <InputText id="f-code" v-model="fiche.code" placeholder="HACCP" />
      </div>
      <div class="champ long">
        <label for="f-intitule">Intitulé *</label>
        <InputText id="f-intitule" v-model="fiche.intitule" />
      </div>

      <div class="champ">
        <label for="f-domaine">Domaine *</label>
        <Select inputId="f-domaine" v-model="fiche.domaine" :options="domaines"
                editable placeholder="Choisir ou saisir un domaine" />
      </div>
      <div class="champ">
        <label for="f-modalite">Modalité</label>
        <Select inputId="f-modalite" v-model="fiche.modalite" :options="MODALITES"
                optionLabel="label" optionValue="code" />
      </div>

      <div class="champ">
        <label for="f-duree">Durée (heures) *</label>
        <InputNumber inputId="f-duree" v-model="fiche.duree_heures" :min="1" :max="500" />
      </div>
      <div class="champ">
        <label for="f-lieu">Lieu</label>
        <InputText id="f-lieu" v-model="fiche.lieu"
                   placeholder="Dans chaque établissement, classe virtuelle…" />
      </div>

      <div class="champ large">
        <label for="f-objectifs">Objectifs</label>
        <Textarea id="f-objectifs" v-model="fiche.objectifs" rows="2" autoResize />
      </div>
      <div class="champ large">
        <label for="f-programme">Programme</label>
        <Textarea id="f-programme" v-model="fiche.programme" rows="3" autoResize />
      </div>
      <div class="champ large">
        <label for="f-prerequis">Prérequis</label>
        <InputText id="f-prerequis" v-model="fiche.prerequis" />
      </div>

      <div class="champ">
        <label for="f-competence">Compétence développée</label>
        <Select inputId="f-competence" v-model="fiche.skill_id" :options="competences"
                optionLabel="label" optionValue="id" filter showClear
                placeholder="Aucune en particulier" />
      </div>
      <div class="champ">
        <label for="f-periodicite">À refaire tous les (mois)</label>
        <InputNumber inputId="f-periodicite" v-model="fiche.periodicite_mois"
                     :min="1" :max="240" placeholder="Pas de recyclage" />
      </div>

      <div class="champ large">
        <label for="f-obligations">Obligatoire pour les métiers</label>
        <MultiSelect inputId="f-obligations" v-model="fiche.obligations"
                     :options="familles" display="chip"
                     placeholder="Formation non obligatoire" />
        <small>« {{ TOUS_LES_METIERS }} » rend la formation obligatoire pour tous les postes.</small>
      </div>

      <div class="champ large bascule">
        <ToggleSwitch v-model="fiche.actif" inputId="f-actif" />
        <label for="f-actif">Formation proposée au catalogue</label>
      </div>
    </div>

    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="fiche = null" />
      <Button label="Enregistrer" icon="pi pi-check"
              :loading="enregistrement" @click="enregistrer" />
    </template>
  </Dialog>
</template>

<style scoped>
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-inputtext { min-width: 18rem; }
.filtres > .p-select { min-width: 14rem; }
.bascule { display: flex; align-items: center; gap: .5rem; font-size: .9rem; }

.formulaire { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.champ { display: flex; flex-direction: column; gap: .35rem; min-width: 0; }
.champ.large { grid-column: 1 / -1; }
.champ.bascule { flex-direction: row; align-items: center; }
.champ label { font-size: .85rem; font-weight: 600; }
.champ small { color: var(--p-text-muted-color); }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
