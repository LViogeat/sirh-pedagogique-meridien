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

const TABLES = ['formations', 'obligations', 'sessions', 'inscriptions', 'souhaits', 'budgets']
// Les colonnes ajoutées au sprint 2 sur des tables du sprint 1.
const COLONNES_AJOUTEES = 3
let preparation = null

/**
 * Vérifie que les tables du module existent (et qu'elles ont bien les
 * colonnes ajoutées depuis), et applique schema.sql si quelque chose manque.
 * Chaque écran l'appelle avant sa première requête : le module marche donc
 * même si personne n'a joué le script dans la Console SQL.
 */
export function preparerSchema() {
  if (!preparation) {
    preparation = (async () => {
      const lignes = await sql(
        `select
           (select count(*)
              from information_schema.tables
             where table_schema = :schema
               and table_name in ('formations', 'obligations', 'sessions',
                                  'inscriptions', 'souhaits', 'budgets')) as tables,
           (select count(*)
              from information_schema.columns
             where table_schema = :schema
               and ((table_name = 'inscriptions'
                     and column_name in ('realisation', 'realisation_le'))
                 or (table_name = 'sessions' and column_name = 'cout'))) as colonnes`,
        { schema: MODULE_CODE },
      )
      const complet =
        Number(lignes[0]?.tables) >= TABLES.length &&
        Number(lignes[0]?.colonnes) >= COLONNES_AJOUTEES
      if (!complet) await sqlScript(schema)
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

export const ORIGINES_SOUHAIT = [
  { code: 'entretien_annuel', label: 'Entretien annuel' },
  { code: 'en_cours_annee', label: 'En cours d’année' },
]

export const PRIORITES = [
  { code: 'haute', label: 'Haute', severity: 'danger' },
  { code: 'moyenne', label: 'Moyenne', severity: 'warn' },
  { code: 'basse', label: 'Basse', severity: 'secondary' },
]

export const AVIS_MANAGER = [
  { code: 'favorable', label: 'Favorable', severity: 'success' },
  { code: 'reserve', label: 'Réservé', severity: 'warn' },
]

export const STATUTS_SOUHAIT = [
  { code: 'exprime', label: 'Exprimé, à formaliser', severity: 'warn' },
  { code: 'transmis', label: 'Transmis au RH', severity: 'success' },
  { code: 'ecarte', label: 'Non retenu par le manager', severity: 'secondary' },
]

export const REALISATIONS = [
  { code: 'validee', label: 'Réalisation validée', severity: 'success' },
  { code: 'non_validee', label: 'Non validée', severity: 'danger' },
]

/** Où en est un salarié sur une formation obligatoire. */
export const ETATS_OBLIGATION = [
  { code: 'a_faire', label: 'À faire', severity: 'danger' },
  { code: 'a_renouveler', label: 'À renouveler', severity: 'danger' },
  { code: 'demande', label: 'Demande en attente', severity: 'warn' },
  { code: 'inscrit', label: 'Inscrit', severity: 'info' },
  { code: 'a_valider', label: 'Suivie, à valider par le RH', severity: 'info' },
  { code: 'a_jour', label: 'À jour', severity: 'success' },
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

/** L'établissement sur lequel le Responsable RH travaille. */
export const etablissementCourantId = ref(lire('form.etablissement'))
garder('form.etablissement', etablissementCourantId)

// ── Le suivi des formations obligatoires ─────────────────────────────────────

/**
 * Le délai pour faire une formation obligatoire qu'on n'a jamais suivie :
 * six mois après l'arrivée dans l'entreprise. Pour une formation à recycler,
 * l'échéance est la dernière réalisation + la périodicité de la formation.
 */
export const DELAI_INITIAL_MOIS = 6

/** Une échéance qui tombe dans moins de 90 jours est signalée « bientôt ». */
export const ALERTE_ECHEANCE_JOURS = 90

function ajouterMois(iso, mois) {
  const date = enDate(iso)
  if (!date) return null
  date.setMonth(date.getMonth() + Number(mois))
  return date
}

/**
 * Pour une liste de salariés (les lignes de getSalaries), renvoie une ligne
 * par salarié et par formation obligatoire sur son poste, avec sa situation :
 *
 *   etat        un code de ETATS_OBLIGATION
 *   realisee_le la dernière réalisation validée par le RH
 *   echeance    la date limite (premier passage ou recyclage)
 *   en_retard   la formation n'est pas à jour et l'échéance est dépassée
 *   bientot     la formation est à jour mais l'échéance approche
 *
 * Une formation ne compte comme réalisée qu'une fois la réalisation validée
 * par le RH (écran « Validation des réalisations »).
 */
export async function chargerSuiviObligations(salaries) {
  const obligations = await sql(
    `select f.id as formation_id, f.code, f.intitule, f.domaine, f.duree_heures,
            f.periodicite_mois, o.famille_metier
     from   obligations o
     join   formations f on f.id = o.formation_id
     where  f.actif
     order by f.intitule`,
  )
  const parcours = await sql(
    `select i.employee_id, s.formation_id,
            max(case when i.realisation = 'validee' then s.date_fin end) as realisee_le,
            max(case when i.presence = 'present' and i.realisation is null
                     then s.date_fin end) as a_valider_le,
            min(case when i.statut = 'validee' and i.presence is null
                      and s.statut in ('ouverte', 'fermee')
                     then s.date_debut end) as inscrit_le,
            min(case when i.statut = 'demandee' and s.statut in ('ouverte', 'fermee')
                     then s.date_debut end) as demandee_le
     from   inscriptions i
     join   sessions s on s.id = i.session_id
     group by i.employee_id, s.formation_id`,
  )
  const trace = new Map(parcours.map((p) => [`${p.employee_id}-${p.formation_id}`, p]))

  const aujourdhui = new Date()
  const alerte = new Date()
  alerte.setDate(alerte.getDate() + ALERTE_ECHEANCE_JOURS)

  const lignes = []
  for (const salarie of salaries) {
    const dejaVues = new Set()
    for (const o of obligations) {
      const concerne =
        o.famille_metier === TOUS_LES_METIERS || o.famille_metier === salarie.job_family
      if (!concerne || dejaVues.has(o.formation_id)) continue
      dejaVues.add(o.formation_id)

      const p = trace.get(`${salarie.id}-${o.formation_id}`) ?? {}
      const realisee = p.realisee_le ?? null
      const echeance = realisee
        ? (o.periodicite_mois ? ajouterMois(realisee, o.periodicite_mois) : null)
        : ajouterMois(salarie.joined_on, DELAI_INITIAL_MOIS)
      const perimee = !!(realisee && echeance && echeance < aujourdhui)

      let etat
      if (realisee && !perimee) etat = 'a_jour'
      else if (p.a_valider_le) etat = 'a_valider'
      else if (p.inscrit_le) etat = 'inscrit'
      else if (p.demandee_le) etat = 'demande'
      else etat = perimee ? 'a_renouveler' : 'a_faire'

      lignes.push({
        cle: `${salarie.id}-${o.formation_id}`,
        employee_id: salarie.id,
        salarie: salarie.full_name,
        matricule: salarie.matricule,
        email: salarie.email_pro,
        arrivee_le: salarie.joined_on,
        poste: salarie.position_title,
        famille_metier: salarie.job_family,
        establishment_id: salarie.establishment_id,
        etablissement: salarie.establishment_name,
        manager_id: salarie.manager_id,
        manager: salarie.manager_name,
        formation_id: o.formation_id,
        formation: o.intitule,
        domaine: o.domaine,
        periodicite_mois: o.periodicite_mois,
        realisee_le: realisee,
        prochaine_session: p.inscrit_le ?? p.demandee_le ?? null,
        echeance: echeance ? enIso(echeance) : null,
        etat,
        en_retard: etat !== 'a_jour' && !!echeance && echeance < aujourdhui,
        jours_de_retard: etat !== 'a_jour' && echeance && echeance < aujourdhui
          ? Math.floor((aujourdhui - echeance) / 86400000)
          : 0,
        bientot: etat === 'a_jour' && !!echeance && echeance < alerte,
      })
    }
  }
  return lignes
}

// ── L'export vers un tableur ─────────────────────────────────────────────────

/**
 * Télécharge un fichier CSV qui s'ouvre dans Excel.
 *
 *   telechargerCsv('souhaits.csv',
 *     [{ titre: 'Collaborateur', champ: 'salarie' }, …], lignes)
 *
 * `champ` peut être le nom d'une colonne ou une fonction (ligne) => valeur.
 */
export function telechargerCsv(nomFichier, colonnes, lignes) {
  const cellule = (valeur) => {
    const texte = valeur === null || valeur === undefined ? '' : String(valeur)
    return `"${texte.replaceAll('"', '""')}"`
  }
  const contenu = [
    colonnes.map((c) => cellule(c.titre)).join(';'),
    ...lignes.map((ligne) =>
      colonnes
        .map((c) => cellule(typeof c.champ === 'function' ? c.champ(ligne) : ligne[c.champ]))
        .join(';')),
  ].join('\r\n')

  // Le caractère invisible du début dit à Excel que le fichier est en UTF-8.
  const fichier = new Blob(['\uFEFF' + contenu], { type: 'text/csv;charset=utf-8' })
  const lien = document.createElement('a')
  lien.href = URL.createObjectURL(fichier)
  lien.download = nomFichier
  document.body.appendChild(lien)
  lien.click()
  lien.remove()
  URL.revokeObjectURL(lien.href)
}
