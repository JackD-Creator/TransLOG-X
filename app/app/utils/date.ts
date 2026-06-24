export function fmtDate(d: string | null | undefined): string {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

export function fmtDateLong(d: string | null | undefined): string {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })
}

export function daysDiff(d: string): number {
  const today = new Date().toISOString().slice(0, 10)
  return Math.round((new Date(d).getTime() - new Date(today).getTime()) / 86400000)
}

export function isOverdue(d: string | null): boolean {
  if (!d) return false
  return d < new Date().toISOString().slice(0, 10)
}
