import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EnrolmentsPage from '../../pages/enrolments/index.vue'
import SignInPage from '../../pages/sign-in.vue'

const { navigated } = vi.hoisted(() => ({ navigated: [] as string[] }))

mockNuxtImport('navigateTo', () => {
  return (to: string) => {
    navigated.push(to)
  }
})

const wrong = 'Email or password is wrong'
const unconfirmed = 'Confirm your email to sign in'
const limited = 'Too many attempts. Try again later.'

type CapturedRequest = {
  url: string
  method: string
  authorization: string | null
  json: Record<string, unknown> | null
}

function stubSession(status: number, body: unknown) {
  const calls: CapturedRequest[] = []
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push(capture(input, init))
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => body
    }
  }))
  return calls
}

function capture(input: RequestInfo | URL, init?: RequestInit): CapturedRequest {
  const headers = new Headers(init?.headers)
  return {
    url: String(input),
    method: init?.method ?? 'GET',
    authorization: headers.get('Authorization'),
    json: init?.body ? JSON.parse(String(init.body)) as Record<string, unknown> : null
  }
}

async function fill(page: Awaited<ReturnType<typeof mountSuspended>>) {
  await page.get('#email').setValue('siti@example.com')
  await page.get('#password').setValue('correct horse battery staple')
}

describe('sign in', () => {
  beforeEach(() => {
    sessionStorage.clear()
    navigated.length = 0
  })

  it('stores the token for a confirmed pair and opens enrolments', async () => {
    const calls = stubSession(200, {
      token: 'secret-token',
      account: { id: 'account-1', email: 'Siti@Example.com', role: 'submitter', name: 'Aman' }
    })
    sessionStorage.setItem('other', 'kept')
    const page = await mountSuspended(SignInPage)

    expect(page.text()).toContain('Sign in')
    expect(page.text()).toContain('Email')
    expect(page.text()).toContain('Password')
    expect(page.get('#password').attributes('type')).toBe('password')
    expect(page.get('#password').attributes('autocomplete')).toBe('current-password')
    expect(page.get('#sign-in').text()).toBe('Sign in')
    expect(page.find('#sign-out').exists()).toBe(false)

    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/enrolments' ])
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/sessions')
    expect(request.method).toBe('POST')
    expect(request.authorization).toBeNull()
    expect(request.json).toEqual({
      email: 'siti@example.com',
      password: 'correct horse battery staple'
    })
    expect(request.json).not.toHaveProperty('role')
    expect(page.text()).not.toContain('secret-token')
    expect(page.text()).not.toContain('correct horse battery staple')
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    expect(sessionStorage.getItem('sokong.role')).toBe('submitter')
    expect(sessionStorage.getItem('sokong.name')).toBe('Aman')
    expect(sessionStorage.getItem('other')).toBe('kept')
    vi.unstubAllGlobals()
  })

  it.each([
    { id: 'account-1', email: 'siti@example.com' },
    { id: 'account-1', email: 'siti@example.com', role: '' },
    { id: 'account-1', email: 'siti@example.com', role: 1 }
  ])('stores the token and leaves a missing role unset', async (account) => {
    stubSession(200, { token: 'secret-token', account })
    const page = await mountSuspended(SignInPage)
    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/enrolments' ])
    })
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    expect(sessionStorage.getItem('sokong.role')).toBeNull()
    vi.unstubAllGlobals()
    navigated.length = 0
  })

  it('shows a wrong pair and an unconfirmed account without storing a token', async () => {
    stubSession(401, {
      token: 'secret-token',
      error: { code: 'UNAUTHENTICATED', message: wrong }
    })
    const page = await mountSuspended(SignInPage)
    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain(wrong)
    })
    expect(page.get('.notice').text()).toContain(wrong)
    expect(page.text()).not.toContain('secret-token')
    expect(page.text()).toContain('Sign in')
    expect(navigated).toEqual([])
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')

    stubSession(401, {
      error: { code: 'UNAUTHENTICATED', message: unconfirmed }
    })
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain(unconfirmed)
    })
    expect(page.text()).not.toContain(wrong)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(navigated).toEqual([])

    stubSession(429, {
      error: { code: 'RATE_LIMITED', message: limited }
    })
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('.notice').text()).toContain(limited)
    })
    expect(page.text()).not.toContain(unconfirmed)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('signs out, then sends the next call with no bearer token', async () => {
    const calls: CapturedRequest[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push(capture(input, init))
      const method = init?.method ?? 'GET'
      if (method === 'DELETE') return { ok: true, status: 204, json: async () => ({ token: 'secret-token' }) }
      return {
        ok: false,
        status: 401,
        json: async () => ({ error: { code: 'UNAUTHENTICATED', message: wrong } })
      }
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'submitter')
    sessionStorage.setItem('sokong.name', 'Aman')
    sessionStorage.setItem('other', 'kept')
    const page = await mountSuspended(SignInPage)
    await vi.waitFor(() => {
      expect(page.get('#sign-out').text()).toBe('Sign out')
    })

    await page.get('#sign-out').trigger('click')
    await vi.waitFor(() => {
      expect(sessionStorage.getItem('sokong.token')).toBeNull()
    })

    const revoked = calls[0]!
    const url = new URL(revoked.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/sessions')
    expect(revoked.method).toBe('DELETE')
    expect(revoked.authorization).toBe('Bearer secret-token')
    expect(revoked.json).toBeNull()
    expect(page.text()).not.toContain('secret-token')
    expect(page.find('#sign-out').exists()).toBe(false)
    expect(sessionStorage.getItem('other')).toBe('kept')

    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain(wrong)
    })
    expect(calls[1]!.method).toBe('POST')
    expect(calls[1]!.authorization).toBeNull()
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('sokong.role')).toBeNull()
    expect(sessionStorage.getItem('sokong.name')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('sends one post while sign-in is in flight', async () => {
    const calls: number[] = []
    let release = () => {}
    const gate = new Promise<void>((resolve) => {
      release = resolve
    })
    vi.stubGlobal('fetch', vi.fn(async () => {
      calls.push(1)
      await gate
      return {
        ok: true,
        status: 200,
        json: async () => ({ token: 'secret-token', account: { id: 'account-1' } })
      }
    }))
    const page = await mountSuspended(SignInPage)
    await fill(page)
    const pending = page.get('form').trigger('submit')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    expect(page.get('#sign-in').attributes('disabled')).toBeDefined()
    await page.get('form').trigger('submit')
    expect(calls).toHaveLength(1)
    release()
    await pending
    await vi.waitFor(() => expect(navigated).toEqual([ '/enrolments' ]))
    expect(page.text()).not.toContain('secret-token')
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    vi.unstubAllGlobals()
  })

  it('stays on the form when the session is not created', async () => {
    stubSession(500, { error: { message: 'Something else' }, token: 'secret-token' })
    const page = await mountSuspended(SignInPage)
    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('#sign-in').attributes('disabled')).toBeUndefined()
    })
    expect(page.text()).toContain('Sign in')
    expect(page.text()).not.toContain('secret-token')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')
    expect(page.get<HTMLInputElement>('#password').element.value).toBe('correct horse battery staple')
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(navigated).toEqual([])

    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new Error('offline')
    }))
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('#sign-in').attributes('disabled')).toBeUndefined()
    })
    expect(page.get<HTMLInputElement>('#password').element.value).toBe('correct horse battery staple')
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('opens enrolments and signs out from there', async () => {
    const calls: CapturedRequest[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push(capture(input, init))
      const method = init?.method ?? 'GET'
      if (method === 'DELETE') return { ok: true, status: 204, json: async () => ({}) }
      return { ok: true, status: 200, json: async () => [] }
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentsPage)
    expect(page.get('#sign-out').text()).toBe('Sign out')
    expect(page.text()).not.toContain('secret-token')

    await page.get('#sign-out').trigger('click')
    await vi.waitFor(() => {
      expect(sessionStorage.getItem('sokong.token')).toBeNull()
    })
    const revoked = calls.find((call) => call.method === 'DELETE')
    expect(revoked?.method).toBe('DELETE')
    expect(revoked?.authorization).toBe('Bearer secret-token')
    expect(navigated).toEqual([ '/sign-in' ])
    vi.unstubAllGlobals()
  })

  it('keeps the token when sign-out does not revoke it', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new Error('offline')
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(SignInPage)
    await vi.waitFor(() => expect(page.find('#sign-out').exists()).toBe(true))
    await page.get('#sign-out').trigger('click')
    await vi.waitFor(() => {
      expect(page.get('#sign-out').attributes('disabled')).toBeUndefined()
    })
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    expect(page.text()).not.toContain('secret-token')
    vi.unstubAllGlobals()
  })
})
