"""
Les besoins identifiés — le pivot du dispositif.

Lecture pour tous les groupes. Écriture limitée au statut : c'est la seule
chose qu'un module ait le droit de modifier dans le socle, et c'est ce qui
rend visible, lors des démonstrations, la chaîne entre l'évaluation et l'action.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import aliased
from sqlmodel import Session, select

from .. import enums, models, schemas
from ..config import DATE_REFERENCE
from ..db import session_socle
from ..security import GroupeAppelant, groupe_appelant

router = APIRouter(dependencies=[Depends(groupe_appelant)])

Db = Annotated[Session, Depends(session_socle)]

Concerne = aliased(models.Employee, name="concerne")


def _requete_besoins():
    return (
        select(models.IdentifiedNeed, Concerne, models.Position,
               models.Department, models.Establishment, models.Skill)
        .join(Concerne, Concerne.id == models.IdentifiedNeed.employee_id, isouter=True)
        .join(models.Position, models.Position.id == models.IdentifiedNeed.position_id)
        .join(models.Department, models.Department.id == models.Position.department_id)
        .join(models.Establishment,
              models.Establishment.id == models.IdentifiedNeed.establishment_id)
        .join(models.Skill, models.Skill.id == models.IdentifiedNeed.skill_id, isouter=True)
    )


def _ligne_besoin(besoin, salarie, poste, departement, etablissement, competence) -> dict:
    return dict(
        id=besoin.id,
        need_type=besoin.need_type,
        need_type_label=enums.libelle(enums.NeedType, besoin.need_type),
        priority=besoin.priority,
        priority_label=enums.libelle(enums.NeedPriority, besoin.priority),
        status=besoin.status,
        status_label=enums.libelle(enums.NeedStatus, besoin.status),
        origin=besoin.origin,
        detected_on=besoin.detected_on,
        employee_id=besoin.employee_id,
        employee_name=f"{salarie.first_name} {salarie.last_name}" if salarie else None,
        matricule=salarie.matricule if salarie else None,
        position_id=poste.id, position_title=poste.title,
        job_family=poste.job_family, hierarchy_level=poste.hierarchy_level,
        department_id=departement.id, department_label=departement.label,
        establishment_id=etablissement.id, establishment_name=etablissement.name,
        establishment_city=etablissement.city,
        skill_id=besoin.skill_id,
        skill_code=competence.code if competence else None,
        skill_label=competence.label if competence else None,
        review_id=besoin.review_id,
        handled_by_module=besoin.handled_by_module,
        handled_on=besoin.handled_on,
        comment=besoin.comment,
    )


@router.get("/besoins", response_model=list[schemas.BesoinOut],
            summary="Les besoins identifiés, filtrables par type et par statut",
            tags=["Besoins identifiés"])
def lister_besoins(
    db: Db,
    type_besoin: Annotated[enums.NeedType | None, Query(
        description="recrutement, formation ou mobilite")] = None,
    statut: Annotated[enums.NeedStatus | None, Query()] = None,
    priorite: Annotated[enums.NeedPriority | None, Query()] = None,
    etablissement_id: int | None = None,
    departement_id: int | None = None,
    poste_id: int | None = None,
    salarie_id: int | None = None,
    competence_id: int | None = None,
    module: Annotated[str | None, Query(
        description="Le code du groupe ayant pris le besoin en charge")] = None,
) -> list[schemas.BesoinOut]:
    requete = _requete_besoins().order_by(
        models.IdentifiedNeed.priority,
        models.Establishment.name,
        models.Position.title,
    )

    if type_besoin is not None:
        requete = requete.where(models.IdentifiedNeed.need_type == type_besoin.value)
    if statut is not None:
        requete = requete.where(models.IdentifiedNeed.status == statut.value)
    if priorite is not None:
        requete = requete.where(models.IdentifiedNeed.priority == priorite.value)
    if etablissement_id is not None:
        requete = requete.where(models.IdentifiedNeed.establishment_id == etablissement_id)
    if departement_id is not None:
        requete = requete.where(models.Position.department_id == departement_id)
    if poste_id is not None:
        requete = requete.where(models.IdentifiedNeed.position_id == poste_id)
    if salarie_id is not None:
        requete = requete.where(models.IdentifiedNeed.employee_id == salarie_id)
    if competence_id is not None:
        requete = requete.where(models.IdentifiedNeed.skill_id == competence_id)
    if module is not None:
        requete = requete.where(models.IdentifiedNeed.handled_by_module == module)

    return [schemas.BesoinOut(**_ligne_besoin(*ligne)) for ligne in db.exec(requete).all()]


@router.get("/besoins/{besoin_id}", response_model=schemas.BesoinOut,
            summary="Un besoin identifié", tags=["Besoins identifiés"])
def lire_besoin(besoin_id: int, db: Db) -> schemas.BesoinOut:
    ligne = db.exec(_requete_besoins().where(models.IdentifiedNeed.id == besoin_id)).first()
    if ligne is None:
        raise HTTPException(404, f"Aucun besoin d'identifiant {besoin_id}.")
    return schemas.BesoinOut(**_ligne_besoin(*ligne))


# -----------------------------------------------------------------------------
# Les transitions autorisées.
#
# On avance : ouvert → pris en charge → clôturé. Le retour en arrière n'est
# permis que vers « ouvert », pour qu'un groupe puisse relâcher un besoin pris
# par erreur. Un besoin clôturé ne se rouvre pas : la démonstration doit
# pouvoir s'appuyer sur un état final stable.
# -----------------------------------------------------------------------------

TRANSITIONS = {
    enums.NeedStatus.OUVERT.value: [
        enums.NeedStatus.PRIS_EN_CHARGE.value,
    ],
    enums.NeedStatus.PRIS_EN_CHARGE.value: [
        enums.NeedStatus.CLOTURE.value,
        enums.NeedStatus.OUVERT.value,
    ],
    enums.NeedStatus.CLOTURE.value: [],
}


@router.patch("/besoins/{besoin_id}", response_model=schemas.BesoinOut,
              summary="Faire évoluer le statut d'un besoin — la seule écriture "
                      "autorisée sur le socle",
              tags=["Besoins identifiés"])
def modifier_besoin(
    besoin_id: int, modification: schemas.BesoinPatch, groupe: GroupeAppelant, db: Db,
) -> schemas.BesoinOut:
    """
    Réservé aux trois modules qui consomment des besoins, et chacun ne traite
    que son type : Recrutement les besoins de recrutement, Formation ceux de
    formation, Mobilité ceux de mobilité.

    Le module n'est pas à renseigner : il est déduit du jeton.
    """
    besoin = db.get(models.IdentifiedNeed, besoin_id)
    if besoin is None:
        raise HTTPException(404, f"Aucun besoin d'identifiant {besoin_id}.")

    nouveau = modification.status.value

    if nouveau == besoin.status:
        raise HTTPException(
            409, f"Ce besoin est déjà au statut « "
                 f"{enums.libelle(enums.NeedStatus, besoin.status)} »."
        )

    if nouveau not in TRANSITIONS[besoin.status]:
        autorisees = TRANSITIONS[besoin.status]
        raise HTTPException(
            409,
            f"Transition refusée : « {enums.libelle(enums.NeedStatus, besoin.status)} » "
            f"→ « {enums.libelle(enums.NeedStatus, nouveau)} ». "
            + (f"Statuts possibles depuis ici : {', '.join(autorisees)}."
               if autorisees else "Un besoin clôturé ne peut plus changer de statut."),
        )

    # Un module ne prend en charge QUE les besoins de son type. Le module
    # Recrutement traite les besoins de recrutement, Formation ceux de
    # formation, Mobilité ceux de mobilité. Les trois autres modules ne
    # consomment pas de besoins du tout.
    if groupe.type_besoin is None:
        raise HTTPException(
            403,
            f"Le module « {groupe.libelle} » ne consomme pas de besoins identifiés. "
            f"Seuls les modules Recrutement, Formation et Mobilité en prennent en charge.",
        )

    if besoin.need_type != groupe.type_besoin:
        raise HTTPException(
            403,
            f"Ce besoin est de type « {enums.libelle(enums.NeedType, besoin.need_type)} ». "
            f"Le module « {groupe.libelle} » ne prend en charge que les besoins de type "
            f"« {enums.libelle(enums.NeedType, groupe.type_besoin)} ».",
        )

    # Un besoin déjà pris par un autre groupe ne se reprend pas : sinon deux
    # groupes travaillent sur le même sujet sans le savoir.
    if besoin.handled_by_module not in (None, groupe.code):
        raise HTTPException(
            409,
            f"Ce besoin est pris en charge par le module « {besoin.handled_by_module} ». "
            f"Votre module est « {groupe.libelle} ».",
        )

    besoin.status = nouveau
    if nouveau == enums.NeedStatus.PRIS_EN_CHARGE.value:
        besoin.handled_by_module = groupe.code
        besoin.handled_on = DATE_REFERENCE
    elif nouveau == enums.NeedStatus.OUVERT.value:
        besoin.handled_by_module = None
        besoin.handled_on = None

    if modification.comment is not None:
        besoin.comment = modification.comment

    db.add(besoin)
    db.commit()

    return lire_besoin(besoin_id, db)
