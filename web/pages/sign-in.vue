<script setup lang="ts">
import { onMounted, ref } from 'vue'

const email = ref('')
const password = ref('')
const error = ref('')
const submitting = ref(false)
const signedIn = ref(false)
const { signIn, signOut } = useAuth()
const { t } = useI18n()

onMounted(() => {
  signedIn.value = sessionStorage.getItem('sokong.token') !== null
})

async function submit() {
  if (submitting.value) return
  submitting.value = true
  error.value = ''
  try {
    const result = await signIn({ email: email.value, password: password.value })
    if (result.ok) {
      await navigateTo('/enrolments')
      return
    }
    error.value = result.message
  } catch {
    // A failed request leaves the form and the typed values.
  } finally {
    submitting.value = false
  }
}

async function endSession() {
  if (submitting.value) return
  submitting.value = true
  try {
    await signOut()
    signedIn.value = false
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
    <form novalidate @submit.prevent="submit">
      <h1>{{ t('signIn.title') }}</h1>
      <p v-if="error" class="notice" role="alert">{{ error }}</p>
      <label class="field">{{ t('signIn.email') }}
        <input id="email" v-model="email" type="email" autocomplete="email">
      </label>
      <label class="field">{{ t('signIn.password') }}
        <input id="password" v-model="password" type="password" autocomplete="current-password">
      </label>
      <div class="actions">
        <button v-if="signedIn" id="sign-out" class="secondary" type="button" :disabled="submitting" @click="endSession">{{ t('signIn.signOut') }}</button>
        <button id="sign-in" class="primary" type="submit" :disabled="submitting">{{ t('signIn.submit') }}</button>
      </div>
    </form>
  </main>
</template>
