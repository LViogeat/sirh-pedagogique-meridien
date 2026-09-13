-- =============================================================================
-- SIRH pédagogique — 01 — Schéma Core HR
-- Master SIRH — Université Paris 1 Panthéon-Sorbonne
--
-- À exécuter en premier, dans le SQL Editor de Supabase.
-- Ordre d'exécution : 01-schema → 02-referentiels → 03-vues
--                   → 04-profils-policies → 05-seed
--
-- Ce script est ré-exécutable : il supprime et recrée tout le Core HR.
-- ATTENTION : il détruit les données. Ne jamais le rejouer en cours de session.
-- =============================================================================

drop view  if exists v_historique_remuneration cascade;
drop view  if exists v_postes               cascade;
drop view  if exists v_organigramme          cascade;
drop view  if exists v_mouvements            cascade;
drop view  if exists v_effectif_par_service  cascade;
drop view  if exists v_employes_actifs       cascade;
drop view  if exists v_personnes             cascade;
drop view  if exists v_affectations_actives  cascade;
drop view  if exists v_contrats_actifs       cascade;
drop view  if exists v_avenants_actifs       cascade;

drop table if exists affectations              cascade;
drop table if exists avenants                  cascade;
drop table if exists contrats                  cascade;
drop table if exists postes                    cascade;
drop table if exists emplois                   cascade;
drop table if exists unites_organisationnelles cascade;
drop table if exists personnes                 cascade;
drop table if exists etablissements            cascade;

drop table if exists ref_civilite      cascade;
drop table if exists ref_type_contrat  cascade;
drop table if exists ref_motif_cdd     cascade;
drop table if exists ref_motif_sortie  cascade;
drop table if exists ref_csp           cascade;
drop table if exists ref_type_avenant  cascade;


-- -----------------------------------------------------------------------------
-- 1. RÉFÉRENTIELS
--
-- Toutes les tables ref_* ont exactement la même forme. C'est volontaire :
-- le SDK les lit uniformément via getRef('type_contrat'), et une IA à qui on
-- décrit une seule forme ne peut pas se tromper sur les autres.
-- -----------------------------------------------------------------------------

create table ref_civilite (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);

create table ref_type_contrat (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);

create table ref_motif_cdd (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);

create table ref_motif_sortie (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);

create table ref_csp (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);

create table ref_type_avenant (
  code    text primary key,
  libelle text    not null,
  ordre   int     not null default 0,
  actif   boolean not null default true
);


-- -----------------------------------------------------------------------------
-- 2. STRUCTURE DE L'ENTREPRISE
-- -----------------------------------------------------------------------------

create table etablissements (
  id             bigint generated always as identity primary key,
  code           text not null unique,
  nom            text not null,
  siret          text,
  adresse        text,
  code_postal    text,
  ville          text,
  date_ouverture date
);

comment on table etablissements is
  'Entités juridiques ou géographiques. Un contrat est toujours rattaché à un établissement.';


-- Les personnes sont créées avant les unités car une unité a un responsable.
create table personnes (
  id             bigint generated always as identity primary key,
  matricule      text unique,
  civilite_code  text references ref_civilite(code),
  nom            text not null,
  nom_usage      text,
  prenom         text not null,
  date_naissance date,
  email_perso    text,
  email_pro      text,
  telephone      text,
  adresse        text,
  code_postal    text,
  ville          text,
  nationalite    text default 'Française'
);

comment on table personnes is
  'L''IDENTITÉ, indépendamment de tout emploi. Une personne peut être candidate '
  '(matricule NULL), puis salariée, puis ancienne salariée. C''est ce découpage '
  'qui permet au module Recrutement de s''accrocher au référentiel.';
comment on column personnes.matricule is
  'NULL tant que la personne n''a jamais été salariée. Sert de test « est-ce un salarié ? ».';


create table unites_organisationnelles (
  id                      bigint generated always as identity primary key,
  code                    text not null unique,
  libelle                 text not null,
  type_unite              text not null
                          check (type_unite in ('direction', 'departement', 'service')),
  parent_id               bigint references unites_organisationnelles(id),
  etablissement_id        bigint not null references etablissements(id),
  responsable_personne_id bigint references personnes(id),
  actif                   boolean not null default true
);

comment on table unites_organisationnelles is
  'Arbre organisationnel auto-référencé (parent_id) sur 3 niveaux : '
  'direction > département > service.';


create table emplois (
  id             bigint generated always as identity primary key,
  code           text not null unique,
  libelle        text not null,
  famille_metier text not null,
  csp_code       text not null references ref_csp(code)
);

comment on table emplois is
  'Le RÉFÉRENTIEL MÉTIER : « Chargé de recrutement » existe même si personne '
  'ne l''occupe. À ne pas confondre avec un poste.';


create table postes (
  id          bigint generated always as identity primary key,
  code        text not null unique,
  libelle     text,
  emploi_id   bigint not null references emplois(id),
  unite_id    bigint not null references unites_organisationnelles(id),
  etp_budgete numeric(4,2) not null default 1.00,
  ouvert      boolean not null default true
);

comment on table postes is
  'La POSITION BUDGÉTÉE : un emploi, dans une unité, pour un ETP donné. '
  'Un poste ouvert et non pourvu est une vacance — c''est le crochet naturel '
  'du module Recrutement (« une offre pourvoit un poste vacant »).';


-- -----------------------------------------------------------------------------
-- 3. RELATION DE TRAVAIL ET AFFECTATION
--
-- Ces deux tables sont HISTORISÉES. C'est ce qui distingue un SIRH d'un
-- fichier Excel — et c'est aussi ce que les étudiants ne verront jamais
-- directement : ils consommeront les vues aplaties de 03-vues.sql.
-- -----------------------------------------------------------------------------

create table contrats (
  id                bigint generated always as identity primary key,
  personne_id       bigint not null references personnes(id) on delete cascade,
  etablissement_id  bigint not null references etablissements(id),
  numero            text not null unique,
  type_contrat_code text not null references ref_type_contrat(code),
  date_debut        date not null,
  date_fin_prevue   date,
  date_fin_reelle   date,
  fin_periode_essai date,
  motif_cdd_code    text references ref_motif_cdd(code),
  motif_sortie_code text references ref_motif_sortie(code),

  constraint contrat_fin_prevue_coherente
    check (date_fin_prevue is null or date_fin_prevue >= date_debut),
  constraint contrat_fin_reelle_coherente
    check (date_fin_reelle is null or date_fin_reelle >= date_debut),
  constraint contrat_cdd_motif_obligatoire
    check (type_contrat_code <> 'CDD' or motif_cdd_code is not null),
  constraint contrat_sortie_motif_obligatoire
    check (date_fin_reelle is null or motif_sortie_code is not null)
);

comment on table contrats is
  'La RELATION DE TRAVAIL : juridique, datée. Ne porte QUE ce qui ne change '
  'jamais au cours de la vie du contrat. Tout ce qui est négociable — salaire, '
  'temps de travail, classification — vit dans la table avenants.';
comment on column contrats.date_fin_prevue is
  'Terme prévu au contrat (CDD, stage). NULL pour un CDI.';
comment on column contrats.date_fin_reelle is
  'Sortie effective. Tant qu''elle est NULL, le contrat court.';


-- -----------------------------------------------------------------------------
-- LES AVENANTS
--
-- Un salaire n'est pas un attribut du contrat : c'est l'état courant d'une
-- SUITE D'AVENANTS DATÉS. Une augmentation, un passage à temps partiel, une
-- promotion sont juridiquement des avenants, avec une date d'effet.
--
-- Choix de modélisation : LE CONTRAT INITIAL EST LUI-MÊME UN AVENANT (n° 1).
-- Les termes variables ne vivent donc QUE dans cette table, jamais en double
-- sur le contrat. Pas de logique de repli « si pas d'avenant, prendre la
-- valeur du contrat » — c'est exactement là que les erreurs se logent.
--
-- L'état courant = le dernier avenant dont la date d'effet est passée.
-- Les étudiants ne font jamais ce calcul : la vue v_employes_actifs le fait.
-- -----------------------------------------------------------------------------

create table avenants (
  id                        bigint generated always as identity primary key,
  contrat_id                bigint not null references contrats(id) on delete cascade,
  numero_ordre              int    not null,
  type_avenant_code         text   not null references ref_type_avenant(code),
  date_effet                date   not null,
  date_signature            date,
  motif                     text,

  etp                       numeric(4,2) not null,
  csp_code                  text   not null references ref_csp(code),
  classification            text,
  coefficient               int,
  salaire_base_brut_mensuel numeric(10,2),

  constraint avenant_ordre_unique  unique (contrat_id, numero_ordre),
  constraint avenant_effet_unique  unique (contrat_id, date_effet),
  constraint avenant_etp_valide    check (etp > 0 and etp <= 1),
  constraint avenant_salaire_positif
    check (salaire_base_brut_mensuel is null or salaire_base_brut_mensuel > 0)
);

comment on table avenants is
  'Les termes NÉGOCIABLES du contrat, datés. L''avenant n° 1 est le contrat '
  'initial ; les suivants sont les augmentations, promotions et changements '
  'de temps de travail.';
comment on column avenants.date_effet is
  'Date à laquelle les nouveaux termes s''appliquent. À ne pas confondre avec '
  'la date de signature, qui peut la précéder.';
comment on column avenants.salaire_base_brut_mensuel is
  'Salaire CONTRACTUEL, qui relève bien du Core HR. La paie (bulletins, '
  'cotisations, net) est hors périmètre : elle est externalisée.';


create table affectations (
  id                  bigint generated always as identity primary key,
  personne_id         bigint not null references personnes(id) on delete cascade,
  poste_id            bigint references postes(id),
  unite_id            bigint not null references unites_organisationnelles(id),
  manager_personne_id bigint references personnes(id),
  date_debut          date not null,
  date_fin            date,
  taux_affectation    numeric(4,2) not null default 1.00,

  constraint affectation_dates_coherentes
    check (date_fin is null or date_fin >= date_debut),
  constraint affectation_taux_valide
    check (taux_affectation > 0 and taux_affectation <= 1)
);

comment on table affectations is
  'OÙ la personne travaille et SOUS QUELLE AUTORITÉ. Historisée séparément '
  'du contrat, car on change de service ou de manager sans changer de contrat. '
  'C''est le point de modélisation le plus important du schéma.';


-- -----------------------------------------------------------------------------
-- 4. INDEX
-- -----------------------------------------------------------------------------

create index idx_contrats_personne      on contrats(personne_id);
create index idx_avenants_contrat       on avenants(contrat_id);
create index idx_avenants_effet         on avenants(date_effet);
create index idx_contrats_dates         on contrats(date_debut, date_fin_prevue, date_fin_reelle);
create index idx_affectations_personne  on affectations(personne_id);
create index idx_affectations_unite     on affectations(unite_id);
create index idx_affectations_manager   on affectations(manager_personne_id);
create index idx_affectations_dates     on affectations(date_debut, date_fin);
create index idx_unites_parent          on unites_organisationnelles(parent_id);
create index idx_postes_unite           on postes(unite_id);
