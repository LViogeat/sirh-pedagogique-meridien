import { createRouter, createWebHashHistory } from 'vue-router'
import { h } from 'vue'
import { modules } from './modules'
import ModuleEnErreur from './composants/ModuleEnErreur.vue'
import ModuleVerrouille from './composants/ModuleVerrouille.vue'

/** La porte d'entrée du logiciel : l'entreprise, la chaîne, les six modules. */
const ACCUEIL_GENERAL = {
  path: '/accueil',
  name: 'accueil',
  component: () => import('./composants/AccueilGeneral.vue'),
  meta: { moduleLabel: 'SIRH Sorbonne-Hôtel', label: 'Accueil' },
}

/**
 * Enveloppe le chargement d'un écran : si le fichier ne compile pas ou n'existe
 * pas, on affiche une erreur lisible au lieu d'une page blanche.
 *
 * C'est ce qui protège la démonstration : l'écran fautif affiche un message,
 * le reste du SIRH continue de fonctionner.
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

/**
 * Seuls le socle et VOTRE module ont de vraies routes.
 *
 * Les cinq autres modules reçoivent une route qui affiche un écran de verrou :
 * une URL tapée à la main n'ouvre rien.
 */
const ouverts = modules.filter((m) => m.socle || m.mien)

const routesOuvertes = ouverts.flatMap((m) =>
  m.routes.map((r) => ({
    path: `/${m.code}/${r.path}`.replace(/\/+/g, '/'),
    name: `${m.code}.${r.path}`,
    component: ecranProtege(r.component, { label: r.label, moduleLabel: m.label }),
    meta: {
      moduleCode: m.code,
      moduleLabel: m.label,
      moduleIcon: m.icon,
      label: r.label,
    },
  })),
)

const routesVerrouillees = modules
  .filter((m) => !m.socle && !m.mien)
  .map((m) => ({
    path: `/${m.code}/:reste(.*)*`,
    name: `${m.code}.verrouille`,
    component: { render: () => h(ModuleVerrouille, { groupe: m }) },
    meta: { moduleCode: m.code, moduleLabel: m.label, label: 'Accès refusé' },
  }))

export const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', redirect: '/accueil' },
    ACCUEIL_GENERAL,
    ...routesOuvertes,
    ...routesVerrouillees,
    {
      path: '/:reste(.*)*',
      component: {
        render: () =>
          h(ModuleEnErreur, {
            titre: 'Cette page n’existe pas',
            message: 'Vérifiez le menu de gauche.',
          }),
      },
    },
  ],
})
