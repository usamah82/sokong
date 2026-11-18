<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { SubmitterEnrolment, WorkerSummary } from '../../composables/useApi'
import { formatVisit } from '../../utils/visitTime'

const enrolments = ref<Array<SubmitterEnrolment | WorkerSummary>>([])
const unlinked = ref(false)
const loaded = ref(false)
const submitting = ref(false)
const { hasToken, clearToken, signOut, role } = useAuth()
const { listEnrolments } = useApi()
const { t } = useI18n()
const zone = Intl.DateTimeFormat().resolvedOptions().timeZone

function headName(enrolment: SubmitterEnrolment | WorkerSummary) {
  if ('head_name' in enrolment) return enrolment.head_name
  return enrolment.members.find((member) => member.role === 'head')?.name ?? ''
}

function visitAt(enrolment: SubmitterEnrolment | WorkerSummary) {
  if ('progress' in enrolment) return enrolment.progress.visit_at
  return enrolment.visit_at ?? null
}

function outcomeOf(enrolment: SubmitterEnrolment | WorkerSummary) {
  const outcome = 'progress' in enrolment ? enrolment.progress.outcome : enrolment.outcome
  return outcome === 'qualified' || outcome === 'disqualified' ? outcome : null
}

function visitLine(enrolment: SubmitterEnrolment | WorkerSummary) {
  const instant = visitAt(enrolment)
  if (!instant) return t('progress.noVisit')
  return t('progress.visitSet', { time: formatVisit(instant, zone) })
}

onMounted(async () => {
  if (!hasToken()) {
    await navigateTo('/sign-in')
    return
  }
  try {
    const result = await listEnrolments()
    if (!result.ok) {
      if (result.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      unlinked.value = true
      loaded.value = true
      return
    }
    enrolments.value = result.enrolments
    loaded.value = true
  } catch {
    // A failed read leaves the token so a reload can try again.
  }
})

async function endSession() {
  if (submitting.value) return
  submitting.value = true
  try {
    await signOut()
    await navigateTo('/sign-in')
  } catch {
    // A failed revocation keeps the token so it can be retried.
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('progress.mark') }}</p>
    <h1 v-if="unlinked">{{ t('worker.unlinked') }}</h1>
    <h1 v-else-if="loaded && role() === 'worker' && enrolments.length === 0">{{ t('worker.empty') }}</h1>
    <ul v-else-if="loaded" id="cases" class="cases">
      <li v-for="enrolment in enrolments" :key="enrolment.id">
        <NuxtLink :id="`case-${enrolment.id}`" :to="`/enrolments/${enrolment.id}`">
          <span>{{ enrolment.place_name }} {{ headName(enrolment) }}</span>
          <span class="case-line">{{ visitLine(enrolment) }}</span>
          <span v-if="outcomeOf(enrolment) === 'qualified'" class="case-line">{{ t('worker.qualified') }}</span>
          <span v-else-if="outcomeOf(enrolment) === 'disqualified'" class="case-line">{{ t('worker.disqualified') }}</span>
        </NuxtLink>
      </li>
    </ul>
    <div class="actions">
      <button id="sign-out" class="secondary" type="button" :disabled="submitting" @click="endSession">{{ t('progress.signOut') }}</button>
    </div>
  </main>
</template>
