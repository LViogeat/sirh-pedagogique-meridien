// =============================================================================
// Auto-découverte des modules.
//
// Le menu global n'existe dans AUCUN fichier : il est déduit des manifestes
// trouvés dans src/modules/*/module.js. C'est ce qui rend la fusion gratuite —
// un dossier déposé apparaît, un dossier retiré disparaît, sans qu'aucune
// autre ligne ne bouge — et c'est ce qui rend les conflits impossibles,
// puisque aucun fichier n'est partagé.
// =============================================================================

import corehr from '@/corehr/module.js'

const trouves = import.meta.glob('../modules/*/module.js', { eager: true })

/** Vérifie un manifeste et explique précisément ce qui manque. */
function valider(manifeste, chemin) {
  const m = manifeste?.default ?? manifeste
  const probleme = (texte) => {
    console.error(
      `[SIRH] Module ignoré : ${chemin}\n` +
      `       ${texte}\n` +
      `       Un module.js doit exporter par défaut : ` +
      `{ code, label, icon, routes: [{ path, label, component }] }`
    )
    return null
  }

  if (!m)                        return probleme('aucun export par défaut.')
  if (!m.code)                   return probleme('la propriété « code » est absente.')
  if (!/^[a-z][a-z0-9]{1,11}$/.test(m.code))
    return probleme(`le code « ${m.code} » doit être en minuscules, sans accent ni tiret (ex. « rec »).`)
  if (!m.label)                  return probleme('la propriété « label » est absente.')
  if (!Array.isArray(m.routes) || m.routes.length === 0)
    return probleme('la propriété « routes » est absente ou vide.')

  for (const [i, r] of m.routes.entries()) {
    if (!r?.path)                    return probleme(`routes[${i}] : « path » manquant.`)
    if (!r?.label)                   return probleme(`routes[${i}] : « label » manquant.`)
    if (typeof r?.component !== 'function')
      return probleme(`routes[${i}] : « component » doit être une fonction, ` +
                      `par exemple () => import('./MonEcran.vue').`)
    // `masque: true` retire l'entrée du menu — pour les écrans de détail
    // atteints depuis une liste, comme /corehr/salaries/:id.
  }
  return { ...m, icon: m.icon || 'pi pi-th-large' }
}

const etudiants = Object.entries(trouves)
  .map(([chemin, m]) => valider(m, chemin))
  .filter(Boolean)
  .sort((a, b) => a.label.localeCompare(b.label, 'fr'))

const doublons = etudiants.filter((m, i, t) => t.findIndex(x => x.code === m.code) !== i)
if (doublons.length) {
  console.error(`[SIRH] Codes de module en double : ${doublons.map(d => d.code).join(', ')}`)
}

/** Le Core HR d'abord, les modules étudiants ensuite par ordre alphabétique. */
export const modules = [corehr, ...etudiants]

export const modulesEtudiants = etudiants
