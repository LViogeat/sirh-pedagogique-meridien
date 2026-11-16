<!-- libelle: Mes souhaits de formation -->
<script setup>
/**
 * Story #27 — Le collaborateur exprime ses souhaits de formation lors de son
 * entretien annuel, en choisissant des formations du catalogue.
 *
 * L'écran rappelle l'entretien annuel du collaborateur (campagne, date,
 * écarts de compétences constatés), puis lui fait cocher les formations
 * qu'il souhaite suivre. Ses souhaits partent ensuite chez son manager, qui
 * les formalise et les transmet au RH (écran « Souhaits de mon équipe »).
 */
import { ref, computed } from 'vue'
import {
  sql, insert, remove, getEntretiens, getEntretien, formatDate, formatNombre, toast,
} from '@/socle/sdk'
import {
  preparerSchema, STATUTS_SOUHAIT, ORIGINES_SOUHAIT, libelle, couleur, salarieCourantId,
} from './_donnees'
import ChoixSalarie from './_ChoixSalarie.vue'

const salarie = ref(null)
const entretien = ref(null)
const formations = ref([])
const souhaits = ref([])
const chargement = ref(false)

const choisies = ref([])
const motivation = ref('')
const envoi = ref(false)

async function chargerSouhaits() {
  souhaits.value = await sql(
    `select w.*, f.intitule as formation, f.domaine, f.duree_heures
     from   souhaits w
     join   formations f on f.id = w.formation_id
     where  w.employee_id = :salarie
     order by w.cree_le desc, w.id desc`,
    { salarie: salarie.value.id },
  )
}

async function charger() {
  entretien.value = null
  souhaits.value = []
  choisies.value = []
  motivation.value = ''
  if (!salarie.value) return

  chargement.value = true
  try {
    await preparerSchema()
    formations.value = await sql(
      `select id, code, intitule, domaine, duree_heures, skill_id
       from   formations
       where  actif
       order by domaine, intitule`,
    )
    await chargerSouhaits()

    // Le dernier entretien annuel du collaborateur, avec ses écarts de niveau.
    const entretiens = await getEntretiens({ salarieId: salarie.value.id })
    if (entretiens.length) {
      const dernier = [...entretiens].sort(
        (a, b) => String(b.review_date).localeCompare(String(a.review_date)))[0]
      entretien.value = await getEntretien(dernier.id)
    }
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

async function changerSalarie(s) {
  salarie.value = s
  await charger()
}

/** Les compétences où le niveau constaté est sous le niveau attendu. */
const ecarts = computed(() =>
  (entretien.value?.skill_assessments ?? []).filter((e) => (e.gap ?? 0) > 0))

/** Les formations déjà demandées au titre de l'entretien annuel. */
const dejaDemandees = computed(() => new Set(
  souhaits.value
    .filter((w) => w.origine === 'entretien_annuel')
    .map((w) => w.formation_id)))

/**
 * Le catalogue proposé, sans les formations déjà demandées. Celles qui
 * répondent à un écart constaté en entretien sont signalées et placées en tête.
 */
const proposees = computed(() => {
  const competences = new Set(ecarts.value.map((e) => e.skill_id))
  return formations.value
    .filter((f) => !dejaDemandees.value.has(f.id))
    .map((f) => {
      const conseillee = f.skill_id && competences.has(f.skill_id)
      return {
        ...f,
        conseillee,
        affichage: `${f.intitule} (${f.domaine}, ${f.duree_heures} h)` +
                   (conseillee ? ' — conseillée après votre entretien' : ''),
      }
    })
    .sort((a, b) => Number(b.conseillee) - Number(a.conseillee))
})

async function enregistrer() {
  if (!choisies.value.length) {
    toast.alerte('Choisissez au moins une formation dans le catalogue.')
    return
  }
  envoi.value = true
  try {
    for (const formationId of choisies.value) {
      await insert('souhaits', {
        employee_id: salarie.value.id,
        formation_id: formationId,
        origine: 'entretien_annuel',
        review_id: entretien.value?.id ?? null,
        saisi_par: 'collaborateur',
        motivation: motivation.value.trim() || null,
      })
    }
    toast.succes(`${choisies.value.length} souhait(s) enregistré(s) et envoyé(s) à votre manager`)
    choisies.value = []
    motivation.value = ''
    await chargerSouhaits()
  } catch (erreur) {
    toast.erreur(erreur.message)
    await chargerSouhaits()
  } finally {
    envoi.value = false
  }
}

async function retirer(souhait) {
  try {
    await remove('souhaits', souhait.id)
    toast.info('Souhait retiré')
    await chargerSouhaits()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}
</script>

<template>
  <PageHeader
    titre="Mes souhaits de formation"
    sousTitre="Les formations que je souhaite suivre, exprimées lors de mon entretien annuel"
  />

  <ChoixSalarie @change="changerSalarie" />

  <Message v-if="!salarieCourantId" severity="info" :closable="false">
    Choisissez votre nom dans la liste pour exprimer vos souhaits de formation.
  </Message>

  <div v-else-if="chargement" class="attente"><ProgressSpinner /></div>

  <template v-else-if="salarie">
    <Card class="bloc">
      <template #title>Mon entretien annuel</template>
      <template #content>
        <template v-if="entretien">
          <p class="chapo">
            {{ entretien.campaign_label }} · entretien du
            {{ formatDate(entretien.review_date, 'long') }} avec {{ entretien.reviewer_name }} ·
            {{ entretien.status_label }}
          </p>
          <template v-if="ecarts.length">
            <p>Compétences à renforcer d’après cet entretien :</p>
            <div class="ecarts">
              <Tag v-for="e in ecarts" :key="e.id" severity="warn"
                   :value="`${e.skill_label} : niveau ${e.assessed_level} pour ${e.required_level} attendu`" />
            </div>
          </template>
          <p v-else class="discret">Aucun écart de compétence n’a été relevé dans cet entretien.</p>
        </template>
        <p v-else class="discret">
          Aucun entretien annuel n’est enregistré pour vous. Vous pouvez quand même
          exprimer vos souhaits : ils seront transmis à votre manager.
        </p>
      </template>
    </Card>

    <Card class="bloc">
      <template #title>Je souhaite suivre…</template>
      <template #content>
        <div class="formulaire">
          <div class="champ">
            <label for="w-formations">Formations du catalogue</label>
            <MultiSelect inputId="w-formations" v-model="choisies" :options="proposees"
                         optionLabel="affichage" optionValue="id" filter display="chip"
                         placeholder="Sélectionner une ou plusieurs formations"
                         emptyMessage="Vous avez déjà demandé toutes les formations du catalogue" />
          </div>
          <div class="champ">
            <label for="w-motivation">Pourquoi ces formations ? (facultatif)</label>
            <Textarea id="w-motivation" v-model="motivation" rows="2" autoResize
                      placeholder="Ce que j’en attends pour mon poste ou mon projet" />
          </div>
          <div>
            <Button label="Enregistrer mes souhaits" icon="pi pi-send"
                    :loading="envoi" :disabled="!choisies.length" @click="enregistrer" />
          </div>
        </div>
      </template>
    </Card>

    <h3>Mes souhaits déjà exprimés</h3>
    <DataTable :value="souhaits" dataKey="id" stripedRows size="small">
      <template #empty>Vous n’avez pas encore exprimé de souhait de formation.</template>

      <Column field="formation" header="Formation" />
      <Column field="domaine" header="Domaine" />
      <Column header="Durée" style="width: 6rem">
        <template #body="{ data }">{{ formatNombre(data.duree_heures) }} h</template>
      </Column>
      <Column header="Exprimé" style="width: 11rem">
        <template #body="{ data }">{{ libelle(ORIGINES_SOUHAIT, data.origine) }}</template>
      </Column>
      <Column header="Le" style="width: 7rem">
        <template #body="{ data }">{{ formatDate(data.cree_le) }}</template>
      </Column>
      <Column field="motivation" header="Motivation">
        <template #body="{ data }">{{ data.motivation || '—' }}</template>
      </Column>
      <Column header="Suite donnée" style="width: 14rem">
        <template #body="{ data }">
          <Tag :value="libelle(STATUTS_SOUHAIT, data.statut)"
               :severity="couleur(STATUTS_SOUHAIT, data.statut)" />
        </template>
      </Column>
      <Column style="width: 4rem">
        <template #body="{ data }">
          <Button v-if="data.statut === 'exprime' && data.saisi_par === 'collaborateur'"
                  icon="pi pi-trash" text rounded severity="secondary"
                  aria-label="Retirer ce souhait" v-tooltip.left="'Retirer ce souhait'"
                  @click="retirer(data)" />
        </template>
      </Column>
    </DataTable>
  </template>
</template>

<style scoped>
.attente { display: flex; justify-content: center; padding: 3rem; }
.bloc { margin-bottom: 1.25rem; }
.chapo { color: var(--p-text-muted-color); font-size: .9rem; margin-top: 0; }
.discret { color: var(--p-text-muted-color); font-size: .9rem; }
.ecarts { display: flex; gap: .5rem; flex-wrap: wrap; }
.formulaire { display: flex; flex-direction: column; gap: 1rem; }
.champ { display: flex; flex-direction: column; gap: .35rem; }
.champ label { font-size: .85rem; font-weight: 600; }
h3 { font-size: 1rem; margin: 1.5rem 0 .5rem; }
</style>
