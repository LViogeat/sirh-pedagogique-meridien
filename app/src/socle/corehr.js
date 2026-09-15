/**
 * La lecture du socle.
 *
 * Une fonction par endpoint, un objet de filtres facultatifs. Aucun de ces
 * appels ne peut modifier le socle : l'API ne l'autoriserait pas.
 *
 * La seule exception est en bas de ce fichier : le statut d'un besoin.
 */

import { get, patch } from './api'

// ── Structure ────────────────────────────────────────────────────────────────

/** Les cinq hôtels, avec leur effectif présent. */
export const getEtablissements = () => get('/etablissements')

/** Les départements. `{ etablissementId }` pour un seul hôtel. */
export const getDepartements = ({ etablissementId } = {}) =>
  get('/departements', { etablissement_id: etablissementId })

/**
 * Les postes, avec effectif cible et effectif réel.
 * `{ vacants: true }` ne renvoie que ceux qui sont en sous-effectif.
 */
export const getPostes = ({ etablissementId, departementId, famille, vacants } = {}) =>
  get('/postes', {
    etablissement_id: etablissementId, departement_id: departementId,
    famille, vacants,
  })

/** Un poste, avec les compétences qu'il requiert et le niveau attendu. */
export const getPoste = (id) => get(`/postes/${id}`)

/** Le référentiel de compétences. `{ categorie: 'langue' }` pour en filtrer une. */
export const getCompetences = ({ categorie } = {}) => get('/competences', { categorie })

// ── Salariés et contrats ─────────────────────────────────────────────────────

/**
 * Les salariés, avec leur contrat en cours déjà aplati sur la ligne.
 * Par défaut, seuls les salariés présents : passez `{ statut: 'sorti' }`
 * pour les anciens.
 */
export const getSalaries = ({ etablissementId, departementId, posteId, managerId,
                              statut, typeContrat, q } = {}) =>
  get('/salaries', {
    etablissement_id: etablissementId, departement_id: departementId,
    poste_id: posteId, manager_id: managerId, statut, type_contrat: typeContrat, q,
  })

/** Un salarié, avec son parcours contractuel complet. */
export const getSalarie = (id) => get(`/salaries/${id}`)

/**
 * Les contrats. `{ finAvant: '2026-12-31' }` repère les échéances proches —
 * c'est le filtre dont le groupe Recrutement a besoin.
 */
export const getContrats = ({ etablissementId, posteId, salarieId,
                              typeContrat, statut, finAvant } = {}) =>
  get('/contrats', {
    etablissement_id: etablissementId, poste_id: posteId, salarie_id: salarieId,
    type_contrat: typeContrat, statut, fin_avant: finAvant,
  })

// ── Évaluation ───────────────────────────────────────────────────────────────

export const getCampagnes = () => get('/campagnes')

/** Les entretiens annuels. */
export const getEntretiens = ({ campagneId, salarieId, evaluateurId,
                                etablissementId, statut } = {}) =>
  get('/entretiens', {
    campagne_id: campagneId, salarie_id: salarieId, evaluateur_id: evaluateurId,
    etablissement_id: etablissementId, statut,
  })

/** Un entretien, avec ses objectifs, ses évaluations de compétences et ses aspirations. */
export const getEntretien = (id) => get(`/entretiens/${id}`)

/** Les souhaits d'évolution exprimés en entretien. */
export const getAspirations = ({ salarieId, etablissementId, typeAspiration } = {}) =>
  get('/aspirations', {
    salarie_id: salarieId, etablissement_id: etablissementId,
    type_aspiration: typeAspiration,
  })

// ── Besoins identifiés ───────────────────────────────────────────────────────

/**
 * Les besoins identifiés — le pivot du socle.
 *
 *   getBesoins({ typeBesoin: 'formation', statut: 'ouvert' })
 */
export const getBesoins = ({ typeBesoin, statut, priorite, etablissementId,
                             departementId, posteId, salarieId, competenceId,
                             module } = {}) =>
  get('/besoins', {
    type_besoin: typeBesoin, statut, priorite,
    etablissement_id: etablissementId, departement_id: departementId,
    poste_id: posteId, salarie_id: salarieId, competence_id: competenceId, module,
  })

export const getBesoin = (id) => get(`/besoins/${id}`)

/**
 * LA SEULE ÉCRITURE AUTORISÉE SUR LE SOCLE.
 *
 * Un besoin avance : ouvert → pris en charge → clôturé. Votre module est
 * déduit du jeton : personne ne peut prendre un besoin au nom d'un autre
 * groupe, et un besoin pris par un autre groupe vous sera refusé.
 */
export const prendreEnChargeBesoin = (id, commentaire = null) =>
  patch(`/besoins/${id}`, { status: 'pris_en_charge', comment: commentaire })

export const cloturerBesoin = (id, commentaire = null) =>
  patch(`/besoins/${id}`, { status: 'cloture', comment: commentaire })

/** Relâcher un besoin pris par erreur : il redevient disponible. */
export const relacherBesoin = (id) => patch(`/besoins/${id}`, { status: 'ouvert' })

// ── Référentiels ─────────────────────────────────────────────────────────────

/**
 * Toutes les listes de valeurs en un appel :
 *
 *   const refs = await getReferentiels()
 *   refs.type_contrat  // [{ code: 'CDI', label: 'CDI' }, …]
 */
export const getReferentiels = () => get('/referentiels')

/** La date sur laquelle tout le socle est calé. Le socle ne lit jamais l'horloge. */
export const getDateReference = () =>
  get('/date-reference').then((r) => r.date_reference)
