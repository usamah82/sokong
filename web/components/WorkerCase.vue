<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerDetail } from '../composables/useApi'
import Interview from './interview/Interview.vue'
import { formatVisit, toLocalInput, toUtcInstant, visitIsLate } from '../utils/visitTime'

const props = defineProps<{ enrolment: WorkerDetail }>()

const note = ref('')
const error = ref('')
const submitting = ref(false)
const looks = ref(sorted(props.enrolment.looks))
const { addLook, scheduleVisit } = useApi()
const { clearToken, name } = useAuth()
const { t } = useI18n()
const visitAt = ref(props.enrolment.visit_at)
const visitInput = ref(props.enrolment.visit_at ? toLocalInput(props.enrolment.visit_at) : '')
const bringingBasket = ref(props.enrolment.bringing_basket === true)
const assignedWorkers = ref(startingNames())
const visitError = ref('')
const savingVisit = ref(false)
const emit = defineEmits<{
  marked: [mark: { outcome: string, marked_at: string, marker_name: string }]
}>()
const outcome = ref(props.enrolment.outcome ?? null)

function onMarked(mark: { outcome: string, marked_at: string, marker_name: string }) {
  outcome.value = mark.outcome
  emit('marked', mark)
}

const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
const visitLabel = computed(() => visitAt.value ? formatVisit(visitAt.value, zone) : '')
const late = computed(() => visitAt.value ? visitIsLate(props.enrolment.submitted_at, visitAt.value) : false)

function startingNames() {
  if (props.enrolment.assigned_workers && props.enrolment.assigned_workers.length > 0) {
    return [ ...props.enrolment.assigned_workers ]
  }
  return [ name() ]
}

const helpLabels: Record<string, string> = {
  food: t('wizard.notes.food'),
  clothing: t('wizard.notes.clothing'),
  school_supplies: t('wizard.notes.schoolSupplies'),
  help_applying: t('wizard.notes.helpApplying')
}

const helpNamed = computed(() => props.enrolment.help.length > 0 || props.enrolment.other_help.trim() !== '')

function sorted(rows: WorkerDetail['looks']) {
  return [ ...rows ].sort((left, right) => left.looked_at.localeCompare(right.looked_at))
}

function gender(value: string) {
  if (value === 'male') return t('wizard.family.male')
  if (value === 'female') return t('wizard.family.female')
  return t('wizard.family.unspecified')
}

async function submit() {
  if (submitting.value) return
  submitting.value = true
  error.value = ''
  try {
    const result = await addLook(props.enrolment.id, note.value)
    if (!result.ok) {
      if (result.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      error.value = result.message
      return
    }
    looks.value = sorted([ ...looks.value, result.look ])
    note.value = ''
  } catch {
    // A failed note leaves the typed text.
  } finally {
    submitting.value = false
  }
}

function addWorker() {
  assignedWorkers.value = [ ...assignedWorkers.value, '' ]
}

function nameMissing(value: string) {
  return visitError.value === t('worker.workerRequired') && value.trim() === ''
}

async function saveVisit() {
  if (savingVisit.value) return
  visitError.value = ''
  const instant = toUtcInstant(visitInput.value)
  if (!instant) {
    visitError.value = t('worker.visitInvalid')
    return
  }
  const names = assignedWorkers.value.map((worker) => worker.trim())
  if (names.some((worker) => worker === '')) {
    visitError.value = t('worker.workerRequired')
    return
  }
  savingVisit.value = true
  try {
    const result = await scheduleVisit(props.enrolment.id, {
      visit_at: instant,
      bringing_basket: bringingBasket.value,
      assigned_workers: names
    })
    if (!result.ok) {
      if (result.reason === 'unauthenticated') {
        clearToken()
        await navigateTo('/sign-in')
        return
      }
      visitError.value = result.message
      return
    }
    visitAt.value = result.visit.visit_at
    visitInput.value = toLocalInput(result.visit.visit_at)
    bringingBasket.value = result.visit.bringing_basket
    assignedWorkers.value = [ ...result.visit.assigned_workers ]
  } catch {
    // A failed save leaves the typed time.
  } finally {
    savingVisit.value = false
  }
}
</script>

<template>
  <div class="worker-case">
    <h1>{{ enrolment.place_name }}</h1>
    <p v-if="outcome === 'qualified'" id="outcome">{{ t('worker.qualified') }}</p>
    <p v-else-if="outcome === 'disqualified'" id="outcome">{{ t('worker.disqualified') }}</p>
    <p><span class="label">{{ t('wizard.family.place') }}</span> {{ enrolment.place_name }}</p>
    <p><NuxtLink :id="`locality-${enrolment.locality.id}`" :to="`/localities/${enrolment.locality.id}`">{{ t('boundary.open') }}</NuxtLink></p>
    <p><span class="label">{{ t('wizard.notes.howToFind') }}</span> {{ enrolment.how_to_find }}</p>
    <p><span class="label">{{ t('wizard.family.familyPhone') }}</span> {{ enrolment.family_phone }}</p>
    <p><span class="label">{{ t('worker.enroler') }}</span> {{ enrolment.enroler_contact }}</p>
    <h2 class="label">{{ t('worker.members') }}</h2>
    <article v-for="member in enrolment.members" :id="`member-${member.id}`" :key="member.id" class="person">
      <p>{{ member.name }}</p>
      <p>{{ gender(member.gender) }}<template v-if="member.age !== null">, {{ member.age }}</template></p>
      <p v-if="member.description">{{ member.description }}</p>
      <p>{{ t('wizard.family.education') }} {{ member.in_education ? t('worker.yes') : t('worker.no') }}</p>
      <p>{{ t('wizard.family.working') }} {{ member.working ? t('worker.yes') : t('worker.no') }}</p>
      <p v-if="member.job.trim()"><span class="label">{{ t('wizard.family.job') }}</span> {{ member.job }}</p>
      <p v-if="member.monthly_amount !== null"><span class="label">{{ t('wizard.family.amount') }}</span> {{ member.monthly_amount }}</p>
    </article>
    <h2 class="label">{{ t('wizard.notes.help') }}</h2>
    <p v-if="!helpNamed" id="no-help">{{ t('worker.noHelp') }}</p>
    <ul v-else class="help">
      <li v-for="key in enrolment.help" :key="key">{{ helpLabels[key] ?? key }}</li>
      <li v-if="enrolment.other_help.trim()">{{ enrolment.other_help }}</li>
    </ul>
    <h2 class="label">{{ t('worker.looks') }}</h2>
    <article v-for="look in looks" :id="`look-${look.id}`" :key="look.id" class="look">
      <p class="worker">{{ look.worker_name }}</p>
      <time :datetime="look.looked_at">{{ look.looked_at }}</time>
      <p v-if="look.note">{{ look.note }}</p>
    </article>
    <form novalidate @submit.prevent="submit">
      <label class="field">{{ t('worker.note') }}
        <textarea id="note" v-model="note" rows="3" />
      </label>
      <p v-if="error" class="notice" role="alert">{{ error }}</p>
      <div class="actions">
        <button id="add-note" class="primary" type="submit" :disabled="submitting">{{ t('worker.addNote') }}</button>
      </div>
    </form>
    <section class="pre-visit">
      <h2>{{ t('worker.preVisit') }}</h2>
      <p>{{ t('worker.aim') }}</p>
      <p v-if="!visitAt">{{ t('worker.setBefore') }}</p>
      <p v-if="late">{{ t('worker.late') }}</p>
      <time v-if="visitAt" id="visit-clock" :datetime="visitAt">{{ visitLabel }}</time>
      <template v-if="outcome">
        <p><span class="label">{{ t('worker.bringingBasket') }}</span> {{ bringingBasket ? t('worker.yes') : t('worker.no') }}</p>
        <p class="label">{{ t('worker.assignedWorkers') }}</p>
        <p v-for="(worker, index) in assignedWorkers" :key="index">{{ worker }}</p>
      </template>
      <form v-else class="pre-visit" novalidate @submit.prevent="saveVisit">
        <label class="field">{{ t('worker.visitTime') }}
          <input id="visit-time" v-model="visitInput" type="datetime-local" :aria-invalid="visitError === t('worker.visitInvalid')">
        </label>
        <label class="check">
          <input id="bringing-basket" v-model="bringingBasket" type="checkbox">
          {{ t('worker.bringingBasket') }}
        </label>
        <fieldset>
          <legend class="label">{{ t('worker.assignedWorkers') }}</legend>
          <label v-for="(worker, index) in assignedWorkers" :key="index" class="field">{{ t('wizard.family.name') }}
            <input :id="`assigned-worker-${index}`" v-model="assignedWorkers[index]" type="text" :aria-invalid="nameMissing(worker)">
          </label>
          <button id="add-worker" type="button" @click="addWorker">{{ t('worker.addWorker') }}</button>
        </fieldset>
        <p v-if="visitError" class="error" role="alert">{{ visitError }}</p>
        <div class="actions">
          <button id="save-visit" class="primary" type="submit" :disabled="savingVisit">
            {{ visitAt ? t('worker.changeVisit') : t('worker.setVisit') }}
          </button>
        </div>
      </form>
    </section>
    <Interview
      v-if="visitAt"
      :enrolment-id="enrolment.id"
      :members="enrolment.members"
      :help="enrolment.help"
      :family-phone="enrolment.family_phone"
      :verification="enrolment.verification ?? null"
      :readonly="Boolean(outcome)"
      @marked="onMarked"
    />
  </div>
</template>
