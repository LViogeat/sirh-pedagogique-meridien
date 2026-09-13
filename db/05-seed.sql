-- =============================================================================
-- SIRH pédagogique — 05 — Jeu de données de démonstration
--
-- Société fictive : GROUPE MERIDIEN — PME industrielle et commerciale française.
-- 3 établissements, 5 directions, 13 services, 180 salariés présents,
-- une trentaine d'anciens salariés et une dizaine de candidats externes.
--
-- ┌───────────────────────────────────────────────────────────────────────┐
-- │ CE SCRIPT EST DÉTERMINISTE : aucun random(), aucune dépendance à       │
-- │ l'horloge autre que current_date. Rejoué deux fois, il produit         │
-- │ exactement les mêmes lignes.                                          │
-- │                                                                        │
-- │ C'est une exigence de la RECETTE : les étudiants doivent pouvoir       │
-- │ écrire « alors la liste affiche 22 salariés au service Études »        │
-- │ AVANT d'avoir codé l'écran.                                           │
-- └───────────────────────────────────────────────────────────────────────┘
--
-- ATTENTION : ce script vide le Core HR avant de le recharger.
-- =============================================================================

truncate table affectations, avenants, contrats, postes, emplois,
               unites_organisationnelles, personnes, etablissements
         restart identity cascade;


-- -----------------------------------------------------------------------------
-- Petit utilitaire : retirer les accents pour fabriquer les adresses e-mail.
-- (L'extension unaccent n'est pas activée par défaut sur un projet Supabase.)
-- -----------------------------------------------------------------------------

create or replace function sans_accent(t text)
returns text
language sql
immutable
as 'select translate($1,
     ''àâäáãåçèéêëìíîïñòóôöõùúûüýÿÀÂÄÁÃÅÇÈÉÊËÌÍÎÏÑÒÓÔÖÕÙÚÛÜÝ'',
     ''aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY'')';


-- -----------------------------------------------------------------------------
-- Fabrique la suite d'avenants d'un contrat : le contrat initial, puis les
-- augmentations et promotions échelonnées sur l'ancienneté.
--
-- On raisonne À REBOURS : on connaît le salaire courant visé, on en déduit le
-- salaire d'embauche en divisant par les augmentations successives. C'est ce
-- qui garantit à la fois une histoire crédible ET une masse salariale conforme.
-- -----------------------------------------------------------------------------

create or replace function _seed_carriere(
  p_contrat_id bigint,
  p_date_debut date,
  p_date_ref   date,       -- date à laquelle p_salaire est le salaire en vigueur
  p_salaire    numeric,
  p_etp        numeric,
  p_csp        text,
  p_classif    text,
  p_coef       int,
  p_graine     int
) returns int
language plpgsql as $carriere$
declare
  anc_jours int := greatest(p_date_ref - p_date_debut, 0);
  nb_aug    int;
  pcts      numeric[] := '{}';
  types     text[]    := '{}';
  facteur   numeric   := 1;
  pct       numeric;
  sal       numeric;
  d         date;
  i         int;
begin
  -- Une révision tous les 26 mois environ, six au maximum.
  nb_aug := least(floor(anc_jours / 790.0)::int, 6);

  for i in 1 .. nb_aug loop
    pct := 1.5 + ((p_graine + i * 7) % 5) * 0.7;          -- 1,5 % → 4,3 %
    if (p_graine + i) % 6 = 0 then
      pct   := pct + 3.5;                                  -- promotion
      types := types || 'PROMO'::text;
    else
      types := types || (case when (p_graine + i) % 3 = 0 then 'AUGM_GEN' else 'AUGM' end)::text;
    end if;
    pcts    := pcts || pct;
    facteur := facteur * (1 + pct / 100);
  end loop;

  sal := round(p_salaire / facteur, 2);

  insert into avenants (contrat_id, numero_ordre, type_avenant_code, date_effet,
                        date_signature, motif, etp, csp_code, classification,
                        coefficient, salaire_base_brut_mensuel)
  values (p_contrat_id, 1, 'INITIAL', p_date_debut, p_date_debut - 10,
          'Signature du contrat', p_etp, p_csp, p_classif,
          greatest(p_coef - nb_aug * 5, 100), sal);

  for i in 1 .. nb_aug loop
    sal := round(sal * (1 + pcts[i] / 100), 2);
    d   := p_date_debut + ((anc_jours::numeric * i / (nb_aug + 1))::int);
    insert into avenants (contrat_id, numero_ordre, type_avenant_code, date_effet,
                          date_signature, motif, etp, csp_code, classification,
                          coefficient, salaire_base_brut_mensuel)
    values (p_contrat_id, i + 1, types[i], d, d - 20,
            case types[i] when 'PROMO'    then 'Promotion'
                          when 'AUGM_GEN' then 'Revalorisation générale'
                          else                 'Révision annuelle' end,
            p_etp, p_csp, p_classif,
            greatest(p_coef - (nb_aug - i) * 5, 100), sal);
  end loop;

  -- Le dernier avenant doit restituer EXACTEMENT le salaire cible.
  if nb_aug > 0 then
    update avenants set salaire_base_brut_mensuel = p_salaire
     where contrat_id = p_contrat_id and numero_ordre = nb_aug + 1;
  end if;

  return nb_aug + 1;
end;
$carriere$;


-- -----------------------------------------------------------------------------
-- 1. Établissements
-- -----------------------------------------------------------------------------

insert into etablissements (code, nom, siret, adresse, code_postal, ville, date_ouverture) values
  ('SIEGE',  'Meridien — Siège',          '81234567800012', '14 rue de Provence',         '75009', 'Paris',  '1998-03-02'),
  ('LYON',   'Meridien — Agence Lyon',    '81234567800038', '5 quai Jean Moulin',         '69001', 'Lyon',   '2007-09-17'),
  ('NANTES', 'Meridien — Site de Nantes', '81234567800053', '27 boulevard des Fonderies', '44200', 'Nantes', '2012-01-09');


-- -----------------------------------------------------------------------------
-- 2. Plan de l'organisation
--
-- Cette table décrit l'entreprise cible ; tout le reste en découle. Pour
-- changer un effectif ou ajouter un service, c'est le SEUL endroit à toucher.
-- -----------------------------------------------------------------------------

drop table if exists _plan;
create temp table _plan (
  ordre         int,
  dir_code      text,
  dir_libelle   text,
  svc_code      text,
  svc_libelle   text,
  etab          text,
  effectif      int,
  csp_membre    text,
  emploi_resp   text,
  lib_resp      text,
  emploi_membre text,
  lib_membre    text,
  famille       text
);

insert into _plan values
  ( 1,'DAF','Direction Administrative et Financière','COMPTA',   'Comptabilité',                       'SIEGE',  8,'EMP','RESP_COMPTA','Responsable comptable',           'COMPTABLE',    'Comptable',                'Finance'),
  ( 2,'DAF','Direction Administrative et Financière','CONTROLE', 'Contrôle de gestion',                'SIEGE',  5,'CAD','RESP_CDG',   'Responsable contrôle de gestion', 'CDG',          'Contrôleur de gestion',    'Finance'),
  ( 3,'DRH','Direction des Ressources Humaines',     'PAIE',     'Paie et ADP','SIEGE',  6,'EMP','RESP_PAIE',  'Responsable paie et ADP',         'GEST_PAIE',    'Gestionnaire de paie',     'Ressources humaines'),
  ( 4,'DRH','Direction des Ressources Humaines',     'DEVRH',    'Développement RH',                   'SIEGE',  5,'CAD','RESP_DEVRH', 'Responsable développement RH',    'CHARGE_RH',    'Chargé de développement RH','Ressources humaines'),
  ( 5,'DSI','Direction des Systèmes d''Information', 'ETUDES',   'Études et développement',            'SIEGE', 22,'CAD','RESP_ETUDES','Responsable études',              'DEV',          'Développeur',              'Informatique'),
  ( 6,'DSI','Direction des Systèmes d''Information', 'PROD',     'Production et support',              'SIEGE', 14,'TAM','RESP_PROD',  'Responsable production',          'TECH_SUP',     'Technicien support',       'Informatique'),
  ( 7,'DCO','Direction Commerciale',                 'VENTESIDF','Ventes Île-de-France',               'SIEGE', 24,'EMP','RESP_VIDF',  'Directeur régional des ventes',   'COMMERCIAL',   'Commercial',               'Commerce'),
  ( 8,'DCO','Direction Commerciale',                 'VENTESRA', 'Ventes Rhône-Alpes',                 'LYON',  16,'EMP','RESP_VRA',   'Directeur régional des ventes',   'COMMERCIAL_RA','Commercial',               'Commerce'),
  ( 9,'DCO','Direction Commerciale',                 'MKT',      'Marketing',                          'SIEGE',  9,'CAD','RESP_MKT',   'Responsable marketing',           'CHARGE_MKT',   'Chargé de marketing',      'Commerce'),
  (10,'DOP','Direction des Opérations',              'ATELIER',  'Atelier',                            'NANTES',33,'OUV','RESP_ATEL',  'Responsable d''atelier',          'OPERATEUR',    'Opérateur de production',  'Production'),
  (11,'DOP','Direction des Opérations',              'LOGIS',    'Logistique',                         'NANTES',18,'OUV','RESP_LOG',   'Responsable logistique',          'PREPARATEUR',  'Préparateur de commandes', 'Production'),
  (12,'DOP','Direction des Opérations',              'QUALITE',  'Qualité',                            'NANTES',10,'TAM','RESP_QUAL',  'Responsable qualité',             'TECH_QUAL',    'Technicien qualité',       'Production'),
  (13,'DOP','Direction des Opérations',              'METHODES', 'Méthodes',                           'NANTES',  4,'TAM','RESP_METH', 'Responsable méthodes',            'TECH_METH',    'Technicien méthodes',      'Production');
-- Effectifs : 8+5+6+5+22+14+24+16+9+33+18+10+4 = 174, plus 1 DG et 5 directeurs = 180.


-- -----------------------------------------------------------------------------
-- 3. Génération de l'effectif présent
-- -----------------------------------------------------------------------------

do $seed$
declare
  -- Les index sont tirés par arithmétique modulaire sur des nombres premiers :
  -- c'est ce qui rend le résultat varié ET reproductible.
  prenoms_h text[] := array[
    'Julien','Thomas','Nicolas','Sébastien','Alexandre','Mathieu','Antoine','Guillaume',
    'Vincent','Romain','Maxime','Olivier','Christophe','Laurent','Pierre','Damien',
    'Fabien','Cédric','Benoît','Étienne','Hugo','Théo','Lucas','Nathan',
    'Karim','Mehdi','Samuel','Adrien','Xavier','Grégory','Yann','Bastien'];
  prenoms_f text[] := array[
    'Camille','Julie','Aurélie','Sophie','Marion','Émilie','Claire','Céline',
    'Laura','Manon','Élodie','Sarah','Amandine','Charlotte','Pauline','Léa',
    'Anaïs','Justine','Mathilde','Clémence','Nadia','Inès','Lucie','Hélène',
    'Delphine','Sandrine','Virginie','Fanny','Océane','Margaux','Alice','Noémie'];
  noms text[] := array[
    'Martin','Bernard','Dubois','Thomas','Robert','Richard','Petit','Durand',
    'Leroy','Moreau','Simon','Laurent','Lefèvre','Michel','Garcia','David',
    'Bertrand','Roux','Vincent','Fournier','Morel','Girard','André','Lefebvre',
    'Mercier','Dupont','Lambert','Bonnet','François','Martinez','Legrand','Garnier',
    'Faure','Rousseau','Blanc','Guérin','Muller','Henry','Roussel','Nicolas',
    'Perrin','Morin','Mathieu','Clément','Gauthier','Dumont','Lopez','Fontaine',
    'Chevalier','Robin','Masson','Sanchez','Gérard','Nguyen','Boyer','Denis',
    'Lemaire','Duval','Joly','Gautier'];
  villes text[] := array[
    'Paris','Boulogne-Billancourt','Montreuil','Créteil','Versailles','Nanterre',
    'Lyon','Villeurbanne','Vénissieux','Nantes','Saint-Herblain','Rezé'];

  d record;   -- direction
  s record;   -- service

  id_siege     bigint;
  id_etab      bigint;
  id_dg        bigint;
  id_dir       bigint;
  id_unite_dg  bigint;
  id_unite_dir bigint;
  id_unite_svc bigint;
  id_resp      bigint;
  id_pers      bigint;
  id_emploi_r  bigint;
  id_emploi_m  bigint;
  id_poste     bigint;
  id_contrat   bigint;

  n            int := 0;   -- compteur global : alimente matricule et variations
  k            int;
  est_femme    boolean;
  v_prenom     text;
  v_nom        text;
  v_login      text;
  v_naiss      date;
  v_entree     date;
  v_type       text;
  v_motif_cdd  text;
  v_fin_prevue date;
  v_etp        numeric(4,2);
  v_csp        text;
  v_salaire    numeric(10,2);
  v_anc        int;
begin

  select id into id_siege from etablissements where code = 'SIEGE';

  -- ---- Direction générale ---------------------------------------------------

  insert into unites_organisationnelles (code, libelle, type_unite, parent_id, etablissement_id)
  values ('DG', 'Direction générale', 'direction', null, id_siege)
  returning id into id_unite_dg;

  insert into emplois (code, libelle, famille_metier, csp_code) values
    ('DG',  'Directeur général', 'Direction', 'CAD'),
    ('DIR', 'Directeur',         'Direction', 'CAD');

  n := 1;
  insert into personnes (matricule, civilite_code, nom, prenom, date_naissance,
                         email_perso, email_pro, telephone, ville, code_postal)
  values ('M00001', 'M', 'Delaunay', 'Bertrand', date '1966-04-12',
          'b.delaunay@orange.fr', 'b.delaunay@meridien.fr',
          '0612000001', 'Versailles', '78000')
  returning id into id_dg;

  insert into contrats (personne_id, etablissement_id, numero, type_contrat_code,
                        date_debut, fin_periode_essai)
  values (id_dg, id_siege, 'C00001', 'CDI', date '1998-03-02', date '1998-09-02')
  returning id into id_contrat;

  perform _seed_carriere(id_contrat, date '1998-03-02', current_date,
                         11500.00, 1.00, 'CAD', 'Cadre dirigeant', 500, 1);

  select id into id_emploi_r from emplois where code = 'DG';
  insert into postes (code, libelle, emploi_id, unite_id, etp_budgete)
  values ('P00001', 'Directeur général', id_emploi_r, id_unite_dg, 1.00)
  returning id into id_poste;

  insert into affectations (personne_id, poste_id, unite_id, manager_personne_id, date_debut)
  values (id_dg, id_poste, id_unite_dg, null, date '1998-03-02');

  update unites_organisationnelles set responsable_personne_id = id_dg where id = id_unite_dg;

  -- ---- Directions -----------------------------------------------------------

  for d in (select dir_code, min(dir_libelle) as dir_libelle, min(ordre) as ordre
            from _plan group by dir_code order by min(ordre)) loop

    insert into unites_organisationnelles (code, libelle, type_unite, parent_id, etablissement_id)
    values (d.dir_code, d.dir_libelle, 'direction', id_unite_dg, id_siege)
    returning id into id_unite_dir;

    n         := n + 1;
    est_femme := (n % 2 = 0);
    v_prenom  := case when est_femme
                      then prenoms_f[1 + (n * 13) % array_length(prenoms_f, 1)]
                      else prenoms_h[1 + (n * 13) % array_length(prenoms_h, 1)] end;
    v_nom     := noms[1 + (n * 29) % array_length(noms, 1)];
    v_login   := lower(sans_accent(left(v_prenom, 1) || '.' || v_nom));
    v_naiss   := date '1963-01-01' + ((n * 137) % 3650);
    v_entree  := date '2001-01-01' + ((n * 271) % 5100);
    v_anc     := extract(year from age(current_date, v_entree))::int;

    insert into personnes (matricule, civilite_code, nom, prenom, date_naissance,
                           email_perso, email_pro, telephone, ville, code_postal)
    values ('M' || lpad(n::text, 5, '0'),
            case when est_femme then 'MME' else 'M' end,
            v_nom, v_prenom, v_naiss,
            v_login || '@free.fr', v_login || '@meridien.fr',
            '06' || lpad(((n * 7919) % 100000000)::text, 8, '0'),
            villes[1 + (n * 7) % array_length(villes, 1)], '75011')
    returning id into id_dir;

    insert into contrats (personne_id, etablissement_id, numero, type_contrat_code,
                          date_debut, fin_periode_essai)
    values (id_dir, id_siege, 'C' || lpad(n::text, 5, '0'), 'CDI',
            v_entree, v_entree + 120)
    returning id into id_contrat;

    perform _seed_carriere(id_contrat, v_entree, current_date,
                           6800 + v_anc * 110 + (n % 7) * 60,
                           1.00, 'CAD', 'Cadre position 3', 400, n);

    select id into id_emploi_r from emplois where code = 'DIR';
    insert into postes (code, libelle, emploi_id, unite_id, etp_budgete)
    values ('P' || lpad(n::text, 5, '0'), d.dir_libelle, id_emploi_r, id_unite_dir, 1.00)
    returning id into id_poste;

    insert into affectations (personne_id, poste_id, unite_id, manager_personne_id, date_debut)
    values (id_dir, id_poste, id_unite_dir, id_dg, v_entree);

    update unites_organisationnelles set responsable_personne_id = id_dir where id = id_unite_dir;

    -- ---- Services de cette direction ----------------------------------------

    for s in (select * from _plan where dir_code = d.dir_code order by ordre) loop

      select id into id_etab from etablissements where code = s.etab;

      insert into unites_organisationnelles (code, libelle, type_unite, parent_id, etablissement_id)
      values (s.svc_code, s.svc_libelle, 'service', id_unite_dir, id_etab)
      returning id into id_unite_svc;

      insert into emplois (code, libelle, famille_metier, csp_code) values
        (s.emploi_resp,   s.lib_resp,   s.famille, 'CAD'),
        (s.emploi_membre, s.lib_membre, s.famille, s.csp_membre);
      select id into id_emploi_r from emplois where code = s.emploi_resp;
      select id into id_emploi_m from emplois where code = s.emploi_membre;

      id_resp := null;

      for k in 1 .. s.effectif loop
        n         := n + 1;
        est_femme := ((n * 5) % 9 < 4);
        v_prenom  := case when est_femme
                          then prenoms_f[1 + (n * 13) % array_length(prenoms_f, 1)]
                          else prenoms_h[1 + (n * 13) % array_length(prenoms_h, 1)] end;
        v_nom     := noms[1 + (n * 29) % array_length(noms, 1)];
        v_login   := lower(sans_accent(left(v_prenom, 1) || '.' || v_nom));
        v_naiss   := date '1962-01-01' + ((n * 149) % 14600);   -- 1962 → 2001
        v_entree  := current_date - ((n * 311) % 5200);         -- 0 → ~14 ans

        -- Un salarié ne peut pas être entré avant ses 18 ans.
        if v_entree < (v_naiss + interval '18 years')::date then
          v_entree := (v_naiss + interval '18 years')::date + (n % 400);
        end if;
        if v_entree >= current_date then
          v_entree := current_date - ((n % 900) + 30);
        end if;

        -- Nature du contrat : ~85 % de CDI, le reste en CDD, alternance, stage.
        v_type       := 'CDI';
        v_motif_cdd  := null;
        v_fin_prevue := null;

        if k > 1 and n % 19 = 0 then
          v_type       := 'APP';
          v_entree     := current_date - ((n % 400) + 60);
          v_fin_prevue := v_entree + 730;
        elsif k > 1 and n % 17 = 3 then
          v_type       := 'CDD';
          v_motif_cdd  := (array['REMPL','ACCROI','SAISON'])[1 + n % 3];
          v_entree     := current_date - ((n % 300) + 45);
          v_fin_prevue := v_entree + 180 + (n % 180);
        elsif k > 1 and n % 29 = 5 then
          v_type       := 'STAGE';
          v_entree     := current_date - ((n % 110) + 20);
          v_fin_prevue := v_entree + 130;
        end if;

        -- Temps partiel : environ 12 % de l'effectif.
        v_etp := case
                   when v_type in ('APP', 'STAGE') then 1.00
                   when n % 11 = 4 then 0.80
                   when n % 23 = 7 then 0.50
                   else 1.00
                 end;

        -- Le premier salarié de chaque service en est le responsable.
        v_csp := case
                   when k = 1                        then 'CAD'
                   when v_type in ('APP', 'STAGE')   then 'EMP'
                   when n % 8  = 0 and s.csp_membre = 'OUV' then 'TAM'
                   when n % 9  = 0 and s.csp_membre = 'EMP' then 'TAM'
                   when n % 12 = 0 and s.csp_membre = 'TAM' then 'CAD'
                   else s.csp_membre
                 end;

        v_anc     := extract(year from age(current_date, v_entree))::int;
        v_salaire := round((
            case v_csp when 'OUV' then 1950 + v_anc * 28
                       when 'EMP' then 2150 + v_anc * 35
                       when 'TAM' then 2900 + v_anc * 55
                       else            4300 + v_anc * 105 end
            + (n % 7) * 45
          ) * case v_type when 'STAGE' then 0.25 when 'APP' then 0.55 else 1 end
            * v_etp, 2);

        insert into personnes (matricule, civilite_code, nom, prenom, date_naissance,
                               email_perso, email_pro, telephone, ville, code_postal)
        values ('M' || lpad(n::text, 5, '0'),
                case when est_femme then 'MME' else 'M' end,
                v_nom, v_prenom, v_naiss,
                v_login || n || '@laposte.net',
                v_login || case when n % 3 = 0 then n::text else '' end || '@meridien.fr',
                '06' || lpad(((n * 7919) % 100000000)::text, 8, '0'),
                villes[1 + (n * 7) % array_length(villes, 1)],
                lpad((75000 + (n * 13) % 900)::text, 5, '0'))
        returning id into id_pers;

        insert into contrats (personne_id, etablissement_id, numero, type_contrat_code,
                              date_debut, date_fin_prevue, fin_periode_essai, motif_cdd_code)
        values (id_pers, id_etab, 'C' || lpad(n::text, 5, '0'), v_type,
                v_entree, v_fin_prevue,
                case when v_type = 'CDI' then v_entree + 90 end,
                v_motif_cdd)
        returning id into id_contrat;

        perform _seed_carriere(id_contrat, v_entree, current_date, v_salaire, v_etp, v_csp,
                case v_csp when 'CAD' then 'Cadre position 2'
                           when 'TAM' then 'Agent de maîtrise niveau 4'
                           when 'EMP' then 'Employé niveau 3'
                           else            'Ouvrier niveau 2' end,
                150 + (n % 12) * 15, n);

        if k = 1 then
          id_resp := id_pers;
          insert into postes (code, libelle, emploi_id, unite_id, etp_budgete)
          values ('P' || lpad(n::text, 5, '0'), s.lib_resp, id_emploi_r, id_unite_svc, 1.00)
          returning id into id_poste;

          insert into affectations (personne_id, poste_id, unite_id, manager_personne_id, date_debut)
          values (id_pers, id_poste, id_unite_svc, id_dir, v_entree);

          update unites_organisationnelles
             set responsable_personne_id = id_pers
           where id = id_unite_svc;
        else
          insert into postes (code, libelle, emploi_id, unite_id, etp_budgete)
          values ('P' || lpad(n::text, 5, '0'), s.lib_membre, id_emploi_m, id_unite_svc, v_etp)
          returning id into id_poste;

          insert into affectations (personne_id, poste_id, unite_id, manager_personne_id,
                                    date_debut, taux_affectation)
          values (id_pers, id_poste, id_unite_svc, id_resp, v_entree, v_etp);
        end if;
      end loop;

      -- Un poste vacant par service : le crochet naturel du module Recrutement.
      insert into postes (code, libelle, emploi_id, unite_id, etp_budgete, ouvert)
      values ('PV_' || s.svc_code, s.lib_membre || ' (poste vacant)',
              id_emploi_m, id_unite_svc, 1.00, true);
    end loop;
  end loop;

  raise notice 'Effectif présent généré : % personnes', n;
end;
$seed$;


-- -----------------------------------------------------------------------------
-- 4. Anciens salariés
--
-- 32 sorties étalées sur 34 mois. Sans elles, v_mouvements serait vide et le
-- turnover incalculable : c'est ce qui JUSTIFIE l'historisation du modèle.
-- -----------------------------------------------------------------------------

do $sorties$
declare
  prenoms text[] := array[
    'Frédéric','Isabelle','Patrick','Nathalie','Philippe','Valérie','Éric','Corinne',
    'Stéphane','Karine','Franck','Sylvie','Bruno','Catherine','Gilles','Martine'];
  noms text[] := array[
    'Colin','Brun','Renaud','Maillard','Barbier','Rey','Leclerc','Noël',
    'Berger','Menard','Fabre','Aubert','Charpentier','Bourgeois','Perez','Meyer'];
  motifs text[] := array['DEM','RC','FIN_CDD','LIC_PER','RETR','FIN_ALT','FIN_ESS','DEM'];

  s          record;
  i          int;
  n          int;
  id_pers    bigint;
  id_poste   bigint;
  id_etab    bigint;
  id_contrat bigint;
  v_entree   date;
  v_sortie   date;
  v_type     text;
  v_motif    text;
  v_login    text;
begin
  for i in 1 .. 32 loop
    n := 900 + i;

    -- On répartit les sorties sur les services, dans l'ordre du plan.
    select u.id as unite_id, u.etablissement_id, p.id as poste_id
      into s
      from unites_organisationnelles u
      join postes p on p.unite_id = u.id and p.code like 'PV\_%'
     where u.type_unite = 'service'
     order by u.id
    offset (i - 1) % 13 limit 1;

    -- Étalement sur 34 mois : (i * 13) % 34 parcourt bien toute la plage.
    v_sortie := (date_trunc('month', current_date) - ((i * 13) % 34 || ' months')::interval)::date
                + ((i * 7) % 27);
    if v_sortie >= current_date then
      v_sortie := current_date - ((i * 11) % 300 + 10);
    end if;

    v_type   := case when i % 5 = 0 then 'CDD' else 'CDI' end;
    v_motif  := case when v_type = 'CDD' then 'FIN_CDD' else motifs[1 + i % 8] end;
    if v_motif = 'FIN_CDD' and v_type = 'CDI' then v_motif := 'DEM'; end if;
    v_entree := v_sortie - (300 + (i * 173) % 3000);

    v_login := lower(sans_accent(left(prenoms[1 + i % 16], 1) || '.' || noms[1 + i % 16]));

    insert into personnes (matricule, civilite_code, nom, prenom, date_naissance,
                           email_perso, email_pro, telephone, ville, code_postal)
    values ('M' || lpad(n::text, 5, '0'),
            case when i % 2 = 0 then 'MME' else 'M' end,
            noms[1 + i % 16], prenoms[1 + i % 16],
            date '1968-01-01' + ((i * 421) % 10500),
            v_login || n || '@laposte.net', v_login || n || '@meridien.fr',
            '06' || lpad(((n * 7919) % 100000000)::text, 8, '0'),
            'Paris', '75015')
    returning id into id_pers;

    insert into contrats (personne_id, etablissement_id, numero, type_contrat_code,
                          date_debut, date_fin_prevue, date_fin_reelle, motif_cdd_code,
                          motif_sortie_code)
    values (id_pers, s.etablissement_id, 'C' || lpad(n::text, 5, '0'), v_type,
            v_entree,
            case when v_type = 'CDD' then v_sortie end,
            v_sortie,
            case when v_type = 'CDD' then 'ACCROI' end,
            v_motif)
    returning id into id_contrat;

    -- Salaire figé à la date de sortie, pas à aujourd'hui.
    perform _seed_carriere(id_contrat, v_entree, v_sortie,
                           2400 + (i % 9) * 120, 1.00,
                           case when i % 4 = 0 then 'CAD' else 'EMP' end,
                           'Employé niveau 3', 180, n);

    insert into affectations (personne_id, poste_id, unite_id, date_debut, date_fin)
    values (id_pers, null, s.unite_id, v_entree, v_sortie);
  end loop;

  raise notice 'Anciens salariés générés : 32';
end;
$sorties$;


-- -----------------------------------------------------------------------------
-- 5. Candidats externes
--
-- Des personnes SANS matricule et SANS contrat : statut « Externe » dans
-- v_personnes. Elles existent pour que le module Recrutement ait de la matière
-- dès son premier sprint.
-- -----------------------------------------------------------------------------

insert into personnes (civilite_code, nom, prenom, date_naissance, email_perso,
                       telephone, ville, code_postal) values
  ('MME','Aubry',     'Céline',   '1994-02-18','celine.aubry@gmail.com',   '0611223301','Paris','75012'),
  ('M',  'Marchand',  'Rémi',     '1989-11-03','remi.marchand@gmail.com',  '0611223302','Lyon','69003'),
  ('MME','Perrot',    'Salomé',   '1998-06-27','salome.perrot@gmail.com',  '0611223303','Nantes','44000'),
  ('M',  'Dufour',    'Malik',    '1992-09-14','malik.dufour@gmail.com',   '0611223304','Montreuil','93100'),
  ('MME','Leclercq',  'Anne-Laure','1985-01-30','al.leclercq@gmail.com',   '0611223305','Versailles','78000'),
  ('M',  'Baron',     'Yohan',    '2000-04-08','yohan.baron@gmail.com',    '0611223306','Rezé','44400'),
  ('MME','Guillaume', 'Farida',   '1991-12-21','farida.guillaume@gmail.com','0611223307','Créteil','94000'),
  ('M',  'Tessier',   'Loïc',     '1987-07-05','loic.tessier@gmail.com',   '0611223308','Villeurbanne','69100'),
  ('MME','Bourdon',   'Jeanne',   '1996-03-11','jeanne.bourdon@gmail.com', '0611223309','Paris','75018'),
  ('M',  'Hamon',     'Gaspard',  '1993-10-02','gaspard.hamon@gmail.com',  '0611223310','Saint-Herblain','44800');


-- -----------------------------------------------------------------------------
-- 6. Les cas tordus — volontaires
--
-- Chacun est un sujet de conception qui fera surface en sprint. Ils sont ciblés
-- par des règles stables (« le 3e salarié du service X par matricule »), donc
-- reproductibles sans dépendre d'un identifiant en dur.
-- -----------------------------------------------------------------------------

-- (a) Parcours en deux contrats : un stage effectué AVANT l'embauche en CDI.
--     Effet attendu : date_entree ≠ date_debut_contrat, et l'ancienneté
--     calculée est supérieure à la durée du contrat en cours.
with cible as (
  select p.id, c.etablissement_id, c.date_debut
  from personnes p
  join contrats c on c.personne_id = p.id
  join affectations a on a.personne_id = p.id
  join unites_organisationnelles u on u.id = a.unite_id
  where u.code = 'ETUDES' and c.type_contrat_code = 'CDI'
  order by p.matricule
  offset 2 limit 1
),
nouveau as (
  insert into contrats (personne_id, etablissement_id, numero, type_contrat_code,
                        date_debut, date_fin_prevue, date_fin_reelle, motif_sortie_code)
  select id, etablissement_id, 'C90001', 'STAGE',
         date_debut - 200, date_debut - 70, date_debut - 70, 'FIN_STG'
  from cible
  returning id, date_debut
)
insert into avenants (contrat_id, numero_ordre, type_avenant_code, date_effet,
                      date_signature, motif, etp, csp_code, classification,
                      coefficient, salaire_base_brut_mensuel)
select id, 1, 'INITIAL', date_debut, date_debut - 15, 'Convention de stage',
       1.00, 'EMP', 'Stagiaire', 100, 620.00
from nouveau;

-- (b) Un CDD qui expire DEMAIN.
--     Effet attendu : présent aujourd'hui, absent demain. C'est le cas qui
--     démontre qu'un effectif est toujours daté.
with cible as (
  select c.id from contrats c
  join affectations a on a.personne_id = c.personne_id
  join unites_organisationnelles u on u.id = a.unite_id
  where u.code = 'LOGIS' and c.type_contrat_code = 'CDD' and c.date_fin_reelle is null
  order by c.numero limit 1
)
update contrats set date_fin_prevue = current_date + 1
where id in (select id from cible);

-- (c) Un manager parti dont l'équipe est restée rattachée à lui.
--     Effet attendu : les salariés du service Qualité ont un manager qui
--     n'apparaît dans aucune liste de salariés présents. Grand classique
--     des reprises de données.
with cible as (
  select c.id, c.personne_id
  from contrats c
  join unites_organisationnelles u on u.responsable_personne_id = c.personne_id
  where u.code = 'QUALITE' and c.date_fin_reelle is null
  limit 1
)
update contrats
   set date_fin_reelle   = current_date - 25,
       motif_sortie_code = 'RC'
where id in (select id from cible);

update affectations
   set date_fin = current_date - 25
where personne_id in (
  select responsable_personne_id from unites_organisationnelles where code = 'QUALITE'
);

-- (d) Un passage à temps partiel à 60 %.
--     Ce n'est pas une correction de donnée : c'est un AVENANT, avec sa date
--     d'effet. Avant cette date, le salarié était à temps plein — et un
--     effectif au 31/12 de l'an dernier doit le compter comme tel.
with cible as (
  select c.id as contrat_id
  from contrats c
  join affectations a on a.personne_id = c.personne_id
  join unites_organisationnelles u on u.id = a.unite_id
  where u.code = 'COMPTA' and c.type_contrat_code = 'CDI' and c.date_fin_reelle is null
  order by c.numero offset 3 limit 1
),
dernier as (
  select a.*
  from avenants a
  join cible k on k.contrat_id = a.contrat_id
  order by a.numero_ordre desc
  limit 1
)
insert into avenants (contrat_id, numero_ordre, type_avenant_code, date_effet,
                      date_signature, motif, etp, csp_code, classification,
                      coefficient, salaire_base_brut_mensuel)
select contrat_id, numero_ordre + 1, 'TEMPS',
       least(greatest(current_date - 400, date_effet + 60), current_date - 1),
       least(greatest(current_date - 400, date_effet + 60), current_date - 1) - 30,
       'Passage à temps partiel à la demande du salarié',
       0.60, csp_code, classification, coefficient,
       round(salaire_base_brut_mensuel * 0.60 / etp, 2)
from dernier;

-- (e) Une unité sans responsable désigné.
update unites_organisationnelles set responsable_personne_id = null where code = 'METHODES';


-- -----------------------------------------------------------------------------
-- 7. Contrôle de cohérence
--
-- À lire après chaque exécution. Ces chiffres sont les valeurs attendues
-- que les étudiants utiliseront pour écrire leurs scripts de recette.
-- -----------------------------------------------------------------------------

select 'Établissements'          as indicateur, count(*)::text as valeur from etablissements
union all select 'Unités',                count(*)::text from unites_organisationnelles
union all select 'Emplois',               count(*)::text from emplois
union all select 'Postes',                count(*)::text from postes
union all select 'Postes vacants',        count(*)::text from postes where code like 'PV\_%'
union all select 'Personnes (total)',     count(*)::text from personnes
union all select 'Salariés présents',     count(*)::text from v_employes_actifs
union all select 'Anciens salariés',      count(*)::text from v_personnes where statut = 'Ancien salarié'
union all select 'Candidats externes',    count(*)::text from v_personnes where statut = 'Externe'
union all select 'Contrats (total)',      count(*)::text from contrats
union all select 'Avenants (total)',      count(*)::text from avenants
union all select 'Dont augmentations',    count(*)::text from avenants where type_avenant_code in ('AUGM','AUGM_GEN')
union all select 'Dont promotions',       count(*)::text from avenants where type_avenant_code = 'PROMO'
union all select 'Avenants par contrat (moy.)', to_char(avg(nb),'FM9.0') from (select count(*) nb from avenants group by contrat_id) z
union all select 'Dont CDI présents',     count(*)::text from v_employes_actifs where type_contrat_code = 'CDI'
union all select 'Dont temps partiels',   count(*)::text from v_employes_actifs where etp < 1
union all select 'ETP total',             to_char(sum(etp), 'FM999999.00') from v_employes_actifs
union all select 'Âge moyen',             to_char(avg(age), 'FM99.0') from v_employes_actifs
union all select 'Ancienneté moyenne (mois)', to_char(avg(anciennete_mois), 'FM999.0') from v_employes_actifs
union all select 'Salariés sans manager', count(*)::text from v_employes_actifs where manager_id is null
union all select 'Mouvements sur 36 mois', (sum(entrees) + sum(sorties))::text from v_mouvements;

-- Le utilitaire de génération n'a plus lieu d'être une fois le seed passé.
drop function if exists _seed_carriere(bigint, date, date, numeric, numeric, text, text, int, int);
