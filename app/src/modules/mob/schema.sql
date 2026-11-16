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
