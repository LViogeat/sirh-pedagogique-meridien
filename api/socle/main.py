"""
L'application FastAPI du socle SIRH Sorbonne-Hôtel.

Au démarrage : les tables sont créées si elles n'existent pas, les schémas des
six groupes sont préparés, et le jeu de démonstration est chargé si la base est
vide. Un déploiement Coolify n'a donc aucune commande à lancer ensuite.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, SQLModel, select

from . import models
from .bootstrap import preparer_sans_echouer
from .config import DATE_REFERENCE, GROUPES, ORIGINES_AUTORISEES
from .db import engine
from .routers import admin, besoins, corehr, evaluation, referentiels, sql
from .rules import besoins as regles_besoins
from .seed import seed

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s — %(message)s")
logger = logging.getLogger("socle")


DESCRIPTION = """
Le référentiel RH de **Sorbonne-Hôtel**, chaîne hôtelière française de cinq
établissements et cent quarante salariés.

Cette API est le socle commun du cours : les six modules développés par les
groupes s'y branchent. Elle expose le Core HR (établissements, départements,
postes, salariés, contrats, compétences) et l'Évaluation (campagnes,
entretiens annuels, objectifs, évaluations de compétences, aspirations), et
elle en dérive les **besoins identifiés**, qui sont le pivot du dispositif.

## La règle d'or

Les modules **ne modifient jamais** les données du socle. Ils le lisent, et
créent leurs propres données dans leur schéma PostgreSQL, via `/sql`.

Seule exception : faire passer un besoin identifié d'`ouvert` à
`pris_en_charge`, puis à `cloture`, via `PATCH /besoins/{id}`. C'est ce qui
rend visible, lors des démonstrations, la chaîne entre l'évaluation et l'action.

## S'identifier

Toutes les requêtes portent le jeton du groupe :

    Authorization: Bearer <votre jeton>

Il ne protège rien — les données sont fictives. Il sert à savoir quel groupe
appelle quoi, et à ce qu'un groupe ne puisse pas écrire chez un autre.

## Vos propres tables

`POST /sql` exécute vos requêtes sous le rôle PostgreSQL de votre groupe.
Vous êtes propriétaire du schéma qui porte le code de votre module : vous y
créez vos tables, vous les lisez, vous les écrivez. Vous lisez le socle et les
schémas des cinq autres groupes, sans jamais pouvoir les modifier.

## Les dates

Le socle ne regarde jamais l'horloge. Tout est calculé par rapport à une date
de référence, que renvoie `GET /date-reference`. C'est ce qui permet de remettre
les données à zéro entre deux sprints et de retrouver exactement le même jeu.
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    SQLModel.metadata.create_all(engine)

    with Session(engine) as session:
        preparer_sans_echouer(session)

        vide = session.exec(select(models.Establishment)).first() is None
        if vide:
            logger.info("Base vide — chargement du jeu de démonstration Sorbonne-Hôtel.")
            resume = seed.remettre_a_zero(session)
            generation = regles_besoins.generer(session)
            logger.info("Chargé : %s", resume)
            logger.info("Besoins générés : %s", generation)

    logger.info("Date de référence : %s", DATE_REFERENCE.isoformat())
    logger.info("Groupes : %s", ", ".join(f"{g.code} ({g.libelle})" for g in GROUPES))
    yield


app = FastAPI(
    title="Socle SIRH — Sorbonne-Hôtel",
    version="1.0.0",
    description=DESCRIPTION,
    lifespan=lifespan,
    docs_url="/docs",
    openapi_url="/openapi.json",
)

# Le front de chaque groupe tourne sur un sous-domaine différent de l'API :
# sans cette autorisation, le navigateur bloque tous les appels.
app.add_middleware(
    CORSMiddleware,
    allow_origins=ORIGINES_AUTORISEES,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(referentiels.router)
app.include_router(corehr.router)
app.include_router(evaluation.router)
app.include_router(besoins.router)
app.include_router(sql.router)
app.include_router(admin.router)


@app.get("/", tags=["Référentiels"], summary="Vérifier que l'API répond")
def accueil() -> dict:
    """Le seul endpoint qui ne demande pas de jeton — sert de sonde de santé."""
    return {
        "socle": "SIRH Sorbonne-Hôtel",
        "version": app.version,
        "date_reference": DATE_REFERENCE.isoformat(),
        "documentation": "/docs",
        "contrat_openapi": "/openapi.json",
    }
