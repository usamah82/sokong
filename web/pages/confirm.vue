<script setup lang="ts">
import { onMounted, ref } from 'vue'

const route = useRoute()
const status = ref<'pending' | 'confirmed' | 'invalid'>('pending')
const message = ref('')
const { confirmEmail } = useApi()
const { t } = useI18n()

onMounted(async () => {
  const token = typeof route.query.token === 'string' ? route.query.token : ''
  try {
    const result = await confirmEmail(token)
    if (result.ok) {
      status.value = 'confirmed'
      return
    }
    status.value = 'invalid'
    message.value = result.message
  } catch {
    status.value = 'invalid'
  }
})
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('confirm.mark') }}</p>
    <div v-if="status === 'confirmed'" class="confirm">
      <h1>{{ t('confirm.confirmed') }}</h1>
      <div class="actions">
        <NuxtLink id="sign-in" class="primary" to="/sign-in">{{ t('confirm.signIn') }}</NuxtLink>
      </div>
    </div>
    <div v-else-if="status === 'invalid'" class="confirm">
      <h1>{{ message }}</h1>
      <div class="actions">
        <NuxtLink id="sign-up" class="primary" to="/sign-up">{{ t('confirm.signUp') }}</NuxtLink>
      </div>
    </div>
  </main>
</template>
