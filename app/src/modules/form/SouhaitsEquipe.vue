<!-- libelle: Souhaits de mon équipe -->
<script setup>
/**
 * Story #24 — Le manager formalise les souhaits de formation de son équipe :
 * ceux exprimés lors des entretiens annuels et les demandes formulées en
 * cours d'année, pour les transmettre au service RH.
 *
 * Le manager choisit son nom, voit les souhaits des personnes qu'il encadre,
 * et pour chacun donne une priorité et un avis avant de le transmettre. Il
 * peut aussi ajouter lui-même un souhait pour un membre de son équipe.
 */
import { ref, computed } from 'vue'
import { sql, insert, update, getSalaries, formatDate, toast } from '@/socle/sdk'
import {
  preparerSchema, STATUTS_SOUHAIT, ORIGINES_SOUHAIT, PRIORITES, AVIS_MANAGER,
  libelle, couleur, enIso, salarieCourantId,
} from './_donnees'
import ChoixSalarie from './_ChoixSalarie.vue'

const manager = ref(null)
const equipe = ref([])
const formations = ref([])
const souhaits = ref([])
const chargement = ref(false)

const statut = ref('exprime')
const fiche = ref(null)
const enregistrement = ref(false)

async function chargerSouhaits() {
  souhaits.value = await sql(
    `select w.*,
            f.intitule as formation, f.domaine,
            e.first_name || ' ' || e.last_name as salarie
     from   souhaits w
     join   formations f       on f.id = w.formation_id
     join   public.employees e on e.id = w.employee_id
     where  e.manager_id = :manager
     order by w.statut, e.last_name, e.first_name, w.id`,
    { manager: manager.value.id },
  )
}

async function charger() {
  souhaits.value = []
  equipe.value = []
  if (!manager.value) return
  chargement.value = true
  try {
    await preparerSchema()
    equipe.value = await getSalaries({ managerId: manager.value.id })
    formations.value = await sql(
      'select id, intitule, domaine from formations where actif order by intitule',
    )
    await chargerSouhaits()
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
}

async function changerManager(s) {
  manager.value = s
  await charger()
}

const visibles = computed(() =>
  souhaits.value.filter((w) => !statut.value || w.statut === statut.value))

const totaux = computed(() => ({
  aFormaliser: souhaits.value.filter((w) => w.statut === 'exprime').length,
  transmis: souhaits.value.filter((w) => w.statut === 'transmis').length,
  ecartes: souhaits.value.filter((w) => w.statut === 'ecarte').length,
}))

// ── La fiche : formaliser un souhait, ou en ajouter un ───────────────────────

function ajouter() {
  fiche.value = {
    id: null, employee_id: null, formation_id: null, origine: 'en_cours_annee',
    motivation: '', priorite: 'moyenne', avis_manager: 'favorable',
    commentaire_manager: '', salarie: null, formation: null,
  }
}

function formaliser(souhait) {
  fiche.value = {
    ...souhait,
    motivation: souhait.motivation ?? '',
    priorite: souhait.priorite ?? 'moyenne',
    avis_manager: souhait.avis_manager ?? 'favorable',
    commentaire_manager: souhait.commentaire_manager ?? '',
  }
}

/**
 * Enregistre la fiche avec le statut demandé :
 * 'exprime' (brouillon), 'transmis' (envoyé au RH) ou 'ecarte' (non retenu).
 */
async function enregistrer(nouveauStatut) {
  const f = fiche.value
  if (!f.id && (!f.employee_id || !f.formation_id)) {
    toast.alerte('Choisissez le collaborateur et la formation.')
    return
  }
  enregistrement.value = true
  try {
    let id = f.id
    if (!id) {
      const cree = await insert('souhaits', {
        employee_id: f.employee_id,
        formation_id: f.formation_id,
        origine: f.origine,
        saisi_par: 'manager',
        motivation: f.motivation.trim() || null,
      })
      id = cree.id
    }
    await update('souhaits', id, {
      priorite: f.priorite,
      avis_manager: f.avis_manager,
      commentaire_manager: f.commentaire_manager.trim() || null,
      statut: nouveauStatut,
      transmis_le: nouveauStatut === 'transmis' ? enIso(new Date()) : null,
    })
    toast.succes({
      exprime: 'Souhait enregistré, il reste à transmettre',
      transmis: 'Souhait transmis au service RH',
      ecarte: 'Souhait non retenu',
    }[nouveauStatut])
    fiche.value = null
    await chargerSouhaits()
  } catch (erreur) {
    toast.erreur(erreur.message.includes('souhaits_employee_id_formation_id_origine_key')
      ? 'Ce collaborateur a déjà un souhait pour cette formation.'
      : erreur.message)
  } finally {
    enregistrement.value = false
  }
}
</script>

<template>
  <PageHeader
    titre="Souhaits de mon équipe"
    sousTitre="Formaliser les souhaits de formation de mon équipe et les transmettre au RH"
  >
    <Button v-if="manager" label="Ajouter un souhait" icon="pi pi-plus" @click="ajouter" />
  </PageHeader>

  <ChoixSalarie managers libelle="Je suis le manager" @change="changerManager" />

  <Message v-if="!manager" severity="info" :closable="false">
    Choisissez votre nom dans la liste des managers pour voir les souhaits de votre équipe.
    <template v-if="salarieCourantId"> Le salarié choisi sur un autre écran n’encadre personne.</template>
  </Message>

  <template v-else>
    <div class="stats">
      <StatCard titre="Mon équipe" :valeur="equipe.length" icone="pi pi-users"
                precision="collaborateur(s)" />
      <StatCard titre="Souhaits à formaliser" :valeur="totaux.aFormaliser" icone="pi pi-inbox" />
      <StatCard titre="Transmis au RH" :valeur="totaux.transmis" icone="pi pi-send" />
      <StatCard titre="Non retenus" :valeur="totaux.ecartes" icone="pi pi-ban" />
    </div>

    <div class="filtres">
      <Select v-model="statut" :options="STATUTS_SOUHAIT"
              optionLabel="label" optionValue="code"
              placeholder="Tous les souhaits" showClear />
    </div>

    <DataTable :value="visibles" :loading="chargement" dataKey="id"
               stripedRows size="small" rowHover removableSort
               @row-click="(e) => formaliser(e.data)">
      <template #empty>Aucun souhait de formation dans cette liste.</template>

      <Column field="salarie" header="Collaborateur" sortable />
      <Column field="formation" header="Formation souhaitée" sortable />

      <Column field="origine" header="Exprimé" sortable style="width: 10rem">
        <template #body="{ data }">{{ libelle(ORIGINES_SOUHAIT, data.origine) }}</template>
      </Column>

      <Column field="cree_le" header="Le" sortable style="width: 7rem">
        <template #body="{ data }">{{ formatDate(data.cree_le) }}</template>
      </Column>

      <Column field="motivation" header="Motivation">
        <template #body="{ data }">{{ data.motivation || '—' }}</template>
      </Column>

      <Column field="priorite" header="Priorité" sortable style="width: 7rem">
        <template #body="{ data }">
          <Tag v-if="data.priorite" :value="libelle(PRIORITES, data.priorite)"
               :severity="couleur(PRIORITES, data.priorite)" />
          <span v-else>—</span>
        </template>
      </Column>

      <Column field="statut" header="Statut" sortable style="width: 14rem">
        <template #body="{ data }">
          <Tag :value="libelle(STATUTS_SOUHAIT, data.statut)"
               :severity="couleur(STATUTS_SOUHAIT, data.statut)" />
        </template>
      </Column>

      <Column style="width: 9rem">
        <template #body="{ data }">
          <Button :label="data.statut === 'exprime' ? 'Formaliser' : 'Revoir'"
                  icon="pi pi-pencil" text size="small" @click.stop="formaliser(data)" />
        </template>
      </Column>
    </DataTable>
  </template>

  <Dialog :visible="!!fiche" modal :style="{ width: '40rem' }"
          :header="fiche?.id ? 'Formaliser le souhait' : 'Ajouter un souhait de formation'"
          @update:visible="fiche = null">
    <div v-if="fiche" class="formulaire">
      <template v-if="fiche.id">
        <p class="chapo large">
          {{ fiche.salarie }} souhaite suivre « {{ fiche.formation }} »
          ({{ libelle(ORIGINES_SOUHAIT, fiche.origine).toLowerCase() }}).
          <template v-if="fiche.motivation"><br>Sa motivation : {{ fiche.motivation }}</template>
        </p>
      </template>

      <template v-else>
        <div class="champ">
          <label for="q-salarie">Collaborateur *</label>
          <Select inputId="q-salarie" v-model="fiche.employee_id" :options="equipe"
                  optionLabel="full_name" optionValue="id" filter
                  placeholder="Un membre de mon équipe" />
        </div>
        <div class="champ">
          <label for="q-origine">Souhait exprimé</label>
          <Select inputId="q-origine" v-model="fiche.origine" :options="ORIGINES_SOUHAIT"
                  optionLabel="label" optionValue="code" />
        </div>
        <div class="champ large">
          <label for="q-formation">Formation du catalogue *</label>
          <Select inputId="q-formation" v-model="fiche.formation_id" :options="formations"
                  optionLabel="intitule" optionValue="id" filter
                  placeholder="Choisir une formation" />
        </div>
        <div class="champ large">
          <label for="q-motivation">Besoin exprimé</label>
          <Textarea id="q-motivation" v-model="fiche.motivation" rows="2" autoResize />
        </div>
      </template>

      <div class="champ">
        <label for="q-priorite">Priorité</label>
        <Select inputId="q-priorite" v-model="fiche.priorite" :options="PRIORITES"
                optionLabel="label" optionValue="code" />
      </div>
      <div class="champ">
        <label for="q-avis">Mon avis</label>
        <Select inputId="q-avis" v-model="fiche.avis_manager" :options="AVIS_MANAGER"
                optionLabel="label" optionValue="code" />
      </div>
      <div class="champ large">
        <label for="q-commentaire">Commentaire pour le service RH</label>
        <Textarea id="q-commentaire" v-model="fiche.commentaire_manager" rows="2" autoResize />
      </div>
    </div>

    <template #footer>
      <Button label="Ne pas retenir" severity="secondary" text
              :disabled="enregistrement" @click="enregistrer('ecarte')" />
      <Button label="Enregistrer sans transmettre" severity="secondary" outlined
              :disabled="enregistrement" @click="enregistrer('exprime')" />
      <Button label="Transmettre au RH" icon="pi pi-send"
              :loading="enregistrement" @click="enregistrer('transmis')" />
    </template>
  </Dialog>
</template>

<style scoped>
.stats {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.25rem;
}
.filtres { margin-bottom: 1rem; }
.filtres > .p-select { min-width: 16rem; }
.formulaire { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.champ { display: flex; flex-direction: column; gap: .35rem; min-width: 0; }
.large { grid-column: 1 / -1; }
.champ label { font-size: .85rem; font-weight: 600; }
.chapo { margin: 0; line-height: 1.5; }
:deep(.p-datatable-tbody > tr) { cursor: pointer; }
</style>
