"""
Accès à la base.

Deux façons d'ouvrir une session, et la différence est tout le modèle de
sécurité du socle :

  session_socle()   — le compte applicatif. Lit et écrit le socle. Utilisé par
                      les endpoints de lecture, par le PATCH sur les besoins et
                      par les commandes d'administration.

  session_groupe()  — bascule sur le rôle PostgreSQL du groupe (`SET LOCAL
                      ROLE`) pour la durée d'une transaction. Le groupe est
                      alors propriétaire de son schéma, lecteur du socle et des
                      autres schémas, et rien d'autre. C'est PostgreSQL qui
                      refuse, pas le code Python : il n'y a rien à contourner.
"""

from collections.abc import Iterator
from contextlib import contextmanager

from sqlalchemy import text
from sqlmodel import Session, create_engine

from .config import DATABASE_URL, DELAI_MAX_SQL_MS, Groupe

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_recycle=1800)


def session_socle() -> Iterator[Session]:
    """Dépendance FastAPI : une session sur le compte applicatif."""
    with Session(engine) as session:
        yield session


@contextmanager
def session_groupe(groupe: Groupe) -> Iterator[Session]:
    """
    Une session qui n'a que les droits du groupe.

    `SET LOCAL` ne vaut que jusqu'à la fin de la transaction : la connexion
    rendue au pool repart avec les droits du compte applicatif, sans que rien
    n'ait à être remis en place.
    """
    with Session(engine) as session:
        session.execute(text(f'set local role "{groupe.role_sql}"'))
        session.execute(text(f'set local search_path = "{groupe.code}", public'))
        session.execute(text(f"set local statement_timeout = {DELAI_MAX_SQL_MS}"))
        yield session
