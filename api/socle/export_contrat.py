"""
Génère `contrat-api.md` : la version compacte du contrat d'API.

    python -m socle.export_contrat > ../contrat-api.md

Pourquoi deux fichiers ? `openapi.json` est la spécification complète, celle
qui fait foi et qu'on ouvre dans un outil. Elle pèse une centaine de kilo-octets,
ce qui sature le contexte d'un chat IA gratuit.

Ce fichier-ci dit la même chose en dix fois moins de place : les endpoints,
leurs filtres, et la forme exacte des réponses. C'est LUI que les étudiants
collent dans Copilot au début d'une conversation.

Il est engendré depuis la même source que la spécification : les deux ne
peuvent pas diverger.
"""

import sys

from .main import app

FAMILLES = ["Référentiels", "Core HR", "Évaluation", "Besoins identifiés",
            "SQL des modules", "Administration"]


def _nom_du_ref(ref: str) -> str:
    return ref.rsplit("/", 1)[-1]


def _type_lisible(schema: dict, spec: dict) -> str:
    """Rend un schéma JSON sous une forme qu'on lit d'un coup d'œil."""
    if "$ref" in schema:
        return _nom_du_ref(schema["$ref"])

    if "anyOf" in schema:
        variantes = [_type_lisible(v, spec) for v in schema["anyOf"]]
        sans_null = [v for v in variantes if v != "null"]
        suffixe = "?" if "null" in variantes else ""
        return "|".join(sans_null) + suffixe

    if "enum" in schema:
        return " | ".join(str(v) for v in schema["enum"])

    type_json = schema.get("type")
    if type_json == "array":
        return f"[{_type_lisible(schema.get('items', {}), spec)}]"
    if type_json == "string" and schema.get("format") == "date":
        return "date"
    return type_json or "any"


def _schemas_utilises(spec: dict) -> list[str]:
    """Les objets référencés par au moins une réponse, dans l'ordre utile."""
    utilises: list[str] = []

    def visiter(nom: str) -> None:
        if nom in utilises:
            return
        utilises.append(nom)
        proprietes = spec["components"]["schemas"].get(nom, {}).get("properties", {})
        for definition in proprietes.values():
            for ref in _refs(definition):
                visiter(ref)

    def _refs(definition: dict) -> list[str]:
        trouves = []
        if "$ref" in definition:
            trouves.append(_nom_du_ref(definition["$ref"]))
        for cle in ("items", "additionalProperties"):
            if isinstance(definition.get(cle), dict):
                trouves += _refs(definition[cle])
        for variante in definition.get("anyOf", []) + definition.get("allOf", []):
            trouves += _refs(variante)
        return trouves

    for chemin in spec["paths"].values():
        for operation in chemin.values():
            reponse = operation.get("responses", {}).get("200", {})
            schema = reponse.get("content", {}).get("application/json", {}).get("schema", {})
            for nom in _refs(schema):
                visiter(nom)
            corps = operation.get("requestBody", {})
            schema = corps.get("content", {}).get("application/json", {}).get("schema", {})
            for nom in _refs(schema):
                visiter(nom)

    return [n for n in utilises if not n.startswith("HTTP") and n != "ValidationError"]


def main() -> None:
    spec = app.openapi()
    sortir = sys.stdout.write

    sortir(f"# Contrat d'API — {spec['info']['title']}\n\n")
    sortir("Version compacte, faite pour être collée dans un chat IA. "
           "La spécification complète est dans `openapi.json`.\n\n")
    sortir("Toutes les requêtes portent l'en-tête "
           "`Authorization: Bearer <le jeton de votre groupe>`.\n\n")
    sortir("Toutes les listes renvoient l'intégralité des lignes : pas de pagination. "
           "Tous les filtres sont facultatifs et se combinent.\n\n")

    sortir("## Endpoints\n\n")
    par_famille: dict[str, list] = {f: [] for f in FAMILLES}
    for chemin, operations in spec["paths"].items():
        for methode, operation in operations.items():
            famille = (operation.get("tags") or ["Autres"])[0]
            par_famille.setdefault(famille, []).append((methode.upper(), chemin, operation))

    for famille in FAMILLES:
        entrees = par_famille.get(famille) or []
        if not entrees:
            continue
        sortir(f"### {famille}\n\n")
        for methode, chemin, operation in entrees:
            sortir(f"**{methode} {chemin}** — {operation.get('summary', '')}\n\n")

            filtres = [
                p for p in operation.get("parameters", [])
                if p.get("in") == "query"
            ]
            if filtres:
                rendus = []
                for p in filtres:
                    rendus.append(f"`{p['name']}` : {_type_lisible(p.get('schema', {}), spec)}")
                sortir("- filtres : " + " · ".join(rendus) + "\n")

            corps = operation.get("requestBody", {})
            schema = corps.get("content", {}).get("application/json", {}).get("schema", {})
            if schema:
                sortir(f"- corps : `{_type_lisible(schema, spec)}`\n")

            reponse = operation.get("responses", {}).get("200", {})
            schema = reponse.get("content", {}).get("application/json", {}).get("schema", {})
            if schema:
                sortir(f"- réponse : `{_type_lisible(schema, spec)}`\n")
            sortir("\n")

    sortir("## Objets\n\n")
    for nom in _schemas_utilises(spec):
        definition = spec["components"]["schemas"].get(nom, {})
        proprietes = definition.get("properties")
        if not proprietes:
            continue
        sortir(f"**{nom}**\n\n```\n")
        for champ, forme in proprietes.items():
            sortir(f"{champ}: {_type_lisible(forme, spec)}\n")
        sortir("```\n\n")


if __name__ == "__main__":
    main()
