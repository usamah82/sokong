import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import LocalityPage from '../../pages/localities/[id].vue'

const unavailable = 'This locality is not available.'
const radiusMessage = 'Radius requires a center'

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

function stubFetch(handler: (body: Record<string, unknown> | null) => { status: number, body: unknown }) {
  const calls: CapturedRequest[] = []
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers)
    const json = init?.body ? JSON.parse(String(init.body)) as Record<string, unknown> : null
    calls.push({
      url: String(input),
      method: init?.method ?? 'GET',
      authorization: headers.get('Authorization'),
      json
    })
    const response = handler(json)
    return {
      ok: response.status >= 200 && response.status < 300,
      status: response.status,
      json: async () => response.body
    }
  }))
  return calls
}

const stored = {
  id: 'locality-1',
  name: 'Block 4',
  latitude: 3.1,
  longitude: 101.7,
  radius_metres: 500
}

describe('locality boundary', () => {
  beforeEach(() => {
    sessionStorage.clear()
    navigated.length = 0
  })

  it('opens sign-in when the token is missing', async () => {
    const calls = stubFetch(() => ({ status: 200, body: stored }))
    await mountSuspended(LocalityPage, { route: '/localities/locality-1' })
    await vi.waitFor(() => {
      expect(navigated).toEqual([ '/sign-in' ])
    })
    expect(calls).toHaveLength(0)
    vi.unstubAllGlobals()
  })

  it('saves a name, center, and radius and shows the returned values', async () => {
    const calls = stubFetch((body) => {
      if (body && Object.keys(body).length === 0) return { status: 200, body: stored }
      return {
        status: 200,
        body: { ...stored, name: 'Block 4', latitude: 3.1, longitude: 101.7, radius_metres: 200000 }
      }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(LocalityPage, { route: '/localities/locality-1' })
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#name').element.value).toBe('Block 4')
    })
    expect(page.get<HTMLInputElement>('#latitude').element.value).toBe('3.1')
    expect(page.get<HTMLInputElement>('#longitude').element.value).toBe('101.7')
    expect(page.get<HTMLInputElement>('#radius').element.value).toBe('500')
    expect(calls[0]!.method).toBe('PATCH')
    expect(new URL(calls[0]!.url).pathname).toBe('/localities/locality-1')
    expect(calls[0]!.authorization).toBe('Bearer secret-token')
    expect(calls[0]!.json).toEqual({})

    await page.get('#radius').setValue('200000')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#radius').element.value).toBe('200000')
    })
    const saved = calls[1]!
    expect(saved.method).toBe('PATCH')
    expect(saved.json).toEqual({
      name: 'Block 4',
      latitude: 3.1,
      longitude: 101.7,
      radius_metres: 200000
    })
    expect(page.text()).not.toContain('moved')
    vi.unstubAllGlobals()
  })

  it('clears the circle with nulls and shows an empty circle', async () => {
    const calls = stubFetch((body) => {
      if (body && body.radius_metres === null) {
        return { status: 200, body: { ...stored, latitude: null, longitude: null, radius_metres: null } }
      }
      return { status: 200, body: stored }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(LocalityPage, { route: '/localities/locality-1' })
    await vi.waitFor(() => expect(page.get('#clear-circle').text()).toBe('Clear the circle'))
    await page.get('#clear-circle').trigger('click')
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#radius').element.value).toBe('')
    })
    expect(page.get<HTMLInputElement>('#latitude').element.value).toBe('')
    expect(page.get<HTMLInputElement>('#longitude').element.value).toBe('')
    expect(page.get<HTMLInputElement>('#name').element.value).toBe('Block 4')
    expect(calls.at(-1)!.json).toEqual({
      name: 'Block 4',
      latitude: null,
      longitude: null,
      radius_metres: null
    })
    vi.unstubAllGlobals()
  })

  it('shows the radius message and keeps the typed values', async () => {
    const calls = stubFetch((body) => {
      if (body && Object.keys(body).length === 0) {
        return { status: 200, body: { ...stored, latitude: null, longitude: null, radius_metres: null } }
      }
      return { status: 422, body: { error: { code: 'VALIDATION_ERROR', message: radiusMessage } } }
    })
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(LocalityPage, { route: '/localities/locality-1' })
    await vi.waitFor(() => expect(page.get('#name').exists()).toBe(true))
    await page.get('#radius').setValue('20')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => expect(page.text()).toContain(radiusMessage))
    expect(page.get<HTMLInputElement>('#radius').element.value).toBe('20')
    expect(page.get<HTMLInputElement>('#latitude').element.value).toBe('')
    expect(page.get<HTMLInputElement>('#longitude').element.value).toBe('')
    expect(page.get<HTMLInputElement>('#name').element.value).toBe('Block 4')
    expect(calls[1]!.json).toEqual({
      name: 'Block 4',
      latitude: null,
      longitude: null,
      radius_metres: 20
    })
    vi.unstubAllGlobals()
  })

  it('says the locality is not available', async () => {
    stubFetch(() => ({ status: 404, body: { error: { code: 'NOT_FOUND', message: 'Not found' } } }))
    sessionStorage.setItem('sokong.token', 'secret-token')
    const page = await mountSuspended(LocalityPage, { route: '/localities/locality-1' })
    await vi.waitFor(() => expect(page.text()).toContain(unavailable))
    expect(page.text()).not.toContain('Not found')
    vi.unstubAllGlobals()
  })
})
