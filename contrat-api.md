# Contrat d'API — Socle SIRH — Sorbonne-Hôtel

Version compacte, faite pour être collée dans un chat IA. La spécification complète est dans `openapi.json`.

Toutes les requêtes portent l'en-tête `Authorization: Bearer <le jeton de votre groupe>`.

Toutes les listes renvoient l'intégralité des lignes : pas de pagination. Tous les filtres sont facultatifs et se combinent.

## Endpoints

### Référentiels

**GET /referentiels** — Toutes les énumérations du socle, avec leur libellé français

- réponse : `object`

**GET /date-reference** — La date sur laquelle tout le socle est calé

- réponse : `object`

**GET /** — Vérifier que l'API répond

- réponse : `object`

### Core HR

**GET /etablissements** — Les cinq hôtels de la chaîne

- réponse : `[EtablissementOut]`

**GET /departements** — Les départements, filtrables par établissement

- filtres : `etablissement_id` : integer?
- réponse : `[DepartementOut]`

**GET /postes** — Les postes, avec effectif cible et effectif réel

- filtres : `etablissement_id` : integer? · `departement_id` : integer? · `famille` : string? · `vacants` : boolean?
- réponse : `[PosteOut]`

**GET /postes/{poste_id}** — Un poste et les compétences qu'il requiert

- réponse : `PosteDetailOut`

**GET /competences** — Le référentiel de compétences

- filtres : `categorie` : SkillCategory?
- réponse : `[CompetenceOut]`

**GET /salaries** — Les salariés, avec leur contrat en cours

- filtres : `etablissement_id` : integer? · `departement_id` : integer? · `poste_id` : integer? · `manager_id` : integer? · `statut` : EmployeeStatus? · `type_contrat` : ContractType? · `q` : string?
- réponse : `[SalarieOut]`

**GET /salaries/{salarie_id}** — Un salarié et son parcours contractuel

- réponse : `SalarieDetailOut`

**GET /contrats** — Les contrats, filtrables par échéance

- filtres : `etablissement_id` : integer? · `poste_id` : integer? · `salarie_id` : integer? · `type_contrat` : ContractType? · `statut` : ContractStatus? · `fin_avant` : date?
- réponse : `[ContratOut]`

### Évaluation

**GET /campagnes** — Les campagnes d'entretiens annuels

- réponse : `[CampagneOut]`

**GET /entretiens** — Les entretiens annuels

- filtres : `campagne_id` : integer? · `salarie_id` : integer? · `evaluateur_id` : integer? · `etablissement_id` : integer? · `statut` : ReviewStatus?
- réponse : `[EntretienOut]`

**GET /entretiens/{entretien_id}** — Un entretien, avec ses objectifs, ses évaluations et ses aspirations

- réponse : `EntretienDetailOut`

**GET /aspirations** — Les souhaits d'évolution exprimés en entretien

- filtres : `salarie_id` : integer? · `etablissement_id` : integer? · `type_aspiration` : AspirationType?
- réponse : `[AspirationOut]`

### Besoins identifiés

**GET /besoins** — Les besoins identifiés, filtrables par type et par statut

- filtres : `type_besoin` : NeedType? · `statut` : NeedStatus? · `priorite` : NeedPriority? · `etablissement_id` : integer? · `departement_id` : integer? · `poste_id` : integer? · `salarie_id` : integer? · `competence_id` : integer? · `module` : string?
- réponse : `[BesoinOut]`

**GET /besoins/{besoin_id}** — Un besoin identifié

- réponse : `BesoinOut`

**PATCH /besoins/{besoin_id}** — Faire évoluer le statut d'un besoin — la seule écriture autorisée sur le socle

- corps : `BesoinPatch`
- réponse : `BesoinOut`

### SQL des modules

**POST /sql** — Exécuter une requête sur le schéma de votre module

- corps : `RequeteSql`
- réponse : `ReponseSql`

**POST /sql/script** — Exécuter plusieurs instructions — pour appliquer votre schema.sql

- corps : `ScriptSql`
- réponse : `ReponseScriptSql`

### Administration

**POST /admin/reset** — Remettre les données du socle à zéro

- réponse : `object`

**POST /admin/besoins/generer** — Rejouer les trois règles de génération des besoins

- réponse : `object`

**POST /admin/modules/{code}/reset** — Vider et recréer le schéma d'un groupe

- réponse : `object`

**GET /admin/etat** — Compter les lignes de chaque table du socle

- réponse : `object`

## Objets

**ValeurReferentiel**

```
code: string
label: string
```

**EtablissementOut**

```
id: integer
code: string
name: string
city: string
postal_code: string
address: string
category: integer
opened_on: date
is_head_office: boolean
headcount: integer
```

**DepartementOut**

```
id: integer
code: string
label: string
establishment_id: integer
establishment_name: string
establishment_city: string
headcount: integer
```

**PosteOut**

```
id: integer
code: string
title: string
job_family: string
hierarchy_level: integer
target_headcount: integer
current_headcount: integer
vacancies: integer
department_id: integer
department_label: string
establishment_id: integer
establishment_name: string
establishment_city: string
```

**PosteDetailOut**

```
id: integer
code: string
title: string
job_family: string
hierarchy_level: integer
target_headcount: integer
current_headcount: integer
vacancies: integer
department_id: integer
department_label: string
establishment_id: integer
establishment_name: string
establishment_city: string
required_skills: [CompetenceAttendueOut]
```

**CompetenceAttendueOut**

```
skill_id: integer
skill_code: string
skill_label: string
category: SkillCategory
category_label: string
required_level: integer
```

**CompetenceOut**

```
id: integer
code: string
label: string
category: SkillCategory
category_label: string
```

**SalarieOut**

```
id: integer
matricule: string
civility: string
first_name: string
last_name: string
full_name: string
email_pro: string
joined_on: date
left_on: date?
seniority_months: integer
status: EmployeeStatus
status_label: string
manager_id: integer?
manager_name: string?
contract_id: integer?
contract_type: ContractType?
contract_type_label: string?
contract_start_date: date?
contract_end_date: date?
work_time_ratio: number?
position_id: integer?
position_title: string?
job_family: string?
hierarchy_level: integer?
department_id: integer?
department_label: string?
establishment_id: integer?
establishment_name: string?
establishment_city: string?
```

**SalarieDetailOut**

```
id: integer
matricule: string
civility: string
first_name: string
last_name: string
full_name: string
email_pro: string
joined_on: date
left_on: date?
seniority_months: integer
status: EmployeeStatus
status_label: string
manager_id: integer?
manager_name: string?
contract_id: integer?
contract_type: ContractType?
contract_type_label: string?
contract_start_date: date?
contract_end_date: date?
work_time_ratio: number?
position_id: integer?
position_title: string?
job_family: string?
hierarchy_level: integer?
department_id: integer?
department_label: string?
establishment_id: integer?
establishment_name: string?
establishment_city: string?
direct_reports_count: integer
contracts: [ContratOut]
```

**ContratOut**

```
id: integer
employee_id: integer
employee_name: string
matricule: string
contract_type: ContractType
contract_type_label: string
start_date: date
end_date: date?
work_time_ratio: number
status: ContractStatus
status_label: string
days_to_end: integer?
position_id: integer
position_title: string
department_id: integer
department_label: string
establishment_id: integer
establishment_name: string
```

**CampagneOut**

```
id: integer
label: string
year: integer
opens_on: date
closes_on: date
status: CampaignStatus
status_label: string
reviews_count: integer
```

**EntretienOut**

```
id: integer
campaign_id: integer
campaign_label: string
employee_id: integer
employee_name: string
matricule: string
position_title: string?
establishment_id: integer?
establishment_name: string?
reviewer_id: integer
reviewer_name: string
review_date: date
status: ReviewStatus
status_label: string
summary: string?
goals_count: integer
average_achievement_rate: integer?
skill_gaps_count: integer
aspirations_count: integer
```

**EntretienDetailOut**

```
id: integer
campaign_id: integer
campaign_label: string
employee_id: integer
employee_name: string
matricule: string
position_title: string?
establishment_id: integer?
establishment_name: string?
reviewer_id: integer
reviewer_name: string
review_date: date
status: ReviewStatus
status_label: string
summary: string?
goals_count: integer
average_achievement_rate: integer?
skill_gaps_count: integer
aspirations_count: integer
goals: [ObjectifOut]
skill_assessments: [EvaluationCompetenceOut]
aspirations: [AspirationOut]
```

**ObjectifOut**

```
id: integer
review_id: integer
label: string
achievement_rate: integer
comment: string?
```

**EvaluationCompetenceOut**

```
id: integer
review_id: integer
skill_id: integer
skill_code: string
skill_label: string
category: SkillCategory
assessed_level: integer
required_level: integer?
gap: integer?
comment: string?
```

**AspirationOut**

```
id: integer
review_id: integer
employee_id: integer
employee_name: string
aspiration_type: AspirationType
aspiration_type_label: string
target_establishment_id: integer?
target_establishment_name: string?
target_position_id: integer?
target_position_title: string?
comment: string?
```

**BesoinOut**

```
id: integer
need_type: NeedType
need_type_label: string
priority: NeedPriority
priority_label: string
status: NeedStatus
status_label: string
origin: string
detected_on: date
employee_id: integer?
employee_name: string?
matricule: string?
position_id: integer
position_title: string
job_family: string
hierarchy_level: integer
department_id: integer
department_label: string
establishment_id: integer
establishment_name: string
establishment_city: string
skill_id: integer?
skill_code: string?
skill_label: string?
review_id: integer?
handled_by_module: string?
handled_on: date?
comment: string?
```

**BesoinPatch**

```
status: NeedStatus
comment: string?
```

**ReponseSql**

```
columns: [string]
rows: [object]
row_count: integer
truncated: boolean
```

**RequeteSql**

```
query: string
params: object
```

**ReponseScriptSql**

```
statements: integer
message: string
```

**ScriptSql**

```
script: string
```

