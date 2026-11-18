<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  saved: Record<string, unknown> | null
  readonly: boolean
}>()

const { t } = useI18n()
const year = ref(props.saved?.started_year == null || props.saved.started_year === '' ? '' : String(props.saved.started_year))
const how = ref(typeof props.saved?.how_it_started === 'string' ? props.saved.how_it_started : '')
const notes = ref(typeof props.saved?.notes === 'string' ? props.saved.notes : '')
const error = ref('')

function parseYear(value: string) {
  const trimmed = value.trim()
  if (trimmed === '') return null
  if (!/^\d+$/.test(trimmed)) return false
  const parsed = Number(trimmed)
  const current = new Date().getUTCFullYear()
  if (parsed < 1900 || parsed > current) return false
  return parsed
}

function attempt() {
  const parsed = parseYear(year.value)
  if (parsed === false) {
    error.value = t('interview.yearInvalid')
    return null
  }
  if (how.value.trim().length > 2000) {
    error.value = t('interview.howTooLong')
    return null
  }
  if (notes.value.trim().length > 2000) {
    error.value = t('interview.notesTooLong')
    return null
  }
  error.value = ''
  return {
    started_year: parsed,
    how_it_started: how.value.trim(),
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
    <template v-if="readonly">
      <p><span class="label">{{ t('interview.started') }}</span> {{ year }}</p>
      <p><span class="label">{{ t('interview.how') }}</span> {{ how }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <label class="field">{{ t('interview.started') }}
        <input id="started-year" v-model="year" type="text" inputmode="numeric" :aria-invalid="error === t('interview.yearInvalid')">
      </label>
      <label class="field">{{ t('interview.how') }}
        <textarea id="how-it-started" v-model="how" rows="3" />
      </label>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="formation-notes" v-model="notes" rows="3" />
      </label>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
    </template>
  </div>
</template>
