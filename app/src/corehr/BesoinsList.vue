<script setup>
/* =============================================================================
   L'ÉCRAN DE RÉFÉRENCE — celui que vous dupliquez pour écrire les vôtres.

   Il fait ce que fait n'importe quel écran de liste d'un SIRH :
     1. il charge des listes de valeurs pour ses filtres,
     2. il charge des données filtrées depuis le socle,
     3. il les affiche dans un tableau triable.

   ATTENTION — cet écran est en LECTURE SEULE, comme tout le socle. Il montre
   les besoins de la chaîne entière, tous types confondus, pour que chacun voie
   d'où vient sa matière. Il ne comporte aucun bouton d'action : prendre un
   besoin en charge est quelque chose que VOTRE module fait, dans VOS écrans.

   Chaque bloc ci-dessous est commenté. Pour votre propre écran, copiez ce
   fichier entier dans votre chat IA et demandez-lui la même chose pour vos
   données — la structure est faite pour être reprise telle quelle.
   ========================================================================== */

import { ref, computed, onMounted, watch } from 'vue'
import { getBesoins, getEtablissements, getReferentiels, formatDate, toast } from '@/socle/sdk'
import { libelleGroupe } from '@/socle/groupes'
import { monModule } from '@/socle/modules'

/* ── 1. L'état de l'écran ──────────────────────────────────────────────────
   `ref()` crée une valeur réactive : quand elle change, l'affichage suit.
   On sépare toujours les DONNÉES (besoins, etablissements) des FILTRES
   (typeBesoin, statut…) et de l'état d'attente (chargement).            */

const besoins = ref([])
const etablissements = ref([])
const referentiels = ref({})
const chargement = ref(true)

/* Le filtre s'ouvre par défaut sur le type que VOTRE module consomme :
   on arrive directement sur sa matière. Les trois modules qui n'en
   consomment pas voient tout. */
const typeBesoin = ref(monModule?.typeBesoin ?? null)
const statut = ref('ouvert')
const etablissementId = ref(null)
const priorite = ref(null)

/* ── 2. Le chargement des données ──────────────────────────────────────────
   Un seul appel au socle, avec les filtres en cours. Les valeurs nulles sont
   ignorées par le SDK : pas besoin de construire l'URL à la main.
   `try / finally` garantit que le voyant d'attente s'éteint, même en cas
   d'erreur.                                                             */

async function charger() {
  chargement.value = true
  try {
    besoins.value = await getBesoins({
      typeBesoin: typeBesoin.value,
      statut: statut.value,
      etablissementId: etablissementId.value,
      priorite: priorite.value,
    })
  } catch (erreur) {
    toast.erreur(erreur.message)
    besoins.value = []
  } finally {
    chargement.value = false
  }
}

/* Au montage de l'écran : les listes de valeurs d'abord, puis les données.
   `Promise.all` lance les deux appels en parallèle plutôt qu'à la suite.  */
onMounted(async () => {
  ;[etablissements.value, referentiels.value] = await Promise.all([
    getEtablissements(),
    getReferentiels(),
  ])
  await charger()
})

/* Dès qu'un filtre change, on recharge. C'est tout le câblage nécessaire. */
watch([typeBesoin, statut, etablissementId, priorite], charger)

/* ── 3. Les valeurs calculées ──────────────────────────────────────────────
   `computed()` se recalcule tout seul quand ce qu'il lit change. À utiliser
   pour tout ce qui se DÉDUIT des données — jamais pour les stocker.     */

const compteurs = computed(() => ({
  total: besoins.value.length,
  hautes: besoins.value.filter((b) => b.priority === 'haute').length,
  pris: besoins.value.filter((b) => b.handled_by_module).length,
}))

const severitePriorite = (code) =>
  ({ haute: 'danger', moyenne: 'warn', basse: 'secondary' })[code] || 'secondary'

const severiteStatut = (code) =>
  ({ ouvert: 'info', pris_en_charge: 'warn', cloture: 'success' })[code] || 'secondary'
</script>

<template>
  <!-- ── 4. L'en-tête ────────────────────────────────────────────────────── -->
  <PageHeader
    titre="Besoins identifiés"
    :sousTitre="`${compteurs.total} besoin(s) · ${compteurs.hautes} prioritaire(s) · ${compteurs.pris} déjà pris en charge`"
  />

  <!-- ── 5. Ce que fait cet écran, et ce qu'il ne fait pas ────────────────── -->
  <Message severity="info" :closable="false" class="bandeau">
    <strong>Écran de consultation.</strong>
    Le socle RH est en lecture seule : ces besoins sont produits par le système
    d'évaluation, personne ne les saisit à la main.
    <template v-if="monModule?.typeBesoin">
      Les besoins de type
      <strong>« {{ monModule.typeBesoin }} »</strong> sont ceux que
      <strong>{{ monModule.label }}</strong> traite. Les prendre en charge et
      les clôturer se fait depuis vos propres écrans, avec
      <code>prendreEnChargeBesoin()</code> et <code>cloturerBesoin()</code>.
    </template>
    <template v-else-if="monModule">
      {{ monModule.label }} ne consomme pas de besoins identifiés : il travaille
      directement sur les salariés, les contrats et l'organisation.
    </template>
  </Message>

  <!-- ── 6. Les filtres ──────────────────────────────────────────────────────
       Un `Select` affiche `optionLabel` et renvoie `optionValue`. Les listes
       viennent de GET /referentiels : les libellés français sont déjà là, on
       ne les écrit jamais en dur dans un écran.                           -->
  <div class="filtres">
    <Select v-model="typeBesoin" :options="referentiels.type_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Tous les types" showClear />

    <Select v-model="statut" :options="referentiels.statut_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Tous les statuts" showClear />

    <Select v-model="priorite" :options="referentiels.priorite_besoin"
            optionLabel="label" optionValue="code"
            placeholder="Toutes les priorités" showClear />

    <Select v-model="etablissementId" :options="etablissements"
            optionLabel="name" optionValue="id"
            placeholder="Tous les établissements" showClear />
  </div>

  <!-- ── 7. Le tableau ───────────────────────────────────────────────────────
       `:value` reçoit les lignes, `dataKey` dit quel champ les identifie.
       Un `<Column>` sans template affiche directement le champ ; avec un
       template `#body`, on décide de l'affichage.                         -->
  <DataTable
    :value="besoins" :loading="chargement" dataKey="id"
    paginator :rows="20" :rowsPerPageOptions="[20, 50, 100]"
    removableSort stripedRows size="small"
    currentPageReportTemplate="{first} à {last} sur {totalRecords}"
    paginatorTemplate="FirstPageLink PrevPageLink CurrentPageReport NextPageLink LastPageLink RowsPerPageDropdown"
  >
    <template #empty>Aucun besoin ne correspond à ces critères.</template>

    <Column field="need_type_label" header="Type" sortable style="width: 8rem" />

    <Column field="priority" header="Priorité" sortable style="width: 8rem">
      <template #body="{ data }">
        <Tag :value="data.priority_label" :severity="severitePriorite(data.priority)" />
      </template>
    </Column>

    <Column field="position_title" header="Poste" sortable />
    <Column field="establishment_name" header="Établissement" sortable />

    <Column field="employee_name" header="Salarié" sortable>
      <template #body="{ data }">
        <!-- Un besoin de recrutement ne concerne personne : le champ est vide. -->
        {{ data.employee_name || '—' }}
      </template>
    </Column>

    <Column field="skill_label" header="Compétence" sortable>
      <template #body="{ data }">{{ data.skill_label || '—' }}</template>
    </Column>

    <Column field="origin" header="Origine">
      <template #body="{ data }">
        <span class="origine" v-tooltip.top="data.origin">{{ data.origin }}</span>
      </template>
    </Column>

    <Column field="detected_on" header="Détecté le" sortable style="width: 8rem">
      <template #body="{ data }">{{ formatDate(data.detected_on) }}</template>
    </Column>

    <Column field="status" header="Statut" sortable style="width: 10rem">
      <template #body="{ data }">
        <Tag :value="data.status_label" :severity="severiteStatut(data.status)" />
      </template>
    </Column>

    <!-- Quel module a pris le besoin. Jamais le code brut : le libellé complet. -->
    <Column field="handled_by_module" header="Traité par" sortable style="width: 13rem">
      <template #body="{ data }">
        <span v-if="data.handled_by_module">{{ libelleGroupe(data.handled_by_module) }}</span>
        <span v-else class="disponible">Disponible</span>
      </template>
    </Column>
  </DataTable>
</template>

<style scoped>
.bandeau { margin-bottom: 1rem; }
.bandeau code { font-size: .82rem; }
.filtres { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 1rem; }
.filtres > * { min-width: 13rem; }
.origine {
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
  overflow: hidden; font-size: .8rem; color: var(--p-text-muted-color);
}
.disponible { color: var(--p-text-muted-color); }
</style>
