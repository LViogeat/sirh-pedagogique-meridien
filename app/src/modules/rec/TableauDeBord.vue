<!-- libelle: Tableau de bord -->
<script setup>
/**
 * Le tableau de bord du recrutement (story #8).
 *
 * Tout se lit en deux sources : les besoins de recrutement du socle, et nos
 * trois tables. Rien n'est stocké : chaque chiffre se recalcule à l'ouverture.
 */
import { ref, computed, onMounted } from 'vue'
import { getBesoins, sql, formatDate, formatNombre, toast } from '@/socle/sdk'
import { ETAPES as ETAPES_WORKFLOW, REFUS } from './_workflow.js'

const ETAPES = [...ETAPES_WORKFLOW, REFUS]

const besoins = ref([])
const offres = ref([])
const parEtape = ref([])
const embauches = ref([])
const chargement = ref(true)

onMounted(async () => {
  try {
    ;[besoins.value, offres.value, parEtape.value, embauches.value] = await Promise.all([
      getBesoins({ typeBesoin: 'recrutement' }),
      sql(
        `select o.id, o.intitule, o.statut, o.publiee_le, count(c.id)::int as nb
           from offres o left join candidatures c on c.offre_id = o.id
          group by o.id order by o.id`,
      ),
      sql('select etape, count(*)::int as nb from candidatures group by etape'),
      sql(
        `select ca.maj_le, o.besoin_id
           from candidatures ca join offres o on o.id = ca.offre_id
          where ca.etape = 'embauche'`,
      ),
    ])
  } catch (erreur) {
    toast.erreur(erreur.message)
  } finally {
    chargement.value = false
  }
})

const compter = (liste, test) => liste.filter(test).length

const indicateurs = computed(() => {
  const enCours = parEtape.value
    .filter((e) => !['embauche', 'refus'].includes(e.etape))
    .reduce((t, e) => t + e.nb, 0)

  /* Délai de recrutement : de la détection du besoin à l'embauche. */
  const detecteLe = Object.fromEntries(besoins.value.map((b) => [b.id, b.detected_on]))
  const delais = embauches.value
    .filter((e) => e.besoin_id && detecteLe[e.besoin_id])
    .map((e) => (new Date(e.maj_le) - new Date(detecteLe[e.besoin_id])) / 86400000)
  const delaiMoyen = delais.length ? delais.reduce((a, b) => a + b, 0) / delais.length : null

  return {
    ouverts: compter(besoins.value, (b) => b.status === 'ouvert'),
    hautes: compter(besoins.value, (b) => b.status === 'ouvert' && b.priority === 'haute'),
    publiees: compter(offres.value, (o) => o.statut === 'publiee'),
    brouillons: compter(offres.value, (o) => o.statut === 'brouillon'),
    enCours,
    pourvus: compter(besoins.value, (b) => b.status === 'cloture'),
    delaiMoyen,
  }
})

const etapes = computed(() => {
  const nb = Object.fromEntries(parEtape.value.map((e) => [e.etape, e.nb]))
  return ETAPES.map((e) => ({ ...e, nb: nb[e.code] || 0 }))
})

const offresSansCandidat = computed(() =>
  offres.value.filter((o) => o.statut === 'publiee' && o.nb === 0))

const parHotel = computed(() => {
  const lignes = {}
  for (const b of besoins.value) {
    const l = (lignes[b.establishment_id] ??= {
      hotel: b.establishment_name, ville: b.establishment_city,
      ouvert: 0, pris_en_charge: 0, cloture: 0, total: 0,
    })
    l[b.status] += 1
    l.total += 1
  }
  return Object.values(lignes).sort((a, b) => b.ouvert - a.ouvert || a.hotel.localeCompare(b.hotel))
})
</script>

<template>
  <PageHeader titre="Tableau de bord du recrutement"
              sousTitre="Les besoins du socle et l'avancement de nos recrutements, recalculés à l'ouverture" />

  <div class="stats">
    <StatCard titre="Besoins ouverts" :valeur="chargement ? '…' : indicateurs.ouverts"
              icone="pi pi-inbox" :precision="`dont ${indicateurs.hautes} en priorité haute`" />
    <StatCard titre="Offres publiées" :valeur="chargement ? '…' : indicateurs.publiees"
              icone="pi pi-megaphone" :precision="`${indicateurs.brouillons} brouillon(s) à publier`" />
    <StatCard titre="Candidatures en cours" :valeur="chargement ? '…' : indicateurs.enCours"
              icone="pi pi-users" precision="hors embauches et refus" />
    <StatCard titre="Postes pourvus" :valeur="chargement ? '…' : indicateurs.pourvus"
              icone="pi pi-check-circle" precision="besoins clôturés" />
    <StatCard titre="Délai moyen" icone="pi pi-clock"
              :valeur="indicateurs.delaiMoyen === null ? '—' : `${formatNombre(indicateurs.delaiMoyen)} j`"
              precision="de la détection du besoin à l'embauche" />
  </div>

  <div class="grille">
    <Card>
      <template #title>Candidatures par étape</template>
      <template #content>
        <DataTable :value="etapes" :loading="chargement" dataKey="code" size="small">
          <Column field="label" header="Étape du workflow" />
          <Column field="nb" header="Candidatures" style="width: 9rem">
            <template #body="{ data }">
              <span :class="{ muet: !data.nb }">{{ data.nb }}</span>
            </template>
          </Column>
        </DataTable>
      </template>
    </Card>

    <Card>
      <template #title>Offres publiées sans candidature</template>
      <template #content>
        <DataTable :value="offresSansCandidat" :loading="chargement" dataKey="id" size="small">
          <template #empty>Aucune offre publiée sans candidat.</template>
          <Column field="id" header="N°" style="width: 4rem" />
          <Column field="intitule" header="Offre" />
          <Column field="publiee_le" header="Publiée le" style="width: 8rem">
            <template #body="{ data }">{{ formatDate(data.publiee_le) }}</template>
          </Column>
        </DataTable>
      </template>
    </Card>

    <Card class="large">
      <template #title>Besoins de recrutement par hôtel</template>
      <template #content>
        <DataTable :value="parHotel" :loading="chargement" dataKey="hotel" size="small">
          <Column field="hotel" header="Établissement">
            <template #body="{ data }">
              {{ data.hotel }} <span class="ville">{{ data.ville }}</span>
            </template>
          </Column>
          <Column field="ouvert" header="Ouverts" style="width: 8rem" />
          <Column field="pris_en_charge" header="Pris en charge" style="width: 9rem" />
          <Column field="cloture" header="Clôturés" style="width: 8rem" />
          <Column field="total" header="Total" style="width: 7rem" />
        </DataTable>
      </template>
    </Card>
  </div>
</template>

<style scoped>
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); gap: 1rem; margin-bottom: 1.25rem; }
.grille { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
.grille .large { grid-column: 1 / -1; }
.ville { font-size: .8rem; color: var(--p-text-muted-color); margin-left: .25rem; }
.muet { color: var(--p-text-muted-color); }
:deep(.p-card-title) { font-size: 1rem; }
@media (max-width: 900px) { .grille { grid-template-columns: 1fr; } }
</style>
