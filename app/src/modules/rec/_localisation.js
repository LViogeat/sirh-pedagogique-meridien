/**
 * La localisation d'une DP, déduite de son hôtel (story #147).
 *
 * Le socle donne l'adresse, le code postal et la ville ; le pays et la région
 * s'en déduisent. Rien n'est saisi : la localisation est toujours juste.
 */

/* Département (2 premiers chiffres du code postal) → région. */
const REGIONS = {
  'Île-de-France': ['75', '77', '78', '91', '92', '93', '94', '95'],
  'Auvergne-Rhône-Alpes': ['01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74'],
  'Nouvelle-Aquitaine': ['16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87'],
  "Provence-Alpes-Côte d'Azur": ['04', '05', '06', '13', '83', '84'],
  'Occitanie': ['09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82'],
  'Hauts-de-France': ['02', '59', '60', '62', '80'],
  'Grand Est': ['08', '10', '51', '52', '54', '55', '57', '67', '68', '88'],
  'Bretagne': ['22', '29', '35', '56'],
  'Normandie': ['14', '27', '50', '61', '76'],
  'Pays de la Loire': ['44', '49', '53', '72', '85'],
  'Centre-Val de Loire': ['18', '28', '36', '37', '41', '45'],
  'Bourgogne-Franche-Comté': ['21', '25', '39', '58', '70', '71', '89', '90'],
  'Corse': ['20'],
}

export function regionDe(codePostal) {
  const dep = String(codePostal || '').slice(0, 2)
  return Object.entries(REGIONS).find(([, deps]) => deps.includes(dep))?.[0] ?? '—'
}

/** { pays, region, ville, adresse, codePostal } pour un établissement du socle. */
export function localisationDe(hotel) {
  if (!hotel) return null
  return {
    pays: 'France',
    region: regionDe(hotel.postal_code),
    ville: hotel.city,
    adresse: hotel.address,
    codePostal: hotel.postal_code,
  }
}
