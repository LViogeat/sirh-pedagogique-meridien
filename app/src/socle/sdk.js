/**
 * Le SDK du socle — tout ce qu'un écran a le droit d'appeler.
 *
 *   import { getBesoins, sql, formatDate } from '@/socle/sdk'
 *
 * Si une fonction n'est pas listée ici, elle n'existe pas pour vous.
 */

export {
  // Structure
  getEtablissements, getDepartements, getPostes, getPoste, getCompetences,
  // Salariés
  getSalaries, getSalarie, getContrats,
  // Évaluation
  getCampagnes, getEntretiens, getEntretien, getAspirations,
  // Besoins identifiés
  getBesoins, getBesoin,
  prendreEnChargeBesoin, cloturerBesoin, relacherBesoin,
  // Référentiels
  getReferentiels, getDateReference,
} from './corehr'

export { sql, sqlComplet, sqlScript, insert, update, remove, useQuery } from './sql'

export { formatDate, formatNombre, formatPourcent, anciennete, toast } from './format'

export { MODULE_CODE } from './config'
