import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EnrolmentDetail from '../../pages/enrolments/[id].vue'
import EnrolmentsPage from '../../pages/enrolments/index.vue'
import { formatVisit, visitIsLate } from '../../utils/visitTime'

const unlinked = 'No locality is linked to this account.'
const empty = 'No enrolments yet.'
const noHelp = 'No help was named.'

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
  json: Record<string, unknown> | null
}

function stubFetch(handler: (method: string) => { status: number, body: unknown }) {
  const calls: CapturedRequest[] = []
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers)
    const method = init?.method ?? 'GET'
    calls.push({
      url: String(input),
      method,
      authorization: headers.get('Authorization'),
      json: init?.body ? JSON.parse(String(init.body)) as Record<string, unknown> : null
    })
    const response = handler(method)
    return {
      ok: response.status >= 200 && response.status < 300,
      status: response.status,
      json: async () => response.body
    }
  }))
  return calls
}

const summary = {
  id: 'case-1',
  submitted_at: '2026-11-12T09:00:00Z',
  place_name: 'Block 4',
  head_name: 'Rahim',
  enroler_contact: '+60123456789',
  on_behalf: false,
  locality: { id: 'locality-1', name: 'Block 4' }
}

function detail(looks: Array<{ id: string, worker_name: string, looked_at: string, note: string }>, help: string[] = [], other = '') {
  return {
    ...summary,
    email: 'siti@example.com',
    how_to_find: 'Blue gate',
    family_phone: '+60129876543',
    help,
    other_help: other,
    consent_text: 'Submission means the family consents.',
    latitude: null,
    longitude: null,
    members: [
      {
        id: 'member-1',
        role: 'head',
        name: 'Rahim',
        age: 40,
        gender: 'male',
        description: 'Tall',
        in_education: false,
        working: true,
        job: 'Driver',
        monthly_amount: 800
      }
    ],
    looks,
    visit_at: null as string | null,
    bringing_basket: null as boolean | null,
    assigned_workers: null as string[] | null,
    verification: null as Record<string, unknown> | null,
    outcome: null as string | null
  }
}

const emptyLook = { id: 'look-empty', worker_name: 'Aminah', looked_at: '2026-11-12T09:00:00Z', note: '' }

function visited() {
  const stored = detail([ emptyLook ])
  stored.visit_at = '2026-11-24T01:00:00Z'
  stored.bringing_basket = false
  stored.assigned_workers = [ 'Aman' ]
  return stored
}

const phoneError = 'Enter a phone number, for example +60 12-345 6789.'

describe('worker cases', () => {
  beforeEach(() => {
    sessionStorage.clear()
    navigated.length = 0
  })

  it('says no locality is linked and keeps the token', async () => {
    const calls = stubFetch(() => ({
      status: 403,
      body: { error: { code: 'FORBIDDEN', message: unlinked } }
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(page.text()).toContain(unlinked)
    })
    expect(calls).toHaveLength(1)
    expect(calls[0]!.method).toBe('GET')
    expect(new URL(calls[0]!.url).pathname).toBe('/enrolments')
    expect(calls[0]!.authorization).toBe('Bearer secret-token')
    expect(page.text()).not.toContain(empty)
    expect(sessionStorage.getItem('sokong.token')).toBe('secret-token')
    expect(navigated).toEqual([])
    vi.unstubAllGlobals()
  })

  it('says there are no enrolments when the linked list is empty', async () => {
    const calls = stubFetch(() => ({ status: 200, body: [] }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(page.text()).toContain(empty)
    })
    expect(calls).toHaveLength(1)
    expect(calls[0]!.method).toBe('GET')
    expect(page.text()).not.toContain(unlinked)
    vi.unstubAllGlobals()
  })

  it('shows the family fields and that no help was named', async () => {
    const calls = stubFetch(() => ({ status: 200, body: detail([ emptyLook ]) }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain(noHelp)
    })
    expect(page.text()).toContain('Block 4')
    expect(page.text()).toContain('Blue gate')
    expect(page.text()).toContain('+60129876543')
    expect(page.text()).toContain('+60123456789')
    expect(page.text()).toContain('Rahim')
    const member = page.get('#member-member-1').text()
    expect(member).toContain('Male')
    expect(member).toContain('Tall')
    expect(member).toContain('40')
    expect(member).toContain('In education No')
    expect(member).toContain('Working Yes')
    expect(member).toContain('Driver')
    expect(member).toContain('800')
    expect(calls.filter((call) => call.method === 'POST')).toHaveLength(0)
    expect(new URL(calls[0]!.url).pathname).toBe('/enrolments/case-1')
    vi.unstubAllGlobals()
  })

  it('names the help that was asked', async () => {
    stubFetch(() => ({
      status: 200,
      body: detail([ emptyLook ], [ 'food', 'help_applying' ], 'A school uniform')
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain('A school uniform')
    })
    expect(page.text()).toContain('Food')
    expect(page.text()).toContain('Help applying to a body (for example social security, welfare, or a tithe body)')
    expect(page.text()).not.toContain(noHelp)
    vi.unstubAllGlobals()
  })

  it('names clothing and school supplies without other help', async () => {
    stubFetch(() => ({
      status: 200,
      body: detail([ emptyLook ], [ 'clothing', 'school_supplies' ])
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain('School supplies')
    })
    expect(page.text()).toContain('Clothing')
    expect(page.text()).not.toContain('clothing')
    expect(page.text()).not.toContain('school_supplies')
    expect(page.text()).not.toContain(noHelp)
    vi.unstubAllGlobals()
  })

  it('names other help when no key was chosen', async () => {
    stubFetch(() => ({
      status: 200,
      body: detail([ emptyLook ], [], 'A school uniform')
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain('A school uniform')
    })
    expect(page.text()).not.toContain(noHelp)
    vi.unstubAllGlobals()
  })

  it('treats blank other help as no help named', async () => {
    stubFetch(() => ({ status: 200, body: detail([ emptyLook ], [], '   ') }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain(noHelp)
    })
    vi.unstubAllGlobals()
  })

  it('shows a member who is in education and not working', async () => {
    const body = detail([ emptyLook ])
    body.members.push({
      id: 'member-2',
      role: 'other',
      name: 'Siti',
      age: null,
      gender: 'female',
      description: '',
      in_education: true,
      working: false,
      job: '',
      monthly_amount: null
    })
    stubFetch(() => ({ status: 200, body }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.get('#member-member-2').text()).toContain('Siti')
    })
    const person = page.get('#member-member-2').text()
    expect(person).toContain('Female')
    expect(person).toContain('In education Yes')
    expect(person).toContain('Working No')
    expect(person).not.toContain('Job')
    expect(person).not.toContain('Rough monthly amount')
    expect(page.get('#member-member-1').text()).toContain('Rahim')
    vi.unstubAllGlobals()
  })

  it('shows looks in time order, with no note on the empty look', async () => {
    const noted = { id: 'look-note', worker_name: 'Aminah', looked_at: '2026-11-12T10:00:00Z', note: 'Called the enroler, no answer' }
    stubFetch(() => ({ status: 200, body: detail([ noted, emptyLook ]) }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => {
      expect(page.text()).toContain('Called the enroler, no answer')
    })
    const rows = page.findAll('.look')
    expect(rows).toHaveLength(2)
    expect(rows[0]!.text()).toContain('Aminah')
    expect(rows[0]!.text()).toContain('2026-11-12T09:00:00Z')
    expect(rows[0]!.text()).not.toContain('Called the enroler, no answer')
    expect(rows[1]!.text()).toContain('Called the enroler, no answer')
    vi.unstubAllGlobals()
  })

  it('shows the place and the head name on the list', async () => {
    const calls = stubFetch(() => ({ status: 200, body: [ summary ] }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => {
      expect(page.get('#case-case-1').text()).toContain('Rahim')
    })
    expect(page.get('#case-case-1').text()).toContain('Block 4')
    expect(page.get('#case-case-1').attributes('href')).toBe('/enrolments/case-1')
    expect(calls).toHaveLength(1)
    expect(calls[0]!.method).toBe('GET')
    expect(new URL(calls[0]!.url).pathname).toBe('/enrolments')
    expect(page.text()).not.toContain(empty)
    vi.unstubAllGlobals()
  })

  it('adds a note beside the one empty look and does not add another on a second visit', async () => {
    const recorded = [
      emptyLook,
      { id: 'look-note', worker_name: 'Aminah', looked_at: '2026-11-12T10:00:00Z', note: 'Called the enroler, no answer' }
    ]
    let posted = false
    const calls = stubFetch((method) => {
      if (method === 'POST') {
        posted = true
        return { status: 201, body: recorded[1] }
      }
      return { status: 200, body: detail(posted ? recorded : [ emptyLook ]) }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#look-look-empty').exists()).toBe(true))
    expect(page.findAll('.look')).toHaveLength(1)

    await page.get('#note').setValue('Called the enroler, no answer')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(page.text()).toContain('Called the enroler, no answer'))
    expect(page.findAll('.look')).toHaveLength(2)
    expect(page.findAll('#look-look-empty')).toHaveLength(1)
    const post = calls.find((call) => call.method === 'POST')
    expect(new URL(post!.url).pathname).toBe('/enrolments/case-1/looks')
    expect(post!.authorization).toBe('Bearer secret-token')
    expect(post!.json).toEqual({ note: 'Called the enroler, no answer' })

    page.unmount()
    const again = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(again.text()).toContain('Called the enroler, no answer'))
    expect(again.findAll('#look-look-empty')).toHaveLength(1)
    expect(again.findAll('.look')).toHaveLength(2)
    expect(calls.filter((call) => call.method === 'POST')).toHaveLength(1)
    vi.unstubAllGlobals()
  })

  it('signs out when a note is rejected', async () => {
    stubFetch((method) => {
      if (method === 'POST') return { status: 401, body: { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } } }
      return { status: 200, body: detail([ emptyLook ]) }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#look-look-empty').exists()).toBe(true))
    await page.get('#note').setValue('Called the enroler, no answer')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(navigated).toEqual([ '/sign-in' ]))
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('sokong.role')).toBeNull()
    expect(page.findAll('.look')).toHaveLength(1)
    vi.unstubAllGlobals()
  })

  it('shows a rejected note and keeps the typed text', async () => {
    stubFetch((method) => {
      if (method === 'POST') return { status: 422, body: { error: { code: 'VALIDATION_ERROR', message: 'Note is required' } } }
      return { status: 200, body: detail([ emptyLook ]) }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#note').exists()).toBe(true))
    await page.get('#note').setValue('Called the enroler, no answer')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(page.text()).toContain('Note is required'))
    expect(page.get<HTMLTextAreaElement>('#note').element.value).toBe('Called the enroler, no answer')
    expect(page.findAll('.look')).toHaveLength(1)
    vi.unstubAllGlobals()
  })

  it('keeps the typed note when the save fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      if ((init?.method ?? 'GET') === 'POST') throw new Error('offline')
      return { ok: true, status: 200, json: async () => detail([ emptyLook ]) }
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#note').exists()).toBe(true))
    await page.get('#note').setValue('Called the enroler, no answer')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(page.get('#add-note').attributes('disabled')).toBeUndefined())
    expect(page.get<HTMLTextAreaElement>('#note').element.value).toBe('Called the enroler, no answer')
    expect(page.findAll('.look')).toHaveLength(1)
    expect(navigated).toEqual([])

    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const method = init?.method ?? 'GET'
      if (method === 'POST') return { ok: false, status: 404, json: async () => ({ error: { code: 'NOT_FOUND', message: 'Not found' } }) }
      return { ok: true, status: 200, json: async () => detail([ emptyLook ]) }
    }))
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(page.get('#add-note').attributes('disabled')).toBeUndefined())
    expect(page.get<HTMLTextAreaElement>('#note').element.value).toBe('Called the enroler, no answer')
    expect(page.findAll('.look')).toHaveLength(1)
    vi.unstubAllGlobals()
  })

  it('sends one note while the save is in flight, then clears the field', async () => {
    const posts: number[] = []
    let release = () => {}
    const gate = new Promise<void>((resolve) => {
      release = resolve
    })
    vi.stubGlobal('fetch', vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      if ((init?.method ?? 'GET') === 'POST') {
        posts.push(1)
        await gate
        return {
          ok: true,
          status: 201,
          json: async () => ({ id: 'look-note', worker_name: 'Aminah', looked_at: '2026-11-12T10:00:00Z', note: 'Called the enroler, no answer' })
        }
      }
      return { ok: true, status: 200, json: async () => detail([ emptyLook ]) }
    }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#note').exists()).toBe(true))
    await page.get('#note').setValue('Called the enroler, no answer')
    const pending = page.get('form').trigger('submit')
    await vi.waitFor(() => expect(posts).toHaveLength(1))
    expect(page.get('#add-note').attributes('disabled')).toBeDefined()
    await page.get('form').trigger('submit')
    expect(posts).toHaveLength(1)
    release()
    await pending
    await vi.waitFor(() => expect(page.get<HTMLTextAreaElement>('#note').element.value).toBe(''))
    expect(page.findAll('.look')).toHaveLength(2)
    vi.unstubAllGlobals()
  })

  it('clears the role when the list is rejected', async () => {
    stubFetch(() => ({ status: 401, body: { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } } }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    sessionStorage.setItem('sokong.name', 'Aman')
    await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => expect(navigated).toEqual([ '/sign-in' ]))
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('sokong.role')).toBeNull()
    expect(sessionStorage.getItem('sokong.name')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('formats a visit in the browser zone and flags a time past a week', () => {
    expect(formatVisit('2026-11-24T01:00:00Z', 'Asia/Kuala_Lumpur')).toBe('24 November 2026 at 09:00')
    expect(visitIsLate('2026-11-17T01:00:00Z', '2026-11-24T01:00:00Z')).toBe(false)
    expect(visitIsLate('2026-11-17T01:00:00Z', '2026-11-24T01:00:01Z')).toBe(true)
  })

  it('shows pre-visit and does not send an empty time or a blank name', async () => {
    const calls = stubFetch(() => ({ status: 200, body: detail([ emptyLook ]) }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.name', 'Aman')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.text()).toContain('Pre-visit'))
    expect(page.text()).toContain('Aim for a visit within a week of the enrolment.')
    expect(page.text()).toContain('Set the visit before recording it.')
    expect(page.text()).toContain('Visit time')
    expect(page.text()).toContain('Bringing a basket')
    expect(page.text()).toContain('Assigned workers')
    expect(page.get<HTMLInputElement>('#assigned-worker-0').element.value).toBe('Aman')
    expect(page.text()).not.toContain('Verification Interview')
    expect(page.text()).not.toContain('Post-visit')
    expect(page.text()).not.toContain('Mark qualified')
    expect(page.text()).toContain('Rahim')
    expect(page.text()).toContain(noHelp)
    expect(page.find('#note').exists()).toBe(true)

    await page.get('form.pre-visit').trigger('submit')
    expect(page.text()).toContain('Visit time is invalid')
    expect(calls.filter((call) => call.method === 'PATCH')).toHaveLength(0)

    await page.get('#visit-time').setValue('2026-11-24T09:00')
    await page.get('#add-worker').trigger('click')
    await page.get('form.pre-visit').trigger('submit')
    expect(calls.filter((call) => call.method === 'PATCH')).toHaveLength(0)
    expect(page.get<HTMLInputElement>('#assigned-worker-0').element.value).toBe('Aman')
    expect(page.get('#assigned-worker-1').attributes('aria-invalid')).toBe('true')
    vi.unstubAllGlobals()
  })

  it('saves a visit and shows the local time', async () => {
    const calls = stubFetch((method) => {
      if (method === 'PATCH') {
        return {
          status: 200,
          body: {
            visit_at: '2026-11-24T01:00:00Z',
            bringing_basket: true,
            assigned_workers: [ 'Aman', 'Farid' ]
          }
        }
      }
      return { status: 200, body: detail([ emptyLook ]) }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.name', 'Aman')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#visit-time').exists()).toBe(true))
    await page.get('#visit-time').setValue('2026-11-24T09:00')
    await page.get('#bringing-basket').setValue(true)
    await page.get('#add-worker').trigger('click')
    await page.get('#assigned-worker-1').setValue('Farid')
    await page.get('form.pre-visit').trigger('submit')
    await vi.waitFor(() => expect(page.text()).toContain('Change visit'))
    expect(page.text()).not.toContain('Set the visit before recording it.')
    const patch = calls.find((call) => call.method === 'PATCH')
    expect(new URL(patch!.url).pathname).toBe('/enrolments/case-1/visit')
    expect(patch!.json).toMatchObject({
      bringing_basket: true,
      assigned_workers: [ 'Aman', 'Farid' ]
    })
    expect(typeof patch!.json!.visit_at).toBe('string')
    const shown = page.get('#visit-clock')
    expect(shown.attributes('datetime')).toBe('2026-11-24T01:00:00Z')
    expect(shown.text()).toBe(formatVisit('2026-11-24T01:00:00Z', Intl.DateTimeFormat().resolvedOptions().timeZone))
    expect(page.text()).toContain('This visit is later than a week after the enrolment.')
    expect(page.text()).toContain('Verification Interview')
    vi.unstubAllGlobals()
  })

  it('keeps an on-time visit quiet and sends a checkbox change at the same instant', async () => {
    const stored = detail([ emptyLook ])
    stored.submitted_at = '2026-11-17T01:00:00Z'
    stored.visit_at = '2026-11-24T01:00:00Z'
    stored.bringing_basket = false
    stored.assigned_workers = [ 'Aman' ]
    const calls = stubFetch((method) => {
      if (method === 'PATCH') {
        return {
          status: 200,
          body: { visit_at: stored.visit_at, bringing_basket: true, assigned_workers: [ 'Aman' ] }
        }
      }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.text()).toContain('Change visit'))
    expect(page.text()).not.toContain('Set the visit before recording it.')
    expect(page.text()).not.toContain('This visit is later than a week after the enrolment.')
    expect(page.get('#visit-clock').attributes('datetime')).toBe('2026-11-24T01:00:00Z')
    await page.get('#bringing-basket').setValue(true)
    await page.get('form.pre-visit').trigger('submit')
    await vi.waitFor(() => expect(calls.some((call) => call.method === 'PATCH')).toBe(true))
    const patch = calls.find((call) => call.method === 'PATCH')
    expect(patch!.json).toMatchObject({
      visit_at: '2026-11-24T01:00:00Z',
      bringing_basket: true,
      assigned_workers: [ 'Aman' ]
    })
    expect(page.text()).not.toContain('visit message')
    vi.unstubAllGlobals()
  })

  it('lists the six stages after a visit and keeps Who is here current', async () => {
    const stored = detail([ emptyLook ])
    stored.visit_at = '2026-11-24T01:00:00Z'
    stored.assigned_workers = [ 'Aman' ]
    stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.text()).toContain('Verification Interview'))
    for (const name of [
      'Who is here',
      'How the family formed',
      'A day in their life',
      'How they are together',
      'The house and the meals',
      'What they need'
    ]) {
      expect(page.text()).toContain(name)
    }
    expect(page.get('#status-who_is_here').text()).toContain('Current')
    expect(page.get('#status-who_is_here').text()).toContain('Not saved')
    expect(page.get('#status-formation').text()).toBe('Not saved')
    expect(page.find('#back-stage').exists()).toBe(false)
    expect(page.find('#next-stage').exists()).toBe(true)
    expect(page.find('#stage-boxes').exists()).toBe(false)
    expect(page.text()).not.toContain('Post-visit')
    expect(page.text()).toContain('The children are the people recorded here.')
    expect(page.get('#enrolment-facts').text()).toContain('Enrolment')
    expect(page.get('#enrolment-facts').text()).toContain('Rahim')
    expect(page.get('#enrolment-facts').text()).toContain('Male')
    expect(page.get('#enrolment-facts').text()).toContain('+60129876543')
    expect(page.find('#person-relationship').exists()).toBe(false)
    expect(page.find('#person-origin').exists()).toBe(true)
    vi.unstubAllGlobals()
  })

  it('stays on a bad phone, a blank added name, and an incomplete document', async () => {
    const calls = stubFetch(() => ({ status: 200, body: visited() }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#person-phone').exists()).toBe(true))
    await page.get('#person-name').setValue('Rahim')
    await page.get('#person-phone').setValue('12')
    await page.get('#stage-dynamics').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    expect(page.text()).toContain(phoneError)
    expect(page.get<HTMLInputElement>('#person-phone').element.value).toBe('12')
    expect(page.get('#status-who_is_here').text()).toContain('Current')

    await page.get('#person-phone').setValue('+60 12-345 6789')
    await page.get('#add-person').trigger('click')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    expect(page.text()).toContain('Full name is required')
    expect(page.get('#person-name').attributes('aria-invalid')).toBe('true')
    expect(page.get<HTMLInputElement>('#person-name').element.value).toBe('')

    await page.get('#remove-person').trigger('click')
    await page.get('#add-document').trigger('click')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    expect(page.text()).toContain('Document is invalid')
    await page.get('#document-kind-0').setValue('passport')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('Document number is required')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    await page.get('#document-kind-0').setValue('other')
    await page.get('#document-number-0').setValue('ABC')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('What document? is required')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    vi.unstubAllGlobals()
  })

  it('saves Who is here on Next and leaves the other stages unsaved', async () => {
    const calls = stubFetch((method) => {
      if (method === 'PUT') {
        return {
          status: 200,
          body: {
            people: [ {
              person_id: 'person-1',
              family_member_id: 'member-1',
              head: true,
              name: 'Rahim',
              birth_date: '',
              gender: '',
              phone: '',
              documents: [],
              origin: 'Kelantan',
              relationship: '',
              identity: '',
              absent: false,
              absent_since: '',
              absent_reason: ''
            } ],
            others_stay: null,
            others_stay_detail: '',
            care_for_parents: null,
            care_for_parents_detail: '',
            notes: '',
            worker_name: 'Aman',
            recorded_at: '2026-11-24T02:00:00Z'
          }
        }
      }
      return { status: 200, body: visited() }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#person-name').exists()).toBe(true))
    await page.get('#person-name').setValue('Rahim')
    await page.get('#person-origin').setValue('Kelantan')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1))
    const put = calls.find((call) => call.method === 'PUT')
    expect(new URL(put!.url).pathname).toBe('/enrolments/case-1/verification/who_is_here')
    expect(put!.authorization).toBe('Bearer secret-token')
    expect(put!.json).toMatchObject({
      others_stay: null,
      others_stay_detail: '',
      care_for_parents: null,
      care_for_parents_detail: '',
      notes: ''
    })
    expect(put!.json!.people).toMatchObject([ {
      family_member_id: 'member-1',
      head: true,
      name: 'Rahim',
      origin: 'Kelantan',
      relationship: '',
      documents: [],
      absent: false,
      absent_since: '',
      absent_reason: ''
    } ])
    expect(page.get('#status-who_is_here').text()).toBe('Saved')
    expect(page.get('#status-formation').text()).toContain('Current')
    expect(page.get('#status-formation').text()).toContain('Not saved')
    expect(page.find('#person-name').exists()).toBe(false)

    await page.get('#stage-daily_life').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    expect(new URL(calls.filter((call) => call.method === 'PUT')[1]!.url).pathname).toBe('/enrolments/case-1/verification/formation')
    expect(calls.filter((call) => call.method === 'PUT')[1]!.json).toEqual({
      started_year: null,
      how_it_started: '',
      notes: ''
    })
    expect(page.get('#status-formation').text()).toBe('Saved')
    expect(page.get('#status-daily_life').text()).toContain('Current')
    await page.get('#stage-needs').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(3))
    expect(new URL(calls.filter((call) => call.method === 'PUT')[2]!.url).pathname).toBe('/enrolments/case-1/verification/daily_life')
    expect(calls.filter((call) => call.method === 'PUT')[2]!.json).toMatchObject({
      notes: '',
      people: [ { person_id: 'person-1', working: null, in_school: null, job: '', skills: '' } ]
    })
    expect(page.find('#next-stage').exists()).toBe(false)
    expect(page.find('#back-stage').exists()).toBe(true)
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(3)

    await page.get('#back-stage').trigger('click')
    await page.get('#stage-who_is_here').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(4))
    expect(new URL(calls.filter((call) => call.method === 'PUT')[3]!.url).pathname).toBe('/enrolments/case-1/verification/house')
    expect(page.get('#status-who_is_here').text()).toContain('Current')
    expect(page.get('#status-who_is_here').text()).toContain('Saved')
    expect(page.get<HTMLInputElement>('#person-name').element.value).toBe('Rahim')
    expect(page.get<HTMLInputElement>('#person-origin').element.value).toBe('Kelantan')
    vi.unstubAllGlobals()
  })

  it('opens follow-ups for a child, an absence, a guest, and a document', async () => {
    const stored = visited()
    stored.members.push({
      id: 'member-2',
      role: 'spouse',
      name: 'Siti',
      age: 38,
      gender: 'female',
      description: '',
      in_education: false,
      working: false,
      job: '',
      monthly_amount: null
    })
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#person-tab-1').exists()).toBe(true))
    await page.get('#person-tab-1').trigger('click')
    expect(page.find('#remove-person').exists()).toBe(false)
    expect(page.get('#enrolment-facts').text()).toContain('Siti')
    expect(page.get('#enrolment-facts').text()).toContain('Female')
    expect(page.get('#enrolment-facts').text()).not.toContain('+60129876543')
    expect(page.find('#absent-since').exists()).toBe(false)
    expect(page.find('#others-detail').exists()).toBe(false)
    expect(page.find('#care-detail').exists()).toBe(false)
    expect(page.find('#document-other-0').exists()).toBe(false)

    await page.get('#person-relationship').setValue('child')
    expect(page.find('#person-origin').exists()).toBe(false)
    await page.get('#person-relationship').setValue('spouse')
    expect(page.find('#person-origin').exists()).toBe(true)
    await page.get('#person-origin').setValue('Kelantan')
    await page.get('#person-absent').setValue(true)
    expect(page.find('#absent-since').exists()).toBe(true)
    expect(page.find('#absent-reason').exists()).toBe(true)
    await page.get('#absent-since').setValue('2020-01-01')
    await page.get('#absent-reason').setValue('Work')
    await page.get('#others-stay').setValue('yes')
    expect(page.find('#others-detail').exists()).toBe(true)
    await page.get('#others-detail').setValue('A cousin')
    await page.get('#care-for-parents').setValue('yes')
    expect(page.find('#care-detail').exists()).toBe(true)
    await page.get('#care-detail').setValue('Mother')
    await page.get('#add-document').trigger('click')
    expect(page.find('#document-kind-0').exists()).toBe(true)
    expect(page.find('#document-number-0').exists()).toBe(true)
    await page.get('#document-kind-0').setValue('other')
    expect(page.find('#document-other-0').exists()).toBe(true)
    await page.get('#document-other-0').setValue('Card')

    await page.get('#add-person').trigger('click')
    expect(page.find('#remove-person').exists()).toBe(true)
    expect(page.find('#enrolment-facts').exists()).toBe(false)
    await page.get('#remove-person').trigger('click')

    await page.get('#person-relationship').setValue('child')
    await page.get('#person-absent').setValue(false)
    await page.get('#others-stay').setValue('no')
    await page.get('#care-for-parents').setValue('no')
    await page.get('#document-kind-0').setValue('passport')
    await page.get('#document-number-0').setValue('A1')
    expect(page.find('#person-origin').exists()).toBe(false)
    expect(page.find('#absent-since').exists()).toBe(false)
    expect(page.find('#others-detail').exists()).toBe(false)
    expect(page.find('#care-detail').exists()).toBe(false)
    expect(page.find('#document-other-0').exists()).toBe(false)

    await page.get('#person-name').setValue('Siti')
    await page.get('#person-tab-0').trigger('click')
    await page.get('#person-name').setValue('Rahim')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1))
    const put = calls.find((call) => call.method === 'PUT')
    expect(put!.json).toMatchObject({
      others_stay: false,
      others_stay_detail: '',
      care_for_parents: false,
      care_for_parents_detail: ''
    })
    const people = put!.json!.people as Array<Record<string, unknown>>
    expect(people[1]).toMatchObject({
      name: 'Siti',
      relationship: 'child',
      origin: '',
      absent: false,
      absent_since: '',
      absent_reason: '',
      documents: [ { kind: 'passport', number: 'A1', other_label: '' } ]
    })
    vi.unstubAllGlobals()
  })

  it('renders a saved Who is here as text and does not save again', async () => {
    const stored = visited()
    stored.outcome = 'qualified'
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: 'person-1',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          birth_date: '1986-01-02',
          gender: 'male',
          phone: '+60123456789',
          documents: [ { kind: 'other', number: 'ABC', other_label: 'Card' } ],
          origin: 'Kelantan',
          relationship: '',
          identity: 'verified',
          absent: true,
          absent_since: '2020-01-01',
          absent_reason: 'Work'
        } ],
        others_stay: true,
        others_stay_detail: 'A cousin',
        care_for_parents: false,
        care_for_parents_detail: '',
        notes: 'They asked for rice'
      }
    }
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.get('#status-who_is_here').text()).toContain('Saved'))
    expect(page.find('#add-person').exists()).toBe(false)
    expect(page.find('#add-document').exists()).toBe(false)
    expect(page.find('#remove-person').exists()).toBe(false)
    expect(page.find('#person-name').exists()).toBe(false)
    expect(page.text()).toContain('Verified')
    expect(page.text()).toContain('Card')
    expect(page.text()).toContain('A cousin')
    expect(page.text()).toContain('They asked for rice')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    expect(page.get('#status-formation').text()).toContain('Current')
    vi.unstubAllGlobals()
  })

  it('stays on the stage when the save is rejected and signs out on 401', async () => {
    const calls = stubFetch((method) => {
      if (method === 'PUT') {
        return { status: 422, body: { error: { code: 'VALIDATION_ERROR', message: 'Person is required' } } }
      }
      return { status: 200, body: visited() }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.name', 'Aman')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#person-name').exists()).toBe(true))
    await page.get('#person-name').setValue('Rahim')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(page.text()).toContain('Person is required'))
    expect(page.get('#status-who_is_here').text()).toContain('Current')
    expect(page.get<HTMLInputElement>('#person-name').element.value).toBe('Rahim')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)
    vi.unstubAllGlobals()

    stubFetch((method) => {
      if (method === 'PUT') return { status: 401, body: { error: { code: 'UNAUTHENTICATED', message: 'Sign in is required' } } }
      return { status: 200, body: visited() }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    sessionStorage.setItem('sokong.role', 'worker')
    sessionStorage.setItem('sokong.name', 'Aman')
    const again = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(again.find('#person-name').exists()).toBe(true))
    await again.get('#person-name').setValue('Rahim')
    await again.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(navigated).toEqual([ '/sign-in' ]))
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('sokong.name')).toBeNull()
    vi.unstubAllGlobals()
  })

  it('stays on formation for a year outside 1900 through this year and saves a real year', async () => {
    const stored = visited()
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: 'person-1',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        } ]
      }
    }
    const calls = stubFetch((method) => {
      if (method === 'PUT') {
        return {
          status: 200,
          body: {
            people: stored.verification!.who_is_here,
            started_year: 2008,
            how_it_started: 'They met at the market',
            notes: 'Rice',
            worker_name: 'Aman',
            recorded_at: '2026-11-24T02:00:00Z'
          }
        }
      }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-formation').exists()).toBe(true))
    await page.get('#stage-formation').trigger('click')
    await vi.waitFor(() => expect(page.text()).toContain('When did this family start?'))
    expect(page.text()).toContain('How did it start?')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#started-year').setValue('1899')
    await page.get('#stage-daily_life').trigger('click')
    expect(page.text()).toContain('Enter the year, for example 2008.')
    expect(page.get('#status-formation').text()).toContain('Current')
    expect(page.get<HTMLInputElement>('#started-year').element.value).toBe('1899')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#started-year').setValue(String(new Date().getUTCFullYear() + 1))
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)
    expect(page.get('#status-formation').text()).toContain('Current')

    await page.get('#started-year').setValue('2008')
    await page.get('#how-it-started').setValue('a'.repeat(2001))
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('How did it start? is too long')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)
    await page.get('#how-it-started').setValue('They met at the market')
    await page.get('#formation-notes').setValue('Rice')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    const put = calls.filter((call) => call.method === 'PUT')[1]
    expect(new URL(put!.url).pathname).toBe('/enrolments/case-1/verification/formation')
    expect(put!.json).toEqual({
      started_year: 2008,
      how_it_started: 'They met at the market',
      notes: 'Rice'
    })
    expect(page.get('#status-formation').text()).toBe('Saved')
    expect(page.get('#status-daily_life').text()).toContain('Current')
    vi.unstubAllGlobals()
  })

  it('asks about the children only when a person is a child', async () => {
    const stored = visited()
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: 'person-1',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        } ]
      }
    }
    const calls = stubFetch((method) => {
      if (method === 'PUT') return { status: 200, body: stored.verification!.who_is_here as Record<string, unknown> }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-dynamics').exists()).toBe(true))
    await page.get('#stage-dynamics').trigger('click')
    await vi.waitFor(() => expect(page.text()).toContain('What does a hard week look like here?'))
    expect(page.text()).toContain('When someone here needs help, who steps in?')
    expect(page.text()).toContain('Write what the family said.')
    expect(page.text()).not.toContain('How are the children at home?')
    expect(page.text().toLowerCase()).not.toContain('score')
    await page.get('#hard-week').setValue('Rain')
    await page.get('#who-steps-in').setValue('Siti')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    expect(calls.filter((call) => call.method === 'PUT')[1]!.json).toEqual({
      hard_week: 'Rain',
      who_steps_in: 'Siti',
      children_at_home: '',
      notes: ''
    })
    vi.unstubAllGlobals()

    const withChild = visited()
    withChild.verification = {
      who_is_here: {
        people: [ {
          person_id: 'person-2',
          family_member_id: null,
          head: false,
          name: 'Ali',
          relationship: 'child',
          documents: []
        } ]
      }
    }
    const childCalls = stubFetch((method) => {
      if (method === 'PUT') return { status: 200, body: withChild.verification!.who_is_here as Record<string, unknown> }
      return { status: 200, body: withChild }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const childPage = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(childPage.find('#stage-dynamics').exists()).toBe(true))
    await childPage.get('#stage-dynamics').trigger('click')
    await vi.waitFor(() => expect(childPage.text()).toContain('How are the children at home?'))
    await childPage.get('#children-at-home').setValue('They study at the table')
    await childPage.get('#dynamics-notes').setValue('Nothing else')
    await childPage.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(childCalls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    expect(new URL(childCalls.filter((call) => call.method === 'PUT')[1]!.url).pathname).toBe('/enrolments/case-1/verification/dynamics')
    expect(childCalls.filter((call) => call.method === 'PUT')[1]!.json).toMatchObject({
      children_at_home: 'They study at the table',
      notes: 'Nothing else'
    })
    expect(childPage.get('#status-dynamics').text()).toBe('Saved')
    await childPage.get('#stage-needs').trigger('click')
    await vi.waitFor(() => expect(childCalls.filter((call) => call.method === 'PUT')).toHaveLength(3))
    expect(new URL(childCalls.filter((call) => call.method === 'PUT')[2]!.url).pathname).toBe('/enrolments/case-1/verification/house')
    expect(childCalls.filter((call) => call.method === 'PUT')[2]!.json).toEqual({
      place: '',
      rent_per_month: null,
      behind_on_payments: null,
      has_water: null,
      has_electricity: null,
      sleeping_rooms: null,
      safe: null,
      unsafe_detail: '',
      meals: '',
      basket: '',
      notes: ''
    })
    expect(childPage.find('#next-stage').exists()).toBe(false)
    expect(childPage.text()).not.toContain('Post-visit')
    vi.unstubAllGlobals()
  })

  it('renders formation and dynamics as text when the mark is set', async () => {
    const stored = visited()
    stored.outcome = 'qualified'
    stored.verification = {
      who_is_here: {
        people: [ { person_id: 'person-2', name: 'Ali', relationship: 'child', head: false, documents: [] } ]
      },
      formation: { started_year: 2008, how_it_started: 'They met at the market', notes: 'Rice' },
      dynamics: { hard_week: 'Rain', who_steps_in: 'Siti', children_at_home: 'They study at the table', notes: '' }
    }
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-formation').exists()).toBe(true))
    await page.get('#stage-formation').trigger('click')
    expect(page.find('#started-year').exists()).toBe(false)
    expect(page.text()).toContain('2008')
    expect(page.text()).toContain('They met at the market')
    expect(page.text()).toContain('Rice')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    await page.get('#stage-dynamics').trigger('click')
    expect(page.find('#hard-week').exists()).toBe(false)
    expect(page.text()).toContain('Rain')
    expect(page.text()).toContain('They study at the table')
    expect(page.text()).toContain('How are the children at home?')
    vi.unstubAllGlobals()
  })

  it('records work and school independently and saves every person on leave', async () => {
    const stored = visited()
    stored.members.push({
      id: 'member-2',
      role: 'spouse',
      name: 'Siti',
      age: 38,
      gender: 'female',
      description: '',
      in_education: true,
      working: false,
      job: '',
      monthly_amount: null
    })
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: '11111111-1111-4111-8111-111111111111',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        }, {
          person_id: '22222222-2222-4222-8222-222222222222',
          family_member_id: 'member-2',
          head: false,
          name: 'Siti',
          relationship: 'spouse',
          documents: []
        } ]
      }
    }
    const calls = stubFetch((method) => {
      if (method === 'PUT') return { status: 200, body: stored.verification!.who_is_here as Record<string, unknown> }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-daily_life').exists()).toBe(true))
    await page.get('#stage-daily_life').trigger('click')
    await vi.waitFor(() => expect(page.text()).toContain('Are you working?'))
    expect(page.text()).toContain('Are you in school?')
    expect(page.text()).toContain('Any skills to highlight?')
    expect(page.get('#daily-enrolment').text()).toContain('Working')
    expect(page.get('#daily-enrolment').text()).toContain('Yes')
    expect(page.get('#daily-enrolment').text()).toContain('Driver')
    expect(page.get('#daily-enrolment').text()).toContain('800')
    expect(page.get('#daily-enrolment').text()).toContain('In education')
    expect(page.find('#job').exists()).toBe(false)
    expect(page.find('#school-where').exists()).toBe(false)
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#working').setValue('yes')
    expect(page.find('#job').exists()).toBe(true)
    expect(page.find('#monthly-amount').exists()).toBe(true)
    expect(page.find('#previous-jobs').exists()).toBe(true)
    expect(page.find('#wished-work').exists()).toBe(true)
    await page.get('#job').setValue('A stall')
    await page.get('#monthly-amount').setValue('12abc')
    await page.get('#skills').setValue('Cooking')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('Ringgit per month is invalid')
    expect(page.get('#status-daily_life').text()).toContain('Current')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#monthly-amount').setValue('800')
    await page.get('#previous-jobs').setValue('Driving')
    await page.get('#wished-work').setValue('A shop')
    await page.get('#in-school').setValue('yes')
    expect(page.find('#job').exists()).toBe(true)
    expect(page.find('#school-where').exists()).toBe(true)
    await page.get('#in-school').setValue('no')
    await page.get('#day-tab-1').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)
    expect(page.get('#daily-enrolment').text()).toContain('In education')
    expect(page.get('#daily-enrolment').text()).toContain('Yes')
    expect(page.get('#daily-enrolment').text()).not.toContain('Driver')
    await page.get('#working').setValue('yes')
    await page.get('#job').setValue('Should be cleared')
    await page.get('#monthly-amount').setValue('50')
    await page.get('#previous-jobs').setValue('a'.repeat(2001))
    await page.get('#working').setValue('no')
    expect(page.find('#job').exists()).toBe(false)
    await page.get('#in-school').setValue('yes')
    expect(page.find('#school-going').exists()).toBe(true)
    expect(page.find('#school-where').exists()).toBe(true)
    expect(page.find('#school-travel').exists()).toBe(true)
    await page.get('#school-going').setValue('Well')
    await page.get('#school-where').setValue('The village school')
    await page.get('#school-travel').setValue('Walk')
    await page.get('#skills').setValue('Sewing')
    await page.get('#day-tab-0').trigger('click')
    expect(page.get<HTMLInputElement>('#job').element.value).toBe('A stall')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#daily-notes').setValue('A long day')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    const put = calls.filter((call) => call.method === 'PUT')[1]
    expect(new URL(put!.url).pathname).toBe('/enrolments/case-1/verification/daily_life')
    expect(put!.json).toMatchObject({
      notes: 'A long day',
      people: [
        {
          person_id: '11111111-1111-4111-8111-111111111111',
          working: true,
          job: 'A stall',
          monthly_amount: 800,
          previous_jobs: 'Driving',
          wished_work: 'A shop',
          skills: 'Cooking',
          in_school: false,
          school_going: '',
          school_where: '',
          school_travel: ''
        },
        {
          person_id: '22222222-2222-4222-8222-222222222222',
          working: false,
          job: '',
          monthly_amount: null,
          previous_jobs: '',
          wished_work: '',
          skills: 'Sewing',
          in_school: true,
          school_going: 'Well',
          school_where: 'The village school',
          school_travel: 'Walk'
        }
      ]
    })
    expect(page.get('#status-daily_life').text()).toBe('Saved')
    vi.unstubAllGlobals()
  })

  it('renders a saved day as text', async () => {
    const stored = visited()
    stored.outcome = 'qualified'
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: '11111111-1111-4111-8111-111111111111',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        } ]
      },
      daily_life: {
        people: [ {
          person_id: '11111111-1111-4111-8111-111111111111',
          working: true,
          job: 'A stall',
          monthly_amount: 800,
          previous_jobs: 'Driving',
          wished_work: 'A shop',
          skills: 'Cooking',
          in_school: true,
          school_going: 'Well',
          school_where: 'The village school',
          school_travel: 'Walk'
        } ],
        notes: 'A long day'
      }
    }
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-daily_life').exists()).toBe(true))
    await page.get('#stage-daily_life').trigger('click')
    expect(page.find('#working').exists()).toBe(false)
    expect(page.text()).toContain('A stall')
    expect(page.text()).toContain('Driving')
    expect(page.text()).toContain('A shop')
    expect(page.text()).toContain('Cooking')
    expect(page.text()).toContain('Well')
    expect(page.text()).toContain('The village school')
    expect(page.text()).toContain('Walk')
    expect(page.text()).toContain('A long day')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    vi.unstubAllGlobals()
  })

  it('hides rent and the unsafe note unless those answers open them', async () => {
    const stored = visited()
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: '11111111-1111-4111-8111-111111111111',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        } ]
      }
    }
    const calls = stubFetch((method) => {
      if (method === 'PUT') return { status: 200, body: calls[calls.length - 1]?.json ?? {} }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-house').exists()).toBe(true))
    await page.get('#stage-house').trigger('click')
    await vi.waitFor(() => expect(page.text()).toContain('This place'))
    expect(page.text()).toContain('Own')
    expect(page.text()).toContain('Rent')
    expect(page.text()).toContain('Staying with someone')
    expect(page.text()).toContain('Temporary')
    expect(page.text()).toContain('Does it have water?')
    expect(page.text()).toContain('Does it have electricity?')
    expect(page.text()).toContain('How many meals a day?')
    expect(page.text()).toContain('3 a day')
    expect(page.text()).toContain('2 a day')
    expect(page.text()).toContain('1 a day')
    expect(page.text()).toContain('Not every day')
    expect(page.text()).toContain('Basket')
    expect(page.find('#rent-per-month').exists()).toBe(false)
    expect(page.find('#unsafe-detail').exists()).toBe(false)

    await page.get('#place').setValue('rent')
    expect(page.find('#rent-per-month').exists()).toBe(true)
    expect(page.find('#behind-on-payments').exists()).toBe(true)
    await page.get('#rent-per-month').setValue('12abc')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('Rent per month is invalid')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#rent-per-month').setValue('400')
    await page.get('#behind-on-payments').setValue('yes')
    await page.get('#safe').setValue('no')
    await page.get('#unsafe-detail').setValue('The stairs')
    await page.get('#has-water').setValue('yes')
    await page.get('#has-electricity').setValue('no')
    await page.get('#sleeping-rooms').setValue('2')
    await page.get('#meals').setValue('three')
    await page.get('#basket').setValue('Rice')
    await page.get('#house-notes').setValue('The roof leaks')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    expect(calls.filter((call) => call.method === 'PUT')[1]!.json).toMatchObject({
      place: 'rent',
      rent_per_month: 400,
      behind_on_payments: true,
      safe: false,
      unsafe_detail: 'The stairs'
    })

    await page.get('#back-stage').trigger('click')
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('rent')
    expect(page.get<HTMLInputElement>('#rent-per-month').element.value).toBe('400')
    expect(page.get<HTMLInputElement>('#behind-on-payments').element.value).toBe('yes')
    expect(page.get<HTMLTextAreaElement>('#unsafe-detail').element.value).toBe('The stairs')
    await page.get('#place').setValue('own')
    expect(page.find('#rent-per-month').exists()).toBe(false)
    await page.get('#safe').setValue('yes')
    expect(page.find('#unsafe-detail').exists()).toBe(false)
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(3))
    expect(new URL(calls.filter((call) => call.method === 'PUT')[2]!.url).pathname).toBe('/enrolments/case-1/verification/house')
    expect(calls.filter((call) => call.method === 'PUT')[2]!.json).toEqual({
      place: 'own',
      rent_per_month: null,
      behind_on_payments: null,
      has_water: true,
      has_electricity: false,
      sleeping_rooms: 2,
      safe: true,
      unsafe_detail: '',
      meals: 'three',
      basket: 'Rice',
      notes: 'The roof leaks'
    })
    expect(page.get('#status-house').text()).toBe('Saved')
    vi.unstubAllGlobals()
  })

  it('renders a saved house as text', async () => {
    const stored = visited()
    stored.outcome = 'qualified'
    stored.verification = {
      house: {
        place: 'rent',
        rent_per_month: 400,
        behind_on_payments: true,
        has_water: true,
        has_electricity: false,
        sleeping_rooms: 2,
        safe: false,
        unsafe_detail: 'The stairs',
        meals: 'three',
        basket: 'Rice',
        notes: 'The roof leaks'
      }
    }
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-house').exists()).toBe(true))
    await page.get('#stage-house').trigger('click')
    expect(page.find('#place').exists()).toBe(false)
    expect(page.text()).toContain('This place Rent')
    expect(page.text()).toContain('How many meals a day? 3 a day')
    expect(page.text()).toContain('Are you behind on payments? Yes')
    expect(page.text()).toContain('Does it have water? Yes')
    expect(page.text()).toContain('Does it have electricity? No')
    expect(page.text()).toContain('How many rooms do people sleep in? 2')
    expect(page.text()).toContain('Is this place safe? No')
    expect(page.text()).toContain('The roof leaks')
    expect(page.text()).toContain('400')
    expect(page.text()).toContain('The stairs')
    expect(page.text()).toContain('Rice')
    await page.get('#next-stage').trigger('click')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(0)
    vi.unstubAllGlobals()

    const staying = visited()
    staying.outcome = 'qualified'
    staying.verification = {
      house: {
        place: 'staying_with_someone',
        meals: 'not_every_day',
        rent_per_month: null,
        behind_on_payments: null,
        has_water: null,
        has_electricity: null,
        sleeping_rooms: null,
        safe: null,
        unsafe_detail: '',
        basket: '',
        notes: ''
      }
    }
    stubFetch(() => ({ status: 200, body: staying }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const again = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(again.find('#stage-house').exists()).toBe(true))
    await again.get('#stage-house').trigger('click')
    expect(again.text()).toContain('This place Staying with someone')
    expect(again.text()).toContain('How many meals a day? Not every day')
    vi.unstubAllGlobals()
  })

  it('stays on the house stage for a bad room count or a long basket', async () => {
    const stored = visited()
    stored.verification = {
      who_is_here: {
        people: [ {
          person_id: '11111111-1111-4111-8111-111111111111',
          family_member_id: 'member-1',
          head: true,
          name: 'Rahim',
          relationship: '',
          documents: []
        } ]
      }
    }
    const calls = stubFetch((method) => {
      if (method === 'PUT') return { status: 200, body: calls[calls.length - 1]?.json ?? {} }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(EnrolmentDetail, { route: '/enrolments/case-1' })
    await vi.waitFor(() => expect(page.find('#stage-house').exists()).toBe(true))
    await page.get('#stage-house').trigger('click')
    await vi.waitFor(() => expect(page.find('#sleeping-rooms').exists()).toBe(true))

    await page.get('#sleeping-rooms').setValue('100')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('How many rooms do people sleep in? is invalid')
    expect(page.get('#status-house').text()).toContain('Current')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#sleeping-rooms').setValue('12abc')
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('How many rooms do people sleep in? is invalid')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(1)

    await page.get('#sleeping-rooms').setValue('0')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(2))
    expect(calls.filter((call) => call.method === 'PUT')[1]!.json).toMatchObject({ sleeping_rooms: 0 })

    await page.get('#back-stage').trigger('click')
    await page.get('#sleeping-rooms').setValue('99')
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(3))
    expect(calls.filter((call) => call.method === 'PUT')[2]!.json).toMatchObject({ sleeping_rooms: 99 })

    await page.get('#back-stage').trigger('click')
    await page.get('#basket').setValue('a'.repeat(501))
    await page.get('#next-stage').trigger('click')
    expect(page.text()).toContain('Basket is too long')
    expect(page.get('#status-house').text()).toContain('Current')
    expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(3)

    await page.get('#basket').setValue('a'.repeat(500))
    await page.get('#next-stage').trigger('click')
    await vi.waitFor(() => expect(calls.filter((call) => call.method === 'PUT')).toHaveLength(4))
    expect(calls.filter((call) => call.method === 'PUT')[3]!.json).toMatchObject({
      sleeping_rooms: 99,
      basket: 'a'.repeat(500)
    })
    vi.unstubAllGlobals()
  })
})
