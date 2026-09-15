<script setup>
/**
 * La page d'accueil du module d'un groupe.
 *
 * Le socle la fournit, et c'est la SEULE page du module qu'il fournit. Elle
 * dit où en est le module — ses écrans, ses tables — et rien d'autre : ce que
 * le module doit contenir est précisément ce que le groupe a à concevoir, en
 * partant de ce qu'il aura compris du socle.
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { sql } from '@/socle/sdk'
import { monModule } from '../modules'

const router = useRouter()

const tables = ref([])
const erreurSql = ref(null)
const chargement = ref(true)

/**
 * Les tables du groupe et leur nombre de lignes.
 *
 * information_schema donne les noms ; une seconde requête les compte toutes.
 * Les noms viennent du catalogue de PostgreSQL, pas d'une saisie : les insérer
 * dans la requête est sans danger ici.
 */
async function chargerTables() {
  const trouvees = await sql(
    `select table_name
     from   information_schema.tables
     where  table_schema = current_schema() and table_type = 'BASE TABLE'
     order  by table_name`,
  )
  if (!trouvees.length) return []

  const comptes = trouvees
    .map((t) => `select '${t.table_name}' as nom, count(*)::int as lignes from "${t.table_name}"`)
    .join(' union all ')
  return await sql(`${comptes} order by nom`)
}

onMounted(async () => {
  try {
    tables.value = await chargerTables()
  } catch (erreur) {
    erreurSql.value = erreur.message
  } finally {
    chargement.value = false
  }
})

/* Les écrans écrits par le groupe : tout sauf cette page d'accueil. */
const ecrans = computed(() => (monModule?.routes || []).filter((r) => !r.socle))
</script>

<template>
  <template v-if="monModule">
    <PageHeader :titre="monModule.label" :sousTitre="monModule.perimetre" />

    <p class="chapo">
      Ce module est le vôtre. Cette page est la seule que le socle vous donne :
      tout le reste est à concevoir.
    </p>

    <div v-if="chargement" class="attente"><ProgressSpinner /></div>

    <div v-else class="colonnes">
      <Card>
        <template #title>Vos écrans</template>
        <template #content>
          <div v-if="ecrans.length" class="ecrans">
            <Button v-for="r in ecrans" :key="r.path"
                    :label="r.label" icon="pi pi-desktop" severity="secondary"
                    outlined size="small"
                    @click="router.push(`/${monModule.code}/${r.path}`)" />
          </div>
          <p v-else class="vide">Aucun écran pour l’instant.</p>
        </template>
      </Card>

      <Card>
        <template #title>Votre schéma <code>{{ monModule.code }}</code></template>
        <template #content>
          <Message v-if="erreurSql" severity="error" :closable="false">
            {{ erreurSql }}
          </Message>
          <DataTable v-else-if="tables.length" :value="tables" size="small" dataKey="nom">
            <Column field="nom" header="Table" />
            <Column field="lignes" header="Lignes" style="width: 7rem" />
          </DataTable>
          <p v-else class="vide">Aucune table pour l’instant.</p>
        </template>
      </Card>
    </div>
  </template>

  <Message v-else severity="error" :closable="false">
    Aucun module n’est attribué à cette instance. Vérifiez
    <code>VITE_MODULE_CODE</code> dans <code>app/.env</code>.
  </Message>
</template>

<style scoped>
.chapo {
  color: var(--p-text-muted-color); font-size: .9rem;
  margin: -.5rem 0 1.5rem; max-width: 46rem; line-height: 1.6;
}
.attente { display: grid; place-items: center; min-height: 30vh; }
.colonnes { display: grid; grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr)); gap: 1.25rem; }
.ecrans { display: flex; gap: .5rem; flex-wrap: wrap; }
.vide { margin: 0; color: var(--p-text-muted-color); font-size: .875rem; }
</style>
