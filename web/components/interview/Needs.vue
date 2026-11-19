<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  help: string[]
  saved: Record<string, unknown> | null
  readonly: boolean
}>()

const helpLabels: Record<string, string> = {
  food: 'Food',
  clothing: 'Clothing',
  school_supplies: 'School supplies',
  help_applying: 'Help applying to a body (for example social security, welfare, or a tithe body)'
}

const { t } = useI18n()
const needMost = ref(typeof props.saved?.need_most === 'string' ? props.saved.need_most : '')
const consent = ref(props.saved?.consent_given === true ? 'yes' : props.saved?.consent_given === false ? 'no' : '')
const notes = ref(typeof props.saved?.notes === 'string' ? props.saved.notes : '')
const error = ref('')
const listedHelp = props.help.filter((key) => helpLabels[key])

function attempt() {
  if (needMost.value.trim().length > 2000) {
    error.value = t('interview.needTooLong')
    return null
  }
  if (notes.value.trim().length > 2000) {
    error.value = t('interview.notesTooLong')
    return null
  }
  error.value = ''
  return {
    need_most: needMost.value.trim(),
    consent_given: consent.value === '' ? null : consent.value === 'yes',
    notes: notes.value.trim()
  }
}

function fail(message: string) {
  error.value = message
}

defineExpose({ attempt, fail })
</script>

<template>
  <div>
    <div id="needs-enrolment">
      <p class="label">{{ t('interview.enrolment') }}</p>
      <p v-for="key in listedHelp" :key="key">{{ helpLabels[key] }}</p>
    </div>
    <template v-if="readonly">
      <p><span class="label">{{ t('interview.needMost') }}</span> {{ needMost }}</p>
      <p>{{ consent === 'yes' ? t('interview.consents') : consent === 'no' ? t('interview.refuses') : '' }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <label class="field">{{ t('interview.needMost') }}
        <textarea id="need-most" v-model="needMost" rows="3" />
      </label>
      <fieldset>
        <legend class="label">{{ t('interview.consent') }}</legend>
        <label class="choice">
          <input id="consent-yes" v-model="consent" type="radio" value="yes">
          {{ t('interview.consents') }}
        </label>
        <label class="choice">
          <input id="consent-no" v-model="consent" type="radio" value="no">
          {{ t('interview.refuses') }}
        </label>
      </fieldset>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="needs-notes" v-model="notes" rows="3" />
      </label>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
    </template>
  </div>
</template>
