import { mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import SignUpPage from '../../pages/sign-up.vue'

const checkEmail = 'Check your email to confirm this address. Then sign in.'

type CapturedRequest = {
  url: string
  method: string
  authorization: string | null
  json: Record<string, unknown>
}

function stubAccount(status: number, body: unknown) {
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

async function fill(page: Awaited<ReturnType<typeof mountSuspended>>, confirmation = 'correct horse battery staple') {
  await page.get('#email').setValue('siti@example.com')
  await page.get('#password').setValue('correct horse battery staple')
  await page.get('#password-confirmation').setValue(confirmation)
}

describe('sign up', () => {
  beforeEach(() => {
    sessionStorage.clear()
  })

  it('asks the enroler to check the typed email and stores no token', async () => {
    const calls = stubAccount(201, {
      account: { id: 'account-1', email: 'siti@example.com', role: 'submitter' },
      token: 'secret-token'
    })
    sessionStorage.setItem('other', 'kept')
    const page = await mountSuspended(SignUpPage)

    expect(page.text()).toContain('Sign up')
    expect(page.get('#password').attributes('type')).toBe('password')
    expect(page.get('#password-confirmation').attributes('type')).toBe('password')
    expect(page.text()).toContain('Email')
    expect(page.text()).toContain('Password')
    expect(page.text()).toContain('Password confirmation')
    expect(page.get('#create-account').text()).toBe('Create account')

    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain(checkEmail)
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/accounts')
    expect(request.method).toBe('POST')
    expect(request.authorization).toBeNull()
    expect(request.json).toEqual({
      email: 'siti@example.com',
      password: 'correct horse battery staple',
      password_confirmation: 'correct horse battery staple'
    })
    expect(request.json).not.toHaveProperty('role')
    expect(page.text()).toContain('siti@example.com')
    expect(page.text()).not.toContain('secret-token')
    expect(page.text()).not.toContain('correct horse battery staple')
    expect(page.find('#create-account').exists()).toBe(false)
    expect(page.find('#password').exists()).toBe(false)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('other')).toBe('kept')
    vi.unstubAllGlobals()
  })

  it('shows the API message for a mismatch and for too many attempts', async () => {
    const mismatch = stubAccount(422, {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Password confirmation does not match',
        details: { password_confirmation: [ 'does not match' ] }
      }
    })
    const page = await mountSuspended(SignUpPage)
    await fill(page, 'correct horse battery staples')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain('Password confirmation does not match')
    })
    expect(page.text()).toContain('Sign up')
    expect(page.get('#password-confirmation').attributes('aria-invalid')).toBe('true')
    expect(page.get('#email').attributes('aria-invalid')).toBeUndefined()
    expect(page.get('#password').attributes('aria-invalid')).toBeUndefined()
    expect(page.get('#password-confirmation').element.parentElement?.textContent).toContain('Password confirmation does not match')
    expect(page.find('.notice').exists()).toBe(false)
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')
    expect(page.get<HTMLInputElement>('#password-confirmation').element.value).toBe('correct horse battery staples')
    expect(page.text()).not.toContain(checkEmail)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(mismatch[0]!.json.password_confirmation).toBe('correct horse battery staples')

    const limited = stubAccount(429, {
      error: { code: 'RATE_LIMITED', message: 'Too many attempts. Try again later.' }
    })
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain('Too many attempts. Try again later.')
    })
    expect(page.get('.notice').text()).toContain('Too many attempts. Try again later.')
    expect(page.get('#password-confirmation').attributes('aria-invalid')).toBeUndefined()
    expect(page.text()).not.toContain('Password confirmation does not match')
    expect(page.text()).toContain('Sign up')
    expect(limited).toHaveLength(1)
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('puts the API message on the first named field and ignores a stored token', async () => {
    sessionStorage.setItem('sokong.token', 'already-here')
    const calls = stubAccount(422, {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Email has already been taken',
        details: { email: [ 'has already been taken' ], password: [ 'is too short' ] }
      }
    })
    const page = await mountSuspended(SignUpPage)
    await fill(page, 'short')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain('Email has already been taken')
    })
    expect(page.get('#email').attributes('aria-invalid')).toBe('true')
    expect(page.get('#password').attributes('aria-invalid')).toBeUndefined()
    expect(page.get('#password-confirmation').attributes('aria-invalid')).toBeUndefined()
    expect(page.get('#email').element.parentElement?.textContent).toContain('Email has already been taken')
    expect(page.find('.notice').exists()).toBe(false)
    expect(sessionStorage.getItem('sokong.token')).toBe('already-here')
    expect(calls[0]!.json.password).toBe('correct horse battery staple')

    stubAccount(422, {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Password is too short',
        details: { password: [ 'is too short' ] }
      }
    })
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('#password').attributes('aria-invalid')).toBe('true')
    })
    expect(page.get('#password').element.parentElement?.textContent).toContain('Password is too short')
    expect(page.get('#email').attributes('aria-invalid')).toBeUndefined()
    expect(page.find('.notice').exists()).toBe(false)
    expect(page.text()).not.toContain(checkEmail)
    expect(sessionStorage.getItem('sokong.token')).toBe('already-here')
    vi.unstubAllGlobals()
  })

  it('sends one post while sign-up is in flight', async () => {
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
        status: 201,
        json: async () => ({ account: { id: 'account-1' }, token: 'secret-token' })
      }
    }))
    const page = await mountSuspended(SignUpPage)
    await fill(page)
    const pending = page.get('form').trigger('submit')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    expect(page.get('#create-account').attributes('disabled')).toBeDefined()
    await page.get('form').trigger('submit')
    expect(calls).toHaveLength(1)
    release()
    await pending
    await vi.waitFor(() => expect(page.text()).toContain(checkEmail))
    expect(page.text()).not.toContain('secret-token')
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('stays on the form when the account is not created', async () => {
    stubAccount(500, { error: { message: 'Something else' } })
    const page = await mountSuspended(SignUpPage)
    await fill(page)
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('#create-account').attributes('disabled')).toBeUndefined()
    })
    expect(page.text()).toContain('Sign up')
    expect(page.text()).not.toContain(checkEmail)
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')
    expect(page.get<HTMLInputElement>('#password').element.value).toBe('correct horse battery staple')
    expect(page.get<HTMLInputElement>('#password-confirmation').element.value).toBe('correct horse battery staple')
    expect(sessionStorage.getItem('sokong.token')).toBeNull()

    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new Error('offline')
    }))
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get('#create-account').attributes('disabled')).toBeUndefined()
    })
    expect(page.text()).not.toContain(checkEmail)
    expect(page.get<HTMLInputElement>('#password').element.value).toBe('correct horse battery staple')
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })
})
