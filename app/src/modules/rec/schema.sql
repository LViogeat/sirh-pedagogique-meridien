-- =============================================================================
-- Module Recrutement — le modèle de données du schéma « rec »
--
-- À coller tel quel dans la Console SQL de l'application, puis « Exécuter ».
-- Le script est rejouable : le relancer ne casse rien et ne vide aucune table.
--
-- Trois tables :
--   offres        ce qu'on publie pour pourvoir un besoin de recrutement
--   candidats     le vivier des personnes qui postulent
--   candidatures  le lien entre une offre et un candidat, étape par étape
--
-- Les références au socle (besoin_id, position_id, establishment_id) sont de
-- simples entiers, sans clé étrangère : une remise à zéro du socle ne doit
-- jamais emporter nos données.
-- =============================================================================

-- Une offre naît de la prise en charge d'un besoin de recrutement.
create table if not exists offres (
  id                serial  primary key,
  besoin_id         integer,                         -- public.identified_needs
  position_id       integer not null,                -- public.positions
  establishment_id  integer not null,                -- public.establishments
  intitule          text    not null,
  type_contrat      text    not null default 'CDI',  -- CDI, CDD, SAISONNIER…
  description       text,
  statut            text    not null default 'brouillon'
                    check (statut in ('brouillon', 'publiee', 'pourvue', 'annulee')),
  creee_le          date    not null default current_date,
  publiee_le        date
);

-- Le vivier : une personne peut postuler à plusieurs offres.
create table if not exists candidats (
  id         serial primary key,
  nom        text   not null,
  prenom     text   not null,
  email      text,
  telephone  text,
  source     text   not null default 'spontanée',   -- Indeed, LinkedIn, cooptation…
  cree_le    date   not null default current_date
);

-- Une candidature = un candidat sur une offre, à une étape du processus.
create table if not exists candidatures (
  id           serial  primary key,
  offre_id     integer not null references offres(id)    on delete cascade,
  candidat_id  integer not null references candidats(id) on delete cascade,
  etape        text    not null default 'nouvelle'
               check (etape in ('nouvelle', 'preselection', 'entretien',
                                'proposition', 'embauche', 'refus')),
  note         integer check (note between 1 and 5),
  commentaire  text,
  recue_le     date    not null default current_date,
  maj_le       date    not null default current_date,
  unique (offre_id, candidat_id)                       -- pas de doublon
);
