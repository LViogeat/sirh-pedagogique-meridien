"""
Préparation de la base : les rôles et les schémas des six groupes.

Exécuté à chaque démarrage de l'API, et rejouable sans effet de bord. Ajouter
un septième groupe consiste à ajouter une ligne dans la variable GROUPES, puis
à redémarrer : ni migration, ni script à lancer à la main.

LA MATRICE D'HABILITATION, EN TROIS LIGNES

    Le socle (schéma public)      lecture pour tous, écriture pour personne
    Son propre schéma             tous les droits, DDL compris
    Le schéma des autres groupes  lecture seule

Elle est appliquée par PostgreSQL. Le code de l'API n'a rien à vérifier, et
un étudiant ne peut pas la contourner, quel que soit le SQL qu'il envoie.
"""

import logging

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlmodel import Session

from .config import GROUPES

logger = logging.getLogger("socle.bootstrap")

ROLE_COLLECTIF = "grp_all"


def _creer_role(session: Session, nom: str) -> None:
    """CREATE ROLE n'a pas de IF NOT EXISTS : on regarde d'abord."""
    session.execute(text(
        f"do $$ begin "
        f"  if not exists (select 1 from pg_roles where rolname = '{nom}') then "
        f"    create role \"{nom}\" nologin; "
        f"  end if; "
        f"end $$;"
    ))


def preparer(session: Session) -> list[str]:
    """Crée ce qui manque et renvoie la liste des schémas prêts."""
    _creer_role(session, ROLE_COLLECTIF)

    # Le socle : lisible par tous les groupes, y compris les tables créées
    # après coup par une remise à zéro.
    session.execute(text(f'grant usage on schema public to "{ROLE_COLLECTIF}"'))
    session.execute(text(f'grant select on all tables in schema public to "{ROLE_COLLECTIF}"'))
    session.execute(text(
        f'alter default privileges in schema public '
        f'grant select on tables to "{ROLE_COLLECTIF}"'
    ))
    # Personne d'autre que le compte applicatif ne crée de table dans public.
    session.execute(text("revoke create on schema public from public"))

    prets = []
    for groupe in GROUPES:
        role = groupe.role_sql
        schema = groupe.code

        _creer_role(session, role)
        session.execute(text(f'grant "{ROLE_COLLECTIF}" to "{role}"'))
        # Le compte applicatif doit être membre du rôle pour pouvoir prendre
        # son identité le temps d'une requête (SET LOCAL ROLE).
        session.execute(text(f'grant "{role}" to current_user'))

        session.execute(text(f'create schema if not exists "{schema}" authorization "{role}"'))
        session.execute(text(f'alter schema "{schema}" owner to "{role}"'))

        # Les autres groupes lisent ce schéma — c'est ce qui rend l'intégration
        # inter-modules possible sans que personne ne puisse rien casser.
        session.execute(text(f'grant usage on schema "{schema}" to "{ROLE_COLLECTIF}"'))
        session.execute(text(
            f'grant select on all tables in schema "{schema}" to "{ROLE_COLLECTIF}"'
        ))
        session.execute(text(
            f'alter default privileges for role "{role}" in schema "{schema}" '
            f'grant select on tables to "{ROLE_COLLECTIF}"'
        ))

        prets.append(schema)

    session.commit()
    return prets


def reinitialiser_module(session: Session, code: str) -> None:
    """
    Vide le schéma d'un groupe et le recrée, vide.

    Sert quand un groupe s'est mis dans une impasse : tables incohérentes,
    données de test partout. Deux minutes pour repartir propre.
    """
    groupe = next((g for g in GROUPES if g.code == code), None)
    if groupe is None:
        raise ValueError(f"Aucun groupe de code « {code} ».")

    session.execute(text(f'drop schema if exists "{code}" cascade'))
    session.commit()
    preparer(session)


def preparer_sans_echouer(session: Session) -> None:
    """
    Au démarrage, une erreur de droits ne doit pas empêcher l'API de servir le
    socle en lecture : les groupes perdraient leur SQL, mais les six écrans du
    cours continueraient de fonctionner. On journalise ce qu'il faut corriger.
    """
    try:
        schemas = preparer(session)
        logger.info("Schémas de groupe prêts : %s", ", ".join(schemas))
    except SQLAlchemyError as erreur:
        session.rollback()
        logger.error(
            "Impossible de préparer les schémas des groupes : %s\n"
            "Le compte de la base doit disposer de l'attribut CREATEROLE. "
            "Sans cela, l'endpoint /sql ne fonctionnera pas.",
            erreur,
        )
