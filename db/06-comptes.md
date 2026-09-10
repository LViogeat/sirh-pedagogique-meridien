# Création des comptes et attribution des groupes

*SIRH pédagogique — procédure pour l'intervenant*

## Ce qu'il faut avoir sous la main

Dans **Project Settings → API** de votre projet Supabase :

| | |
|---|---|
| **Project URL** | `https://xxxx.supabase.co` — à distribuer aux étudiants |
| **anon public** | clé publique — à distribuer aux étudiants |
| **service_role** | clé d'administration — **ne jamais la distribuer, ni la mettre dans le code** |

La clé `anon` est publique par nature : elle vit dans le navigateur. Ce sont les politiques RLS qui protègent les données, pas le secret de cette clé. C'est un bon moment de cours.

---

## 1. Régler l'authentification avant de créer quoi que ce soit

Dans **Authentication → Providers → Email** :

- ✅ Email activé
- ❌ **« Confirm email » désactivé** — sinon chaque étudiant devra cliquer sur un lien reçu par mail avant de pouvoir se connecter, et vous perdrez vingt minutes le jour J
- ❌ **« Enable signups » désactivé** — personne ne doit pouvoir créer son propre compte

---

## 2. Créer les comptes

### Option A — par le dashboard *(simple, ~10 minutes pour 30 étudiants)*

**Authentication → Users → Add user** : e-mail, mot de passe, et cocher **Auto Confirm User**.

### Option B — par l'API d'administration *(rapide et rejouable)*

Préparez un fichier `etudiants.csv` :

```csv
email,nom,prenom
lea.dupont@etu.univ-paris1.fr,Dupont,Léa
paul.nguyen@etu.univ-paris1.fr,Nguyen,Paul
```

Puis :

```bash
URL="https://xxxx.supabase.co"
SERVICE_KEY="eyJ..."          # service_role — ne jamais la committer
MDP="Sorbonne2026!"           # mot de passe commun, changé au premier cours

tail -n +2 etudiants.csv | while IFS=, read -r email nom prenom; do
  curl -s -X POST "$URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$MDP\",\"email_confirm\":true}" \
    | grep -o '"id":"[^"]*"' | head -1
  echo "  → $prenom $nom"
done
```

Un mot de passe commun est acceptable ici : les données sont fictives et le compte ne donne accès qu'à ce projet. Dites-le explicitement en cours, c'est encore un sujet d'habilitations.

---

## 3. Rattacher chaque compte à son groupe

**À faire en cours**, une fois les groupes constitués. C'est le seul geste qui donne des droits.

```sql
-- Le module vaut le code du groupe : rec, gta, form, eval…
-- Réservez 'corehr' à votre propre compte.
insert into profils (user_id, nom, prenom, module)
select id, 'Dupont', 'Léa', 'rec' from auth.users where email = 'lea.dupont@etu.univ-paris1.fr'
on conflict (user_id) do update set module = excluded.module;
```

Pour rattacher tout un groupe d'un coup :

```sql
insert into profils (user_id, nom, prenom, module)
select u.id,
       split_part(split_part(u.email, '@', 1), '.', 2),
       split_part(split_part(u.email, '@', 1), '.', 1),
       'gta'
from auth.users u
where u.email in (
  'paul.nguyen@etu.univ-paris1.fr',
  'sofia.mercier@etu.univ-paris1.fr'
)
on conflict (user_id) do update set module = excluded.module;
```

### Changer un étudiant de groupe

Une seule cellule, effet **immédiat** — ni reconnexion, ni redéploiement :

```sql
update profils set module = 'form' where prenom = 'Léa' and nom = 'Dupont';
```

C'est précisément pourquoi le rôle vit dans une table plutôt que dans le jeton d'authentification.

### Vérifier la répartition

```sql
select module, count(*) as etudiants,
       string_agg(prenom || ' ' || nom, ', ' order by nom) as membres
from profils group by module order by module;
```

---

## 4. Livrer une table à un groupe

À chaque demande d'évolution honorée, deux instructions :

```sql
create table rec_offres (
  id       bigint generated always as identity primary key,
  intitule text not null,
  poste_id bigint references postes(id),
  statut   text not null default 'brouillon',
  creee_le timestamptz not null default now()
);

select creer_politiques_module('rec_offres', 'rec');
```

La seconde pose les deux politiques standard — lecture pour tous, écriture pour le seul groupe `rec` — et **refuse** une table dont le nom ne commence pas par le préfixe du module. C'est un garde-fou contre l'erreur de copier-coller à 17h.

---

## 5. Contrôler l'état des habilitations

```sql
select * from v_controle_habilitations;
```

Ce que vous devez voir :

| | |
|---|---|
| Tables Core HR | RLS active, politique `corehr_lecture` **seule** — donc aucune écriture possible |
| Tables de module | RLS active, `lecture_tous` **et** `ecriture_module` |
| `profils` | RLS active, `profils_lecture` seule |

Une table de module sans politique est **inaccessible** aux étudiants : c'est le symptôme d'un `creer_politiques_module` oublié.

---

## Rituel avant chaque session

1. **Vérifier que le projet est éveillé.** Un projet gratuit se met en pause après 7 jours sans appel API. Il reste restaurable 90 jours, donc un intervalle d'un mois passe — mais il faut le réveiller. Le plus sûr est un ping automatique (cron-job.org ou GitHub Actions) tous les 3 jours sur `"$URL/rest/v1/"` avec la clé `anon`.
2. **Restaurer le dernier `pg_dump` sur un projet de test.** Une sauvegarde jamais restaurée n'est pas une sauvegarde — et l'offre gratuite ne conserve **aucun** backup de son côté.
3. **Livrer les évolutions de schéma** demandées le mois précédent.
4. **Vérifier la répartition des groupes** dans `profils`.

## Rituel après chaque session

```bash
pg_dump "postgresql://postgres:MDP@db.xxxx.supabase.co:5432/postgres" \
        --no-owner --no-privileges -f "meridien_$(date +%Y%m%d).sql"
```

Déposé dans SharePoint, avec les dossiers `src/modules/<code>/` collectés dans Teams.
