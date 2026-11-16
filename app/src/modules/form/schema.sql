-- =============================================================================
-- Module Formation — schéma « form »
--
-- Ce fichier est rejouable : on peut le coller en entier dans la Console SQL
-- autant de fois qu'on veut, il ne casse rien et ne duplique rien.
-- Les écrans du module l'appliquent aussi tout seuls au premier affichage si
-- les tables n'existent pas encore (voir _donnees.js).
--
-- Rappel des règles du socle : pas de préfixe, une colonne id serial dans
-- chaque table, des clés étrangères entre NOS tables, jamais vers le socle
-- (employee_id, establishment_id et skill_id sont de simples integer).
-- =============================================================================

-- Le catalogue commun à tous les établissements (story #9)
create table if not exists formations (
  id               serial primary key,
  code             text not null unique,
  intitule         text not null,
  domaine          text not null,
  objectifs        text,
  programme        text,
  duree_heures     integer not null default 7 check (duree_heures > 0),
  prerequis        text,
  modalite         text not null default 'presentiel'
                   check (modalite in ('presentiel', 'distanciel', 'mixte')),
  lieu             text,
  periodicite_mois integer check (periodicite_mois is null or periodicite_mois > 0),
  skill_id         integer,
  actif            boolean not null default true,
  cree_le          timestamp not null default now()
);

-- Les formations obligatoires, par famille de métier (story #35).
-- famille_metier reprend public.positions.job_family, ou 'Tous' pour
-- une formation obligatoire quel que soit le poste.
create table if not exists obligations (
  id             serial primary key,
  formation_id   integer not null references formations(id) on delete cascade,
  famille_metier text not null default 'Tous',
  unique (formation_id, famille_metier)
);

-- Les sessions planifiées d'une formation (stories #38 et #21)
create table if not exists sessions (
  id               serial primary key,
  formation_id     integer not null references formations(id),
  date_debut       date not null,
  date_fin         date not null,
  heure_debut      time not null,
  heure_fin        time not null,
  establishment_id integer not null,
  salle            text,
  formateur        text,
  places           integer not null check (places > 0),
  statut           text not null default 'ouverte'
                   check (statut in ('ouverte', 'fermee', 'terminee', 'annulee')),
  cree_le          timestamp not null default now(),
  check (date_fin >= date_debut)
);

-- Les inscriptions des salariés aux sessions (stories #19, #53 et #39).
-- presence reste vide tant que le formateur n'a pas fait l'émargement.
create table if not exists inscriptions (
  id          serial primary key,
  session_id  integer not null references sessions(id) on delete cascade,
  employee_id integer not null,
  statut      text not null default 'demandee'
              check (statut in ('demandee', 'validee', 'refusee', 'annulee')),
  origine     text not null default 'collaborateur'
              check (origine in ('collaborateur', 'rh')),
  presence    text check (presence is null
                          or presence in ('present', 'absent', 'absent_justifie')),
  commentaire text,
  cree_le     timestamp not null default now(),
  unique (session_id, employee_id)
);

-- -----------------------------------------------------------------------------
-- Un premier catalogue, pour ne pas partir d'un écran vide.
-- Inséré seulement si la table formations est vide.
-- -----------------------------------------------------------------------------
insert into formations
  (code, intitule, domaine, objectifs, programme, duree_heures, prerequis,
   modalite, lieu, periodicite_mois, skill_id)
select v.code, v.intitule, v.domaine, v.objectifs, v.programme, v.duree_heures,
       v.prerequis, v.modalite, v.lieu, v.periodicite_mois, s.id
from (values
  ('SEC-INCENDIE', 'Sécurité incendie et évacuation', 'Sécurité',
   'Connaître les consignes de sécurité incendie de l''hôtel et savoir évacuer les clients.',
   'Les risques dans un hôtel. Lecture des consignes et des plans. Maniement des extincteurs. Exercice d''évacuation.',
   4, 'Aucun', 'presentiel', 'Dans chaque établissement', 12, null),
  ('SST', 'Sauveteur secouriste du travail (SST)', 'Sécurité',
   'Être capable de porter secours à un collègue ou à un client en attendant les secours.',
   'Protéger, examiner, alerter, secourir. Mises en situation. Délivrance du certificat SST.',
   14, 'Aucun', 'presentiel', 'Dans chaque établissement', 24, null),
  ('HACCP', 'Hygiène alimentaire et méthode HACCP', 'Hygiène',
   'Appliquer les règles d''hygiène alimentaire et la méthode HACCP en cuisine et en salle.',
   'Les dangers alimentaires. Les bonnes pratiques d''hygiène. Le plan de maîtrise sanitaire. Traçabilité et contrôles.',
   14, 'Aucun', 'presentiel', 'Dans chaque établissement', 36, 'HACCP'),
  ('PERMIS-EXPLOIT', 'Permis d''exploitation (débit de boissons)', 'Réglementaire',
   'Connaître les obligations liées à la vente d''alcool dans un établissement.',
   'Le cadre légal. Les licences. La prévention de l''ivresse et la protection des mineurs. Les responsabilités de l''exploitant.',
   20, 'Aucun', 'presentiel', 'Sorbonne-Hôtel Panthéon, Paris', 120, null),
  ('HAB-ELEC', 'Habilitation électrique', 'Réglementaire',
   'Intervenir en sécurité sur ou à proximité des installations électriques.',
   'Les dangers de l''électricité. Les zones et les niveaux d''habilitation. Les équipements de protection. Exercices pratiques.',
   14, 'Travailler à la maintenance', 'presentiel', 'Sorbonne-Hôtel Panthéon, Paris', 36, 'ELEC'),
  ('ACCUEIL-EXC', 'Accueil client et excellence de service', 'Relation client',
   'Offrir un accueil au niveau attendu dans un hôtel 4 et 5 étoiles.',
   'Les attentes des clients. Les étapes de l''accueil et du check-in. La personnalisation du séjour. Jeux de rôle.',
   7, 'Aucun', 'presentiel', 'Dans chaque établissement', null, 'ACCUEIL'),
  ('RECLAMATIONS', 'Gérer les réclamations des clients', 'Relation client',
   'Savoir répondre à un client mécontent et transformer une réclamation en occasion de fidéliser.',
   'Comprendre le mécontentement. L''écoute active. Proposer une solution. Cas pratiques tirés des avis en ligne.',
   7, 'Être en contact avec la clientèle', 'mixte', 'Dans chaque établissement et en classe virtuelle', null, 'RECLAM'),
  ('ANGLAIS-PRO', 'Anglais professionnel de l''hôtellerie', 'Langues',
   'Être à l''aise en anglais dans les situations courantes avec les clients.',
   'Accueillir et renseigner. Prendre une réservation. Répondre au téléphone. Vocabulaire de la restauration et de l''hébergement.',
   30, 'Niveau débutant accepté, test de positionnement au départ', 'distanciel', 'Classe virtuelle', null, 'EN'),
  ('PMS-RESA', 'Prise en main du logiciel de réservation (PMS)', 'Outils',
   'Utiliser le logiciel de réservation au quotidien, de la réservation à la facturation.',
   'Créer et modifier une réservation. Check-in et check-out. Facturation. Clôture de journée.',
   7, 'Travailler à la réception ou à la réservation', 'presentiel', 'Sorbonne-Hôtel Panthéon, Paris', null, 'PMS'),
  ('MANAGER-EQUIPE', 'Manager une équipe au quotidien', 'Management',
   'Prendre son rôle de manager de proximité et animer son équipe.',
   'Le rôle du manager. Organiser le travail et les plannings. Donner un retour. Gérer les tensions.',
   14, 'Encadrer une équipe ou être sur le point de le faire', 'presentiel', 'Sorbonne-Hôtel Panthéon, Paris', null, 'ENCADRE'),
  ('ENTRETIEN-ANNUEL', 'Conduire un entretien annuel', 'Management',
   'Préparer et mener les entretiens annuels de son équipe.',
   'Préparer l''entretien. Fixer des objectifs. Évaluer les compétences. Recueillir les souhaits d''évolution et de formation.',
   7, 'Être manager', 'mixte', 'Classe virtuelle puis atelier dans l''établissement', null, 'ENTRETIEN')
) as v (code, intitule, domaine, objectifs, programme, duree_heures, prerequis,
        modalite, lieu, periodicite_mois, skill_code)
left join public.skills s on s.code = v.skill_code
where not exists (select 1 from formations);

-- Qui doit suivre quoi. Inséré seulement si la table obligations est vide.
insert into obligations (formation_id, famille_metier)
select f.id, v.famille_metier
from (values
  ('SEC-INCENDIE',   'Tous'),
  ('SST',            'Technique'),
  ('SST',            'Direction'),
  ('HACCP',          'Cuisine'),
  ('HACCP',          'Restauration'),
  ('PERMIS-EXPLOIT', 'Direction'),
  ('HAB-ELEC',       'Technique')
) as v (code, famille_metier)
join formations f on f.code = v.code
where not exists (select 1 from obligations);

-- Quelques sessions d'exemple. Insérées seulement si la table sessions est vide.
-- Les identifiants d'établissement du socle sont stables : 1 Panthéon,
-- 2 Bellecour, 3 Garonne, 4 Promenade, 5 Mont-Blanc.
insert into sessions
  (formation_id, date_debut, date_fin, heure_debut, heure_fin,
   establishment_id, salle, formateur, places)
select f.id, cast(v.date_debut as date), cast(v.date_fin as date),
       cast(v.heure_debut as time), cast(v.heure_fin as time),
       v.establishment_id, v.salle, v.formateur, v.places
from (values
  ('SEC-INCENDIE', '2026-12-03', '2026-12-03', '09:00', '13:00', 1, 'Salon Soufflot',  'Organisme externe - Prévention Sécurité', 12),
  ('SEC-INCENDIE', '2026-12-10', '2026-12-10', '14:00', '18:00', 2, 'Salle Bellecour', 'Organisme externe - Prévention Sécurité', 10),
  ('HACCP',        '2026-12-08', '2026-12-09', '09:00', '17:00', 1, 'Cuisine école',   'Formateur interne - Chef de cuisine',     8),
  ('ACCUEIL-EXC',  '2026-12-15', '2026-12-15', '09:00', '17:00', 4, 'Salon Azur',      'Formateur interne - Chef de réception',   10),
  ('ANGLAIS-PRO',  '2027-01-11', '2027-03-26', '14:00', '15:30', 1, 'Classe virtuelle','Organisme externe - Langues Pro',         15),
  ('SST',          '2027-01-19', '2027-01-20', '09:00', '17:00', 3, 'Salle Chartrons', 'Organisme externe - Secourisme',          10)
) as v (code, date_debut, date_fin, heure_debut, heure_fin,
        establishment_id, salle, formateur, places)
join formations f on f.code = v.code
where not exists (select 1 from sessions);
