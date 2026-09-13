// =============================================================================
// useTable — le CRUD sur les tables de VOTRE module.
//
// Le préfixe est ajouté automatiquement à partir du module dans lequel vous
// vous trouvez : pour le groupe « rec », useTable('offres') travaille sur
// la table rec_offres.
//
// Viser la table d'un autre groupe en écriture échoue ici, avec un message
// lisible — et échouerait de toute façon en base. La double barrière est
// volontaire : la première donne une erreur compréhensible tout de suite.
// =============================================================================

import { reactive, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from './supabase'

export function useTable(nom, options = {}) {
  const { lectureSeule = false, ordre = 'id', ascendant = true, chargerAuDemarrage = true } = options

  const route = useRoute()
  const codeModule = route?.meta?.moduleCode

  if (!codeModule) {
    throw new Error(
      "useTable() ne peut être appelé que depuis un écran de module " +
      "(un fichier de src/modules/<code>/). Pour lire le référentiel, " +
      "utilisez getEmployes() et les autres fonctions du Core HR."
    )
  }

  // Un nom sans « _ » désigne une table du module courant.
  const qualifie = nom.includes('_')
  const table = qualifie ? nom : `${codeModule}_${nom}`

  if (qualifie && !table.startsWith(`${codeModule}_`) && !lectureSeule) {
    throw new Error(
      `La table « ${table} » n'appartient pas à votre module (« ${codeModule} »). ` +
      `Vous pouvez la LIRE avec useTable('${table}', { lectureSeule: true }), ` +
      `mais pas y écrire : la base le refuserait.`
    )
  }

  const etat = reactive({
    rows: [],
    loading: false,
    error: null,
    table,
    lectureSeule: lectureSeule || !table.startsWith(`${codeModule}_`),
  })

  function traiter(error) {
    if (!error) { etat.error = null; return false }
    // Les refus de RLS remontent en messages techniques : on les traduit.
    etat.error = /row-level security|violates|permission denied/i.test(error.message)
      ? `Écriture refusée sur « ${table} » : cette table n'appartient pas à votre module.`
      : error.message
    return true
  }

  async function refresh() {
    etat.loading = true
    const { data, error } = await supabase.from(table).select('*').order(ordre, { ascending: ascendant })
    etat.loading = false
    if (traiter(error)) return
    etat.rows = data || []
  }

  async function create(objet) {
    const { data, error } = await supabase.from(table).insert(objet).select().single()
    if (traiter(error)) return null
    await refresh()
    return data
  }

  async function update(id, objet) {
    const { data, error } = await supabase.from(table).update(objet).eq('id', id).select().single()
    if (traiter(error)) return null
    await refresh()
    return data
  }

  async function remove(id) {
    const { error } = await supabase.from(table).delete().eq('id', id)
    if (traiter(error)) return false
    await refresh()
    return true
  }

  if (chargerAuDemarrage) onMounted(refresh)

  etat.refresh = refresh
  etat.create = create
  etat.update = update
  etat.remove = remove
  return etat
}
