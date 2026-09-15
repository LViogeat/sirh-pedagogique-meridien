"""
Le modèle de données du socle : Core HR et Évaluation.

Ces treize classes sont la seule source de vérité du schéma. Les tables sont
créées à partir d'elles, la spécification OpenAPI en découle, et c'est ce que
les étudiants voient quand ils interrogent la base en SQL.

Deux partis pris qui expliquent la forme du modèle :

1. Les énumérations sont stockées en `text` avec une contrainte CHECK, pas en
   type PostgreSQL dédié. Un étudiant écrit `where contract_type = 'CDI'` et
   ça marche, sans conversion de type ni message d'erreur obscur.

2. Le modèle n'est pas historisé. Un SIRH de production daterait les
   affectations et les avenants ; ici, l'historique d'un salarié tient dans la
   suite de ses contrats, et c'est suffisant. Chaque jointure épargnée est une
   requête juste de plus.
"""

from datetime import date

from sqlalchemy import CheckConstraint, UniqueConstraint
from sqlmodel import Field, SQLModel

from . import enums


def _check(colonne: str, enumeration) -> CheckConstraint:
    """Contrainte CHECK reprenant les valeurs d'une énumération."""
    liste = ", ".join(f"'{v}'" for v in enums.valeurs(enumeration))
    return CheckConstraint(f"{colonne} in ({liste})", name=f"ck_{colonne}")


# =============================================================================
# CORE HR
# =============================================================================


class Establishment(SQLModel, table=True):
    __tablename__ = "establishments"
    __table_args__ = {"comment": "Les hôtels de la chaîne Sorbonne-Hôtel."}

    id: int | None = Field(default=None, primary_key=True)
    code: str = Field(unique=True, index=True)
    name: str
    city: str
    address: str
    postal_code: str
    category: int = Field(description="Nombre d'étoiles : 4 ou 5")
    opened_on: date
    is_head_office: bool = Field(default=False)


class Department(SQLModel, table=True):
    __tablename__ = "departments"
    __table_args__ = (
        UniqueConstraint("establishment_id", "code", name="uq_department_code"),
        {"comment": "Un département existe dans un établissement donné."},
    )

    id: int | None = Field(default=None, primary_key=True)
    establishment_id: int = Field(foreign_key="establishments.id", index=True)
    code: str
    label: str


class Position(SQLModel, table=True):
    __tablename__ = "positions"
    __table_args__ = (
        UniqueConstraint("department_id", "code", name="uq_position_code"),
        {
            "comment": "Un poste dans un département, avec son effectif cible. "
            "L'écart entre effectif cible et effectif réel est ce qui "
            "déclenche un besoin de recrutement."
        },
    )

    id: int | None = Field(default=None, primary_key=True)
    department_id: int = Field(foreign_key="departments.id", index=True)
    code: str
    title: str
    job_family: str
    hierarchy_level: int = Field(
        description="1 exécution · 2 qualifié · 3 encadrement · 4 direction"
    )
    target_headcount: int


class Skill(SQLModel, table=True):
    __tablename__ = "skills"
    __table_args__ = (
        _check("category", enums.SkillCategory),
        {"comment": "Le référentiel de compétences, commun à tous les établissements."},
    )

    id: int | None = Field(default=None, primary_key=True)
    code: str = Field(unique=True, index=True)
    label: str
    category: str


class PositionSkill(SQLModel, table=True):
    __tablename__ = "position_skills"
    __table_args__ = (
        UniqueConstraint("position_id", "skill_id", name="uq_position_skill"),
        CheckConstraint("required_level between 1 and 4", name="ck_required_level"),
        {"comment": "Le niveau attendu sur une compétence pour tenir un poste."},
    )

    id: int | None = Field(default=None, primary_key=True)
    position_id: int = Field(foreign_key="positions.id", index=True)
    skill_id: int = Field(foreign_key="skills.id", index=True)
    required_level: int


class Employee(SQLModel, table=True):
    __tablename__ = "employees"
    __table_args__ = (
        _check("status", enums.EmployeeStatus),
        {"comment": "L'identité et le rattachement hiérarchique d'un salarié."},
    )

    id: int | None = Field(default=None, primary_key=True)
    matricule: str = Field(unique=True, index=True)
    civility: str
    first_name: str
    last_name: str
    email_pro: str = Field(unique=True)
    joined_on: date = Field(description="Date d'entrée dans le groupe")
    left_on: date | None = Field(
        default=None, description="Date de sortie ; NULL tant que le salarié est présent"
    )
    manager_id: int | None = Field(
        default=None,
        foreign_key="employees.id",
        index=True,
        description="NULL pour le directeur général uniquement",
    )
    status: str = Field(index=True)


class Contract(SQLModel, table=True):
    __tablename__ = "contracts"
    __table_args__ = (
        _check("contract_type", enums.ContractType),
        _check("status", enums.ContractStatus),
        CheckConstraint("end_date is null or end_date >= start_date", name="ck_contract_dates"),
        CheckConstraint(
            "work_time_ratio > 0 and work_time_ratio <= 1", name="ck_work_time_ratio"
        ),
        {
            "comment": "La relation de travail. La suite des contrats d'un salarié "
            "constitue son parcours dans le groupe."
        },
    )

    id: int | None = Field(default=None, primary_key=True)
    employee_id: int = Field(foreign_key="employees.id", index=True)
    position_id: int = Field(foreign_key="positions.id", index=True)
    establishment_id: int = Field(
        foreign_key="establishments.id",
        index=True,
        description="Redondant avec le poste, et volontairement : un extra ou un "
        "saisonnier peut être employé par un hôtel différent de celui du poste, "
        "et cela évite une double jointure à tous les modules.",
    )
    contract_type: str = Field(index=True)
    start_date: date
    end_date: date | None = Field(default=None, description="NULL pour un CDI")
    work_time_ratio: float = Field(description="1.00 = temps plein")
    status: str = Field(index=True)


# =============================================================================
# ÉVALUATION / GESTION DES TALENTS
# =============================================================================


class Campaign(SQLModel, table=True):
    __tablename__ = "campaigns"
    __table_args__ = (
        _check("status", enums.CampaignStatus),
        {"comment": "Une campagne d'entretiens annuels."},
    )

    id: int | None = Field(default=None, primary_key=True)
    label: str
    year: int
    opens_on: date
    closes_on: date
    status: str


class Review(SQLModel, table=True):
    __tablename__ = "reviews"
    __table_args__ = (
        UniqueConstraint("campaign_id", "employee_id", name="uq_review_campaign_employee"),
        _check("status", enums.ReviewStatus),
        {"comment": "L'entretien annuel d'un salarié, mené par son manager."},
    )

    id: int | None = Field(default=None, primary_key=True)
    campaign_id: int = Field(foreign_key="campaigns.id", index=True)
    employee_id: int = Field(foreign_key="employees.id", index=True)
    reviewer_id: int = Field(foreign_key="employees.id", index=True)
    review_date: date
    status: str = Field(index=True)
    summary: str | None = Field(default=None)


class Goal(SQLModel, table=True):
    __tablename__ = "goals"
    __table_args__ = (
        CheckConstraint("achievement_rate between 0 and 150", name="ck_achievement_rate"),
        {"comment": "Un objectif fixé lors d'un entretien, et son taux d'atteinte."},
    )

    id: int | None = Field(default=None, primary_key=True)
    review_id: int = Field(foreign_key="reviews.id", index=True)
    label: str
    achievement_rate: int = Field(description="En pourcentage ; peut dépasser 100")
    comment: str | None = Field(default=None)


class SkillAssessment(SQLModel, table=True):
    __tablename__ = "skill_assessments"
    __table_args__ = (
        UniqueConstraint("review_id", "skill_id", name="uq_assessment_review_skill"),
        CheckConstraint("assessed_level between 1 and 4", name="ck_assessed_level"),
        {
            "comment": "Le niveau constaté sur une compétence lors d'un entretien. "
            "Comparé au niveau attendu du poste, l'écart révèle un besoin "
            "de formation."
        },
    )

    id: int | None = Field(default=None, primary_key=True)
    review_id: int = Field(foreign_key="reviews.id", index=True)
    skill_id: int = Field(foreign_key="skills.id", index=True)
    assessed_level: int
    comment: str | None = Field(default=None)


class Aspiration(SQLModel, table=True):
    __tablename__ = "aspirations"
    __table_args__ = (
        _check("aspiration_type", enums.AspirationType),
        {"comment": "Ce que le salarié exprime en entretien sur la suite de son parcours."},
    )

    id: int | None = Field(default=None, primary_key=True)
    review_id: int = Field(foreign_key="reviews.id", index=True)
    aspiration_type: str = Field(index=True)
    target_establishment_id: int | None = Field(
        default=None, foreign_key="establishments.id"
    )
    target_position_id: int | None = Field(default=None, foreign_key="positions.id")
    comment: str | None = Field(default=None)


class IdentifiedNeed(SQLModel, table=True):
    """
    Le pivot de tout le système.

    Trois des six modules étudiants consomment cette table : Recrutement lit les
    besoins de type `recrutement`, Formation ceux de type `formation`, Mobilité
    ceux de type `mobilite`. C'est la seule table du socle sur laquelle ils ont
    le droit d'écrire, et uniquement pour en faire évoluer le statut.

    La clé naturelle (need_type, employee_id, position_id, skill_id) rend la
    commande de génération rejouable : relancée, elle ne crée pas de doublon et
    ne rouvre jamais un besoin qu'un groupe a déjà pris en charge.
    """

    __tablename__ = "identified_needs"
    __table_args__ = (
        UniqueConstraint(
            "need_type", "employee_id", "position_id", "skill_id", name="uq_need_naturelle"
        ),
        _check("need_type", enums.NeedType),
        _check("priority", enums.NeedPriority),
        _check("status", enums.NeedStatus),
        {"comment": "Les besoins RH identifiés — le pivot entre l'évaluation et l'action."},
    )

    id: int | None = Field(default=None, primary_key=True)
    need_type: str = Field(index=True)
    employee_id: int | None = Field(
        default=None,
        foreign_key="employees.id",
        index=True,
        description="NULL pour un besoin de recrutement, qui ne concerne personne",
    )
    position_id: int = Field(foreign_key="positions.id", index=True)
    establishment_id: int = Field(foreign_key="establishments.id", index=True)
    skill_id: int | None = Field(default=None, foreign_key="skills.id", index=True)
    review_id: int | None = Field(
        default=None,
        foreign_key="reviews.id",
        description="L'entretien dont découle le besoin, s'il y en a un",
    )
    origin: str = Field(description="La règle qui a produit ce besoin, en clair")
    priority: str = Field(index=True)
    status: str = Field(index=True)
    detected_on: date
    handled_by_module: str | None = Field(
        default=None, description="Le code du groupe qui a pris le besoin en charge"
    )
    handled_on: date | None = Field(default=None)
    comment: str | None = Field(default=None)


# L'ordre de suppression : les tables qui référencent les autres d'abord.
TABLES_DANS_L_ORDRE = [
    IdentifiedNeed,
    Aspiration,
    SkillAssessment,
    Goal,
    Review,
    Campaign,
    Contract,
    Employee,
    PositionSkill,
    Skill,
    Position,
    Department,
    Establishment,
]
