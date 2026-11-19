const weekMs = 7 * 24 * 60 * 60 * 1000

export function formatVisit(iso: string, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(new Date(iso))
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value ?? ''
  return `${value('day')} ${value('month')} ${value('year')} at ${value('hour')}:${value('minute')}`
}

export function visitIsLate(submittedAt: string, visitAt: string): boolean {
  return new Date(visitAt).getTime() > new Date(submittedAt).getTime() + weekMs
}

export function toLocalInput(iso: string): string {
  const date = new Date(iso)
  const pad = (value: number) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

export function toUtcInstant(localValue: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(localValue)) return null
  const parsed = new Date(localValue)
  if (Number.isNaN(parsed.getTime())) return null
  const [datePart, timePart] = localValue.split('T')
  const [year, month, day] = datePart!.split('-').map(Number)
  const [hour, minute] = timePart!.split(':').map(Number)
  if (parsed.getFullYear() !== year || parsed.getMonth() + 1 !== month || parsed.getDate() !== day) return null
  if (parsed.getHours() !== hour || parsed.getMinutes() !== minute) return null
  return parsed.toISOString().replace(/\.\d{3}Z$/, 'Z')
}
