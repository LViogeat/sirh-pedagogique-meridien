<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getEmploye, getHistoriqueRemuneration,
         formatDate, formatEuro, formatPourcent, anciennete } from '@/socle/sdk'

const route = useRoute()
const router = useRouter()
const salarie = ref(null)
const remuneration = ref([])
const chargement = ref(true)

const contratEnCours = computed(() =>
  salarie.value?.contrats?.find(c => !c.date_fin_reelle) ?? null)

const severiteAvenant = (code) =>
  ({ INITIAL: 'secondary', PROMO: 'success', TEMPS: 'warn', CLASSIF: 'info' }[code] || 'info')

onMounted(async () => {
  try {
    const id = Number(route.params.id)
    salarie.value = await getEmploye(id)
    remuneration.value = await getHistoriqueRemuneration(id)
  } finally {
    chargement.value = false
  }
})
</script>

<template>
  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!salarie" severity="warn" :closable="false">
    Ce salarié est introuvable.
  </Message>

  <template v-else>
    <PageHeader :titre="salarie.nom_complet"
                :sousTitre="`${salarie.matricule || 'sans matricule'} · ${salarie.emploi || '—'} · ${salarie.service || 'sans service'}`">
      <Button label="Retour à la liste" icon="pi pi-arrow-left" severity="secondary" outlined
              @click="router.push('/corehr/salaries')" />
    </PageHeader>

    <EmployeCard :employe="salarie" class="carte" />

    <Tabs value="0" class="onglets">
      <TabList>
        <Tab value="0">Identité</Tab>
        <Tab value="1">Contrats et avenants</Tab>
        <Tab value="2">Rémunération</Tab>
        <Tab value="3">Affectations</Tab>
      </TabList>

      <TabPanels>
        <!-- Identité ------------------------------------------------------- -->
        <TabPanel value="0">
          <dl class="identite">
            <div><dt>Matricule</dt><dd>{{ salarie.matricule || '—' }}</dd></div>
            <div><dt>Date de naissance</dt><dd>{{ formatDate(salarie.date_naissance, 'long') }}</dd></div>
            <div><dt>Âge</dt><dd>{{ salarie.age ?? '—' }} ans</dd></div>
            <div><dt>E-mail professionnel</dt><dd>{{ salarie.email_pro || '—' }}</dd></div>
            <div><dt>E-mail personnel</dt><dd>{{ salarie.email_perso || '—' }}</dd></div>
            <div><dt>Téléphone</dt><dd>{{ salarie.telephone || '—' }}</dd></div>
            <div><dt>Ville</dt><dd>{{ salarie.ville || '—' }}</dd></div>
            <div><dt>Établissement</dt><dd>{{ salarie.etablissement || '—' }}</dd></div>
            <div><dt>Date d’entrée dans l’entreprise</dt><dd>{{ formatDate(salarie.date_entree, 'long') }}</dd></div>
            <div><dt>Ancienneté</dt><dd>{{ anciennete(salarie.anciennete_mois) }}</dd></div>
          </dl>

          <Message v-if="salarie.date_entree && salarie.date_debut_contrat
                         && salarie.date_entree !== salarie.date_debut_contrat"
                   severity="info" :closable="false">
            L’ancienneté part de la <strong>date d’entrée dans l’entreprise</strong>
            ({{ formatDate(salarie.date_entree) }}), pas du début du contrat en cours
            ({{ formatDate(salarie.date_debut_contrat) }}) : cette personne a eu un
            contrat antérieur.
          </Message>
        </TabPanel>

        <!-- Contrats et avenants ------------------------------------------- -->
        <TabPanel value="1">
          <div v-for="c in salarie.contrats" :key="c.id" class="contrat">
            <header>
              <div>
                <Tag :value="c.type_contrat_code" />
                <strong>{{ c.numero }}</strong>
                <span class="periode">
                  du {{ formatDate(c.date_debut) }}
                  <template v-if="c.date_fin_reelle">au {{ formatDate(c.date_fin_reelle) }}</template>
                  <template v-else-if="c.date_fin_prevue">jusqu’au {{ formatDate(c.date_fin_prevue) }}</template>
                  <template v-else>— en cours</template>
                </span>
              </div>
              <Tag v-if="c.date_fin_reelle" :value="c.motif_sortie || 'Terminé'" severity="secondary" />
              <Tag v-else value="En cours" severity="success" />
            </header>

            <DataTable :value="c.avenants" size="small" class="avenants">
              <template #empty>Aucun avenant enregistré.</template>
              <Column field="numero_ordre" header="N°" style="width: 3.5rem" />
              <Column field="type_avenant" header="Type">
                <template #body="{ data }">
                  <Tag :value="data.type_avenant" :severity="severiteAvenant(data.type_avenant_code)" />
                </template>
              </Column>
              <Column header="Date d’effet" style="width: 8rem">
                <template #body="{ data }">{{ formatDate(data.date_effet) }}</template>
              </Column>
              <Column field="etp" header="ETP" style="width: 4.5rem" />
              <Column field="classification" header="Classification" />
              <Column field="coefficient" header="Coef." style="width: 4.5rem" />
              <Column header="Salaire brut" style="width: 8rem">
                <template #body="{ data }">{{ formatEuro(data.salaire_base_brut_mensuel) }}</template>
              </Column>
              <Column field="motif" header="Motif" />
            </DataTable>
          </div>
        </TabPanel>

        <!-- Rémunération ---------------------------------------------------- -->
        <TabPanel value="2">
          <Message severity="info" :closable="false" class="rappel">
            Le salaire n’est pas une colonne qu’on écrase : c’est l’état courant d’une
            suite d’<strong>avenants datés</strong>. C’est ce qui rend cette carrière lisible —
            et une masse salariale calculable à une date passée.
          </Message>

          <DataTable :value="remuneration" size="small" stripedRows>
            <template #empty>Aucun historique de rémunération.</template>
            <Column header="Date d’effet" style="width: 8rem">
              <template #body="{ data }">{{ formatDate(data.date_effet) }}</template>
            </Column>
            <Column field="type_avenant" header="Événement" />
            <Column field="etp" header="ETP" style="width: 4.5rem" />
            <Column header="Salaire brut mensuel" style="width: 10rem">
              <template #body="{ data }">{{ formatEuro(data.salaire) }}</template>
            </Column>
            <Column header="Évolution" style="width: 7rem">
              <template #body="{ data }">
                <span v-if="data.evolution_pct === null" class="muet">—</span>
                <Tag v-else :value="formatPourcent(data.evolution_pct)"
                     :severity="data.evolution_pct > 0 ? 'success' : 'secondary'" />
              </template>
            </Column>
            <Column field="motif" header="Motif" />
          </DataTable>
        </TabPanel>

        <!-- Affectations ---------------------------------------------------- -->
        <TabPanel value="3">
          <DataTable :value="salarie.affectations" size="small" stripedRows>
            <template #empty>Aucune affectation enregistrée.</template>
            <Column header="Du" style="width: 8rem">
              <template #body="{ data }">{{ formatDate(data.date_debut) }}</template>
            </Column>
            <Column header="Au" style="width: 8rem">
              <template #body="{ data }">
                {{ data.date_fin ? formatDate(data.date_fin) : 'en cours' }}
              </template>
            </Column>
            <Column field="service" header="Service" />
            <Column field="poste" header="Poste" />
            <Column field="manager" header="Manager" />
            <Column field="taux_affectation" header="Taux" style="width: 5rem" />
          </DataTable>
        </TabPanel>
      </TabPanels>
    </Tabs>
  </template>
</template>

<style scoped>
.attente { display: grid; place-items: center; min-height: 12rem; }
.carte { margin-bottom: 1.25rem; }
.onglets :deep(.p-tabpanels) { background: transparent; padding: 1.25rem 0 0; }
.identite {
  display: grid; gap: .85rem 2rem; margin: 0 0 1rem;
  grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
}
.identite dt { font-size: .78rem; color: var(--p-text-muted-color); text-transform: uppercase; letter-spacing: .03em; }
.identite dd { margin: .15rem 0 0; font-weight: 500; }
.contrat {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1rem; margin-bottom: 1rem;
}
.contrat header { display: flex; align-items: center; justify-content: space-between; gap: 1rem; margin-bottom: .75rem; flex-wrap: wrap; }
.contrat header > div { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.periode { color: var(--p-text-muted-color); font-size: .85rem; }
.rappel { margin-bottom: 1rem; }
.muet { color: var(--p-text-muted-color); }
</style>
