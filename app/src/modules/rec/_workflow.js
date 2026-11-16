/**
 * Le workflow de recrutement (story #127) : UN seul workflow, les mêmes règles
 * partout. La page candidat et le Pipeline passent tous les deux par ce
 * fichier pour changer l'étape d'une candidature.
 *
 *   1 Candidature externe reçue → 2 Tri de CV → 3 Entretien à réaliser
 *   → 4 Offre à présenter → 5 Offre acceptée → 6 Embauché
 *   — Refusé : sortie du workflow, avec motif, réactivable
 *
 * Règles :
 *   - on avance et on recule d'UNE étape à la fois ;
 *   - reculer exige un commentaire ; aucun retour après « Embauché » ;
 *   - passer à « Entretien à réaliser » exige de planifier l'entretien
 *     (c'est _PlanifierEntretien.vue qui fait ce passage) ;
 *   - refuser exige un motif ; une candidature refusée peut être réactivée
 *     à l'étape où elle était avant le refus ;
 *   - chaque changement est écrit dans `historique_etapes`.
 */
import { sql, update, cloturerBesoin } from '@/socle/sdk'

export const ETAPES = [
  { code: 'nouvelle', label: 'Candidature externe reçue', court: 'Reçue', icone: 'pi pi-inbox' },
  { code: 'preselection', label: 'Tri de CV', court: 'Tri de CV', icone: 'pi pi-filter' },
  { code: 'entretien', label: 'Entretien à réaliser', court: 'Entretien', icone: 'pi pi-comments' },
  { code: 'proposition', label: 'Offre à présenter', court: 'Offre à présenter', icone: 'pi pi-file-edit' },
  { code: 'offre_acceptee', label: 'Offre acceptée', court: 'Offre acceptée', icone: 'pi pi-thumbs-up' },
  { code: 'embauche', label: 'Embauché', court: 'Embauché', icone: 'pi pi-check-circle' },
]
export const REFUS = { code: 'refus', label: 'Refusé', court: 'Refusé', icone: 'pi pi-times-circle' }

export const MOTIFS_REFUS = [
  'Profil inadapté au poste',
  'Compétences insuffisantes',
  'Prétentions salariales',
  'Désistement du candidat',
  'Candidat injoignable',
  'Poste pourvu par un autre candidat',
  'Autre',
]

const ORDRE = ETAPES.map((e) => e.code)

export const etapeDe = (code) => (code === 'refus' ? REFUS : ETAPES.find((e) => e.code === code))
export const libelleEtape = (code) => etapeDe(code)?.label ?? code
export const rangDe = (code) => ORDRE.indexOf(code) // 0 à 5, -1 pour « refus »

/** L'étape suivante, ou null (dernière étape, ou candidature refusée). */
export const suivante = (code) => (rangDe(code) >= 0 ? ORDRE[rangDe(code) + 1] ?? null : null)

/** L'étape précédente, ou null (première étape, embauche définitive, refus). */
export const precedente = (code) =>
  rangDe(code) > 0 && code !== 'embauche' ? ORDRE[rangDe(code) - 1] : null

export const SEVERITES = {
  nouvelle: 'secondary', preselection: 'info', entretien: 'info', proposition: 'warn',
  offre_acceptee: 'warn', embauche: 'success', refus: 'danger',
}

export const MOUVEMENTS = {
  avance: { label: 'Avancée', icone: 'pi pi-arrow-right' },
  retour: { label: 'Retour arrière', icone: 'pi pi-undo' },
  refus: { label: 'Refus', icone: 'pi pi-times' },
  reactivation: { label: 'Réactivation', icone: 'pi pi-replay' },
}

/** Date et heure locales « 2026-11-20 10:00:00 », sans conversion de fuseau. */
export function maintenant() {
  const d = new Date()
  const z = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${z(d.getMonth() + 1)}-${z(d.getDate())} ${z(d.getHours())}:${z(d.getMinutes())}:${z(d.getSeconds())}`
}

async function tracer(candidatureId, depart, arrivee, mouvement, { motif = null, commentaire = null } = {}) {
  await sql(
    `insert into historique_etapes
            (candidature_id, etape_depart, etape_arrivee, mouvement, motif, commentaire, fait_le)
     values (:id, :depart, :arrivee, :mouvement, :motif, :commentaire, cast(:quand as timestamp))`,
    {
      id: candidatureId, depart, arrivee, mouvement,
      motif, commentaire: commentaire?.trim() || null, quand: maintenant(),
    },
  )
}

async function poserEtape(candidatureId, etape, colonnes = '') {
  await sql(
    `update candidatures set etape = :etape, maj_le = current_date${colonnes} where id = :id`,
    { etape, id: candidatureId },
  )
}

/**
 * Avance d'une étape. Ne fait PAS « Entretien à réaliser » (il faut planifier
 * l'entretien) ni « Embauché » (il faut confirmer) : voir plus bas.
 */
export async function avancer(candidature, commentaire = null) {
  const vers = suivante(candidature.etape)
  if (!vers) throw new Error('Cette candidature ne peut plus avancer.')
  if (vers === 'entretien') throw new Error("Planifiez l'entretien pour passer à « Entretien à réaliser ».")
  if (vers === 'embauche') throw new Error("Utilisez « Embaucher » pour confirmer l'embauche.")
  await poserEtape(candidature.id, vers)
  await tracer(candidature.id, candidature.etape, vers, 'avance', { commentaire })
  return vers
}

/** Passage à « Entretien à réaliser », appelé une fois l'entretien planifié. */
export async function passerEnEntretien(candidature, commentaire = null) {
  if (candidature.etape !== 'preselection') return candidature.etape // déjà en entretien : 2e entretien
  await poserEtape(candidature.id, 'entretien')
  await tracer(candidature.id, 'preselection', 'entretien', 'avance', { commentaire })
  return 'entretien'
}

/** Recule d'une étape ; le commentaire est obligatoire. */
export async function reculer(candidature, commentaire) {
  const vers = precedente(candidature.etape)
  if (!vers) throw new Error('Cette candidature ne peut pas revenir en arrière.')
  if (!commentaire?.trim()) throw new Error('Un commentaire est obligatoire pour revenir en arrière.')
  await poserEtape(candidature.id, vers)
  await tracer(candidature.id, candidature.etape, vers, 'retour', { commentaire })
  return vers
}

/** Refuse la candidature ; le motif est obligatoire (et un commentaire pour « Autre »). */
export async function refuser(candidature, motif, commentaire = null) {
  if (candidature.etape === 'embauche' || candidature.etape === 'refus') {
    throw new Error('Cette candidature ne peut pas être refusée.')
  }
  if (!MOTIFS_REFUS.includes(motif)) throw new Error('Choisissez un motif de refus.')
  if (motif === 'Autre' && !commentaire?.trim()) {
    throw new Error('Précisez le motif « Autre » dans le commentaire.')
  }
  await sql(
    `update candidatures
        set etape = 'refus', etape_avant_refus = etape, motif_refus = :motif, maj_le = current_date
      where id = :id`,
    { motif, id: candidature.id },
  )
  await tracer(candidature.id, candidature.etape, 'refus', 'refus', { motif, commentaire })
}

/** Réactive une candidature refusée, à l'étape d'avant le refus. */
export async function reactiver(candidature, commentaire = null) {
  if (candidature.etape !== 'refus') throw new Error("Cette candidature n'est pas refusée.")
  const vers = candidature.etape_avant_refus || 'nouvelle'
  await poserEtape(candidature.id, vers, ', motif_refus = null, etape_avant_refus = null')
  await tracer(candidature.id, 'refus', vers, 'reactivation', { commentaire })
  return vers
}

/**
 * « Offre acceptée » → « Embauché » : clôture le besoin dans le socle (définitif),
 * passe l'offre à « pourvue ». candidature doit porter offre_id et besoin_id.
 */
export async function embaucher(candidature, commentaire = null) {
  if (candidature.etape !== 'offre_acceptee') {
    throw new Error("Seule une candidature à « Offre acceptée » peut être embauchée.")
  }
  const nom = `${candidature.prenom} ${candidature.nom}`
  if (candidature.besoin_id) {
    await cloturerBesoin(candidature.besoin_id, `Poste pourvu : ${nom} (offre n° ${candidature.offre_id})`)
  }
  await poserEtape(candidature.id, 'embauche')
  await update('offres', candidature.offre_id, { statut: 'pourvue' })
  await tracer(candidature.id, 'offre_acceptee', 'embauche', 'avance', { commentaire })
}

/** L'historique de plusieurs candidatures, du plus récent au plus ancien. */
export function chargerHistorique(candidatureIds) {
  if (!candidatureIds.length) return Promise.resolve([])
  return sql(
    `select * from historique_etapes
      where candidature_id = any(cast(:ids as integer[]))
      order by fait_le desc, id desc`,
    { ids: `{${candidatureIds.join(',')}}` },
  )
}
