import { mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import ConfirmPage from '../../pages/confirm.vue'

const confirmed = 'This email is confirmed. Sign in.'
const invalid = 'Confirmation link is invalid'
const token = 'opaque-confirm-token'

type CapturedRequest = {
  url: string
  method: string
  authorization: string | null
  json: Record<string, unknown>
}

function stubVerification(status: number, body: unknown) {
  const calls: CapturedRequest[] = []
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers)
    calls.push({
      url: String(input),
      method: init?.method ?? 'GET',
      authorization: headers.get('Authorization'),
      json: JSON.parse(String(init?.body)) as Record<string, unknown>
    })
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => body
    }
  }))
  return calls
}

describe('email confirmation', () => {
  beforeEach(() => {
    sessionStorage.clear()
  })

  it('confirms the email from the link and stores no token', async () => {
    const calls = stubVerification(204, { token: 'secret-token' })
    const page = await mountSuspended(ConfirmPage, { route: `/confirm?token=${token}` })
    await vi.waitFor(() => {
      expect(page.text()).toContain(confirmed)
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/account_verifications')
    expect(request.method).toBe('POST')
    expect(request.authorization).toBeNull()
    expect(request.json).toEqual({ token })
    expect(page.text()).not.toContain(token)
    expect(page.text()).not.toContain('secret-token')
    expect(page.get('#sign-in').attributes('href')).toBe('/sign-in')
    expect(page.find('#sign-up').exists()).toBe(false)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('shows an invalid link and offers sign up', async () => {
    sessionStorage.setItem('sokong.token', 'already-here')
    stubVerification(422, {
      error: { code: 'VALIDATION_ERROR', message: invalid, details: {} }
    })
    const page = await mountSuspended(ConfirmPage, { route: `/confirm?token=${token}` })
    await vi.waitFor(() => {
      expect(page.text()).toContain(invalid)
    })
    expect(page.text()).not.toContain(confirmed)
    expect(page.text()).not.toContain(token)
    expect(page.get('#sign-up').attributes('href')).toBe('/sign-up')
    expect(page.find('#sign-in').exists()).toBe(false)
    expect(sessionStorage.getItem('sokong.token')).toBe('already-here')
    vi.unstubAllGlobals()
  })

  it('shows too many attempts and does not store a token', async () => {
    const calls = stubVerification(429, {
      error: { code: 'RATE_LIMITED', message: 'Too many attempts. Try again later.', details: {} }
    })
    const page = await mountSuspended(ConfirmPage, { route: `/confirm?token=${token}` })
    await vi.waitFor(() => {
      expect(page.text()).toContain('Too many attempts. Try again later.')
    })
    expect(page.text()).not.toContain(confirmed)
    expect(calls).toHaveLength(1)
    expect(calls[0]!.json).toEqual({ token })
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('leaves the page pending when the request fails', async () => {
    const fetchMock = vi.fn(async () => {
      throw new Error('offline')
    })
    vi.stubGlobal('fetch', fetchMock)
    const page = await mountSuspended(ConfirmPage, { route: `/confirm?token=${token}` })
    await vi.waitFor(() => {
      expect(fetchMock).toHaveBeenCalled()
    })
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(page.text()).not.toContain(confirmed)
    expect(page.text()).not.toContain(invalid)
    expect(page.find('#sign-up').exists()).toBe(false)
    expect(page.find('#sign-in').exists()).toBe(false)
    expect(page.text()).not.toContain(token)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })
})
