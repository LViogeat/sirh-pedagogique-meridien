"""
La génération des besoins identifiés.

Trois règles, décrites dans `seuils.py`, parcourent les entretiens et l'état
des effectifs. Elles produisent la table `identified_needs`, qui est ce que
consomment les groupes Recrutement, Formation et Mobilité.

La commande est REJOUABLE. Chaque besoin possède une clé naturelle :

    (type, salarié, poste, compétence)

Relancée, la génération :
  - crée les besoins nouveaux,
  - rafraîchit ceux qui sont encore ouverts (priorité, origine),
  - NE TOUCHE PAS à ceux qu'un groupe a pris en charge ou clôturés.

C'est cette dernière ligne qui permet de relancer la commande en plein cours
sans détruire le travail des étudiants.
"""

from collections import defaultdict
from datetime import timedelta

from sqlmodel import Session, select

from .. import enums, models
from ..config import DATE_REFERENCE
from . import seuils


class _Besoin:
    """Un besoin candidat, avant confrontation avec ce qui existe en base."""

    def __init__(self, need_type, position_id, establishment_id, origin, priority,
                 employee_id=None, skill_id=None, review_id=None):
        self.need_type = need_type
        self.employee_id = employee_id
        self.position_id = position_id
        self.establishment_id = establishment_id
        self.skill_id = skill_id
        self.review_id = review_id
        self.origin = origin
        self.priority = priority

    @property
    def cle(self):
        return (self.need_type, self.employee_id, self.position_id, self.skill_id)


# =============================================================================
# Règle 1 — formation
# =============================================================================


def _besoins_formation(session: Session, contexte: dict) -> list[_Besoin]:
    besoins = []

    niveaux_attendus = {
        (ps.position_id, ps.skill_id): ps.required_level
        for ps in session.exec(select(models.PositionSkill)).all()
    }

    for evaluation in session.exec(select(models.SkillAssessment)).all():
        entretien = contexte["entretiens"].get(evaluation.review_id)
        if entretien is None:
            continue

        poste_id = contexte["poste_par_salarie"].get(entretien.employee_id)
        if poste_id is None:
            continue

        attendu = niveaux_attendus.get((poste_id, evaluation.skill_id))
        if attendu is None:
            continue

        ecart = attendu - evaluation.assessed_level
        if ecart < seuils.ECART_COMPETENCE_MINIMUM:
            continue

        besoins.append(_Besoin(
            need_type=enums.NeedType.FORMATION.value,
            employee_id=entretien.employee_id,
            position_id=poste_id,
            establishment_id=contexte["etablissement_par_salarie"][entretien.employee_id],
            skill_id=evaluation.skill_id,
            review_id=entretien.id,
            origin=f"Écart de {ecart} niveau(x) entre le niveau attendu ({attendu}) "
                   f"et le niveau constaté ({evaluation.assessed_level}) en entretien",
            priority=(enums.NeedPriority.HAUTE.value
                      if ecart >= seuils.ECART_COMPETENCE_PRIORITAIRE
                      else enums.NeedPriority.MOYENNE.value),
        ))

    return besoins


# =============================================================================
# Règle 2 — mobilité
# =============================================================================


def _besoins_mobilite(session: Session, contexte: dict) -> list[_Besoin]:
    besoins = []

    taux_par_entretien = defaultdict(list)
    for objectif in session.exec(select(models.Goal)).all():
        taux_par_entretien[objectif.review_id].append(objectif.achievement_rate)

    for aspiration in session.exec(select(models.Aspiration)).all():
        if aspiration.aspiration_type not in seuils.ASPIRATIONS_MOBILITE:
            continue

        entretien = contexte["entretiens"].get(aspiration.review_id)
        if entretien is None:
            continue

        taux = taux_par_entretien.get(entretien.id)
        if not taux:
            continue
        moyenne = round(sum(taux) / len(taux))
        if moyenne < seuils.TAUX_ATTEINTE_SATISFAISANT:
            continue

        salarie_id = entretien.employee_id
        poste_id = aspiration.target_position_id or contexte["poste_par_salarie"].get(salarie_id)
        etablissement_id = (
            aspiration.target_establishment_id
            or contexte["etablissement_par_salarie"].get(salarie_id)
        )
        if poste_id is None or etablissement_id is None:
            continue

        libelle = enums.libelle(enums.AspirationType, aspiration.aspiration_type)
        besoins.append(_Besoin(
            need_type=enums.NeedType.MOBILITE.value,
            employee_id=salarie_id,
            position_id=poste_id,
            establishment_id=etablissement_id,
            review_id=entretien.id,
            origin=f"Aspiration « {libelle} » exprimée en entretien, "
                   f"avec un taux d'atteinte moyen de {moyenne} %",
            priority=(enums.NeedPriority.HAUTE.value
                      if moyenne >= seuils.TAUX_ATTEINTE_PRIORITAIRE
                      else enums.NeedPriority.MOYENNE.value),
        ))

    return besoins


# =============================================================================
# Règle 3 — recrutement
# =============================================================================


def _besoins_recrutement(session: Session, contexte: dict) -> list[_Besoin]:
    besoins = []
    limite = DATE_REFERENCE + timedelta(days=seuils.FENETRE_FIN_CONTRAT_JOURS)

    postes = {p.id: p for p in session.exec(select(models.Position)).all()}
    etablissement_du_poste = contexte["etablissement_du_poste"]

    effectif = defaultdict(int)
    fins_proches = defaultdict(list)
    releve_prevue = defaultdict(int)

    for contrat in session.exec(select(models.Contract)).all():
        if contrat.status == enums.ContractStatus.A_VENIR.value:
            releve_prevue[contrat.position_id] += 1
            continue
        if contrat.status != enums.ContractStatus.ACTIF.value:
            continue
        if contexte["statut_salarie"].get(contrat.employee_id) != enums.EmployeeStatus.ACTIF.value:
            continue

        effectif[contrat.position_id] += 1
        if contrat.end_date is not None and contrat.end_date <= limite:
            fins_proches[contrat.position_id].append(contrat.end_date)

    for poste_id, poste in postes.items():
        manquants = poste.target_headcount - effectif[poste_id]
        departs = len(fins_proches[poste_id]) - releve_prevue[poste_id]

        raisons = []
        if manquants > 0:
            raisons.append(
                f"Effectif réel ({effectif[poste_id]}) inférieur à l'effectif cible "
                f"({poste.target_headcount})"
            )
        if departs > 0:
            prochaine = min(fins_proches[poste_id])
            raisons.append(
                f"{departs} contrat(s) se terminant avant le {prochaine.isoformat()} "
                f"sans remplacement prévu"
            )
        if not raisons:
            continue

        a_remplacer = max(manquants, 0) + max(departs, 0)
        besoins.append(_Besoin(
            need_type=enums.NeedType.RECRUTEMENT.value,
            position_id=poste_id,
            establishment_id=etablissement_du_poste[poste_id],
            origin=" ; ".join(raisons),
            priority=(enums.NeedPriority.HAUTE.value
                      if a_remplacer >= seuils.SOUS_EFFECTIF_PRIORITAIRE
                      else enums.NeedPriority.MOYENNE.value),
        ))

    return besoins


# =============================================================================
# Orchestration
# =============================================================================


def _contexte(session: Session) -> dict:
    """Les correspondances dont les trois règles ont besoin, chargées une fois."""
    departements = {d.id: d for d in session.exec(select(models.Department)).all()}
    etablissement_du_poste = {
        p.id: departements[p.department_id].establishment_id
        for p in session.exec(select(models.Position)).all()
    }

    statut_salarie = {}
    for salarie in session.exec(select(models.Employee)).all():
        statut_salarie[salarie.id] = salarie.status

    # Le poste et l'établissement d'un salarié, lus sur son contrat en cours.
    poste_par_salarie = {}
    etablissement_par_salarie = {}
    for contrat in session.exec(
        select(models.Contract).where(models.Contract.status == enums.ContractStatus.ACTIF.value)
    ).all():
        poste_par_salarie[contrat.employee_id] = contrat.position_id
        etablissement_par_salarie[contrat.employee_id] = contrat.establishment_id

    # Seuls les entretiens réalisés ou validés produisent des besoins :
    # un entretien planifié n'a encore rien constaté.
    entretiens = {
        e.id: e
        for e in session.exec(
            select(models.Review).where(
                models.Review.status.in_([
                    enums.ReviewStatus.REALISE.value,
                    enums.ReviewStatus.VALIDE.value,
                ])
            )
        ).all()
        if statut_salarie.get(e.employee_id) == enums.EmployeeStatus.ACTIF.value
    }

    return {
        "etablissement_du_poste": etablissement_du_poste,
        "statut_salarie": statut_salarie,
        "poste_par_salarie": poste_par_salarie,
        "etablissement_par_salarie": etablissement_par_salarie,
        "entretiens": entretiens,
    }


def generer(session: Session) -> dict:
    """Applique les trois règles et rapporte ce qui a changé."""
    contexte = _contexte(session)

    candidats = {}
    for besoin in (_besoins_formation(session, contexte)
                   + _besoins_mobilite(session, contexte)
                   + _besoins_recrutement(session, contexte)):
        # Deux règles peuvent viser la même clé naturelle — un poste en
        # sous-effectif ET dont un contrat se termine. Le premier calculé gagne,
        # son libellé d'origine mentionnant déjà les deux raisons.
        candidats.setdefault(besoin.cle, besoin)

    existants = {}
    for besoin in session.exec(select(models.IdentifiedNeed)).all():
        existants[(besoin.need_type, besoin.employee_id, besoin.position_id,
                   besoin.skill_id)] = besoin

    crees = mis_a_jour = conserves = 0

    for cle, candidat in candidats.items():
        existant = existants.get(cle)

        if existant is None:
            session.add(models.IdentifiedNeed(
                need_type=candidat.need_type,
                employee_id=candidat.employee_id,
                position_id=candidat.position_id,
                establishment_id=candidat.establishment_id,
                skill_id=candidat.skill_id,
                review_id=candidat.review_id,
                origin=candidat.origin,
                priority=candidat.priority,
                status=enums.NeedStatus.OUVERT.value,
                detected_on=DATE_REFERENCE,
            ))
            crees += 1
            continue

        if existant.status != enums.NeedStatus.OUVERT.value:
            # Pris en charge ou clôturé par un groupe : on n'y touche pas.
            conserves += 1
            continue

        existant.origin = candidat.origin
        existant.priority = candidat.priority
        existant.review_id = candidat.review_id
        existant.establishment_id = candidat.establishment_id
        session.add(existant)
        mis_a_jour += 1

    # Les besoins ouverts que plus aucune règle ne justifie sont laissés en
    # place : un groupe est peut-être déjà en train de travailler dessus.
    sans_regle = sum(
        1 for cle, besoin in existants.items()
        if cle not in candidats and besoin.status == enums.NeedStatus.OUVERT.value
    )

    session.commit()

    return {
        "crees": crees,
        "mis_a_jour": mis_a_jour,
        "conserves": conserves,
        "ouverts_sans_regle_active": sans_regle,
        "total": len(session.exec(select(models.IdentifiedNeed)).all()),
    }
