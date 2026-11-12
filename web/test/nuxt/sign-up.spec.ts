import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it, vi } from 'vitest'
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
  it('asks the enroler to check the typed email and stores no token', async () => {
    const calls = stubAccount(201, { account: { id: 'account-1', email: 'siti@example.com', role: 'submitter' } })
    sessionStorage.setItem('other', 'kept')
    const page = await mountSuspended(SignUpPage)

    expect(page.text()).toContain('Sign up')
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
})
