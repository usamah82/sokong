type LocalitySuggestion = {
  locality: { name: string } | null
}

type EnrolmentResult = { ok: true } | { ok: false, message: string }

type AccountField = 'email' | 'password' | 'password_confirmation'

type AccountResult = { ok: true } | { ok: false, message: string, field: AccountField | null }

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

    async confirmEmail(token: string): Promise<AccountResult> {
      const response = await fetch(new URL('/account_verifications', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ token })
      })
      if (response.status === 204) return { ok: true }
      const payload = await response.json().catch(() => null) as {
        error?: { message?: string, details?: Record<string, unknown> }
      } | null
      if (response.status === 422 || response.status === 429) {
        return { ok: false, message: payload?.error?.message ?? '', field: null }
      }
      throw new Error('email was not confirmed')
    }
  }
}
