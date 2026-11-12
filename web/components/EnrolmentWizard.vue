<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import type { FamilyMember } from './MemberFields.vue'
import { enrolmentPayload } from '../utils/enrolment'

const stage = ref(1)
const mode = ref<'self' | 'behalf'>('self')
const phone = ref('')
const email = ref('')
const place = ref('')
const latitude = ref<number | null>(null)
const longitude = ref<number | null>(null)
const suggestion = ref<null | { kind: 'suggested', name: string } | { kind: 'renamed' } | { kind: 'read' }>(null)
const locationRequest = ref(0)
const { suggestLocality, submitEnrolment } = useApi()
const familyPhone = ref('')
const familyPhoneTouched = ref(false)
const head = ref<FamilyMember>({
  name: '',
  age: '',
  gender: 'unspecified',
  description: '',
  education: false,
  working: false,
  job: '',
  amount: ''
})
const others = ref<FamilyMember[]>([])
const howToFind = ref('')
const otherHelp = ref('')
const help = ref<string[]>([])
const confirmed = ref(false)
const submitError = ref('')
const submitting = ref(false)
const { t } = useI18n()

watch(place, (value) => {
  const current = suggestion.value
  if (current?.kind === 'suggested' && value !== current.name) {
    suggestion.value = { kind: 'renamed' }
    latitude.value = null
    longitude.value = null
  }
})

function useLocation() {
  if (!navigator.geolocation) return
  const id = locationRequest.value + 1
  locationRequest.value = id
  const placeAtClick = place.value
  navigator.geolocation.getCurrentPosition(async (position) => {
    const { latitude: lat, longitude: lng } = position.coords
    try {
      const body = await suggestLocality(lat, lng)
      if (id !== locationRequest.value || place.value !== placeAtClick) return
      const name = body.locality?.name
      if (name) {
        suggestion.value = { kind: 'suggested', name }
        latitude.value = lat
        longitude.value = lng
        place.value = name
        return
      }
      suggestion.value = { kind: 'read' }
      latitude.value = null
      longitude.value = null
    } catch {
      // A failed lookup leaves the place and any point already on screen.
    }
  }, () => {})
}

async function submit() {
  if (submitting.value) return
  submitting.value = true
  submitError.value = ''
  try {
    const result = await submitEnrolment(enrolmentPayload({
      onBehalf: mode.value === 'behalf',
      consentText: mode.value === 'behalf' ? t('wizard.enroler.consentBehalf') : t('wizard.enroler.consentSelf'),
      phone: phone.value,
      email: email.value,
      place: place.value,
      familyPhone: familyPhoneShown.value,
      latitude: latitude.value,
      longitude: longitude.value,
      howToFind: howToFind.value,
      help: help.value,
      otherHelp: otherHelp.value,
      head: head.value,
      others: others.value
    }))
    if (result.ok) {
      confirmed.value = true
      return
    }
    submitError.value = result.message
  } catch {
    // A failed request leaves stage 4 and the typed values.
  } finally {
    submitting.value = false
  }
}

const familyPhoneShown = computed({
  get() {
    if (familyPhoneTouched.value) return familyPhone.value
    return mode.value === 'self' ? phone.value : ''
  },
  set(value: string) {
    familyPhoneTouched.value = true
    familyPhone.value = value
  }
})
</script>

<template>
  <main class="phone">
    <p class="mark">{{ t('wizard.mark') }}</p>
    <p v-if="!confirmed" class="step">{{ t('wizard.step', { current: stage, total: 4 }) }}</p>
    <EnrolmentConfirmation v-if="confirmed" :email="email" />
    <template v-else>
    <StageEnroler
      v-if="stage === 1"
      v-model:mode="mode"
      v-model:phone="phone"
      v-model:email="email"
      @next="stage = 2"
    />
    <StageFamily
      v-else-if="stage === 2"
      v-model:place="place"
      v-model:family-phone="familyPhoneShown"
      v-model:head="head"
      v-model:latitude="latitude"
      v-model:longitude="longitude"
      :suggestion="suggestion"
      @locate="useLocation"
      @back="stage = 1"
      @next="stage = 3"
    />
    <StageMembers
      v-else-if="stage === 3"
      v-model:people="others"
      @back="stage = 2"
      @next="stage = 4"
    />
    <StageNotes
      v-else
      v-model:how-to-find="howToFind"
      v-model:other-help="otherHelp"
      v-model:help="help"
      :error="submitError"
      :submitting="submitting"
      @back="stage = 3"
      @submit="submit"
    />
    </template>
  </main>
</template>
