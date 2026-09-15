"""
Identification des appelants.

Il n'y a rien à protéger : les données sont fictives. Le jeton sert à savoir
quel groupe appelle quoi, et à ce qu'un groupe ne puisse pas écrire dans le
schéma d'un autre par accident — un cas qui arrive tout seul quand six groupes
travaillent sur la même base avec du code généré.
"""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import GROUPES_PAR_JETON, JETON_ADMIN, Groupe

schema_jeton = HTTPBearer(
    scheme_name="Jeton de groupe",
    description="Le jeton remis à votre groupe, en en-tête "
    "`Authorization: Bearer <jeton>`.",
    auto_error=False,
)


def _jeton(credentials: HTTPAuthorizationCredentials | None) -> str:
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Aucun jeton fourni. Ajoutez l'en-tête « Authorization: Bearer <votre jeton> ».",
        )
    return credentials.credentials.strip()


def groupe_appelant(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(schema_jeton)],
) -> Groupe:
    """Le groupe identifié par le jeton, ou 401."""
    jeton = _jeton(credentials)
    groupe = GROUPES_PAR_JETON.get(jeton)
    if groupe is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Jeton inconnu. Vérifiez la valeur de VITE_API_TOKEN dans votre fichier .env.",
        )
    return groupe


def intervenant(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(schema_jeton)],
) -> str:
    """Réservé à l'intervenant : remise à zéro, génération des besoins."""
    if _jeton(credentials) != JETON_ADMIN:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Cet endpoint est réservé à l'intervenant.",
        )
    return "admin"


GroupeAppelant = Annotated[Groupe, Depends(groupe_appelant)]
Intervenant = Annotated[str, Depends(intervenant)]
