"""
Les seuils qui déclenchent un besoin.

CE FICHIER EST FAIT POUR ÊTRE RETOUCHÉ ENTRE DEUX SPRINTS.

Si un groupe manque de matière, on baisse un seuil et on relance
`POST /admin/besoins/generer` : les besoins déjà pris en charge par les
étudiants ne bougent pas, seuls des besoins nouveaux apparaissent.

Les étudiants lisent ce fichier. Ils doivent pouvoir répondre à la question
« d'où sort cette ligne dans mon écran ? » sans ouvrir le reste du code.
"""

# -----------------------------------------------------------------------------
# Règle 1 — besoin de FORMATION
#
# Un entretien constate un niveau sur une compétence ; le poste en attend un
# autre. L'écart produit un besoin de formation.
# -----------------------------------------------------------------------------

# Écart minimum, en niveaux, pour qu'un besoin soit ouvert.
# À 1, le moindre décalage compte. À 2, seuls les écarts sérieux remontent.
ECART_COMPETENCE_MINIMUM = 1

# À partir de cet écart, le besoin est prioritaire.
ECART_COMPETENCE_PRIORITAIRE = 2


# -----------------------------------------------------------------------------
# Règle 2 — besoin de MOBILITÉ
#
# Un salarié exprime une aspiration en entretien. On ne la transforme en besoin
# que si son année est satisfaisante : proposer une mobilité à quelqu'un dont
# les objectifs ne sont pas tenus n'aurait pas de sens.
# -----------------------------------------------------------------------------

# Moyenne des taux d'atteinte des objectifs, en pourcentage, au-delà de
# laquelle l'évaluation est considérée comme satisfaisante.
TAUX_ATTEINTE_SATISFAISANT = 70

# Au-delà de ce taux, le besoin de mobilité est prioritaire : c'est un profil
# qu'on risque de perdre si on ne lui propose rien.
TAUX_ATTEINTE_PRIORITAIRE = 90

# Les aspirations qui produisent un besoin de mobilité. « Montée en
# compétences » n'en fait pas partie : elle relève de la formation.
ASPIRATIONS_MOBILITE = [
    "mobilite_geographique",
    "changement_poste",
    "evolution_hierarchique",
]


# -----------------------------------------------------------------------------
# Règle 3 — besoin de RECRUTEMENT
#
# Deux déclencheurs, qui aboutissent au même besoin sur le même poste :
# le sous-effectif constaté, et le contrat qui se termine sans relève.
# -----------------------------------------------------------------------------

# Nombre de postes manquants à partir duquel le besoin est prioritaire.
SOUS_EFFECTIF_PRIORITAIRE = 2

# Fenêtre, en jours, pendant laquelle une fin de contrat est considérée comme
# imminente. Trois mois : le délai de recrutement moyen dans l'hôtellerie.
FENETRE_FIN_CONTRAT_JOURS = 90
