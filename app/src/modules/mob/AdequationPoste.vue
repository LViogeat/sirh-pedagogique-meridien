<!-- libelle: Adéquation au poste visé -->
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { getPoste, getEntretien, formatDate, toast } from '@/socle/sdk'
import { salariesAvecBesoin } from './_commun'

const candidats = ref([])
const besoin = ref(null)
const poste = ref(null)
const entretien = ref(null)
const chargement = ref(false)

onMounted(async () => {
  try {
    candidats.value = await salariesAvecBesoin()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})

watch(besoin, async (b) => {
  poste.value = entretien.value = null
  if (!b) return
  chargement.value = true
  try {
    ;[poste.value, entretien.value] = await Promise.all([
      getPoste(b.position_id),
      b.review_id ? getEntretien(b.review_id) : null,
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

/*
 * Une ligne par compétence attendue sur le poste visé.
 * `manque` = niveau attendu − niveau constaté (0 si le salarié est au niveau).
 */
const lignes = computed(() => {
  if (!poste.value) return []
  const constatees = new Map((entretien.value?.skill_assessments || []).map((a) => [a.skill_id, a]))
  return poste.value.required_skills.map((r) => {
    const a = constatees.get(r.skill_id)
    const constate = a ? a.assessed_level : null
    return {
      ...r,
      constate,
      manque: constate == null ? null : Math.max(0, r.required_level - constate),
    }
  })
})

const nonEvaluees = computed(() => lignes.value.filter((l) => l.manque == null).length)

/*
 * Le verdict :
 *   Prêt                 aucun écart
 *   Prêt avec formation  des écarts de 1 niveau au plus
 *   À accompagner        sinon
 * Une compétence non évaluée compte comme un écart de 1 niveau : on ne peut
 * pas dire qu'il est prêt sans l'avoir vue, mais une formation peut suffire.
 */
const verdict = computed(() => {
  if (!lignes.value.length) return null
  const manques = lignes.value.map((l) => (l.manque == null ? 1 : l.manque))
  const pire = Math.max(...manques)
  if (pire === 0) return { label: 'Prêt', severite: 'success', icone: 'pi pi-check-circle' }
  if (pire <= 1) return { label: 'Prêt avec formation', severite: 'warn', icone: 'pi pi-book' }
  return { label: 'À accompagner', severite: 'danger', icone: 'pi pi-exclamation-triangle' }
})
</script>

<template>
  <PageHeader titre="Adéquation au poste visé"
              sousTitre="Ce qui manque au salarié pour sa mobilité" />

  <Select v-model="besoin" :options="candidats" optionLabel="libelle" filter showClear
          placeholder="Choisir un salarié ayant un besoin de mobilité" class="choix" />

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!besoin" severity="info" :closable="false">
    Choisissez un salarié pour comparer ses compétences à celles du poste visé.
  </Message>

  <template v-else-if="poste">
    <div class="bandeau">
      <div>
        <div class="poste">{{ poste.title }} — {{ poste.establishment_name }}</div>
        <small class="discret">
          Niveau {{ poste.hierarchy_level }} ·
          {{ entretien ? `entretien du ${formatDate(entretien.review_date)}` : 'aucun entretien rattaché' }}
          <template v-if="nonEvaluees"> · {{ nonEvaluees }} compétence(s) non évaluée(s)</template>
        </small>
      </div>
      <Tag v-if="verdict" :value="verdict.label" :severity="verdict.severite" :icon="verdict.icone" class="verdict" />
    </div>

    <Message v-if="nonEvaluees" severity="warn" :closable="false" class="note">
      Verdict provisoire : {{ nonEvaluees }} compétence(s) attendue(s) n'ont pas été évaluées
      au dernier entretien. À vérifier lors de l'entretien de mobilité.
    </Message>

    <DataTable :value="lignes" size="small" dataKey="skill_id">
      <template #empty>Aucune compétence attendue n'est renseignée pour ce poste.</template>
      <Column field="skill_label" header="Compétence" />
      <Column field="category_label" header="Catégorie" />
      <Column field="required_level" header="Niveau attendu" style="width: 9rem" />
      <Column header="Niveau constaté" style="width: 9rem">
        <template #body="{ data }">
          <span v-if="data.constate != null">{{ data.constate }}</span>
          <Tag v-else value="Non évaluée" severity="secondary" />
        </template>
      </Column>
      <Column header="Écart" style="width: 7rem">
        <template #body="{ data }">
          <span v-if="data.manque == null" class="discret">—</span>
          <span v-else-if="data.manque > 0" class="rouge">−{{ data.manque }}</span>
          <span v-else class="vert">OK</span>
        </template>
      </Column>
    </DataTable>
  </template>
</template>

<style scoped>
.choix { min-width: 28rem; margin-bottom: 1.25rem; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.bandeau { display: flex; align-items: center; justify-content: space-between; gap: 1rem;
           background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
           border-radius: 12px; padding: 1rem 1.25rem; margin-bottom: 1rem; }
.poste { font-weight: 600; font-size: 1.1rem; }
.note { margin-bottom: 1rem; }
.verdict { font-size: 1rem; padding: .4rem .8rem; }
.discret { color: var(--p-text-muted-color); }
.rouge { color: var(--p-red-600); font-weight: 700; }
.vert { color: var(--p-green-600); font-weight: 600; }
</style>
