<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerMember } from '../../composables/useApi'
import Boxes from './Boxes.vue'
import DailyLife from './DailyLife.vue'
import Dynamics from './Dynamics.vue'
import Formation from './Formation.vue'
import House from './House.vue'
import Needs from './Needs.vue'
import WhoIsHere from './WhoIsHere.vue'

const props = defineProps<{
  enrolmentId: string
  members: WorkerMember[]
  help: string[]
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

const emit = defineEmits<{
  marked: [mark: { outcome: string, marked_at: string, marker_name: string }]
}>()

const { t } = useI18n()
const { saveStage, markQualification } = useApi()
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
const house = ref<Editor | null>(null)
const needs = ref<Editor | null>(null)

type BoxesEditor = Editor & {
  notices: (outcome: 'qualified' | 'disqualified') => string[]
  show: (messages: string[]) => void
}

const boxes = ref<BoxesEditor | null>(null)
const boxesSaved = ref(Boolean(props.verification?.boxes))

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
  if (key === 'house') return house.value
  if (key === 'needs') return needs.value
  return null
}

function statusText(key: StageKey) {
  const parts: string[] = []
  if (current.value === key) parts.push(t('interview.current'))
  parts.push(saved.value.has(key) ? t('interview.saved') : t('interview.notSaved'))
  return parts.join(' ')
}

const consentGiven = computed(() => {
  const stage = record.value.needs
  if (!stage || typeof stage !== 'object') return null
  const value = (stage as { consent_given?: unknown }).consent_given
  return value === true || value === false ? value : null
})

function once(messages: string[]) {
  return messages.filter((message, index) => message !== '' && messages.indexOf(message) === index)
}

async function mark(outcome: 'qualified' | 'disqualified') {
  const editor = boxes.value
  if (!editor || saving.value || props.readonly) return
  const body = editor.attempt()
  if (!body) return
  const notices = editor.notices(outcome)
  saving.value = true
  try {
    const saved = await saveStage(props.enrolmentId, 'boxes', body)
    if (!saved.ok) {
      if (saved.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      editor.show(once([ ...notices, saved.message ]))
      return
    }
    record.value = { ...record.value, boxes: saved.stage }
    boxesSaved.value = true
    const marked = await markQualification(props.enrolmentId, outcome)
    if (!marked.ok) {
      if (marked.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      editor.show(once([ ...notices, marked.message ]))
      return
    }
    editor.show([])
    emit('marked', marked.mark)
  } catch {
    return
  } finally {
    saving.value = false
  }
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
    <House
      v-else-if="current === 'house'"
      ref="house"
      :saved="stageSaved('house')"
      :readonly="readonly"
    />
    <Needs
      v-else-if="current === 'needs'"
      ref="needs"
      :help="help"
      :saved="stageSaved('needs')"
      :readonly="readonly"
    />
    <section v-else :id="`open-${current}`">
      <h3>{{ labelOf(current) }}</h3>
    </section>
    <div class="actions">
      <button v-if="!readonly && index > 0" id="back-stage" class="secondary" type="button" @click="leave(stages[index - 1]!.key)">{{ t('interview.back') }}</button>
      <button v-if="!readonly && index < stages.length - 1" id="next-stage" class="primary" type="button" @click="leave(stages[index + 1]!.key)">{{ t('interview.next') }}</button>
    </div>
  </section>
  <Boxes
    ref="boxes"
    :saved="boxesSaved ? stageSaved('boxes') : null"
    :consent-given="consentGiven"
    :readonly="readonly"
    @mark="mark"
  />
</template>
