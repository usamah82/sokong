<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  saved: Record<string, unknown> | null
  readonly: boolean
  hasChild: boolean
}>()

const { t } = useI18n()
const hardWeek = ref(typeof props.saved?.hard_week === 'string' ? props.saved.hard_week : '')
const whoStepsIn = ref(typeof props.saved?.who_steps_in === 'string' ? props.saved.who_steps_in : '')
const childrenAtHome = ref(typeof props.saved?.children_at_home === 'string' ? props.saved.children_at_home : '')
const notes = ref(typeof props.saved?.notes === 'string' ? props.saved.notes : '')
const error = ref('')

function tooLong(value: string, message: string) {
  if (value.trim().length <= 2000) return false
  error.value = message
  return true
}

function attempt() {
  if (tooLong(hardWeek.value, t('interview.hardWeekTooLong'))) return null
  if (tooLong(whoStepsIn.value, t('interview.whoStepsInTooLong'))) return null
  if (props.hasChild && tooLong(childrenAtHome.value, t('interview.childrenTooLong'))) return null
  if (tooLong(notes.value, t('interview.notesTooLong'))) return null
  error.value = ''
  return {
    hard_week: hardWeek.value.trim(),
    who_steps_in: whoStepsIn.value.trim(),
    children_at_home: props.hasChild ? childrenAtHome.value.trim() : '',
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
    <p>{{ t('interview.familySaid') }}</p>
    <template v-if="readonly">
      <p><span class="label">{{ t('interview.hardWeek') }}</span> {{ hardWeek }}</p>
      <p><span class="label">{{ t('interview.whoStepsIn') }}</span> {{ whoStepsIn }}</p>
      <p v-if="hasChild"><span class="label">{{ t('interview.childrenAtHome') }}</span> {{ childrenAtHome }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <label class="field">{{ t('interview.hardWeek') }}
        <textarea id="hard-week" v-model="hardWeek" rows="3" />
      </label>
      <label class="field">{{ t('interview.whoStepsIn') }}
        <textarea id="who-steps-in" v-model="whoStepsIn" rows="3" />
      </label>
      <label v-if="hasChild" class="field">{{ t('interview.childrenAtHome') }}
        <textarea id="children-at-home" v-model="childrenAtHome" rows="3" />
      </label>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="dynamics-notes" v-model="notes" rows="3" />
      </label>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
    </template>
  </div>
</template>
