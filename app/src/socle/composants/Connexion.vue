<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { connexion } from '../session'
import { estConfigure } from '../supabase'

const email = ref('')
const motDePasse = ref('')
const erreur = ref('')
const occupe = ref(false)
const router = useRouter()
const route = useRoute()

async function valider() {
  erreur.value = ''
  occupe.value = true
  try {
    await connexion(email.value.trim(), motDePasse.value)
    router.push(route.query.suite || '/')
  } catch (e) {
    erreur.value = e.message
  } finally {
    occupe.value = false
  }
}
</script>

<template>
  <div class="page-connexion">
    <form class="carte" @submit.prevent="valider">
      <h1>SIRH Meridien</h1>
      <p class="sous-titre">Master SIRH — Université Paris 1 Panthéon-Sorbonne</p>

      <Message v-if="!estConfigure()" severity="warn" :closable="false">
        La connexion à la base n’est pas configurée.
        Renseignez <code>src/socle/config.js</code>.
      </Message>

      <div class="champ">
        <label for="email">Adresse e-mail</label>
        <InputText id="email" v-model="email" type="email" autocomplete="username" required />
      </div>

      <div class="champ">
        <label for="mdp">Mot de passe</label>
        <Password id="mdp" v-model="motDePasse" :feedback="false" toggleMask
                  inputId="mdp" autocomplete="current-password" required fluid />
      </div>

      <Message v-if="erreur" severity="error" :closable="false">{{ erreur }}</Message>

      <Button type="submit" label="Se connecter" icon="pi pi-sign-in"
              :loading="occupe" fluid />

      <p class="aide">
        Vos identifiants vous sont remis par l’intervenant.
        Votre compte détermine le module sur lequel vous pouvez écrire.
      </p>
    </form>
  </div>
</template>

<style scoped>
.page-connexion {
  min-height: 100vh; display: grid; place-items: center; padding: 1.5rem;
  background: var(--p-surface-100);
}
.carte {
  width: min(26rem, 100%); display: flex; flex-direction: column; gap: 1rem;
  background: var(--p-surface-0); padding: 2rem; border-radius: 14px;
  border: 1px solid var(--p-surface-200);
}
h1 { margin: 0; font-size: 1.5rem; }
.sous-titre { margin: -.5rem 0 .5rem; color: var(--p-text-muted-color); font-size: .85rem; }
.champ { display: flex; flex-direction: column; gap: .4rem; }
label { font-size: .85rem; font-weight: 500; }
.aide { margin: 0; font-size: .8rem; color: var(--p-text-muted-color); }
code { background: var(--p-surface-200); padding: 0 .25rem; border-radius: 4px; }
</style>
