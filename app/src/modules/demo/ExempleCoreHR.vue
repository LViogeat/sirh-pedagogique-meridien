<script setup>
// =============================================================================
// Comment lire le référentiel — les six appels que vous utiliserez le plus.
//
// Aucun de ces écrans n'écrit dans le Core HR : il est en LECTURE SEULE,
// et la base refuserait toute écriture. Votre module stocke ses propres
// données dans ses propres tables, en ne gardant que le personne_id.
// =============================================================================

import { ref, onMounted } from 'vue'
import { getEmployes, getServices, getPostes, getRef,
         getHistoriqueRemuneration, useSession,
         formatDate, formatEuro, anciennete } from '@/socle/sdk'

const session = useSession()

const salaries = ref([])
const services = ref([])
const vacants = ref([])
const typesContrat = ref([])
const carriere = ref([])
const choisi = ref(null)

onMounted(async () => {
  salaries.value     = await getEmployes({ typeContrat: 'CDD' })
  services.value     = await getServices()
  vacants.value      = await getPostes({ vacants: true })
  typesContrat.value = await getRef('type_contrat')
})

async function voirCarriere(id) {
  choisi.value = id
  carriere.value = id ? await getHistoriqueRemuneration(id) : []
}
</script>

<template>
  <PageHeader titre="Lire le Core HR"
              sousTitre="Les appels du SDK, démontrés un par un" />

  <div class="grille">
    <!-- 1 ------------------------------------------------------------------ -->
    <section class="bloc">
      <h2>getEmployes({ typeContrat: 'CDD' })</h2>
      <p>Les salariés présents, avec filtres facultatifs combinables :
         <code>recherche</code>, <code>serviceId</code>, <code>typeContrat</code>,
         <code>managerId</code>, <code>etablissementId</code>.</p>
      <DataTable :value="salaries" size="small" :rows="5" paginator>
        <Column field="matricule" header="Matricule" />
        <Column field="nom_complet" header="Nom" />
        <Column field="service" header="Service" />
        <Column header="Fin prévue">
          <template #body="{ data }">{{ formatDate(data.date_fin_prevue) }}</template>
        </Column>
      </DataTable>
    </section>

    <!-- 2 ------------------------------------------------------------------ -->
    <section class="bloc">
      <h2>getPostes({ vacants: true })</h2>
      <p>Les positions ouvertes sans titulaire. Un poste vacant ne se décrète pas,
         il se calcule — c’est le point d’accroche d’un module Recrutement.</p>
      <DataTable :value="vacants" size="small" :rows="5" paginator>
        <Column field="libelle" header="Poste" />
        <Column field="service" header="Service" />
      </DataTable>
    </section>

    <!-- 3 ------------------------------------------------------------------ -->
    <section class="bloc">
      <h2>getServices()</h2>
      <p>L’organisation, avec responsable et effectif.</p>
      <DataTable :value="services" size="small" :rows="5" paginator>
        <Column field="service" header="Service" />
        <Column field="responsable" header="Responsable">
          <template #body="{ data }">{{ data.responsable || '— non pourvu —' }}</template>
        </Column>
        <Column field="effectif" header="Effectif" />
      </DataTable>
    </section>

    <!-- 4 ------------------------------------------------------------------ -->
    <section class="bloc">
      <h2>getRef('type_contrat')</h2>
      <p>Une liste de référence, à brancher directement sur un <code>&lt;Select&gt;</code>.
         Accepte aussi <code>civilite</code>, <code>motif_cdd</code>,
         <code>motif_sortie</code>, <code>csp</code>, <code>type_avenant</code>.</p>
      <div class="puces">
        <Tag v-for="t in typesContrat" :key="t.code" :value="`${t.code} — ${t.libelle}`"
             severity="secondary" />
      </div>
    </section>

    <!-- 5 ------------------------------------------------------------------ -->
    <section class="bloc large">
      <h2>getHistoriqueRemuneration(personneId)</h2>
      <p>La carrière salariale, avenant par avenant, avec l’évolution déjà calculée.
         Choisissez un salarié :</p>
      <EmployeSelect :modelValue="choisi" @update:modelValue="voirCarriere"
                     label="" placeholder="Rechercher un salarié…" class="select" />
      <DataTable v-if="carriere.length" :value="carriere" size="small" class="marge">
        <Column header="Date d’effet">
          <template #body="{ data }">{{ formatDate(data.date_effet) }}</template>
        </Column>
        <Column field="type_avenant" header="Événement" />
        <Column header="Salaire">
          <template #body="{ data }">{{ formatEuro(data.salaire) }}</template>
        </Column>
        <Column header="Évolution">
          <template #body="{ data }">
            {{ data.evolution_pct === null ? '—' : `${data.evolution_pct} %` }}
          </template>
        </Column>
      </DataTable>
    </section>

    <!-- 6 ------------------------------------------------------------------ -->
    <section class="bloc large">
      <h2>useSession() — deux axes à ne pas confondre</h2>
      <div class="duo">
        <div class="encadre">
          <h3>session.module — <em>réel</em></h3>
          <p class="valeur">{{ session.module || 'aucun' }}</p>
          <p>Vient de votre compte. Détermine sur quelles tables vous pouvez
             <strong>écrire</strong>. Appliqué <strong>par la base</strong> :
             le modifier dans le code ne changerait rien.</p>
        </div>
        <div class="encadre">
          <h3>session.profilRH — <em>simulé</em></h3>
          <p class="valeur">{{ session.profilRH }}</p>
          <p v-if="session.employe">
            Incarne {{ session.employe.nom_complet }},
            {{ session.equipe.length }} personne(s) dans son équipe.
          </p>
          <p>Se change dans la barre du haut. Détermine ce que votre écran
             <strong>affiche</strong>. Aucun effet sur les droits — c’est un
             outil de conception : <em>qu’est-ce qu’un manager doit voir ?</em></p>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.grille { display: grid; gap: 1rem; grid-template-columns: repeat(auto-fit, minmax(23rem, 1fr)); }
.bloc {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1.1rem 1.25rem; min-width: 0;
}
.bloc.large { grid-column: 1 / -1; }
h2 { margin: 0 0 .4rem; font-size: .9rem; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
h3 { margin: 0 0 .3rem; font-size: .85rem; }
p  { margin: 0 0 .9rem; font-size: .85rem; color: var(--p-text-muted-color); }
code { background: var(--p-surface-200); padding: 0 .25rem; border-radius: 4px; font-size: .85em; }
.puces { display: flex; flex-wrap: wrap; gap: .4rem; }
.select { max-width: 26rem; }
.marge { margin-top: 1rem; }
.duo { display: grid; gap: 1rem; grid-template-columns: 1fr 1fr; }
.encadre { border: 1px solid var(--p-surface-200); border-radius: 10px; padding: 1rem; }
.valeur { font-size: 1.2rem; font-weight: 600; color: var(--p-text-color); margin-bottom: .6rem; }
@media (max-width: 760px) { .duo { grid-template-columns: 1fr; } }
</style>
