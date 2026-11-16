// =============================================================================
// Le menu de l'application.
//
// Deux sources se rejoignent ici :
//
//   1. GROUPES (groupes.js) — les six modules du cours. La liste est fixe :
//      le menu montre le SIRH entier, même les modules qui n'existent pas
//      encore. Chacun voit où le sien s'inscrit.
//
//   2. Ce qui a réellement été écrit : les fichiers .vue de
//      src/modules/<code>/ (un fichier = un écran), plus, si besoin, le
//      manifeste module.js du même dossier pour les écrans de détail.
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

// Les écrans eux-mêmes : tout fichier .vue posé dans src/modules/<code>/ devient
// un écran du menu, sans rien déclarer. `module.js` n'est plus nécessaire que
// pour un écran de détail (avec un paramètre, comme offres/:id).
const ecransVue = import.meta.glob('../modules/*/*.vue')
const sourcesVue = import.meta.glob('../modules/*/*.vue', {
  query: '?raw', import: 'default', eager: true,
})

/** « FeteFinAnnee » → « fete-fin-annee » */
function enAdresse(nom) {
  return nom.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase()
}

/** « FeteFinAnnee » → « Fete Fin Annee » (le libellé de secours) */
function enLibelle(nom) {
  return nom.replace(/([a-z0-9])([A-Z])/g, '$1 $2')
}

/**
 * Le libellé du menu : la première ligne `<!-- libelle: Fête de fin d'année -->`
 * du fichier, sinon le nom du fichier mis en clair.
 */
function libelleDe(chemin, nom) {
  const m = /<!--\s*libell?e\s*:\s*(.+?)\s*-->/i.exec(sourcesVue[chemin] || '')
  return m ? m[1] : enLibelle(nom)
}

/** Les écrans d'un module trouvés dans son dossier, hors ceux que le manifeste déclare déjà. */
function ecransDuDossier(code, routesDuManifeste) {
  const dejaLa = new Set(routesDuManifeste.map((r) => r.path))
  const sources = routesDuManifeste.map((r) => String(r.component))
  const ecrans = []
  for (const [chemin, charger] of Object.entries(ecransVue)) {
    const [, dossier, nom] = /\.\.\/modules\/([^/]+)\/([^/]+)\.vue$/.exec(chemin) || []
    if (dossier !== code || nom.startsWith('_')) continue
    if (sources.some((src) => src.includes(`/${nom}.vue`))) continue
    const path = enAdresse(nom)
    if (dejaLa.has(path)) continue
    ecrans.push({ path, label: libelleDe(chemin, nom), component: charger })
  }
  return ecrans
}

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
  if (!Array.isArray(m.routes))
    return probleme('la propriété « routes » est absente (elle peut être vide : []).')

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

if (MODULE_CODE && !GROUPES.some((g) => g.code === MODULE_CODE)) {
  console.error(
    `[SIRH] VITE_MODULE_CODE vaut « ${MODULE_CODE} », qui n'est le code d'aucun ` +
    `groupe. Corrigez le fichier .env, à la racine du projet. Codes attendus : ` +
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
 *   ecrit  — au moins un écran existe ; sinon le module reste à créer
 */
function routesDuGroupe(code, manifeste) {
  const declarees = manifeste?.routes ?? []
  return [...declarees, ...ecransDuDossier(code, declarees)]
}

export const modulesEtudiants = GROUPES.map((groupe) => {
  const manifeste = manifestes[groupe.code]
  const mien = groupe.code === MODULE_CODE
  return {
    ...groupe,
    mien,
    ecrit: routesDuGroupe(groupe.code, manifeste).length > 0,
    // Seul le module du groupe reçoit des routes : les cinq autres sont fermés.
    routes: mien ? [ACCUEIL_DU_MODULE, ...routesDuGroupe(groupe.code, manifeste)] : [],
  }
})

/** Le socle d'abord, les six modules ensuite, toujours dans le même ordre. */
export const modules = [
  { ...corehr, mien: false, ecrit: true, socle: true },
  ...modulesEtudiants,
]

export const monModule = modulesEtudiants.find((m) => m.mien) || null
