type LocalitySuggestion = {
  locality: { name: string } | null
}

type EnrolmentResult = { ok: true } | { ok: false, message: string }

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

    async createAccount(body: { email: string, password: string, password_confirmation: string }): Promise<EnrolmentResult> {
      const response = await fetch(new URL('/accounts', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      })
      if (response.status === 201) return { ok: true }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 422 || response.status === 429) return { ok: false, message: payload?.error?.message ?? '' }
      throw new Error('account was not created')
    }
  }
}
