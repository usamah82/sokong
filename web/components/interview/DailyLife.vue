<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerMember } from '../../composables/useApi'

type DayPerson = {
  person_id: string
  name: string
  family_member_id: string | null
  head: boolean
  working: string
  job: string
  monthly_amount: string
  previous_jobs: string
  wished_work: string
  skills: string
  in_school: string
  school_going: string
  school_where: string
  school_travel: string
}

const props = defineProps<{
  whoPeople: unknown[]
  members: WorkerMember[]
  saved: Record<string, unknown> | null
  readonly: boolean
}>()

const { t } = useI18n()
const notes = ref(typeof props.saved?.notes === 'string' ? props.saved.notes : '')
const people = ref(buildPeople())
const openIndex = ref(0)
const error = ref('')
const open = computed(() => people.value[openIndex.value])

function text(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function choice(value: unknown) {
  if (value === true) return 'yes'
  if (value === false) return 'no'
  return ''
}

function rows(value: unknown) {
  if (!Array.isArray(value)) return []
  return value.filter((person) => person && typeof person === 'object') as Record<string, unknown>[]
}

function memberFor(person: DayPerson) {
  if (!person.family_member_id) return null
  return props.members.find((member) => member.id === person.family_member_id) ?? null
}

function buildPeople() {
  const savedRows = rows(props.saved?.people)
  const source = rows(props.whoPeople)
  const ordered = [ ...source ].sort((left, right) => {
    if (left.head === true) return -1
    if (right.head === true) return 1
    return 0
  })
  const base = ordered.length > 0 ? ordered : savedRows
  return base.map((person) => {
    const personId = text(person.person_id)
    const saved = savedRows.find((row) => text(row.person_id) === personId) ?? person
    return {
      person_id: personId,
      name: text(person.name),
      family_member_id: typeof person.family_member_id === 'string' ? person.family_member_id : null,
      head: person.head === true,
      working: choice(saved.working),
      job: text(saved.job),
      monthly_amount: typeof saved.monthly_amount === 'number' ? String(saved.monthly_amount) : '',
      previous_jobs: text(saved.previous_jobs),
      wished_work: text(saved.wished_work),
      skills: text(saved.skills),
      in_school: choice(saved.in_school),
      school_going: text(saved.school_going),
      school_where: text(saved.school_where),
      school_travel: text(saved.school_travel)
    }
  })
}

function amount(value: string) {
  const trimmed = value.trim()
  if (trimmed === '') return null
  if (!/^\d+$/.test(trimmed)) return false
  const parsed = Number(trimmed)
  if (parsed > 999_999_999) return false
  return parsed
}

function attempt() {
  for (const [index, person] of people.value.entries()) {
    if (person.working === 'yes') {
      if (person.job.trim().length > 200) {
        error.value = t('interview.jobTooLong')
        openIndex.value = index
        return null
      }
      if (person.previous_jobs.trim().length > 2000) {
        error.value = t('interview.previousTooLong')
        openIndex.value = index
        return null
      }
      if (person.wished_work.trim().length > 2000) {
        error.value = t('interview.wishedTooLong')
        openIndex.value = index
        return null
      }
      if (amount(person.monthly_amount) === false) {
        error.value = t('interview.amountInvalid')
        openIndex.value = index
        return null
      }
    }
    if (person.skills.trim().length > 2000) {
      error.value = t('interview.skillsTooLong')
      openIndex.value = index
      return null
    }
    if (person.in_school === 'yes' && person.school_where.trim().length > 200) {
      error.value = t('interview.schoolWhereTooLong')
      openIndex.value = index
      return null
    }
  }
  if (notes.value.trim().length > 2000) {
    error.value = t('interview.notesTooLong')
    return null
  }
  error.value = ''
  return {
    people: people.value.map((person) => ({
      person_id: person.person_id,
      working: person.working === '' ? null : person.working === 'yes',
      job: person.working === 'yes' ? person.job.trim() : '',
      monthly_amount: person.working === 'yes' ? amount(person.monthly_amount) : null,
      previous_jobs: person.working === 'yes' ? person.previous_jobs.trim() : '',
      wished_work: person.working === 'yes' ? person.wished_work.trim() : '',
      skills: person.skills.trim(),
      in_school: person.in_school === '' ? null : person.in_school === 'yes',
      school_going: person.in_school === 'yes' ? person.school_going.trim() : '',
      school_where: person.in_school === 'yes' ? person.school_where.trim() : '',
      school_travel: person.in_school === 'yes' ? person.school_travel.trim() : ''
    })),
    notes: notes.value.trim()
  }
}

function fail(message: string) {
  error.value = message
}

function labelFor(person: DayPerson, index: number) {
  return person.name || memberFor(person)?.name || `${t('wizard.members.person')} ${index + 1}`
}

defineExpose({ attempt, fail })
</script>

<template>
  <div>
    <div v-if="!readonly && people.length > 1" class="person-tabs">
      <button
        v-for="(person, index) in people"
        :id="`day-tab-${index}`"
        :key="person.person_id"
        type="button"
        @click="openIndex = index"
      >
        {{ labelFor(person, index) }}
      </button>
    </div>
    <template v-if="readonly">
      <article v-for="(person, index) in people" :key="person.person_id" class="person">
        <p>{{ labelFor(person, index) }}</p>
        <p><span class="label">{{ t('interview.working') }}</span> {{ person.working === 'yes' ? t('worker.yes') : person.working === 'no' ? t('worker.no') : '' }}</p>
        <p v-if="person.working === 'yes'"><span class="label">{{ t('interview.job') }}</span> {{ person.job }}</p>
        <p v-if="person.working === 'yes'"><span class="label">{{ t('interview.amount') }}</span> {{ person.monthly_amount }}</p>
        <p v-if="person.working === 'yes'"><span class="label">{{ t('interview.previousJobs') }}</span> {{ person.previous_jobs }}</p>
        <p v-if="person.working === 'yes'"><span class="label">{{ t('interview.wishedWork') }}</span> {{ person.wished_work }}</p>
        <p><span class="label">{{ t('interview.skills') }}</span> {{ person.skills }}</p>
        <p><span class="label">{{ t('interview.inSchool') }}</span> {{ person.in_school === 'yes' ? t('worker.yes') : person.in_school === 'no' ? t('worker.no') : '' }}</p>
        <p v-if="person.in_school === 'yes'"><span class="label">{{ t('interview.schoolGoing') }}</span> {{ person.school_going }}</p>
        <p v-if="person.in_school === 'yes'"><span class="label">{{ t('interview.schoolWhere') }}</span> {{ person.school_where }}</p>
        <p v-if="person.in_school === 'yes'"><span class="label">{{ t('interview.schoolTravel') }}</span> {{ person.school_travel }}</p>
      </article>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else-if="open">
      <div v-if="memberFor(open)" id="daily-enrolment">
        <p class="label">{{ t('interview.enrolment') }}</p>
        <p>{{ t('wizard.family.working') }} {{ memberFor(open)!.working ? t('worker.yes') : t('worker.no') }}</p>
        <p>{{ t('wizard.family.education') }} {{ memberFor(open)!.in_education ? t('worker.yes') : t('worker.no') }}</p>
        <p v-if="memberFor(open)!.job">{{ t('wizard.family.job') }} {{ memberFor(open)!.job }}</p>
        <p v-if="memberFor(open)!.monthly_amount !== null">{{ t('wizard.family.amount') }} {{ memberFor(open)!.monthly_amount }}</p>
      </div>
      <label class="field">{{ t('interview.working') }}
        <select id="working" v-model="open.working">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <template v-if="open.working === 'yes'">
        <label class="field">{{ t('interview.job') }}
          <input id="job" v-model="open.job" type="text">
        </label>
        <label class="field">{{ t('interview.amount') }}
          <input id="monthly-amount" v-model="open.monthly_amount" type="text" inputmode="numeric" :aria-invalid="error === t('interview.amountInvalid')">
        </label>
        <label class="field">{{ t('interview.previousJobs') }}
          <textarea id="previous-jobs" v-model="open.previous_jobs" rows="2" />
        </label>
        <label class="field">{{ t('interview.wishedWork') }}
          <textarea id="wished-work" v-model="open.wished_work" rows="2" />
        </label>
      </template>
      <label class="field">{{ t('interview.skills') }}
        <textarea id="skills" v-model="open.skills" rows="2" />
      </label>
      <label class="field">{{ t('interview.inSchool') }}
        <select id="in-school" v-model="open.in_school">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <template v-if="open.in_school === 'yes'">
        <label class="field">{{ t('interview.schoolGoing') }}
          <textarea id="school-going" v-model="open.school_going" rows="2" />
        </label>
        <label class="field">{{ t('interview.schoolWhere') }}
          <input id="school-where" v-model="open.school_where" type="text">
        </label>
        <label class="field">{{ t('interview.schoolTravel') }}
          <textarea id="school-travel" v-model="open.school_travel" rows="2" />
        </label>
      </template>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="daily-notes" v-model="notes" rows="3" />
      </label>
    </template>
    <label v-else class="field">{{ t('interview.notes') }}
      <textarea id="daily-notes" v-model="notes" rows="3" />
    </label>
    <p v-if="error" class="error" role="alert">{{ error }}</p>
  </div>
</template>
