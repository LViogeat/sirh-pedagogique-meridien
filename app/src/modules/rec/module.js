// Manifeste du module « rec ».
//
// Les écrans du menu n'ont pas besoin d'y figurer : tout fichier .vue posé
// dans ce dossier devient un écran. On ne déclare ici que les pages de DÉTAIL,
// qui reçoivent un identifiant dans leur adresse et restent hors du menu
// (masque: true) : on y arrive par un clic.
export default {
  code: 'rec',
  routes: [
    {
      path: 'candidat/:id',
      label: 'Page candidat',
      masque: true,
      component: () => import('./_PageCandidat.vue'),
    },
  ],
}
