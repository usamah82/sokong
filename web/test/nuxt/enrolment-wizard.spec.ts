import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it } from 'vitest'
import IndexPage from '../../pages/index.vue'

const copy = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../i18n/locales/en.json'), 'utf8')
).wizard.enroler as {
  self: string
  behalf: string
  consentSelf: string
  consentBehalf: string
  phoneError: string
}

describe('who is enrolling', () => {
  it('starts on this family, swaps the consent sentence, and keeps a valid phone across Back', async () => {
    const page = await mountSuspended(IndexPage)

    expect(page.get('input[value="self"]').element.checked).toBe(true)
    expect(page.text()).toContain(copy.self)
    expect(page.text()).toContain(copy.consentSelf)
    expect(page.get('button').attributes('disabled')).toBeDefined()

    await page.get('input[value="behalf"]').setValue(true)
    expect(page.text()).toContain(copy.consentBehalf)
    expect(page.text()).not.toContain(copy.consentSelf)

    await page.get('#phone').setValue('Mary at the shop')
    expect(page.text()).toContain(copy.phoneError)
    expect(page.get('button').attributes('disabled')).toBeDefined()

    await page.get('#phone').setValue('+60 12-345 6789')
    await page.get('#email').setValue('siti@example.com')
    expect(page.text()).not.toContain(copy.phoneError)

    await page.get('form').trigger('submit')
    expect(page.text()).toContain('The family')

    await page.get('button').trigger('click')
    expect(page.get<HTMLInputElement>('#phone').element.value).toBe('+60 12-345 6789')
    expect(page.get<HTMLInputElement>('#email').element.value).toBe('siti@example.com')
    expect(page.get('input[value="behalf"]').element.checked).toBe(true)
    expect(page.text()).toContain(copy.consentBehalf)
  })
})
