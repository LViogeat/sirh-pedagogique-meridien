// =============================================================================
// Lecture du référentiel Core HR.
//
// Ces fonctions lisent les VUES APLATIES de la base, jamais les tables
// historisées. Toute la complexité temporelle — quel contrat est en cours,
// quel avenant est en vigueur, depuis quand — est résolue côté PostgreSQL.
//
// Une donnée qui manque ici est une DEMANDE D'ÉVOLUTION, pas une jointure.
// =============================================================================

import { supabase } from './supabase'

/** Nettoie une saisie avant de la passer à un filtre PostgREST `or`. */
function assainir(texte) {
  return String(texte).replace(/[,()*%\\]/g, ' ').trim()
}

function verifier({ data, error }) {
  if (error) throw new Error(error.message)
  return data
}

/**
 * Les salariés présents aujourd'hui.
 * Tous les filtres sont facultatifs et se combinent.
 */
export async function getEmployes(filtres = {}) {
  let q = supabase.from('v_employes_actifs').select('*')

  if (filtres.serviceId)       q = q.eq('service_id', filtres.serviceId)
  if (filtres.etablissementId) q = q.eq('etablissement_id', filtres.etablissementId)
  if (filtres.typeContrat)     q = q.eq('type_contrat_code', filtres.typeContrat)
  if (filtres.managerId)       q = q.eq('manager_id', filtres.managerId)

  const recherche = assainir(filtres.recherche || '')
  if (recherche) {
    q = q.or(`nom_complet.ilike.%${recherche}%,matricule.ilike.%${recherche}%,email_pro.ilike.%${recherche}%`)
  }

  return verifier(await q.order('nom').order('prenom'))
}

/** Un salarié, avec tout son historique : contrats, avenants, affectations. */
export async function getEmploye(personneId) {
  const base = verifier(await supabase
    .from('v_employes_actifs').select('*').eq('personne_id', personneId).maybeSingle())

  const identite = base || verifier(await supabase
    .from('v_personnes').select('*').eq('personne_id', personneId).maybeSingle())

  if (!identite) return null

  const contrats = verifier(await supabase
    .from('contrats')
    .select('*, ref_type_contrat(libelle), ref_motif_sortie(libelle), avenants(*, ref_type_avenant(libelle))')
    .eq('personne_id', personneId)
    .order('date_debut', { ascending: false }))

  const affectations = verifier(await supabase
    .from('affectations')
    .select('*, unites_organisationnelles(libelle), postes(libelle)')
    .eq('personne_id', personneId)
    .order('date_debut', { ascending: false }))

  // Le manager est une auto-référence sur personnes : on résout les noms à part,
  // c'est plus lisible qu'une jointure nommée PostgREST.
  const idsManagers = [...new Set(affectations.map(a => a.manager_personne_id).filter(Boolean))]
  let noms = {}
  if (idsManagers.length) {
    const lignes = verifier(await supabase
      .from('v_personnes').select('personne_id, nom_complet').in('personne_id', idsManagers))
    noms = Object.fromEntries(lignes.map(l => [l.personne_id, l.nom_complet]))
  }

  return {
    ...identite,
    contrats: contrats.map(c => ({
      ...c,
      type_contrat: c.ref_type_contrat?.libelle,
      motif_sortie: c.ref_motif_sortie?.libelle,
      avenants: (c.avenants || [])
        .map(a => ({ ...a, type_avenant: a.ref_type_avenant?.libelle }))
        .sort((a, b) => a.numero_ordre - b.numero_ordre),
    })),
    affectations: affectations.map(a => ({
      ...a,
      service: a.unites_organisationnelles?.libelle,
      poste: a.postes?.libelle,
      manager: noms[a.manager_personne_id] || null,
    })),
  }
}

/** La carrière salariale : contrat initial, augmentations, promotions. */
export async function getHistoriqueRemuneration(personneId) {
  return verifier(await supabase
    .from('v_historique_remuneration').select('*')
    .eq('personne_id', personneId)
    .order('contrat_id').order('numero_ordre'))
}

/** L'organisation. Par défaut, seulement les services ; sinon tout l'arbre. */
export async function getServices({ toutesUnites = false } = {}) {
  let q = supabase.from('v_organigramme').select('*')
  if (!toutesUnites) q = q.eq('type_unite', 'service')
  return verifier(await q.order('service'))
}

/** Les postes. `{ vacants: true }` ne renvoie que les positions non pourvues. */
export async function getPostes({ vacants = false, serviceId = null } = {}) {
  let q = supabase.from('v_postes').select('*')
  if (vacants)   q = q.eq('vacant', true)
  if (serviceId) q = q.eq('service_id', serviceId)
  return verifier(await q.order('service').order('libelle'))
}

export async function getEtablissements() {
  return verifier(await supabase
    .from('etablissements').select('id, code, nom, ville').order('nom'))
}

/** Toutes les personnes connues, salariées ou non (statut : Salarié / Ancien salarié / Externe). */
export async function getPersonnes({ statut = null, recherche = '' } = {}) {
  let q = supabase.from('v_personnes').select('*')
  if (statut) q = q.eq('statut', statut)
  const r = assainir(recherche)
  if (r) q = q.or(`nom_complet.ilike.%${r}%,email_perso.ilike.%${r}%`)
  return verifier(await q.order('nom_complet'))
}

/** Effectif et ETP agrégés par service. */
export async function getEffectifParService() {
  return verifier(await supabase
    .from('v_effectif_par_service').select('*')
    .eq('type_unite', 'service').order('effectif', { ascending: false }))
}

/** Entrées et sorties par mois sur 36 mois — la base du turnover. */
export async function getMouvements() {
  return verifier(await supabase.from('v_mouvements').select('*').order('mois'))
}

const REFERENTIELS = {
  civilite:      'ref_civilite',
  type_contrat:  'ref_type_contrat',
  motif_cdd:     'ref_motif_cdd',
  motif_sortie:  'ref_motif_sortie',
  csp:           'ref_csp',
  type_avenant:  'ref_type_avenant',
}

/** Une liste de référence : getRef('type_contrat') → [{ code, libelle }, …] */
export async function getRef(nom) {
  const table = REFERENTIELS[nom]
  if (!table) {
    throw new Error(
      `Référentiel inconnu : « ${nom} ». Valeurs possibles : ${Object.keys(REFERENTIELS).join(', ')}.`
    )
  }
  return verifier(await supabase
    .from(table).select('code, libelle').eq('actif', true).order('ordre'))
}
