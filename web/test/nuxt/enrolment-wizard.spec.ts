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
