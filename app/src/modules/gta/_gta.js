/**
 * Outils communs aux écrans du module gta. Ce n'est pas un écran : le nom
 * commence par « _ » et ce n'est pas un .vue, il n'apparaît donc pas au menu.
 */
import { sqlScript } from '@/socle/sdk'
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
