/**
 * Les trois valeurs qui changent d'un groupe à l'autre.
 *
 * Elles viennent du fichier `.env` à la racine de `app/`. Chaque instance de
 * code-server a le sien, avec le jeton et le code de son groupe — il n'y a
 * donc rien à modifier dans le code.
 */

export const API_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8000')
  .replace(/\/+$/, '')

export const API_TOKEN = import.meta.env.VITE_API_TOKEN || 'jeton-rec'

/** Le code de votre module — c'est aussi le nom de votre schéma PostgreSQL. */
export const MODULE_CODE = import.meta.env.VITE_MODULE_CODE || 'rec'
