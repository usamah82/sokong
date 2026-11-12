import type { FamilyMember } from '../components/MemberFields.vue'

const helpKeys = [ 'food', 'clothing', 'school_supplies', 'help_applying' ] as const

export type EnrolmentDraft = {
  onBehalf: boolean
  consentText: string
  phone: string
  email: string
  place: string
  familyPhone: string
  latitude: number | null
  longitude: number | null
  howToFind: string
  help: string[]
  otherHelp: string
  head: FamilyMember
  others: FamilyMember[]
}

export function enrolmentPayload(draft: EnrolmentDraft) {
  const body: Record<string, unknown> = {
    on_behalf: draft.onBehalf,
    consent_text: draft.consentText,
    enroler_contact: draft.phone,
    place_name: draft.place,
    family_phone: draft.familyPhone,
    how_to_find: draft.howToFind,
    help: helpKeys.filter((key) => draft.help.includes(key)),
    other_help: draft.otherHelp,
    members: [
      memberPayload(draft.head, 'head'),
      ...draft.others.map((person) => memberPayload(person, 'member'))
    ]
  }
  if (draft.email !== '') body.email = draft.email
  if (draft.latitude !== null && draft.longitude !== null) {
    body.latitude = draft.latitude
    body.longitude = draft.longitude
  }
  return body
}

function memberPayload(person: FamilyMember, role: 'head' | 'member') {
  const body: Record<string, unknown> = {
    role,
    name: person.name,
    gender: person.gender,
    description: person.description,
    in_education: person.education,
    working: person.working
  }
  const age = jsonInteger(person.age)
  if (age !== undefined) body.age = age
  if (person.working) {
    body.job = person.job
    const amount = jsonInteger(person.amount)
    if (amount !== undefined) body.monthly_amount = amount
  }
  return body
}

function jsonInteger(value: string) {
  const trimmed = value.trim()
  if (trimmed === '') return undefined
  if (/^-?(0|[1-9]\d*)$/.test(trimmed)) return Number(trimmed)
  return trimmed
}
