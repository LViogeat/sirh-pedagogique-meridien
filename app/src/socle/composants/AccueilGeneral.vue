<script setup>
/**
 * La page d'accueil du logiciel.
 *
 * Elle répond à trois questions, dans cet ordre : de quelle entreprise
 * parle-t-on, comment le système produit-il du travail pour les modules, et
 * qui fait quoi.
 *
 * Les chiffres sont lus en direct : après une remise à zéro, ils changent.
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { getEtablissements, getPostes, getBesoins, getEntretiens } from '@/socle/sdk'
import { modulesEtudiants } from '../modules'

const router = useRouter()

const etablissements = ref([])
const postesAPourvoir = ref([])
const besoins = ref([])
const entretiens = ref([])
const chargement = ref(true)
const erreur = ref(null)

onMounted(async () => {
  try {
    ;[etablissements.value, postesAPourvoir.value, besoins.value, entretiens.value] =
      await Promise.all([
        getEtablissements(),
        getPostes({ vacants: true }),
        getBesoins({ statut: 'ouvert' }),
        getEntretiens(),
      ])
  } catch (e) {
    erreur.value = e.message
  } finally {
    chargement.value = false
  }
})

const effectif = computed(() =>
  etablissements.value.reduce((total, e) => total + e.headcount, 0))

const parType = computed(() => {
  const compte = { recrutement: 0, formation: 0, mobilite: 0 }
  for (const b of besoins.value) compte[b.need_type] += 1
  return compte
})

const ecartsConstates = computed(() =>
  entretiens.value.reduce((total, e) => total + e.skill_gaps_count, 0))

function ouvrir(module) {
  if (!module.mien) return
  const premier = module.routes[0]
  if (premier) router.push(`/${module.code}/${premier.path}`)
}
</script>

<template>
  <PageHeader
    titre="SIRH Sorbonne-Hôtel"
    sousTitre="Chaîne hôtelière française · 5 établissements · Master 2 SIRH, Université Paris 1 Panthéon-Sorbonne"
  />

  <div v-if="chargement" class="attente"><ProgressSpinner /></div>

  <Message v-else-if="erreur" severity="error" :closable="false">
    {{ erreur }}
  </Message>

  <template v-else>
    <!-- ── L'entreprise en cinq chiffres ──────────────────────────────── -->
    <div class="cartes">
      <StatCard titre="Établissements" :valeur="etablissements.length"
                icone="pi pi-building" precision="Paris, Lyon, Bordeaux, Nice, Annecy" />
      <StatCard titre="Salariés présents" :valeur="effectif"
                icone="pi pi-users" precision="tous établissements confondus" />
      <StatCard titre="Postes à pourvoir" :valeur="postesAPourvoir.length"
                icone="pi pi-briefcase" precision="effectif réel sous l’effectif cible" />
      <StatCard titre="Entretiens annuels" :valeur="entretiens.length"
                icone="pi pi-comments" :precision="`${ecartsConstates} écarts de compétence constatés`" />
      <StatCard titre="Besoins ouverts" :valeur="besoins.length"
                icone="pi pi-flag"
                :precision="`${parType.recrutement} recrutement · ${parType.formation} formation · ${parType.mobilite} mobilité`" />
    </div>

    <!-- ── La chaîne du dispositif ────────────────────────────────────── -->
    <Card class="chaine">
      <template #title>Comment le travail arrive jusqu’à vous</template>
      <template #content>
        <div class="etapes">
          <div class="etape">
            <i class="pi pi-comments" />
            <strong>L’entretien annuel</strong>
            <p>
              Le manager constate un niveau de compétence, mesure l’atteinte des
              objectifs et recueille les souhaits d’évolution.
            </p>
          </div>
          <i class="pi pi-arrow-right fleche" />
          <div class="etape">
            <i class="pi pi-flag" />
            <strong>Le besoin identifié</strong>
            <p>
              Trois règles transforment ces constats en besoins : un écart de
              compétence en <em>formation</em>, un souhait tenu en
              <em>mobilité</em>, un sous-effectif en <em>recrutement</em>.
            </p>
          </div>
          <i class="pi pi-arrow-right fleche" />
          <div class="etape">
            <i class="pi pi-th-large" />
            <strong>Le module qui agit</strong>
            <p>
              Un groupe prend le besoin en charge, le traite dans son module,
              puis le clôture. La chaîne devient visible de bout en bout.
            </p>
          </div>
        </div>

        <Message severity="secondary" :closable="false" class="rappel">
          Le socle RH est en <strong>lecture seule</strong>. Personne ne saisit
          ces besoins à la main : ils sont produits par le système d’évaluation.
        </Message>
      </template>
    </Card>

    <!-- ── Les six modules ────────────────────────────────────────────── -->
    <h2 class="titre-section">Les six modules du SIRH</h2>
    <div class="modules">
      <div v-for="m in modulesEtudiants" :key="m.code"
           class="module" :class="{ mien: m.mien }"
           @click="ouvrir(m)">
        <div class="entete">
          <i :class="m.icon" />
          <strong>{{ m.label }}</strong>
          <Tag v-if="m.mien" value="votre groupe" severity="success" />
          <i v-else class="pi pi-lock cadenas" />
        </div>
        <p class="perimetre">{{ m.perimetre }}</p>
        <div class="pied-module">
          <Tag v-if="m.typeBesoin" :value="`besoins : ${m.typeBesoin}`" severity="secondary" />
          <Tag v-else value="pas de besoins consommés" severity="secondary" />
          <span v-if="m.mien && m.routes.length" class="ecrans">
            {{ m.routes.length }} écran(s) — ouvrir
          </span>
          <span v-else-if="m.mien" class="ecrans">à créer</span>
        </div>
      </div>
    </div>
  </template>
</template>

<style scoped>
.attente { display: grid; place-items: center; min-height: 40vh; }

.cartes {
  display: grid; grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 1rem; margin-bottom: 1.5rem;
}

.chaine { margin-bottom: 1.75rem; }
.etapes { display: flex; align-items: stretch; gap: 1rem; flex-wrap: wrap; }
.etape { flex: 1 1 15rem; }
.etape > i { font-size: 1.3rem; color: var(--p-primary-color); }
.etape strong { display: block; margin: .4rem 0 .3rem; }
.etape p { margin: 0; font-size: .875rem; color: var(--p-text-muted-color); line-height: 1.55; }
.fleche { align-self: center; color: var(--p-surface-400); }
.rappel { margin-top: 1.25rem; }

.titre-section { font-size: 1.05rem; margin: 0 0 .85rem; }
.modules { display: grid; grid-template-columns: repeat(auto-fit, minmax(19rem, 1fr)); gap: 1rem; }
.module {
  background: var(--p-surface-0); border: 1px solid var(--p-surface-200);
  border-radius: 12px; padding: 1.1rem 1.25rem; opacity: .55;
}
.module.mien {
  opacity: 1; border-color: var(--p-primary-color); cursor: pointer;
}
.module.mien:hover { background: var(--p-primary-50); }
.entete { display: flex; align-items: center; gap: .5rem; }
.entete i:first-child { color: var(--p-primary-color); }
.entete strong { flex: 1; font-size: .95rem; }
.cadenas { font-size: .8rem; color: var(--p-text-muted-color); }
.perimetre { margin: .5rem 0 .85rem; font-size: .85rem; color: var(--p-text-muted-color); line-height: 1.5; }
.pied-module { display: flex; align-items: center; gap: .5rem; flex-wrap: wrap; }
.pied-module :deep(.p-tag) { font-size: .68rem; }
.ecrans { margin-left: auto; font-size: .8rem; color: var(--p-primary-color); font-weight: 500; }

@media (max-width: 900px) {
  .fleche { display: none; }
}
</style>
