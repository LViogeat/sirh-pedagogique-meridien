import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import Components from 'unplugin-vue-components/vite'
import { PrimeVueResolver } from '@primevue/auto-import-resolver'

export default defineConfig({
  plugins: [
    vue(),
    // Auto-import des composants PrimeVue : <DataTable>, <Button>, <Dialog>…
    // s'utilisent SANS ligne d'import. C'est délibéré : ça supprime l'erreur
    // la plus fréquente quand on colle du code produit par une IA.
    Components({ resolvers: [PrimeVueResolver()], dts: false }),
  ],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  server: {
    hmr: {
      // L'overlay d'erreur de Vite recouvre TOUTE l'application : impossible
      // même de changer d'écran. C'est exactement le « écran noir » contre
      // lequel le socle est conçu. On le coupe : l'erreur est alors affichée
      // par ModuleEnErreur, qui nomme le module fautif, laisse le menu
      // utilisable, et propose le détail technique à coller à l'IA.
      overlay: false,
    },
  },
})
