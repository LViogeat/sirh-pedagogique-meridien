/**
 * Les trois valeurs qui changent d'un groupe à l'autre.
 *
 * Elles viennent du fichier `.env` placé à la racine de `app/`. Copiez
 * `.env.example`, remplissez les deux lignes, redémarrez `npm run dev`.
 *
 * L'URL de l'API a une valeur par défaut : c'est celle du serveur du cours.
 * Vous n'avez donc à renseigner que le jeton et le code de votre groupe,
 * que l'intervenant vous a remis.
 */

export const API_URL = (import.meta.env.VITE_API_URL || 'https://sirh-api.govetia.com')
  .replace(/\/+$/, '')

export const API_TOKEN = (import.meta.env.VITE_API_TOKEN || '').trim()

/** Le code de votre module — c'est aussi le nom de votre schéma PostgreSQL. */
export const MODULE_CODE = (import.meta.env.VITE_MODULE_CODE || '').trim()

/**
 * Tant que ces deux valeurs manquent, l'application n'affiche rien d'autre
 * qu'un écran expliquant quoi créer. Mieux vaut cela qu'une erreur réseau
 * incompréhensible au premier lancement.
 */
export const CONFIGURATION_INCOMPLETE = !API_TOKEN || !MODULE_CODE
