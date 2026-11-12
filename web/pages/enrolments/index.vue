<script setup lang="ts">
import { ref } from 'vue'

const submitting = ref(false)
const { signOut } = useAuth()
const { t } = useI18n()

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
    <p class="mark">{{ t('signIn.mark') }}</p>
    <div class="actions">
      <button id="sign-out" class="secondary" type="button" :disabled="submitting" @click="endSession">{{ t('signIn.signOut') }}</button>
    </div>
  </main>
</template>
