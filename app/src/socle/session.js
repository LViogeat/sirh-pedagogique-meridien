// =============================================================================
// La session — deux axes de rôles, à ne pas confondre.
//
//   session.module    RÉEL, issu du compte (rec, gta, form, eval…).
//                     Détermine vos droits d'ÉCRITURE, appliqués PAR LA BASE.
//
//   session.profilRH  SIMULÉ, choisi dans la barre du haut (RH, MANAGER, SALARIE).
//                     Détermine ce que votre écran AFFICHE. Aucun effet sur
//                     les droits — c'est un outil de conception.
//
// useSession() renvoie un objet réactif : pas de .value à écrire nulle part.
// =============================================================================

import { reactive } from 'vue'
import { supabase } from './supabase'
import { getEmployes } from './corehr'

const etat = reactive({
  utilisateur: null,   // le compte Supabase
  profil: null,        // la ligne de la table profils
  module: null,        // le code du groupe : 'rec', 'gta'…
  estConnecte: false,
  chargement: true,

  profilRH: 'RH',      // 'RH' | 'MANAGER' | 'SALARIE'
  employe: null,       // le salarié incarné quand profilRH ≠ 'RH'
  equipe: [],          // ceux qui ont `employe` pour manager
})

export function useSession() { return etat }

async function appliquer(session) {
  etat.utilisateur = session?.user ?? null
  etat.estConnecte = !!session?.user
  etat.profil = null
  etat.module = null

  if (etat.utilisateur) {
    const { data, error } = await supabase
      .from('profils').select('*').eq('user_id', etat.utilisateur.id).maybeSingle()
    if (!error && data) {
      etat.profil = data
      etat.module = data.module
    }
  }
  etat.chargement = false
}

export async function initSession() {
  const { data } = await supabase.auth.getSession()
  await appliquer(data.session)
  supabase.auth.onAuthStateChange((_evenement, session) => { appliquer(session) })
}

export async function connexion(email, motDePasse) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password: motDePasse })
  if (error) {
    throw new Error(
      /invalid login/i.test(error.message)
        ? 'Adresse e-mail ou mot de passe incorrect.'
        : error.message
    )
  }
  await appliquer(data.session)
  return data.session
}

export async function deconnexion() {
  await supabase.auth.signOut()
  etat.profilRH = 'RH'
  etat.employe = null
  etat.equipe = []
}

/**
 * Change le profil fonctionnel simulé.
 * Sans personneId, on choisit un salarié représentatif du rôle demandé.
 */
export async function choisirProfilRH(role, personneId = null) {
  etat.profilRH = role

  if (role === 'RH') {
    etat.employe = null
    etat.equipe = []
    return
  }

  const tous = await getEmployes()
  const encadrants = new Set(tous.map(e => e.manager_id).filter(Boolean))

  let id = personneId
  if (!id) {
    id = role === 'MANAGER'
      ? tous.find(e => encadrants.has(e.personne_id))?.personne_id
      : tous.find(e => !encadrants.has(e.personne_id))?.personne_id
  }

  etat.employe = tous.find(e => e.personne_id === id) ?? null
  etat.equipe = etat.employe
    ? tous.filter(e => e.manager_id === etat.employe.personne_id)
    : []
}
