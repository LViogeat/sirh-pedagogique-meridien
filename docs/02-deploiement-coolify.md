# Déploiement sur Coolify

*Tout tourne sur un VPS unique. Trois briques à créer, puis six instances de
code-server.*

## Ce qu'on déploie

| Service | Rôle | Sous-domaine |
|---|---|---|
| PostgreSQL | la base, partagée par tout le monde | interne, pas exposé |
| `api` | le socle : lecture, besoins, SQL des groupes | `sirh-api.exemple.fr` |
| `code-server` ×6 | l'atelier de chaque groupe | `rec.exemple.fr`, `form.exemple.fr`… |

Le front des groupes tourne dans leur code-server, sur un sous-domaine
différent de celui de l'API. C'est pour cela que le CORS doit être ouvert.

---

## 1. PostgreSQL

Créer une ressource **PostgreSQL 17** dans le projet Coolify. Noter le nom
d'utilisateur, le mot de passe et le nom de la base.

> ⚠️ **Le compte doit avoir l'attribut `CREATEROLE`.** C'est lui qui crée les
> six rôles et les six schémas de groupe au démarrage. Le compte créé par
> défaut par Coolify est propriétaire de la base et convient. En cas de doute :
>
> ```sql
> alter role sirh createrole;
> ```
>
> Sans cela, l'API démarre et sert le socle en lecture, mais journalise une
> erreur et l'endpoint `/sql` ne fonctionne pas.

---

## 2. L'API

**Source** : ce dépôt · **Build pack** : Dockerfile · **Base directory** :
`/api` · **Port** : `8000`

**Variables d'environnement** — voir [`.env.example`](../.env.example) :

```
DATABASE_URL=postgresql+psycopg://sirh:MOTDEPASSE@HOTE:5432/sirh
DATE_REFERENCE=2026-09-15
GROUPES=rec:Recrutement:JETON1:recrutement,form:Formation:JETON2:formation,mob:Mobilité & carrière:JETON3:mobilite,gta:Gestion des temps:JETON4,portail:Portail RH & Self-Service:JETON5,onb:Onboarding & Offboarding:JETON6
JETON_ADMIN=UN-JETON-QUE-VOUS-GARDEZ
ORIGINES_AUTORISEES=*
```

> `DATABASE_URL` doit porter le pilote `+psycopg`. Coolify fournit une URL en
> `postgres://` ou `postgresql://` : ajoutez `+psycopg` après `postgresql`.

> Le format de `GROUPES` est `code:Libellé:jeton[:type_besoin]`. Le quatrième
> champ dit quel type de besoin identifié le module a le droit de prendre en
> charge. Trois modules seulement en consomment ; les trois autres n'ont pas ce
> champ, et l'API leur refusera toute écriture sur les besoins.

**Health check** : `GET /` — c'est le seul endpoint sans jeton.

**Domaine** : `https://sirh-api.exemple.fr`, avec le certificat géré par
Coolify.

Au premier démarrage, l'API crée les tables, prépare les six schémas de groupe
et charge le jeu de démonstration. Vérifier dans les journaux :

```
INFO socle.bootstrap — Schémas de groupe prêts : rec, form, mob, gta, portail, onb
INFO socle — Chargé : {'etablissements': 5, …}
INFO socle — Besoins générés : {'crees': 178, …}
```

Puis, depuis un navigateur : `https://sirh-api.exemple.fr/docs`.

---

## 3. Les jetons

Six jetons de groupe, un jeton intervenant. Ils ne protègent rien — les données
sont fictives — mais ils identifient l'appelant et empêchent un groupe
d'écrire chez un autre.

Les engendrer :

```bash
for g in rec form mob gta portail onb admin; do
  echo "$g: $(openssl rand -hex 12)"
done
```

Reporter les six premiers dans `GROUPES`, le dernier dans `JETON_ADMIN`.
**Le jeton intervenant ne se distribue pas** : il ouvre `/admin`.

Ajouter un septième groupe consiste à ajouter une entrée dans `GROUPES` et à
redémarrer le service : le schéma, le rôle et les droits sont créés tout seuls.

---

## 4. Le CORS

Le front d'un groupe tourne sur `rec.exemple.fr` et appelle
`sirh-api.exemple.fr`. Sans autorisation explicite, le navigateur bloque tous
les appels, avec un message que les étudiants ne sauront pas interpréter.

`ORIGINES_AUTORISEES=*` convient au cours. Pour restreindre :

```
ORIGINES_AUTORISEES=https://rec.exemple.fr,https://form.exemple.fr,https://mob.exemple.fr,https://gta.exemple.fr,https://portail.exemple.fr,https://onb.exemple.fr
```

Attention : une instance de code-server sert souvent l'aperçu Vite sur un port
ou un sous-domaine dérivé. Si un groupe voit une erreur CORS, le plus simple
est de repasser à `*` — il n'y a rien à protéger.

---

## 5. Les six instances de code-server

Une ressource Docker par groupe, image
`lscr.io/linuxserver/code-server:latest`, avec :

| Variable | Valeur |
|---|---|
| `PASSWORD` | un mot de passe par groupe |
| `DEFAULT_WORKSPACE` | `/config/workspace/sirh` |

Volume persistant sur `/config`, domaine `rec.exemple.fr`, port `8443`.

Dans chaque instance, une fois ouverte :

```bash
git clone <url-du-depot> ~/sirh
cd ~/sirh/app
cat > .env <<'FIN'
VITE_API_URL=https://sirh-api.exemple.fr
VITE_API_TOKEN=LE-JETON-DE-CE-GROUPE
VITE_MODULE_CODE=rec
FIN
npm install
```

Le groupe lance ensuite `npm run dev` et travaille. Ces trois lignes de `.env`
sont la seule chose qui distingue une instance d'une autre.

`VITE_MODULE_CODE` décide de tout côté application : c'est lui qui ouvre un
module et ferme les cinq autres. `VITE_API_TOKEN` décide de tout côté serveur :
le schéma PostgreSQL accessible en écriture, et le type de besoin que le groupe
peut prendre en charge. **Les deux doivent désigner le même groupe.**

> Node est nécessaire dans l'image. Si l'image de base ne le fournit pas, le
> plus simple est de construire une image dérivée :
>
> ```dockerfile
> FROM lscr.io/linuxserver/code-server:latest
> RUN apt-get update && apt-get install -y nodejs npm git && rm -rf /var/lib/apt/lists/*
> ```

---

## 6. Tenir le cours

```bash
# Remise à zéro des données du socle, entre deux sprints.
# Les schémas des groupes ne sont PAS touchés.
curl -X POST https://sirh-api.exemple.fr/admin/reset \
     -H "Authorization: Bearer $JETON_ADMIN"

# Rejouer les règles après avoir ajusté un seuil dans rules/seuils.py.
# Les besoins pris en charge par un groupe ne bougent pas.
curl -X POST https://sirh-api.exemple.fr/admin/besoins/generer \
     -H "Authorization: Bearer $JETON_ADMIN"

# Repartir propre sur le schéma d'un groupe.
# Il recrée ensuite ses tables depuis la console SQL.
curl -X POST https://sirh-api.exemple.fr/admin/modules/rec/reset \
     -H "Authorization: Bearer $JETON_ADMIN"

# Compter les lignes de chaque table — le contrôle de cohérence.
curl https://sirh-api.exemple.fr/admin/etat \
     -H "Authorization: Bearer $JETON_ADMIN"
```

Ajuster un seuil impose un redéploiement de l'API (le fichier est dans
l'image), puis un appel à `/admin/besoins/generer`.

---

## 7. Sauvegarde

Le travail des six groupes vit dans les schémas `rec`, `form`, `mob`, `gta`,
`portail`, `onb`. À la fin de chaque journée :

```bash
docker exec <conteneur-postgres> \
  pg_dump -U sirh -n rec -n form -n mob -n gta -n portail -n onb sirh \
  > groupes-$(date +%F).sql
```

Restaurer un groupe :

```bash
curl -X POST https://sirh-api.exemple.fr/admin/modules/rec/reset \
     -H "Authorization: Bearer $JETON_ADMIN"
docker exec -i <conteneur-postgres> psql -U sirh sirh < groupes-2026-09-16.sql
```

Le socle, lui, n'a pas besoin d'être sauvegardé : il se régénère à l'identique
avec `/admin/reset`.

Le code des groupes, en revanche, vit dans leur instance de code-server. Leur
faire déposer leur dossier `app/src/modules/<code>/` en fin de journée est le
seul filet — c'est aussi ce qui permet de constituer le projet consolidé.

---

## 8. Vérifications à faire avant le premier cours

1. **Depuis un poste étudiant réel**, ouvrir `https://rec.exemple.fr` et
   `https://sirh-api.exemple.fr/docs`. Le réseau de l'université filtre
   parfois les sous-domaines inconnus : c'est le seul test qui, s'il échoue,
   remet en cause le dispositif.
2. Dans une instance de code-server, `npm install && npm run dev`, puis
   vérifier que l'écran **Besoins identifiés** affiche des lignes. Si oui,
   l'API, le jeton et le CORS sont bons tous les trois.
3. Dans la **Console SQL**, exécuter `select 1` puis un `create table`. Si les
   deux passent, le rôle du groupe et l'attribut `CREATEROLE` sont bons.
4. Lancer `/admin/reset` et vérifier que les tables d'un groupe survivent.
