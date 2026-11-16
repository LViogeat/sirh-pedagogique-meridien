// Manifeste du module « mob » : l'ORDRE des écrans dans le menu.
//
// Sans ce fichier, le menu range les écrans par ordre alphabétique. Ici, on
// les range dans l'ordre où un dossier de mobilité est traité : on repère le
// besoin, on ouvre le dossier, on prépare, on propose, on échange, on suit,
// et on clôture à la fin.
//
// Un nouvel écran posé dans ce dossier apparaît quand même dans le menu,
// après ceux-ci. Pour le placer ailleurs, ajoutez sa ligne au bon endroit.
export default {
  code: 'mob',
  routes: [
    // 1. Repérer
    { path: 'besoins-mobilite', label: 'Besoins de mobilité', component: () => import('./BesoinsMobilite.vue') },
    { path: 'souhaits-evolution', label: "Souhaits d'évolution", component: () => import('./SouhaitsEvolution.vue') },

    // 2. Ouvrir le dossier
    { path: 'prise-en-charge', label: 'Prise en charge', component: () => import('./PriseEnCharge.vue') },
    { path: 'dossiers', label: 'Dossiers de mobilité', component: () => import('./Dossiers.vue') },

    // 3. Préparer
    { path: 'fiche-carriere', label: 'Fiche carrière', component: () => import('./FicheCarriere.vue') },
    { path: 'adequation-poste', label: 'Adéquation au poste visé', component: () => import('./AdequationPoste.vue') },

    // 4. Proposer et échanger
    { path: 'opportunites', label: 'Opportunités de postes', component: () => import('./Opportunites.vue') },
    { path: 'propositions', label: 'Propositions de postes', component: () => import('./Propositions.vue') },
    { path: 'echanges', label: 'Échanges avec le salarié', component: () => import('./Echanges.vue') },

    // 5. Suivre
    { path: 'mobilites-realisees', label: 'Mobilités réalisées', component: () => import('./MobilitesRealisees.vue') },
    { path: 'tableau-de-bord', label: 'Tableau de bord', component: () => import('./TableauDeBord.vue') },

    // 6. Clôturer
    { path: 'cloture', label: 'Clôture des dossiers', component: () => import('./Cloture.vue') },
  ],
}
