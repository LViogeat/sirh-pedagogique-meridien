"""
Remise à zéro des données du socle, en une commande.

    docker compose exec api python -m socle.reset

Vide le Core HR et l'Évaluation, les recharge à l'identique, puis régénère les
besoins. Les schémas des six groupes ne sont pas touchés.
"""

from sqlmodel import Session, SQLModel

from .bootstrap import preparer_sans_echouer
from .config import DATE_REFERENCE
from .db import engine
from .rules import besoins as regles_besoins
from .seed import seed


def main() -> None:
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        preparer_sans_echouer(session)
        donnees = seed.remettre_a_zero(session)
        generation = regles_besoins.generer(session)

    print(f"Date de référence : {DATE_REFERENCE.isoformat()}")
    for cle, valeur in donnees.items():
        print(f"  {cle:38} {valeur}")
    print("Besoins :")
    for cle, valeur in generation.items():
        print(f"  {cle:38} {valeur}")


if __name__ == "__main__":
    main()
