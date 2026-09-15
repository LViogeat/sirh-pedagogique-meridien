<script setup>
/**
 * La fiche d'un salarié : son identité, son poste, son parcours contractuel,
 * ses entretiens et les besoins qui le concernent.
 *
 * Le patron d'un écran de DÉTAIL : on lit l'identifiant dans l'URL, on charge,
 * on affiche. `masque: true` dans le manifeste le retire du menu.
 */
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  getSalarie, getEntretiens, getBesoins,
  formatDate, anciennete, toast,
} from '@/socle/sdk'

const route = useRoute()
const router = useRouter()

const salarie = ref(null)
const entretiens = ref([])
const besoins = ref([])
const chargement = ref(true)

onMounted(async () => {
  const id = route.params.id
  try {
    salarie.value = await getSalarie(id)
    ;[entretiens.value, besoins.value] = await Promise.all([
      getEntretiens({ salarieId: id }),
      getBesoins({ salarieId: id }),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const severiteStatutContrat = (code) =>
  ({ actif: 'success', termine: 'secondary', a_venir: 'info' })[code] || 'secondary'
</script>

<template>
  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <template v-else-if="salarie">
    <PageHeader :titre="salarie.full_name"
                :sousTitre="`${salarie.matricule} · ${salarie.position_title || 'sans poste'} · ${salarie.establishment_name || '—'}`">
      <Button label="Retour" icon="pi pi-arrow-left" severity="secondary" outlined
              @click="router.push('/corehr/salaries')" />
    </PageHeader>

    <div class="cartes">
      <StatCard titre="Ancienneté" :valeur="anciennete(salarie.seniority_months)"
                icone="pi pi-calendar" />
      <StatCard titre="Contrat"
                :valeur="salarie.contract_type_label || '—'" icone="pi pi-file" />
      <StatCard titre="Temps de travail"
                :valeur="salarie.work_time_ratio ? `${Math.round(salarie.work_time_ratio * 100)} %` : '—'"
                icone="pi pi-clock" />
      <StatCard titre="Équipe directe" :valeur="salarie.direct_reports_count"
                icone="pi pi-users" />
    </div>

    <div class="grille">
      <Card>
        <template #title>Identité</template>
        <template #content>
          <dl>
            <dt>E-mail professionnel</dt><dd>{{ salarie.email_pro }}</dd>
            <dt>Entrée dans le groupe</dt><dd>{{ formatDate(salarie.joined_on, 'long') }}</dd>
            <dt>Sortie</dt><dd>{{ salarie.left_on ? formatDate(salarie.left_on, 'long') : '—' }}</dd>
            <dt>Statut</dt><dd>{{ salarie.status_label }}</dd>
            <dt>Manager</dt>
            <dd>
              <a v-if="salarie.manager_id" href="#"
                 @click.prevent="router.push(`/corehr/salaries/${salarie.manager_id}`)">
                {{ salarie.manager_name }}
              </a>
              <span v-else>—</span>
            </dd>
            <dt>Département</dt><dd>{{ salarie.department_label || '—' }}</dd>
          </dl>
        </template>
      </Card>

      <Card>
        <template #title>Parcours dans le groupe</template>
        <template #content>
          <!-- L'historique d'un salarié, c'est la suite de ses contrats. -->
          <DataTable :value="salarie.contracts" size="small" dataKey="id">
            <template #empty>Aucun contrat.</template>
            <Column field="contract_type_label" header="Type" />
            <Column field="position_title" header="Poste" />
            <Column field="establishment_name" header="Établissement" />
            <Column header="Du">
              <template #body="{ data }">{{ formatDate(data.start_date) }}</template>
            </Column>
            <Column header="Au">
              <template #body="{ data }">{{ formatDate(data.end_date) }}</template>
            </Column>
            <Column header="Statut">
              <template #body="{ data }">
                <Tag :value="data.status_label" :severity="severiteStatutContrat(data.status)" />
              </template>
            </Column>
          </DataTable>
        </template>
      </Card>

      <Card>
        <template #title>Entretiens annuels</template>
        <template #content>
          <DataTable :value="entretiens" size="small" dataKey="id">
            <template #empty>Aucun entretien.</template>
            <Column field="campaign_label" header="Campagne" />
            <Column header="Date">
              <template #body="{ data }">{{ formatDate(data.review_date) }}</template>
            </Column>
            <Column field="reviewer_name" header="Évaluateur" />
            <Column field="average_achievement_rate" header="Atteinte">
              <template #body="{ data }">
                {{ data.average_achievement_rate !== null ? `${data.average_achievement_rate} %` : '—' }}
              </template>
            </Column>
            <Column field="status_label" header="Statut" />
          </DataTable>
        </template>
      </Card>

      <Card>
        <template #title>Besoins identifiés le concernant</template>
        <template #content>
          <DataTable :value="besoins" size="small" dataKey="id">
            <template #empty>Aucun besoin identifié.</template>
            <Column field="need_type_label" header="Type" />
            <Column field="skill_label" header="Compétence">
              <template #body="{ data }">{{ data.skill_label || '—' }}</template>
            </Column>
            <Column field="priority_label" header="Priorité" />
            <Column field="status_label" header="Statut" />
            <Column field="handled_by_module" header="Pris par">
              <template #body="{ data }">{{ data.handled_by_module || '—' }}</template>
            </Column>
          </DataTable>
        </template>
      </Card>
    </div>
  </template>
</template>

<style scoped>
.attente { display: grid; place-items: center; min-height: 40vh; }
.cartes { display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
          gap: 1rem; margin-bottom: 1.25rem; }
.grille { display: grid; gap: 1.25rem; }
dl { display: grid; grid-template-columns: 12rem 1fr; gap: .4rem 1rem; margin: 0; }
dt { color: var(--p-text-muted-color); font-size: .85rem; }
dd { margin: 0; }
</style>
