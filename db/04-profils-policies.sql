-- =============================================================================
-- SIRH pédagogique — 04 — Comptes, rôles et habilitations
--
-- Principe : LE POINT D'APPLICATION DES DROITS, C'EST LA BASE — PAS LE CODE.
--
-- StackBlitz ne permet aucun verrouillage de fichier : rien n'empêche un
-- étudiant d'éditer le dossier d'un autre groupe dans son propre fork. C'est
-- sans conséquence, parce que la base refusera l'écriture. C'est d'ailleurs un
-- excellent sujet de cours : la sécurité applicative ne se joue jamais dans
-- l'interface.
--
-- Règle appliquée ici :
--   Core HR + vues          → lecture pour tout compte connecté, AUCUNE écriture
--   Tables d'un module      → lecture pour tous, écriture pour le groupe propriétaire
--   Non connecté            → rien du tout
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. La table profils : qui appartient à quel groupe
--
-- Le rôle vit dans une TABLE, pas dans le jeton d'authentification. C'est un
-- choix délibéré : l'attribution des groupes se décide en cours, et il suffit
-- de modifier une cellule dans le dashboard Supabase pour qu'elle prenne effet
-- immédiatement, sans reconnexion ni redéploiement.
-- -----------------------------------------------------------------------------

create table if not exists profils (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nom        text not null,
  prenom     text not null,
  module     text not null,
  created_at timestamptz not null default now()
);

comment on table profils is
  'Associe chaque compte étudiant au code de son module (rec, gta, form, eval...). '
  'Le code « corehr » est réservé à l''intervenant.';
comment on column profils.module is
  'Code du groupe. Détermine sur quelles tables le compte peut écrire. '
  'Modifiable à chaud depuis le dashboard.';

alter table profils enable row level security;

drop policy if exists profils_lecture on profils;
create policy profils_lecture on profils
  for select to authenticated using (true);

-- Personne n'écrit dans profils depuis l'application : l'intervenant le fait
-- via le dashboard, qui utilise la clé service_role et contourne la RLS.

grant select on profils to authenticated;
revoke all   on profils from anon;


-- -----------------------------------------------------------------------------
-- 2. mon_module() — le module du compte connecté
--
-- SECURITY DEFINER : la fonction doit pouvoir lire profils quelles que soient
-- les politiques appliquées à l'appelant, sinon les politiques qui l'utilisent
-- tourneraient en rond.
-- -----------------------------------------------------------------------------

create or replace function mon_module()
returns text
language sql
stable
security definer
set search_path = public
as 'select module from public.profils where user_id = auth.uid()';

grant execute on function mon_module() to authenticated;


-- -----------------------------------------------------------------------------
-- 3. Core HR : lecture seule pour tout le monde
--
-- Aucune politique d'écriture n'est créée. Avec la RLS activée, l'absence de
-- politique signifie « interdit » : les étudiants ne peuvent donc pas modifier
-- le référentiel, même par accident d'une IA trop zélée.
--
-- L'intervenant, lui, édite le Core HR via le dashboard Supabase.
-- -----------------------------------------------------------------------------

do $bloc$
declare
  t text;
begin
  foreach t in array array[
    'etablissements', 'personnes', 'unites_organisationnelles',
    'emplois', 'postes', 'contrats', 'avenants', 'affectations',
    'ref_civilite', 'ref_type_contrat', 'ref_motif_cdd',
    'ref_motif_sortie', 'ref_csp', 'ref_type_avenant'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists corehr_lecture on public.%I', t);
    execute format('create policy corehr_lecture on public.%I for select to authenticated using (true)', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('revoke insert, update, delete on public.%I from authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end;
$bloc$;


-- -----------------------------------------------------------------------------
-- 4. Les vues
--
-- Une vue Postgres s'exécute avec les droits de son propriétaire : elle
-- traverse donc la RLS des tables sous-jacentes. C'est exactement l'effet
-- recherché — le GRANT sur la vue devient le seul point de contrôle.
-- -----------------------------------------------------------------------------

do $bloc$
declare
  v text;
begin
  foreach v in array array[
    'v_employes_actifs', 'v_personnes', 'v_effectif_par_service',
    'v_mouvements', 'v_organigramme', 'v_historique_remuneration'
  ] loop
    execute format('grant select on public.%I to authenticated', v);
    execute format('revoke all on public.%I from anon', v);
  end loop;

  -- Vues techniques : hors du contrat d'interface, non exposées.
  foreach v in array array['v_contrats_actifs', 'v_affectations_actives',
                           'v_avenants_actifs'] loop
    execute format('revoke all on public.%I from anon, authenticated', v);
  end loop;
end;
$bloc$;


-- -----------------------------------------------------------------------------
-- 5. Le générateur de politiques de module
--
-- À appeler à CHAQUE livraison d'une demande d'évolution, juste après le
-- create table. Exemple :
--
--     create table rec_offres ( ... );
--     select creer_politiques_module('rec_offres', 'rec');
--
-- Deux politiques sont posées :
--   lecture_tous   → tout compte connecté peut LIRE la table.
--                    C'est ce qui rend l'intégration inter-modules possible :
--                    le groupe Formation peut afficher les entretiens du
--                    groupe Évaluation.
--   ecriture_module → seul le groupe propriétaire peut écrire.
-- -----------------------------------------------------------------------------

create or replace function creer_politiques_module(p_table text, p_module text)
returns void
language plpgsql
security definer
set search_path = public
as $func$
begin
  if p_table !~ ('^' || p_module || '_') then
    raise exception
      'La table % ne respecte pas le préfixe du module « % ». Attendu : %_...',
      p_table, p_module, p_module;
  end if;

  execute format('alter table public.%I enable row level security', p_table);
  execute format('drop policy if exists lecture_tous    on public.%I', p_table);
  execute format('drop policy if exists ecriture_module on public.%I', p_table);

  execute format(
    'create policy lecture_tous on public.%I for select to authenticated using (true)',
    p_table);

  execute format(
    'create policy ecriture_module on public.%I for all to authenticated '
    'using (public.mon_module() = %L) with check (public.mon_module() = %L)',
    p_table, p_module, p_module);

  execute format('grant select, insert, update, delete on public.%I to authenticated', p_table);
  execute format('grant usage, select on all sequences in schema public to authenticated');
  execute format('revoke all on public.%I from anon', p_table);
end;
$func$;

comment on function creer_politiques_module(text, text) is
  'Pose les deux politiques standard sur une table de module. '
  'Refuse une table dont le nom ne commence pas par le préfixe du module.';


-- -----------------------------------------------------------------------------
-- 6. Contrôle : qui a le droit de quoi
--
-- À exécuter pour vérifier l'état des habilitations à tout moment.
-- -----------------------------------------------------------------------------

create or replace view v_controle_habilitations as
select
  c.relname                          as table_ou_vue,
  case c.relkind when 'r' then 'table' when 'v' then 'vue' end as type,
  c.relrowsecurity                   as rls_active,
  coalesce(
    (select string_agg(pol.polname, ', ' order by pol.polname)
     from pg_policy pol where pol.polrelid = c.oid),
    '— aucune —'
  )                                  as politiques
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'v')
order by type, c.relname;

grant select on v_controle_habilitations to authenticated;
