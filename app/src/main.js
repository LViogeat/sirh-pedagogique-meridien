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

import PageHeader from './socle/composants/PageHeader.vue'
import StatCard from './socle/composants/StatCard.vue'

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
    accept: 'Oui', reject: 'Non', choose: 'Choisir', cancel: 'Annuler', clear: 'Effacer',
  },
})
app.use(ToastService)
app.use(ConfirmationService)
app.directive('tooltip', Tooltip)

// Deux composants globaux, pour qu'un écran de module n'ait pas à les importer.
app.component('PageHeader', PageHeader)
app.component('StatCard', StatCard)

app.use(router)
app.mount('#app')
