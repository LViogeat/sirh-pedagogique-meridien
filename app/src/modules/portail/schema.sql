-- Module Portail RH & Self-Service — tables du groupe (schéma « portail »).
-- Rejouable : « create table if not exists » partout.

-- Story #41 — Demande d'absence (collaborateur)
-- Le collaborateur choisit un type d'absence et l'envoie à son manager.
create table if not exists demandes_absence (
  id            serial primary key,
  salarie_id    integer     not null,          -- référence LOGIQUE à public.employees
  manager_id    integer,                       -- le manager destinataire (copié au moment de l'envoi)
  type_absence  text        not null
                check (type_absence in ('conges_annuels', 'rtt', 'evenement_familial',
                                        'conge_sans_solde', 'absence_remuneree',
                                        'absence_non_remuneree')),
  date_debut    date        not null,
  date_fin      date        not null,
  commentaire   text,
  statut        text        not null default 'envoyee'
                check (statut in ('envoyee', 'validee', 'refusee')),
  envoyee_le    timestamptz not null default now(),
  check (date_fin >= date_debut)
);

-- Story #68 — Planning : absences, présences, télétravail
-- Les jours de télétravail demandés par le collaborateur, un jour par ligne.
create table if not exists demandes_teletravail (
  id          serial primary key,
  salarie_id  integer     not null,            -- référence LOGIQUE à public.employees
  manager_id  integer,
  jour        date        not null,
  statut      text        not null default 'envoyee'
              check (statut in ('envoyee', 'validee', 'refusee')),
  envoyee_le  timestamptz not null default now(),
  unique (salarie_id, jour)
);

-- Les heures réellement travaillées, saisies par le collaborateur.
-- Un jour sans saisie compte pour ses heures prévues : il ne change pas le solde.
create table if not exists heures_realisees (
  id          serial primary key,
  salarie_id  integer      not null,
  jour        date         not null,
  heures      numeric(4,2) not null check (heures >= 0 and heures <= 24),
  unique (salarie_id, jour)
);
