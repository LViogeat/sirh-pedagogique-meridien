// =============================================================================
// LE SEUL FICHIER À RENSEIGNER POUR CONNECTER L'APPLICATION À LA BASE.
//
// Ces deux valeurs sont PUBLIQUES par nature : elles vivent dans le navigateur
// de chaque utilisateur. Elles ne protègent rien — ce sont les politiques RLS
// de la base qui protègent les données, et le fait d'être connecté.
//
// La clé service_role, elle, ne doit JAMAIS figurer ici.
// =============================================================================

export const SUPABASE_URL =
  import.meta.env.VITE_SUPABASE_URL || 'https://VOTRE-PROJET.supabase.co'

export const SUPABASE_ANON_KEY =
  import.meta.env.VITE_SUPABASE_ANON_KEY || 'VOTRE-CLE-ANON'

// Les deux variables d'environnement permettent de pointer ailleurs sans
// modifier ce fichier — c'est ce qu'utilise scripts/demo-locale.sh, via un
// app/.env.local que git ignore. Sur StackBlitz, seules les valeurs
// ci-dessus comptent : il n'y a pas de fichier d'environnement à gérer.
