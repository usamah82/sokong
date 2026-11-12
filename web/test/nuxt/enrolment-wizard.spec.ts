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

    await page.get('button').trigger('click')
    expect(page.text()).toContain('Step 1 of 4')
    expect(page.get<HTMLInputElement>('#phone').element.value).toBe('012-345 6789')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('')

    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('#email').setValue('siti@example.com')
    await page.get('button.primary').trigger('click')
    expect(page.text()).toContain(copy.family.title)

    await page.get('button').trigger('click')
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

    await page.get('button').trigger('click')
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

    await page.get('button.secondary').trigger('click')
    expect(page.get<HTMLInputElement>('#place').element.value).toBe('Block 4')
    expect(page.get<HTMLInputElement>('#head-name').element.value).toBe('Aminah')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60123456789')

    await page.get('button.secondary').trigger('click')
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

    await page.get('button.secondary').trigger('click')
    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('+60 12-345 6789')

    await page.get('#family-phone').setValue('60123456789')
    await page.get('button.secondary').trigger('click')
    await page.get('#phone').setValue('0123456789')
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('60123456789')

    await page.get('#family-phone').setValue('')
    await page.get('button.secondary').trigger('click')
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
    await page.get('button.secondary').trigger('click')
    await page.get('input[value="behalf"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('')

    await page.get('button.secondary').trigger('click')
    await page.get('input[value="self"]').setValue(true)
    await page.get('button.primary').trigger('click')
    expect(page.get<HTMLInputElement>('#family-phone').element.value).toBe('+60 12-345 6789')

    await page.get('#family-phone').setValue('60111111111')
    await page.get('button.secondary').trigger('click')
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
    await page.get('button.secondary').trigger('click')
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
