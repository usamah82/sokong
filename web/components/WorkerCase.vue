<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerDetail } from '../composables/useApi'

const props = defineProps<{ enrolment: WorkerDetail }>()

const note = ref('')
const error = ref('')
const submitting = ref(false)
const looks = ref(sorted(props.enrolment.looks))
const { addLook } = useApi()
const { clearToken } = useAuth()
const { t } = useI18n()

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
</script>

<template>
  <div class="worker-case">
    <h1>{{ enrolment.place_name }}</h1>
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
  </div>
</template>
