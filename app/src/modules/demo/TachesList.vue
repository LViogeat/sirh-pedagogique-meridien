<script setup>
// =============================================================================
// IMPLÉMENTATION DE RÉFÉRENCE — liste, création, modification, suppression.
//
// Copiez ce fichier, renommez-le, adaptez-le : c'est le modèle attendu pour
// tous les écrans de module. Tout ce qui suit y est démontré une fois.
//
// Remarquez qu'il n'y a QU'UN SEUL import : les composants PrimeVue
// (<DataTable>, <Dialog>, <Button>…) et ceux du socle (<PageHeader>,
// <EmployeSelect>…) s'utilisent sans être importés.
// =============================================================================

import { ref, computed } from 'vue'
import { useConfirm } from 'primevue/useconfirm'
import { useTable, formatDate, toast } from '@/socle/sdk'

// useTable('taches') travaille sur la table demo_taches : le préfixe de votre
// module est ajouté tout seul. Le chargement initial est automatique.
const taches = useTable('taches', { ordre: 'echeance' })

const confirm = useConfirm()

const PRIORITES = [
  { code: 'basse',   libelle: 'Basse' },
  { code: 'normale', libelle: 'Normale' },
  { code: 'haute',   libelle: 'Haute' },
]

// ---- Formulaire -------------------------------------------------------------

const dialogueOuvert = ref(false)
const enCoursId = ref(null)
const formulaire = ref(vide())
const erreurs = ref({})

function vide() {
  return { titre: '', personne_id: null, echeance: null, priorite: 'normale', commentaire: '' }
}

function ouvrirCreation() {
  enCoursId.value = null
  formulaire.value = vide()
  erreurs.value = {}
  dialogueOuvert.value = true
}

function ouvrirModification(ligne) {
  enCoursId.value = ligne.id
  formulaire.value = {
    titre: ligne.titre,
    personne_id: ligne.personne_id,
    echeance: ligne.echeance ? new Date(ligne.echeance) : null,
    priorite: ligne.priorite,
    commentaire: ligne.commentaire ?? '',
  }
  erreurs.value = {}
  dialogueOuvert.value = true
}

// Valider AVANT d'envoyer : la base refusera de toute façon, mais un message
// en français vaut mieux qu'une erreur technique.
function valide() {
  const e = {}
  if (!formulaire.value.titre?.trim()) e.titre = 'Le titre est obligatoire.'
  if (formulaire.value.echeance && formulaire.value.echeance < new Date().setHours(0, 0, 0, 0)) {
    e.echeance = 'L’échéance ne peut pas être dans le passé.'
  }
  erreurs.value = e
  return Object.keys(e).length === 0
}

async function enregistrer() {
  if (!valide()) return

  const donnees = {
    ...formulaire.value,
    titre: formulaire.value.titre.trim(),
    // Une date PrimeVue est un objet Date : PostgreSQL attend 'AAAA-MM-JJ'.
    echeance: formulaire.value.echeance
      ? new Date(formulaire.value.echeance).toISOString().slice(0, 10)
      : null,
  }

  const resultat = enCoursId.value
    ? await taches.update(enCoursId.value, donnees)
    : await taches.create(donnees)

  if (!resultat) { toast.erreur(taches.error); return }

  toast.succes(enCoursId.value ? 'Tâche modifiée.' : 'Tâche créée.')
  dialogueOuvert.value = false
}

function supprimer(ligne) {
  confirm.require({
    message: `Supprimer « ${ligne.titre} » ?`,
    header: 'Confirmation',
    icon: 'pi pi-exclamation-triangle',
    acceptLabel: 'Supprimer',
    rejectLabel: 'Annuler',
    acceptProps: { severity: 'danger' },
    accept: async () => {
      const ok = await taches.remove(ligne.id)
      ok ? toast.succes('Tâche supprimée.') : toast.erreur(taches.error)
    },
  })
}

async function basculer(ligne) {
  const ok = await taches.update(ligne.id, { terminee: !ligne.terminee })
  if (!ok) toast.erreur(taches.error)
}

// ---- Affichage --------------------------------------------------------------

const filtre = ref('toutes')
const visibles = computed(() => {
  if (filtre.value === 'ouvertes')  return taches.rows.filter(t => !t.terminee)
  if (filtre.value === 'terminees') return taches.rows.filter(t => t.terminee)
  return taches.rows
})

const severitePriorite = (p) => ({ haute: 'danger', normale: 'info', basse: 'secondary' }[p])
const enRetard = (t) => !t.terminee && t.echeance && new Date(t.echeance) < new Date()
</script>

<template>
  <PageHeader titre="Tâches" sousTitre="Module de démonstration — le modèle à recopier">
    <Button label="Nouvelle tâche" icon="pi pi-plus" @click="ouvrirCreation" />
  </PageHeader>

  <Message v-if="taches.error" severity="error" :closable="false" class="bandeau">
    {{ taches.error }}
  </Message>

  <SelectButton v-model="filtre" class="bandeau"
                :options="[
                  { libelle: 'Toutes', code: 'toutes' },
                  { libelle: 'En cours', code: 'ouvertes' },
                  { libelle: 'Terminées', code: 'terminees' }]"
                optionLabel="libelle" optionValue="code" :allowEmpty="false" />

  <DataTable :value="visibles" :loading="taches.loading" dataKey="id"
             paginator :rows="10" removableSort stripedRows size="small">
    <template #empty>Aucune tâche. Créez-en une avec le bouton ci-dessus.</template>

    <Column header="" style="width: 3rem">
      <template #body="{ data }">
        <Checkbox :modelValue="data.terminee" binary @update:modelValue="basculer(data)" />
      </template>
    </Column>

    <Column field="titre" header="Tâche" sortable>
      <template #body="{ data }">
        <span :class="{ terminee: data.terminee }">{{ data.titre }}</span>
      </template>
    </Column>

    <!-- On ne stocke JAMAIS un nom de personne : on stocke le personne_id,
         et <EmployeCard> se charge de l'afficher. -->
    <Column header="Salarié concerné" style="width: 18rem">
      <template #body="{ data }">
        <EmployeCard v-if="data.personne_id" :id="data.personne_id" compact />
        <span v-else class="muet">—</span>
      </template>
    </Column>

    <Column field="echeance" header="Échéance" sortable style="width: 9rem">
      <template #body="{ data }">
        <span :class="{ retard: enRetard(data) }">{{ formatDate(data.echeance) }}</span>
      </template>
    </Column>

    <Column field="priorite" header="Priorité" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="data.priorite" :severity="severitePriorite(data.priorite)" />
      </template>
    </Column>

    <Column header="" style="width: 7rem">
      <template #body="{ data }">
        <Button icon="pi pi-pencil" text severity="secondary"
                aria-label="Modifier" @click="ouvrirModification(data)" />
        <Button icon="pi pi-trash" text severity="danger"
                aria-label="Supprimer" @click="supprimer(data)" />
      </template>
    </Column>
  </DataTable>

  <!-- Formulaire en boîte de dialogue : le schéma standard pour créer et modifier. -->
  <Dialog v-model:visible="dialogueOuvert" modal
          :header="enCoursId ? 'Modifier la tâche' : 'Nouvelle tâche'"
          :style="{ width: '34rem' }">
    <div class="formulaire">
      <div class="champ">
        <label for="titre">Titre *</label>
        <InputText id="titre" v-model="formulaire.titre" :invalid="!!erreurs.titre" fluid />
        <small v-if="erreurs.titre" class="erreur">{{ erreurs.titre }}</small>
      </div>

      <EmployeSelect v-model="formulaire.personne_id" label="Salarié concerné" />

      <div class="duo">
        <div class="champ">
          <label for="echeance">Échéance</label>
          <DatePicker id="echeance" v-model="formulaire.echeance" dateFormat="dd/mm/yy"
                      showIcon :invalid="!!erreurs.echeance" fluid />
          <small v-if="erreurs.echeance" class="erreur">{{ erreurs.echeance }}</small>
        </div>
        <div class="champ">
          <label for="priorite">Priorité</label>
          <Select id="priorite" v-model="formulaire.priorite" :options="PRIORITES"
                  optionLabel="libelle" optionValue="code" fluid />
        </div>
      </div>

      <div class="champ">
        <label for="commentaire">Commentaire</label>
        <Textarea id="commentaire" v-model="formulaire.commentaire" rows="3" fluid />
      </div>
    </div>

    <template #footer>
      <Button label="Annuler" severity="secondary" text @click="dialogueOuvert = false" />
      <Button label="Enregistrer" icon="pi pi-check" @click="enregistrer" />
    </template>
  </Dialog>
</template>

<style scoped>
.bandeau { margin-bottom: 1rem; }
.terminee { text-decoration: line-through; color: var(--p-text-muted-color); }
.retard { color: var(--p-red-600); font-weight: 500; }
.muet { color: var(--p-text-muted-color); }
.formulaire { display: flex; flex-direction: column; gap: 1rem; padding-top: .5rem; }
.champ { display: flex; flex-direction: column; gap: .35rem; }
.duo { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
label { font-size: .85rem; font-weight: 500; }
.erreur { color: var(--p-red-600); font-size: .8rem; }
@media (max-width: 640px) { .duo { grid-template-columns: 1fr; } }
</style>
