<script setup lang="ts">
import { phoneMatches } from '../utils/phone'

const mode = defineModel<'self' | 'behalf'>('mode', { required: true })
const phone = defineModel<string>('phone', { required: true })
const email = defineModel<string>('email', { required: true })

const emit = defineEmits<{ next: [] }>()
const { t } = useI18n()

const valid = computed(() => phoneMatches(phone.value))
const showError = computed(() => phone.value !== '' && !valid.value)
const consent = computed(() => t(mode.value === 'self' ? 'wizard.enroler.consentSelf' : 'wizard.enroler.consentBehalf'))

function goNext(event?: Event) {
  if (!valid.value) return
  if (event?.type === 'submit') {
    // Chrome warns if the form leaves the document before submit finishes.
    setTimeout(() => emit('next'), 0)
    return
  }
  emit('next')
}
</script>

<template>
  <form @submit.prevent="goNext">
    <h1>{{ t('wizard.enroler.title') }}</h1>
    <fieldset>
      <legend>{{ t('wizard.enroler.legend') }}</legend>
      <label class="choice">
        <input v-model="mode" type="radio" name="mode" value="self">
        <span>{{ t('wizard.enroler.self') }}</span>
      </label>
      <label class="choice">
        <input v-model="mode" type="radio" name="mode" value="behalf">
        <span>{{ t('wizard.enroler.behalf') }}</span>
      </label>
    </fieldset>
    <p class="consent">{{ consent }}</p>
    <label class="field">{{ t('wizard.enroler.phone') }}
      <input
        id="phone"
        v-model="phone"
        type="tel"
        autocomplete="tel"
        :aria-invalid="showError"
        :aria-describedby="showError ? 'phone-error' : undefined"
      >
      <p v-if="showError" id="phone-error" class="error" role="alert">{{ t('wizard.enroler.phoneError') }}</p>
    </label>
    <label class="field">{{ t('wizard.enroler.email') }}
      <input id="email" v-model="email" type="email" autocomplete="email">
    </label>
    <div class="actions">
      <button class="primary" type="submit" :disabled="!valid" @click.prevent="goNext">{{ t('wizard.next') }}</button>
    </div>
  </form>
</template>
