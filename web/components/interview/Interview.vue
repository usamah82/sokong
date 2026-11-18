<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerMember } from '../../composables/useApi'
import DailyLife from './DailyLife.vue'
import Dynamics from './Dynamics.vue'
import Formation from './Formation.vue'
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

type Editor = {
  attempt: () => Record<string, unknown> | null
  fail: (message: string) => void
}

const whoIsHere = ref<Editor | null>(null)
const formation = ref<Editor | null>(null)
const dynamics = ref<Editor | null>(null)
const dailyLife = ref<Editor | null>(null)

const index = computed(() => stages.findIndex((stage) => stage.key === current.value))
const hasChild = computed(() => {
  const stage = record.value.who_is_here
  if (!stage || typeof stage !== 'object') return false
  const people = (stage as { people?: unknown }).people
  if (!Array.isArray(people)) return false
  return people.some((person) => {
    return !!person && typeof person === 'object' && (person as { relationship?: unknown }).relationship === 'child'
  })
})

function stageSaved(key: string) {
  const value = record.value[key]
  return value && typeof value === 'object' ? value as Record<string, unknown> : null
}

const whoPeople = computed(() => {
  const stage = record.value.who_is_here
  if (!stage || typeof stage !== 'object') return []
  const people = (stage as { people?: unknown }).people
  return Array.isArray(people) ? people : []
})

function editorFor(key: StageKey): Editor | null {
  if (key === 'who_is_here') return whoIsHere.value
  if (key === 'formation') return formation.value
  if (key === 'dynamics') return dynamics.value
  if (key === 'daily_life') return dailyLife.value
  return null
}

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
  const editor = editorFor(current.value)
  if (editor && !props.readonly) {
    const body = editor.attempt()
    if (!body) return
    const stage = current.value
    saving.value = true
    try {
      const result = await saveStage(props.enrolmentId, stage, body)
      if (!result.ok) {
        if (result.reason === 'unauthenticated') {
          clearToken()
          await navigateTo('/sign-in')
          return
        }
        editor.fail(result.message)
        return
      }
      record.value = { ...record.value, [stage]: result.stage }
      saved.value = new Set(saved.value).add(stage)
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
      :saved="stageSaved('who_is_here')"
      :readonly="readonly"
    />
    <Formation
      v-else-if="current === 'formation'"
      ref="formation"
      :saved="stageSaved('formation')"
      :readonly="readonly"
    />
    <Dynamics
      v-else-if="current === 'dynamics'"
      ref="dynamics"
      :saved="stageSaved('dynamics')"
      :readonly="readonly"
      :has-child="hasChild"
    />
    <DailyLife
      v-else-if="current === 'daily_life'"
      ref="dailyLife"
      :who-people="whoPeople"
      :members="members"
      :saved="stageSaved('daily_life')"
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
