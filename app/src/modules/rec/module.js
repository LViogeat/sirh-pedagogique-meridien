// Manifeste du module « rec ».
//
// Au démarrage, le module met ses tables à jour si schema.sql a changé
// (voir _schema.js) : plus besoin de le recoller dans la Console SQL.
//
// Les écrans du menu n'ont pas besoin d'y figurer : tout fichier .vue posé
// dans ce dossier devient un écran. On ne déclare ici que les pages de DÉTAIL,
// qui reçoivent un identifiant dans leur adresse et restent hors du menu
// (masque: true) : on y arrive par un clic.
import { assurerSchema } from './_schema.js'

assurerSchema()

export default {
  code: 'rec',
  routes: [
    {
      path: 'candidat/:id',
      label: 'Page candidat',
      masque: true,
      component: () => import('./_PageCandidat.vue'),
    },
    {
      path: 'entretien/:id',
      label: "Compte rendu d'entretien",
      masque: true,
      component: () => import('./_CompteRendu.vue'),
    },
    {
      path: 'offre/:id',
      label: 'Page DP',
      masque: true,
      component: () => import('./_PageOffre.vue'),
    },
  ],
}
