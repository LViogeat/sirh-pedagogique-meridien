// =============================================================================
// Le menu de l'application.
//
// Deux sources se rejoignent ici :
//
//   1. GROUPES (groupes.js) — les six modules du cours. La liste est fixe :
//      le menu montre le SIRH entier, même les modules qui n'existent pas
//      encore. Chacun voit où le sien s'inscrit.
//
//   2. Les manifestes trouvés dans src/modules/<code>/module.js — ce qui a
//      réellement été écrit.
//
// UN SEUL MODULE EST OUVERT : celui de votre groupe, désigné par
// VITE_MODULE_CODE. Les cinq autres apparaissent grisés. Ce n'est pas qu'une
// affaire d'affichage : le routeur refuse d'y aller, et la base refuserait
// l'écriture de toute façon.
// =============================================================================

import corehr from '@/corehr/module.js'
import { GROUPES } from './groupes'
import { MODULE_CODE } from './config'

const trouves = import.meta.glob('../modules/*/module.js', { eager: true })

/** Vérifie un manifeste et explique précisément ce qui manque. */
function valider(manifeste, chemin) {
  const m = manifeste?.default ?? manifeste
  const probleme = (texte) => {
    console.error(
      `[SIRH] Module ignoré : ${chemin}\n` +
      `       ${texte}\n` +
      `       Un module.js doit exporter par défaut : ` +
      `{ code, label, icon, routes: [{ path, label, component }] }`,
    )
    return null
  }

  if (!m)      return probleme('aucun export par défaut.')
  if (!m.code) return probleme('la propriété « code » est absente.')
  if (!/^[a-z][a-z0-9]{1,11}$/.test(m.code))
    return probleme(`le code « ${m.code} » doit être en minuscules, sans accent ni tiret.`)
  if (!Array.isArray(m.routes) || m.routes.length === 0)
    return probleme('la propriété « routes » est absente ou vide.')

  for (const [i, r] of m.routes.entries()) {
    if (!r?.path)  return probleme(`routes[${i}] : « path » manquant.`)
    if (!r?.label) return probleme(`routes[${i}] : « label » manquant.`)
    if (typeof r?.component !== 'function')
      return probleme(`routes[${i}] : « component » doit être une fonction, ` +
                      `par exemple () => import('./MonEcran.vue').`)
  }
  return m
}

/** Les manifestes réellement présents, rangés par code. */
const manifestes = {}
for (const [chemin, m] of Object.entries(trouves)) {
  const valide = valider(m, chemin)
  if (valide) manifestes[valide.code] = valide
}

if (!GROUPES.some((g) => g.code === MODULE_CODE)) {
  console.error(
    `[SIRH] VITE_MODULE_CODE vaut « ${MODULE_CODE} », qui n'est le code d'aucun ` +
    `groupe. Corrigez le fichier app/.env. Codes attendus : ` +
    GROUPES.map((g) => g.code).join(', '),
  )
}

/**
 * La page d'accueil d'un module est fournie par le socle.
 *
 * Elle marche dès le premier jour, avant que le groupe ait écrit quoi que ce
 * soit, et lui sert de tableau de bord de sprint. Toutes les autres pages du
 * module sont écrites par le groupe, et déclarées dans son manifeste.
 *
 * `socle: true` la distingue des écrans du groupe : c'est ce qui permet à la
 * page d'accueil de ne compter que les écrans réellement écrits.
 */
const ACCUEIL_DU_MODULE = {
  path: 'accueil',
  label: 'Accueil du module',
  socle: true,
  component: () => import('./composants/AccueilModule.vue'),
}

/**
 * Les six modules, chacun avec son état :
 *   mien   — c'est celui de votre groupe, vous pouvez l'ouvrir
 *   ecrit  — un manifeste existe ; sinon le module reste à créer
 */
export const modulesEtudiants = GROUPES.map((groupe) => {
  const manifeste = manifestes[groupe.code]
  const mien = groupe.code === MODULE_CODE
  return {
    ...groupe,
    mien,
    ecrit: !!manifeste,
    // Seul le module du groupe reçoit des routes : les cinq autres sont fermés.
    routes: mien ? [ACCUEIL_DU_MODULE, ...(manifeste?.routes ?? [])] : [],
  }
})

/** Le socle d'abord, les six modules ensuite, toujours dans le même ordre. */
export const modules = [
  { ...corehr, mien: false, ecrit: true, socle: true },
  ...modulesEtudiants,
]

export const monModule = modulesEtudiants.find((m) => m.mien) || null
