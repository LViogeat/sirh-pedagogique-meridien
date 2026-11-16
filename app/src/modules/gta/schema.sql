-- =============================================================================
-- Schéma du module Gestion des temps et activités (gta) — sprint 1
--
-- Rejouable à volonté : « create table if not exists » partout, et les données
-- de départ ne sont insérées que si la table est encore vide.
-- Les écrans du module l'appliquent d'eux-mêmes à l'ouverture (voir _gta.js) ;
-- on peut aussi le coller tel quel dans la Console SQL.
--
-- Références au socle (employee_id) : simple integer, jamais de clé étrangère.
-- =============================================================================

-- ── Absences (#128, #129) ────────────────────────────────────────────────────

create table if not exists familles_absence (
  id      serial  primary key,
  code    text    not null unique,
  libelle text    not null,
  ordre   integer not null default 0
);

create table if not exists motifs_absence (
  id         serial  primary key,
  code       text    not null unique,
  libelle    text    not null,
  famille_id integer not null references familles_absence(id),
  actif      boolean not null default true
);

-- Les 5 familles de départ.
insert into familles_absence (code, libelle, ordre)
select v.code, v.libelle, v.ordre
from (values
  ('CONGES',    'Congés',                 1),
  ('MALADIE',   'Maladie et accidents',   2),
  ('FAMILLE',   'Événements familiaux',   3),
  ('FORMATION', 'Formation',              4),
  ('AUTRES',    'Autres absences',        5)
) as v(code, libelle, ordre)
where not exists (select 1 from familles_absence);

-- Les 17 motifs de départ, rattachés à leur famille par son code.
insert into motifs_absence (code, libelle, famille_id)
select v.code, v.libelle, f.id
from (values
  ('CP',  'Congés payés',                    'CONGES'),
  ('RTT', 'Réduction du temps de travail',   'CONGES'),
  ('CSS', 'Congé sans solde',                'CONGES'),
  ('CET', 'Compte épargne-temps',            'CONGES'),
  ('MAL', 'Maladie',                         'MALADIE'),
  ('AT',  'Accident du travail',             'MALADIE'),
  ('ATJ', 'Accident de trajet',              'MALADIE'),
  ('MP',  'Maladie professionnelle',         'MALADIE'),
  ('MAR', 'Mariage ou PACS',                 'FAMILLE'),
  ('NAI', 'Naissance ou adoption',           'FAMILLE'),
  ('PAT', 'Congé de paternité',              'FAMILLE'),
  ('MAT', 'Congé de maternité',              'FAMILLE'),
  ('DEC', 'Décès d''un proche',              'FAMILLE'),
  ('FOR', 'Formation professionnelle',       'FORMATION'),
  ('EXA', 'Examen',                          'FORMATION'),
  ('ABA', 'Absence autorisée',               'AUTRES'),
  ('ABI', 'Absence injustifiée',             'AUTRES')
) as v(code, libelle, famille)
join familles_absence f on f.code = v.famille
where not exists (select 1 from motifs_absence);

-- ── Horaires (#130, #131) ────────────────────────────────────────────────────

-- Un code horaire : une plage de travail sur une journée.
-- Si l'heure de fin est avant l'heure de début, la plage passe minuit (NUIT).
create table if not exists codes_horaires (
  id            serial  primary key,
  code          text    not null unique,
  libelle       text    not null,
  heure_debut   time    not null,
  heure_fin     time    not null,
  pause_minutes integer not null default 0 check (pause_minutes >= 0)
);

-- Un profil horaire : un code horaire par jour de la semaine.
-- Un jour sans code (null) est un jour de repos.
create table if not exists profils_horaires (
  id          serial  primary key,
  code        text    not null unique,
  libelle     text    not null,
  lundi_id    integer references codes_horaires(id),
  mardi_id    integer references codes_horaires(id),
  mercredi_id integer references codes_horaires(id),
  jeudi_id    integer references codes_horaires(id),
  vendredi_id integer references codes_horaires(id),
  samedi_id   integer references codes_horaires(id),
  dimanche_id integer references codes_horaires(id)
);

-- ── Affectations (#132) ──────────────────────────────────────────────────────

-- Le profil horaire d'un salarié à partir d'une date.
-- Le profil en vigueur est celui dont la date de début est la plus récente.
create table if not exists affectations_profil (
  id          serial  primary key,
  employee_id integer not null,                 -- référence LOGIQUE au socle
  profil_id   integer not null references profils_horaires(id),
  date_debut  date    not null,
  creee_le    date    not null default current_date
);

create index if not exists affectations_profil_salarie
  on affectations_profil (employee_id, date_debut desc);

-- ── Pointages (#133, #134, #135) ─────────────────────────────────────────────

-- Un pointage : un passage à la pointeuse, horodaté par le poste du salarié.
-- Le sens alterne : entrée, sortie, entrée, sortie… La première entrée du jour
-- est l'arrivée, la dernière sortie le départ, et ce qui est entre les deux
-- sont les pauses.
create table if not exists pointages (
  id          serial  primary key,
  employee_id integer not null,                 -- référence LOGIQUE au socle
  jour        date    not null,
  heure       time    not null,
  sens        text    not null check (sens in ('entree', 'sortie')),
  lieu        text    not null default 'site' check (lieu in ('site', 'teletravail')),
  cree_le     timestamptz not null default now()
);

create index if not exists pointages_salarie_jour on pointages (employee_id, jour, heure);
