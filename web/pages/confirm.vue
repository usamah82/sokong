<script setup lang="ts">
import { onMounted, ref } from 'vue'

const route = useRoute()
const status = ref<'pending' | 'confirmed' | 'invalid' | 'limited'>('pending')
const { confirmEmail } = useApi()
const { t } = useI18n()

onMounted(async () => {
  const token = typeof route.query.token === 'string' ? route.query.token : ''
  if (token === '') {
    status.value = 'invalid'
    return
  }
  try {
    const result = await confirmEmail(token)
    status.value = result.ok ? 'confirmed' : result.reason
  } catch {
    // A failed request stays pending so a reload can post the same token.
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
      <h1>{{ t('confirm.invalid') }}</h1>
      <div class="actions">
        <NuxtLink id="sign-up" class="primary" to="/sign-up">{{ t('confirm.signUp') }}</NuxtLink>
      </div>
    </div>
    <div v-else-if="status === 'limited'" class="confirm">
      <h1>{{ t('confirm.limited') }}</h1>
    </div>
  </main>
</template>
