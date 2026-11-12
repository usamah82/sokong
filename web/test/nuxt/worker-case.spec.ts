import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import EnrolmentDetail from '../../pages/enrolments/[id].vue'
import EnrolmentsPage from '../../pages/enrolments/index.vue'

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
    visit_at: null
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
    expect(member).toContain('In education')
    expect(member).toContain('No')
    expect(member).toContain('Working')
    expect(member).toContain('Yes')
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
})
