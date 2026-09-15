"""
Les énumérations du socle, avec leur libellé français.

Un seul endroit les décrit, et c'est cet endroit qui alimente à la fois :
  - les valeurs autorisées dans la spécification OpenAPI,
  - la contrainte CHECK posée en base,
  - l'endpoint GET /referentiels que les écrans utilisent pour leurs listes
    déroulantes.

Les codes restent courts et stables : ce sont eux qui voyagent dans l'API et
dans le SQL des étudiants. Les libellés, eux, sont faits pour être affichés.
"""

from enum import Enum


class EmployeeStatus(str, Enum):
    ACTIF = "actif"
    SORTI = "sorti"


class ContractType(str, Enum):
    CDI = "CDI"
    CDD = "CDD"
    APPRENTISSAGE = "APPRENTISSAGE"
    SAISONNIER = "SAISONNIER"
    EXTRA = "EXTRA"


class ContractStatus(str, Enum):
    ACTIF = "actif"
    TERMINE = "termine"
    A_VENIR = "a_venir"


class SkillCategory(str, Enum):
    TECHNIQUE = "technique"
    RELATIONNEL = "relationnel"
    LANGUE = "langue"
    MANAGEMENT = "management"


class CampaignStatus(str, Enum):
    PREPAREE = "preparee"
    OUVERTE = "ouverte"
    CLOTUREE = "cloturee"


class ReviewStatus(str, Enum):
    PLANIFIE = "planifie"
    REALISE = "realise"
    VALIDE = "valide"


class AspirationType(str, Enum):
    MOBILITE_GEOGRAPHIQUE = "mobilite_geographique"
    CHANGEMENT_POSTE = "changement_poste"
    EVOLUTION_HIERARCHIQUE = "evolution_hierarchique"
    MONTEE_COMPETENCES = "montee_competences"


class NeedType(str, Enum):
    RECRUTEMENT = "recrutement"
    FORMATION = "formation"
    MOBILITE = "mobilite"


class NeedPriority(str, Enum):
    HAUTE = "haute"
    MOYENNE = "moyenne"
    BASSE = "basse"


class NeedStatus(str, Enum):
    OUVERT = "ouvert"
    PRIS_EN_CHARGE = "pris_en_charge"
    CLOTURE = "cloture"


# -----------------------------------------------------------------------------
# Les libellés affichables, par énumération.
# -----------------------------------------------------------------------------

LIBELLES: dict[type[Enum], dict[str, str]] = {
    EmployeeStatus: {
        "actif": "Présent",
        "sorti": "Sorti des effectifs",
    },
    ContractType: {
        "CDI": "CDI",
        "CDD": "CDD",
        "APPRENTISSAGE": "Contrat d'apprentissage",
        "SAISONNIER": "Contrat saisonnier",
        "EXTRA": "Extra",
    },
    ContractStatus: {
        "actif": "En cours",
        "termine": "Terminé",
        "a_venir": "À venir",
    },
    SkillCategory: {
        "technique": "Compétence technique",
        "relationnel": "Savoir-être",
        "langue": "Langue",
        "management": "Management",
    },
    CampaignStatus: {
        "preparee": "En préparation",
        "ouverte": "Ouverte",
        "cloturee": "Clôturée",
    },
    ReviewStatus: {
        "planifie": "Planifié",
        "realise": "Réalisé",
        "valide": "Validé",
    },
    AspirationType: {
        "mobilite_geographique": "Mobilité géographique",
        "changement_poste": "Changement de poste",
        "evolution_hierarchique": "Évolution hiérarchique",
        "montee_competences": "Montée en compétences",
    },
    NeedType: {
        "recrutement": "Recrutement",
        "formation": "Formation",
        "mobilite": "Mobilité",
    },
    NeedPriority: {
        "haute": "Haute",
        "moyenne": "Moyenne",
        "basse": "Basse",
    },
    NeedStatus: {
        "ouvert": "Ouvert",
        "pris_en_charge": "Pris en charge",
        "cloture": "Clôturé",
    },
}


def libelle(enumeration: type[Enum], code: str | None) -> str | None:
    """Le libellé français d'un code, ou le code lui-même s'il est inconnu."""
    if code is None:
        return None
    return LIBELLES.get(enumeration, {}).get(code, code)


# -----------------------------------------------------------------------------
# Le catalogue exposé par GET /referentiels.
#
# Le nom à gauche est celui que les étudiants emploient dans leurs écrans :
#   const types = referentiels.type_contrat
# -----------------------------------------------------------------------------

REFERENTIELS: dict[str, type[Enum]] = {
    "statut_salarie": EmployeeStatus,
    "type_contrat": ContractType,
    "statut_contrat": ContractStatus,
    "categorie_competence": SkillCategory,
    "statut_campagne": CampaignStatus,
    "statut_entretien": ReviewStatus,
    "type_aspiration": AspirationType,
    "type_besoin": NeedType,
    "priorite_besoin": NeedPriority,
    "statut_besoin": NeedStatus,
}


def valeurs(enumeration: type[Enum]) -> list[str]:
    return [membre.value for membre in enumeration]
