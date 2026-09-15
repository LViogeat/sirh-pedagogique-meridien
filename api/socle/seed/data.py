"""
Les données de référence de Sorbonne-Hôtel.

C'est ici, et seulement ici, qu'on décrit la chaîne : ses hôtels, ses
départements, son catalogue de postes, son référentiel de compétences.
Le reste du jeu de données — les salariés, leurs contrats, leurs entretiens —
est engendré à partir de ces tableaux par `seed.py`.

Pour donner plus de matière à un groupe, c'est ce fichier qu'on retouche :
augmenter un effectif cible, ouvrir un spa à Bordeaux, ajouter une compétence.
"""

from collections import namedtuple
from datetime import date

# -----------------------------------------------------------------------------
# Les cinq établissements
#
# `facteur` dimensionne l'hôtel : les effectifs cibles du catalogue de postes
# sont multipliés par cette valeur. Panthéon est le plus gros et porte le siège.
# -----------------------------------------------------------------------------

Etablissement = namedtuple(
    "Etablissement",
    "code nom ville code_postal adresse categorie ouverture siege facteur",
)

ETABLISSEMENTS = [
    Etablissement("PANTHEON",  "Sorbonne-Hôtel Panthéon",  "Paris",    "75005",
                  "12 rue Soufflot",              5, date(1987, 4, 12),  True,  1.15),
    Etablissement("BELLECOUR", "Sorbonne-Hôtel Bellecour", "Lyon",     "69002",
                  "8 place Bellecour",            4, date(1998, 9, 1),   False, 0.75),
    Etablissement("GARONNE",   "Sorbonne-Hôtel Garonne",   "Bordeaux", "33000",
                  "23 quai des Chartrons",        4, date(2004, 6, 15),  False, 0.70),
    Etablissement("PROMENADE", "Sorbonne-Hôtel Promenade", "Nice",     "06000",
                  "45 promenade des Anglais",     5, date(2011, 3, 21),  False, 1.00),
    Etablissement("MONTBLANC", "Sorbonne-Hôtel Mont-Blanc", "Annecy",  "74000",
                  "3 avenue du Lac",              4, date(2016, 12, 10), False, 0.60),
]

# Les hôtels à forte saisonnalité : c'est là que se concentrent les saisonniers.
ETABLISSEMENTS_SAISONNIERS = {"MONTBLANC", "PROMENADE"}


# -----------------------------------------------------------------------------
# Les départements
#
# Tous les hôtels n'ont pas les mêmes : le spa n'existe que dans trois d'entre
# eux, le service commercial dans trois également, et les ressources humaines
# sont centralisées au siège.
# -----------------------------------------------------------------------------

DEPARTEMENTS = [
    ("REC", "Réception"),
    ("HEB", "Hébergement"),
    ("RES", "Restauration"),
    ("CUI", "Cuisine"),
    ("SPA", "Spa & Bien-être"),
    ("TEC", "Technique & Maintenance"),
    ("COM", "Commercial"),
    ("DIR", "Direction"),
    ("RH",  "Ressources Humaines"),
]

DEPARTEMENTS_PAR_ETABLISSEMENT = {
    "PANTHEON":  ["REC", "HEB", "RES", "CUI", "SPA", "TEC", "COM", "DIR", "RH"],
    "BELLECOUR": ["REC", "HEB", "RES", "CUI", "TEC", "COM", "DIR"],
    "GARONNE":   ["REC", "HEB", "RES", "CUI", "TEC", "DIR"],
    "PROMENADE": ["REC", "HEB", "RES", "CUI", "SPA", "TEC", "COM", "DIR"],
    "MONTBLANC": ["REC", "HEB", "RES", "CUI", "SPA", "TEC", "DIR"],
}


# -----------------------------------------------------------------------------
# Le catalogue de postes
#
# `effectif` est l'effectif cible de référence, avant application du facteur de
# l'établissement. `cinq_etoiles` réserve le poste aux hôtels 5 étoiles :
# un voiturier et un sommelier ne se justifient pas dans un 4 étoiles.
#
# Niveau hiérarchique : 1 exécution · 2 qualifié · 3 encadrement · 4 direction.
# Il sert à reconstituer la chaîne managériale et à repérer une aspiration
# d'évolution hiérarchique réaliste.
# -----------------------------------------------------------------------------

Poste = namedtuple("Poste", "departement code titre famille niveau effectif cinq_etoiles")

CATALOGUE_POSTES = [
    Poste("REC", "RECEPTIONNISTE",  "Réceptionniste",             "Hébergement",  1, 4, False),
    Poste("REC", "NIGHT_AUDITOR",   "Night auditor",              "Hébergement",  2, 1, False),
    Poste("REC", "CHEF_RECEPTION",  "Chef de réception",          "Hébergement",  3, 1, False),
    Poste("REC", "BAGAGISTE",       "Bagagiste",                  "Hébergement",  1, 1, False),
    Poste("REC", "VOITURIER",       "Voiturier",                  "Hébergement",  1, 1, True),

    Poste("HEB", "VALET_CHAMBRE",   "Femme / valet de chambre",   "Hébergement",  1, 6, False),
    Poste("HEB", "GOUV_ETAGE",      "Gouvernante d'étage",        "Hébergement",  2, 1, False),
    Poste("HEB", "GOUV_GENERALE",   "Gouvernante générale",       "Hébergement",  3, 1, False),

    Poste("RES", "SERVEUR",         "Serveur",                    "Restauration", 1, 3, False),
    Poste("RES", "CHEF_RANG",       "Chef de rang",               "Restauration", 2, 1, False),
    Poste("RES", "MAITRE_HOTEL",    "Maître d'hôtel",             "Restauration", 3, 1, False),
    Poste("RES", "BARMAN",          "Barman",                     "Restauration", 2, 1, False),
    Poste("RES", "SOMMELIER",       "Sommelier",                  "Restauration", 3, 1, True),

    Poste("CUI", "PLONGEUR",        "Plongeur",                   "Cuisine",      1, 1, False),
    Poste("CUI", "COMMIS",          "Commis de cuisine",          "Cuisine",      1, 2, False),
    Poste("CUI", "CHEF_PARTIE",     "Chef de partie",             "Cuisine",      2, 2, False),
    Poste("CUI", "SECOND_CUISINE",  "Second de cuisine",          "Cuisine",      3, 1, False),
    Poste("CUI", "CHEF_CUISINE",    "Chef de cuisine",            "Cuisine",      4, 1, False),

    Poste("SPA", "PRATICIEN_SPA",   "Praticien spa",              "Bien-être",    2, 2, False),
    Poste("SPA", "RESP_SPA",        "Responsable spa",            "Bien-être",    3, 1, False),

    Poste("TEC", "TECHNICIEN",      "Technicien de maintenance",  "Technique",    2, 1, False),
    Poste("TEC", "RESP_TECHNIQUE",  "Responsable technique",      "Technique",    3, 1, False),

    Poste("COM", "CHARGE_RESA",     "Chargé de réservation",      "Commercial",   2, 1, False),
    Poste("COM", "RESP_COMMERCIAL", "Responsable commercial",     "Commercial",   3, 1, False),

    Poste("DIR", "DIRECTEUR",       "Directeur d'établissement",  "Direction",    4, 1, False),

    Poste("RH",  "CHARGE_RH",       "Chargé RH",                  "Ressources humaines", 2, 2, False),
]


# -----------------------------------------------------------------------------
# Le référentiel de compétences
# -----------------------------------------------------------------------------

Competence = namedtuple("Competence", "code libelle categorie")

COMPETENCES = [
    Competence("ACCUEIL",   "Accueil et check-in",              "technique"),
    Competence("PMS",       "Gestion des réservations (PMS)",   "technique"),
    Competence("NIGHT",     "Clôture de nuit",                  "technique"),
    Competence("CHAMBRE",   "Remise en état des chambres",      "technique"),
    Competence("QUALITE",   "Contrôle qualité des étages",      "technique"),
    Competence("SERVICE",   "Service en salle",                 "technique"),
    Competence("DRESSAGE",  "Dressage et mise en place",        "technique"),
    Competence("CUISSON",   "Techniques de cuisson",            "technique"),
    Competence("PATISSERIE","Pâtisserie",                       "technique"),
    Competence("HACCP",     "Hygiène et méthode HACCP",         "technique"),
    Competence("MIXO",      "Mixologie",                        "technique"),
    Competence("VINS",      "Dégustation et accords mets-vins", "technique"),
    Competence("SOINS",     "Protocoles de soin",               "technique"),
    Competence("MASSAGE",   "Massage bien-être",                "technique"),
    Competence("ELEC",      "Électricité du bâtiment",          "technique"),
    Competence("CVC",       "Plomberie et climatisation",       "technique"),
    Competence("YIELD",     "Yield management",                 "technique"),
    Competence("VENTE",     "Techniques de vente",              "technique"),

    Competence("RELCLI",    "Relation client",                  "relationnel"),
    Competence("RECLAM",    "Gestion des réclamations",         "relationnel"),
    Competence("EQUIPE",    "Travail en équipe",                "relationnel"),
    Competence("DISCRET",   "Discrétion et confidentialité",    "relationnel"),

    Competence("EN",        "Anglais professionnel",            "langue"),
    Competence("ES",        "Espagnol professionnel",           "langue"),
    Competence("IT",        "Italien professionnel",            "langue"),
    Competence("ZH",        "Mandarin professionnel",           "langue"),

    Competence("ENCADRE",   "Encadrement d'équipe",             "management"),
    Competence("PLANIF",    "Planification des effectifs",      "management"),
    Competence("ENTRETIEN", "Conduite d'entretien",             "management"),
    Competence("BUDGET",    "Gestion budgétaire",               "management"),
]


# -----------------------------------------------------------------------------
# Les compétences attendues par poste, sur une échelle de 1 à 4
#
# C'est ce tableau qui donne son sens au module Formation : l'écart entre le
# niveau attendu ici et le niveau constaté en entretien produit un besoin.
# -----------------------------------------------------------------------------

COMPETENCES_ATTENDUES = {
    "RECEPTIONNISTE":  [("ACCUEIL", 3), ("PMS", 3), ("RELCLI", 3), ("EN", 3), ("ES", 2)],
    "NIGHT_AUDITOR":   [("NIGHT", 3), ("PMS", 3), ("ACCUEIL", 2), ("EN", 2)],
    "CHEF_RECEPTION":  [("ACCUEIL", 3), ("PMS", 4), ("ENCADRE", 3), ("PLANIF", 3),
                        ("RECLAM", 4), ("EN", 3)],
    "BAGAGISTE":       [("ACCUEIL", 2), ("RELCLI", 3), ("EN", 2)],
    "VOITURIER":       [("ACCUEIL", 2), ("RELCLI", 3), ("DISCRET", 3)],

    "VALET_CHAMBRE":   [("CHAMBRE", 3), ("DISCRET", 3), ("EQUIPE", 2)],
    "GOUV_ETAGE":      [("CHAMBRE", 3), ("QUALITE", 3), ("ENCADRE", 2), ("PLANIF", 2)],
    "GOUV_GENERALE":   [("QUALITE", 4), ("ENCADRE", 3), ("PLANIF", 3), ("BUDGET", 2)],

    "SERVEUR":         [("SERVICE", 3), ("DRESSAGE", 2), ("RELCLI", 3), ("EN", 2)],
    "CHEF_RANG":       [("SERVICE", 4), ("DRESSAGE", 3), ("RELCLI", 3), ("ENCADRE", 2),
                        ("EN", 3)],
    "MAITRE_HOTEL":    [("SERVICE", 4), ("ENCADRE", 3), ("PLANIF", 3), ("RECLAM", 4),
                        ("VINS", 2), ("EN", 3)],
    "BARMAN":          [("MIXO", 3), ("SERVICE", 3), ("RELCLI", 3), ("EN", 2)],
    "SOMMELIER":       [("VINS", 4), ("SERVICE", 3), ("RELCLI", 3), ("EN", 3), ("IT", 2)],

    "PLONGEUR":        [("HACCP", 2), ("EQUIPE", 2)],
    "COMMIS":          [("CUISSON", 2), ("HACCP", 3), ("EQUIPE", 2)],
    "CHEF_PARTIE":     [("CUISSON", 3), ("HACCP", 3), ("DRESSAGE", 3), ("EQUIPE", 3)],
    "SECOND_CUISINE":  [("CUISSON", 4), ("HACCP", 4), ("ENCADRE", 3), ("PLANIF", 2),
                        ("PATISSERIE", 3)],
    "CHEF_CUISINE":    [("CUISSON", 4), ("HACCP", 4), ("ENCADRE", 4), ("BUDGET", 3),
                        ("PLANIF", 3)],

    "PRATICIEN_SPA":   [("SOINS", 3), ("MASSAGE", 3), ("RELCLI", 3), ("DISCRET", 3)],
    "RESP_SPA":        [("SOINS", 3), ("ENCADRE", 3), ("BUDGET", 2), ("VENTE", 3)],

    "TECHNICIEN":      [("ELEC", 3), ("CVC", 3), ("EQUIPE", 2)],
    "RESP_TECHNIQUE":  [("ELEC", 3), ("CVC", 3), ("ENCADRE", 3), ("BUDGET", 3)],

    "CHARGE_RESA":     [("PMS", 3), ("YIELD", 2), ("VENTE", 3), ("EN", 3)],
    "RESP_COMMERCIAL": [("YIELD", 4), ("VENTE", 4), ("ENCADRE", 3), ("BUDGET", 3),
                        ("EN", 3)],

    "DIRECTEUR":       [("ENCADRE", 4), ("BUDGET", 4), ("YIELD", 3), ("RECLAM", 4),
                        ("EN", 3)],

    "CHARGE_RH":       [("ENTRETIEN", 3), ("PLANIF", 3), ("DISCRET", 4), ("EQUIPE", 3)],
}


# -----------------------------------------------------------------------------
# Identités
#
# Prénoms et noms français, pour que les listes soient crédibles en démonstration.
# -----------------------------------------------------------------------------

PRENOMS_F = [
    "Camille", "Léa", "Manon", "Chloé", "Inès", "Sarah", "Jeanne", "Louise",
    "Nadia", "Fatima", "Sophie", "Aurélie", "Mathilde", "Claire", "Amandine",
    "Élodie", "Sandrine", "Karine", "Valérie", "Delphine", "Céline", "Nathalie",
    "Maëva", "Oumou", "Lucie", "Émilie", "Anaïs", "Pauline", "Justine", "Marion",
    "Audrey", "Hélène", "Béatrice", "Corinne", "Sylvie", "Isabelle",
]

PRENOMS_M = [
    "Lucas", "Hugo", "Théo", "Nathan", "Antoine", "Julien", "Maxime", "Romain",
    "Thomas", "Alexandre", "Nicolas", "Sébastien", "Yanis", "Mehdi", "Karim",
    "Bastien", "Quentin", "Guillaume", "Vincent", "Damien", "Olivier", "Pascal",
    "Jean-Marc", "Frédéric", "Stéphane", "Laurent", "Christophe", "Fabrice",
    "Adrien", "Benoît", "Cédric", "Émile", "Gaël", "Mathieu", "Samir", "Tristan",
]

NOMS = [
    "Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit",
    "Durand", "Leroy", "Moreau", "Simon", "Laurent", "Lefebvre", "Michel",
    "Garcia", "David", "Bertrand", "Roux", "Vincent", "Fournier", "Morel",
    "Girard", "André", "Lefèvre", "Mercier", "Dupont", "Lambert", "Bonnet",
    "François", "Martinez", "Legrand", "Garnier", "Faure", "Rousseau", "Blanc",
    "Guérin", "Muller", "Henry", "Roussel", "Nicolas", "Perrin", "Morin",
    "Mathieu", "Clément", "Gauthier", "Dumont", "Lopez", "Fontaine", "Chevalier",
    "Robin", "Masson", "Sanchez", "Gérard", "Nguyen", "Boyer", "Denis",
    "Lemaire", "Duval", "Joly", "Gautier", "Roger", "Roche", "Roy", "Noël",
    "Meyer", "Lucas", "Meunier", "Jean", "Perez", "Marchand", "Dufour",
    "Blanchard", "Marie", "Barbier", "Brun", "Dumas", "Brunet", "Schmitt",
    "Leroux", "Colin", "Fernandez", "Pierre", "Renard", "Arnaud", "Rolland",
    "Caron", "Aubert", "Giraud", "Leclerc", "Vidal", "Bourgeois", "Renaud",
]


# -----------------------------------------------------------------------------
# Les libellés d'objectifs proposés en entretien, par famille de métier.
# -----------------------------------------------------------------------------

OBJECTIFS_PAR_FAMILLE = {
    "Hébergement": [
        "Porter la note d'accueil à 4,5/5 sur les avis en ligne",
        "Réduire le temps d'attente au check-in à moins de 4 minutes",
        "Fiabiliser la saisie des réservations dans le PMS",
        "Augmenter le taux de surclassement vendu de 10 %",
    ],
    "Restauration": [
        "Augmenter le ticket moyen au restaurant de 8 %",
        "Réduire les ruptures de mise en place à zéro sur le service du soir",
        "Former deux commis aux techniques de service en salle",
        "Développer la vente additionnelle sur la carte des vins",
    ],
    "Cuisine": [
        "Réduire le gaspillage alimentaire de 15 %",
        "Tenir le coût matière sous 28 % du chiffre d'affaires",
        "Obtenir la conformité totale à l'audit HACCP",
        "Renouveler la carte deux fois dans l'année",
    ],
    "Bien-être": [
        "Atteindre un taux d'occupation des cabines de 70 %",
        "Développer la vente de produits de soin de 20 %",
        "Mettre en place deux nouveaux protocoles de soin",
    ],
    "Technique": [
        "Réduire le délai moyen d'intervention à moins de 2 heures",
        "Mettre en place le plan de maintenance préventive",
        "Réduire la consommation énergétique de 10 %",
    ],
    "Commercial": [
        "Augmenter le revenu par chambre disponible de 6 %",
        "Signer trois nouveaux comptes entreprises",
        "Améliorer le taux de transformation des demandes de groupe",
    ],
    "Direction": [
        "Tenir le budget d'exploitation de l'établissement",
        "Porter le taux d'occupation annuel à 78 %",
        "Réduire le turnover de l'établissement de 5 points",
    ],
    "Ressources humaines": [
        "Réduire le délai moyen de recrutement à 30 jours",
        "Atteindre 90 % d'entretiens annuels réalisés",
        "Déployer le plan de formation sur les cinq établissements",
    ],
}

COMMENTAIRES_ENTRETIEN = [
    "Année solide, tenue du poste sans réserve.",
    "Progression nette sur la technique, à confirmer sur l'encadrement.",
    "Très bon relationnel client, régulièrement cité dans les avis.",
    "Quelques difficultés en période de forte affluence, accompagnement à prévoir.",
    "Salarié moteur dans l'équipe, prend des initiatives.",
    "Résultats en retrait cette année, contexte de sous-effectif à prendre en compte.",
    "Maîtrise du poste acquise, prêt à élargir son périmètre.",
    "Ponctualité et sérieux irréprochables.",
]
