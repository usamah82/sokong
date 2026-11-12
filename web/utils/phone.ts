export function phoneMatches(value: string) {
  return /^\+?[0-9]{8,15}$/.test(value.replace(/[ \-.()]/g, ''))
}
