# Déploiement

*Ce que fait tourner le cours, et où.*

| Quoi | Où | Coût |
|---|---|---|
| PostgreSQL + API du socle | VPS Hostinger `194.164.76.215` | ~95 Mo de RAM |
| Poste de travail des six groupes | StackBlitz, dans leur navigateur | aucun |

L'API est le seul service à héberger. Les groupes n'installent rien et ne font
tourner aucune base : ils lancent une interface Vite qui appelle cette API.

---

## 1. Le socle sur votre poste

Avant de déployer quoi que ce soit, le socle tourne en entier sur une machine
de développement — c'est là qu'on fait évoluer le modèle, les seuils ou les
écrans, et qu'on vérifie avant de pousser.

```bash
docker compose up -d --build     # base + API, données chargées au premier démarrage
cd app && npm install && npm run dev
```

- API et documentation interactive : <http://localhost:8000/docs>
- Application : <http://localhost:5173>

Le premier démarrage crée les tables, prépare les six schémas de groupe et
charge le jeu de démonstration. Il n'y a aucune commande à lancer ensuite.

Ajoutez un fichier `app/.env` pour que le front local vise votre API locale
plutôt que celle du serveur :

```
VITE_API_URL=http://localhost:8000
VITE_API_TOKEN=jeton-rec
VITE_MODULE_CODE=rec
```

Les jetons `jeton-rec`, `jeton-form`, … et `jeton-admin` sont les valeurs par
défaut hors production ; elles ne valent que sur votre poste.

Après une modification de l'API, régénérer les deux livrables de documentation :

```bash
docker compose exec -T api python -m socle.export_openapi > openapi.json
docker compose exec -T api python -m socle.export_contrat > contrat-api.md
```

Pour tout effacer et repartir de zéro : `docker compose down -v`.

---

## 2. Pourquoi pas de panneau d'orchestration

Le VPS a **1 vCPU et 3,8 Go de RAM**, et héberge déjà une autre application qui
occupe les ports 80 et 443 avec son propre Caddy.

Coolify, Dokploy ou CapRover apporteraient tous les trois le même problème :
leur proxy veut ces deux ports, et le panneau lui-même coûte entre 300 Mo et
1 Go de RAM. Pour deux conteneurs — une API et une base — c'est une couche de
panne sans contrepartie.

Le socle est donc déployé en `docker compose` simple, dans `/opt/sirh`, et
exposé par le reverse proxy déjà en place.

## 3. Pourquoi les groupes ne codent pas sur le serveur

Six instances de code-server, c'était le plan initial. L'arithmétique l'a
écarté :

| | |
|---|---|
| L'autre application du serveur | 800 Mo |
| API + PostgreSQL du socle | 95 Mo |
| 6 × code-server au repos | ~1,2 Go |
| 6 × `vite dev` en simultané | ~2,1 Go |
| **Total** | **~4,2 Go pour 3,8 Go** |

Et surtout : **1 vCPU** pour six serveurs de développement avec rechargement à
chaud, six `npm install` le premier matin, six reconstructions à chaque
sauvegarde. Aucun panneau d'orchestration ne crée de la RAM.

StackBlitz exécute Vite **dans le navigateur de l'étudiant**, en WebContainer.
Le serveur ne porte plus que l'API, et la charge de compilation part chez celui
qui code. C'est aussi ce que prévoyait l'architecture d'origine.

---

## 4. Le déploiement, de bout en bout

### Préparer le serveur

```bash
git clone https://github.com/LViogeat/sirh-pedagogique-meridien.git /opt/sirh
cd /opt/sirh
```

### Écrire `/opt/sirh/.env`

Jamais committé, `chmod 600`. Engendrer les jetons :

```bash
for g in rec form mob gta portail onb admin postgres; do openssl rand -hex 12; done
```

```
POSTGRES_USER=sirh
POSTGRES_PASSWORD=...
POSTGRES_DB=sirh

# Le réseau Docker du reverse proxy déjà présent sur le serveur.
RESEAU_PROXY=sweet-waters-backend_default

# Le jour 1 du cours. À régler AVANT la première séance, puis à ne plus toucher :
# ancienneté, contrats à échéance et campagne en cours sont calculés dessus.
DATE_REFERENCE=2026-09-15

# code:Libellé:jeton[:type_besoin] — le quatrième champ dit quel type de besoin
# le module prend en charge. Trois modules seulement en consomment.
GROUPES=rec:Recrutement:JETON1:recrutement,form:Formation:JETON2:formation,mob:Mobilité & carrière:JETON3:mobilite,gta:Gestion des temps:JETON4,portail:Portail RH & Self-Service:JETON5,onb:Onboarding & Offboarding:JETON6

# Ouvre /admin. Ne se distribue pas.
JETON_ADMIN=...

# Les fronts des groupes tournent sur des origines imprévisibles (StackBlitz
# attribue un sous-domaine par session). « * » est le seul réglage tenable,
# et il ne coûte rien : les données sont fictives.
ORIGINES_AUTORISEES=*
```

### Démarrer

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

Au premier démarrage, l'API crée les tables, prépare les six schémas de groupe
et charge le jeu de démonstration. Vérifier :

```bash
docker compose -f docker-compose.prod.yml logs api | grep "INFO socle"
curl -s http://127.0.0.1:8001/
```

> ⚠️ Le compte PostgreSQL doit avoir l'attribut `CREATEROLE` : c'est lui qui crée
> les six rôles et les six schémas. Le compte créé par l'image officielle
> convient. Sans cela, l'API sert le socle en lecture mais journalise une erreur,
> et `/sql` ne fonctionne pas.

### Ce que le fichier compose garantit

- **La base n'est publiée sur aucun port de l'hôte.** Elle n'est joignable que
  par l'API, sur un réseau Docker privé.
- **L'API n'ouvre que la boucle locale** (`127.0.0.1:8001`), pour diagnostiquer
  depuis le serveur. Elle rejoint en plus le réseau du reverse proxy, qui
  l'atteint sous le nom `sirh-api`.

---

## 5. Le nom de domaine et le certificat

Un enregistrement `A` chez le gestionnaire DNS du domaine :

| Type | Nom | Valeur | TTL |
|---|---|---|---|
| `A` | `sirh-api` | `194.164.76.215` | 300 |

Vérifier avant d'aller plus loin — Caddy ne peut pas obtenir de certificat tant
que le nom ne résout pas :

```bash
dig +short A sirh-api.govetia.com
```

Puis ajouter le site au Caddy existant, par sa variable `CADDY_EXTRA_CONFIG` :

```
CADDY_EXTRA_CONFIG=sirh-api.govetia.com {
    reverse_proxy sirh-api:8000
}
```

Le certificat est demandé automatiquement au premier appel. Sauvegarder le
fichier d'environnement avant de le modifier, et recréer le conteneur qui porte
Caddy — quelques secondes d'interruption pour l'application voisine.

---

## 6. Le poste d'un groupe

Rien à installer. Le dépôt s'ouvre dans StackBlitz, directement sur le dossier
de l'application :

```
https://stackblitz.com/github/LViogeat/sirh-pedagogique-meridien/tree/main/app
```

Chaque groupe crée son fork, puis un fichier `.env` avec deux lignes :

```
VITE_API_TOKEN=le jeton de son groupe
VITE_MODULE_CODE=son code de module
```

L'URL de l'API est déjà compilée dans l'application. Tant que ce fichier manque,
l'application affiche un écran qui dit exactement quoi créer — pas une erreur
réseau.

> **Le seul test qui conditionne le dispositif**, et il doit être fait depuis un
> poste étudiant réel : vérifier que `stackblitz.com`, `*.webcontainer.io` et
> `sirh-api.govetia.com` passent le filtrage du réseau de l'université. S'il
> échoue, c'est l'environnement qu'il faut revoir, pas l'architecture.

---

## 7. Tenir le cours

```bash
JETON=... ; API=https://sirh-api.govetia.com

# Remise à zéro des données du socle, entre deux sprints.
# Les schémas des groupes ne sont PAS touchés.
curl -X POST $API/admin/reset -H "Authorization: Bearer $JETON"

# Rejouer les règles après avoir ajusté un seuil dans rules/seuils.py.
# Les besoins pris en charge par un groupe ne bougent pas.
curl -X POST $API/admin/besoins/generer -H "Authorization: Bearer $JETON"

# Repartir propre sur le schéma d'un groupe.
curl -X POST $API/admin/modules/rec/reset -H "Authorization: Bearer $JETON"

# Compter les lignes de chaque table — le contrôle de cohérence.
curl $API/admin/etat -H "Authorization: Bearer $JETON"
```

Depuis le serveur, sans jeton :

```bash
cd /opt/sirh && docker compose -f docker-compose.prod.yml exec api python -m socle.reset
```

Ajuster un seuil impose de pousser le dépôt, puis sur le serveur :

```bash
cd /opt/sirh && git pull && docker compose -f docker-compose.prod.yml up -d --build
```

---

## 8. Sauvegarde

Le socle se régénère à l'identique : il n'a pas besoin d'être sauvegardé. Le
travail des six groupes, si.

```bash
docker exec sirh-db-1 pg_dump -U sirh \
  -n rec -n form -n mob -n gta -n portail -n onb sirh \
  > /root/groupes-$(date +%F).sql
```

Restaurer un groupe :

```bash
curl -X POST $API/admin/modules/rec/reset -H "Authorization: Bearer $JETON"
docker exec -i sirh-db-1 psql -U sirh sirh < /root/groupes-2026-09-16.sql
```

Leur **code**, lui, vit dans leur StackBlitz. Le faire déposer en fin de journée
— le dossier `src/modules/<code>/` et leur `schema.sql` — est le seul filet, et
c'est ce qui permet de constituer le projet consolidé.
