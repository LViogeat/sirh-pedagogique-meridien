// =============================================================================
// MANIFESTE — le seul fichier de forme imposée dans un module.
//
// Pour ajouter une page : une ligne de plus dans `routes`, et le fichier .vue
// correspondant. Le menu et le routeur se mettent à jour tout seuls — vous
// n'avez AUCUN autre fichier à modifier.
// =============================================================================

export default {
  code:  'demo',                 // préfixe de vos tables ET segment d'URL
  label: 'Démonstration',        // ce qui s'affiche au 1er niveau du menu
  icon:  'pi pi-compass',        // une icône PrimeIcons : primevue.org/icons

  routes: [
    { path:  'taches',
      label: 'Tâches',
      component: () => import('./TachesList.vue') },

    { path:  'exemple',
      label: 'Lire le Core HR',
      component: () => import('./ExempleCoreHR.vue') },
  ],
}
