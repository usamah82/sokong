<script setup lang="ts">
import { computed, ref } from 'vue'
import type { FamilyMember } from './MemberFields.vue'

const stage = ref(1)
const mode = ref<'self' | 'behalf'>('self')
const phone = ref('')
const email = ref('')
const place = ref('')
const latitude = ref<number | null>(null)
const longitude = ref<number | null>(null)
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
const { t } = useI18n()

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
    <p class="step">{{ t('wizard.step', { current: stage, total: 4 }) }}</p>
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
      @back="stage = 1"
      @next="stage = 3"
    />
    <section v-else>
      <h1>{{ t('wizard.members.title') }}</h1>
      <div class="actions">
        <button class="secondary" type="button" @click="stage = 2">{{ t('wizard.back') }}</button>
      </div>
    </section>
  </main>
</template>
