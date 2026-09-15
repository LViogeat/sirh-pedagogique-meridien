"""
Configuration du socle — tout se règle par variables d'environnement.

Ce fichier est volontairement sans magie : un seul endroit à lire pour savoir
ce que l'API attend de son environnement, et ce qu'elle fait sans configuration.
"""

import os
from dataclasses import dataclass
from datetime import date


def _env(nom: str, defaut: str) -> str:
    return os.environ.get(nom, defaut).strip()


# -----------------------------------------------------------------------------
# Base de données
# -----------------------------------------------------------------------------

DATABASE_URL = _env(
    "DATABASE_URL",
    "postgresql+psycopg://sirh:sirh@localhost:5432/sirh",
)


# -----------------------------------------------------------------------------
# Date de référence
#
# TOUTE la démonstration est calculée par rapport à cette date, jamais par
# rapport à l'horloge : ancienneté, contrats arrivant à échéance, campagne
# d'évaluation en cours. C'est ce qui rend le jeu de données reproductible —
# remis à zéro deux fois, il produit exactement les mêmes lignes.
#
# À régler sur le premier jour du cours avant la première séance.
# -----------------------------------------------------------------------------

DATE_REFERENCE = date.fromisoformat(_env("DATE_REFERENCE", "2026-09-15"))


# -----------------------------------------------------------------------------
# Groupes étudiants
#
# Format : "code:Libellé:jeton,code:Libellé:jeton,..."
#
# Le code est aussi le nom du schéma PostgreSQL du groupe. Ajouter un groupe
# revient à ajouter une entrée ici puis à relancer `python -m socle.bootstrap` :
# aucune ligne de code à modifier.
#
# Les jetons ci-dessous ne protègent rien — les données sont fictives. Ils
# servent à savoir quel groupe appelle quoi, et à empêcher un groupe d'écrire
# dans le schéma d'un autre par inattention.
# -----------------------------------------------------------------------------

_GROUPES_DEFAUT = ",".join(
    [
        "rec:Recrutement:jeton-rec:recrutement",
        "form:Formation:jeton-form:formation",
        "mob:Mobilité & carrière:jeton-mob:mobilite",
        "gta:Gestion des temps:jeton-gta",
        "portail:Portail RH & Self-Service:jeton-portail",
        "onb:Onboarding & Offboarding:jeton-onb",
    ]
)


@dataclass(frozen=True)
class Groupe:
    code: str  # aussi le nom du schéma PostgreSQL et du rôle grp_<code>
    libelle: str
    jeton: str
    type_besoin: str | None = None

    @property
    def role_sql(self) -> str:
        return f"grp_{self.code}"


def _lire_groupes(brut: str) -> list[Groupe]:
    """
    Lit « code:Libellé:jeton[:type_besoin] », séparés par des virgules.

    Le quatrième champ dit quel type de besoin ce module a le droit de prendre
    en charge. Trois groupes seulement en consomment : Recrutement, Formation
    et Mobilité. Les trois autres n'en ont pas, et l'API leur refusera toute
    écriture sur les besoins.
    """
    groupes = []
    for entree in brut.split(","):
        entree = entree.strip()
        if not entree:
            continue
        morceaux = [m.strip() for m in entree.split(":", 3)]
        if len(morceaux) < 3:
            raise ValueError(
                f"GROUPES : l'entrée « {entree} » est mal formée. Attendu : "
                f"code:Libellé:jeton[:type_besoin], séparés par des virgules."
            )
        code, libelle, jeton = morceaux[0], morceaux[1], morceaux[2]
        type_besoin = morceaux[3] if len(morceaux) == 4 and morceaux[3] else None
        groupes.append(Groupe(code, libelle, jeton, type_besoin))
    return groupes


GROUPES = _lire_groupes(_env("GROUPES", _GROUPES_DEFAUT))

GROUPES_PAR_CODE = {g.code: g for g in GROUPES}
GROUPES_PAR_JETON = {g.jeton: g for g in GROUPES}


# -----------------------------------------------------------------------------
# Jeton intervenant
#
# Ouvre /admin : remise à zéro des données, régénération des besoins,
# réinitialisation du schéma d'un groupe. À changer en production.
# -----------------------------------------------------------------------------

JETON_ADMIN = _env("JETON_ADMIN", "jeton-admin")


# -----------------------------------------------------------------------------
# CORS
#
# Le front de chaque groupe tourne sur un sous-domaine différent de l'API.
# Sans cette autorisation, le navigateur bloque tous les appels.
#
# "*" convient au cours : données fictives, jetons d'identification. Pour
# restreindre, lister les origines séparées par des virgules.
# -----------------------------------------------------------------------------

ORIGINES_AUTORISEES = [o.strip() for o in _env("ORIGINES_AUTORISEES", "*").split(",")]


# -----------------------------------------------------------------------------
# Garde-fou sur les requêtes SQL des étudiants
#
# Une requête qui dépasse ce délai est interrompue : la base est partagée par
# les six groupes, une jointure oubliée ne doit pas bloquer la démonstration.
# -----------------------------------------------------------------------------

DELAI_MAX_SQL_MS = int(_env("DELAI_MAX_SQL_MS", "5000"))

LIGNES_MAX_SQL = int(_env("LIGNES_MAX_SQL", "2000"))
