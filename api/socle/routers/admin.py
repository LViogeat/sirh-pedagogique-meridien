"""
Les commandes de l'intervenant.

Réservées au jeton administrateur. Ce sont elles qui permettent de tenir le
cours : remettre les données à zéro entre deux sprints, régénérer les besoins
après avoir ajusté un seuil, et repartir propre sur le schéma d'un groupe qui
s'est mis en difficulté.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlmodel import Session, select

from .. import models
from ..bootstrap import reinitialiser_module
from ..config import DATE_REFERENCE, GROUPES_PAR_CODE
from ..db import session_socle
from ..rules import besoins as regles_besoins
from ..seed import seed
from ..security import Intervenant

router = APIRouter(prefix="/admin", tags=["Administration"])

Db = Annotated[Session, Depends(session_socle)]


@router.post("/reset", summary="Remettre les données du socle à zéro")
def reinitialiser(_: Intervenant, db: Db) -> dict:
    """
    Vide le socle, le recharge à l'identique, puis régénère les besoins.

    Les schémas des six groupes ne sont pas touchés : le travail des étudiants
    survit à une remise à zéro. Les identifiants du socle repartent à 1 et le
    jeu de données est reproductible, donc les références logiques stockées par
    les modules (`besoin_id`, `employee_id`…) restent valables.
    """
    donnees = seed.remettre_a_zero(db)
    generation = regles_besoins.generer(db)
    return {
        "date_reference": DATE_REFERENCE.isoformat(),
        "donnees": donnees,
        "besoins": generation,
    }


@router.post("/besoins/generer", summary="Rejouer les trois règles de génération des besoins")
def generer_besoins(_: Intervenant, db: Db) -> dict:
    """
    À lancer après avoir ajusté un seuil dans `rules/seuils.py`.

    Les besoins pris en charge ou clôturés par un groupe ne sont jamais
    modifiés : la commande peut être relancée en plein sprint.
    """
    return regles_besoins.generer(db)


@router.post("/modules/{code}/reset", summary="Vider et recréer le schéma d'un groupe")
def reinitialiser_schema(code: str, _: Intervenant, db: Db) -> dict:
    """
    Supprime toutes les tables d'un groupe et recrée son schéma, vide.

    Le groupe recrée ensuite ses tables depuis la console SQL.
    """
    if code not in GROUPES_PAR_CODE:
        raise HTTPException(404, f"Aucun groupe de code « {code} ». "
                                 f"Groupes connus : {', '.join(GROUPES_PAR_CODE)}.")
    reinitialiser_module(db, code)
    return {"message": f"Le schéma « {code} » a été vidé et recréé."}


@router.get("/etat", summary="Compter les lignes de chaque table du socle")
def etat(_: Intervenant, db: Db) -> dict:
    """Le contrôle de cohérence, à passer après chaque remise à zéro."""
    comptes = {}
    for modele in reversed(models.TABLES_DANS_L_ORDRE):
        comptes[modele.__tablename__] = db.exec(
            select(func.count()).select_from(modele)
        ).one()
    return {"date_reference": DATE_REFERENCE.isoformat(), "lignes": comptes}
