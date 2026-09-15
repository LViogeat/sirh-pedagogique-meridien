/**
 * Vos propres tables.
 *
 * Votre groupe est PROPRIÉTAIRE d'un schéma PostgreSQL qui porte son code.
 * Vous y créez vos tables, vous les lisez, vous les écrivez. Vous lisez aussi
 * le socle (`public.`) et les schémas des cinq autres groupes.
 *
 * Vous n'avez pas à préfixer vos tables : `offres` désigne déjà la table
 * `offres` de votre schéma.
 *
 * La règle de sécurité : NE JAMAIS concaténer une valeur dans une requête.
 * Les paramètres nommés `:nom` sont là pour ça, et ils gèrent les accents,
 * les apostrophes et les pourcents sans que vous ayez à y penser.
 *
 *   ✅ sql('select * from offres where statut = :s', { s: statut.value })
 *   ❌ sql(`select * from offres where statut = '${statut.value}'`)
 */

import { onMounted, reactive } from 'vue'
import { post } from './api'

/**
 * Exécute une requête et renvoie les lignes.
 *
 *   const offres = await sql('select * from offres order by id desc')
 *   const trouves = await sql(
 *     'select * from candidats where nom ilike :motif',
 *     { motif: `%${recherche.value}%` },
 *   )
 */
export async function sql(requete, params = {}) {
  const reponse = await post('/sql', { query: requete, params })
  return reponse.rows
}

/** Comme `sql`, mais renvoie aussi les colonnes et le nombre de lignes. */
export const sqlComplet = (requete, params = {}) =>
  post('/sql', { query: requete, params })

/** Applique plusieurs instructions d'un coup — votre fichier schema.sql. */
export const sqlScript = (script) => post('/sql/script', { script })

// ── Le CRUD courant, pour ne pas écrire des INSERT à la main ─────────────────

const NOM_VALIDE = /^[a-z_][a-z0-9_]*$/

function verifierNom(table) {
  if (!NOM_VALIDE.test(table)) {
    throw new Error(
      `« ${table} » n'est pas un nom de table valide : minuscules, chiffres et ` +
      `tirets bas uniquement.`,
    )
  }
}

/**
 * insert('candidats', { nom: 'Meyer', prenom: 'Léa' })
 * Renvoie la ligne créée, identifiant compris.
 */
export async function insert(table, objet) {
  verifierNom(table)
  const colonnes = Object.keys(objet)
  if (!colonnes.length) throw new Error('Rien à insérer : l’objet est vide.')

  const lignes = await sql(
    `insert into ${table} (${colonnes.join(', ')}) ` +
    `values (${colonnes.map((c) => `:${c}`).join(', ')}) returning *`,
    objet,
  )
  return lignes[0]
}

/**
 * update('candidatures', 12, { statut: 'entretien' })
 * Renvoie la ligne modifiée.
 */
export async function update(table, id, objet) {
  verifierNom(table)
  const colonnes = Object.keys(objet)
  if (!colonnes.length) throw new Error('Rien à modifier : l’objet est vide.')

  const lignes = await sql(
    `update ${table} set ${colonnes.map((c) => `${c} = :${c}`).join(', ')} ` +
    `where id = :__id returning *`,
    { ...objet, __id: id },
  )
  return lignes[0]
}

/** remove('offres', 3) — supprime une ligne par son identifiant. */
export async function remove(table, id) {
  verifierNom(table)
  await sql(`delete from ${table} where id = :__id`, { __id: id })
  return true
}

// ── La requête réactive, pour les écrans ─────────────────────────────────────

/**
 * Charge une requête et la garde à jour.
 *
 *   const offres = useQuery('select * from offres order by id desc')
 *   // offres.rows · offres.loading · offres.error · offres.refresh()
 *
 * Pour des paramètres qui changent, passez une FONCTION : elle est réévaluée
 * à chaque rafraîchissement.
 *
 *   const offres = useQuery(
 *     'select * from offres where statut = :s',
 *     () => ({ s: statut.value }),
 *   )
 *   watch(statut, offres.refresh)
 */
export function useQuery(requete, params = {}, { chargerAuDemarrage = true } = {}) {
  const etat = reactive({ rows: [], columns: [], loading: false, error: null })

  etat.refresh = async () => {
    etat.loading = true
    etat.error = null
    try {
      const reponse = await sqlComplet(
        requete, typeof params === 'function' ? params() : params,
      )
      etat.rows = reponse.rows
      etat.columns = reponse.columns
    } catch (erreur) {
      etat.error = erreur.message
      etat.rows = []
    } finally {
      etat.loading = false
    }
  }

  if (chargerAuDemarrage) onMounted(etat.refresh)
  return etat
}
