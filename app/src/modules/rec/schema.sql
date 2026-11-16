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


-- =============================================================================
-- Workflow de recrutement (story #127)
--
--   1 Candidature externe reçue (nouvelle)   4 Offre à présenter (proposition)
--   2 Tri de CV                (preselection) 5 Offre acceptée    (offre_acceptee)
--   3 Entretien à réaliser     (entretien)    6 Embauché          (embauche)
--   — Refusé (refus) : sortie du workflow, avec motif, réactivable
-- =============================================================================

-- La nouvelle étape « offre acceptée ».
alter table candidatures drop constraint if exists candidatures_etape_check;
alter table candidatures add constraint candidatures_etape_check
  check (etape in ('nouvelle', 'preselection', 'entretien', 'proposition',
                   'offre_acceptee', 'embauche', 'refus'));

-- Le refus : son motif, et l'étape à laquelle revenir si on réactive.
alter table candidatures add column if not exists motif_refus text;
alter table candidatures add column if not exists etape_avant_refus text;

-- Chaque changement d'étape, quel que soit l'écran d'où il est fait.
create table if not exists historique_etapes (
  id              serial    primary key,
  candidature_id  integer   not null references candidatures(id) on delete cascade,
  etape_depart    text,
  etape_arrivee   text      not null,
  mouvement       text      not null
                  check (mouvement in ('avance', 'retour', 'refus', 'reactivation')),
  motif           text,                              -- motif de refus
  commentaire     text,
  fait_le         timestamp not null
);

-- Le panel de compétences que le recruteur peut choisir d'évaluer.
create table if not exists panel_competences (
  id       serial  primary key,
  famille  text    not null,
  libelle  text    not null unique,
  ordre    integer not null
);

insert into panel_competences (famille, libelle, ordre) values
  ('Savoir-être', 'Sens du service client', 1),
  ('Savoir-être', 'Présentation et savoir-vivre', 2),
  ('Savoir-être', 'Fiabilité et ponctualité', 3),
  ('Savoir-être', 'Esprit d''équipe', 4),
  ('Communication et langues', 'Expression orale', 5),
  ('Communication et langues', 'Écoute et reformulation', 6),
  ('Communication et langues', 'Anglais professionnel', 7),
  ('Communication et langues', 'Seconde langue étrangère', 8),
  ('Techniques hôtelières', 'Accueil et check-in / check-out', 9),
  ('Techniques hôtelières', 'Logiciel de réservation (PMS)', 10),
  ('Techniques hôtelières', 'Hygiène et normes HACCP', 11),
  ('Techniques hôtelières', 'Remise en état des chambres', 12),
  ('Organisation et management', 'Organisation et gestion des priorités', 13),
  ('Organisation et management', 'Gestion des réclamations', 14),
  ('Organisation et management', 'Prise d''initiative', 15),
  ('Organisation et management', 'Animation d''équipe', 16)
on conflict (libelle) do nothing;

-- Les compétences retenues pour un entretien, et leur évaluation.
--   source 'poste' : competence_id = public.skills (attendue sur le poste)
--   source 'panel' : competence_id = panel_competences
create table if not exists entretien_competences (
  id               serial  primary key,
  entretien_id     integer not null references entretiens(id) on delete cascade,
  source           text    not null check (source in ('poste', 'panel')),
  competence_id    integer not null,
  libelle          text    not null,
  famille          text,
  niveau_attendu   integer not null check (niveau_attendu between 1 and 4),
  niveau_constate  integer check (niveau_constate between 1 and 4),
  commentaire      text,
  unique (entretien_id, source, competence_id)
);

-- Les évaluations déjà saisies au sprint 2 sont reprises dans la nouvelle table.
insert into entretien_competences
       (entretien_id, source, competence_id, libelle, niveau_attendu, niveau_constate, commentaire)
select entretien_id, 'poste', skill_id, competence, coalesce(niveau_attendu, 2), niveau_constate, commentaire
  from evaluations_competences
on conflict (entretien_id, source, competence_id) do nothing;


-- =============================================================================
-- Page DP : détails du poste (story #147)
-- =============================================================================

alter table offres add column if not exists recruteur_id     integer;      -- public.employees (Chargé RH)
alter table offres add column if not exists recruteur_nom    text;
alter table offres add column if not exists manager_id       integer;      -- public.employees
alter table offres add column if not exists manager_nom      text;
alter table offres add column if not exists temps_travail    text not null default 'temps_plein';
alter table offres add column if not exists quotite          integer;      -- en pourcentage, si temps partiel
alter table offres add column if not exists salaire_min_k    numeric(5,1); -- k€ brut annuel
alter table offres add column if not exists salaire_max_k    numeric(5,1);
alter table offres add column if not exists date_prise_poste date;
alter table offres add column if not exists nb_postes        integer not null default 1;

alter table offres drop constraint if exists offres_details_check;
alter table offres add constraint offres_details_check check (
  temps_travail in ('temps_plein', 'temps_partiel')
  and (temps_travail = 'temps_plein' or quotite between 10 and 99)
  and (salaire_min_k is null or salaire_max_k is null or salaire_min_k <= salaire_max_k)
  and nb_postes >= 1
);


-- =============================================================================
-- Version du schéma appliquée automatiquement par le module (_schema.js)
-- =============================================================================

create table if not exists schema_version (
  id           integer   primary key,
  empreinte    text      not null,
  applique_le  timestamp not null
);
