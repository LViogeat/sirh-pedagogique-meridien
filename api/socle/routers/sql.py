"""
L'accès SQL des groupes à leur propre schéma.

Chaque groupe est PROPRIÉTAIRE d'un schéma PostgreSQL portant son code. Il y
crée ses tables, les lit, les écrit. Il lit aussi le socle (`public`) et les
schémas des cinq autres groupes, ce qui permet les jointures inter-modules à
partir du moment où chacun a de la matière.

L'isolation n'est pas assurée par ce fichier : elle est assurée par PostgreSQL.
Chaque requête tourne sous le rôle `grp_<code>` du groupe appelant, qui n'a
aucun droit d'écriture ailleurs que chez lui. Une requête qui tenterait de
modifier le socle est refusée par la base, avec un message explicite.
"""

from fastapi import APIRouter, HTTPException
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from .. import schemas
from ..config import LIGNES_MAX_SQL
from ..db import session_groupe
from ..security import GroupeAppelant

router = APIRouter()


def _message_postgres(erreur: SQLAlchemyError) -> str:
    """Le message brut de PostgreSQL : c'est lui qui apprend quelque chose."""
    origine = getattr(erreur, "orig", None)
    return str(origine or erreur).strip()


@router.post("/sql", response_model=schemas.ReponseSql, tags=["SQL des modules"],
             summary="Exécuter une requête sur le schéma de votre module")
def executer(requete: schemas.RequeteSql, groupe: GroupeAppelant) -> schemas.ReponseSql:
    """
    Une seule instruction SQL, avec ses paramètres nommés.

    Les paramètres s'écrivent `:nom` et se passent dans `params`. Ne jamais
    concaténer une valeur saisie par l'utilisateur dans la requête : c'est
    exactement ce que ces paramètres évitent.

        {
          "query": "select * from candidats where statut = :statut order by nom",
          "params": { "statut": "nouveau" }
        }

    La recherche par motif fonctionne de la même façon :

        {
          "query": "select * from candidats where nom ilike :motif",
          "params": { "motif": "%mar%" }
        }

    Une instruction qui ne renvoie pas de lignes (`insert`, `update`, `delete`,
    `create table`) renvoie `rows: []` et le nombre de lignes touchées.
    """
    with session_groupe(groupe) as session:
        try:
            resultat = session.execute(text(requete.query), requete.params or {})
        except SQLAlchemyError as erreur:
            session.rollback()
            raise HTTPException(400, _message_postgres(erreur)) from None

        if resultat.returns_rows:
            colonnes = list(resultat.keys())
            lignes = [dict(zip(colonnes, ligne)) for ligne in resultat.fetchmany(LIGNES_MAX_SQL)]
            tronque = resultat.fetchone() is not None
            session.commit()
            return schemas.ReponseSql(
                columns=colonnes, rows=lignes, row_count=len(lignes), truncated=tronque
            )

        touchees = resultat.rowcount if resultat.rowcount and resultat.rowcount > 0 else 0
        session.commit()
        return schemas.ReponseSql(columns=[], rows=[], row_count=touchees, truncated=False)


@router.post("/sql/script", response_model=schemas.ReponseScriptSql, tags=["SQL des modules"],
             summary="Exécuter plusieurs instructions — pour appliquer votre schema.sql")
def executer_script(script: schemas.ScriptSql, groupe: GroupeAppelant) -> schemas.ReponseScriptSql:
    """
    Plusieurs instructions séparées par des points-virgules, sans paramètres.

    C'est l'endpoint qu'utilise la console SQL du socle pour appliquer le
    fichier `schema.sql` d'un module. Tout passe dans une seule transaction :
    si une instruction échoue, aucune n'est appliquée.
    """
    texte = script.script.strip()
    if not texte:
        raise HTTPException(400, "Le script est vide.")

    with session_groupe(groupe) as session:
        try:
            session.connection().exec_driver_sql(texte)
        except SQLAlchemyError as erreur:
            session.rollback()
            raise HTTPException(400, _message_postgres(erreur)) from None
        session.commit()

    instructions = len([i for i in texte.split(";") if i.strip()])
    return schemas.ReponseScriptSql(
        statements=instructions,
        message=f"{instructions} instruction(s) appliquée(s) au schéma « {groupe.code} ».",
    )
