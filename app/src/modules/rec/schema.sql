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


-- =============================================================================
-- Sprint 2 — entretiens, évaluation des compétences, pièces jointes
-- =============================================================================

-- Le consentement RGPD donné par le candidat (page carrière).
alter table candidats add column if not exists consentement_le date;

-- Un entretien de recrutement, rattaché à une candidature.
create table if not exists entretiens (
  id              serial    primary key,
  candidature_id  integer   not null references candidatures(id) on delete cascade,
  date_heure      timestamp not null,
  lieu            text,                              -- salle, adresse ou lien visio
  recruteur_id    integer,                           -- public.employees
  recruteur_nom   text,                              -- recopié pour l'affichage
  statut          text      not null default 'planifie'
                  check (statut in ('planifie', 'realise', 'annule')),
  compte_rendu    text,
  avis            text      check (avis in ('favorable', 'reserve', 'defavorable')),
  recommandation  text      check (recommandation in ('proposition', 'second_entretien', 'refus')),
  cree_le         date      not null default current_date
);

-- Le niveau constaté en entretien, compétence par compétence du poste.
create table if not exists evaluations_competences (
  id               serial  primary key,
  entretien_id     integer not null references entretiens(id) on delete cascade,
  skill_id         integer not null,                 -- public.skills
  competence       text    not null,                 -- libellé recopié
  niveau_attendu   integer check (niveau_attendu between 1 and 4),
  niveau_constate  integer check (niveau_constate between 1 and 4),
  commentaire      text,
  unique (entretien_id, skill_id)
);

-- Les documents d'un candidat (CV, lettre…), stockés en base64.
create table if not exists pieces_jointes (
  id             serial  primary key,
  candidat_id    integer not null references candidats(id) on delete cascade,
  type_document  text    not null default 'cv'
                 check (type_document in ('cv', 'lettre', 'autre')),
  nom_fichier    text    not null,
  type_mime      text    not null,
  taille         integer not null,                   -- en octets, 500 Ko maximum
  contenu        text    not null,                   -- le fichier, encodé en base64
  ajoutee_le     date    not null default current_date
);
