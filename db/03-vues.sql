-- =============================================================================
-- SIRH pédagogique — 03 — Vues : le contrat d'interface
--
-- C'EST LA PIÈCE MAÎTRESSE DU DISPOSITIF.
--
-- Le modèle est historisé (contrats et affectations sont datés), parce qu'un
-- vrai SIRH doit savoir où était un salarié au 31/12. Mais si on exposait ce
-- modèle temporel brut à des étudiants non-développeurs, chaque requête
-- générée par une IA serait fausse.
--
-- Ces vues aplatissent l'historique : UNE LIGNE PAR SALARIÉ, état du jour.
-- Les étudiants voient l'historisation en théorie et dans le schéma ;
-- ils codent sur du plat. La complexité reste ici.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Vues techniques intermédiaires — non exposées aux étudiants.
--
-- « Contrat actif » = commencé, non terminé, et dont le terme prévu n'est pas
-- dépassé. Si une personne a plusieurs contrats actifs simultanés, on retient
-- le principal : le plus gros ETP, puis le plus récent.
-- -----------------------------------------------------------------------------

-- « Avenant en vigueur » = le dernier dont la date d'effet est passée.
-- C'est ici, et nulle part ailleurs, que se fait le calcul de l'état courant
-- d'un contrat. Les étudiants ne le voient jamais.
create or replace view v_avenants_actifs as
select distinct on (a.contrat_id) a.*
from avenants a
where a.date_effet <= current_date
order by a.contrat_id, a.date_effet desc, a.numero_ordre desc;


create or replace view v_contrats_actifs as
select distinct on (c.personne_id) c.*
from contrats c
left join v_avenants_actifs av on av.contrat_id = c.id
where c.date_debut <= current_date
  and c.date_fin_reelle is null
  and (c.date_fin_prevue is null or c.date_fin_prevue >= current_date)
order by c.personne_id, av.etp desc nulls last, c.date_debut desc;


create or replace view v_affectations_actives as
select distinct on (a.personne_id) a.*
from affectations a
where a.date_debut <= current_date
  and (a.date_fin is null or a.date_fin >= current_date)
order by a.personne_id, a.date_debut desc;


-- -----------------------------------------------------------------------------
-- v_employes_actifs — LA vue de référence.
--
-- Une ligne par salarié présent aujourd'hui. C'est ce que lit getEmployes().
-- Si un module a besoin d'une donnée du référentiel, elle doit être ICI :
-- c'est une demande d'évolution, pas une jointure côté étudiant.
-- -----------------------------------------------------------------------------

create or replace view v_employes_actifs as
select
  p.id                                  as personne_id,
  p.matricule,
  p.civilite_code,
  p.prenom,
  coalesce(p.nom_usage, p.nom)          as nom,
  p.prenom || ' ' || coalesce(p.nom_usage, p.nom) as nom_complet,
  p.date_naissance,
  extract(year from age(current_date, p.date_naissance))::int as age,
  p.email_pro,
  p.telephone,
  p.ville,

  c.id                                  as contrat_id,
  c.type_contrat_code,
  tc.libelle                            as type_contrat,
  c.date_debut                          as date_debut_contrat,
  c.date_fin_prevue,

  -- Termes issus de l'avenant en vigueur, pas du contrat.
  av.etp,
  av.csp_code,
  csp.libelle                           as csp,
  av.classification,
  av.coefficient,
  av.salaire_base_brut_mensuel,
  av.date_effet                         as date_dernier_avenant,
  (select count(*) from avenants x where x.contrat_id = c.id
     and x.date_effet <= current_date)::int as nb_avenants,
  (select max(x.date_effet) from avenants x where x.contrat_id = c.id
     and x.date_effet <= current_date
     and x.type_avenant_code in ('AUGM', 'AUGM_GEN', 'PROMO')) as date_derniere_augmentation,

  etb.id                                as etablissement_id,
  etb.nom                               as etablissement,

  u.id                                  as service_id,
  u.libelle                             as service,

  em.id                                 as emploi_id,
  em.libelle                            as emploi,
  em.famille_metier,
  po.id                                 as poste_id,

  a.manager_personne_id                 as manager_id,
  mg.prenom || ' ' || coalesce(mg.nom_usage, mg.nom) as manager,

  ent.date_entree,
  (extract(year  from age(current_date, ent.date_entree)) * 12
 + extract(month from age(current_date, ent.date_entree)))::int as anciennete_mois

from personnes p
join      v_contrats_actifs        c   on c.personne_id      = p.id
join      v_avenants_actifs        av  on av.contrat_id      = c.id
join      ref_type_contrat         tc  on tc.code            = c.type_contrat_code
join      ref_csp                  csp on csp.code           = av.csp_code
join      etablissements           etb on etb.id             = c.etablissement_id
left join v_affectations_actives   a   on a.personne_id      = p.id
left join unites_organisationnelles u  on u.id               = a.unite_id
left join postes                   po  on po.id              = a.poste_id
left join emplois                  em  on em.id              = po.emploi_id
left join personnes                mg  on mg.id              = a.manager_personne_id
join (
  select personne_id, min(date_debut) as date_entree
  from contrats
  group by personne_id
) ent on ent.personne_id = p.id;

comment on view v_employes_actifs is
  'Une ligne par salarié présent aujourd''hui. Vue de référence du Core HR : '
  'tout module qui a besoin d''une donnée salarié la lit ici.';


-- -----------------------------------------------------------------------------
-- v_personnes — toutes les personnes, salariées ou non.
--
-- Destinée au module Recrutement : un candidat existe dans le référentiel
-- avant d'être salarié.
-- -----------------------------------------------------------------------------

create or replace view v_personnes as
select
  p.id                                  as personne_id,
  p.matricule,
  p.civilite_code,
  p.prenom,
  coalesce(p.nom_usage, p.nom)          as nom,
  p.prenom || ' ' || coalesce(p.nom_usage, p.nom) as nom_complet,
  p.date_naissance,
  p.email_perso,
  p.email_pro,
  p.telephone,
  p.ville,
  case
    when exists (select 1 from v_contrats_actifs c where c.personne_id = p.id)
      then 'Salarié'
    when exists (select 1 from contrats c where c.personne_id = p.id)
      then 'Ancien salarié'
    else 'Externe'
  end                                   as statut
from personnes p;

comment on view v_personnes is
  'Toutes les personnes connues, avec leur statut (Salarié / Ancien salarié / '
  'Externe). Un « Externe » est typiquement un candidat.';


-- -----------------------------------------------------------------------------
-- v_effectif_par_service — pour les tableaux de bord.
-- -----------------------------------------------------------------------------

create or replace view v_effectif_par_service as
select
  u.id                                  as service_id,
  u.code,
  u.libelle                             as service,
  u.type_unite,
  etb.nom                               as etablissement,
  count(v.personne_id)::int             as effectif,
  coalesce(sum(v.etp), 0)::numeric(8,2) as etp
from unites_organisationnelles u
join      etablissements     etb on etb.id       = u.etablissement_id
left join v_employes_actifs  v   on v.service_id = u.id
where u.actif
group by u.id, u.code, u.libelle, u.type_unite, etb.nom;


-- -----------------------------------------------------------------------------
-- v_mouvements — entrées et sorties par mois sur 36 mois.
--
-- Base du calcul de turnover. C'est la vue qui JUSTIFIE l'historisation :
-- elle serait impossible sur un modèle « un salarié = une ligne ».
-- -----------------------------------------------------------------------------

create or replace view v_mouvements as
with axe_mois as (
  select generate_series(
           date_trunc('month', current_date) - interval '35 months',
           date_trunc('month', current_date),
           interval '1 month'
         )::date as mois
),
entrees as (
  select personne_id, date_trunc('month', min(date_debut))::date as mois
  from contrats
  group by personne_id
),
sorties as (
  select c.personne_id,
         date_trunc('month', coalesce(c.date_fin_reelle, c.date_fin_prevue))::date as mois
  from contrats c
  where coalesce(c.date_fin_reelle, c.date_fin_prevue) is not null
    and coalesce(c.date_fin_reelle, c.date_fin_prevue) <= current_date
    -- on ne compte comme sortie que si la personne n'a plus aucun contrat actif
    and not exists (select 1 from v_contrats_actifs v where v.personne_id = c.personne_id)
)
select
  m.mois,
  count(distinct e.personne_id)::int as entrees,
  count(distinct s.personne_id)::int as sorties
from axe_mois m
left join entrees e on e.mois = m.mois
left join sorties s on s.mois = m.mois
group by m.mois
order by m.mois;


-- -----------------------------------------------------------------------------
-- v_organigramme — l'arbre organisationnel avec ses effectifs.
-- -----------------------------------------------------------------------------

create or replace view v_organigramme as
select
  u.id                                  as service_id,
  u.code,
  u.libelle                             as service,
  u.type_unite,
  u.parent_id,
  pu.libelle                            as parent,
  etb.nom                               as etablissement,
  u.responsable_personne_id             as responsable_id,
  r.prenom || ' ' || coalesce(r.nom_usage, r.nom) as responsable,
  coalesce(ef.effectif, 0)              as effectif
from unites_organisationnelles u
join      etablissements              etb on etb.id = u.etablissement_id
left join unites_organisationnelles   pu  on pu.id  = u.parent_id
left join personnes                   r   on r.id   = u.responsable_personne_id
left join (
  select service_id, count(*)::int as effectif
  from v_employes_actifs
  where service_id is not null
  group by service_id
) ef on ef.service_id = u.id
where u.actif;


-- -----------------------------------------------------------------------------
-- v_historique_remuneration — la carrière salariale, avenant par avenant.
--
-- Rendue possible par le modèle : un salaire n'est pas une colonne qu'on écrase,
-- c'est une suite d'avenants datés. Cette vue est le matériau du module
-- Évaluation (campagnes d'augmentation) et du module Formation (budget).
-- -----------------------------------------------------------------------------

create or replace view v_historique_remuneration as
select
  c.personne_id,
  p.prenom || ' ' || coalesce(p.nom_usage, p.nom) as nom_complet,
  c.id                                  as contrat_id,
  c.numero                              as contrat,
  a.numero_ordre,
  a.type_avenant_code,
  ta.libelle                            as type_avenant,
  a.date_effet,
  a.motif,
  a.etp,
  a.csp_code,
  a.classification,
  a.coefficient,
  a.salaire_base_brut_mensuel           as salaire,
  lag(a.salaire_base_brut_mensuel) over w as salaire_precedent,
  round(100.0 * (a.salaire_base_brut_mensuel - lag(a.salaire_base_brut_mensuel) over w)
        / nullif(lag(a.salaire_base_brut_mensuel) over w, 0), 2) as evolution_pct
from avenants a
join contrats         c  on c.id  = a.contrat_id
join personnes        p  on p.id  = c.personne_id
join ref_type_avenant ta on ta.code = a.type_avenant_code
window w as (partition by c.id order by a.numero_ordre);
