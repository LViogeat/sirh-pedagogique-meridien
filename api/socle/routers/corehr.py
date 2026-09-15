"""
Les endpoints de lecture du Core HR.

Toutes les listes renvoient l'intégralité des lignes : la chaîne compte cinq
hôtels et cent quarante salariés, la pagination coûterait aux étudiants plus
qu'elle ne rapporte.

Tous les filtres sont facultatifs et se combinent librement.
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import aliased
from sqlmodel import Session, select

from .. import enums, models, schemas
from ..config import DATE_REFERENCE
from ..db import session_socle
from ..security import groupe_appelant

router = APIRouter(dependencies=[Depends(groupe_appelant)])

Db = Annotated[Session, Depends(session_socle)]

CONTRAT_ACTIF = models.Contract.status == enums.ContractStatus.ACTIF.value


def _anciennete_mois(entree, sortie=None) -> int:
    """Ancienneté en mois pleins, arrêtée à la date de sortie si elle existe."""
    fin = sortie or DATE_REFERENCE
    return max(0, (fin.year - entree.year) * 12 + (fin.month - entree.month)
               - (1 if fin.day < entree.day else 0))


def _jours_restants(fin) -> int | None:
    return None if fin is None else (fin - DATE_REFERENCE).days


def _effectifs_par(colonne, db: Session) -> dict[int, int]:
    """Effectif présent, regroupé par la colonne demandée."""
    requete = (
        select(colonne, func.count())
        .select_from(models.Contract)
        .join(models.Employee, models.Employee.id == models.Contract.employee_id)
        .join(models.Position, models.Position.id == models.Contract.position_id)
        .join(models.Department, models.Department.id == models.Position.department_id)
        .where(CONTRAT_ACTIF)
        .where(models.Employee.status == enums.EmployeeStatus.ACTIF.value)
        .group_by(colonne)
    )
    return {cle: nombre for cle, nombre in db.exec(requete).all()}


# =============================================================================
# Établissements et départements
# =============================================================================


@router.get("/etablissements", response_model=list[schemas.EtablissementOut],
            summary="Les cinq hôtels de la chaîne", tags=["Core HR"])
def lister_etablissements(db: Db) -> list[schemas.EtablissementOut]:
    effectifs = _effectifs_par(models.Contract.establishment_id, db)
    etablissements = db.exec(select(models.Establishment).order_by(models.Establishment.name)).all()
    return [
        schemas.EtablissementOut(
            **e.model_dump(), headcount=effectifs.get(e.id, 0)
        )
        for e in etablissements
    ]


@router.get("/departements", response_model=list[schemas.DepartementOut],
            summary="Les départements, filtrables par établissement", tags=["Core HR"])
def lister_departements(
    db: Db,
    etablissement_id: Annotated[int | None, Query(description="Filtre sur un hôtel")] = None,
) -> list[schemas.DepartementOut]:
    effectifs = _effectifs_par(models.Department.id, db)

    requete = (
        select(models.Department, models.Establishment)
        .join(models.Establishment, models.Establishment.id == models.Department.establishment_id)
        .order_by(models.Establishment.name, models.Department.label)
    )
    if etablissement_id is not None:
        requete = requete.where(models.Department.establishment_id == etablissement_id)

    return [
        schemas.DepartementOut(
            id=d.id, code=d.code, label=d.label,
            establishment_id=e.id, establishment_name=e.name, establishment_city=e.city,
            headcount=effectifs.get(d.id, 0),
        )
        for d, e in db.exec(requete).all()
    ]


# =============================================================================
# Postes et compétences
# =============================================================================


def _requete_postes():
    return (
        select(models.Position, models.Department, models.Establishment)
        .join(models.Department, models.Department.id == models.Position.department_id)
        .join(models.Establishment, models.Establishment.id == models.Department.establishment_id)
    )


def _ligne_poste(poste, departement, etablissement, effectif: int) -> dict:
    return dict(
        id=poste.id, code=poste.code, title=poste.title, job_family=poste.job_family,
        hierarchy_level=poste.hierarchy_level, target_headcount=poste.target_headcount,
        current_headcount=effectif,
        vacancies=max(0, poste.target_headcount - effectif),
        department_id=departement.id, department_label=departement.label,
        establishment_id=etablissement.id, establishment_name=etablissement.name,
        establishment_city=etablissement.city,
    )


@router.get("/postes", response_model=list[schemas.PosteOut],
            summary="Les postes, avec effectif cible et effectif réel", tags=["Core HR"])
def lister_postes(
    db: Db,
    etablissement_id: int | None = None,
    departement_id: int | None = None,
    famille: Annotated[str | None, Query(description="Famille de métier, ex. « Cuisine »")] = None,
    vacants: Annotated[bool | None, Query(
        description="À true, ne renvoie que les postes dont l'effectif réel est "
                    "inférieur à l'effectif cible")] = None,
) -> list[schemas.PosteOut]:
    effectifs = _effectifs_par(models.Position.id, db)

    requete = _requete_postes().order_by(
        models.Establishment.name, models.Department.label, models.Position.title
    )
    if etablissement_id is not None:
        requete = requete.where(models.Department.establishment_id == etablissement_id)
    if departement_id is not None:
        requete = requete.where(models.Position.department_id == departement_id)
    if famille is not None:
        requete = requete.where(models.Position.job_family == famille)

    lignes = [
        _ligne_poste(p, d, e, effectifs.get(p.id, 0))
        for p, d, e in db.exec(requete).all()
    ]
    if vacants:
        lignes = [l for l in lignes if l["vacancies"] > 0]
    return [schemas.PosteOut(**l) for l in lignes]


@router.get("/postes/{poste_id}", response_model=schemas.PosteDetailOut,
            summary="Un poste et les compétences qu'il requiert", tags=["Core HR"])
def lire_poste(poste_id: int, db: Db) -> schemas.PosteDetailOut:
    ligne = db.exec(_requete_postes().where(models.Position.id == poste_id)).first()
    if ligne is None:
        raise HTTPException(404, f"Aucun poste d'identifiant {poste_id}.")
    poste, departement, etablissement = ligne

    effectifs = _effectifs_par(models.Position.id, db)
    competences = db.exec(
        select(models.PositionSkill, models.Skill)
        .join(models.Skill, models.Skill.id == models.PositionSkill.skill_id)
        .where(models.PositionSkill.position_id == poste_id)
        .order_by(models.Skill.category, models.Skill.label)
    ).all()

    return schemas.PosteDetailOut(
        **_ligne_poste(poste, departement, etablissement, effectifs.get(poste_id, 0)),
        required_skills=[
            schemas.CompetenceAttendueOut(
                skill_id=s.id, skill_code=s.code, skill_label=s.label,
                category=s.category,
                category_label=enums.libelle(enums.SkillCategory, s.category),
                required_level=ps.required_level,
            )
            for ps, s in competences
        ],
    )


@router.get("/competences", response_model=list[schemas.CompetenceOut],
            summary="Le référentiel de compétences", tags=["Core HR"])
def lister_competences(
    db: Db,
    categorie: Annotated[enums.SkillCategory | None, Query()] = None,
) -> list[schemas.CompetenceOut]:
    requete = select(models.Skill).order_by(models.Skill.category, models.Skill.label)
    if categorie is not None:
        requete = requete.where(models.Skill.category == categorie.value)
    return [
        schemas.CompetenceOut(
            id=s.id, code=s.code, label=s.label, category=s.category,
            category_label=enums.libelle(enums.SkillCategory, s.category),
        )
        for s in db.exec(requete).all()
    ]


# =============================================================================
# Salariés
# =============================================================================

Manager = aliased(models.Employee, name="manager")


def _requete_salaries():
    """
    Un salarié, son contrat en cours et tout ce qui s'y rattache, sur une ligne.

    Les jointures sont externes à partir du contrat : un salarié sorti n'en a
    plus, et doit rester visible — c'est de lui que naissent les besoins de
    remplacement.
    """
    return (
        select(models.Employee, models.Contract, models.Position,
               models.Department, models.Establishment, Manager)
        .join(models.Contract,
              and_(models.Contract.employee_id == models.Employee.id, CONTRAT_ACTIF),
              isouter=True)
        .join(models.Position, models.Position.id == models.Contract.position_id, isouter=True)
        .join(models.Department, models.Department.id == models.Position.department_id,
              isouter=True)
        .join(models.Establishment,
              models.Establishment.id == models.Contract.establishment_id, isouter=True)
        .join(Manager, Manager.id == models.Employee.manager_id, isouter=True)
    )


def _ligne_salarie(salarie, contrat, poste, departement, etablissement, manager) -> dict:
    return dict(
        id=salarie.id, matricule=salarie.matricule, civility=salarie.civility,
        first_name=salarie.first_name, last_name=salarie.last_name,
        full_name=f"{salarie.first_name} {salarie.last_name}",
        email_pro=salarie.email_pro, joined_on=salarie.joined_on, left_on=salarie.left_on,
        seniority_months=_anciennete_mois(salarie.joined_on, salarie.left_on),
        status=salarie.status,
        status_label=enums.libelle(enums.EmployeeStatus, salarie.status),
        manager_id=salarie.manager_id,
        manager_name=f"{manager.first_name} {manager.last_name}" if manager else None,
        contract_id=contrat.id if contrat else None,
        contract_type=contrat.contract_type if contrat else None,
        contract_type_label=(enums.libelle(enums.ContractType, contrat.contract_type)
                             if contrat else None),
        contract_start_date=contrat.start_date if contrat else None,
        contract_end_date=contrat.end_date if contrat else None,
        work_time_ratio=contrat.work_time_ratio if contrat else None,
        position_id=poste.id if poste else None,
        position_title=poste.title if poste else None,
        job_family=poste.job_family if poste else None,
        hierarchy_level=poste.hierarchy_level if poste else None,
        department_id=departement.id if departement else None,
        department_label=departement.label if departement else None,
        establishment_id=etablissement.id if etablissement else None,
        establishment_name=etablissement.name if etablissement else None,
        establishment_city=etablissement.city if etablissement else None,
    )


@router.get("/salaries", response_model=list[schemas.SalarieOut],
            summary="Les salariés, avec leur contrat en cours", tags=["Core HR"])
def lister_salaries(
    db: Db,
    etablissement_id: int | None = None,
    departement_id: int | None = None,
    poste_id: int | None = None,
    manager_id: Annotated[int | None, Query(description="L'équipe directe d'un manager")] = None,
    statut: Annotated[enums.EmployeeStatus | None, Query()] = enums.EmployeeStatus.ACTIF,
    type_contrat: Annotated[enums.ContractType | None, Query()] = None,
    q: Annotated[str | None, Query(description="Recherche sur le nom, le matricule "
                                               "ou l'e-mail")] = None,
) -> list[schemas.SalarieOut]:
    requete = _requete_salaries().order_by(models.Employee.last_name, models.Employee.first_name)

    if statut is not None:
        requete = requete.where(models.Employee.status == statut.value)
    if etablissement_id is not None:
        requete = requete.where(models.Contract.establishment_id == etablissement_id)
    if departement_id is not None:
        requete = requete.where(models.Position.department_id == departement_id)
    if poste_id is not None:
        requete = requete.where(models.Contract.position_id == poste_id)
    if manager_id is not None:
        requete = requete.where(models.Employee.manager_id == manager_id)
    if type_contrat is not None:
        requete = requete.where(models.Contract.contract_type == type_contrat.value)
    if q:
        motif = f"%{q.strip()}%"
        requete = requete.where(or_(
            models.Employee.last_name.ilike(motif),
            models.Employee.first_name.ilike(motif),
            models.Employee.matricule.ilike(motif),
            models.Employee.email_pro.ilike(motif),
        ))

    return [schemas.SalarieOut(**_ligne_salarie(*ligne)) for ligne in db.exec(requete).all()]


@router.get("/salaries/{salarie_id}", response_model=schemas.SalarieDetailOut,
            summary="Un salarié et son parcours contractuel", tags=["Core HR"])
def lire_salarie(salarie_id: int, db: Db) -> schemas.SalarieDetailOut:
    ligne = db.exec(_requete_salaries().where(models.Employee.id == salarie_id)).first()
    if ligne is None:
        raise HTTPException(404, f"Aucun salarié d'identifiant {salarie_id}.")

    equipe = db.exec(
        select(func.count()).select_from(models.Employee)
        .where(models.Employee.manager_id == salarie_id)
        .where(models.Employee.status == enums.EmployeeStatus.ACTIF.value)
    ).one()

    return schemas.SalarieDetailOut(
        **_ligne_salarie(*ligne),
        direct_reports_count=equipe,
        contracts=_contrats(db, salarie_id=salarie_id),
    )


# =============================================================================
# Contrats
# =============================================================================


def _contrats(db: Session, **filtres) -> list[schemas.ContratOut]:
    requete = (
        select(models.Contract, models.Employee, models.Position,
               models.Department, models.Establishment)
        .join(models.Employee, models.Employee.id == models.Contract.employee_id)
        .join(models.Position, models.Position.id == models.Contract.position_id)
        .join(models.Department, models.Department.id == models.Position.department_id)
        .join(models.Establishment,
              models.Establishment.id == models.Contract.establishment_id)
        .order_by(models.Contract.start_date.desc())
    )

    if filtres.get("salarie_id") is not None:
        requete = requete.where(models.Contract.employee_id == filtres["salarie_id"])
    if filtres.get("etablissement_id") is not None:
        requete = requete.where(models.Contract.establishment_id == filtres["etablissement_id"])
    if filtres.get("poste_id") is not None:
        requete = requete.where(models.Contract.position_id == filtres["poste_id"])
    if filtres.get("type_contrat") is not None:
        requete = requete.where(models.Contract.contract_type == filtres["type_contrat"])
    if filtres.get("statut") is not None:
        requete = requete.where(models.Contract.status == filtres["statut"])
    if filtres.get("fin_avant") is not None:
        requete = requete.where(models.Contract.end_date.is_not(None))
        requete = requete.where(models.Contract.end_date <= filtres["fin_avant"])

    return [
        schemas.ContratOut(
            id=c.id, employee_id=s.id,
            employee_name=f"{s.first_name} {s.last_name}", matricule=s.matricule,
            contract_type=c.contract_type,
            contract_type_label=enums.libelle(enums.ContractType, c.contract_type),
            start_date=c.start_date, end_date=c.end_date,
            work_time_ratio=c.work_time_ratio, status=c.status,
            status_label=enums.libelle(enums.ContractStatus, c.status),
            days_to_end=_jours_restants(c.end_date),
            position_id=p.id, position_title=p.title,
            department_id=d.id, department_label=d.label,
            establishment_id=e.id, establishment_name=e.name,
        )
        for c, s, p, d, e in db.exec(requete).all()
    ]


@router.get("/contrats", response_model=list[schemas.ContratOut],
            summary="Les contrats, filtrables par échéance", tags=["Core HR"])
def lister_contrats(
    db: Db,
    etablissement_id: int | None = None,
    poste_id: int | None = None,
    salarie_id: int | None = None,
    type_contrat: Annotated[enums.ContractType | None, Query()] = None,
    statut: Annotated[enums.ContractStatus | None, Query()] = None,
    fin_avant: Annotated[date | None, Query(
        description="Ne renvoie que les contrats dont le terme est antérieur à "
                    "cette date. Sert à repérer les échéances proches.",
        examples=["2026-12-31"])] = None,
) -> list[schemas.ContratOut]:
    return _contrats(
        db,
        etablissement_id=etablissement_id, poste_id=poste_id, salarie_id=salarie_id,
        type_contrat=type_contrat.value if type_contrat else None,
        statut=statut.value if statut else None,
        fin_avant=fin_avant,
    )
