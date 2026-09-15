"""
Les formes de réponse de l'API.

Le modèle relationnel est normalisé ; ces classes l'aplatissent. Une ligne de
salarié porte déjà le nom de son hôtel, l'intitulé de son poste et le nom de
son manager : aucun écran n'a besoin de recoller deux appels.

Chaque code d'énumération est doublé de son libellé français, suffixé
`_label`. Un écran affiche le libellé et filtre sur le code.
"""

from datetime import date

from pydantic import BaseModel

from .enums import (
    AspirationType, CampaignStatus, ContractStatus, ContractType, EmployeeStatus,
    NeedPriority, NeedStatus, NeedType, ReviewStatus, SkillCategory,
)


# =============================================================================
# Core HR
# =============================================================================


class EtablissementOut(BaseModel):
    id: int
    code: str
    name: str
    city: str
    postal_code: str
    address: str
    category: int
    opened_on: date
    is_head_office: bool
    headcount: int


class DepartementOut(BaseModel):
    id: int
    code: str
    label: str
    establishment_id: int
    establishment_name: str
    establishment_city: str
    headcount: int


class CompetenceOut(BaseModel):
    id: int
    code: str
    label: str
    category: SkillCategory
    category_label: str


class CompetenceAttendueOut(BaseModel):
    skill_id: int
    skill_code: str
    skill_label: str
    category: SkillCategory
    category_label: str
    required_level: int


class PosteOut(BaseModel):
    id: int
    code: str
    title: str
    job_family: str
    hierarchy_level: int
    target_headcount: int
    current_headcount: int
    vacancies: int
    department_id: int
    department_label: str
    establishment_id: int
    establishment_name: str
    establishment_city: str


class PosteDetailOut(PosteOut):
    required_skills: list[CompetenceAttendueOut]


class ContratOut(BaseModel):
    id: int
    employee_id: int
    employee_name: str
    matricule: str
    contract_type: ContractType
    contract_type_label: str
    start_date: date
    end_date: date | None
    work_time_ratio: float
    status: ContractStatus
    status_label: str
    days_to_end: int | None
    position_id: int
    position_title: str
    department_id: int
    department_label: str
    establishment_id: int
    establishment_name: str


class SalarieOut(BaseModel):
    id: int
    matricule: str
    civility: str
    first_name: str
    last_name: str
    full_name: str
    email_pro: str
    joined_on: date
    left_on: date | None
    seniority_months: int
    status: EmployeeStatus
    status_label: str
    manager_id: int | None
    manager_name: str | None

    # Le contrat en cours, aplati. Tout est NULL pour un salarié sorti.
    contract_id: int | None
    contract_type: ContractType | None
    contract_type_label: str | None
    contract_start_date: date | None
    contract_end_date: date | None
    work_time_ratio: float | None
    position_id: int | None
    position_title: str | None
    job_family: str | None
    hierarchy_level: int | None
    department_id: int | None
    department_label: str | None
    establishment_id: int | None
    establishment_name: str | None
    establishment_city: str | None


class SalarieDetailOut(SalarieOut):
    direct_reports_count: int
    contracts: list[ContratOut]


# =============================================================================
# Évaluation
# =============================================================================


class CampagneOut(BaseModel):
    id: int
    label: str
    year: int
    opens_on: date
    closes_on: date
    status: CampaignStatus
    status_label: str
    reviews_count: int


class ObjectifOut(BaseModel):
    id: int
    review_id: int
    label: str
    achievement_rate: int
    comment: str | None


class EvaluationCompetenceOut(BaseModel):
    id: int
    review_id: int
    skill_id: int
    skill_code: str
    skill_label: str
    category: SkillCategory
    assessed_level: int
    required_level: int | None
    gap: int | None
    comment: str | None


class AspirationOut(BaseModel):
    id: int
    review_id: int
    employee_id: int
    employee_name: str
    aspiration_type: AspirationType
    aspiration_type_label: str
    target_establishment_id: int | None
    target_establishment_name: str | None
    target_position_id: int | None
    target_position_title: str | None
    comment: str | None


class EntretienOut(BaseModel):
    id: int
    campaign_id: int
    campaign_label: str
    employee_id: int
    employee_name: str
    matricule: str
    position_title: str | None
    establishment_id: int | None
    establishment_name: str | None
    reviewer_id: int
    reviewer_name: str
    review_date: date
    status: ReviewStatus
    status_label: str
    summary: str | None
    goals_count: int
    average_achievement_rate: int | None
    skill_gaps_count: int
    aspirations_count: int


class EntretienDetailOut(EntretienOut):
    goals: list[ObjectifOut]
    skill_assessments: list[EvaluationCompetenceOut]
    aspirations: list[AspirationOut]


# =============================================================================
# Besoins identifiés
# =============================================================================


class BesoinOut(BaseModel):
    id: int
    need_type: NeedType
    need_type_label: str
    priority: NeedPriority
    priority_label: str
    status: NeedStatus
    status_label: str
    origin: str
    detected_on: date

    employee_id: int | None
    employee_name: str | None
    matricule: str | None

    position_id: int
    position_title: str
    job_family: str
    hierarchy_level: int
    department_id: int
    department_label: str
    establishment_id: int
    establishment_name: str
    establishment_city: str

    skill_id: int | None
    skill_code: str | None
    skill_label: str | None

    review_id: int | None
    handled_by_module: str | None
    handled_on: date | None
    comment: str | None


class BesoinPatch(BaseModel):
    """
    La seule écriture autorisée aux groupes sur le socle.

    Le module qui prend le besoin en charge n'est pas à renseigner : il est
    déduit du jeton, pour qu'un groupe ne puisse pas écrire au nom d'un autre.
    """

    status: NeedStatus
    comment: str | None = None


# =============================================================================
# Référentiels et SQL
# =============================================================================


class ValeurReferentiel(BaseModel):
    code: str
    label: str


class RequeteSql(BaseModel):
    query: str
    params: dict = {}


class ReponseSql(BaseModel):
    columns: list[str]
    rows: list[dict]
    row_count: int
    truncated: bool


class ScriptSql(BaseModel):
    script: str


class ReponseScriptSql(BaseModel):
    statements: int
    message: str
