/**
 * L'application automatique du schéma du module.
 *
 * À chaque évolution de `schema.sql`, il fallait le recoller dans la Console
 * SQL, sinon les écrans affichaient « column … does not exist ». Désormais,
 * au démarrage, le module compare l'empreinte du fichier à celle enregistrée
 * en base (table `schema_version`) : si elles diffèrent, il exécute le script
 * — rejouable, il n'efface rien — puis enregistre la nouvelle empreinte.
 *
 * Uniquement pour le groupe Recrutement : dans le SIRH assemblé de la démo,
 * ouvert avec le code d'un autre groupe, rien n'est exécuté.
 *
 * La Console SQL reste utilisable comme avant : relancer le script à la main
 * ne gêne rien.
 */
import schema from './schema.sql?raw'
import { sql, sqlScript, MODULE_CODE, toast } from '@/socle/sdk'

/** Empreinte courte du texte du script (djb2). */
function empreinteDe(texte) {
  let h = 5381
  for (let i = 0; i < texte.length; i++) h = ((h << 5) + h + texte.charCodeAt(i)) | 0
  return (h >>> 0).toString(16)
}

const EMPREINTE = empreinteDe(schema)
let enCours = null

async function versionEnBase() {
  try {
    const [ligne] = await sql('select empreinte from schema_version where id = 1')
    return ligne?.empreinte ?? null
  } catch {
    return null // table absente : le schéma n'a jamais été appliqué automatiquement
  }
}

/**
 * Garantit que le schéma est à jour. Appelée au démarrage et par chaque écran
 * avant ses requêtes ; le travail n'est fait qu'une fois.
 */
export function assurerSchema() {
  if (MODULE_CODE !== 'rec') return Promise.resolve()
  enCours ??= (async () => {
    if ((await versionEnBase()) === EMPREINTE) return
    await sqlScript(schema)
    await sql(
      `insert into schema_version (id, empreinte, applique_le) values (1, :e, now())
       on conflict (id) do update set empreinte = excluded.empreinte, applique_le = excluded.applique_le`,
      { e: EMPREINTE },
    )
    // Au démarrage, l'application n'affiche pas encore les messages : on attend un peu.
    setTimeout(() => toast.info('Les tables du module ont été mises à jour automatiquement.', 'Schéma à jour'), 1500)
  })().catch((erreur) => {
    enCours = null // on réessaiera au prochain écran
    console.error('[rec] Application automatique du schéma impossible :', erreur)
    toast.erreur(`Mise à jour automatique des tables impossible : ${erreur.message}`)
  })
  return enCours
}
