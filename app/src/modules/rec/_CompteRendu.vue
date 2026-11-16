<script setup>
/**
 * Le compte rendu d'un entretien (story #107).
 *
 * La grille reprend les compétences attendues du poste (getPoste) : pour
 * chacune, le recruteur note le niveau constaté de 1 à 4, et l'écart avec le
 * niveau attendu s'affiche. Puis un compte rendu libre, un avis global et une
 * recommandation. Enregistrer passe l'entretien à « Réalisé ».
 *
 * Le score d'adéquation est la part des compétences évaluées au niveau
 * attendu ou au-dessus.
 */
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPoste, sql, update, formatDate, toast } from '@/socle/sdk'

const route = useRoute()
const router = useRouter()
const entretienId = computed(() => Number(route.params.id))

const entretien = ref(null)
const grille = ref([])
const formulaire = ref(null)
const chargement = ref(true)
const enregistrement = ref(false)

const NIVEAUX = [
  { valeur: 1, label: '1 · Notions' },
  { valeur: 2, label: '2 · Opérationnel' },
  { valeur: 3, label: '3 · Confirmé' },
  { valeur: 4, label: '4 · Expert' },
]
const AVIS = [
  { code: 'favorable', label: 'Favorable' },
  { code: 'reserve', label: 'Réservé' },
  { code: 'defavorable', label: 'Défavorable' },
]
const RECOMMANDATIONS = [
  { code: 'proposition', label: 'Passer à la proposition' },
  { code: 'second_entretien', label: 'Revoir en second entretien' },
  { code: 'refus', label: 'Refuser la candidature' },
]

async function charger() {
  if (!Number.isInteger(entretienId.value) || entretienId.value <= 0) {
    chargement.value = false
    return
  }
  chargement.value = true
  try {
    const [ligne] = await sql(
      `select e.*, ca.etape, ca.id as candidature_id,
              c.id as candidat_id, c.prenom, c.nom,
              o.id as offre_id, o.intitule, o.position_id
         from entretiens e
         join candidatures ca on ca.id = e.candidature_id
         join candidats c on c.id = ca.candidat_id
         join offres o on o.id = ca.offre_id
        where e.id = :id`,
      { id: entretienId.value },
    )
    entretien.value = ligne || null
    if (!ligne) return

    const [poste, evaluations] = await Promise.all([
      getPoste(ligne.position_id),
      sql('select * from evaluations_competences where entretien_id = :id', { id: ligne.id }),
    ])
    const deja = Object.fromEntries(evaluations.map((e) => [e.skill_id, e]))
    grille.value = poste.required_skills.map((s) => ({
      skill_id: s.skill_id,
      competence: s.skill_label,
      categorie: s.category_label,
      niveau_attendu: s.required_level,
      niveau_constate: deja[s.skill_id]?.niveau_constate ?? null,
      commentaire: deja[s.skill_id]?.commentaire ?? '',
    }))
    formulaire.value = {
      compte_rendu: ligne.compte_rendu || '',
      avis: ligne.avis,
      recommandation: ligne.recommandation,
    }
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(charger)
watch(entretienId, charger)

const evaluees = computed(() => grille.value.filter((g) => g.niveau_constate))
const score = computed(() => {
  if (!evaluees.value.length) return null
  const atteintes = evaluees.value.filter((g) => g.niveau_constate >= g.niveau_attendu).length
  return { atteintes, total: evaluees.value.length, pct: Math.round((100 * atteintes) / evaluees.value.length) }
})

function ecart(g) {
  if (!g.niveau_constate) return null
  const d = g.niveau_constate - g.niveau_attendu
  if (d >= 0) return { label: d === 0 ? 'Au niveau' : `+${d} au-dessus`, severite: 'success' }
  return { label: `${d} en dessous`, severite: d === -1 ? 'warn' : 'danger' }
}

const dateHeure = computed(() => {
  if (!entretien.value) return ''
  const d = new Date(entretien.value.date_heure)
  return `${formatDate(d, 'long')} à ${d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`
})

async function enregistrer() {
  const f = formulaire.value
  if (!f.avis) {
    toast.alerte("Choisissez un avis global avant d'enregistrer.")
    return
  }
  enregistrement.value = true
  try {
    for (const g of grille.value) {
      if (!g.niveau_constate) continue
      await sql(
        `insert into evaluations_competences
                (entretien_id, skill_id, competence, niveau_attendu, niveau_constate, commentaire)
         values (:entretien, :skill, :competence, :attendu, :constate, :commentaire)
         on conflict (entretien_id, skill_id) do update
            set niveau_constate = excluded.niveau_constate,
                niveau_attendu  = excluded.niveau_attendu,
                commentaire     = excluded.commentaire`,
        {
          entretien: entretien.value.id, skill: g.skill_id, competence: g.competence,
          attendu: g.niveau_attendu, constate: g.niveau_constate,
          commentaire: g.commentaire?.trim() || null,
        },
      )
    }
    await update('entretiens', entretien.value.id, {
      statut: 'realise',
      compte_rendu: f.compte_rendu.trim() || null,
      avis: f.avis,
      recommandation: f.recommandation || null,
    })
    toast.succes(`Compte rendu enregistré · entretien de ${entretien.value.prenom} ${entretien.value.nom} réalisé`)
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <div class="retour">
    <Button label="Retour aux entretiens" icon="pi pi-arrow-left" text size="small"
            @click="router.push('/rec/entretiens')" />
  </div>

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="!entretien" severity="info" :closable="false">
    Aucun entretien à afficher. Ouvrez un compte rendu depuis l'écran « Entretiens ».
  </Message>

  <template v-else>
    <PageHeader :titre="`Compte rendu d'entretien · ${entretien.prenom} ${entretien.nom}`"
                :sousTitre="`${entretien.intitule} · ${dateHeure} · avec ${entretien.recruteur_nom}`" />

    <div class="bandeau">
      <Tag :value="entretien.statut === 'realise' ? 'Réalisé' : entretien.statut === 'annule' ? 'Annulé' : 'Planifié'"
           :severity="entretien.statut === 'realise' ? 'success' : 'info'" />
      <span v-if="entretien.lieu"><i class="pi pi-map-marker" /> {{ entretien.lieu }}</span>
      <a href="#" class="lien" @click.prevent="router.push(`/rec/candidat/${entretien.candidat_id}`)">
        <i class="pi pi-user" /> Page du candidat
      </a>
    </div>

    <Card>
      <template #title>Compétences du poste</template>
      <template #content>
        <DataTable :value="grille" dataKey="skill_id" size="small">
          <template #empty>Aucune compétence attendue n'est définie pour ce poste dans le socle.</template>
          <Column header="Compétence">
            <template #body="{ data }">
              <strong>{{ data.competence }}</strong>
              <span class="detail">{{ data.categorie }}</span>
            </template>
          </Column>
          <Column header="Attendu" style="width: 6rem">
            <template #body="{ data }">{{ data.niveau_attendu }} / 4</template>
          </Column>
          <Column header="Constaté en entretien" style="width: 13rem">
            <template #body="{ data }">
              <Select v-model="data.niveau_constate" :options="NIVEAUX" optionLabel="label"
                      optionValue="valeur" placeholder="Non évalué" showClear fluid />
            </template>
          </Column>
          <Column header="Écart" style="width: 9rem">
            <template #body="{ data }">
              <Tag v-if="ecart(data)" :value="ecart(data).label" :severity="ecart(data).severite" />
              <span v-else class="muet">—</span>
            </template>
          </Column>
          <Column header="Commentaire">
            <template #body="{ data }">
              <InputText v-model="data.commentaire" placeholder="Exemple observé…" fluid />
            </template>
          </Column>
        </DataTable>

        <div class="score">
          <template v-if="score">
            Score d'adéquation : <strong>{{ score.atteintes }} sur {{ score.total }}</strong>
            compétence(s) au niveau attendu, soit <strong>{{ score.pct }} %</strong>
            <ProgressBar :value="score.pct" :showValue="false" class="barre" />
          </template>
          <span v-else class="muet">Évaluez au moins une compétence pour obtenir le score d'adéquation.</span>
        </div>
      </template>
    </Card>

    <Card class="bloc">
      <template #title>Compte rendu et avis</template>
      <template #content>
        <form class="formulaire" @submit.prevent="enregistrer">
          <label for="compte-rendu">Compte rendu</label>
          <Textarea id="compte-rendu" v-model="formulaire.compte_rendu" rows="6" autoResize
                    placeholder="Motivation, expérience, points forts, points de vigilance, disponibilité…" />

          <label>Avis global</label>
          <SelectButton v-model="formulaire.avis" :options="AVIS" optionLabel="label" optionValue="code" />

          <label>Recommandation</label>
          <SelectButton v-model="formulaire.recommandation" :options="RECOMMANDATIONS"
                        optionLabel="label" optionValue="code" />

          <div class="pied">
            <Button label="Enregistrer le compte rendu" icon="pi pi-check" type="submit"
                    :loading="enregistrement" :disabled="entretien.statut === 'annule'" />
          </div>
        </form>
      </template>
    </Card>
  </template>
</template>

<style scoped>
.retour { margin: -.5rem 0 .5rem -.75rem; }
.attente { display: flex; justify-content: center; padding: 3rem; }
.bandeau { display: flex; align-items: center; gap: 1.25rem; margin-bottom: 1rem; font-size: .9rem; }
.bloc { margin-top: 1rem; }
.detail { display: block; font-size: .78rem; color: var(--p-text-muted-color); }
.score { margin-top: 1rem; font-size: .95rem; }
.barre { height: .5rem; margin-top: .5rem; max-width: 26rem; }
.formulaire { display: flex; flex-direction: column; gap: .4rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .75rem; }
.pied { display: flex; justify-content: flex-end; margin-top: 1.25rem; }
.lien { color: var(--p-primary-color); text-decoration: none; }
.lien:hover { text-decoration: underline; }
.muet { color: var(--p-text-muted-color); }
:deep(.p-card-title) { font-size: 1rem; }
</style>
