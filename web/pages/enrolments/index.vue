<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { SubmitterEnrolment } from '../../composables/useApi'

const enrolments = ref<SubmitterEnrolment[]>([])
const submitting = ref(false)
const { hasToken, clearToken, signOut } = useAuth()
const { listEnrolments } = useApi()
const { t } = useI18n()

onMounted(async () => {
  if (!hasToken()) {
    await navigateTo('/sign-in')
    return
  }
  try {
    const result = await listEnrolments()
    if (!result.ok) {
      clearToken()
      await navigateTo('/sign-in')
      return
    }
    enrolments.value = result.enrolments
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
    <ul class="cases">
      <li v-for="enrolment in enrolments" :key="enrolment.id">
        <NuxtLink :id="`case-${enrolment.id}`" :to="`/enrolments/${enrolment.id}`">{{ enrolment.place_name }}</NuxtLink>
      </li>
    </ul>
    <div class="actions">
      <button id="sign-out" class="secondary" type="button" :disabled="submitting" @click="endSession">{{ t('progress.signOut') }}</button>
    </div>
  </main>
</template>
