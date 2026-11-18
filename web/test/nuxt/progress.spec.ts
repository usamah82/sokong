import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EnrolmentDetail from '../../pages/enrolments/[id].vue'
import EnrolmentsPage from '../../pages/enrolments/index.vue'
import { formatVisit } from '../../utils/visitTime'

const quiet = 'This case is in. No one has looked. No visit is set.'
const missing = 'This case is not available.'

const { navigated } = vi.hoisted(() => ({ navigated: [] as string[] }))

mockNuxtImport('navigateTo', () => {
  return (to: string) => {
    navigated.push(to)
  }
})

type CapturedRequest = {
  url: string
  method: string
  authorization: string | null
}

function stubFetch(status: number, body: unknown) {
  const calls: CapturedRequest[] = []
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers)
    calls.push({
      url: String(input),
      method: init?.method ?? 'GET',
      authorization: headers.get('Authorization')
    })
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => body
    }
  }))
  return calls
}

const newer = {
  id: 'case-new',
  place_name: 'Block 4',
  members: [ { role: 'head', name: 'Rahim' } ],
  progress: { case_in: true, looks: [], visit_at: null }
}

const older = {
  id: 'case-old',
  place_name: 'Block 2',
  members: [ { role: 'head', name: 'Mina' } ],
  progress: { case_in: true, looks: [], visit_at: null }
}

describe('submitter progress', () => {
  beforeEach(() => {
    sessionStorage.clear()
    navigated.length = 0
  })

  it('lists the cases and asks for the bearer token', async () => {
    const calls = stubFetch(200, [ newer, older ])
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(page.text()).toContain('Block 4')
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/enrolments')
    expect(request.method).toBe('GET')
    expect(request.authorization).toBe('Bearer secret-token')
    expect(page.text().indexOf('Block 4')).toBeLessThan(page.text().indexOf('Block 2'))
    expect(page.get('#case-case-new').attributes('href')).toBe('/enrolments/case-new')
    expect(page.text()).not.toContain('secret-token')
    vi.unstubAllGlobals()
  })

  it('does not tell a submitter that there are no enrolments yet', async () => {
    stubFetch(200, [])
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'submitter')
    const page = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(page.find('#cases').exists()).toBe(true)
    })
    expect(page.text()).not.toContain('No enrolments yet.')
    expect(page.text()).not.toContain('No locality is linked to this account.')
    vi.unstubAllGlobals()
  })

  it('opens sign-in when the token is missing or rejected', async () => {
    const calls = stubFetch(200, [])
    await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/sign-in' ])
    })
    expect(calls).toHaveLength(0)

    sessionStorage.setItem('sokong.token', 'secret-token')
    navigated.length = 0
    stubFetch(401, { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } })
    const rejected = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/sign-in' ])
    })
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(rejected.text()).not.toContain('secret-token')
    vi.unstubAllGlobals()
  })

  it('shows that nobody has looked and that no visit is set', async () => {
    const calls = stubFetch(200, newer)
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => {
      expect(page.text()).toContain(quiet)
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.pathname).toBe('/enrolments/case-new')
    expect(request.method).toBe('GET')
    expect(request.authorization).toBe('Bearer secret-token')
    expect(page.text()).not.toContain('secret-token')
    vi.unstubAllGlobals()
  })

  it('shows notes under the worker name in time order', async () => {
    stubFetch(200, {
      ...newer,
      progress: {
        case_in: true,
        visit_at: null,
        looks: [
          { id: 'later', worker_name: 'Aminah', looked_at: '2026-11-12T10:00:00Z', note: 'Called the enroler, no answer' },
          { id: 'earlier', worker_name: 'Siti', looked_at: '2026-11-12T09:00:00Z', note: '' }
        ]
      }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => {
      expect(page.text()).toContain('Called the enroler, no answer')
    })

    const text = page.text()
    expect(text.indexOf('Siti')).toBeLessThan(text.indexOf('Aminah'))
    expect(text.indexOf('Aminah')).toBeLessThan(text.indexOf('Called the enroler, no answer'))
    expect(text.indexOf('2026-11-12T09:00:00Z')).toBeLessThan(text.indexOf('2026-11-12T10:00:00Z'))
    expect(text).toContain('No visit is set.')
    expect(text).not.toContain('A visit is set for')
    expect(text).not.toContain('No one has looked')
    expect(page.get('#look-earlier').text()).not.toContain('Called the enroler, no answer')
    vi.unstubAllGlobals()
  })

  it('says the case is not available for someone else', async () => {
    const calls = stubFetch(404, { error: { code: 'NOT_FOUND', message: 'Not found' } })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-other' })
    await vi.waitFor(() => {
      expect(page.text()).toContain(missing)
    })
    expect(page.text()).not.toContain(quiet)
    expect(page.text()).not.toContain('Not found')
    expect(calls[0]!.authorization).toBe('Bearer secret-token')
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    expect(navigated).toEqual([])
    vi.unstubAllGlobals()
  })

  it('opens sign-in from a case when the token is missing or rejected', async () => {
    const calls = stubFetch(401, { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } })
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/sign-in' ])
    })
    expect(calls).toHaveLength(0)
    expect(page.text()).not.toContain(missing)

    sessionStorage.setItem('sokong.token', 'secret-token')
    navigated.length = 0
    stubFetch(401, { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } })
    await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/sign-in' ])
    })
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('shows the visit line and hides the interview', async () => {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    stubFetch(200, {
      ...newer,
      bringing_basket: true,
      assigned_workers: [ 'Aman' ],
      verification: { house: { basket: 'Rice secret' } },
      marked_at: '2026-11-24T02:00:00Z',
      marker_name: 'Marker Aman',
      progress: {
        case_in: true,
        looks: [],
        visit_at: '2026-11-24T01:00:00Z',
        outcome: 'qualified'
      }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => expect(page.find('#visit-line').exists()).toBe(true))
    expect(page.text()).toContain('This case is in.')
    expect(page.text()).not.toContain(quiet)
    expect(page.get('#visit-line').text()).toBe(`A visit is set for ${formatVisit('2026-11-24T01:00:00Z', zone)}.`)
    expect(page.get('#outcome').text()).toBe('This family is qualified.')
    expect(page.text()).not.toContain('No visit is set.')
    expect(page.text()).not.toContain('Verification Interview')
    expect(page.text()).not.toContain('Bringing a basket')
    expect(page.text()).not.toContain('Assigned workers')
    expect(page.text()).not.toContain('Rice secret')
    expect(page.text()).not.toContain('Marker Aman')
    expect(page.text()).not.toContain('2026-11-24T02:00:00Z')
    vi.unstubAllGlobals()
  })

  it('shows a disqualified family and keeps no visit when only a look exists', async () => {
    stubFetch(200, {
      ...newer,
      progress: {
        case_in: true,
        looks: [ { id: 'look-1', worker_name: 'Aminah', looked_at: '2026-11-12T09:00:00Z', note: '' } ],
        visit_at: null,
        outcome: 'disqualified'
      }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-new' })
    await vi.waitFor(() => expect(page.find('#outcome').exists()).toBe(true))
    expect(page.text()).toContain('This case is in.')
    expect(page.text()).toContain('No visit is set.')
    expect(page.get('#outcome').text()).toBe('This family is disqualified.')
    expect(page.find('#visit-line').exists()).toBe(false)
    vi.unstubAllGlobals()
  })
})
