-- =============================================================================
-- SIRH pédagogique — 02 — Alimentation des référentiels
--
-- Ré-exécutable : les insertions sont idempotentes (on conflict do update).
-- =============================================================================

insert into ref_civilite (code, libelle, ordre) values
  ('M',   'Monsieur', 1),
  ('MME', 'Madame',   2)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;


insert into ref_type_contrat (code, libelle, ordre) values
  ('CDI',   'CDI',                          1),
  ('CDD',   'CDD',                          2),
  ('APP',   'Contrat d''apprentissage',     3),
  ('PRO',   'Contrat de professionnalisation', 4),
  ('STAGE', 'Convention de stage',          5),
  ('INT',   'Intérim',                      6)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;


-- Motifs de recours au CDD (art. L1242-2 du Code du travail).
insert into ref_motif_cdd (code, libelle, ordre) values
  ('REMPL',   'Remplacement d''un salarié absent',        1),
  ('ACCROI',  'Accroissement temporaire d''activité',     2),
  ('SAISON',  'Emploi à caractère saisonnier',            3),
  ('USAGE',   'CDD d''usage',                             4),
  ('ATTENTE', 'Attente de prise de poste d''un recruté',  5)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;


insert into ref_motif_sortie (code, libelle, ordre) values
  ('DEM',    'Démission',                1),
  ('RC',     'Rupture conventionnelle',  2),
  ('LIC_ECO','Licenciement économique',  3),
  ('LIC_PER','Licenciement personnel',   4),
  ('FIN_CDD','Fin de CDD',               5),
  ('FIN_ESS','Rupture période d''essai', 6),
  ('RETR',   'Départ à la retraite',     7),
  ('FIN_ALT','Fin d''alternance',        8),
  ('FIN_STG','Fin de stage',             9),
  ('MUT',    'Mutation intra-groupe',   10)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;


-- Catégories socioprofessionnelles (nomenclature simplifiée).
insert into ref_csp (code, libelle, ordre) values
  ('OUV', 'Ouvrier',                  1),
  ('EMP', 'Employé',                  2),
  ('TAM', 'Technicien / Agent de maîtrise', 3),
  ('CAD', 'Cadre',                    4)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;


-- Types d'avenant. Un avenant modifie les termes négociables du contrat :
-- l'avenant n° 1 est le contrat initial lui-même.
insert into ref_type_avenant (code, libelle, ordre) values
  ('INITIAL',   'Contrat initial',                1),
  ('AUGM',      'Augmentation individuelle',      2),
  ('AUGM_GEN',  'Augmentation générale',          3),
  ('PROMO',     'Promotion',                      4),
  ('TEMPS',     'Changement de temps de travail', 5),
  ('CLASSIF',   'Changement de classification',   6),
  ('MOBILITE',  'Mobilité',                       7),
  ('AUTRE',     'Autre avenant',                  8)
on conflict (code) do update set libelle = excluded.libelle, ordre = excluded.ordre;
