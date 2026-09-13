import { createClient } from '@supabase/supabase-js'
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config'

// Les étudiants n'utilisent JAMAIS ce client directement : ils passent par
// le SDK (socle/sdk.js). C'est ce qui garde leurs prompts courts et fiables.
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

export const estConfigure = () =>
  !SUPABASE_URL.includes('VOTRE-PROJET') && !SUPABASE_ANON_KEY.includes('VOTRE-CLE')
