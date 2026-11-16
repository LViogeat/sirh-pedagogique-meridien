<!-- libelle: Indicateurs de réalisation -->
<script setup>
/**
 * Story #67 — Le Responsable Formation Groupe suit les indicateurs de
 * réalisation des formations, pour mesurer le taux de réalisation des plans
 * de formation et les niveaux de participation.
 *
 * Les indicateurs, sur l'année choisie :
 *   Taux de réalisation du plan : sessions terminées / sessions planifiées.
 *   Taux de participation       : présents / participants émargés.
 *   Taux de remplissage         : inscrits / places proposées.
 *   Heures de formation         : durée × réalisations validées par le RH.
 * Ils sont donnés pour le groupe, puis par établissement et par formation.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { sql, formatNombre, toast } from '@/socle/sdk'
import { preparerSchema, telechargerCsv } from './_donnees'

const sessions = ref([])
const salariesFormes = ref(0)
const chargement = ref(true)

const annee = ref(new Date().getFullYear())

async function charger() {
  chargement.value = true
  try {
    await preparerSchema()
    const lignes = await sql(
      `select s.id, s.formation_id, s.establishment_id, s.statut, s.date_debut, s.places,
              f.intitule as formation, f.duree_heures,
              e.name as etablissement,
              count(i.id) filter (where i.statut = 'validee') as inscrits,
              count(i.id) filter (where i.statut = 'validee'
                                    and i.presence = 'present') as presents,
              count(i.id) filter (where i.statut = 'validee'
                                    and i.presence in ('absent', 'absent_justifie')) as absents,
              count(i.id) filter (where i.realisation = 'validee') as realisations
       from   sessions s
       join   formations f on f.id = s.formation_id
       left join public.establishments e on e.id = s.establishment_id
       left join inscriptions i on i.session_id = s.id
       group by s.id, f.intitule, f.duree_heures, e.name
       order by s.date_debut`,
    )
    sessions.value = lignes.map((s) => ({
      ...s,
      annee: Number(String(s.date_debut).slice(0, 4)),
      places: Number(s.places),
      inscrits: Number(s.inscrits),
      presents: Number(s.presents),
      absents: Number(s.absents),
      realisations: Number(s.realisations),
      duree_heures: Number(s.duree_heures),
    }))
    await compterSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

/** Le nombre de salariés différents ayant au moins une réalisation validée. */
async function compterSalaries() {
  const lignes = await sql(
    `select count(distinct i.employee_id) as nombre
     from   inscriptions i
     join   sessions s on s.id = i.session_id
     where  i.realisation = 'validee'
     and    extract(year from s.date_debut) = :annee`,
    { annee: annee.value },
  )
  salariesFormes.value = Number(lignes[0]?.nombre ?? 0)
}

onMounted(charger)

watch(annee, async () => {
  try {
    await compterSalaries()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

const annees = computed(() => {
  const vues = new Set([new Date().getFullYear(), annee.value])
  for (const s of sessions.value) vues.add(s.annee)
  return [...vues].sort()
})

const deLAnnee = computed(() => sessions.value.filter((s) => s.annee === annee.value))

const taux = (numerateur, denominateur) =>
  (denominateur ? Math.round((numerateur / denominateur) * 100) : null)
const enPourcent = (valeur) => (valeur === null ? '—' : `${valeur} %`)

/** Calcule tous les indicateurs pour une liste de sessions. */
function indicateurs(liste) {
  const maintenues = liste.filter((s) => s.statut !== 'annulee')
  const terminees = liste.filter((s) => s.statut === 'terminee')
  const somme = (lignes, champ) => lignes.reduce((t, s) => t + s[champ], 0)
  const presents = somme(maintenues, 'presents')
  const absents = somme(maintenues, 'absents')
  return {
    planifiees: liste.length,
    terminees: terminees.length,
    annulees: liste.length - maintenues.length,
    aVenir: maintenues.length - terminees.length,
    places: somme(maintenues, 'places'),
    inscrits: somme(maintenues, 'inscrits'),
    presents,
    absents,
    realisations: somme(maintenues, 'realisations'),
    heures: maintenues.reduce((t, s) => t + s.realisations * s.duree_heures, 0),
    tauxRealisation: taux(terminees.length, liste.length),
    tauxParticipation: taux(presents, presents + absents),
    tauxRemplissage: taux(somme(maintenues, 'inscrits'), somme(maintenues, 'places')),
  }
}

const groupe = computed(() => indicateurs(deLAnnee.value))

function regrouper(cle, nom) {
  const paquets = new Map()
  for (const s of deLAnnee.value) {
    const paquet = paquets.get(s[cle]) ?? { id: s[cle], nom: s[nom] ?? '—', sessions: [] }
    paquet.sessions.push(s)
    paquets.set(s[cle], paquet)
  }
  return [...paquets.values()]
    .map((p) => ({ id: p.id, nom: p.nom, ...indicateurs(p.sessions) }))
    .sort((a, b) => a.nom.localeCompare(b.nom))
}

const parEtablissement = computed(() => regrouper('establishment_id', 'etablissement'))
const parFormation = computed(() => regrouper('formation_id', 'formation'))

function exporter() {
  const colonnes = (titre) => [
    { titre, champ: 'nom' },
    { titre: 'Sessions planifiées', champ: 'planifiees' },
    { titre: 'Sessions terminées', champ: 'terminees' },
    { titre: 'Sessions annulées', champ: 'annulees' },
    { titre: 'Taux de réalisation (%)', champ: (l) => l.tauxRealisation ?? '' },
    { titre: 'Places', champ: 'places' },
    { titre: 'Inscrits', champ: 'inscrits' },
    { titre: 'Taux de remplissage (%)', champ: (l) => l.tauxRemplissage ?? '' },
    { titre: 'Présents', champ: 'presents' },
    { titre: 'Absents', champ: 'absents' },
    { titre: 'Taux de participation (%)', champ: (l) => l.tauxParticipation ?? '' },
    { titre: 'Réalisations validées', champ: 'realisations' },
    { titre: 'Heures de formation', champ: 'heures' },
  ]
  telechargerCsv(`indicateurs-formation-${annee.value}.csv`, colonnes('Périmètre'), [
    { nom: 'Groupe', ...groupe.value },
    ...parEtablissement.value,
    ...parFormation.value,
  ])
}
</script>

<template>
  <PageHeader
    titre="Indicateurs de réalisation"
    sousTitre="Le plan de formation du groupe : ce qui est réalisé, et la participation"
  >
    <Button label="Exporter" icon="pi pi-download" severity="secondary" outlined
            :disabled="!deLAnnee.length" @click="exporter" />
  </PageHeader>

  <div class="filtres">
    <label for="i-annee">Année</label>
    <Select inputId="i-annee" v-model="annee" :options="annees" />
  </div>

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <template v-else>
    <div class="stats">
      <StatCard titre="Taux de réalisation du plan" :valeur="enPourcent(groupe.tauxRealisation)"
                icone="pi pi-chart-line"
                :precision="`${groupe.terminees} session(s) terminée(s) sur ${groupe.planifiees} planifiée(s)`" />
      <StatCard titre="Taux de participation" :valeur="enPourcent(groupe.tauxParticipation)"
                icone="pi pi-users"
                :precision="`${groupe.presents} présent(s) · ${groupe.absents} absent(s)`" />
      <StatCard titre="Taux de remplissage" :valeur="enPourcent(groupe.tauxRemplissage)"
                icone="pi pi-th-large"
                :precision="`${groupe.inscrits} inscrit(s) pour ${groupe.places} place(s)`" />
      <StatCard titre="Heures de formation réalisées" :valeur="formatNombre(groupe.heures)"
                icone="pi pi-clock"
                :precision="`${groupe.realisations} réalisation(s) validée(s)`" />
      <StatCard titre="Salariés formés" :valeur="salariesFormes" icone="pi pi-verified"
                precision="au moins une formation validée" />
      <StatCard titre="Sessions à venir" :valeur="groupe.aVenir" icone="pi pi-calendar"
                :precision="`${groupe.annulees} annulée(s)`" />
    </div>

    <Message v-if="!deLAnnee.length" severity="info" :closable="false">
      Aucune session de formation n’est planifiée pour {{ annee }}.
    </Message>

    <template v-else>
      <h3>Par établissement</h3>
      <DataTable :value="parEtablissement" dataKey="id" size="small" stripedRows removableSort>
        <Column field="nom" header="Établissement" sortable />
        <Column field="planifiees" header="Planifiées" sortable style="width: 7rem" />
        <Column field="terminees" header="Terminées" sortable style="width: 7rem" />
        <Column field="annulees" header="Annulées" sortable style="width: 7rem" />
        <Column field="tauxRealisation" header="Réalisation du plan" sortable style="width: 14rem">
          <template #body="{ data }">
            <div class="jauge">
              <span class="piste"><span class="plein"
                                        :style="{ width: `${data.tauxRealisation ?? 0}%` }" /></span>
              <span class="taux">{{ enPourcent(data.tauxRealisation) }}</span>
            </div>
          </template>
        </Column>
        <Column field="inscrits" header="Inscrits" sortable style="width: 7rem" />
        <Column field="tauxRemplissage" header="Remplissage" sortable style="width: 8rem">
          <template #body="{ data }">{{ enPourcent(data.tauxRemplissage) }}</template>
        </Column>
        <Column field="tauxParticipation" header="Participation" sortable style="width: 14rem">
          <template #body="{ data }">
            <div class="jauge">
              <span class="piste"><span class="plein vert"
                                        :style="{ width: `${data.tauxParticipation ?? 0}%` }" /></span>
              <span class="taux">{{ enPourcent(data.tauxParticipation) }}</span>
            </div>
          </template>
        </Column>
        <Column field="heures" header="Heures réalisées" sortable style="width: 9rem">
          <template #body="{ data }">{{ formatNombre(data.heures) }}</template>
        </Column>
      </DataTable>

      <h3>Par formation</h3>
      <DataTable :value="parFormation" dataKey="id" size="small" stripedRows removableSort
                 paginator :rows="15">
        <Column field="nom" header="Formation" sortable />
        <Column field="planifiees" header="Planifiées" sortable style="width: 7rem" />
        <Column field="terminees" header="Terminées" sortable style="width: 7rem" />
        <Column field="tauxRealisation" header="Réalisation du plan" sortable style="width: 10rem">
          <template #body="{ data }">{{ enPourcent(data.tauxRealisation) }}</template>
        </Column>
        <Column field="inscrits" header="Inscrits" sortable style="width: 7rem" />
        <Column field="presents" header="Présents" sortable style="width: 7rem" />
        <Column field="absents" header="Absents" sortable style="width: 7rem" />
        <Column field="tauxParticipation" header="Participation" sortable style="width: 9rem">
          <template #body="{ data }">{{ enPourcent(data.tauxParticipation) }}</template>
        </Column>
        <Column field="realisations" header="Réalisations validées" sortable style="width: 11rem" />
      </DataTable>
    </template>
  </template>
</template>

<style scoped>
.filtres { display: flex; gap: .75rem; align-items: center; margin-bottom: 1rem; }
.filtres label { font-size: .85rem; font-weight: 600; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
h3 { font-size: 1rem; margin: 1.5rem 0 .6rem; }
.jauge { display: flex; align-items: center; gap: .5rem; }
.piste { flex: 1; background: var(--p-surface-200); border-radius: 6px; height: .7rem; overflow: hidden; }
.plein { display: block; height: 100%; background: var(--p-primary-color); }
.plein.vert { background: var(--p-green-500); }
.taux { width: 3.2rem; text-align: right; font-size: .85rem; }
</style>
