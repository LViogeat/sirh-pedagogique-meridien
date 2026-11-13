export default {
    code: 'rec',
    routes: [
      {
        path: 'besoins-recrutement',
        label: 'Besoins de recrutement',
        component: () => import('./BesoinsRecrutement.vue'),
      },
    ],
  }
  