import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { mountSuspended } from '@nuxt/test-utils/runtime'
import { describe, expect, it } from 'vitest'
import IndexPage from '../../pages/index.vue'

const locale = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../i18n/locales/en.json'), 'utf8')
) as { wizard: { enroler: { self: string } } }

describe('shell', () => {
  it('renders the English sentence from the locale file', async () => {
    const page = await mountSuspended(IndexPage)
    expect(page.text()).toContain(locale.wizard.enroler.self)
  })
})
