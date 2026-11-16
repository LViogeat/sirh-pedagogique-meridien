-- Tables du module Mobilité & carrière (schéma « mob »).
-- Rejouable : à coller dans la Console SQL, ou à passer à sqlScript().
-- Les références au socle sont de simples entiers, sans clé étrangère.
-- Les dates sont toujours fournies par l'écran avec getDateReference().

create table if not exists dossiers (
  id           serial  primary key,
  besoin_id    integer not null,          -- référence logique au socle
  employee_id  integer not null,          -- référence logique au socle
  conseiller   text    not null,
  etape        text    not null default 'analyse',  -- analyse | propositions | entretien | decision | termine
  issue        text,                      -- realisee | refusee | reportee | abandonnee
  ouvert_le    date    not null default current_date,
  clos_le      date
);

create table if not exists propositions (
  id               serial  primary key,
  dossier_id       integer not null references dossiers(id) on delete cascade,
  position_id      integer not null,      -- poste proposé (socle)
  establishment_id integer,
  statut           text    not null default 'proposee',  -- proposee | acceptee | refusee
  commentaire      text,
  proposee_le      date    not null default current_date
);

create table if not exists echanges (
  id            serial  primary key,
  dossier_id    integer not null references dossiers(id) on delete cascade,
  date_echange  date    not null default current_date,
  type_echange  text    not null,         -- entretien_carriere | appel | mail
  compte_rendu  text
);

create table if not exists mobilites (
  id                       serial  primary key,
  dossier_id               integer not null references dossiers(id),
  position_depart_id       integer,
  position_arrivee_id      integer not null,
  establishment_arrivee_id integer,
  date_effet               date    not null
);

-- ---------------------------------------------------------------------------
-- Compléments pour les sprints 2 et 3 (déjà appliqués au socle, rejouables)
-- ---------------------------------------------------------------------------

-- Commentaire de clôture du dossier
alter table dossiers add column if not exists commentaire text;

-- Hôtel de départ de la mobilité
alter table mobilites add column if not exists establishment_depart_id integer;

-- Date d'acceptation ou de refus d'une proposition
alter table propositions add column if not exists decidee_le date;

-- Plus de date de l'horloge : l'écran donne toujours getDateReference()
alter table dossiers     alter column ouvert_le    drop default;
alter table propositions alter column proposee_le  drop default;
alter table echanges     alter column date_echange drop default;

-- Un seul dossier par besoin
create unique index if not exists dossiers_un_par_besoin
  on dossiers (besoin_id);

-- Un même poste ne peut pas être proposé deux fois au même dossier
create unique index if not exists propositions_poste_unique
  on propositions (dossier_id, position_id);

-- Une seule proposition acceptée par dossier
create unique index if not exists propositions_une_acceptee
  on propositions (dossier_id) where statut = 'acceptee';

-- Une seule mobilité par dossier
create unique index if not exists mobilites_une_par_dossier
  on mobilites (dossier_id);
