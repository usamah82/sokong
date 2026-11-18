type SignInResult = { ok: true } | { ok: false, message: string }

const tokenKey = 'sokong.token'
const roleKey = 'sokong.role'
const nameKey = 'sokong.name'

export function useAuth() {
  const config = useRuntimeConfig()

  return {
    hasToken(): boolean {
      return typeof sessionStorage !== 'undefined' && sessionStorage.getItem(tokenKey) !== null
    },

    role(): string | null {
      if (typeof sessionStorage === 'undefined') return null
      return sessionStorage.getItem(roleKey)
    },

    name(): string {
      if (typeof sessionStorage === 'undefined') return ''
      return sessionStorage.getItem(nameKey) ?? ''
    },

    clearToken() {
      sessionStorage.removeItem(tokenKey)
      sessionStorage.removeItem(roleKey)
      sessionStorage.removeItem(nameKey)
    },

    async signIn(body: { email: string, password: string }): Promise<SignInResult> {
      const response = await fetch(new URL('/sessions', config.public.apiBase), {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(body)
      })
      if (response.status === 200) {
        const payload = await response.json().catch(() => null) as {
          token?: unknown
          account?: { role?: unknown, name?: unknown }
        } | null
        if (typeof payload?.token !== 'string' || payload.token === '') throw new Error('session was not created')
        sessionStorage.setItem(tokenKey, payload.token)
        if (typeof payload.account?.role === 'string' && payload.account.role !== '') {
          sessionStorage.setItem(roleKey, payload.account.role)
        }
        if (typeof payload.account?.name === 'string') {
          sessionStorage.setItem(nameKey, payload.account.name)
        }
        return { ok: true }
      }
      const payload = await response.json().catch(() => null) as { error?: { message?: string } } | null
      if (response.status === 401 || response.status === 429) {
        return { ok: false, message: payload?.error?.message ?? '' }
      }
      throw new Error('session was not created')
    },

    async signOut(): Promise<void> {
      const token = sessionStorage.getItem(tokenKey)
      if (token) {
        const response = await fetch(new URL('/sessions', config.public.apiBase), {
          method: 'DELETE',
          headers: {
            Accept: 'application/json',
            Authorization: `Bearer ${token}`
          }
        })
        if (response.status !== 204 && response.status !== 401) throw new Error('session was not revoked')
      }
      sessionStorage.removeItem(tokenKey)
      sessionStorage.removeItem(roleKey)
      sessionStorage.removeItem(nameKey)
    }
  }
}
