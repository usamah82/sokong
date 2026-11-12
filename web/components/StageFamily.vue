<script setup lang="ts">
import type { FamilyMember } from './MemberFields.vue'

const place = defineModel<string>('place', { required: true })
const familyPhone = defineModel<string>('familyPhone', { required: true })
const head = defineModel<FamilyMember>('head', { required: true })
const latitude = defineModel<number | null>('latitude', { required: true })
const longitude = defineModel<number | null>('longitude', { required: true })

const emit = defineEmits<{ back: [], next: [] }>()
const { t } = useI18n()
const { suggestLocality } = useApi()

const suggestedName = ref<string | null>(null)
const showSuggested = ref(false)
const showElsewhere = ref(false)
const showRead = ref(false)

const ready = computed(() => place.value.trim() !== '' && head.value.name.trim() !== '')

watch(place, (value) => {
  if (suggestedName.value !== null && value !== suggestedName.value) {
    showSuggested.value = false
    latitude.value = null
    longitude.value = null
  }
})

function useLocation() {
  if (!navigator.geolocation) return
  navigator.geolocation.getCurrentPosition(async (position) => {
    const { latitude: lat, longitude: lng } = position.coords
    const body = await suggestLocality(lat, lng)
    const name = body.locality?.name
    if (name) {
      suggestedName.value = name
      showSuggested.value = true
      showElsewhere.value = true
      showRead.value = false
      latitude.value = lat
      longitude.value = lng
      place.value = name
      return
    }
    suggestedName.value = null
    showSuggested.value = false
    latitude.value = null
    longitude.value = null
    showRead.value = true
  }, () => {})
}
</script>

<template>
  <form novalidate @submit.prevent="ready && emit('next')">
    <h1>{{ t('wizard.family.title') }}</h1>
    <label class="field">{{ t('wizard.family.place') }}
      <input
        id="place"
        v-model="place"
        type="text"
        :data-latitude="latitude ?? undefined"
        :data-longitude="longitude ?? undefined"
      >
    </label>
    <button id="use-location" class="secondary block" type="button" @click="useLocation">{{ t('wizard.family.locate') }}</button>
    <p v-if="showSuggested" class="hint">{{ t('wizard.family.suggested') }}</p>
    <p v-if="showElsewhere" class="hint">{{ t('wizard.family.elsewhere') }}</p>
    <p v-if="showRead" class="hint">{{ t('wizard.family.read') }}</p>
    <label class="field">{{ t('wizard.family.familyPhone') }}
      <input id="family-phone" v-model="familyPhone" type="tel" autocomplete="tel">
    </label>
    <h2 class="label">{{ t('wizard.family.head') }}</h2>
    <MemberFields v-model:person="head" />
    <div class="actions">
      <button class="secondary" type="button" @click="emit('back')">{{ t('wizard.back') }}</button>
      <button class="primary" type="button" :disabled="!ready" @click="ready && emit('next')">{{ t('wizard.next') }}</button>
    </div>
  </form>
</template>
