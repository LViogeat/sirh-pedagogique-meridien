// =============================================================================
// Formats et notifications.
// =============================================================================

const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
              'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre']

/** formatDate('2026-03-14') → '14/03/2026'   ·   (…, 'long') → '14 mars 2026' */
export function formatDate(valeur, style = 'court') {
  if (!valeur) return '—'
  const d = valeur instanceof Date ? valeur : new Date(valeur)
  if (Number.isNaN(d.getTime())) return '—'
  const jour = String(d.getDate()).padStart(2, '0')
  if (style === 'long') return `${d.getDate()} ${MOIS[d.getMonth()]} ${d.getFullYear()}`
  return `${jour}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
}

/** anciennete(79) → '6 ans et 7 mois' */
export function anciennete(mois) {
  if (mois === null || mois === undefined) return '—'
  const n = Number(mois)
  if (n < 1) return 'moins d’un mois'
  const ans = Math.floor(n / 12)
  const reste = n % 12
  if (!ans) return `${reste} mois`
  const partAns = `${ans} an${ans > 1 ? 's' : ''}`
  return reste ? `${partAns} et ${reste} mois` : partAns
}

/** formatEuro(2450.5) → '2 450,50 €' */
export function formatEuro(valeur, { decimales = 2 } = {}) {
  if (valeur === null || valeur === undefined || valeur === '') return '—'
  return Number(valeur).toLocaleString('fr-FR', {
    style: 'currency', currency: 'EUR',
    minimumFractionDigits: decimales, maximumFractionDigits: decimales,
  })
}

export function formatNombre(valeur, decimales = 0) {
  if (valeur === null || valeur === undefined) return '—'
  return Number(valeur).toLocaleString('fr-FR', {
    minimumFractionDigits: decimales, maximumFractionDigits: decimales,
  })
}

export function formatPourcent(valeur, decimales = 1) {
  if (valeur === null || valeur === undefined) return '—'
  const n = Number(valeur)
  return `${n > 0 ? '+' : ''}${n.toLocaleString('fr-FR', {
    minimumFractionDigits: decimales, maximumFractionDigits: decimales })} %`
}

// --- Notifications -----------------------------------------------------------
// Le service PrimeVue n'est disponible que dans un setup() ; on le capture une
// fois au démarrage pour que toast.succes() soit appelable de n'importe où.

let service = null
export function _enregistrerToast(s) { service = s }

export const toast = {
  succes: (message, titre = 'Enregistré') =>
    service?.add({ severity: 'success', summary: titre, detail: message, life: 3000 }),
  erreur: (message, titre = 'Erreur') =>
    service?.add({ severity: 'error', summary: titre, detail: message, life: 6000 }),
  info: (message, titre = 'Information') =>
    service?.add({ severity: 'info', summary: titre, detail: message, life: 3000 }),
  alerte: (message, titre = 'Attention') =>
    service?.add({ severity: 'warn', summary: titre, detail: message, life: 4000 }),
}
