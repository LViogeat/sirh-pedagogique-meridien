/**
 * Ce que plusieurs écrans du module Mobilité partagent.
 *
 * Ce n'est pas un écran : un fichier .js (ou un .vue dont le nom commence
 * par « _ ») n'apparaît pas dans le menu.
 */
import { sql, update, getBesoins } from '@/socle/sdk'

/**
 * Les salariés qui ont un besoin de mobilité, un par salarié (son besoin le
 * plus récent), triés par nom. Chaque ligne est le besoin lui-même, avec
 * `libelle` pour une liste déroulante.
 */
export async function salariesAvecBesoin() {
  const besoins = await getBesoins({ typeBesoin: 'mobilite' })
  const parSalarie = new Map()
  for (const b of besoins) {
    const deja = parSalarie.get(b.employee_id)
    if (!deja || b.detected_on > deja.detected_on || (b.detected_on === deja.detected_on && b.id > deja.id)) {
      parSalarie.set(b.employee_id, b)
    }
  }
  return [...parSalarie.values()]
    .map((b) => ({ ...b, libelle: `${b.employee_name} — vise ${b.position_title}` }))
    .sort((a, b) => a.employee_name.localeCompare(b.employee_name))
}

// ── Les étapes d'un dossier, dans l'ordre ───────────────────────────────────

export const ETAPES = [
  { code: 'analyse', label: 'Analyse', severite: 'info' },
  { code: 'propositions', label: 'Propositions', severite: 'warn' },
  { code: 'entretien', label: 'Entretien', severite: 'warn' },
  { code: 'decision', label: 'Décision', severite: 'contrast' },
  { code: 'termine', label: 'Terminé', severite: 'success' },
]

export const etapeDe = (code) =>
  ETAPES.find((e) => e.code === code) || { code, label: code || '—', severite: 'secondary' }

const rang = (code) => ETAPES.findIndex((e) => e.code === code)

/**
 * Fait avancer un dossier à l'étape `cible`. Une étape ne recule jamais :
 * si le dossier est déjà plus loin, rien ne change.
 * Renvoie la nouvelle étape du dossier.
 */
export async function avancerEtape(dossier, cible) {
  if (rang(cible) <= rang(dossier.etape)) return dossier.etape
  await update('dossiers', dossier.id, { etape: cible })
  dossier.etape = cible
  return cible
}

// ── Les listes de valeurs du module ─────────────────────────────────────────

export const ISSUES = [
  { code: 'realisee', label: 'Réalisée', severite: 'success' },
  { code: 'refusee', label: 'Refusée', severite: 'danger' },
  { code: 'reportee', label: 'Reportée', severite: 'warn' },
  { code: 'abandonnee', label: 'Abandonnée', severite: 'secondary' },
]
export const issueDe = (code) => ISSUES.find((i) => i.code === code) || { label: code || '—', severite: 'secondary' }

export const TYPES_ECHANGE = [
  { code: 'entretien_carriere', label: 'Entretien de carrière', icone: 'pi pi-comments' },
  { code: 'appel', label: 'Appel', icone: 'pi pi-phone' },
  { code: 'mail', label: 'Mail', icone: 'pi pi-envelope' },
]
export const typeEchangeDe = (code) => TYPES_ECHANGE.find((t) => t.code === code) || { label: code, icone: 'pi pi-circle' }

export const STATUTS_PROPOSITION = {
  proposee: { label: 'Proposée', severite: 'info' },
  acceptee: { label: 'Acceptée', severite: 'success' },
  refusee: { label: 'Refusée', severite: 'danger' },
}

// ── Les dossiers, avec ce qu'en dit le socle ────────────────────────────────

/**
 * Tous les dossiers, avec le salarié, le poste et l'hôtel visés (lus dans le
 * socle par jointure). `filtre` est une condition SQL facultative, écrite en
 * dur dans l'écran (jamais une saisie de l'utilisateur).
 */
export function lireDossiers(filtre = 'true') {
  return sql(`
    select d.*,
           e.first_name || ' ' || e.last_name as salarie,
           e.matricule,
           n.position_id                      as poste_vise_id,
           p.title                            as poste_vise,
           n.establishment_id                 as hotel_vise_id,
           s.name                             as hotel_vise,
           n.review_id
      from dossiers d
      join public.identified_needs n on n.id = d.besoin_id
      join public.employees        e on e.id = d.employee_id
      join public.positions        p on p.id = n.position_id
      join public.establishments   s on s.id = n.establishment_id
     where ${filtre}
     order by d.ouvert_le desc, d.id desc
  `)
}

/** Libellé d'un dossier dans une liste déroulante. */
export const libelleDossier = (d) => `${d.salarie} → ${d.poste_vise} (${d.hotel_vise})`

// ── Les dates ───────────────────────────────────────────────────────────────

/** Nombre de jours entre deux dates ISO (« 2026-09-01 »). */
export function joursEntre(debut, fin) {
  if (!debut || !fin) return null
  return Math.max(0, Math.round((new Date(fin) - new Date(debut)) / 86400000))
}

/** Un objet Date (DatePicker) → « 2026-09-15 », sans décalage de fuseau. */
export function enDateIso(date) {
  if (!date) return null
  if (typeof date === 'string') return date.slice(0, 10)
  const mm = String(date.getMonth() + 1).padStart(2, '0')
  const jj = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${mm}-${jj}`
}

/** « 2026-09-15 » → objet Date à midi (pour un DatePicker). */
export const enDate = (iso) => (iso ? new Date(`${iso}T12:00:00`) : null)
