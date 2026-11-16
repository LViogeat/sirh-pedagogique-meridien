/**
 * Outils communs aux écrans du module gta. Ce n'est pas un écran : le nom
 * commence par « _ » et ce n'est pas un .vue, il n'apparaît donc pas au menu.
 */
import { ref, watch } from 'vue'
import { sql, sqlScript } from '@/socle/sdk'
import schema from './schema.sql?raw'

let preparation = null

/**
 * Crée les tables du module si elles n'existent pas encore (schema.sql est
 * rejouable). Appelé à l'ouverture de chaque écran : après une remise à zéro
 * du schéma, les écrans se réparent tout seuls. Une seule fois par session.
 */
export function preparerSchema() {
  if (!preparation) {
    preparation = sqlScript(schema).catch((erreur) => {
      preparation = null
      throw erreur
    })
  }
  return preparation
}

/** « 07:00:00 » → « 07:00 » */
export const heure = (valeur) => (valeur ? String(valeur).slice(0, 5) : '')

const enMinutes = (valeur) => {
  const [h, m] = heure(valeur).split(':').map(Number)
  return h * 60 + m
}

/**
 * Durée travaillée d'un code horaire, en minutes, pause déduite.
 * Une fin avant le début veut dire que la plage passe minuit.
 */
export function dureeMinutes(code) {
  if (!code?.heure_debut || !code?.heure_fin) return 0
  let duree = enMinutes(code.heure_fin) - enMinutes(code.heure_debut)
  if (duree <= 0) duree += 24 * 60
  return Math.max(0, duree - (Number(code.pause_minutes) || 0))
}

/** 450 → « 7 h 30 » ; 2100 → « 35 h » */
export function formatDuree(minutes) {
  const h = Math.floor(minutes / 60)
  const m = Math.round(minutes % 60)
  return m ? `${h} h ${String(m).padStart(2, '0')}` : `${h} h`
}

export const JOURS = [
  { cle: 'lundi_id', libelle: 'Lundi', court: 'Lun' },
  { cle: 'mardi_id', libelle: 'Mardi', court: 'Mar' },
  { cle: 'mercredi_id', libelle: 'Mercredi', court: 'Mer' },
  { cle: 'jeudi_id', libelle: 'Jeudi', court: 'Jeu' },
  { cle: 'vendredi_id', libelle: 'Vendredi', court: 'Ven' },
  { cle: 'samedi_id', libelle: 'Samedi', court: 'Sam' },
  { cle: 'dimanche_id', libelle: 'Dimanche', court: 'Dim' },
]

/** Une date JavaScript → « 2026-11-16 », sans décalage de fuseau. */
export function versDateIso(date) {
  if (!date) return null
  if (typeof date === 'string') return date.slice(0, 10)
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const jj = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${mm}-${jj}`
}

// ── Sprint 2 : la journée ────────────────────────────────────────────────────


/** Aujourd'hui, selon l'horloge du poste : « 2026-11-16 ». */
export const aujourdhui = () => versDateIso(new Date())

/** L'heure du poste : « 08:57:12 ». */
export function heureActuelle() {
  const d = new Date()
  return [d.getHours(), d.getMinutes(), d.getSeconds()]
    .map((n) => String(n).padStart(2, '0')).join(':')
}

/** Le jour de la semaine d'une date ISO, comme entrée de JOURS (lundi = 0). */
export function jourDeSemaine(dateIso) {
  const d = new Date(`${dateIso}T12:00:00`)
  return JOURS[(d.getDay() + 6) % 7]
}

/**
 * Le collaborateur qui utilise l'application.
 *
 * L'application n'a pas de connexion : le collaborateur se choisit dans la
 * liste, et le choix est retenu par le navigateur. Partagé par tous les écrans.
 */
const CLE_SALARIE = 'gta.salarieCourant'
function lireSalarieRetenu() {
  try { return Number(localStorage.getItem(CLE_SALARIE)) || null } catch { return null }
}
export const salarieCourantId = ref(lireSalarieRetenu())
watch(salarieCourantId, (id) => {
  try {
    if (id) localStorage.setItem(CLE_SALARIE, String(id))
    else localStorage.removeItem(CLE_SALARIE)
  } catch { /* navigation privée : le choix ne sera simplement pas retenu */ }
})

/**
 * L'horaire prévu un jour donné, pour une liste de salariés.
 * Renvoie { [employee_id]: { profil, code } } :
 *   - pas d'entrée     → aucun profil affecté à cette date
 *   - code null        → jour de repos dans son profil
 */
export async function horairesDuJour(employeeIds, jour) {
  if (!employeeIds.length) return {}
  const lignes = await sql(`
    select distinct on (a.employee_id)
           a.employee_id, a.date_debut,
           p.id as profil_id, p.code as profil_code, p.libelle as profil_libelle,
           p.lundi_id, p.mardi_id, p.mercredi_id, p.jeudi_id,
           p.vendredi_id, p.samedi_id, p.dimanche_id
    from affectations_profil a
    join profils_horaires p on p.id = a.profil_id
    where a.date_debut <= :jour and a.employee_id = any(:ids)
    order by a.employee_id, a.date_debut desc, a.id desc`,
  { jour, ids: employeeIds })
  const codes = Object.fromEntries(
    (await sql('select * from codes_horaires')).map((c) => [c.id, c]))
  const cle = jourDeSemaine(jour).cle
  return Object.fromEntries(lignes.map((l) => [l.employee_id, {
    profil: { id: l.profil_id, code: l.profil_code, libelle: l.profil_libelle },
    code: codes[l[cle]] ?? null,
  }]))
}

/** Les pointages d'un jour, rangés par salarié et dans l'ordre. */
export async function pointagesDuJour(employeeIds, jour) {
  if (!employeeIds.length) return {}
  const lignes = await sql(`
    select * from pointages
    where jour = :jour and employee_id = any(:ids)
    order by employee_id, heure, id`,
  { jour, ids: employeeIds })
  const parSalarie = {}
  for (const p of lignes) (parSalarie[p.employee_id] ??= []).push(p)
  return parSalarie
}

/**
 * Le libellé de chaque pointage d'une journée, d'après sa place :
 * Arrivée, Début de pause, Fin de pause, Départ.
 * Tant que la journée n'est pas finie, la dernière sortie compte comme départ.
 */
export function libellerPointages(pointages) {
  return pointages.map((p, i) => {
    let libelle
    if (p.sens === 'entree') libelle = i === 0 ? 'Arrivée' : 'Fin de pause'
    else libelle = i === pointages.length - 1 ? 'Départ' : 'Début de pause'
    return { ...p, libelle }
  })
}

/** Le prochain sens à pointer, d'après le dernier pointage du jour. */
export const prochainSens = (pointages) =>
  pointages.at(-1)?.sens === 'entree' ? 'sortie' : 'entree'

/** Temps de présence d'une journée, en minutes (entrée → sortie, pauses exclues). */
export function presenceMinutes(pointages, heureFin = null) {
  let total = 0
  let entree = null
  const minutes = (h) => { const [hh, mm] = heure(h).split(':').map(Number); return hh * 60 + mm }
  for (const p of pointages) {
    if (p.sens === 'entree') entree = minutes(p.heure)
    else if (entree !== null) { total += minutes(p.heure) - entree; entree = null }
  }
  if (entree !== null && heureFin) total += Math.max(0, minutes(heureFin) - entree)
  return total
}
