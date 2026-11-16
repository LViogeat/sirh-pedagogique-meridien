/**
 * Ce que les écrans du module Formation ont en commun.
 *
 * Ce fichier n'est pas un écran (son nom commence par « _ ») : il regroupe
 * les listes de valeurs, quelques petites fonctions de dates, et la mise en
 * place des tables du schéma « form ».
 */
import { ref, watch } from 'vue'
import { sql, sqlScript, MODULE_CODE } from '@/socle/sdk'
import schema from './schema.sql?raw'

// ── Les tables ───────────────────────────────────────────────────────────────

const TABLES = ['formations', 'obligations', 'sessions', 'inscriptions']
let preparation = null

/**
 * Vérifie que les quatre tables du module existent, et applique schema.sql
 * si ce n'est pas le cas. Chaque écran l'appelle avant sa première requête :
 * le module marche donc même si personne n'a joué le script dans la Console.
 */
export function preparerSchema() {
  if (!preparation) {
    preparation = (async () => {
      const lignes = await sql(
        `select count(*) as nombre
         from   information_schema.tables
         where  table_schema = :schema
         and    table_name in ('formations', 'obligations', 'sessions', 'inscriptions')`,
        { schema: MODULE_CODE },
      )
      if (Number(lignes[0]?.nombre) < TABLES.length) await sqlScript(schema)
    })().catch((erreur) => {
      preparation = null
      throw erreur
    })
  }
  return preparation
}

// ── Les listes de valeurs ────────────────────────────────────────────────────

export const MODALITES = [
  { code: 'presentiel', label: 'Présentiel' },
  { code: 'distanciel', label: 'Distanciel' },
  { code: 'mixte', label: 'Mixte' },
]

export const STATUTS_SESSION = [
  { code: 'ouverte', label: 'Ouverte aux inscriptions', severity: 'success' },
  { code: 'fermee', label: 'Inscriptions fermées', severity: 'warn' },
  { code: 'terminee', label: 'Terminée', severity: 'secondary' },
  { code: 'annulee', label: 'Annulée', severity: 'danger' },
]

export const STATUTS_INSCRIPTION = [
  { code: 'demandee', label: 'En attente de validation', severity: 'warn' },
  { code: 'validee', label: 'Inscrit', severity: 'success' },
  { code: 'refusee', label: 'Refusée', severity: 'danger' },
  { code: 'annulee', label: 'Annulée', severity: 'secondary' },
]

export const PRESENCES = [
  { code: 'present', label: 'Présent', severity: 'success' },
  { code: 'absent', label: 'Absent', severity: 'danger' },
  { code: 'absent_justifie', label: 'Absent justifié', severity: 'warn' },
]

/** Dans la table obligations : la formation est obligatoire pour tous les postes. */
export const TOUS_LES_METIERS = 'Tous'

/** libelle(STATUTS_SESSION, 'ouverte') → 'Ouverte aux inscriptions' */
export function libelle(liste, code) {
  return liste.find((v) => v.code === code)?.label ?? code ?? '—'
}

/** couleur(STATUTS_SESSION, 'ouverte') → 'success' (pour un <Tag>) */
export function couleur(liste, code) {
  return liste.find((v) => v.code === code)?.severity ?? 'secondary'
}

// ── Les dates et les heures ──────────────────────────────────────────────────

/** Une date choisie dans un DatePicker → '2026-12-03', ce qu'attend la base. */
export function enIso(date) {
  if (!date) return null
  if (typeof date === 'string') return date.slice(0, 10)
  const mois = String(date.getMonth() + 1).padStart(2, '0')
  const jour = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${mois}-${jour}`
}

/** '2026-12-03' → un objet Date, pour préremplir un DatePicker. */
export function enDate(iso) {
  if (!iso) return null
  const [annee, mois, jour] = String(iso).slice(0, 10).split('-').map(Number)
  return new Date(annee, mois - 1, jour)
}

/** '09:00:00' → '09:00' */
export function heure(valeur) {
  return valeur ? String(valeur).slice(0, 5) : '—'
}

/** '9 h à 17 h' d'une session, en clair. */
export function horaires(session) {
  return `${heure(session.heure_debut)} – ${heure(session.heure_fin)}`
}

/** Les dates d'une session : un seul jour, ou « du … au … ». */
export function periode(session, formater) {
  const debut = formater(session.date_debut)
  const fin = formater(session.date_fin)
  return debut === fin ? debut : `du ${debut} au ${fin}`
}

// ── Les sessions, telles que tous les écrans les affichent ───────────────────

/**
 * Toutes les sessions, avec l'intitulé de la formation, le nom de
 * l'établissement, le nombre d'inscrits validés et de demandes en attente.
 */
export async function chargerSessions() {
  const lignes = await sql(
    `select s.*,
            f.intitule as formation,
            f.code     as formation_code,
            f.duree_heures,
            e.name     as etablissement,
            e.city     as ville,
            (select count(*) from inscriptions i
              where i.session_id = s.id and i.statut = 'validee')  as inscrits,
            (select count(*) from inscriptions i
              where i.session_id = s.id and i.statut = 'demandee') as demandes
     from   sessions s
     join   formations f on f.id = s.formation_id
     left join public.establishments e on e.id = s.establishment_id
     order by s.date_debut, s.heure_debut, s.id`,
  )
  return lignes.map((s) => ({
    ...s,
    inscrits: Number(s.inscrits),
    demandes: Number(s.demandes),
    places_restantes: Math.max(0, Number(s.places) - Number(s.inscrits)),
  }))
}

// ── Ce qu'on garde d'un écran à l'autre ──────────────────────────────────────

function lire(cle) {
  try {
    const valeur = Number(sessionStorage.getItem(cle))
    return valeur || null
  } catch {
    return null
  }
}

function garder(cle, source) {
  watch(source, (valeur) => {
    try {
      if (valeur) sessionStorage.setItem(cle, String(valeur))
      else sessionStorage.removeItem(cle)
    } catch {
      /* stockage indisponible : on garde seulement la valeur en mémoire */
    }
  })
}

/**
 * Le salarié « connecté ». L'application n'a pas de page de connexion : sur
 * les écrans du collaborateur, on choisit qui l'on est dans une liste, et ce
 * choix est gardé quand on passe d'un écran à l'autre.
 */
export const salarieCourantId = ref(lire('form.salarie'))
garder('form.salarie', salarieCourantId)

/** La session sur laquelle on travaille (inscriptions, émargement). */
export const sessionCouranteId = ref(lire('form.session'))
garder('form.session', sessionCouranteId)
