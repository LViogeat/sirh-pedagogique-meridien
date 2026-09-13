<script setup>
// Le shell : barre latérale, barre du haut, zone de contenu.
// AUCUN étudiant ne modifie ce fichier — le menu est déduit des manifestes.
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { modules } from '../modules'
import { useSession, deconnexion, choisirProfilRH } from '../session'
import BarriereErreur from './BarriereErreur.vue'
import EmployeSelect from './EmployeSelect.vue'

const route = useRoute()
const session = useSession()
const ouvert = ref(false)

const PROFILS = [
  { code: 'RH',      libelle: 'RH',       icone: 'pi pi-verified' },
  { code: 'MANAGER', libelle: 'Manager',  icone: 'pi pi-sitemap' },
  { code: 'SALARIE', libelle: 'Salarié',  icone: 'pi pi-user' },
]

const monModule = computed(() => session.module)
const estMonModule = (code) => code === monModule.value

async function changerProfil(code) { await choisirProfilRH(code) }
async function changerEmploye(id)  { await choisirProfilRH(session.profilRH, id) }
</script>

<template>
  <div class="shell">
    <aside class="sidebar" :class="{ ouvert }">
      <div class="marque">
        <i class="pi pi-building-columns" />
        <div>
          <strong>SIRH Meridien</strong>
          <small>Master SIRH · Paris 1</small>
        </div>
      </div>

      <nav>
        <div v-for="m in modules" :key="m.code" class="groupe">
          <!-- Niveau 1 : un module = un dossier. Le socle le place ici. -->
          <div class="titre-groupe" :class="{ mien: estMonModule(m.code) }">
            <i :class="m.icon" />
            <span>{{ m.label }}</span>
            <Tag v-if="estMonModule(m.code)" value="votre module" severity="success" />
          </div>
          <!-- Niveau 2 : les groupes ajoutent ces entrées dans leur module.js. -->
          <RouterLink
            v-for="r in m.routes.filter(x => !x.masque)" :key="r.path"
            :to="`/${m.code}/${r.path}`"
            class="lien"
            :class="{ actif: route.path === `/${m.code}/${r.path}` }"
            @click="ouvert = false"
          >{{ r.label }}</RouterLink>
        </div>
      </nav>

      <div class="pied">
        <small>{{ modules.length - 1 }} module{{ modules.length > 2 ? 's' : '' }} branché{{ modules.length > 2 ? 's' : '' }}</small>
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
          <!-- Profil FONCTIONNEL simulé : change ce qui s'affiche, jamais les droits. -->
          <div class="profil-rh" v-tooltip.bottom="'Profil simulé : change ce que l’écran affiche, pas vos droits'">
            <Button
              v-for="p in PROFILS" :key="p.code"
              :label="p.libelle" :icon="p.icone" size="small"
              :severity="session.profilRH === p.code ? 'primary' : 'secondary'"
              :outlined="session.profilRH !== p.code"
              @click="changerProfil(p.code)"
            />
          </div>

          <EmployeSelect
            v-if="session.profilRH !== 'RH'"
            class="incarner"
            :modelValue="session.employe?.personne_id ?? null"
            placeholder="Incarner un salarié…"
            @update:modelValue="changerEmploye"
          />

          <Divider layout="vertical" />

          <div class="compte">
            <span class="nom">{{ session.profil?.prenom }} {{ session.profil?.nom }}</span>
            <Tag v-if="monModule" :value="monModule" severity="info" />
            <Tag v-else value="sans module" severity="warn"
                 v-tooltip.bottom="'Votre compte n’est rattaché à aucun groupe : vous ne pouvez rien écrire.'" />
          </div>
          <Button icon="pi pi-sign-out" text severity="secondary"
                  aria-label="Se déconnecter" @click="deconnexion" />
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
  width: 16rem; flex: none; background: var(--p-surface-0);
  border-right: 1px solid var(--p-surface-200);
  display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh;
}
.marque { display: flex; gap: .75rem; align-items: center; padding: 1.15rem 1rem; border-bottom: 1px solid var(--p-surface-200); }
.marque i { font-size: 1.4rem; color: var(--p-primary-color); }
.marque strong { display: block; font-size: .95rem; }
.marque small { color: var(--p-text-muted-color); font-size: .72rem; }

nav { flex: 1; overflow-y: auto; padding: .75rem .5rem; }
.groupe { margin-bottom: 1rem; }
.titre-groupe {
  display: flex; align-items: center; gap: .5rem; padding: .4rem .6rem;
  font-size: .72rem; font-weight: 600; text-transform: uppercase;
  letter-spacing: .04em; color: var(--p-text-muted-color);
}
.titre-groupe.mien { color: var(--p-primary-color); }
.titre-groupe :deep(.p-tag) { font-size: .6rem; padding: .05rem .3rem; }
.lien {
  display: block; padding: .45rem .75rem .45rem 1.85rem; border-radius: 7px;
  color: var(--p-text-color); text-decoration: none; font-size: .875rem;
}
.lien:hover { background: var(--p-surface-100); }
.lien.actif { background: var(--p-primary-50); color: var(--p-primary-700); font-weight: 500; }
.pied { padding: .75rem 1rem; border-top: 1px solid var(--p-surface-200); color: var(--p-text-muted-color); }

.principal { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.topbar {
  display: flex; align-items: center; gap: 1rem; padding: .6rem 1.25rem;
  background: var(--p-surface-0); border-bottom: 1px solid var(--p-surface-200);
  position: sticky; top: 0; z-index: 10; flex-wrap: wrap;
}
.burger { display: none; }
.fil { font-size: .85rem; color: var(--p-text-muted-color); display: flex; align-items: center; gap: .35rem; }
.fil strong { color: var(--p-text-color); }
.outils { margin-left: auto; display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
.profil-rh { display: flex; gap: .25rem; }
.incarner { min-width: 15rem; }
.compte { display: flex; align-items: center; gap: .4rem; font-size: .85rem; }
.compte .nom { font-weight: 500; }

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
  .incarner { min-width: 100%; order: 10; }
  .contenu { padding: 1rem; }
}
</style>
