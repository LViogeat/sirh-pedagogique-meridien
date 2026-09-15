<script setup>
/**
 * La coque de l'application.
 *
 * Le menu montre le SIRH entier : le socle, puis les six modules du cours.
 * Un seul est ouvrable — le vôtre. Les cinq autres sont grisés : ils
 * appartiennent à d'autres groupes, et vous n'avez aucun droit dessus,
 * ni dans l'application ni dans la base.
 */
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import { modules, monModule } from '../modules'
import BarriereErreur from './BarriereErreur.vue'

const route = useRoute()
const ouvert = ref(false)
</script>

<template>
  <div class="shell">
    <aside class="sidebar" :class="{ ouvert }">
      <div class="marque">
        <i class="pi pi-building-columns" />
        <div>
          <strong>Sorbonne-Hôtel</strong>
          <small>SIRH · Master 2 · Paris 1</small>
        </div>
      </div>

      <nav>
        <!-- La porte d'entrée du logiciel, hors de tout module. -->
        <RouterLink to="/accueil" class="lien accueil"
                    :class="{ actif: route.path === '/accueil' }"
                    @click="ouvert = false">
          <i class="pi pi-home" />
          <span>Accueil</span>
        </RouterLink>

        <div v-for="m in modules" :key="m.code" class="groupe">
          <!-- Le socle : consultation, pour tout le monde. -->
          <template v-if="m.socle">
            <div class="titre-groupe socle">
              <i :class="m.icon" />
              <span>{{ m.label }}</span>
              <Tag value="lecture seule" severity="secondary" />
            </div>
            <RouterLink
              v-for="r in m.routes.filter(x => !x.masque)" :key="r.path"
              :to="`/${m.code}/${r.path}`" class="lien"
              :class="{ actif: route.path === `/${m.code}/${r.path}` }"
              @click="ouvert = false"
            >{{ r.label }}</RouterLink>
          </template>

          <!-- Votre module : le seul sur lequel vous travaillez. -->
          <template v-else-if="m.mien">
            <div class="titre-groupe mien">
              <i :class="m.icon" />
              <span>{{ m.label }}</span>
              <Tag value="votre groupe" severity="success" />
            </div>
            <RouterLink
              v-for="r in m.routes.filter(x => !x.masque)" :key="r.path"
              :to="`/${m.code}/${r.path}`" class="lien"
              :class="{ actif: route.path === `/${m.code}/${r.path}` }"
              @click="ouvert = false"
            >{{ r.label }}</RouterLink>
            <p v-if="!m.routes.length" class="a-creer">
              Aucun écran pour l’instant. Créez
              <code>src/modules/{{ m.code }}/module.js</code>.
            </p>
          </template>

          <!-- Les cinq autres : visibles, pour situer votre module dans
               l'ensemble, mais fermés. -->
          <template v-else>
            <div class="titre-groupe verrouille"
                 v-tooltip.right="`${m.perimetre}. Module d’un autre groupe : vous n’y avez pas accès.`">
              <i :class="m.icon" />
              <span>{{ m.label }}</span>
              <i class="pi pi-lock cadenas" />
            </div>
          </template>
        </div>
      </nav>

      <div class="pied">
        <small v-if="monModule">Vous êtes le groupe <strong>{{ monModule.label }}</strong>.</small>
        <small v-else class="alerte">Aucun module attribué — vérifiez app/.env.</small>
      </div>
    </aside>

    <div class="principal">
      <header class="topbar">
        <Button class="burger" icon="pi pi-bars" text severity="secondary"
                aria-label="Menu" @click="ouvert = !ouvert" />

        <div class="fil">
          <span>{{ route.meta.moduleLabel }}</span>
          <i class="pi pi-angle-right" />
          <strong>{{ route.meta.label }}</strong>
        </div>

        <div class="outils">
          <Tag v-if="monModule" :value="monModule.label" severity="info" />
        </div>
      </header>

      <main class="contenu">
        <!-- Une erreur de rendu dans un module s'arrête ici. -->
        <BarriereErreur>
          <RouterView />
        </BarriereErreur>
      </main>
    </div>

    <div v-if="ouvert" class="voile" @click="ouvert = false" />
  </div>
</template>

<style scoped>
.shell { display: flex; min-height: 100vh; background: var(--p-surface-100); }

.sidebar {
  width: 17rem; flex: none; background: var(--p-surface-0);
  border-right: 1px solid var(--p-surface-200);
  display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh;
}
.marque { display: flex; gap: .75rem; align-items: center; padding: 1.15rem 1rem; border-bottom: 1px solid var(--p-surface-200); }
.marque i { font-size: 1.4rem; color: var(--p-primary-color); }
.marque strong { display: block; font-size: .95rem; }
.marque small { color: var(--p-text-muted-color); font-size: .72rem; }

nav { flex: 1; overflow-y: auto; padding: .75rem .5rem; }
.groupe { margin-bottom: .85rem; }
.titre-groupe {
  display: flex; align-items: center; gap: .5rem; padding: .4rem .6rem;
  font-size: .72rem; font-weight: 600; text-transform: uppercase;
  letter-spacing: .03em; color: var(--p-text-muted-color);
}
.titre-groupe span { flex: 1; text-transform: none; font-size: .8rem; letter-spacing: 0; }
.titre-groupe.mien { color: var(--p-primary-color); }
.titre-groupe.verrouille { opacity: .42; cursor: not-allowed; }
.titre-groupe.verrouille .cadenas { font-size: .7rem; }
.titre-groupe :deep(.p-tag) { font-size: .58rem; padding: .05rem .3rem; }

.lien {
  display: block; padding: .45rem .75rem .45rem 1.95rem; border-radius: 7px;
  color: var(--p-text-color); text-decoration: none; font-size: .875rem;
}
.lien:hover { background: var(--p-surface-100); }
.lien.accueil {
  display: flex; align-items: center; gap: .5rem;
  padding: .5rem .6rem; margin-bottom: .85rem; font-weight: 500;
}
.lien.accueil i { font-size: .9rem; }
.lien.actif { background: var(--p-primary-50); color: var(--p-primary-700); font-weight: 500; }
.a-creer {
  margin: .2rem .6rem; font-size: .75rem; color: var(--p-text-muted-color); line-height: 1.5;
}
.a-creer code { font-size: .72rem; }

.pied { padding: .75rem 1rem; border-top: 1px solid var(--p-surface-200); color: var(--p-text-muted-color); }
.pied .alerte { color: var(--p-red-500); }

.principal { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.topbar {
  display: flex; align-items: center; gap: 1rem; padding: .6rem 1.25rem;
  background: var(--p-surface-0); border-bottom: 1px solid var(--p-surface-200);
  position: sticky; top: 0; z-index: 10; flex-wrap: wrap;
}
.burger { display: none; }
.fil { font-size: .85rem; color: var(--p-text-muted-color); display: flex; align-items: center; gap: .35rem; }
.fil strong { color: var(--p-text-color); }
.outils { margin-left: auto; display: flex; align-items: center; gap: .6rem; }

.contenu { padding: 1.5rem; flex: 1; max-width: 100%; }
.voile { display: none; }

@media (max-width: 900px) {
  .sidebar {
    position: fixed; z-index: 30; transform: translateX(-100%);
    transition: transform .2s ease;
  }
  .sidebar.ouvert { transform: none; }
  .burger { display: inline-flex; }
  .voile { display: block; position: fixed; inset: 0; background: rgba(0,0,0,.35); z-index: 20; }
  .contenu { padding: 1rem; }
}
</style>
