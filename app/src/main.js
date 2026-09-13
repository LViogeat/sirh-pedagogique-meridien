import { createApp } from 'vue'
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'
import ToastService from 'primevue/toastservice'
import ConfirmationService from 'primevue/confirmationservice'
import Tooltip from 'primevue/tooltip'

import 'primeicons/primeicons.css'
import './style.css'

import App from './App.vue'
import { router } from './socle/router'
import { initSession } from './socle/session'

// Les composants du socle sont enregistrés globalement : les étudiants les
// utilisent sans import, comme ceux de PrimeVue.
import PageHeader from './socle/composants/PageHeader.vue'
import StatCard from './socle/composants/StatCard.vue'
import EmployeSelect from './socle/composants/EmployeSelect.vue'
import EmployeCard from './socle/composants/EmployeCard.vue'

async function demarrer() {
  const app = createApp(App)

  app.use(PrimeVue, {
    theme: { preset: Aura, options: { darkModeSelector: '.mode-sombre' } },
    locale: {
      dayNames: ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'],
      dayNamesShort: ['dim', 'lun', 'mar', 'mer', 'jeu', 'ven', 'sam'],
      dayNamesMin: ['D', 'L', 'M', 'M', 'J', 'V', 'S'],
      monthNames: ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                   'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
      monthNamesShort: ['jan', 'fév', 'mar', 'avr', 'mai', 'jun',
                        'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'],
      firstDayOfWeek: 1,
      dateFormat: 'dd/mm/yy',
      emptyMessage: 'Aucun résultat',
      emptyFilterMessage: 'Aucun résultat',
      emptySelectionMessage: 'Aucun élément sélectionné',
      clear: 'Effacer', apply: 'Appliquer', matchAll: 'Tous', matchAny: 'Au moins un',
      accept: 'Oui', reject: 'Non', choose: 'Choisir', upload: 'Envoyer', cancel: 'Annuler',
    },
  })
  app.use(ToastService)
  app.use(ConfirmationService)
  app.directive('tooltip', Tooltip)

  app.component('PageHeader', PageHeader)
  app.component('StatCard', StatCard)
  app.component('EmployeSelect', EmployeSelect)
  app.component('EmployeCard', EmployeCard)

  // La session doit être connue AVANT le premier passage du garde de route,
  // sinon un rechargement de page renverrait un utilisateur connecté vers
  // l'écran de connexion.
  await initSession()

  app.use(router)
  app.mount('#app')
}

demarrer()
