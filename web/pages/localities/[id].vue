<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { LocalityBoundary } from '../../composables/useApi'

const route = useRoute()
const name = ref('')
const latitude = ref('')
const longitude = ref('')
const radius = ref('')
const error = ref('')
const missing = ref(false)
const loaded = ref(false)
const submitting = ref(false)
const { hasToken, clearToken, signOut } = useAuth()
const { updateLocality } = useApi()
const { t } = useI18n()

const localityId = typeof route.params.id === 'string' ? route.params.id : ''

onMounted(async () => {
  if (!hasToken()) {
    await navigateTo('/sign-in')
    return
  }
  await save({})
  loaded.value = true
})

function shown(value: number | null) {
  return value == null ? '' : String(value)
}

function apply(locality: LocalityBoundary) {
  name.value = locality.name
  latitude.value = shown(locality.latitude)
  longitude.value = shown(locality.longitude)
  radius.value = shown(locality.radius_metres)
}

function fieldValue(raw: string): string | number | null {
  const trimmed = raw.trim()
  if (trimmed === '') return null
  if (/^-?(?:\d+\.?\d*|\.\d+)$/.test(trimmed)) return Number(trimmed)
  return trimmed
}

async function save(body: Record<string, unknown>) {
  if (submitting.value) return
  submitting.value = true
  error.value = ''
  try {
    const result = await updateLocality(localityId, body)
    if (!result.ok) {
      if (result.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      if (result.reason === 'missing') {
        missing.value = true
        return
      }
      error.value = result.message
      return
    }
    apply(result.locality)
  } catch {
    // A failed save leaves the typed values.
  } finally {
    submitting.value = false
  }
}

function submit() {
  return save({
    name: name.value,
    latitude: fieldValue(latitude.value),
    longitude: fieldValue(longitude.value),
    radius_metres: fieldValue(radius.value)
  })
}

function clearCircle() {
  latitude.value = ''
  longitude.value = ''
  radius.value = ''
  return submit()
}

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
    <h1 v-if="missing">{{ t('boundary.unavailable') }}</h1>
    <form v-else-if="loaded" novalidate @submit.prevent="submit">
      <h1>{{ name }}</h1>
      <p v-if="error" class="notice" role="alert">{{ error }}</p>
      <label class="field">{{ t('boundary.name') }}
        <input id="name" v-model="name" type="text" autocomplete="off">
      </label>
      <label class="field">{{ t('boundary.latitude') }}
        <input id="latitude" v-model="latitude" type="text" inputmode="decimal" autocomplete="off">
      </label>
      <label class="field">{{ t('boundary.longitude') }}
        <input id="longitude" v-model="longitude" type="text" inputmode="decimal" autocomplete="off">
      </label>
      <label class="field">{{ t('boundary.radius') }}
        <input id="radius" v-model="radius" type="text" inputmode="numeric" autocomplete="off">
      </label>
      <div class="actions">
        <button id="clear-circle" class="secondary" type="button" :disabled="submitting" @click="clearCircle">{{ t('boundary.clear') }}</button>
        <button id="save" class="primary" type="submit" :disabled="submitting">{{ t('boundary.save') }}</button>
      </div>
    </form>
    <div class="actions">
      <button id="sign-out" class="secondary" type="button" :disabled="submitting" @click="endSession">{{ t('progress.signOut') }}</button>
    </div>
  </main>
</template>
