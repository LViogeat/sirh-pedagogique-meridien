<script setup>
/**
 * La boîte de dialogue « Planifier un entretien » (story #106).
 *
 * Utilisée depuis le Pipeline (la candidature est déjà connue) et depuis
 * l'écran Entretiens (on choisit d'abord la candidature). Le recruteur est un
 * salarié du socle, proposé parmi ceux de l'hôtel de l'offre.
 *
 * Si la candidature n'a pas encore atteint l'étape « Entretien », elle y passe.
 */
import { ref, watch, computed } from 'vue'
import { getSalaries, sql, insert, toast } from '@/socle/sdk'

const props = defineProps({
  visible: { type: Boolean, default: false },
  candidature: { type: Object, default: null }, // { id, prenom, nom, intitule, establishment_id, etape }
})
const emit = defineEmits(['update:visible', 'planifie'])

const candidatures = ref([])
const choisie = ref(null)
const salaries = ref([])
const formulaire = ref(null)
const enregistrement = ref(false)

const cible = computed(() => props.candidature || candidatures.value.find((c) => c.id === choisie.value) || null)

watch(() => props.visible, async (ouvert) => {
  if (!ouvert) return
  const demain = new Date()
  demain.setDate(demain.getDate() + 1)
  demain.setHours(0, 0, 0, 0)
  formulaire.value = { date: demain, heure: '10:00', lieu: '', recruteurId: null }
  choisie.value = null
  salaries.value = []
  if (!props.candidature) {
    try {
      candidatures.value = await sql(
        `select ca.id, ca.etape, c.prenom, c.nom, o.intitule, o.establishment_id
           from candidatures ca
           join candidats c on c.id = ca.candidat_id
           join offres o on o.id = ca.offre_id
          where ca.etape not in ('embauche', 'refus') and o.statut = 'publiee'
          order by c.nom, c.prenom`,
      )
    } catch (erreur) {
      toast.erreur(erreur.message)
    }
  }
}, { immediate: true })

watch(cible, async (c) => {
  salaries.value = []
  if (!c || !formulaire.value) return
  formulaire.value.recruteurId = null
  try {
    salaries.value = (await getSalaries({ etablissementId: c.establishment_id }))
      .sort((a, b) => (b.hierarchy_level ?? 0) - (a.hierarchy_level ?? 0) || a.last_name.localeCompare(b.last_name))
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}, { immediate: true })

/* Créneaux d'un quart d'heure, de 7 h à 20 h. */
const CRENEAUX = Array.from({ length: 53 }, (_, i) => {
  const minutes = 7 * 60 + i * 15
  return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`
})

const libelleSalarie = (s) => `${s.full_name} · ${s.position_title || '—'}`
const libelleCandidature = (c) => `${c.prenom} ${c.nom} · ${c.intitule}`

/** Date locale « 2026-11-20 10:00:00 », sans conversion de fuseau. */
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
  const recruteur = salaries.value.find((s) => s.id === f.recruteurId)
  enregistrement.value = true
  try {
    const entretien = await insert('entretiens', {
      candidature_id: cible.value.id,
      date_heure: enTexte(f.date, f.heure),
      lieu: f.lieu.trim() || null,
      recruteur_id: recruteur.id,
      recruteur_nom: recruteur.full_name,
    })
    if (['nouvelle', 'preselection'].includes(cible.value.etape)) {
      await sql(
        "update candidatures set etape = 'entretien', maj_le = current_date where id = :id",
        { id: cible.value.id },
      )
    }
    toast.succes(
      `Entretien de ${cible.value.prenom} ${cible.value.nom} planifié le ` +
      `${f.date.toLocaleDateString('fr-FR')} à ${f.heure} ` +
      `avec ${recruteur.full_name}`,
    )
    emit('planifie', entretien)
    emit('update:visible', false)
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <Dialog :visible="visible" modal :style="{ width: '34rem' }"
          :header="candidature ? `Planifier un entretien · ${candidature.prenom} ${candidature.nom}` : 'Planifier un entretien'"
          @update:visible="(v) => emit('update:visible', v)">
    <form v-if="formulaire" class="formulaire" @submit.prevent="planifier">
      <template v-if="!candidature">
        <label for="candidature">Candidature</label>
        <Select inputId="candidature" v-model="choisie" :options="candidatures" :optionLabel="libelleCandidature"
                optionValue="id" filter placeholder="Choisir une candidature en cours" />
      </template>
      <p v-else class="aide">{{ candidature.intitule }}</p>

      <div class="deux">
        <div>
          <label for="date">Date</label>
          <DatePicker inputId="date" v-model="formulaire.date" dateFormat="dd/mm/yy" showIcon fluid
                      placeholder="jj/mm/aaaa" />
        </div>
        <div>
          <label for="heure">Heure</label>
          <Select inputId="heure" v-model="formulaire.heure" :options="CRENEAUX" fluid />
        </div>
      </div>

      <label for="recruteur">Recruteur</label>
      <Select inputId="recruteur" v-model="formulaire.recruteurId" :options="salaries"
              :optionLabel="libelleSalarie" optionValue="id" filter
              :placeholder="cible ? `${salaries.length} salarié(s) de l'hôtel` : 'Choisir d’abord la candidature'"
              :disabled="!cible" />

      <label for="lieu">Lieu ou lien visio</label>
      <InputText id="lieu" v-model="formulaire.lieu" placeholder="Bureau de la direction, salle de réunion, lien Teams…" />

      <p v-if="cible && ['nouvelle', 'preselection'].includes(cible.etape)" class="aide">
        <i class="pi pi-info-circle" /> La candidature passera à l'étape « Entretien ».
      </p>

      <div class="pied">
        <Button label="Fermer" severity="secondary" text type="button" @click="emit('update:visible', false)" />
        <Button label="Planifier" icon="pi pi-calendar-plus" type="submit" :loading="enregistrement" />
      </div>
    </form>
  </Dialog>
</template>

<style scoped>
.formulaire { display: flex; flex-direction: column; gap: .35rem; }
.formulaire label { font-size: .85rem; font-weight: 600; margin-top: .6rem; display: block; margin-bottom: .25rem; }
.deux { display: grid; grid-template-columns: 1fr 9rem; gap: .75rem; }
.aide { font-size: .85rem; color: var(--p-text-muted-color); margin: .25rem 0 0; }
.pied { display: flex; justify-content: flex-end; gap: .5rem; margin-top: 1.25rem; }
</style>
