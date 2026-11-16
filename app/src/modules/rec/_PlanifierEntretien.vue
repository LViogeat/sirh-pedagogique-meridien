<script setup>
/**
 * La fenêtre « Planifier un entretien » (stories #106 et #127).
 *
 * Planifier est OBLIGATOIRE pour passer à « Entretien à réaliser » : c'est
 * cette fenêtre qui fait le passage, une fois l'entretien enregistré. Fermée
 * sans planifier, la candidature reste à « Tri de CV ».
 *
 * Le recruteur choisit de 1 à 8 compétences à évaluer : celles attendues sur
 * le poste (socle, pré-cochées) et le panel du module (16 compétences).
 */
import { ref, watch, computed } from 'vue'
import { getSalaries, getPoste, sql, insert, remove, toast } from '@/socle/sdk'
import { passerEnEntretien, libelleEtape } from './_workflow.js'

const props = defineProps({
  visible: { type: Boolean, default: false },
  // { id, prenom, nom, intitule, establishment_id, position_id, etape }
  candidature: { type: Object, default: null },
  commentaire: { type: String, default: '' },
})
const emit = defineEmits(['update:visible', 'planifie'])

const MAX = 8
const NIVEAUX = [1, 2, 3, 4]

const candidatures = ref([])
const choisie = ref(null)
const salaries = ref([])
const competences = ref([]) // { cle, source, competence_id, libelle, famille, niveau_attendu, cochee }
const formulaire = ref(null)
const enregistrement = ref(false)

const cible = computed(() => props.candidature || candidatures.value.find((c) => c.id === choisie.value) || null)

/* Créneaux d'un quart d'heure, de 7 h à 20 h. */
const CRENEAUX = Array.from({ length: 53 }, (_, i) => {
  const minutes = 7 * 60 + i * 15
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`
})

watch(() => props.visible, async (ouvert) => {
  if (!ouvert) return
  const demain = new Date()
  demain.setDate(demain.getDate() + 1)
  demain.setHours(0, 0, 0, 0)
  formulaire.value = { date: demain, heure: '10:00', lieu: '', recruteurId: null }
  choisie.value = null
  salaries.value = []
  competences.value = []
  if (!props.candidature) {
    // Un entretien se planifie au « Tri de CV » (il fait passer à l'étape
    // suivante) ou à « Entretien à réaliser » (un entretien de plus).
    try {
      candidatures.value = await sql(
        `select ca.id, ca.etape, c.prenom, c.nom, o.intitule, o.establishment_id, o.position_id
           from candidatures ca
           join candidats c on c.id = ca.candidat_id
           join offres o on o.id = ca.offre_id
          where ca.etape in ('preselection', 'entretien') and o.statut = 'publiee'
          order by c.nom, c.prenom`,
      )
    } catch (erreur) {
      toast.erreur(erreur.message)
    }
  } else {
    await preparer(props.candidature)
  }
}, { immediate: true })

watch(choisie, () => { if (cible.value) preparer(cible.value) })

async function preparer(c) {
  salaries.value = []
  competences.value = []
  if (formulaire.value) formulaire.value.recruteurId = null
  try {
    const [personnes, poste, panel] = await Promise.all([
      getSalaries({ etablissementId: c.establishment_id }),
      c.position_id ? getPoste(c.position_id) : Promise.resolve({ required_skills: [] }),
      sql('select id, famille, libelle from panel_competences order by ordre'),
    ])
    salaries.value = personnes.sort((a, b) =>
      (b.hierarchy_level ?? 0) - (a.hierarchy_level ?? 0) || a.last_name.localeCompare(b.last_name))

    const duPoste = poste.required_skills.map((s, i) => ({
      cle: `poste-${s.skill_id}`, source: 'poste', competence_id: s.skill_id, libelle: s.skill_label,
      famille: 'Attendues sur le poste', niveau_attendu: s.required_level, cochee: i < MAX,
    }))
    const dejaLa = new Set(duPoste.map((s) => s.libelle.toLowerCase()))
    const duPanel = panel
      .filter((p) => !dejaLa.has(p.libelle.toLowerCase()))
      .map((p) => ({
        cle: `panel-${p.id}`, source: 'panel', competence_id: p.id, libelle: p.libelle,
        famille: p.famille, niveau_attendu: 2, cochee: false,
      }))
    competences.value = [...duPoste, ...duPanel]
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

const familles = computed(() => {
  const groupes = []
  for (const c of competences.value) {
    let g = groupes.find((x) => x.nom === c.famille)
    if (!g) groupes.push((g = { nom: c.famille, items: [] }))
    g.items.push(c)
  }
  return groupes
})
const nbCochees = computed(() => competences.value.filter((c) => c.cochee).length)

function basculer(c) {
  if (!c.cochee && nbCochees.value >= MAX) {
    toast.alerte(`${MAX} compétences au plus par entretien.`)
    return
  }
  c.cochee = !c.cochee
}

const libelleSalarie = (s) => `${s.full_name} · ${s.position_title || '—'}`
const libelleCandidature = (c) => `${c.prenom} ${c.nom} · ${c.intitule} (${libelleEtape(c.etape)})`

function enTexte(d, heure) {
  const z = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${z(d.getMonth() + 1)}-${z(d.getDate())} ${heure}:00`
}

async function planifier() {
  const f = formulaire.value
  if (!cible.value || !(f.date instanceof Date) || !f.heure || !f.recruteurId) {
    toast.alerte("Choisissez la candidature, la date, l'heure et le recruteur.")
    return
  }
  if (nbCochees.value < 1 || nbCochees.value > MAX) {
    toast.alerte(`Cochez entre 1 et ${MAX} compétences à évaluer.`)
    return
  }
  const recruteur = salaries.value.find((s) => s.id === f.recruteurId)
  enregistrement.value = true
  let entretien = null
  try {
    entretien = await insert('entretiens', {
      candidature_id: cible.value.id,
      date_heure: enTexte(f.date, f.heure),
      lieu: f.lieu.trim() || null,
      recruteur_id: recruteur.id,
      recruteur_nom: recruteur.full_name,
    })
    for (const c of competences.value.filter((x) => x.cochee)) {
      await insert('entretien_competences', {
        entretien_id: entretien.id, source: c.source, competence_id: c.competence_id,
        libelle: c.libelle, famille: c.famille, niveau_attendu: c.niveau_attendu,
      })
    }
    await passerEnEntretien(cible.value, props.commentaire)
    toast.succes(
      `Entretien de ${cible.value.prenom} ${cible.value.nom} planifié le ` +
      `${f.date.toLocaleDateString('fr-FR')} à ${f.heure} avec ${recruteur.full_name} · ` +
      `${nbCochees.value} compétence(s) à évaluer`,
    )
    emit('planifie', entretien)
    emit('update:visible', false)
  } catch (erreur) {
    if (entretien) await remove('entretiens', entretien.id).catch(() => {}) // rien à moitié
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <Dialog :visible="visible" modal :style="{ width: '50rem' }"
          :header="candidature ? `Planifier un entretien · ${candidature.prenom} ${candidature.nom}` : 'Planifier un entretien'"
          @update:visible="(v) => emit('update:visible', v)">
    <form v-if="formulaire" class="formulaire" @submit.prevent="planifier">
      <template v-if="!candidature">
        <label for="candidature">Candidature</label>
        <Select inputId="candidature" v-model="choisie" :options="candidatures" :optionLabel="libelleCandidature"
                optionValue="id" filter placeholder="Une candidature au Tri de CV ou à l'Entretien" />
      </template>
      <p v-else class="aide">{{ candidature.intitule }}</p>

      <Message v-if="cible?.etape === 'preselection'" severity="info" :closable="false" size="small">
        Planifier cet entretien fera passer la candidature à « Entretien à réaliser ».
        Sans planification, elle reste au « Tri de CV ».
      </Message>

      <div class="trois">
        <div>
          <label for="date">Date</label>
          <DatePicker inputId="date" v-model="formulaire.date" dateFormat="dd/mm/yy" showIcon fluid
                      placeholder="jj/mm/aaaa" />
        </div>
        <div>
          <label for="heure">Heure</label>
          <Select inputId="heure" v-model="formulaire.heure" :options="CRENEAUX" fluid />
        </div>
        <div>
          <label for="recruteur">Recruteur</label>
          <Select inputId="recruteur" v-model="formulaire.recruteurId" :options="salaries"
                  :optionLabel="libelleSalarie" optionValue="id" filter fluid
                  :placeholder="cible ? `${salaries.length} salarié(s) de l'hôtel` : 'Choisir la candidature'"
                  :disabled="!cible" />
        </div>
      </div>

      <label for="lieu">Lieu ou lien visio</label>
      <InputText id="lieu" v-model="formulaire.lieu" placeholder="Bureau de la direction, salle de réunion, lien Teams…" />

      <div class="titre-competences">
        <label>Compétences à évaluer</label>
        <span :class="['compteur', { alerte: nbCochees < 1 }]">{{ nbCochees }} / {{ MAX }} cochée(s)</span>
      </div>
      <p v-if="!cible" class="aide">Choisissez d'abord la candidature.</p>
      <div v-else class="familles">
        <fieldset v-for="g in familles" :key="g.nom" class="famille" :class="{ poste: g.nom === 'Attendues sur le poste' }">
          <legend>{{ g.nom }}</legend>
          <div v-for="c in g.items" :key="c.cle" class="competence">
            <Checkbox :modelValue="c.cochee" binary :inputId="c.cle" @update:modelValue="basculer(c)" />
            <label :for="c.cle">{{ c.libelle }}</label>
            <Select v-if="c.cochee" v-model="c.niveau_attendu" :options="NIVEAUX" size="small"
                    class="niveau" v-tooltip.top="'Niveau attendu (1 à 4)'" />
          </div>
        </fieldset>
      </div>

      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="emit('update:visible', false)" />
        <Button label="Planifier l'entretien" icon="pi pi-calendar-plus" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; display: block; margin-bottom: .25rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: .25rem 0; }
.trois { display: grid; grid-template-columns: 11rem 7rem 1fr; gap: .75rem; }
.titre-competences { display: flex; align-items: baseline; gap: .75rem; margin-top: .5rem; }
.compteur { font-size: .8rem; color: var(--p-text-muted-color); }
.compteur.alerte { color: var(--p-red-500); font-weight: 600; }
.familles { display: grid; grid-template-columns: 1fr 1fr; gap: .6rem; }
.famille { border: 1px solid var(--p-surface-200); border-radius: 8px; padding: .4rem .7rem .5rem; margin: 0; }
.famille.poste { grid-column: 1 / -1; border-color: var(--p-primary-200); background: var(--p-primary-50); }
.famille legend { font-size: .78rem; font-weight: 600; color: var(--p-text-muted-color); padding: 0 .3rem; }
.competence { display: flex; align-items: center; gap: .45rem; min-height: 2rem; }
.formulaire .competence label { font-weight: 400; margin: 0; font-size: .85rem; flex: 1; cursor: pointer; }
.niveau { width: 4.5rem; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
