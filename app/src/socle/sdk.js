// =============================================================================
// LE SDK — tout ce dont un module a besoin, en un seul import.
//
//   import { getEmployes, useTable, useSession, formatDate } from '@/socle/sdk'
//
// Les composants du socle (<PageHeader>, <StatCard>, <EmployeSelect>,
// <EmployeCard>) et ceux de PrimeVue (<DataTable>, <Button>, <Dialog>…)
// s'utilisent SANS import : ils sont enregistrés globalement.
//
// Vous n'avez donc jamais besoin d'écrire d'appel à Supabase ni de SQL.
// =============================================================================

export {
  getEmployes,
  getEmploye,
  getHistoriqueRemuneration,
  getServices,
  getPostes,
  getEtablissements,
  getPersonnes,
  getEffectifParService,
  getMouvements,
  getRef,
} from './corehr'

export { useTable } from './useTable'

export { useSession, choisirProfilRH } from './session'

export {
  formatDate,
  formatEuro,
  formatNombre,
  formatPourcent,
  anciennete,
  toast,
} from './format'
