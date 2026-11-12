import { describe, expect, it } from 'vitest'
import { phoneMatches } from '../../utils/phone'

describe('phoneMatches', () => {
  it('accepts 8 to 15 digits, an optional leading plus, and spaces, hyphens, dots, and parentheses', () => {
    expect(phoneMatches('01234567')).toBe(true)
    expect(phoneMatches('012345678901234')).toBe(true)
    expect(phoneMatches('+601234567')).toBe(true)
    expect(phoneMatches('+601234567890123')).toBe(true)
    expect(phoneMatches('(012) 345.6789')).toBe(true)
    expect(phoneMatches('012-345 6789')).toBe(true)

    expect(phoneMatches('0123456')).toBe(false)
    expect(phoneMatches('0123456789012345')).toBe(false)
    expect(phoneMatches('01+23456789')).toBe(false)
    expect(phoneMatches('0123\t456789')).toBe(false)
    expect(phoneMatches('0123\n456789')).toBe(false)
  })
})
