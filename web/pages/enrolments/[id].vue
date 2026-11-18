<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import type { SubmitterEnrolment, WorkerDetail } from '../../composables/useApi'
import { formatVisit } from '../../utils/visitTime'

const route = useRoute()
const enrolment = ref<SubmitterEnrolment | null>(null)
const worker = ref<WorkerDetail | null>(null)
const missing = ref(false)
const { hasToken, clearToken } = useAuth()
const { readEnrolment } = useApi()
const { t } = useI18n()

const looks = computed(() => {
  const rows = enrolment.value?.progress.looks ?? []
  return [ ...rows ].sort((left, right) => left.looked_at.localeCompare(right.looked_at))
})

const noVisit = computed(() => enrolment.value?.progress.visit_at == null)
const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
const visitLabel = computed(() => {
  const instant = enrolment.value?.progress.visit_at
  return instant ? formatVisit(instant, zone) : ''
})
const outcome = computed(() => enrolment.value?.progress.outcome ?? null)

function onMarked(mark: { outcome: string, marked_at: string, marker_name: string }) {
  if (!worker.value) return
  worker.value.outcome = mark.outcome
  worker.value.marked_at = mark.marked_at
  worker.value.marker_name = mark.marker_name
}

onMounted(async () => {
  if (!hasToken()) {
    await navigateTo('/sign-in')
    return
  }
  const id = typeof route.params.id === 'string' ? route.params.id : ''
  try {
    const result = await readEnrolment(id)
    if (!result.ok) {
      if (result.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      missing.value = true
      return
    }
    if (result.kind === 'worker') worker.value = result.enrolment
    else enrolment.value = result.enrolment
  } catch {
    // A failed read leaves the token so a reload can try again.
  }
})
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('progress.mark') }}</p>
    <h1 v-if="missing">{{ t('progress.missing') }}</h1>
    <WorkerCase v-else-if="worker" :enrolment="worker" @marked="onMarked" />
    <template v-else-if="enrolment">
      <h1 v-if="looks.length === 0 && noVisit">{{ t('progress.quiet') }}</h1>
      <template v-else>
        <h1>{{ t('progress.in') }}</h1>
        <article v-for="look in looks" :id="`look-${look.id}`" :key="look.id" class="look">
          <p class="worker">{{ look.worker_name }}</p>
          <time :datetime="look.looked_at">{{ look.looked_at }}</time>
          <p v-if="look.note">{{ look.note }}</p>
        </article>
        <p v-if="noVisit">{{ t('progress.noVisit') }}</p>
        <p v-else id="visit-line">{{ t('progress.visitSet', { time: visitLabel }) }}</p>
        <p v-if="outcome === 'qualified'" id="outcome">{{ t('worker.qualified') }}</p>
        <p v-else-if="outcome === 'disqualified'" id="outcome">{{ t('worker.disqualified') }}</p>
      </template>
    </template>
  </main>
</template>
