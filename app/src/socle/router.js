// =============================================================================
// Le routeur est construit À PARTIR DES MANIFESTES. Aucun étudiant ne le
// modifie jamais — d'ailleurs, ajouter une page ne demande pas d'y toucher :
// il suffit d'ajouter une ligne dans le tableau `routes` de son module.js.
// =============================================================================

import { createRouter, createWebHashHistory } from 'vue-router'
import { h } from 'vue'
import { modules } from './modules'
import { useSession } from './session'
import ModuleEnErreur from './composants/ModuleEnErreur.vue'
import Connexion from './composants/Connexion.vue'

/**
 * Enveloppe le chargement d'un écran : si le fichier ne compile pas ou n'existe
 * pas, on affiche une erreur lisible au lieu d'une page blanche.
 *
 * On reste une simple fonction de chargement paresseux — c'est ce qu'attend
 * vue-router — et on rattrape l'échec avec .catch(). Passer par
 * defineAsyncComponent marcherait aussi, mais déclencherait un avertissement
 * en console : or du bruit en console masque les vraies erreurs.
 */
function ecranProtege(loader, contexte) {
  return () =>
    loader().catch((erreur) => {
      console.error(`[SIRH] Écran « ${contexte.label} » (${contexte.moduleLabel}) :`, erreur)
      return {
        render: () =>
          h(ModuleEnErreur, {
            message:
              `L’écran « ${contexte.label} » du module « ${contexte.moduleLabel} » ` +
              `n’a pas pu être chargé. Le fichier est introuvable, ou il contient ` +
              `une erreur de syntaxe.`,
            detail: erreur?.message || String(erreur),
          }),
      }
    })
}

const routesModules = modules.flatMap((m) =>
  m.routes.map((r) => ({
    path: `/${m.code}/${r.path}`.replace(/\/+/g, '/'),
    name: `${m.code}.${r.path}`,
    component: ecranProtege(r.component, { label: r.label, moduleLabel: m.label }),
    meta: {
      moduleCode: m.code,
      moduleLabel: m.label,
      moduleIcon: m.icon,
      label: r.label,
      systeme: !!m.systeme,
    },
  }))
)

const accueil = routesModules[0]?.path || '/connexion'

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/connexion', name: 'connexion', component: Connexion, meta: { public: true } },
    { path: '/', redirect: accueil },
    ...routesModules,
    {
      path: '/:reste(.*)*',
      component: { render: () => h(ModuleEnErreur, {
        titre: 'Cette page n’existe pas',
        message: 'Vérifiez le menu de gauche.',
      }) },
    },
  ],
})

router.beforeEach((to) => {
  const session = useSession()
  if (to.meta.public) return true
  if (!session.estConnecte) return { name: 'connexion', query: { suite: to.fullPath } }
  return true
})
