<!-- libelle: Mes formations obligatoires -->
<script setup>
/**
 * Story #35 — Le collaborateur consulte les formations obligatoires
 * associées à son poste, pour savoir ce qu'il doit réaliser.
 *
 * Les obligations sont définies dans le catalogue, par famille de métier
 * (Cuisine, Restauration, Technique…) ou pour tous les postes. On prend la
 * famille de métier du poste du salarié choisi, et on montre pour chaque
 * formation où il en est : à faire, inscrit, ou réalisée.
 */
import { ref, computed } from 'vue'
import { sql, formatDate, formatNombre, toast } from '@/socle/sdk'
import {
  preparerSchema, MODALITES, TOUS_LES_METIERS, libelle, enDate, salarieCourantId,
} from './_donnees'
import ChoixSalarie from './_ChoixSalarie.vue'

const salarie = ref(null)
const formations = ref([])
const chargement = ref(false)
const formationOuverte = ref(null)

async function charger() {
  if (!salarie.value) {
    formations.value = []
    return
  }
  chargement.value = true
  try {
    await preparerSchema()
    const lignes = await sql(
      `select f.id, f.code, f.intitule, f.domaine, f.objectifs, f.programme,
              f.duree_heures, f.modalite, f.lieu, f.prerequis, f.periodicite_mois,
              string_agg(o.famille_metier, ', ' order by o.famille_metier) as perimetre,
              (select max(s.date_fin)
                 from inscriptions i
                 join sessions s on s.id = i.session_id
                where s.formation_id = f.id
                  and i.employee_id = :salarie
                  and i.presence = 'present') as realisee_le,
              (select min(s.date_debut)
                 from inscriptions i
                 join sessions s on s.id = i.session_id
                where s.formation_id = f.id
                  and i.employee_id = :salarie
                  and i.statut = 'validee'
                  and i.presence is null
                  and s.statut in ('ouverte', 'fermee')) as inscrit_le,
              (select min(s.date_debut)
                 from inscriptions i
                 join sessions s on s.id = i.session_id
                where s.formation_id = f.id
                  and i.employee_id = :salarie
                  and i.statut = 'demandee'
                  and s.statut in ('ouverte', 'fermee')) as demandee_le,
              (select count(*) from sessions s
                where s.formation_id = f.id and s.statut = 'ouverte') as sessions_ouvertes
       from   formations f
       join   obligations o on o.formation_id = f.id
       where  f.actif
       and    o.famille_metier in (:famille, :tous)
       group by f.id
       order by f.intitule`,
      {
        salarie: salarie.value.id,
        famille: salarie.value.job_family ?? '',
        tous: TOUS_LES_METIERS,
      },
    )
    formations.value = lignes.map((f) => ({ ...f, ...situation(f) }))
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

/**
 * Où en est le salarié sur une formation obligatoire.
 * Si la formation est à refaire tous les N mois, on calcule la date limite
 * à partir de la dernière réalisation.
 */
function situation(f) {
  let aRefaireLe = null
  if (f.realisee_le && f.periodicite_mois) {
    aRefaireLe = enDate(f.realisee_le)
    aRefaireLe.setMonth(aRefaireLe.getMonth() + Number(f.periodicite_mois))
  }
  const perimee = aRefaireLe && aRefaireLe < new Date()

  if (f.realisee_le && !perimee) {
    return { etat: 'Réalisée', severite: 'success', ordre: 3, a_refaire_le: aRefaireLe }
  }
  if (f.inscrit_le) {
    return { etat: 'Inscrit', severite: 'info', ordre: 2, a_refaire_le: aRefaireLe }
  }
  if (f.demandee_le) {
    return { etat: 'Demande en attente', severite: 'warn', ordre: 1, a_refaire_le: aRefaireLe }
  }
  return {
    etat: perimee ? 'À renouveler' : 'À faire',
    severite: 'danger', ordre: 0, a_refaire_le: aRefaireLe,
  }
}

async function changerSalarie(s) {
  salarie.value = s
  await charger()
}

const triees = computed(() =>
  [...formations.value].sort((a, b) => a.ordre - b.ordre || a.intitule.localeCompare(b.intitule)))

const totaux = computed(() => ({
  total: formations.value.length,
  realisees: formations.value.filter((f) => f.ordre === 3).length,
  enCours: formations.value.filter((f) => f.ordre === 1 || f.ordre === 2).length,
  aFaire: formations.value.filter((f) => f.ordre === 0).length,
}))

function detail(f) {
  if (f.ordre === 3) {
    return f.a_refaire_le
      ? `Le ${formatDate(f.realisee_le)} · à refaire avant le ${formatDate(f.a_refaire_le)}`
      : `Le ${formatDate(f.realisee_le)}`
  }
  if (f.ordre === 2) return `Session du ${formatDate(f.inscrit_le)}`
  if (f.ordre === 1) return `Session du ${formatDate(f.demandee_le)}`
  if (f.realisee_le) return `Dernière réalisation le ${formatDate(f.realisee_le)}`
  return Number(f.sessions_ouvertes) > 0
    ? `${f.sessions_ouvertes} session(s) ouverte(s) aux inscriptions`
    : 'Pas de session ouverte pour l’instant'
}
</script>

<template>
  <PageHeader
    titre="Mes formations obligatoires"
    :sousTitre="salarie
      ? `${salarie.full_name} · ${salarie.position_title ?? 'sans poste'} · famille de métier ${salarie.job_family ?? '—'}`
      : 'Les formations que je dois réaliser sur mon poste'"
  />

  <ChoixSalarie @change="changerSalarie" />

  <Message v-if="!salarieCourantId" severity="info" :closable="false">
    Choisissez votre nom dans la liste pour voir les formations obligatoires de votre poste.
  </Message>

  <template v-else>
    <div class="stats">
      <StatCard titre="Formations obligatoires" :valeur="totaux.total" icone="pi pi-shield"
                precision="sur mon poste" />
      <StatCard titre="Réalisées" :valeur="totaux.realisees" icone="pi pi-check-circle" />
      <StatCard titre="Inscription en cours" :valeur="totaux.enCours" icone="pi pi-calendar" />
      <StatCard titre="À faire" :valeur="totaux.aFaire" icone="pi pi-exclamation-triangle" />
    </div>

    <DataTable :value="triees" :loading="chargement" dataKey="id"
               stripedRows size="small" rowHover
               @row-click="(e) => (formationOuverte = e.data)">
      <template #empty>
        Aucune formation obligatoire n’est associée à votre poste.
      </template>

      <Column field="intitule" header="Formation" />
      <Column field="domaine" header="Domaine" />

      <Column header="Durée" style="width: 6rem">
        <template #body="{ data }">{{ formatNombre(data.duree_heures) }} h</template>
      </Column>

      <Column header="Obligatoire pour">
        <template #body="{ data }">
          {{ data.perimetre === TOUS_LES_METIERS ? 'Tous les métiers' : `Métiers : ${data.perimetre}` }}
        </template>
      </Column>

      <Column header="Recyclage" style="width: 9rem">
        <template #body="{ data }">
          {{ data.periodicite_mois ? `Tous les ${data.periodicite_mois} mois` : '—' }}
        </template>
      </Column>

      <Column header="Ma situation" style="width: 11rem">
        <template #body="{ data }">
          <Tag :value="data.etat" :severity="data.severite" />
        </template>
      </Column>

      <Column header="Détail">
        <template #body="{ data }">
          <span class="discret">{{ detail(data) }}</span>
        </template>
      </Column>
    </DataTable>

    <p class="note">
      Pour vous inscrire à une session, passez par l’écran « Formations et inscription ».
    </p>
  </template>

  <Dialog :visible="!!formationOuverte" modal :style="{ width: '40rem' }"
          :header="formationOuverte?.intitule" @update:visible="formationOuverte = null">
    <template v-if="formationOuverte">
      <p class="chapo">
        {{ formationOuverte.domaine }} · {{ formatNombre(formationOuverte.duree_heures) }} heures ·
        {{ libelle(MODALITES, formationOuverte.modalite) }}
      </p>
      <dl class="descriptif">
        <dt>Ma situation</dt>
        <dd>
          <Tag :value="formationOuverte.etat" :severity="formationOuverte.severite" />
          <span class="discret"> {{ detail(formationOuverte) }}</span>
        </dd>
        <dt>Objectifs</dt>
        <dd>{{ formationOuverte.objectifs || 'Non renseigné' }}</dd>
        <dt>Programme</dt>
        <dd>{{ formationOuverte.programme || 'Non renseigné' }}</dd>
        <dt>Prérequis</dt>
        <dd>{{ formationOuverte.prerequis || 'Aucun' }}</dd>
        <dt>Lieu</dt>
        <dd>{{ formationOuverte.lieu || 'Précisé sur chaque session' }}</dd>
      </dl>
    </template>
  </Dialog>
</template>

<style scoped>
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.discret { color: var(--p-text-muted-color); font-size: .85rem; }
.note { color: var(--p-text-muted-color); font-size: .85rem; margin-top: 1rem; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
.descriptif { display: grid; grid-template-columns: 9rem 1fr; gap: .6rem 1rem; margin: 0; }
.descriptif dt { font-weight: 600; font-size: .9rem; }
.descriptif dd { margin: 0; line-height: 1.45; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
