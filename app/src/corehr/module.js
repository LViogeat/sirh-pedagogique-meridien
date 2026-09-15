/**
 * Le manifeste du socle.
 *
 * C'est le seul fichier dont la FORME est imposée. Le vôtre a exactement la
 * même, dans `src/modules/<votre code>/module.js` :
 *
 *   export default {
 *     code:  'rec',                     // le code de votre groupe
 *     label: 'Recrutement',             // ce qui s'affiche dans le menu
 *     icon:  'pi pi-user-plus',         // une icône PrimeIcons
 *     routes: [
 *       { path: 'offres', label: 'Offres', component: () => import('./OffresList.vue') },
 *     ],
 *   }
 *
 * Ajouter un écran = ajouter une ligne dans `routes` et créer le fichier .vue.
 * Le menu et les URL se construisent tout seuls : /rec/offres.
 */

export default {
  code: 'corehr',
  label: 'Socle SIRH',
  icon: 'pi pi-database',
  routes: [
    { path: 'besoins', label: 'Besoins identifiés',
      component: () => import('./BesoinsList.vue') },
    { path: 'salaries', label: 'Salariés',
      component: () => import('./SalariesList.vue') },
    // `masque: true` : l'écran existe et a une URL, mais n'apparaît pas dans
    // le menu. C'est ce qu'on fait pour une fiche atteinte depuis une liste.
    { path: 'salaries/:id', label: 'Fiche salarié', masque: true,
      component: () => import('./SalarieFiche.vue') },
    { path: 'postes', label: 'Postes',
      component: () => import('./PostesList.vue') },
    { path: 'entretiens', label: 'Entretiens annuels',
      component: () => import('./EntretiensList.vue') },
    { path: 'console-sql', label: 'Console SQL',
      component: () => import('./ConsoleSql.vue') },
  ],
}
