/**
 * Le transport : un seul endroit qui sait parler à l'API.
 *
 * Tout le reste du SDK passe par ici. Si l'API répond une erreur, on remonte
 * SON message — c'est lui qui explique ce qui ne va pas, pas un « HTTP 400 ».
 */

import { API_TOKEN, API_URL } from './config'

export class ErreurApi extends Error {
  constructor(message, statut) {
    super(message)
    this.name = 'ErreurApi'
    this.statut = statut
  }
}

/** Transforme { a: 1, b: null, c: 'x' } en '?a=1&c=x' — les vides sont ignorés. */
function versParametres(filtres = {}) {
  const parametres = new URLSearchParams()
  for (const [cle, valeur] of Object.entries(filtres)) {
    if (valeur === null || valeur === undefined || valeur === '') continue
    parametres.set(cle, String(valeur))
  }
  const chaine = parametres.toString()
  return chaine ? `?${chaine}` : ''
}

async function appeler(methode, chemin, { filtres, corps } = {}) {
  let reponse
  try {
    reponse = await fetch(`${API_URL}${chemin}${versParametres(filtres)}`, {
      method: methode,
      headers: {
        Authorization: `Bearer ${API_TOKEN}`,
        ...(corps ? { 'Content-Type': 'application/json' } : {}),
      },
      body: corps ? JSON.stringify(corps) : undefined,
    })
  } catch {
    throw new ErreurApi(
      `L'API ne répond pas (${API_URL}). Vérifiez VITE_API_URL dans votre fichier .env.`, 0,
    )
  }

  if (!reponse.ok) {
    let message = `L'API a répondu ${reponse.status}.`
    try {
      const details = await reponse.json()
      if (details?.detail) message = details.detail
    } catch { /* la réponse n'était pas du JSON : on garde le message générique */ }
    throw new ErreurApi(message, reponse.status)
  }

  return reponse.status === 204 ? null : reponse.json()
}

export const get = (chemin, filtres) => appeler('GET', chemin, { filtres })
export const post = (chemin, corps) => appeler('POST', chemin, { corps })
export const patch = (chemin, corps) => appeler('PATCH', chemin, { corps })
