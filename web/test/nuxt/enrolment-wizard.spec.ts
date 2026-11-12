import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it, vi } from 'vitest'
import IndexPage from '../../pages/index.vue'

const copy = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../i18n/locales/en.json'), 'utf8')
).wizard as {
  enroler: {
    title: string
    self: string
    behalf: string
    consentSelf: string
    consentBehalf: string
    phoneError: string
  }
  family: { title: string }
}

const enroler = copy.enroler

describe('who is enrolling', () => {
  it('reads the choices, consent sentences, and phone error from the spec', () => {
    expect(enroler.self).toBe('This is my family')
    expect(enroler.behalf).toBe('I am enrolling this family for them')
    expect(enroler.consentSelf).toBe('Submission means the family consents. That consent is confirmed at the verification visit.')
    expect(enroler.consentBehalf).toBe('This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then.')
    expect(enroler.phoneError).toBe('Enter a phone number, for example +60 12-345 6789.')
  })

  it('starts on this family, swaps the consent sentence, and keeps a valid phone across Back', async () => {
    const page = await mountSuspended(IndexPage)

    expect(page.get('input[value="self"]').element.checked).toBe(true)
    expect(page.text()).toContain(enroler.self)
    expect(page.text()).toContain(enroler.behalf)
    expect(page.text()).toContain(enroler.consentSelf)
    expect(page.text()).not.toContain(enroler.consentBehalf)
    expect(page.text()).not.toContain(enroler.phoneError)
    expect(page.text()).toContain('Step 1 of 4')
    expect(page.text()).toContain(enroler.title)
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('input[value="behalf"]').setValue(true)
    expect(page.text()).toContain(enroler.consentBehalf)
    expect(page.text()).not.toContain(enroler.consentSelf)

    await page.get('#phone').setValue('Mary at the shop')
    expect(page.text()).toContain(enroler.phoneError)
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    for (const bad of [ '123', 'phone: 0123456789' ]) {
      await page.get('#phone').setValue(bad)
      expect(page.text()).toContain(enroler.phoneError)
      expect(page.get('button.primary').attributes('disabled')).toBeDefined()
      await page.get('button.primary').trigger('click')
      expect(page.text()).toContain(enroler.title)
    }

    await page.get('#phone').setValue('')
    expect(page.text()).not.toContain(enroler.phoneError)
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#phone').setValue('012-345 6789')
    expect(page.text()).not.toContain(enroler.phoneError)
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('#phone').setValue('123')
    expect(page.text()).toContain(enroler.phoneError)
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#phone').setValue('012-345 6789')
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain(copy.family.title)
    expect(page.text()).toContain('Step 2 of 4')

    await goBack(page)
    expect(page.text()).toContain('Step 1 of 4')
    expect(page.get<HTMLInputElement>('#phone').element.value).toBe('012-345 6789')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('')

    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('#email').setValue('siti@example.com')
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain(copy.family.title)

    await goBack(page)
    expect(page.get<HTMLInputElement>('#phone').element.value).toBe('+60 12-345 6789')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')
    expect(page.get('input[value="behalf"]').element.checked).toBe(true)
    expect(page.text()).toContain(enroler.consentBehalf)
    expect(page.text()).toContain('Step 1 of 4')
  })

  it('advances from a dotted phone and from submit, even when the email is not an address', async () => {
    const page = await mountSuspended(IndexPage)

    await page.get('#phone').setValue('(012) 345.6789')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain(copy.family.title)

    await goBack(page)
    await page.get('#phone').setValue('123')
    await page.get('form').trigger('submit')
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(page.text()).toContain(enroler.title)

    await page.get('#phone').setValue('0123456789')
    await page.get('#email').setValue('not-an-email')
    await page.get('form').trigger('submit')
    await vi.waitFor(() => {
      expect(page.text()).toContain(copy.family.title)
    })
  })
})

async function goBack(page: Awaited<ReturnType<typeof mountSuspended>>) {
  const back = page.findAll('button').find((button) => button.text() === 'Back')
  if (!back) throw new Error('Back is missing')
  await back.trigger('click')
}

async function openFamily(page: Awaited<ReturnType<typeof mountSuspended>>, phone = '+60 12-345 6789') {
  await page.get('#phone').setValue(phone)
  await page.get('button.primary').trigger('click')
}

describe('the family', () => {
  it('requires a place and a head name, and keeps both stages on Back', async () => {
    const page = await mountSuspended(IndexPage)
    await page.get('#email').setValue('siti@example.com')
    await openFamily(page)

    expect(page.text()).toContain('The family')
    expect(page.text()).toContain('Step 2 of 4')
    expect(page.text()).toContain('Head of the family')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#place').setValue('   ')
    await page.get('#head-name').setValue('Aminah')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('   ')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#head-name').setValue('Aminah')
    await page.get('#age').setValue('34')
    await page.get('#description').setValue('Runs a food stall at night.')
    expect(Number(page.get('#description').attributes('rows'))).toBeGreaterThanOrEqual(3)
    await page.get('input[value="female"]').setValue(true)
    await page.get('#education').setValue(true)
    await page.get('#family-phone').setValue('60123456789')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain('Other people in the family')
    expect(page.text()).toContain('Step 3 of 4')

    await goBack(page)
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    expect(page.get<HTMLInputElement>('#head-name').element.value).toBe('Aminah')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60123456789')

    await goBack(page)
    expect(page.get<HTMLInputElement>('#phone').element.value).toBe('+60 12-345 6789')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')

    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    expect(page.get<HTMLInputElement>('#head-name').element.value).toBe('Aminah')
    expect(page.get<HTMLInputElement>('#age').element.value).toBe('34')
    expect(page.get('input[value="female"]').element.checked).toBe(true)
    expect(page.get<HTMLTextAreaElement>('#description').element.value).toBe('Runs a food stall at night.')
    expect(page.get<HTMLInputElement>('#education').element.checked).toBe(true)
  })

  it('copies the enroler phone until the family phone is edited or cleared', async () => {
    const page = await mountSuspended(IndexPage)
    await openFamily(page, '012-345 6789')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('012-345 6789')

    await goBack(page)
    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('+60 12-345 6789')

    await page.get('#family-phone').setValue('60123456789')
    await goBack(page)
    await page.get('#phone').setValue('0123456789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60123456789')

    await page.get('#family-phone').setValue('')
    await goBack(page)
    await page.get('#phone').setValue('+60123456789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('')
  })

  it('starts the family phone empty on behalf and clears only an automatic copy', async () => {
    const behalf = await mountSuspended(IndexPage)
    await behalf.get('input[value="behalf"]').setValue(true)
    await openFamily(behalf)
    expect(behalf.get<HTMLInputElement>('#family-phone').element.value).toBe('')

    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await goBack(page)
    await page.get('input[value="behalf"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('')

    await goBack(page)
    await page.get('input[value="self"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('+60 12-345 6789')

    await page.get('#family-phone').setValue('60111111111')
    await goBack(page)
    await page.get('input[value="behalf"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60111111111')
  })

  it('does not require a family phone, and keeps one typed on behalf', async () => {
    const page = await mountSuspended(IndexPage)
    await page.get('input[value="behalf"]').setValue(true)
    await openFamily(page)
    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('#family-phone').setValue('Mary at the shop')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('#family-phone').setValue('60111111111')
    await goBack(page)
    await page.get('input[value="self"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60111111111')
  })

  it('allows in education and working together', async () => {
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#education').setValue(true)
    await page.get('#working').setValue(true)
    expect(page.get<HTMLInputElement>('#education').element.checked).toBe(true)
    expect(page.get<HTMLInputElement>('#working').element.checked).toBe(true)
    expect(page.get('#job').exists()).toBe(true)
    expect(page.get('#amount').exists()).toBe(true)
  })

  it('offers only three genders, an integer or blank age, and job fields only while working', async () => {
    const page = await mountSuspended(IndexPage)
    await openFamily(page)

    const genders = page.findAll('input[name="gender"]')
    expect(genders).toHaveLength(3)
    expect(genders.map((gender) => gender.attributes('value'))).toEqual([ 'male', 'female', 'unspecified' ])
    expect(page.get('input[value="unspecified"]').element.checked).toBe(true)
    expect(page.text()).toContain('Male')
    expect(page.text()).toContain('Female')
    expect(page.text()).toContain('Unspecified')

    await page.get('#age').setValue('')
    expect(page.get<HTMLInputElement>('#age').element.value).toBe('')
    await page.get('#age').setValue('34')
    expect(page.get<HTMLInputElement>('#age').element.value).toBe('34')

    expect(page.find('#job').exists()).toBe(false)
    expect(page.find('#amount').exists()).toBe(false)
    await page.get('#working').setValue(true)
    expect(page.text()).toContain('Job')
    expect(page.text()).toContain('Rough monthly amount')
    await page.get('#job').setValue('Food stall')
    await page.get('#amount').setValue('800')
    await page.get('#working').setValue(false)
    expect(page.find('#job').exists()).toBe(false)
    await page.get('#working').setValue(true)
    expect(page.get<HTMLInputElement>('#job').element.value).toBe('Food stall')
    expect(page.get<HTMLInputElement>('#amount').element.value).toBe('800')
  })
})

const suggested = 'This place was suggested from your current location.'
const elsewhere = 'You can name a different place if you are not with the family.'
const nameThePlace = 'Your current location was read. Name the place.'

function stubPlace(outcome: 'named' | 'none' | 'refused') {
  const fetchMock = vi.fn(async () => ({
    ok: true,
    json: async () => ({ locality: outcome === 'named' ? { name: 'Block 4' } : null })
  }))
  vi.stubGlobal('fetch', fetchMock)
  Object.defineProperty(navigator, 'geolocation', {
    configurable: true,
    value: {
      getCurrentPosition(success: PositionCallback, error?: PositionErrorCallback) {
        if (outcome === 'refused') {
          error?.({ code: 1 } as GeolocationPositionError)
          return
        }
        success({ coords: { latitude: 3.1, longitude: 101.7 } } as GeolocationPosition)
      }
    }
  })
  return fetchMock
}

describe('place suggestion', () => {
  it('fills the suggested name and drops that sentence when the name changes', async () => {
    const fetchMock = stubPlace('named')
    const page = await mountSuspended(IndexPage)
    await openFamily(page)

    await page.get('#use-location').trigger('click')
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    })
    expect(page.text()).toContain(suggested)
    expect(page.text()).toContain(elsewhere)
    const url = new URL(String(fetchMock.mock.calls[0][0]))
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/localities/suggestion')
    expect(url.searchParams.get('latitude')).toBe('3.1')
    expect(url.searchParams.get('longitude')).toBe('101.7')
    expect(fetchMock.mock.calls[0][1]).toBeUndefined()
    expect(page.get('#place').attributes('data-latitude')).toBe('3.1')
    expect(page.get('#place').attributes('data-longitude')).toBe('101.7')

    await page.get('#place').setValue('Somewhere else')
    expect(page.text()).not.toContain(suggested)
    expect(page.text()).toContain(elsewhere)
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
    expect(page.get('#place').attributes('data-longitude')).toBeUndefined()
  })

  it('asks for a place name when the device point has no locality', async () => {
    stubPlace('none')
    const page = await mountSuspended(IndexPage)
    await openFamily(page)

    await page.get('#use-location').trigger('click')
    await vi.waitFor(() => {
      expect(page.text()).toContain(nameThePlace)
    })
    expect(page.text()).not.toContain(suggested)
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('')
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
  })

  it('still allows Next after the device is refused and a place is typed', async () => {
    const fetchMock = stubPlace('refused')
    const page = await mountSuspended(IndexPage)
    await openFamily(page)

    await page.get('#use-location').trigger('click')
    expect(fetchMock).not.toHaveBeenCalled()
    expect(page.text()).not.toContain(suggested)
    expect(page.text()).not.toContain(nameThePlace)

    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()
  })

  it('keeps the suggestion across Next and drops it when the name changes later', async () => {
    stubPlace('named')
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#use-location').trigger('click')
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    })
    await page.get('#head-name').setValue('Aminah')
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain('Other people in the family')
    await goBack(page)
    expect(page.text()).toContain(suggested)
    expect(page.text()).toContain(elsewhere)
    expect(page.get('#place').attributes('data-latitude')).toBe('3.1')
    expect(page.get('#place').attributes('data-longitude')).toBe('101.7')

    await page.get('#place').setValue('Somewhere else')
    expect(page.text()).not.toContain(suggested)
    expect(page.text()).toContain(elsewhere)
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
    expect(page.get('#place').attributes('data-longitude')).toBeUndefined()
  })

  it('replaces a suggestion when a later point has no locality', async () => {
    const held = holdLocation()
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#use-location').trigger('click')
    await held.answer(0, { locality: { name: 'Block 4' } })
    await vi.waitFor(() => {
      expect(page.text()).toContain(suggested)
    })

    await page.get('#use-location').trigger('click')
    await held.answer(1, { locality: null })
    await vi.waitFor(() => {
      expect(page.text()).toContain(nameThePlace)
    })
    expect(page.text()).not.toContain(suggested)
    expect(page.text()).not.toContain(elsewhere)
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
    expect(page.get('#place').attributes('data-longitude')).toBeUndefined()
  })

  it('ignores a suggestion that arrives after the place was typed', async () => {
    const held = holdLocation()
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#use-location').trigger('click')
    await page.get('#place').setValue('Kampung X')
    await held.answer(0, { locality: { name: 'Block 4' } })
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Kampung X')
    expect(page.text()).not.toContain(suggested)
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
  })

  it('keeps the newer lookup when an older response arrives later', async () => {
    const held = holdLocation()
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#use-location').trigger('click')
    await page.get('#use-location').trigger('click')
    await held.answer(1, { locality: null })
    await vi.waitFor(() => {
      expect(page.text()).toContain(nameThePlace)
    })
    await held.answer(0, { locality: { name: 'Block 4' } })
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(page.text()).toContain(nameThePlace)
    expect(page.text()).not.toContain(suggested)
    expect(page.get('#place').attributes('data-latitude')).toBeUndefined()
  })

  it('keeps the current suggestion when the suggestion request fails', async () => {
    const held = holdLocation()
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#use-location').trigger('click')
    await held.answer(0, { locality: { name: 'Block 4' } })
    await vi.waitFor(() => {
      expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    })
    await page.get('#use-location').trigger('click')
    await held.fail(1)
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    expect(page.text()).toContain(suggested)
    expect(page.text()).toContain(elsewhere)
    expect(page.get('#place').attributes('data-latitude')).toBe('3.1')
  })
})

function holdLocation() {
  const fixes: PositionCallback[] = []
  const calls: Array<{ resolve: (body: unknown) => void, reject: (error: Error) => void }> = []
  Object.defineProperty(navigator, 'geolocation', {
    configurable: true,
    value: {
      getCurrentPosition(success: PositionCallback) {
        fixes.push(success)
      }
    }
  })
  vi.stubGlobal('fetch', () => new Promise((resolve, reject) => {
    calls.push({
      resolve: (body) => resolve({ ok: true, json: async () => body }),
      reject
    })
  }))
  return {
    async answer(index: number, body: unknown) {
      const started = calls.length
      fixes[index]!({ coords: { latitude: 3.1, longitude: 101.7 } } as GeolocationPosition)
      await vi.waitFor(() => {
        expect(calls.length).toBe(started + 1)
      })
      calls[started]!.resolve(body)
    },
    async fail(index: number) {
      const started = calls.length
      fixes[index]!({ coords: { latitude: 3.1, longitude: 101.7 } } as GeolocationPosition)
      await vi.waitFor(() => {
        expect(calls.length).toBe(started + 1)
      })
      calls[started]!.reject(new Error('offline'))
    }
  }
}

describe('other people in the family', () => {
  it('continues with nobody else, and keeps named people across Back', async () => {
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    await page.get('button.primary').trigger('click')

    expect(page.text()).toContain('Other people in the family')
    expect(page.text()).toContain('Step 3 of 4')
    expect(page.text()).toContain('You can add other people, or continue if the head is the only person.')
    expect(page.text()).not.toContain('Head of the family')
    expect(page.find('#head-name').exists()).toBe(false)
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain('Step 4 of 4')
    expect(page.text()).not.toContain('Other people in the family')

    await goBack(page)
    expect(page.text()).toContain('Step 3 of 4')
    await clickLabel(page, 'Add a person')
    expect(page.text()).not.toContain('You can add other people, or continue if the head is the only person.')
    expect(page.text()).toContain('Person')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()

    await page.get('#member-0-name').setValue('   ')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain('Step 3 of 4')

    await page.get('#member-0-name').setValue('Sarah')
    await page.get('#member-0-age').setValue('15')
    await page.get('input[name="member-0-gender"][value="female"]').setValue(true)
    await page.get('#member-0-description').setValue('At school in the afternoon.')
    expect(Number(page.get('#member-0-description').attributes('rows'))).toBeGreaterThanOrEqual(3)
    expect(page.find('#member-0-job').exists()).toBe(false)
    await page.get('#member-0-education').setValue(true)
    await page.get('#member-0-working').setValue(true)
    await page.get('#member-0-job').setValue('Weekend stall')
    await page.get('#member-0-amount').setValue('800')
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await clickLabel(page, 'Add a person')
    expect(page.get('button.primary').attributes('disabled')).toBeDefined()
    await page.get('#member-1-name').setValue('Yusof')
    await page.get('input[name="member-1-gender"][value="male"]').setValue(true)
    expect(page.get<HTMLInputElement>('input[name="member-0-gender"][value="female"]').element.checked).toBe(true)
    expect(page.get<HTMLInputElement>('input[name="member-1-gender"][value="unspecified"]').element.checked).toBe(false)
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await page.get('#member-1-working').setValue(true)
    expect(page.find('#member-1-job').exists()).toBe(true)
    await page.get('#member-1-working').setValue(false)
    expect(page.find('#member-1-job').exists()).toBe(false)
    expect(page.find('#member-0-job').exists()).toBe(true)

    const remove = page.findAll('button').find((button) => button.text() === 'Remove')
    if (!remove) throw new Error('Remove is missing')
    await remove.trigger('click')

    const names = page.findAll('input[id$="-name"]')
    expect(names).toHaveLength(1)
    expect((names[0]!.element as HTMLInputElement).value).toBe('Yusof')
    expect(page.text()).not.toContain('Sarah')
    expect(page.get<HTMLInputElement>('input[name="member-0-gender"][value="male"]').element.checked).toBe(true)
    expect(page.get('button.primary').attributes('disabled')).toBeUndefined()

    await goBack(page)
    expect(page.get<HTMLInputElement>('#head-name').element.value).toBe('Aminah')
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    await page.get('button.primary').trigger('click')

    expect(page.text()).toContain('Step 3 of 4')
    expect(page.get<HTMLInputElement>('#member-0-name').element.value).toBe('Yusof')
    expect(page.text()).not.toContain('Sarah')
    expect(page.get<HTMLInputElement>('input[name="member-0-gender"][value="male"]').element.checked).toBe(true)
    expect(page.find('#member-0-job').exists()).toBe(false)
  })
})

async function clickLabel(page: Awaited<ReturnType<typeof mountSuspended>>, label: string) {
  const button = page.findAll('button').find((item) => item.text() === label)
  if (!button) throw new Error(`${label} is missing`)
  await button.trigger('click')
}

const caseIn = 'This case is in. No visit is set.'
const signUpSentence = 'Sign up with this email to see who has looked and whether a visit is set.'
const selfConsent = 'Submission means the family consents. That consent is confirmed at the verification visit.'
const behalfConsent = 'This case is valid and will be checked at a visit. It may not be enrolled unless the family consents then.'

type CapturedRequest = {
  url: string
  method: string
  authorization: string | null
  json: Record<string, unknown>
}

function stubEnrolment(status: number, body: unknown) {
  const calls: CapturedRequest[] = []
  let release = () => {}
  const gate = new Promise<void>((resolve) => {
    release = resolve
  })
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const headers = new Headers(init?.headers)
    calls.push({
      url: String(input),
      method: init?.method ?? 'GET',
      authorization: headers.get('Authorization'),
      json: JSON.parse(String(init?.body)) as Record<string, unknown>
    })
    await gate
    return {
      ok: status >= 200 && status < 300,
      status,
      json: async () => body
    }
  }))
  return { calls, release }
}

describe('notes for the community worker', () => {
  it('walks every stage and confirms the case, including the sign-up sentence', async () => {
    const { calls, release } = stubEnrolment(201, { id: 'case-1' })
    const page = await mountSuspended(IndexPage)

    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('#email').setValue('siti@example.com')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('+60 12-345 6789')

    await goBack(page)
    await page.get('#phone').setValue('012-345 6789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('012-345 6789')

    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    await page.get('#age').setValue('34')
    await page.get('input[value="female"]').setValue(true)
    await page.get('#description').setValue('Runs a food stall at night.')
    expect(Number(page.get('#description').attributes('rows'))).toBeGreaterThanOrEqual(3)
    await page.get('#education').setValue(true)
    await page.get('#working').setValue(true)
    await page.get('#job').setValue('Food stall')
    await page.get('#amount').setValue('800')
    await page.get('button.primary').trigger('click')

    await clickLabel(page, 'Add a person')
    expect(page.get<HTMLInputElement>('input[name="member-0-gender"][value="unspecified"]').element.checked).toBe(true)
    await page.get('#member-0-name').setValue('Sarah')
    await page.get('#member-0-age').setValue('15')
    await page.get('button.primary').trigger('click')

    expect(page.text()).toContain('Notes for the community worker')
    expect(page.text()).toContain('Step 4 of 4')
    expect(page.text()).toContain('Food')
    expect(page.text()).toContain('Clothing')
    expect(page.text()).toContain('School supplies')
    expect(page.text()).toContain('Help applying to a body (for example social security, welfare, or a tithe body)')
    expect(Number(page.get('#how-to-find').attributes('rows'))).toBeGreaterThanOrEqual(3)
    expect(Number(page.get('#other-help').attributes('rows'))).toBeGreaterThanOrEqual(3)
    expect(page.get('#submit').attributes('disabled')).toBeUndefined()

    await page.get('#how-to-find').setValue('Blue door beside the food stall.')
    await page.get('#other-help').setValue('A school uniform')
    await page.get('input[value="school_supplies"]').setValue(true)
    await page.get('input[value="food"]').setValue(true)
    await goBack(page)
    expect(page.text()).toContain('Step 3 of 4')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLTextAreaElement>('#how-to-find').element.value).toBe('Blue door beside the food stall.')
    expect(page.get<HTMLTextAreaElement>('#other-help').element.value).toBe('A school uniform')
    expect(page.get<HTMLInputElement>('input[value="food"]').element.checked).toBe(true)
    expect(page.get<HTMLInputElement>('input[value="clothing"]').element.checked).toBe(false)

    const pending = page.get('#submit').trigger('click')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    await page.get('#submit').trigger('click')
    expect(calls).toHaveLength(1)
    release()
    await pending
    await vi.waitFor(() => {
      expect(page.text()).toContain(caseIn)
    })

    const request = calls[0]!
    const url = new URL(request.url)
    expect(url.origin).toBe('http://localhost:3000')
    expect(url.pathname).toBe('/enrolments')
    expect(request.method).toBe('POST')
    expect(request.authorization).toBeNull()
    expect(request.json).toEqual({
      on_behalf: false,
      consent_text: selfConsent,
      enroler_contact: '012-345 6789',
      email: 'siti@example.com',
      place_name: 'Block 4',
      family_phone: '012-345 6789',
      how_to_find: 'Blue door beside the food stall.',
      help: [ 'food', 'school_supplies' ],
      other_help: 'A school uniform',
      members: [
        {
          role: 'head',
          name: 'Aminah',
          age: 34,
          gender: 'female',
          description: 'Runs a food stall at night.',
          in_education: true,
          working: true,
          job: 'Food stall',
          monthly_amount: 800
        },
        {
          role: 'member',
          name: 'Sarah',
          age: 15,
          gender: 'unspecified',
          description: '',
          in_education: false,
          working: false
        }
      ]
    })

    expect(page.text()).toContain(caseIn)
    expect(page.text()).toContain(signUpSentence)
    expect(page.text()).toContain('siti@example.com')
    expect(page.text()).not.toContain('Step 4 of 4')
    expect(page.find('#submit').exists()).toBe(false)
    vi.unstubAllGlobals()
  })

  it('omits the sign-up sentence when no email was entered', async () => {
    const { calls, release } = stubEnrolment(201, { id: 'case-2' })
    const page = await mountSuspended(IndexPage)
    await page.get('input[value="behalf"]').setValue(true)
    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('')
    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    await page.get('button.primary').trigger('click')
    await page.get('button.primary').trigger('click')
    const pending = page.get('#submit').trigger('click')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    release()
    await pending
    await vi.waitFor(() => {
      expect(page.text()).toContain(caseIn)
    })

    expect(calls[0]!.json).toMatchObject({
      on_behalf: true,
      consent_text: behalfConsent,
      family_phone: '',
      how_to_find: '',
      help: [],
      other_help: ''
    })
    expect(calls[0]!.json.members).toEqual([
      {
        role: 'head',
        name: 'Aminah',
        gender: 'unspecified',
        description: '',
        in_education: false,
        working: false
      }
    ])
    expect(calls[0]!.json).not.toHaveProperty('email')
    expect(calls[0]!.json).not.toHaveProperty('latitude')
    expect(calls[0]!.json).not.toHaveProperty('longitude')
    expect(page.text()).toContain(caseIn)
    expect(page.text()).not.toContain(signUpSentence)
    vi.unstubAllGlobals()
  })

  it('shows the API message and keeps stage 4 when the enrolment is rejected', async () => {
    const { calls, release } = stubEnrolment(422, {
      error: { code: 'VALIDATION_ERROR', message: 'Age is not an integer', details: { members: [ 'age is not an integer' ] } }
    })
    const page = await mountSuspended(IndexPage)
    await openFamily(page)
    await page.get('#place').setValue('Block 4')
    await page.get('#head-name').setValue('Aminah')
    await page.get('#age').setValue('about 800')
    await page.get('button.primary').trigger('click')
    await page.get('button.primary').trigger('click')
    await page.get('#how-to-find').setValue('Blue door')
    const pending = page.get('#submit').trigger('click')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    release()
    await pending
    await vi.waitFor(() => {
      expect(page.text()).toContain('Age is not an integer')
    })

    expect(calls[0]!.json.members).toEqual([
      expect.objectContaining({ role: 'head', name: 'Aminah', age: 'about 800' })
    ])
    expect(page.text()).toContain('Age is not an integer')
    expect(page.text()).toContain('Notes for the community worker')
    expect(page.text()).not.toContain(caseIn)
    expect(page.get<HTMLTextAreaElement>('#how-to-find').element.value).toBe('Blue door')
    await goBack(page)
    await goBack(page)
    expect(page.get<HTMLInputElement>('#age').element.value).toBe('about 800')
    expect(page.get<HTMLInputElement>('#head-name').element.value).toBe('Aminah')
    vi.unstubAllGlobals()
  })

  it('sends the device point only while the place is still the suggested name', async () => {
    const calls: CapturedRequest[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input)
      if (!init?.body) {
        return { ok: true, status: 200, json: async () => ({ locality: { name: 'Block 4' } }) }
      }
      calls.push({
        url,
        method: init.method ?? 'GET',
        authorization: new Headers(init.headers).get('Authorization'),
        json: JSON.parse(String(init.body)) as Record<string, unknown>
      })
      return { ok: true, status: 201, json: async () => ({ id: 'case-3' }) }
    }))
    Object.defineProperty(navigator, 'geolocation', {
      configurable: true,
      value: {
        getCurrentPosition(success: PositionCallback) {
          success({ coords: { latitude: 3.1, longitude: 101.7 } } as GeolocationPosition)
        }
      }
    })

    const suggested = await mountSuspended(IndexPage)
    await openFamily(suggested)
    await suggested.get('#use-location').trigger('click')
    await vi.waitFor(() => {
      expect(suggested.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    })
    await suggested.get('#head-name').setValue('Aminah')
    await suggested.get('button.primary').trigger('click')
    await suggested.get('button.primary').trigger('click')
    await suggested.get('#submit').trigger('click')
    await vi.waitFor(() => expect(calls).toHaveLength(1))
    expect(calls[0]!.json.latitude).toBe(3.1)
    expect(calls[0]!.json.longitude).toBe(101.7)

    const renamed = await mountSuspended(IndexPage)
    await openFamily(renamed)
    await renamed.get('#use-location').trigger('click')
    await vi.waitFor(() => {
      expect(renamed.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    })
    await renamed.get('#place').setValue('Somewhere else')
    await renamed.get('#head-name').setValue('Aminah')
    await renamed.get('button.primary').trigger('click')
    await renamed.get('button.primary').trigger('click')
    await renamed.get('#submit').trigger('click')
    await vi.waitFor(() => expect(calls).toHaveLength(2))
    expect(calls[1]!.json).not.toHaveProperty('latitude')
    expect(calls[1]!.json).not.toHaveProperty('longitude')
    expect(calls[1]!.json.place_name).toBe('Somewhere else')
    vi.unstubAllGlobals()
  })
})
