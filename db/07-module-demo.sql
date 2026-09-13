-- =============================================================================
-- SIRH pédagogique — 07 — La table du module de démonstration
--
-- Le module « demo » est l'IMPLÉMENTATION DE RÉFÉRENCE que les groupes
-- recopient : liste, formulaire, création, modification, suppression.
--
-- Sa table est délibérément OUVERTE EN ÉCRITURE À TOUS LES COMPTES, alors
-- qu'une vraie table de module n'est écrite que par son groupe propriétaire.
-- C'est un bac à sable : chacun doit pouvoir l'essayer.
--
-- Ne prenez donc PAS ces politiques pour modèle : pour une vraie table,
-- utilisez creer_politiques_module(). Voir db/06-comptes.md.
-- =============================================================================

drop table if exists demo_taches cascade;

create table demo_taches (
  id          bigint generated always as identity primary key,
  titre       text not null,
  personne_id bigint references personnes(id),
  echeance    date,
  priorite    text not null default 'normale'
              check (priorite in ('basse', 'normale', 'haute')),
  terminee    boolean not null default false,
  commentaire text,
  creee_le    timestamptz not null default now()
);

comment on table demo_taches is
  'Bac à sable du module de démonstration. Écriture ouverte à tous les comptes, '
  'contrairement à une vraie table de module.';

alter table demo_taches enable row level security;

drop policy if exists demo_lecture  on demo_taches;
drop policy if exists demo_ecriture on demo_taches;

create policy demo_lecture  on demo_taches for select to authenticated using (true);
create policy demo_ecriture on demo_taches for all    to authenticated
  using (true) with check (true);

grant select, insert, update, delete on demo_taches to authenticated;
grant usage, select on all sequences in schema public to authenticated;
revoke all on demo_taches from anon;

-- Quelques lignes pour que l'écran ne soit pas vide au premier affichage.
insert into demo_taches (titre, personne_id, echeance, priorite, commentaire)
select 'Vérifier le dossier de ' || v.nom_complet,
       v.personne_id,
       current_date + (n * 4)::int,
       (array['basse', 'normale', 'haute'])[1 + (n % 3)::int],
       'Ligne créée par le script de démonstration'
from (select row_number() over (order by matricule) as n, personne_id, nom_complet
      from v_employes_actifs limit 6) v(n, personne_id, nom_complet);
