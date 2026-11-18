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
    assigned_workers: null as string[] | null
  }
}

const emptyLook = { id: 'look-empty', worker_name: 'Aminah', looked_at: '2026-11-12T09:00:00Z', note: '' }

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
    await mountSuspended(EnrolmentsPage)
    await vi.waitFor(() => expect(navigated).toEqual([ '/sign-in' ]))
    expect(sessionStorage.getItem('sokong.token')).toBeNull()
    expect(sessionStorage.getItem('sokong.role')).toBeNull()
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
    expect(page.text()).not.toContain('Verification Interview')
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
})
