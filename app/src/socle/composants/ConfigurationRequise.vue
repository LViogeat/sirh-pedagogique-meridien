<script setup>
/**
 * Le premier écran qu'un groupe voit s'il n'a pas encore créé son `.env`.
 *
 * Une trace d'appel JavaScript devant un étudiant non-développeur, au premier
 * lancement, c'est le pire départ possible. Cet écran dit exactement quoi
 * créer, et rien d'autre.
 */
import { API_URL, API_TOKEN, MODULE_CODE } from '../config'
</script>

<template>
  <div class="page">
    <div class="carte">
      <i class="pi pi-key" />
      <h1>Il manque votre fichier de configuration</h1>
      <p>
        L’application ne sait pas encore quel groupe vous êtes. Créez un fichier
        nommé <code>.env</code> <strong>à côté de <code>package.json</code></strong>,
        dans le dossier <code>app/</code>, avec ces deux lignes :
      </p>

      <pre>VITE_API_TOKEN=le-jeton-de-votre-groupe
VITE_MODULE_CODE=le-code-de-votre-groupe</pre>

      <p>
        L’intervenant vous a remis les deux valeurs. Le code est l’un de
        <code>rec</code>, <code>form</code>, <code>mob</code>, <code>gta</code>,
        <code>portail</code>, <code>onb</code>.
      </p>

      <p class="relance">
        Enregistrez, puis <strong>relancez <code>npm run dev</code></strong> :
        une variable d’environnement n’est lue qu’au démarrage.
      </p>

      <ul class="etat">
        <li :class="{ ok: !!API_TOKEN }">
          <i :class="API_TOKEN ? 'pi pi-check' : 'pi pi-times'" />
          <code>VITE_API_TOKEN</code>
          <span>{{ API_TOKEN ? 'renseigné' : 'manquant' }}</span>
        </li>
        <li :class="{ ok: !!MODULE_CODE }">
          <i :class="MODULE_CODE ? 'pi pi-check' : 'pi pi-times'" />
          <code>VITE_MODULE_CODE</code>
          <span>{{ MODULE_CODE || 'manquant' }}</span>
        </li>
        <li class="ok">
          <i class="pi pi-check" />
          <code>VITE_API_URL</code>
          <span>{{ API_URL }}</span>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; display: grid; place-items: center; padding: 2rem 1rem;
        background: var(--p-surface-100); }
.carte {
  max-width: 38rem; background: var(--p-surface-0);
  border: 1px solid var(--p-surface-200); border-radius: 14px; padding: 2.25rem 2rem;
}
.carte > i { font-size: 1.8rem; color: var(--p-primary-color); }
h1 { font-size: 1.25rem; margin: .75rem 0 1rem; }
p { color: var(--p-text-muted-color); line-height: 1.6; margin: 0 0 1rem; }
pre {
  background: var(--p-surface-100); border-radius: 8px; padding: .85rem 1rem;
  font-size: .85rem; margin: 0 0 1rem; overflow-x: auto;
}
.relance { color: var(--p-text-color); }
.etat { list-style: none; margin: 1.5rem 0 0; padding: 0; border-top: 1px solid var(--p-surface-200); }
.etat li {
  display: flex; align-items: center; gap: .6rem; padding: .55rem 0;
  font-size: .85rem; color: var(--p-red-500);
}
.etat li.ok { color: var(--p-text-muted-color); }
.etat li span { margin-left: auto; }
</style>
