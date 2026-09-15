<script setup>
/**
 * La console SQL de votre module.
 *
 * Vous êtes propriétaire du schéma PostgreSQL qui porte le code de votre
 * groupe. Vous y créez vos tables, vous les lisez, vous les écrivez.
 * Vous lisez aussi le socle et les schémas des cinq autres groupes, sans
 * jamais pouvoir les modifier : c'est PostgreSQL qui refuse, pas l'écran.
 *
 * Le bon rythme de travail : on met au point une instruction ici, puis on la
 * recopie dans `src/modules/<code>/schema.sql` pour pouvoir la rejouer.
 */
import { ref } from 'vue'
import { sqlComplet, sqlScript, MODULE_CODE, toast } from '@/socle/sdk'

const EXEMPLES = [
  {
    titre: 'Créer une table',
    code: `create table if not exists exemple (
  id serial primary key,
  besoin_id integer,          -- référence LOGIQUE vers public.identified_needs
  libelle text not null,
  statut text not null default 'brouillon',
  cree_le date not null default current_date
);`,
  },
  {
    titre: 'Insérer une ligne',
    code: `insert into exemple (libelle, statut) values ('Premier essai', 'brouillon');`,
  },
  {
    titre: 'Lire ses données',
    code: `select * from exemple order by id desc;`,
  },
  {
    titre: 'Joindre le socle',
    code: `select e.libelle, n.need_type, n.priority, p.title, h.name
from   exemple e
join   public.identified_needs n on n.id = e.besoin_id
join   public.positions        p on p.id = n.position_id
join   public.establishments   h on h.id = n.establishment_id
where  n.status = 'ouvert';`,
  },
  {
    titre: 'Lister ses tables',
    code: `select table_name
from   information_schema.tables
where  table_schema = '${MODULE_CODE}'
order  by table_name;`,
  },
]

const requete = ref(EXEMPLES[4].code)
const resultat = ref(null)
const erreur = ref(null)
const chargement = ref(false)

/* Plusieurs instructions séparées par des points-virgules ? On passe par
   /sql/script, qui les applique toutes dans une seule transaction. */
function contientPlusieursInstructions(texte) {
  return texte.trim().replace(/;\s*$/, '').includes(';')
}

async function executer() {
  chargement.value = true
  erreur.value = null
  resultat.value = null
  try {
    if (contientPlusieursInstructions(requete.value)) {
      const reponse = await sqlScript(requete.value)
      toast.succes(reponse.message)
    } else {
      resultat.value = await sqlComplet(requete.value)
      if (!resultat.value.columns.length) {
        toast.succes(`${resultat.value.row_count} ligne(s) touchée(s).`)
      }
    }
  } catch (e) {
    // Le message vient de PostgreSQL : c'est lui qui apprend quelque chose.
    erreur.value = e.message
  } finally {
    chargement.value = false
  }
}

function charger(exemple) {
  requete.value = exemple.code
  resultat.value = null
  erreur.value = null
}
</script>

<template>
  <PageHeader titre="Console SQL"
              :sousTitre="`Vous écrivez dans le schéma « ${MODULE_CODE} ». Le socle reste en lecture seule.`">
    <Button label="Exécuter" icon="pi pi-play" :loading="chargement" @click="executer" />
  </PageHeader>

  <div class="exemples">
    <Button v-for="e in EXEMPLES" :key="e.titre" :label="e.titre"
            size="small" severity="secondary" outlined @click="charger(e)" />
  </div>

  <Textarea v-model="requete" rows="12" class="editeur" spellcheck="false"
            @keydown.ctrl.enter="executer" @keydown.meta.enter="executer" />
  <small class="aide">Ctrl + Entrée pour exécuter.</small>

  <Message v-if="erreur" severity="error" :closable="false" class="erreur">
    <pre>{{ erreur }}</pre>
  </Message>

  <template v-if="resultat">
    <Message v-if="resultat.truncated" severity="warn" :closable="false">
      Résultat tronqué : seules les premières lignes sont affichées.
    </Message>

    <DataTable v-if="resultat.columns.length" :value="resultat.rows"
               paginator :rows="25" stripedRows size="small" removableSort
               class="resultat">
      <template #empty>La requête n'a renvoyé aucune ligne.</template>
      <Column v-for="colonne in resultat.columns" :key="colonne"
              :field="colonne" :header="colonne" sortable />
    </DataTable>

    <Message v-else severity="success" :closable="false">
      {{ resultat.row_count }} ligne(s) touchée(s).
    </Message>
  </template>
</template>

<style scoped>
.exemples { display: flex; gap: .5rem; flex-wrap: wrap; margin-bottom: .75rem; }
.editeur {
  width: 100%; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: .85rem;
}
.aide { color: var(--p-text-muted-color); }
.erreur { margin-top: 1rem; }
.erreur pre { margin: 0; white-space: pre-wrap; font-size: .82rem; }
.resultat { margin-top: 1rem; }
</style>
