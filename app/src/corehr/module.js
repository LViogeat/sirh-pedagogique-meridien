// =============================================================================
// Manifeste du Core HR.
//
// Il a exactement la même forme que celui d'un module étudiant : c'est ce qui
// rend le mécanisme uniforme. Seul `systeme: true` le distingue — il est
// épinglé en tête de menu et ne sera jamais collecté en fin de journée.
// =============================================================================

export default {
  code: 'corehr',
  label: 'Core HR',
  icon: 'pi pi-database',
  systeme: true,
  routes: [
    { path: 'salaries',      label: 'Salariés',        component: () => import('./SalariesList.vue') },
    { path: 'salaries/:id',  label: 'Fiche salarié',   component: () => import('./SalarieFiche.vue'), masque: true },
    { path: 'organigramme',  label: 'Organigramme',    component: () => import('./Organigramme.vue') },
    { path: 'postes',        label: 'Postes',          component: () => import('./Postes.vue') },
    { path: 'pilotage',      label: 'Tableau de bord', component: () => import('./TableauDeBord.vue') },
  ],
}
