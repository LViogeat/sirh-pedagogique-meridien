"""
Les endpoints de lecture de l'Évaluation.

C'est d'ici que sort la matière des groupes Recrutement, Formation et
Mobilité : les entretiens constatent, les besoins en découlent.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, func
from sqlalchemy.orm import aliased
from sqlmodel import Session, select

from .. import enums, models, schemas
from ..db import session_socle
from ..security import groupe_appelant

router = APIRouter(dependencies=[Depends(groupe_appelant)])

Db = Annotated[Session, Depends(session_socle)]

CONTRAT_ACTIF = models.Contract.status == enums.ContractStatus.ACTIF.value

Evalue = aliased(models.Employee, name="evalue")
Evaluateur = aliased(models.Employee, name="evaluateur")


def _nom(salarie) -> str:
    return f"{salarie.first_name} {salarie.last_name}"


# =============================================================================
# Campagnes
# =============================================================================


@router.get("/campagnes", response_model=list[schemas.CampagneOut],
            summary="Les campagnes d'entretiens annuels", tags=["Évaluation"])
def lister_campagnes(db: Db) -> list[schemas.CampagneOut]:
    nombres = dict(db.exec(
        select(models.Review.campaign_id, func.count()).group_by(models.Review.campaign_id)
    ).all())

    return [
        schemas.CampagneOut(
            **c.model_dump(),
            status_label=enums.libelle(enums.CampaignStatus, c.status),
            reviews_count=nombres.get(c.id, 0),
        )
        for c in db.exec(select(models.Campaign).order_by(models.Campaign.year.desc())).all()
    ]


# =============================================================================
# Entretiens
# =============================================================================


def _requete_entretiens():
    return (
        select(models.Review, models.Campaign, Evalue, Evaluateur,
               models.Position, models.Establishment)
        .join(models.Campaign, models.Campaign.id == models.Review.campaign_id)
        .join(Evalue, Evalue.id == models.Review.employee_id)
        .join(Evaluateur, Evaluateur.id == models.Review.reviewer_id)
        .join(models.Contract,
              and_(models.Contract.employee_id == Evalue.id, CONTRAT_ACTIF), isouter=True)
        .join(models.Position, models.Position.id == models.Contract.position_id, isouter=True)
        .join(models.Establishment,
              models.Establishment.id == models.Contract.establishment_id, isouter=True)
    )


def _agregats_entretiens(db: Session) -> dict:
    """Les compteurs affichés dans la liste, calculés en trois requêtes."""
    objectifs = {
        review_id: (nombre, round(moyenne))
        for review_id, nombre, moyenne in db.exec(
            select(models.Goal.review_id, func.count(),
                   func.avg(models.Goal.achievement_rate))
            .group_by(models.Goal.review_id)
        ).all()
    }

    # Un écart = un niveau constaté inférieur au niveau attendu sur le poste
    # que le salarié occupe aujourd'hui.
    ecarts = dict(db.exec(
        select(models.Review.id, func.count())
        .select_from(models.SkillAssessment)
        .join(models.Review, models.Review.id == models.SkillAssessment.review_id)
        .join(models.Contract,
              and_(models.Contract.employee_id == models.Review.employee_id, CONTRAT_ACTIF))
        .join(models.PositionSkill,
              and_(models.PositionSkill.position_id == models.Contract.position_id,
                   models.PositionSkill.skill_id == models.SkillAssessment.skill_id))
        .where(models.SkillAssessment.assessed_level < models.PositionSkill.required_level)
        .group_by(models.Review.id)
    ).all())

    aspirations = dict(db.exec(
        select(models.Aspiration.review_id, func.count())
        .group_by(models.Aspiration.review_id)
    ).all())

    return {"objectifs": objectifs, "ecarts": ecarts, "aspirations": aspirations}


def _ligne_entretien(ligne, agregats: dict) -> dict:
    entretien, campagne, evalue, evaluateur, poste, etablissement = ligne
    nombre, moyenne = agregats["objectifs"].get(entretien.id, (0, None))
    return dict(
        id=entretien.id,
        campaign_id=campagne.id, campaign_label=campagne.label,
        employee_id=evalue.id, employee_name=_nom(evalue), matricule=evalue.matricule,
        position_title=poste.title if poste else None,
        establishment_id=etablissement.id if etablissement else None,
        establishment_name=etablissement.name if etablissement else None,
        reviewer_id=evaluateur.id, reviewer_name=_nom(evaluateur),
        review_date=entretien.review_date, status=entretien.status,
        status_label=enums.libelle(enums.ReviewStatus, entretien.status),
        summary=entretien.summary,
        goals_count=nombre, average_achievement_rate=moyenne,
        skill_gaps_count=agregats["ecarts"].get(entretien.id, 0),
        aspirations_count=agregats["aspirations"].get(entretien.id, 0),
    )


@router.get("/entretiens", response_model=list[schemas.EntretienOut],
            summary="Les entretiens annuels", tags=["Évaluation"])
def lister_entretiens(
    db: Db,
    campagne_id: int | None = None,
    salarie_id: int | None = None,
    evaluateur_id: Annotated[int | None, Query(description="Les entretiens menés "
                                                           "par un manager")] = None,
    etablissement_id: int | None = None,
    statut: Annotated[enums.ReviewStatus | None, Query()] = None,
) -> list[schemas.EntretienOut]:
    requete = _requete_entretiens().order_by(models.Review.review_date.desc())

    if campagne_id is not None:
        requete = requete.where(models.Review.campaign_id == campagne_id)
    if salarie_id is not None:
        requete = requete.where(models.Review.employee_id == salarie_id)
    if evaluateur_id is not None:
        requete = requete.where(models.Review.reviewer_id == evaluateur_id)
    if etablissement_id is not None:
        requete = requete.where(models.Contract.establishment_id == etablissement_id)
    if statut is not None:
        requete = requete.where(models.Review.status == statut.value)

    agregats = _agregats_entretiens(db)
    return [
        schemas.EntretienOut(**_ligne_entretien(ligne, agregats))
        for ligne in db.exec(requete).all()
    ]


@router.get("/entretiens/{entretien_id}", response_model=schemas.EntretienDetailOut,
            summary="Un entretien, avec ses objectifs, ses évaluations et ses aspirations",
            tags=["Évaluation"])
def lire_entretien(entretien_id: int, db: Db) -> schemas.EntretienDetailOut:
    ligne = db.exec(_requete_entretiens().where(models.Review.id == entretien_id)).first()
    if ligne is None:
        raise HTTPException(404, f"Aucun entretien d'identifiant {entretien_id}.")

    agregats = _agregats_entretiens(db)
    poste = ligne[4]

    objectifs = db.exec(
        select(models.Goal).where(models.Goal.review_id == entretien_id)
        .order_by(models.Goal.id)
    ).all()

    niveaux_attendus = {}
    if poste is not None:
        niveaux_attendus = dict(db.exec(
            select(models.PositionSkill.skill_id, models.PositionSkill.required_level)
            .where(models.PositionSkill.position_id == poste.id)
        ).all())

    evaluations = db.exec(
        select(models.SkillAssessment, models.Skill)
        .join(models.Skill, models.Skill.id == models.SkillAssessment.skill_id)
        .where(models.SkillAssessment.review_id == entretien_id)
        .order_by(models.Skill.category, models.Skill.label)
    ).all()

    return schemas.EntretienDetailOut(
        **_ligne_entretien(ligne, agregats),
        goals=[schemas.ObjectifOut(**o.model_dump()) for o in objectifs],
        skill_assessments=[
            schemas.EvaluationCompetenceOut(
                id=ev.id, review_id=ev.review_id, skill_id=s.id, skill_code=s.code,
                skill_label=s.label, category=s.category,
                assessed_level=ev.assessed_level,
                required_level=niveaux_attendus.get(s.id),
                gap=(niveaux_attendus[s.id] - ev.assessed_level
                     if s.id in niveaux_attendus else None),
                comment=ev.comment,
            )
            for ev, s in evaluations
        ],
        aspirations=_aspirations(db, entretien_id=entretien_id),
    )


# =============================================================================
# Aspirations
# =============================================================================

EtablissementCible = aliased(models.Establishment, name="etablissement_cible")
PosteCible = aliased(models.Position, name="poste_cible")


def _aspirations(db: Session, **filtres) -> list[schemas.AspirationOut]:
    requete = (
        select(models.Aspiration, models.Review, Evalue, EtablissementCible, PosteCible)
        .join(models.Review, models.Review.id == models.Aspiration.review_id)
        .join(Evalue, Evalue.id == models.Review.employee_id)
        .join(EtablissementCible,
              EtablissementCible.id == models.Aspiration.target_establishment_id, isouter=True)
        .join(PosteCible, PosteCible.id == models.Aspiration.target_position_id, isouter=True)
        .order_by(models.Aspiration.id)
    )

    if filtres.get("entretien_id") is not None:
        requete = requete.where(models.Aspiration.review_id == filtres["entretien_id"])
    if filtres.get("type_aspiration") is not None:
        requete = requete.where(
            models.Aspiration.aspiration_type == filtres["type_aspiration"])
    if filtres.get("salarie_id") is not None:
        requete = requete.where(models.Review.employee_id == filtres["salarie_id"])
    if filtres.get("etablissement_id") is not None:
        requete = requete.join(
            models.Contract,
            and_(models.Contract.employee_id == Evalue.id, CONTRAT_ACTIF),
        ).where(models.Contract.establishment_id == filtres["etablissement_id"])

    return [
        schemas.AspirationOut(
            id=a.id, review_id=a.review_id, employee_id=evalue.id,
            employee_name=_nom(evalue),
            aspiration_type=a.aspiration_type,
            aspiration_type_label=enums.libelle(enums.AspirationType, a.aspiration_type),
            target_establishment_id=a.target_establishment_id,
            target_establishment_name=cible_etab.name if cible_etab else None,
            target_position_id=a.target_position_id,
            target_position_title=cible_poste.title if cible_poste else None,
            comment=a.comment,
        )
        for a, _review, evalue, cible_etab, cible_poste in db.exec(requete).all()
    ]


@router.get("/aspirations", response_model=list[schemas.AspirationOut],
            summary="Les souhaits d'évolution exprimés en entretien", tags=["Évaluation"])
def lister_aspirations(
    db: Db,
    salarie_id: int | None = None,
    etablissement_id: int | None = None,
    type_aspiration: Annotated[enums.AspirationType | None, Query()] = None,
) -> list[schemas.AspirationOut]:
    return _aspirations(
        db,
        salarie_id=salarie_id,
        etablissement_id=etablissement_id,
        type_aspiration=type_aspiration.value if type_aspiration else None,
    )
