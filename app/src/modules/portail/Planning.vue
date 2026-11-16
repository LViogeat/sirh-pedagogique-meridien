<!-- libelle: Planning -->
<script setup>
/* =============================================================================
   Story #68 — Planning : absences, présences, télétravail (collaborateur/manager)

   Sur un même écran, pour la semaine choisie :
     - le compteur d'heures (solde = heures réalisées − heures prévues),
     - les jours de télétravail et le statut des demandes,
     - le planning individuel, ou celui de l'équipe.

   D'où viennent les données :
     - le socle : salariés, managers, temps de travail du contrat ;
     - nos tables : demandes_absence (#41), demandes_teletravail, heures_realisees.

   Règles de calcul :
     - un jour ouvré (lundi → vendredi) prévoit 7 h × le temps de travail
       du contrat ; le week-end et un jour d'absence ne prévoient rien ;
     - un jour sans heures saisies compte pour ses heures prévues ;
     - une demande refusée n'apparaît pas dans le planning.

   L'équipe : un manager voit ses collaborateurs directs ; un collaborateur
   voit les personnes qui ont le même manager que lui.
   ========================================================================== */

import { ref, computed, onMounted, watch } from 'vue'
import { getSalaries, getDateReference, sql, formatDate, toast } from '@/socle/sdk'

const HEURES_JOUR = 7
const JOURS = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']

const TYPES_ABSENCE = {
  conges_annuels: 'Congés annuels',
  rtt: 'RTT',
  evenement_familial: 'Événement familial',
  conge_sans_solde: 'Congé sans solde',
  absence_remuneree: 'Absence rémunérée',
  absence_non_remuneree: 'Absence non rémunérée',
}

const STATUTS_DEMANDE = {
  envoyee: { label: 'En attente', severite: 'warn' },
  validee: { label: 'Validée', severite: 'success' },
  refusee: { label: 'Refusée', severite: 'danger' },
}

/* ── Les dates, sans fuseau horaire : tout se manipule en « 2026-11-16 » ──── */
const p2 = (n) => String(n).padStart(2, '0')
const enIso = (d) => `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`
const depuisIso = (s) => { const [a, m, j] = s.slice(0, 10).split('-').map(Number); return new Date(a, m - 1, j) }
function ajouterJours(iso, n) { const d = depuisIso(iso); d.setDate(d.getDate() + n); return enIso(d) }
function lundiDe(iso) { const d = depuisIso(iso); return ajouterJours(iso, -((d.getDay() + 6) % 7)) }
const jourCourt = (iso) => `${p2(depuisIso(iso).getDate())}/${p2(depuisIso(iso).getMonth() + 1)}`

/** 1.5 → « +1 h 30 » */
function enHeures(h, signe = false) {
  const minutes = Math.round(Math.abs(h) * 60)
  const texte = `${Math.floor(minutes / 60)} h${minutes % 60 ? ' ' + p2(minutes % 60) : ''}`
  if (!signe) return texte
  return (h > 0.001 ? '+' : h < -0.001 ? '−' : '') + texte
}

/* ── L'état de l'écran ─────────────────────────────────────────────────────── */
const salaries = ref([])
const salarieId = ref(null)
const aujourdhui = ref(enIso(new Date()))
const lundi = ref(lundiDe(aujourdhui.value))
const vue = ref('moi')                        // 'moi' | 'equipe'
const chargement = ref(false)

const absences = ref([])
const teletravail = ref([])
const heures = ref([])
const mesDemandesTeletravail = ref([])

const jourTeletravail = ref(null)
const envoiTeletravail = ref(false)

const salarie = computed(() => salaries.value.find((s) => s.id === salarieId.value))
const jours = computed(() => JOURS.map((nom, i) => ({ nom, iso: ajouterJours(lundi.value, i), weekend: i >= 5 })))
const dimanche = computed(() => ajouterJours(lundi.value, 6))

const estManager = computed(() => salaries.value.some((s) => s.manager_id === salarieId.value))
const equipe = computed(() => {
  if (!salarie.value) return []
  const membres = estManager.value
    ? salaries.value.filter((s) => s.manager_id === salarie.value.id)
    : salaries.value.filter((s) => s.manager_id === salarie.value.manager_id && s.id !== salarie.value.id)
  return [salarie.value, ...membres.sort((a, b) => a.last_name.localeCompare(b.last_name))]
})
const libelleEquipe = computed(() =>
  estManager.value ? 'Mon équipe (mes collaborateurs directs)' : `Mon équipe (manager : ${salarie.value?.manager_name || '—'})`,
)

/* ── Le chargement ─────────────────────────────────────────────────────────── */
async function charger() {
  if (!salarie.value) return
  chargement.value = true
  const params = { ids: equipe.value.map((s) => s.id).join(','), debut: lundi.value, fin: dimanche.value }
  const dansEquipe = "salarie_id = any(string_to_array(:ids, ',')::int[])"
  try {
    ;[absences.value, teletravail.value, heures.value, mesDemandesTeletravail.value] = await Promise.all([
      sql(`select salarie_id, type_absence, statut, date_debut::text as date_debut, date_fin::text as date_fin
             from demandes_absence
            where ${dansEquipe} and statut <> 'refusee' and date_debut <= :fin and date_fin >= :debut`, params),
      sql(`select salarie_id, jour::text as jour, statut from demandes_teletravail
            where ${dansEquipe} and statut <> 'refusee' and jour between :debut and :fin`, params),
      sql(`select jour::text as jour, heures::float as heures from heures_realisees
            where salarie_id = :id and jour between :debut and :fin`, { ...params, id: salarie.value.id }),
      sql(`select id, jour::text as jour, statut, envoyee_le from demandes_teletravail
            where salarie_id = :id order by jour desc limit 20`, { id: salarie.value.id }),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

onMounted(async () => {
  try {
    const [liste, dateRef] = await Promise.all([getSalaries(), getDateReference()])
    salaries.value = liste
    if (dateRef) { aujourdhui.value = dateRef; lundi.value = lundiDe(dateRef) }
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
})
watch([salarieId, lundi], charger)

/* ── Le statut d'une personne pour un jour ────────────────────────────────── */
function statutDuJour(personneId, jour) {
  if (jour.weekend) return { code: 'repos', label: 'Repos', attente: false }
  const absence = absences.value.find(
    (a) => a.salarie_id === personneId && a.date_debut <= jour.iso && a.date_fin >= jour.iso,
  )
  if (absence) {
    return { code: 'absence', label: TYPES_ABSENCE[absence.type_absence] || 'Absence', attente: absence.statut === 'envoyee' }
  }
  const tt = teletravail.value.find((t) => t.salarie_id === personneId && t.jour === jour.iso)
  if (tt) return { code: 'teletravail', label: 'Télétravail', attente: tt.statut === 'envoyee' }
  return { code: 'present', label: 'Sur site', attente: false }
}

/* ── Le planning individuel et le compteur d'heures ───────────────────────── */
const lignesIndividuelles = computed(() => {
  if (!salarie.value) return []
  const ratio = Number(salarie.value.work_time_ratio) || 1
  return jours.value.map((jour) => {
    const statut = statutDuJour(salarie.value.id, jour)
    const prevues = jour.weekend || statut.code === 'absence' ? 0 : HEURES_JOUR * ratio
    const saisie = heures.value.find((h) => h.jour === jour.iso)
    return { ...jour, statut, prevues, saisie: saisie ? saisie.heures : null }
  })
})

const compteur = computed(() => {
  const prevues = lignesIndividuelles.value.reduce((t, l) => t + l.prevues, 0)
  const realisees = lignesIndividuelles.value.reduce((t, l) => t + (l.saisie ?? l.prevues), 0)
  return {
    prevues, realisees, solde: realisees - prevues,
    teletravail: lignesIndividuelles.value.filter((l) => l.statut.code === 'teletravail').length,
    absences: lignesIndividuelles.value.filter((l) => l.statut.code === 'absence').length,
  }
})

async function enregistrerHeures(ligne, valeur) {
  try {
    if (valeur === null || valeur === undefined) {
      await sql('delete from heures_realisees where salarie_id = :s and jour = :j', { s: salarie.value.id, j: ligne.iso })
    } else {
      await sql(
        `insert into heures_realisees (salarie_id, jour, heures) values (:s, :j, :h)
         on conflict (salarie_id, jour) do update set heures = excluded.heures`,
        { s: salarie.value.id, j: ligne.iso, h: valeur },
      )
    }
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  }
}

/* ── Demander un jour de télétravail ──────────────────────────────────────── */
async function demanderTeletravail() {
  if (!jourTeletravail.value || !salarie.value) return
  const jour = enIso(jourTeletravail.value)
  const d = jourTeletravail.value.getDay()
  if (d === 0 || d === 6) { toast.alerte('Le télétravail se demande pour un jour ouvré.'); return }
  envoiTeletravail.value = true
  try {
    const lignes = await sql(
      `insert into demandes_teletravail (salarie_id, manager_id, jour) values (:s, :m, :j)
       on conflict (salarie_id, jour) do nothing returning id`,
      { s: salarie.value.id, m: salarie.value.manager_id, j: jour },
    )
    if (lignes.length) {
      toast.succes(`Télétravail du ${formatDate(jour)} demandé à ${salarie.value.manager_name || 'votre manager'}.`, 'Demande envoyée')
    } else {
      toast.info(`Une demande existe déjà pour le ${formatDate(jour)}.`)
    }
    jourTeletravail.value = null
    await charger()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    envoiTeletravail.value = false
  }
}

/* ── La navigation de semaine en semaine ─────────────────────────────────── */
const semainePrecedente = () => { lundi.value = ajouterJours(lundi.value, -7) }
const semaineSuivante = () => { lundi.value = ajouterJours(lundi.value, 7) }
const cetteSemaine = () => { lundi.value = lundiDe(aujourdhui.value) }
const dateChoisie = computed({
  get: () => depuisIso(lundi.value),
  set: (d) => { if (d) lundi.value = lundiDe(enIso(d)) },
})
</script>

<template>
  <PageHeader
    titre="Planning"
    sousTitre="Mon compteur d'heures, mes jours de télétravail, mon planning et celui de mon équipe."
  />

  <!-- Qui consulte -->
  <div class="carte barre">
    <label class="champ">
      <span>Collaborateur</span>
      <Select v-model="salarieId" :options="salaries" optionLabel="full_name" optionValue="id"
              filter placeholder="Choisir le collaborateur" class="large" />
    </label>
    <p v-if="salarie" class="discret">
      {{ salarie.position_title }} · {{ salarie.establishment_name }}
      · temps de travail {{ Math.round((Number(salarie.work_time_ratio) || 1) * 100) }} %
      <template v-if="estManager"> · <Tag value="Manager" severity="secondary" /></template>
    </p>
  </div>

  <template v-if="salarie">
    <!-- La semaine affichée -->
    <div class="semaine">
      <Button icon="pi pi-chevron-left" text rounded aria-label="Semaine précédente" @click="semainePrecedente" />
      <strong>Semaine du {{ formatDate(lundi) }} au {{ formatDate(dimanche) }}</strong>
      <Button icon="pi pi-chevron-right" text rounded aria-label="Semaine suivante" @click="semaineSuivante" />
      <DatePicker v-model="dateChoisie" dateFormat="dd/mm/yy" showIcon iconDisplay="input"
                  :manualInput="false" class="choix-date" />
      <Button label="Cette semaine" size="small" outlined @click="cetteSemaine" />
    </div>

    <!-- Le compteur -->
    <div class="compteurs">
      <div class="compteur" :class="{ positif: compteur.solde > 0.001, negatif: compteur.solde < -0.001 }">
        <span>Solde d'heures de la semaine</span>
        <strong>{{ enHeures(compteur.solde, true) }}</strong>
        <small>{{ enHeures(compteur.realisees) }} réalisées / {{ enHeures(compteur.prevues) }} prévues</small>
      </div>
      <div class="compteur">
        <span>Jours de télétravail</span>
        <strong>{{ compteur.teletravail }}</strong>
        <small>sur cette semaine</small>
      </div>
      <div class="compteur">
        <span>Jours d'absence</span>
        <strong>{{ compteur.absences }}</strong>
        <small>sur cette semaine</small>
      </div>
    </div>

    <!-- Mon planning / Mon équipe -->
    <div class="carte">
      <SelectButton v-model="vue" :allowEmpty="false" optionLabel="label" optionValue="code"
                    :options="[{ code: 'moi', label: 'Mon planning' }, { code: 'equipe', label: 'Mon équipe' }]" />

      <!-- Planning individuel -->
      <DataTable v-if="vue === 'moi'" :value="lignesIndividuelles" :loading="chargement" dataKey="iso"
                 size="small" class="tableau" :rowClass="(l) => (l.weekend ? 'weekend' : '')">
        <Column header="Jour">
          <template #body="{ data }"><strong>{{ data.nom }}</strong> {{ jourCourt(data.iso) }}</template>
        </Column>
        <Column header="Statut">
          <template #body="{ data }">
            <span class="pastille" :class="data.statut.code">{{ data.statut.label }}</span>
            <small v-if="data.statut.attente" class="attente">en attente de validation</small>
          </template>
        </Column>
        <Column header="Heures prévues">
          <template #body="{ data }">{{ data.prevues ? enHeures(data.prevues) : '—' }}</template>
        </Column>
        <Column header="Heures réalisées">
          <template #body="{ data }">
            <InputNumber v-if="!data.weekend || data.saisie !== null" :modelValue="data.saisie"
                         :placeholder="data.prevues ? String(data.prevues) : '0'"
                         :min="0" :max="24" :maxFractionDigits="2" suffix=" h" inputClass="saisie"
                         @update:modelValue="(v) => enregistrerHeures(data, v)" />
          </template>
        </Column>
      </DataTable>

      <!-- Planning d'équipe -->
      <template v-else>
        <p class="discret">{{ libelleEquipe }} — {{ equipe.length }} personne(s)</p>
        <div class="grille-equipe">
          <table>
            <thead>
              <tr>
                <th>Salarié</th>
                <th v-for="jour in jours" :key="jour.iso" :class="{ weekend: jour.weekend }">
                  {{ jour.nom.slice(0, 3) }}. {{ jourCourt(jour.iso) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="personne in equipe" :key="personne.id" :class="{ moi: personne.id === salarie.id }">
                <td class="nom">
                  {{ personne.full_name }}
                  <small>{{ personne.position_title }}</small>
                </td>
                <td v-for="jour in jours" :key="jour.iso" :class="{ weekend: jour.weekend }">
                  <template v-for="s in [statutDuJour(personne.id, jour)]" :key="s.code">
                    <span v-if="s.code !== 'repos'" class="pastille" :class="[s.code, { pointille: s.attente }]"
                          v-tooltip.top="s.attente ? s.label + ' (en attente)' : s.label">
                      {{ s.label }}
                    </span>
                  </template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p class="legende">
          <span class="pastille present">Sur site</span>
          <span class="pastille teletravail">Télétravail</span>
          <span class="pastille absence">Absence</span>
          <span class="pastille teletravail pointille">En attente de validation</span>
        </p>
      </template>
    </div>

    <!-- Mes demandes de télétravail -->
    <div class="carte">
      <h2>Mes demandes de télétravail</h2>
      <div class="ligne-demande">
        <DatePicker v-model="jourTeletravail" dateFormat="dd/mm/yy" showIcon :manualInput="false"
                    placeholder="Choisir un jour" />
        <Button label="Demander ce jour en télétravail" icon="pi pi-send" :loading="envoiTeletravail"
                :disabled="!jourTeletravail" @click="demanderTeletravail" />
      </div>
      <DataTable :value="mesDemandesTeletravail" dataKey="id" size="small" stripedRows>
        <template #empty>Aucune demande de télétravail.</template>
        <Column header="Jour">
          <template #body="{ data }">{{ formatDate(data.jour, 'long') }}</template>
        </Column>
        <Column header="Demandée le">
          <template #body="{ data }">{{ formatDate(data.envoyee_le) }}</template>
        </Column>
        <Column header="Statut">
          <template #body="{ data }">
            <Tag :value="STATUTS_DEMANDE[data.statut]?.label || data.statut"
                 :severity="STATUTS_DEMANDE[data.statut]?.severite || 'secondary'" />
          </template>
        </Column>
      </DataTable>
    </div>
  </template>
</template>

<style scoped>
.carte {
  background: var(--p-content-background, #fff);
  border: 1px solid var(--p-content-border-color, #e2e8f0);
  border-radius: 8px;
  padding: 1rem 1.25rem;
  margin-bottom: 1rem;
}
h2 { font-size: 1.05rem; margin: 0 0 0.75rem; }
.champ { display: flex; flex-direction: column; gap: 0.35rem; }
.champ > span { font-size: 0.85rem; font-weight: 600; }
.large { max-width: 28rem; }
.discret { color: var(--p-text-muted-color, #64748b); margin: 0.5rem 0 0; }

.semaine { display: flex; align-items: center; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1rem; }
.choix-date { width: 11rem; margin-left: auto; }

.compteurs { display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr)); gap: 1rem; margin-bottom: 1rem; }
.compteur {
  display: flex; flex-direction: column; gap: 0.2rem;
  background: var(--p-content-background, #fff);
  border: 1px solid var(--p-content-border-color, #e2e8f0);
  border-radius: 8px; padding: 0.9rem 1.1rem;
}
.compteur span { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.03em; color: var(--p-text-muted-color, #64748b); }
.compteur strong { font-size: 1.6rem; }
.compteur small { color: var(--p-text-muted-color, #64748b); }
.compteur.positif strong { color: #15803d; }
.compteur.negatif strong { color: #b91c1c; }

.tableau { margin-top: 1rem; }
:deep(tr.weekend) { color: var(--p-text-muted-color, #94a3b8); }
:deep(.saisie) { width: 6.5rem; }
.attente { margin-left: 0.5rem; color: #b45309; }

.pastille {
  display: inline-block; padding: 0.15rem 0.5rem; border-radius: 999px;
  font-size: 0.78rem; font-weight: 600; border: 1px solid transparent; white-space: nowrap;
}
.pastille.present { background: #e0f2fe; color: #075985; }
.pastille.teletravail { background: #dcfce7; color: #166534; }
.pastille.absence { background: #fee2e2; color: #991b1b; }
.pastille.repos { background: #f1f5f9; color: #64748b; }
.pastille.pointille { background: transparent; border: 1px dashed currentColor; }

.grille-equipe { overflow-x: auto; }
.grille-equipe table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.grille-equipe th, .grille-equipe td { padding: 0.45rem 0.4rem; border-bottom: 1px solid var(--p-content-border-color, #e2e8f0); text-align: center; }
.grille-equipe th { font-weight: 600; white-space: nowrap; }
.grille-equipe td.nom { text-align: left; min-width: 12rem; }
.grille-equipe td.nom small { display: block; color: var(--p-text-muted-color, #64748b); }
.grille-equipe .weekend { background: var(--p-content-hover-background, #f8fafc); }
.grille-equipe tr.moi td.nom { font-weight: 700; }
.legende { display: flex; flex-wrap: wrap; gap: 0.5rem; margin: 0.75rem 0 0; }

.ligne-demande { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 0.75rem; }
</style>
