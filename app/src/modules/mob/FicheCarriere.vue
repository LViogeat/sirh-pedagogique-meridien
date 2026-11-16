<!-- libelle: Fiche carrière -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getSalarie, getEntretien, getPoste, getAspirations, sql,
         formatDate, anciennete, toast } from '@/socle/sdk'
import { salariesAvecBesoin, etapeDe } from './_commun'

const candidats = ref([])
const besoin = ref(null)          // le besoin choisi dans la liste
const chargement = ref(false)

const salarie = ref(null)
const entretien = ref(null)
const posteVise = ref(null)
const souhaits = ref([])
const dossier = ref(null)

onMounted(async () => {
  try {
    candidats.value = await salariesAvecBesoin()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

watch(besoin, async (b) => {
  salarie.value = entretien.value = posteVise.value = dossier.value = null
  souhaits.value = []
  if (!b) return
  chargement.value = true
  try {
    const [s, e, p, a, d] = await Promise.all([
      getSalarie(b.employee_id),
      b.review_id ? getEntretien(b.review_id) : null,
      getPoste(b.position_id),
      getAspirations({ salarieId: b.employee_id }),
      sql('select * from dossiers where besoin_id = :id', { id: b.id }),
    ])
    salarie.value = s
    entretien.value = e
    posteVise.value = p
    souhaits.value = a
    dossier.value = d[0] || null
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

/* Le parcours : le contrat le plus récent en haut. */
const parcours = computed(() =>
  [...(salarie.value?.contracts || [])].sort((a, b) => String(b.start_date).localeCompare(String(a.start_date))))

const severiteEcart = (ecart) => (ecart > 0 ? 'danger' : ecart < 0 ? 'success' : 'secondary')
</script>

<template>
  <PageHeader titre="Fiche carrière" sousTitre="Préparer l'entretien de mobilité d'un salarié" />

  <Select v-model="besoin" :options="candidats" optionLabel="libelle" filter
          placeholder="Choisir un salarié ayant un besoin de mobilité" class="choix" showClear />

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!besoin" severity="info" :closable="false">
    Choisissez un salarié pour afficher sa fiche.
  </Message>

  <div v-else-if="salarie" class="grille">
    <!-- Identité et situation actuelle -->
    <Card>
      <template #title>{{ salarie.full_name }}</template>
      <template #subtitle>{{ salarie.matricule }} · {{ salarie.email_pro }}</template>
      <template #content>
        <dl class="detail">
          <dt>Poste</dt><dd>{{ salarie.position_title }} (niveau {{ salarie.hierarchy_level }})</dd>
          <dt>Hôtel</dt><dd>{{ salarie.establishment_name }}</dd>
          <dt>Département</dt><dd>{{ salarie.department_label }}</dd>
          <dt>Manager</dt><dd>{{ salarie.manager_name || '—' }}</dd>
          <dt>Contrat</dt><dd>{{ salarie.contract_type_label }} depuis le {{ formatDate(salarie.contract_start_date) }}</dd>
          <dt>Ancienneté</dt><dd>{{ anciennete(salarie.seniority_months) }}</dd>
          <dt>Dossier</dt>
          <dd>
            <Tag v-if="dossier" :value="etapeDe(dossier.etape).label" :severity="etapeDe(dossier.etape).severite" />
            <span v-else class="discret">Besoin non pris en charge</span>
          </dd>
        </dl>
      </template>
    </Card>

    <!-- Souhait et poste visé -->
    <Card>
      <template #title>Souhait d'évolution</template>
      <template #content>
        <div v-for="a in souhaits" :key="a.id" class="souhait">
          <Tag :value="a.aspiration_type_label" severity="info" />
          <span v-if="a.target_position_title"> {{ a.target_position_title }}</span>
          <span v-if="a.target_establishment_name"> · {{ a.target_establishment_name }}</span>
          <div v-if="a.comment" class="discret">{{ a.comment }}</div>
        </div>
        <p v-if="!souhaits.length" class="discret">Aucun souhait enregistré.</p>

        <h4>Poste visé</h4>
        <p v-if="posteVise">
          <strong>{{ posteVise.title }}</strong> — {{ posteVise.department_label }},
          {{ posteVise.establishment_name }} · niveau {{ posteVise.hierarchy_level }}
        </p>
        <p class="discret">Origine du besoin : {{ besoin.origin }}</p>
      </template>
    </Card>

    <!-- Parcours -->
    <Card class="large">
      <template #title>Parcours</template>
      <template #content>
        <DataTable :value="parcours" size="small" dataKey="id">
          <Column field="position_title" header="Poste" />
          <Column field="establishment_name" header="Hôtel" />
          <Column field="contract_type_label" header="Contrat" />
          <Column header="Du"><template #body="{ data }">{{ formatDate(data.start_date) }}</template></Column>
          <Column header="Au"><template #body="{ data }">{{ data.end_date ? formatDate(data.end_date) : 'en cours' }}</template></Column>
        </DataTable>
      </template>
    </Card>

    <!-- Dernier entretien -->
    <Card class="large">
      <template #title>Dernier entretien</template>
      <template #subtitle v-if="entretien">
        {{ formatDate(entretien.review_date) }} avec {{ entretien.reviewer_name }} ·
        taux moyen {{ entretien.average_achievement_rate }} %
      </template>
      <template #content>
        <p v-if="!entretien" class="discret">Aucun entretien rattaché à ce besoin.</p>
        <div v-else class="deux">
          <DataTable :value="entretien.goals" size="small" dataKey="id">
            <template #header>Objectifs</template>
            <Column field="label" header="Objectif" />
            <Column header="Atteinte" style="width: 6rem">
              <template #body="{ data }">{{ data.achievement_rate }} %</template>
            </Column>
          </DataTable>
          <DataTable :value="entretien.skill_assessments" size="small" dataKey="id">
            <template #header>Compétences évaluées</template>
            <Column field="skill_label" header="Compétence" />
            <Column field="assessed_level" header="Constaté" style="width: 6rem" />
            <Column field="required_level" header="Attendu" style="width: 6rem" />
            <Column header="Écart" style="width: 5rem">
              <template #body="{ data }">
                <Tag :value="data.gap > 0 ? `-${data.gap}` : data.gap < 0 ? `+${-data.gap}` : '0'"
                     :severity="severiteEcart(data.gap)" />
              </template>
            </Column>
          </DataTable>
        </div>
      </template>
    </Card>
  </div>
</template>

<style scoped>
.choix { min-width: 28rem; margin-bottom: 1.25rem; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.grille { display: grid; grid-template-columns: repeat(auto-fit, minmax(24rem, 1fr)); gap: 1.25rem; }
.large { grid-column: 1 / -1; }
.deux { display: grid; grid-template-columns: repeat(auto-fit, minmax(22rem, 1fr)); gap: 1.25rem; }
.detail { display: grid; grid-template-columns: 7rem 1fr; gap: .45rem 1rem; margin: 0; }
.detail dt { font-weight: 600; color: var(--p-text-muted-color); }
.detail dd { margin: 0; }
.souhait { margin-bottom: .6rem; }
.discret { color: var(--p-text-muted-color); }
h4 { margin: 1rem 0 .4rem; }
</style>
