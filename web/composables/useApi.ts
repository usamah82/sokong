type LocalitySuggestion = {
  locality: { name: string } | null
}

type EnrolmentResult = { ok: true } | { ok: false, message: string }

type AccountField = 'email' | 'password' | 'password_confirmation'

type AccountResult = { ok: true } | { ok: false, message: string, field: AccountField | null }

type ConfirmResult = { ok: true } | { ok: false, reason: 'invalid' | 'limited' }

type Look = {
  id: string
  worker_name: string
  looked_at: string
  note: string
}

export type SubmitterEnrolment = {
  id: string
  place_name: string
  members: { name: string, role: string }[]
  progress: {
    case_in: boolean
    looks: Look[]
    visit_at: string | null
  }
}

export type WorkerSummary = {
  id: string
  submitted_at: string
  place_name: string
  head_name: string
  enroler_contact: string
  on_behalf: boolean
  locality: { id: string, name: string }
}

export type WorkerMember = {
  id: string
  role: string
  name: string
  age: number | null
  gender: string
  description: string
  in_education: boolean
  working: boolean
  job: string
  monthly_amount: number | null
}

export type WorkerDetail = WorkerSummary & {
  email: string
  how_to_find: string
  family_phone: string
  help: string[]
  other_help: string
  consent_text: string
  latitude: number | null
  longitude: number | null
  members: WorkerMember[]
  looks: Look[]
  visit_at: string | null
  bringing_basket: boolean | null
  assigned_workers: string[] | null
  verification?: Record<string, unknown> | null
  outcome?: string | null
}

type EnrolmentListResult =
  | { ok: true, enrolments: Array<SubmitterEnrolment | WorkerSummary> }
  | { ok: false, reason: 'unauthenticated' | 'unlinked' }

type EnrolmentDetailResult =
  | { ok: true, kind: 'submitter', enrolment: SubmitterEnrolment }
  | { ok: true, kind: 'worker', enrolment: WorkerDetail }
  | { ok: false, reason: 'unauthenticated' | 'missing' }

type LookResult =
  | { ok: true, look: Look }
  | { ok: false, reason: 'unauthenticated' | 'invalid', message: string }

export type VisitFields = {
  visit_at: string
  bringing_basket: boolean
  assigned_workers: string[]
}

type VisitResult =
  | { ok: true, visit: VisitFields }
  | { ok: false, reason: 'unauthenticated' | 'invalid', message: string }

type StageResult =
  | { ok: true, stage: Record<string, unknown> }
  | { ok: false, reason: 'unauthenticated' | 'invalid', message: string }

export type LocalityBoundary = {
  id: string
  name: string
  latitude: number | null
  longitude: number | null
  radius_metres: number | null
}

type LocalityResult =
  | { ok: true, locality: LocalityBoundary }
  | { ok: false, reason: 'unauthenticated' | 'missing' | 'invalid', message: string }

const accountFields: AccountField[] = [ 'email', 'password', 'password_confirmation' ]

export function useApi() {
  const config = useRuntimeConfig()

  return {
    async suggestLocality(latitude: number, longitude: number): Promise<LocalitySuggestion> {
      const url = new URL('/localities/suggestion', config.public.apiBase)
      url.searchParams.set('latitude', String(latitude))
      url.searchParams.set('longitude', String(longitude))
      const response = await fetch(url)
      if (!response.ok) return { locality: null }
      return response.json() as Promise<LocalitySuggestion>
    },

    async submitEnrolment(body: Record<string, unknown>): Promise<EnrolmentResult> {
      const response = await fetch(new URL('/enrolments', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      })
      if (response.status === 201) return { ok: true }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 422) return { ok: false, message: payload?.error?.message ?? '' }
      throw new Error('enrolment was not saved')
    },

    async createAccount(body: { email: string, password: string, password_confirmation: string }): Promise<AccountResult> {
      const response = await fetch(new URL('/accounts', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      })
      if (response.status === 201) return { ok: true }
      const payload = await response.json().catch(() => null) as {
        error?: { message?: string, details?: Record<string, unknown> }
      } | null
      if (response.status === 422 || response.status === 429) {
        const details = payload?.error?.details
        const field = details ? accountFields.find((key) => Object.prototype.hasOwnProperty.call(details, key)) ?? null : null
        return { ok: false, message: payload?.error?.message ?? '', field }
      }
      throw new Error('account was not created')
    },

    async confirmEmail(token: string): Promise<ConfirmResult> {
      const response = await fetch(new URL('/account_verifications', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ token })
      })
      if (response.status === 204) return { ok: true }
      if (response.status === 429) return { ok: false, reason: 'limited' }
      if (response.status === 422) return { ok: false, reason: 'invalid' }
      throw new Error('email was not confirmed')
    },

    async listEnrolments(): Promise<EnrolmentListResult> {
      const response = await authorizedGet('/enrolments', config.public.apiBase)
      if (response.status === 200) {
        return { ok: true, enrolments: await response.json() as Array<SubmitterEnrolment | WorkerSummary> }
      }
      if (response.status === 401) return { ok: false, reason: 'unauthenticated' }
      if (response.status === 403) return { ok: false, reason: 'unlinked' }
      throw new Error('enrolments were not read')
    },

    async readEnrolment(id: string): Promise<EnrolmentDetailResult> {
      const response = await authorizedGet(`/enrolments/${id}`, config.public.apiBase)
      if (response.status === 200) {
        const enrolment = await response.json() as SubmitterEnrolment | WorkerDetail
        if ('progress' in enrolment) return { ok: true, kind: 'submitter', enrolment }
        return { ok: true, kind: 'worker', enrolment }
      }
      if (response.status === 401) return { ok: false, reason: 'unauthenticated' }
      if (response.status === 404) return { ok: false, reason: 'missing' }
      throw new Error('enrolment was not read')
    },

    async scheduleVisit(id: string, body: VisitFields): Promise<VisitResult> {
      const token = sessionStorage.getItem('sokong.token')
      const response = await fetch(new URL(`/enrolments/${id}/visit`, config.public.apiBase), {
        method: 'PATCH',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        },
        body: JSON.stringify(body)
      })
      if (response.status === 200) return { ok: true, visit: await response.json() as VisitFields }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 401) return { ok: false, reason: 'unauthenticated', message: payload?.error?.message ?? '' }
      if (response.status === 422) return { ok: false, reason: 'invalid', message: payload?.error?.message ?? '' }
      throw new Error('visit was not saved')
    },

    async saveStage(id: string, stage: string, body: Record<string, unknown>): Promise<StageResult> {
      const token = sessionStorage.getItem('sokong.token')
      const response = await fetch(new URL(`/enrolments/${id}/verification/${stage}`, config.public.apiBase), {
        method: 'PUT',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        },
        body: JSON.stringify(body)
      })
      if (response.status === 200) return { ok: true, stage: await response.json() as Record<string, unknown> }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 401) return { ok: false, reason: 'unauthenticated', message: payload?.error?.message ?? '' }
      if (response.status === 422) return { ok: false, reason: 'invalid', message: payload?.error?.message ?? '' }
      throw new Error('stage was not saved')
    },

    async addLook(id: string, note: string): Promise<LookResult> {
      const token = sessionStorage.getItem('sokong.token')
      const response = await fetch(new URL(`/enrolments/${id}/looks`, config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        },
        body: JSON.stringify({ note })
      })
      if (response.status === 201) return { ok: true, look: await response.json() as Look }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 401) return { ok: false, reason: 'unauthenticated', message: payload?.error?.message ?? '' }
      if (response.status === 422) return { ok: false, reason: 'invalid', message: payload?.error?.message ?? '' }
      throw new Error('note was not saved')
    },

    async updateLocality(id: string, body: Record<string, unknown>): Promise<LocalityResult> {
      const token = sessionStorage.getItem('sokong.token')
      const response = await fetch(new URL(`/localities/${id}`, config.public.apiBase), {
        method: 'PATCH',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {})
        },
        body: JSON.stringify(body)
      })
      if (response.status === 200) return { ok: true, locality: await response.json() as LocalityBoundary }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 401) return { ok: false, reason: 'unauthenticated', message: payload?.error?.message ?? '' }
      if (response.status === 404) return { ok: false, reason: 'missing', message: payload?.error?.message ?? '' }
      if (response.status === 422) return { ok: false, reason: 'invalid', message: payload?.error?.message ?? '' }
      throw new Error('locality was not saved')
    }
  }
}

function authorizedGet(path: string, apiBase: string) {
  const token = sessionStorage.getItem('sokong.token')
  return fetch(new URL(path, apiBase), {
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    }
  })
}
