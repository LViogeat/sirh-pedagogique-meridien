<!-- libelle: Formations obligatoires de mon équipe -->
<script setup>
/**
 * Deux stories du manager sur le même écran :
 *
 *   #42 — consulter les formations obligatoires à réaliser par les
 *         collaborateurs de son équipe ;
 *   #58 — identifier ceux qui ne les ont pas réalisées, pour régulariser.
 *
 * Le manager choisit son nom. Il voit une ligne par collaborateur et par
 * formation obligatoire, avec la situation de chacun. Le bouton « Non
 * réalisées » ne garde que ce qui reste à faire, et le bloc du haut liste
 * les collaborateurs à régulariser.
 */
import { ref, computed } from 'vue'
import { getSalaries, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, chargerSuiviObligations, ETATS_OBLIGATION, DELAI_INITIAL_MOIS,
  libelle, couleur, salarieCourantId,
} from './_donnees'
import ChoixSalarie from './_ChoixSalarie.vue'

const manager = ref(null)
const equipe = ref([])
const lignes = ref([])
const chargement = ref(false)

const VUES = [
  { code: 'toutes', label: 'Toutes les formations obligatoires' },
  { code: 'non_realisees', label: 'Non réalisées' },
]
const vue = ref('toutes')
const collaborateurId = ref(null)

async function charger() {
  lignes.value = []
  equipe.value = []
  collaborateurId.value = null
  if (!manager.value) return
  chargement.value = true
  try {
    await preparerSchema()
    equipe.value = await getSalaries({ managerId: manager.value.id })
    lignes.value = await chargerSuiviObligations(equipe.value)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

async function changerManager(s) {
  manager.value = s
  await charger()
}

const visibles = computed(() =>
  lignes.value
    .filter((l) =>
      (vue.value === 'toutes' || l.etat !== 'a_jour') &&
      (!collaborateurId.value || l.employee_id === collaborateurId.value))
    .sort((a, b) =>
      Number(b.en_retard) - Number(a.en_retard) ||
      a.salarie.localeCompare(b.salarie) ||
      a.formation.localeCompare(b.formation)))

/** Les collaborateurs qui ont au moins une formation obligatoire non réalisée. */
const aRegulariser = computed(() => {
  const parSalarie = new Map()
  for (const l of lignes.value) {
    if (l.etat === 'a_jour') continue
    const s = parSalarie.get(l.employee_id) ?? {
      id: l.employee_id, salarie: l.salarie, poste: l.poste, manquantes: 0, enRetard: 0,
    }
    s.manquantes += 1
    if (l.en_retard) s.enRetard += 1
    parSalarie.set(l.employee_id, s)
  }
  return [...parSalarie.values()].sort((a, b) =>
    b.enRetard - a.enRetard || b.manquantes - a.manquantes)
})

const totaux = computed(() => {
  const total = lignes.value.length
  const aJour = lignes.value.filter((l) => l.etat === 'a_jour').length
  return {
    total,
    aJour,
    nonRealisees: total - aJour,
    enRetard: lignes.value.filter((l) => l.en_retard).length,
    taux: total ? Math.round((aJour / total) * 100) : null,
  }
})

function voirCollaborateur(id) {
  collaborateurId.value = collaborateurId.value === id ? null : id
  vue.value = 'non_realisees'
}
</script>

<template>
  <PageHeader
    titre="Formations obligatoires de mon équipe"
    sousTitre="Ce que chaque membre de mon équipe doit suivre, et où il en est"
  />

  <ChoixSalarie managers libelle="Je suis le manager" @change="changerManager" />

  <Message v-if="!manager" severity="info" :closable="false">
    Choisissez votre nom dans la liste des managers pour voir votre équipe.
    <template v-if="salarieCourantId"> Le salarié choisi sur un autre écran n’encadre personne.</template>
  </Message>

  <template v-else>
    <div class="stats">
      <StatCard titre="Mon équipe" :valeur="equipe.length" icone="pi pi-users"
                precision="collaborateur(s)" />
      <StatCard titre="Formations à jour" :valeur="totaux.taux === null ? '—' : `${totaux.taux} %`"
                icone="pi pi-check-circle" :precision="`${totaux.aJour} sur ${totaux.total}`" />
      <StatCard titre="Non réalisées" :valeur="totaux.nonRealisees" icone="pi pi-exclamation-circle" />
      <StatCard titre="Hors délai" :valeur="totaux.enRetard" icone="pi pi-clock"
                precision="échéance dépassée" />
    </div>

    <Card v-if="aRegulariser.length" class="bloc">
      <template #title>Collaborateurs à régulariser</template>
      <template #content>
        <div class="personnes">
          <Button v-for="s in aRegulariser" :key="s.id" size="small"
                  :severity="s.enRetard ? 'danger' : 'warn'"
                  :outlined="collaborateurId !== s.id"
                  :label="`${s.salarie} · ${s.manquantes} formation(s)`"
                  @click="voirCollaborateur(s.id)" />
        </div>
        <p class="note">
          En rouge : au moins une formation dont l’échéance est dépassée.
          Cliquez sur un nom pour ne voir que ses formations.
        </p>
      </template>
    </Card>

    <Message v-else-if="!chargement && lignes.length" severity="success" :closable="false" class="bloc">
      Toute votre équipe est à jour de ses formations obligatoires.
    </Message>

    <div class="filtres">
      <SelectButton v-model="vue" :options="VUES" optionLabel="label" optionValue="code"
                    :allowEmpty="false" />
      <Select v-model="collaborateurId" :options="equipe"
              optionLabel="full_name" optionValue="id"
              placeholder="Toute l’équipe" showClear />
    </div>

    <DataTable :value="visibles" :loading="chargement" dataKey="cle"
               paginator :rows="25" stripedRows size="small" removableSort>
      <template #empty>
        {{ vue === 'toutes'
          ? 'Aucune formation obligatoire ne concerne votre équipe.'
          : 'Aucune formation obligatoire non réalisée.' }}
      </template>

      <Column field="salarie" header="Collaborateur" sortable />
      <Column field="poste" header="Poste" sortable />
      <Column field="formation" header="Formation obligatoire" sortable />

      <Column field="etat" header="Situation" sortable style="width: 15rem">
        <template #body="{ data }">
          <Tag :value="libelle(ETATS_OBLIGATION, data.etat)"
               :severity="couleur(ETATS_OBLIGATION, data.etat)" />
        </template>
      </Column>

      <Column field="realisee_le" header="Dernière réalisation" sortable style="width: 11rem">
        <template #body="{ data }">{{ formatDate(data.realisee_le) }}</template>
      </Column>

      <Column field="echeance" header="Échéance" sortable style="width: 11rem">
        <template #body="{ data }">
          <span :class="{ retard: data.en_retard }">{{ formatDate(data.echeance) }}</span>
          <Tag v-if="data.en_retard" value="Dépassée" severity="danger" class="marge" />
          <Tag v-else-if="data.bientot" value="Bientôt" severity="warn" class="marge" />
        </template>
      </Column>

      <Column field="prochaine_session" header="Session prévue" sortable style="width: 10rem">
        <template #body="{ data }">{{ formatDate(data.prochaine_session) }}</template>
      </Column>
    </DataTable>

    <p class="note">
      Une formation jamais suivie doit être faite dans les {{ DELAI_INITIAL_MOIS }} mois
      après l’arrivée du collaborateur. Une formation à recycler doit être refaite avant
      la fin de sa période de validité. Elle compte comme réalisée une fois validée par le RH.
    </p>
  </template>
</template>

<style scoped>
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.bloc { margin-bottom: 1.25rem; }
.personnes { display: flex; gap: .5rem; flex-wrap: wrap; }
.filtres { display: flex; gap: 1rem; flex-wrap: wrap; align-items: center; margin-bottom: 1rem; }
.filtres > .p-select { min-width: 15rem; }
.note { color: var(--p-text-muted-color); font-size: .85rem; margin: .75rem 0 0; }
.retard { color: var(--p-red-500); font-weight: 600; }
.marge { margin-left: .4rem; }
</style>
