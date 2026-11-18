<script setup lang="ts">
import { computed, ref } from 'vue'
import type { WorkerMember } from '../../composables/useApi'
import { phoneMatches } from '../../utils/phone'

type DocumentRow = { kind: string, number: string, other_label: string }

type PersonRow = {
  person_id: string
  family_member_id: string | null
  head: boolean
  name: string
  birth_date: string
  gender: string
  phone: string
  documents: DocumentRow[]
  origin: string
  relationship: string
  identity: string
  absent: boolean
  absent_since: string
  absent_reason: string
}

const props = defineProps<{
  members: WorkerMember[]
  familyPhone: string
  saved: Record<string, unknown> | null
  readonly: boolean
}>()

const { t } = useI18n()
const phoneMessage = t('wizard.enroler.phoneError')
const nameMessage = t('interview.nameRequired')
const people = ref(peopleFrom(props.saved))
const openIndex = ref(0)
const othersStay = ref(yesNo(props.saved?.others_stay))
const othersDetail = ref(text(props.saved?.others_stay_detail))
const care = ref(yesNo(props.saved?.care_for_parents))
const careDetail = ref(text(props.saved?.care_for_parents_detail))
const notes = ref(text(props.saved?.notes))
const error = ref('')

const openPerson = computed(() => people.value[openIndex.value] ?? people.value[0]!)

function text(value: unknown) {
  return typeof value === 'string' ? value : ''
}

function yesNo(value: unknown) {
  if (value === true) return 'yes'
  if (value === false) return 'no'
  return ''
}

function orderedMembers() {
  return [ ...props.members ].sort((left, right) => {
    if (left.role === 'head') return -1
    if (right.role === 'head') return 1
    return 0
  })
}

function blank(member?: WorkerMember): PersonRow {
  return {
    person_id: crypto.randomUUID(),
    family_member_id: member?.id ?? null,
    head: member?.role === 'head',
    name: '',
    birth_date: '',
    gender: '',
    phone: '',
    documents: [],
    origin: '',
    relationship: '',
    identity: '',
    absent: false,
    absent_since: '',
    absent_reason: ''
  }
}

function readDocument(value: unknown): DocumentRow {
  const row = value && typeof value === 'object' ? value as Record<string, unknown> : {}
  return { kind: text(row.kind), number: text(row.number), other_label: text(row.other_label) }
}

function readPerson(value: unknown): PersonRow {
  const row = value && typeof value === 'object' ? value as Record<string, unknown> : {}
  return {
    person_id: typeof row.person_id === 'string' ? row.person_id : crypto.randomUUID(),
    family_member_id: typeof row.family_member_id === 'string' ? row.family_member_id : null,
    head: row.head === true,
    name: text(row.name),
    birth_date: text(row.birth_date),
    gender: text(row.gender),
    phone: text(row.phone),
    documents: Array.isArray(row.documents) ? row.documents.map(readDocument) : [],
    origin: text(row.origin),
    relationship: text(row.relationship),
    identity: text(row.identity),
    absent: row.absent === true,
    absent_since: text(row.absent_since),
    absent_reason: text(row.absent_reason)
  }
}

function peopleFrom(saved: Record<string, unknown> | null) {
  const raw = saved?.people
  if (Array.isArray(raw) && raw.length > 0) return raw.map(readPerson)
  const seeded = orderedMembers().map((member) => blank(member))
  return seeded.length > 0 ? seeded : [ blank() ]
}

function memberFor(person: PersonRow) {
  if (!person.family_member_id) return null
  return props.members.find((member) => member.id === person.family_member_id) ?? null
}

function genderLabel(value: string) {
  if (value === 'male') return t('wizard.family.male')
  if (value === 'female') return t('wizard.family.female')
  if (value === 'unspecified') return t('wizard.family.unspecified')
  return ''
}

function identityLabel(value: string) {
  if (value === 'verified') return t('interview.verified')
  if (value === 'not_verified') return t('interview.notVerified')
  if (value === 'no_papers') return t('interview.noPapers')
  return ''
}

function relationshipLabel(value: string) {
  if (value === 'spouse') return t('interview.spouse')
  if (value === 'child') return t('interview.child')
  if (value === 'parent') return t('interview.parent')
  if (value === 'other') return t('interview.other')
  return ''
}

function documentLabel(value: string) {
  if (value === 'national_id') return t('interview.nationalId')
  if (value === 'social_security') return t('interview.socialSecurity')
  if (value === 'passport') return t('interview.passport')
  if (value === 'birth_certificate') return t('interview.birthCertificate')
  if (value === 'other') return t('interview.other')
  return ''
}

function personLabel(person: PersonRow, index: number) {
  const typed = person.name.trim()
  if (typed) return typed
  return memberFor(person)?.name || `${t('wizard.members.person')} ${index + 1}`
}

function problem(): { index: number, message: string } | null {
  for (const [index, person] of people.value.entries()) {
    if (person.name.trim() === '') return { index, message: nameMessage }
    if (person.phone.trim() !== '' && !phoneMatches(person.phone)) return { index, message: phoneMessage }
    for (const document of person.documents) {
      if (document.kind === '') return { index, message: t('interview.documentInvalid') }
      if (document.number.trim() === '') return { index, message: t('interview.numberRequired') }
      if (document.kind === 'other' && document.other_label.trim() === '') return { index, message: t('interview.whatRequired') }
    }
  }
  return null
}

function payload() {
  return {
    people: people.value.map((person) => ({
      person_id: person.person_id,
      family_member_id: person.family_member_id,
      head: person.head,
      name: person.name.trim(),
      birth_date: person.birth_date,
      gender: person.gender,
      phone: person.phone.trim(),
      documents: person.documents.map((document) => ({
        kind: document.kind,
        number: document.number.trim(),
        other_label: document.kind === 'other' ? document.other_label.trim() : ''
      })),
      origin: person.relationship === 'child' ? '' : person.origin.trim(),
      relationship: person.head ? '' : person.relationship,
      identity: person.identity,
      absent: person.absent,
      absent_since: person.absent ? person.absent_since : '',
      absent_reason: person.absent ? person.absent_reason.trim() : ''
    })),
    others_stay: othersStay.value === '' ? null : othersStay.value === 'yes',
    others_stay_detail: othersStay.value === 'yes' ? othersDetail.value.trim() : '',
    care_for_parents: care.value === '' ? null : care.value === 'yes',
    care_for_parents_detail: care.value === 'yes' ? careDetail.value.trim() : '',
    notes: notes.value.trim()
  }
}

function attempt() {
  const found = problem()
  if (found) {
    error.value = found.message
    openIndex.value = found.index
    return null
  }
  error.value = ''
  return payload()
}

function fail(message: string) {
  error.value = message
}

function addPerson() {
  people.value = [ ...people.value, blank() ]
  openIndex.value = people.value.length - 1
}

function removePerson() {
  const person = openPerson.value
  if (person.family_member_id) return
  people.value = people.value.filter((row) => row.person_id !== person.person_id)
  openIndex.value = Math.max(0, openIndex.value - 1)
}

function addDocument() {
  openPerson.value.documents.push({ kind: '', number: '', other_label: '' })
}

function removeDocument(index: number) {
  openPerson.value.documents.splice(index, 1)
}

function nameInvalid(person: PersonRow) {
  return error.value === nameMessage && person.name.trim() === ''
}

function phoneInvalid(person: PersonRow) {
  return error.value === phoneMessage && person.phone.trim() !== '' && !phoneMatches(person.phone)
}

defineExpose({ attempt, fail })
</script>

<template>
  <div>
    <p id="children-recorded">{{ t('interview.children') }}</p>
    <div v-if="!readonly" class="person-tabs">
      <button
        v-for="(person, index) in people"
        :id="`person-tab-${index}`"
        :key="person.person_id"
        type="button"
        @click="openIndex = index"
      >
        {{ personLabel(person, index) }}
      </button>
    </div>
    <template v-if="readonly">
      <article v-for="person in people" :key="person.person_id" class="person">
        <div v-if="memberFor(person)" class="enrolment-facts">
          <p class="label">{{ t('interview.enrolment') }}</p>
          <p>{{ memberFor(person)!.name }}</p>
          <p>{{ genderLabel(memberFor(person)!.gender) }}</p>
          <p v-if="person.head && familyPhone">{{ familyPhone }}</p>
        </div>
        <p v-if="person.head">{{ t('interview.head') }}</p>
        <p><span class="label">{{ t('interview.fullName') }}</span> {{ person.name }}</p>
        <p><span class="label">{{ t('interview.birthDate') }}</span> {{ person.birth_date }}</p>
        <p><span class="label">{{ t('wizard.family.gender') }}</span> {{ genderLabel(person.gender) }}</p>
        <p><span class="label">{{ t('interview.phone') }}</span> {{ person.phone }}</p>
        <p v-if="!person.head"><span class="label">{{ t('interview.relationship') }}</span> {{ relationshipLabel(person.relationship) }}</p>
        <p v-if="person.relationship !== 'child'"><span class="label">{{ t('interview.origin') }}</span> {{ person.origin }}</p>
        <p><span class="label">{{ t('interview.identity') }}</span> {{ identityLabel(person.identity) }}</p>
        <p><span class="label">{{ t('interview.documents') }}</span></p>
        <p v-for="(document, index) in person.documents" :key="index">
          {{ documentLabel(document.kind) }} {{ document.number }}
          <template v-if="document.kind === 'other'"> {{ document.other_label }}</template>
        </p>
        <p><span class="label">{{ t('interview.absent') }}</span> {{ person.absent ? t('worker.yes') : t('worker.no') }}</p>
        <p v-if="person.absent"><span class="label">{{ t('interview.since') }}</span> {{ person.absent_since }}</p>
        <p v-if="person.absent"><span class="label">{{ t('interview.why') }}</span> {{ person.absent_reason }}</p>
      </article>
      <p><span class="label">{{ t('interview.othersStay') }}</span> {{ othersStay === 'yes' ? t('worker.yes') : othersStay === 'no' ? t('worker.no') : '' }}</p>
      <p v-if="othersStay === 'yes'">{{ othersDetail }}</p>
      <p><span class="label">{{ t('interview.care') }}</span> {{ care === 'yes' ? t('worker.yes') : care === 'no' ? t('worker.no') : '' }}</p>
      <p v-if="care === 'yes'">{{ careDetail }}</p>
      <p><span class="label">{{ t('interview.notes') }}</span> {{ notes }}</p>
    </template>
    <template v-else>
      <div v-if="memberFor(openPerson)" id="enrolment-facts">
        <p class="label">{{ t('interview.enrolment') }}</p>
        <p>{{ memberFor(openPerson)!.name }}</p>
        <p>{{ genderLabel(memberFor(openPerson)!.gender) }}</p>
        <p v-if="openPerson.head && familyPhone">{{ familyPhone }}</p>
      </div>
      <p v-if="openPerson.head">{{ t('interview.head') }}</p>
      <label class="field">{{ t('interview.fullName') }}
        <input id="person-name" v-model="openPerson.name" type="text" :aria-invalid="nameInvalid(openPerson)">
      </label>
      <label class="field">{{ t('interview.birthDate') }}
        <input id="person-birth" v-model="openPerson.birth_date" type="date">
      </label>
      <label class="field">{{ t('wizard.family.gender') }}
        <select id="person-gender" v-model="openPerson.gender">
          <option value="" />
          <option value="male">{{ t('wizard.family.male') }}</option>
          <option value="female">{{ t('wizard.family.female') }}</option>
          <option value="unspecified">{{ t('wizard.family.unspecified') }}</option>
        </select>
      </label>
      <label class="field">{{ t('interview.phone') }}
        <input id="person-phone" v-model="openPerson.phone" type="tel" :aria-invalid="phoneInvalid(openPerson)">
      </label>
      <label v-if="!openPerson.head" class="field">{{ t('interview.relationship') }}
        <select id="person-relationship" v-model="openPerson.relationship">
          <option value="" />
          <option value="spouse">{{ t('interview.spouse') }}</option>
          <option value="child">{{ t('interview.child') }}</option>
          <option value="parent">{{ t('interview.parent') }}</option>
          <option value="other">{{ t('interview.other') }}</option>
        </select>
      </label>
      <label v-if="openPerson.relationship !== 'child'" class="field">{{ t('interview.origin') }}
        <input id="person-origin" v-model="openPerson.origin" type="text">
      </label>
      <label class="field">{{ t('interview.identity') }}
        <select id="person-identity" v-model="openPerson.identity">
          <option value="" />
          <option value="verified">{{ t('interview.verified') }}</option>
          <option value="not_verified">{{ t('interview.notVerified') }}</option>
          <option value="no_papers">{{ t('interview.noPapers') }}</option>
        </select>
      </label>
      <fieldset>
        <legend class="label">{{ t('interview.documents') }}</legend>
        <div v-for="(document, index) in openPerson.documents" :key="index">
          <label class="field">{{ t('interview.document') }}
            <select :id="`document-kind-${index}`" v-model="document.kind">
              <option value="" />
              <option value="national_id">{{ t('interview.nationalId') }}</option>
              <option value="social_security">{{ t('interview.socialSecurity') }}</option>
              <option value="passport">{{ t('interview.passport') }}</option>
              <option value="birth_certificate">{{ t('interview.birthCertificate') }}</option>
              <option value="other">{{ t('interview.other') }}</option>
            </select>
          </label>
          <label class="field">{{ t('interview.number') }}
            <input :id="`document-number-${index}`" v-model="document.number" type="text">
          </label>
          <label v-if="document.kind === 'other'" class="field">{{ t('interview.whatDocument') }}
            <input :id="`document-other-${index}`" v-model="document.other_label" type="text">
          </label>
          <button :id="`remove-document-${index}`" type="button" @click="removeDocument(index)">{{ t('interview.remove') }}</button>
        </div>
        <button id="add-document" type="button" @click="addDocument">{{ t('interview.addDocument') }}</button>
      </fieldset>
      <label class="check">
        <input id="person-absent" v-model="openPerson.absent" type="checkbox">
        {{ t('interview.absent') }}
      </label>
      <template v-if="openPerson.absent">
        <label class="field">{{ t('interview.since') }}
          <input id="absent-since" v-model="openPerson.absent_since" type="date">
        </label>
        <label class="field">{{ t('interview.why') }}
          <input id="absent-reason" v-model="openPerson.absent_reason" type="text">
        </label>
      </template>
      <button v-if="!openPerson.family_member_id" id="remove-person" type="button" @click="removePerson">{{ t('interview.remove') }}</button>
      <button id="add-person" type="button" @click="addPerson">{{ t('interview.addPerson') }}</button>
      <label class="field">{{ t('interview.othersStay') }}
        <select id="others-stay" v-model="othersStay">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <label v-if="othersStay === 'yes'" class="field">{{ t('interview.othersDetail') }}
        <input id="others-detail" v-model="othersDetail" type="text">
      </label>
      <label class="field">{{ t('interview.care') }}
        <select id="care-for-parents" v-model="care">
          <option value="" />
          <option value="yes">{{ t('worker.yes') }}</option>
          <option value="no">{{ t('worker.no') }}</option>
        </select>
      </label>
      <label v-if="care === 'yes'" class="field">{{ t('interview.careDetail') }}
        <input id="care-detail" v-model="careDetail" type="text">
      </label>
      <label class="field">{{ t('interview.notes') }}
        <textarea id="stage-notes" v-model="notes" rows="3" />
      </label>
      <p v-if="error" class="error" role="alert">{{ error }}</p>
    </template>
  </div>
</template>
