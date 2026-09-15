/**
 * Les six modules du cours.
 *
 * Cette liste ne change pas : elle décrit le SIRH complet, indépendamment de
 * ce que chaque groupe a déjà écrit. Le menu l'affiche en entier, pour que
 * chacun voie où son module s'inscrit dans l'ensemble — mais un groupe ne
 * peut ouvrir que le sien.
 *
 * Le périmètre tient en une ligne, volontairement : c'est l'intitulé du sujet,
 * pas sa solution. Ce que le module contiendra, et comment il lira le socle,
 * est ce que le groupe a à concevoir.
 *
 * `typeBesoin` dit quel type de besoin identifié le module prend en charge.
 * Trois modules seulement en consomment.
 */

export const GROUPES = [
  {
    code: 'rec',
    label: 'Module Recrutement',
    icon: 'pi pi-user-plus',
    typeBesoin: 'recrutement',
    perimetre: 'Offres, candidats, candidatures, processus de recrutement',
  },
  {
    code: 'form',
    label: 'Module Formation',
    icon: 'pi pi-graduation-cap',
    typeBesoin: 'formation',
    perimetre: 'Catalogue, sessions, inscriptions, suivi',
  },
  {
    code: 'mob',
    label: 'Module Mobilité & carrière',
    icon: 'pi pi-directions',
    typeBesoin: 'mobilite',
    perimetre: 'Opportunités, souhaits d’évolution, mobilités internes, parcours',
  },
  {
    code: 'gta',
    label: 'Module Gestion des temps',
    icon: 'pi pi-clock',
    typeBesoin: null,
    perimetre: 'Temps de travail, pointages, congés, absences, compteurs, planning',
  },
  {
    code: 'portail',
    label: 'Module Portail RH & Self-Service',
    icon: 'pi pi-comments',
    typeBesoin: null,
    perimetre: 'Demandes RH, documents, workflows, échanges salarié / manager / RH',
  },
  {
    code: 'onb',
    label: 'Module Onboarding & Offboarding',
    icon: 'pi pi-sign-in',
    typeBesoin: null,
    perimetre: 'Parcours d’arrivée et de départ, checklists, tâches, matériel',
  },
]

export const GROUPE_PAR_CODE = Object.fromEntries(GROUPES.map((g) => [g.code, g]))

/** « rec » → « Module Recrutement ». Jamais de code brut à l'écran. */
export function libelleGroupe(code) {
  return GROUPE_PAR_CODE[code]?.label || code || '—'
}
