"""
Exporte la spécification OpenAPI dans un fichier unique.

    python -m socle.export_openapi > ../openapi.json

C'est ce fichier que les étudiants collent dans Copilot comme contexte. Il est
versionné dans le dépôt pour qu'on n'ait pas besoin de démarrer l'API — ni une
base de données — pour le leur fournir.
"""

import json
import sys

from .main import app


def main() -> None:
    json.dump(app.openapi(), sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
