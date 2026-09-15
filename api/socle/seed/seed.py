"""
Génération du jeu de démonstration Sorbonne-Hôtel.

DÉTERMINISME — aucune valeur ne dépend de l'horloge ni d'un tirage non semé :
le hasard passe par un unique générateur initialisé sur GRAINE, et toutes les
dates se calculent à partir de config.DATE_REFERENCE. Remis à zéro deux fois de
suite, le socle produit exactement les mêmes lignes, avec les mêmes
identifiants.

C'est une exigence du cours, pas une coquetterie : les étudiants stockent des
identifiants du socle dans leurs propres tables, et un groupe doit pouvoir
écrire « alors l'écran affiche 12 besoins de formation » avant d'avoir codé
l'écran.
"""

import random
import unicodedata
from datetime import date, timedelta

from sqlalchemy import text
from sqlmodel import Session

from .. import enums, models
from ..config import DATE_REFERENCE
from . import data

GRAINE = 20260112


def _sans_accent(texte: str) -> str:
    decompose = unicodedata.normalize("NFD", texte)
    return "".join(c for c in decompose if unicodedata.category(c) != "Mn")


def _email(prenom: str, nom: str, pris: set[str]) -> str:
    base = f"{_sans_accent(prenom)}.{_sans_accent(nom)}".lower()
    base = base.replace(" ", "-").replace("'", "")
    candidat = f"{base}@sorbonne-hotel.fr"
    suffixe = 1
    while candidat in pris:
        suffixe += 1
        candidat = f"{base}{suffixe}@sorbonne-hotel.fr"
    pris.add(candidat)
    return candidat


def _statut_contrat(debut: date, fin: date | None) -> str:
    if debut > DATE_REFERENCE:
        return enums.ContractStatus.A_VENIR.value
    if fin is not None and fin < DATE_REFERENCE:
        return enums.ContractStatus.TERMINE.value
    return enums.ContractStatus.ACTIF.value


# =============================================================================
# 1. Structure : établissements, départements, postes, compétences
# =============================================================================


def _creer_structure(session: Session) -> dict:
    etablissements = {}
    for e in data.ETABLISSEMENTS:
        ligne = models.Establishment(
            code=e.code, name=e.nom, city=e.ville, address=e.adresse,
            postal_code=e.code_postal, category=e.categorie,
            opened_on=e.ouverture, is_head_office=e.siege,
        )
        session.add(ligne)
        etablissements[e.code] = ligne
    session.flush()

    libelles_departements = dict(data.DEPARTEMENTS)
    departements = {}
    for e in data.ETABLISSEMENTS:
        for code_dep in data.DEPARTEMENTS_PAR_ETABLISSEMENT[e.code]:
            ligne = models.Department(
                establishment_id=etablissements[e.code].id,
                code=code_dep,
                label=libelles_departements[code_dep],
            )
            session.add(ligne)
            departements[(e.code, code_dep)] = ligne
    session.flush()

    # Un poste par couple (établissement, poste du catalogue). L'effectif cible
    # est mis à l'échelle de l'hôtel, et jamais inférieur à 1 : un hôtel a un
    # chef de cuisine, quelle que soit sa taille.
    postes = {}
    for e in data.ETABLISSEMENTS:
        for p in data.CATALOGUE_POSTES:
            if p.departement not in data.DEPARTEMENTS_PAR_ETABLISSEMENT[e.code]:
                continue
            if p.cinq_etoiles and e.categorie < 5:
                continue
            cible = max(1, round(p.effectif * e.facteur))
            ligne = models.Position(
                department_id=departements[(e.code, p.departement)].id,
                code=p.code, title=p.titre, job_family=p.famille,
                hierarchy_level=p.niveau, target_headcount=cible,
            )
            session.add(ligne)
            postes[(e.code, p.code)] = ligne
    session.flush()

    competences = {}
    for c in data.COMPETENCES:
        ligne = models.Skill(code=c.code, label=c.libelle, category=c.categorie)
        session.add(ligne)
        competences[c.code] = ligne
    session.flush()

    for (code_etab, code_poste), poste in postes.items():
        for code_competence, niveau in data.COMPETENCES_ATTENDUES[code_poste]:
            session.add(models.PositionSkill(
                position_id=poste.id,
                skill_id=competences[code_competence].id,
                required_level=niveau,
            ))
    session.flush()

    return {
        "etablissements": etablissements,
        "departements": departements,
        "postes": postes,
        "competences": competences,
    }


# =============================================================================
# 2. Salariés et contrats
# =============================================================================

# Ancienneté tirée dans ces tranches, en mois. La pondération donne une
# pyramide crédible : beaucoup d'arrivées récentes, quelques très anciens.
TRANCHES_ANCIENNETE = [
    ((2, 11), 22),
    ((12, 35), 30),
    ((36, 71), 22),
    ((72, 131), 16),
    ((132, 216), 10),
]


def _anciennete_mois(tirage: random.Random) -> int:
    bornes = [t[0] for t in TRANCHES_ANCIENNETE]
    poids = [t[1] for t in TRANCHES_ANCIENNETE]
    mini, maxi = tirage.choices(bornes, weights=poids, k=1)[0]
    return tirage.randint(mini, maxi)


def _type_contrat(tirage: random.Random, poste, code_etablissement: str) -> str:
    """
    Le mix contractuel de l'hôtellerie.

    Les postes d'encadrement et de direction sont en CDI : on ne recrute pas un
    chef de cuisine en extra. Le reste suit la répartition du secteur, avec une
    surpondération des saisonniers à Annecy et à Nice.
    """
    if poste.niveau >= 3:
        return enums.ContractType.CDI.value

    if poste.departement == "CUI" and poste.niveau <= 2 and tirage.random() < 0.18:
        return enums.ContractType.APPRENTISSAGE.value

    if poste.departement == "RES" and poste.niveau == 1 and tirage.random() < 0.15:
        return enums.ContractType.EXTRA.value

    saisonnier = 0.30 if code_etablissement in data.ETABLISSEMENTS_SAISONNIERS else 0.05
    tirage_type = tirage.random()
    if tirage_type < saisonnier:
        return enums.ContractType.SAISONNIER.value
    if tirage_type < saisonnier + 0.12:
        return enums.ContractType.CDD.value
    return enums.ContractType.CDI.value


def _temps_de_travail(tirage: random.Random, poste) -> float:
    """Les temps partiels se concentrent en housekeeping, comme dans le secteur."""
    if poste.departement == "HEB" and poste.niveau == 1 and tirage.random() < 0.35:
        return tirage.choice([0.6, 0.7, 0.8])
    if tirage.random() < 0.06:
        return 0.8
    return 1.0


def _duree_contrat_jours(tirage: random.Random, type_contrat: str) -> int | None:
    if type_contrat == enums.ContractType.CDI.value:
        return None
    if type_contrat == enums.ContractType.APPRENTISSAGE.value:
        return tirage.choice([365, 730])
    if type_contrat == enums.ContractType.SAISONNIER.value:
        return tirage.choice([120, 150, 180])
    if type_contrat == enums.ContractType.EXTRA.value:
        return tirage.choice([30, 60, 90])
    return tirage.choice([180, 270, 365])


class _Fabrique:
    """Construit des salariés en tenant les compteurs (matricule, e-mails)."""

    def __init__(self, session: Session, tirage: random.Random):
        self.session = session
        self.tirage = tirage
        self.emails: set[str] = set()
        self.compteur = 0

    def creer(self, sortie: date | None = None) -> models.Employee:
        self.compteur += 1
        if self.tirage.random() < 0.55:
            civilite, prenom = "MME", self.tirage.choice(data.PRENOMS_F)
        else:
            civilite, prenom = "M", self.tirage.choice(data.PRENOMS_M)
        nom = self.tirage.choice(data.NOMS)

        salarie = models.Employee(
            matricule=f"SH-{self.compteur:04d}",
            civility=civilite,
            first_name=prenom,
            last_name=nom,
            email_pro=_email(prenom, nom, self.emails),
            joined_on=DATE_REFERENCE,  # corrigé juste après par l'appelant
            left_on=sortie,
            status=(enums.EmployeeStatus.SORTI.value if sortie
                    else enums.EmployeeStatus.ACTIF.value),
        )
        self.session.add(salarie)
        return salarie


def _creer_salaries(session: Session, tirage: random.Random, structure: dict) -> dict:
    fabrique = _Fabrique(session, tirage)
    postes_par_cle = structure["postes"]
    etablissements = structure["etablissements"]
    catalogue = {p.code: p for p in data.CATALOGUE_POSTES}

    salaries_par_poste: dict[tuple[str, str], list[models.Employee]] = {}
    contrats: list[models.Contract] = []
    fins_proches = 0

    for (code_etab, code_poste), poste in postes_par_cle.items():
        descripteur = catalogue[code_poste]
        cible = poste.target_headcount

        # Quelques postes restent vacants : c'est la matière du groupe
        # Recrutement. Jamais un poste de direction, sinon la chaîne
        # managériale se casse.
        vacants = 0
        if descripteur.niveau < 4 and tirage.random() < 0.12:
            vacants = 1
        effectif = max(0, cible - vacants)

        occupants = []
        for _ in range(effectif):
            anciennete = _anciennete_mois(tirage)
            entree = DATE_REFERENCE - timedelta(days=int(anciennete * 30.44))

            salarie = fabrique.creer()
            salarie.joined_on = entree
            session.flush()

            type_contrat = _type_contrat(tirage, descripteur, code_etab)
            debut = entree
            duree = _duree_contrat_jours(tirage, type_contrat)

            # Un parcours en deux temps : un premier contrat court, puis le
            # contrat actuel. C'est ce qui donne un historique à lire.
            if type_contrat == enums.ContractType.CDI.value and anciennete > 30 \
                    and tirage.random() < 0.18:
                type_initial = tirage.choice([
                    enums.ContractType.CDD.value,
                    enums.ContractType.SAISONNIER.value,
                    enums.ContractType.APPRENTISSAGE.value,
                ])
                duree_initiale = _duree_contrat_jours(tirage, type_initial) or 365
                fin_initiale = entree + timedelta(days=duree_initiale)
                contrats.append(models.Contract(
                    employee_id=salarie.id, position_id=poste.id,
                    establishment_id=etablissements[code_etab].id,
                    contract_type=type_initial, start_date=entree,
                    end_date=fin_initiale, work_time_ratio=1.0,
                    status=_statut_contrat(entree, fin_initiale),
                ))
                debut = fin_initiale + timedelta(days=1)

            if duree is None:
                fin = None
            else:
                fin = debut + timedelta(days=duree)
                # Un contrat court dont le terme est déjà passé serait
                # incohérent avec un salarié présent : on le prolonge.
                while fin < DATE_REFERENCE:
                    fin = fin + timedelta(days=duree)
                if fin <= DATE_REFERENCE + timedelta(days=90):
                    fins_proches += 1

            contrats.append(models.Contract(
                employee_id=salarie.id, position_id=poste.id,
                establishment_id=etablissements[code_etab].id,
                contract_type=type_contrat, start_date=debut, end_date=fin,
                work_time_ratio=_temps_de_travail(tirage, descripteur),
                status=_statut_contrat(debut, fin),
            ))
            occupants.append(salarie)

        salaries_par_poste[(code_etab, code_poste)] = occupants

    # Les anciens salariés : partis dans les douze derniers mois. Leur poste
    # se retrouve en sous-effectif, ce qui alimente le besoin de recrutement.
    anciens = []
    cles_pourvues = [c for c, occupants in salaries_par_poste.items() if occupants]
    for cle in tirage.sample(cles_pourvues, k=12):
        code_etab, code_poste = cle
        poste = postes_par_cle[cle]
        anciennete = tirage.randint(14, 96)
        entree = DATE_REFERENCE - timedelta(days=int(anciennete * 30.44))
        sortie = DATE_REFERENCE - timedelta(days=tirage.randint(20, 330))

        salarie = fabrique.creer(sortie=sortie)
        salarie.joined_on = entree
        session.flush()
        contrats.append(models.Contract(
            employee_id=salarie.id, position_id=poste.id,
            establishment_id=etablissements[code_etab].id,
            contract_type=enums.ContractType.CDI.value,
            start_date=entree, end_date=sortie, work_time_ratio=1.0,
            status=enums.ContractStatus.TERMINE.value,
        ))
        anciens.append(salarie)

    for contrat in contrats:
        session.add(contrat)
    session.flush()

    return {
        "par_poste": salaries_par_poste,
        "anciens": anciens,
        "nb_contrats": len(contrats),
        "fins_proches": fins_proches,
    }


def _rattacher_les_managers(session: Session, structure: dict, salaries: dict) -> None:
    """
    La chaîne managériale.

    Règle unique : on remonte au niveau hiérarchique immédiatement supérieur
    dans le même département et le même établissement. À défaut, au directeur
    de l'établissement. Les directeurs d'établissement remontent au directeur
    général, à Paris — qui est le seul salarié sans manager.
    """
    catalogue = {p.code: p for p in data.CATALOGUE_POSTES}

    directeurs = {}
    for (code_etab, code_poste), occupants in salaries["par_poste"].items():
        if code_poste == "DIRECTEUR" and occupants:
            directeurs[code_etab] = occupants[0]

    directeur_general = directeurs.get("PANTHEON")

    # Les salariés d'un même département, rangés par niveau hiérarchique.
    par_departement: dict[tuple[str, str], dict[int, list]] = {}
    for (code_etab, code_poste), occupants in salaries["par_poste"].items():
        niveau = catalogue[code_poste].niveau
        cle = (code_etab, catalogue[code_poste].departement)
        par_departement.setdefault(cle, {}).setdefault(niveau, []).extend(occupants)

    for (code_etab, code_poste), occupants in salaries["par_poste"].items():
        descripteur = catalogue[code_poste]
        niveaux = par_departement[(code_etab, descripteur.departement)]
        superieurs = [
            niveaux[n] for n in sorted(niveaux) if n > descripteur.niveau and niveaux[n]
        ]
        for rang, salarie in enumerate(occupants):
            if superieurs:
                equipe = superieurs[0]
                manager = equipe[rang % len(equipe)]
            else:
                manager = directeurs.get(code_etab)

            if manager is None or manager.id == salarie.id:
                manager = directeur_general
            if manager is not None and manager.id == salarie.id:
                manager = None

            salarie.manager_id = manager.id if manager else None
            session.add(salarie)

    session.flush()


# =============================================================================
# 3. Campagne d'évaluation
# =============================================================================

# Écarts possibles entre le niveau attendu d'un poste et le niveau constaté,
# avec leur pondération. Les valeurs négatives sont celles qui produisent un
# besoin de formation : elles représentent environ 30 % des évaluations.
ECARTS_EVALUATION = [(-2, 6), (-1, 24), (0, 45), (1, 22), (2, 3)]


def _creer_campagne(session: Session, tirage: random.Random,
                    structure: dict, salaries: dict) -> dict:
    campagne = models.Campaign(
        label=f"Entretiens annuels {DATE_REFERENCE.year}",
        year=DATE_REFERENCE.year,
        opens_on=DATE_REFERENCE - timedelta(days=60),
        closes_on=DATE_REFERENCE + timedelta(days=30),
        status=enums.CampaignStatus.OUVERTE.value,
    )
    session.add(campagne)
    session.flush()

    competences_attendues = {}
    for (code_etab, code_poste), poste in structure["postes"].items():
        competences_attendues[poste.id] = [
            (structure["competences"][code].id, niveau)
            for code, niveau in data.COMPETENCES_ATTENDUES[code_poste]
        ]

    catalogue = {p.code: p for p in data.CATALOGUE_POSTES}
    poste_par_salarie = {}
    famille_par_salarie = {}
    etablissement_par_salarie = {}
    postes_par_etablissement: dict[str, list] = {}
    for (code_etab, code_poste), occupants in salaries["par_poste"].items():
        poste = structure["postes"][(code_etab, code_poste)]
        postes_par_etablissement.setdefault(code_etab, []).append(poste)
        for salarie in occupants:
            poste_par_salarie[salarie.id] = poste
            famille_par_salarie[salarie.id] = catalogue[code_poste].famille
            etablissement_par_salarie[salarie.id] = code_etab

    eligibles = [
        salarie
        for occupants in salaries["par_poste"].values()
        for salarie in occupants
        if salarie.manager_id is not None
        and (DATE_REFERENCE - salarie.joined_on).days >= 365
    ]
    eligibles.sort(key=lambda s: s.id)

    nb_entretiens = nb_objectifs = nb_evaluations = nb_aspirations = 0

    for salarie in eligibles:
        tirage_statut = tirage.random()
        if tirage_statut < 0.70:
            statut = enums.ReviewStatus.VALIDE.value
        elif tirage_statut < 0.90:
            statut = enums.ReviewStatus.REALISE.value
        else:
            statut = enums.ReviewStatus.PLANIFIE.value

        if statut == enums.ReviewStatus.PLANIFIE.value:
            jour = DATE_REFERENCE + timedelta(days=tirage.randint(3, 28))
            resume = None
        else:
            jour = DATE_REFERENCE - timedelta(days=tirage.randint(5, 55))
            resume = tirage.choice(data.COMMENTAIRES_ENTRETIEN)

        entretien = models.Review(
            campaign_id=campagne.id, employee_id=salarie.id,
            reviewer_id=salarie.manager_id, review_date=jour,
            status=statut, summary=resume,
        )
        session.add(entretien)
        session.flush()
        nb_entretiens += 1

        if statut == enums.ReviewStatus.PLANIFIE.value:
            continue

        famille = famille_par_salarie[salarie.id]
        libelles = data.OBJECTIFS_PAR_FAMILLE.get(famille, data.OBJECTIFS_PAR_FAMILLE["Direction"])
        for libelle in tirage.sample(libelles, k=min(len(libelles), tirage.randint(2, 3))):
            session.add(models.Goal(
                review_id=entretien.id, label=libelle,
                achievement_rate=tirage.choices(
                    [40, 55, 70, 80, 90, 100, 110],
                    weights=[6, 12, 18, 22, 20, 15, 7], k=1,
                )[0],
                comment=None,
            ))
            nb_objectifs += 1

        poste = poste_par_salarie[salarie.id]
        for competence_id, niveau_attendu in competences_attendues[poste.id]:
            ecarts = [e for e, _ in ECARTS_EVALUATION]
            poids = [p for _, p in ECARTS_EVALUATION]
            constate = niveau_attendu + tirage.choices(ecarts, weights=poids, k=1)[0]
            session.add(models.SkillAssessment(
                review_id=entretien.id, skill_id=competence_id,
                assessed_level=max(1, min(4, constate)),
            ))
            nb_evaluations += 1

        if tirage.random() < 0.35:
            type_aspiration = tirage.choices(
                [t.value for t in enums.AspirationType],
                weights=[18, 30, 32, 20], k=1,
            )[0]
            cible_etablissement = None
            cible_poste = None
            code_etab_actuel = etablissement_par_salarie[salarie.id]

            # Une mobilité géographique vise un AUTRE hôtel que le sien.
            if type_aspiration == enums.AspirationType.MOBILITE_GEOGRAPHIQUE.value:
                ailleurs = [e for code, e in structure["etablissements"].items()
                            if code != code_etab_actuel]
                cible_etablissement = tirage.choice(ailleurs).id

            # Un changement de poste vise un poste du même hôtel, de niveau au
            # moins égal : personne n'aspire à redescendre d'un cran.
            if type_aspiration == enums.AspirationType.CHANGEMENT_POSTE.value:
                actuel = poste_par_salarie[salarie.id]
                candidats = [
                    p for p in postes_par_etablissement[code_etab_actuel]
                    if p.id != actuel.id and p.hierarchy_level >= actuel.hierarchy_level
                ]
                if candidats:
                    cible_poste = tirage.choice(candidats).id
            session.add(models.Aspiration(
                review_id=entretien.id, aspiration_type=type_aspiration,
                target_establishment_id=cible_etablissement,
                target_position_id=cible_poste,
                comment=None,
            ))
            nb_aspirations += 1

    session.flush()
    return {
        "entretiens": nb_entretiens,
        "objectifs": nb_objectifs,
        "evaluations": nb_evaluations,
        "aspirations": nb_aspirations,
    }


# =============================================================================
# Point d'entrée
# =============================================================================


def vider(session: Session) -> None:
    """
    Vide le socle — et le socle seulement.

    Les schémas des groupes ne sont pas touchés : une remise à zéro entre deux
    sprints ne doit jamais détruire le travail des étudiants. Les identifiants
    repartent à 1, ce qui garantit que les références logiques stockées par les
    modules (`besoin_id`, `employee_id`…) restent valables.
    """
    tables = ", ".join(f"public.{m.__tablename__}" for m in models.TABLES_DANS_L_ORDRE)
    session.execute(text(f"truncate table {tables} restart identity cascade"))


def peupler(session: Session) -> dict:
    tirage = random.Random(GRAINE)
    structure = _creer_structure(session)
    salaries = _creer_salaries(session, tirage, structure)
    _rattacher_les_managers(session, structure, salaries)
    evaluation = _creer_campagne(session, tirage, structure, salaries)

    presents = sum(len(o) for o in salaries["par_poste"].values())
    cible = sum(p.target_headcount for p in structure["postes"].values())

    return {
        "etablissements": len(structure["etablissements"]),
        "departements": len(structure["departements"]),
        "postes": len(structure["postes"]),
        "competences": len(structure["competences"]),
        "salaries_presents": presents,
        "anciens_salaries": len(salaries["anciens"]),
        "contrats": salaries["nb_contrats"],
        "effectif_cible": cible,
        "contrats_finissant_sous_90_jours": salaries["fins_proches"],
        **evaluation,
    }


def remettre_a_zero(session: Session) -> dict:
    vider(session)
    resultat = peupler(session)
    session.commit()
    return resultat
