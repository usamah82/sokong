<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{
  saved: Record<string, unknown> | null
  consentGiven: boolean | null
  readonly: boolean
}>()

const { t } = useI18n()
const good = ref(props.saved?.good_family_unit === true)
const goodGap = ref(typeof props.saved?.good_family_unit_gap === 'string' ? props.saved.good_family_unit_gap : '')
const basic = ref(props.saved?.basic_necessities === true)
const basicGap = ref(typeof props.saved?.basic_necessities_gap === 'string' ? props.saved.basic_necessities_gap : '')
const notes = ref(typeof props.saved?.notes === 'string' ? props.saved.notes : '')
const messages = ref<string[]>([])

defineEmits<{
  mark: [outcome: 'qualified' | 'disqualified']
}>()

function attempt() {
  if (notes.value.trim().length > 2000) {
    messages.value = [ t('interview.notesTooLong') ]
    return null
  }
  return {
    good_family_unit: good.value,
    good_family_unit_gap: goodGap.value.trim(),
    basic_necessities: basic.value,
    basic_necessities_gap: basicGap.value.trim(),
    notes: notes.value.trim()
  }
}

function notices(outcome: 'qualified' | 'disqualified') {
  const list: string[] = []
  const gapMissing = (good.value === false && goodGap.value.trim() === '')
    || (basic.value === false && basicGap.value.trim() === '')
  if (gapMissing) list.push(t('interview.gapRequired'))
  if (outcome === 'qualified' && props.consentGiven === false) list.push(t('interview.consentRefused'))
  return list
}

function show(next: string[]) {
  messages.value = next.filter((message, index) => message !== '' && next.indexOf(message) === index)
}

defineExpose({ attempt, notices, show })
</script>

<template>
  <section id="post-visit">
    <h2>{{ t('interview.postVisit') }}</h2>
    <p id="status-boxes">{{ saved ? t('interview.saved') : t('interview.notSaved') }}</p>
    <h3>{{ t('interview.initialAssessment') }}</h3>
    <p>{{ t('interview.judgment') }}</p>
    <template v-if="readonly">
      <p><span class="label">{{ t('interview.goodFamily') }}</span> {{ good ? t('worker.yes') : t('worker.no') }}</p>
      <p>{{ t('interview.integrity') }}</p>
      <p><span class="label">{{ t('interview.gap') }}</span> {{ goodGap }}</p>
      <p><span class="label">{{ t('interview.basicNecessities') }}</span> {{ basic ? t('worker.yes') : t('worker.no') }}</p>
      <p><span class="label">{{ t('interview.gap') }}</span> {{ basicGap }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <label class="check">
        <input id="good-family-unit" v-model="good" type="checkbox">
        {{ t('interview.goodFamily') }}
      </label>
      <p>{{ t('interview.integrity') }}</p>
      <label class="field">{{ t('interview.gap') }}
        <textarea id="good-family-gap" v-model="goodGap" rows="2" />
      </label>
      <label class="check">
        <input id="basic-necessities" v-model="basic" type="checkbox">
        {{ t('interview.basicNecessities') }}
      </label>
      <label class="field">{{ t('interview.gap') }}
        <textarea id="basic-gap" v-model="basicGap" rows="2" />
      </label>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="boxes-notes" v-model="notes" rows="3" />
      </label>
      <p v-for="message in messages" :key="message" class="error" role="alert">{{ message }}</p>
      <div class="actions">
        <button id="mark-qualified" class="primary" type="button" @click="$emit('mark', 'qualified')">{{ t('interview.markQualified') }}</button>
        <button id="mark-disqualified" class="secondary" type="button" @click="$emit('mark', 'disqualified')">{{ t('interview.markDisqualified') }}</button>
      </div>
    </template>
  </section>
</template>
