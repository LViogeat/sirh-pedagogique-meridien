"""
Les listes de valeurs, en un seul appel.

Un écran qui propose un filtre « type de contrat » n'a pas à connaître les
codes : il lit ce que renvoie cet endpoint et affiche les libellés.
"""

from fastapi import APIRouter, Depends

from .. import enums, schemas
from ..config import DATE_REFERENCE
from ..security import groupe_appelant

router = APIRouter(dependencies=[Depends(groupe_appelant)])


@router.get("/referentiels", response_model=dict[str, list[schemas.ValeurReferentiel]],
            summary="Toutes les énumérations du socle, avec leur libellé français",
            tags=["Référentiels"])
def lister_referentiels() -> dict[str, list[schemas.ValeurReferentiel]]:
    return {
        nom: [
            schemas.ValeurReferentiel(
                code=membre.value, label=enums.libelle(enumeration, membre.value)
            )
            for membre in enumeration
        ]
        for nom, enumeration in enums.REFERENTIELS.items()
    }


@router.get("/date-reference", summary="La date sur laquelle tout le socle est calé",
            tags=["Référentiels"])
def lire_date_reference() -> dict:
    """
    Le socle ne regarde jamais l'horloge.

    Ancienneté, contrats arrivant à échéance, campagne en cours : tout est
    calculé par rapport à cette date. C'est ce qui rend le jeu de données
    reproductible d'une remise à zéro à l'autre.
    """
    return {"date_reference": DATE_REFERENCE.isoformat()}
