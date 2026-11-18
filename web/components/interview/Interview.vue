<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerMember } from '../../composables/useApi'
import WhoIsHere from './WhoIsHere.vue'

const props = defineProps<{
  enrolmentId: string
  members: WorkerMember[]
  familyPhone: string
  verification: Record<string, unknown> | null
  readonly: boolean
}>()

const stages = [
  { key: 'who_is_here', label: 'interview.who' },
  { key: 'formation', label: 'interview.formation' },
  { key: 'daily_life', label: 'interview.dailyLife' },
  { key: 'dynamics', label: 'interview.dynamics' },
  { key: 'house', label: 'interview.house' },
  { key: 'needs', label: 'interview.needs' }
] as const

type StageKey = typeof stages[number]['key']

const { t } = useI18n()
const { saveStage } = useApi()
const { clearToken } = useAuth()
const current = ref<StageKey>('who_is_here')
const record = ref<Record<string, unknown>>(props.verification ? { ...props.verification } : {})
const saved = ref(new Set(stages.map((stage) => stage.key).filter((key) => props.verification?.[key])))
const saving = ref(false)
const whoIsHere = ref<{
  attempt: () => Record<string, unknown> | null
  fail: (message: string) => void
} | null>(null)

const index = computed(() => stages.findIndex((stage) => stage.key === current.value))
const whoSaved = computed(() => {
  const value = record.value.who_is_here
  return value && typeof value === 'object' ? value as Record<string, unknown> : null
})

function statusText(key: StageKey) {
  const parts: string[] = []
  if (current.value === key) parts.push(t('interview.current'))
  parts.push(saved.value.has(key) ? t('interview.saved') : t('interview.notSaved'))
  return parts.join(' ')
}

function labelOf(key: StageKey) {
  return t(stages.find((stage) => stage.key === key)!.label)
}

async function leave(key: StageKey) {
  if (saving.value || key === current.value) return
  if (current.value === 'who_is_here' && !props.readonly) {
    const body = whoIsHere.value?.attempt() ?? null
    if (!body) return
    saving.value = true
    try {
      const result = await saveStage(props.enrolmentId, 'who_is_here', body)
      if (!result.ok) {
        if (result.reason === 'unauthenticated') {
          clearToken()
          await navigateTo('/sign-in')
          return
        }
        whoIsHere.value?.fail(result.message)
        return
      }
      record.value = { ...record.value, who_is_here: result.stage }
      saved.value = new Set(saved.value).add('who_is_here')
    } catch {
      return
    } finally {
      saving.value = false
    }
  }
  current.value = key
}
</script>

<template>
  <section id="interview">
    <h2>{{ t('interview.title') }}</h2>
    <ol class="stages">
      <li v-for="stage in stages" :key="stage.key">
        <button :id="`stage-${stage.key}`" type="button" :aria-current="current === stage.key ? 'step' : undefined" @click="leave(stage.key)">
          {{ t(stage.label) }}
        </button>
        <span :id="`status-${stage.key}`" class="stage-status">{{ statusText(stage.key) }}</span>
      </li>
    </ol>
    <WhoIsHere
      v-if="current === 'who_is_here'"
      ref="whoIsHere"
      :members="members"
      :family-phone="familyPhone"
      :saved="whoSaved"
      :readonly="readonly"
    />
    <section v-else :id="`open-${current}`">
      <h3>{{ labelOf(current) }}</h3>
    </section>
    <div class="actions">
      <button v-if="index > 0" id="back-stage" class="secondary" type="button" @click="leave(stages[index - 1]!.key)">{{ t('interview.back') }}</button>
      <button v-if="index < stages.length - 1" id="next-stage" class="primary" type="button" @click="leave(stages[index + 1]!.key)">{{ t('interview.next') }}</button>
    </div>
  </section>
</template>
