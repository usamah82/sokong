<script setup lang="ts">
import { ref } from 'vue'

const email = ref('')
const password = ref('')
const confirmation = ref('')
const error = ref('')
const sent = ref(false)
const submitting = ref(false)
const { createAccount } = useApi()
const { t } = useI18n()

async function submit() {
  if (submitting.value) return
  submitting.value = true
  error.value = ''
  try {
    const result = await createAccount({
      email: email.value,
      password: password.value,
      password_confirmation: confirmation.value
    })
    if (result.ok) {
      sent.value = true
      return
    }
    error.value = result.message
  } catch {
    // A failed request leaves the form and the typed values.
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('signUp.mark') }}</p>
    <div v-if="sent" class="confirm">
      <h1>{{ t('signUp.sent') }}</h1>
      <p class="email">{{ email }}</p>
    </div>
    <form v-else novalidate @submit.prevent="submit">
      <h1>{{ t('signUp.title') }}</h1>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
      <label class="field">{{ t('signUp.email') }}
        <input id="email" v-model="email" type="email" autocomplete="email">
      </label>
      <label class="field">{{ t('signUp.password') }}
        <input id="password" v-model="password" type="password" autocomplete="new-password">
      </label>
      <label class="field">{{ t('signUp.confirmation') }}
        <input id="password-confirmation" v-model="confirmation" type="password" autocomplete="new-password">
      </label>
      <div class="actions">
        <button id="create-account" class="primary" type="submit" :disabled="submitting">{{ t('signUp.submit') }}</button>
      </div>
    </form>
  </main>
</template>
