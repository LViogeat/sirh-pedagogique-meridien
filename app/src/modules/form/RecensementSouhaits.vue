<!-- libelle: Recensement des souhaits -->
<script setup>
/**
 * Story #28 — Le Responsable RH d'établissement extrait les souhaits de
 * formation recensés lors des entretiens annuels, avec le nom des
 * collaborateurs et les formations demandées, pour chercher et proposer des
 * sessions dans l'année.
 *
 * Un tableau de bord : les chiffres en haut, les formations les plus
 * demandées en barres, puis la liste nominative, exportable vers Excel.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, getSalaries, getEtablissements, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, STATUTS_SOUHAIT, ORIGINES_SOUHAIT, PRIORITES, AVIS_MANAGER,
  libelle, couleur, telechargerCsv, etablissementCourantId,
} from './_donnees'

const etablissements = ref([])
const salaries = ref([])
const souhaits = ref([])
const chargement = ref(true)

const origine = ref('entretien_annuel')
const statut = ref(null)
const formationId = ref(null)

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    salaries.value = await getSalaries({ etablissementId: etablissementCourantId.value })
    souhaits.value = await sql(
      `select w.*,
              f.intitule as formation, f.domaine, f.duree_heures,
              (select count(*) from sessions s
                where s.formation_id = f.id and s.statut = 'ouverte') as sessions_ouvertes
       from   souhaits w
       join   formations f on f.id = w.formation_id
       order by w.cree_le desc, w.id desc`,
    )
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    etablissements.value = await getEtablissements()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
  await charger()
})

watch(etablissementCourantId, charger)

/** Les souhaits des salariés de l'établissement, avec leur nom et leur poste. */
const lignes = computed(() => {
  const parId = new Map(salaries.value.map((s) => [s.id, s]))
  return souhaits.value
    .filter((w) => parId.has(w.employee_id))
    .map((w) => {
      const s = parId.get(w.employee_id)
      return {
        ...w,
        salarie: s.full_name,
        matricule: s.matricule,
        poste: s.position_title ?? '—',
        departement: s.department_label ?? '—',
        etablissement: s.establishment_name ?? '—',
        manager: s.manager_name ?? '—',
        sessions_ouvertes: Number(w.sessions_ouvertes),
      }
    })
})

const visibles = computed(() =>
  lignes.value.filter((w) =>
    (!origine.value || w.origine === origine.value) &&
    (statut.value ? w.statut === statut.value : w.statut !== 'ecarte') &&
    (!formationId.value || w.formation_id === formationId.value)))

/** Les formations demandées, de la plus demandée à la moins demandée. */
const parFormation = computed(() => {
  const compte = new Map()
  for (const w of visibles.value) {
    const ligne = compte.get(w.formation_id) ?? {
      id: w.formation_id, formation: w.formation, nombre: 0,
      sessions_ouvertes: w.sessions_ouvertes,
    }
    ligne.nombre += 1
    compte.set(w.formation_id, ligne)
  }
  const liste = [...compte.values()].sort((a, b) => b.nombre - a.nombre)
  const maximum = liste[0]?.nombre ?? 1
  return liste.map((l) => ({ ...l, largeur: `${Math.round((l.nombre / maximum) * 100)}%` }))
})

const formations = computed(() => {
  const vues = new Map()
  for (const w of lignes.value) vues.set(w.formation_id, w.formation)
  return [...vues].map(([id, intitule]) => ({ id, intitule }))
    .sort((a, b) => a.intitule.localeCompare(b.intitule))
})

const totaux = computed(() => ({
  souhaits: visibles.value.length,
  collaborateurs: new Set(visibles.value.map((w) => w.employee_id)).size,
  formations: parFormation.value.length,
  sansSession: parFormation.value.filter((f) => f.sessions_ouvertes === 0).length,
}))

function exporter() {
  telechargerCsv('souhaits-de-formation.csv', [
    { titre: 'Établissement', champ: 'etablissement' },
    { titre: 'Collaborateur', champ: 'salarie' },
    { titre: 'Matricule', champ: 'matricule' },
    { titre: 'Poste', champ: 'poste' },
    { titre: 'Département', champ: 'departement' },
    { titre: 'Manager', champ: 'manager' },
    { titre: 'Formation demandée', champ: 'formation' },
    { titre: 'Domaine', champ: 'domaine' },
    { titre: 'Exprimé', champ: (w) => libelle(ORIGINES_SOUHAIT, w.origine) },
    { titre: 'Date', champ: (w) => formatDate(w.cree_le) },
    { titre: 'Motivation', champ: (w) => w.motivation ?? '' },
    { titre: 'Priorité', champ: (w) => (w.priorite ? libelle(PRIORITES, w.priorite) : '') },
    { titre: 'Avis du manager', champ: (w) => (w.avis_manager ? libelle(AVIS_MANAGER, w.avis_manager) : '') },
    { titre: 'Commentaire du manager', champ: (w) => w.commentaire_manager ?? '' },
    { titre: 'Statut', champ: (w) => libelle(STATUTS_SOUHAIT, w.statut) },
    { titre: 'Sessions ouvertes', champ: 'sessions_ouvertes' },
  ], visibles.value)
}
</script>

<template>
  <PageHeader
    titre="Recensement des souhaits de formation"
    sousTitre="Qui demande quelle formation dans mon établissement"
  >
    <Button label="Extraire vers Excel" icon="pi pi-download"
            :disabled="!visibles.length" @click="exporter" />
  </PageHeader>

  <div class="filtres">
    <Select v-model="etablissementCourantId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
    <Select v-model="origine" :options="ORIGINES_SOUHAIT"
            optionLabel="label" optionValue="code"
            placeholder="Entretiens et demandes en cours d’année" showClear />
    <Select v-model="statut" :options="STATUTS_SOUHAIT"
            optionLabel="label" optionValue="code"
            placeholder="Exprimés et transmis" showClear />
    <Select v-model="formationId" :options="formations"
            optionLabel="intitule" optionValue="id"
            placeholder="Toutes les formations" showClear />
  </div>

  <div class="stats">
    <StatCard titre="Souhaits recensés" :valeur="totaux.souhaits" icone="pi pi-heart" />
    <StatCard titre="Collaborateurs" :valeur="totaux.collaborateurs" icone="pi pi-users"
              precision="ont exprimé au moins un souhait" />
    <StatCard titre="Formations demandées" :valeur="totaux.formations" icone="pi pi-book" />
    <StatCard titre="Sans session ouverte" :valeur="totaux.sansSession" icone="pi pi-calendar-times"
              precision="formation(s) demandée(s) à planifier" />
  </div>

  <Card v-if="parFormation.length" class="bloc">
    <template #title>Les formations les plus demandées</template>
    <template #content>
      <div v-for="f in parFormation" :key="f.id" class="barre"
           @click="formationId = formationId === f.id ? null : f.id">
        <span class="nom">{{ f.formation }}</span>
        <span class="piste"><span class="plein" :style="{ width: f.largeur }" /></span>
        <span class="nombre">{{ f.nombre }}</span>
        <Tag :severity="f.sessions_ouvertes > 0 ? 'success' : 'warn'"
             :value="f.sessions_ouvertes > 0
                       ? `${f.sessions_ouvertes} session(s) ouverte(s)`
                       : 'Aucune session ouverte'" />
      </div>
    </template>
  </Card>

  <DataTable :value="visibles" :loading="chargement" dataKey="id"
             paginator :rows="25" removableSort stripedRows size="small">
    <template #empty>Aucun souhait de formation ne correspond à ces critères.</template>

    <Column field="salarie" header="Collaborateur" sortable />
    <Column field="poste" header="Poste" sortable />
    <Column field="formation" header="Formation demandée" sortable />

    <Column field="origine" header="Exprimé" sortable style="width: 10rem">
      <template #body="{ data }">{{ libelle(ORIGINES_SOUHAIT, data.origine) }}</template>
    </Column>

    <Column field="cree_le" header="Le" sortable style="width: 7rem">
      <template #body="{ data }">{{ formatDate(data.cree_le) }}</template>
    </Column>

    <Column field="priorite" header="Priorité" sortable style="width: 7rem">
      <template #body="{ data }">
        <Tag v-if="data.priorite" :value="libelle(PRIORITES, data.priorite)"
             :severity="couleur(PRIORITES, data.priorite)" />
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="avis_manager" header="Avis du manager" sortable style="width: 10rem">
      <template #body="{ data }">
        <span v-if="data.avis_manager" v-tooltip.top="data.commentaire_manager || null">
          {{ libelle(AVIS_MANAGER, data.avis_manager) }}
        </span>
        <span v-else>—</span>
      </template>
    </Column>

    <Column field="statut" header="Statut" sortable style="width: 14rem">
      <template #body="{ data }">
        <Tag :value="libelle(STATUTS_SOUHAIT, data.statut)"
             :severity="couleur(STATUTS_SOUHAIT, data.statut)" />
      </template>
    </Column>

    <Column field="sessions_ouvertes" header="Sessions ouvertes" sortable style="width: 9rem" />
  </DataTable>
</template>

<style scoped>
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 15rem; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.bloc { margin-bottom: 1.25rem; }
.barre {
  display: grid; grid-template-columns: 20rem 1fr 2.5rem 13rem;
  gap: .75rem; align-items: center; padding: .3rem 0; cursor: pointer;
}
.nom { font-size: .9rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.piste { background: var(--p-surface-200); border-radius: 6px; height: .8rem; overflow: hidden; }
.plein { display: block; height: 100%; background: var(--p-primary-color); border-radius: 6px; }
.nombre { font-weight: 600; text-align: right; }
</style>
