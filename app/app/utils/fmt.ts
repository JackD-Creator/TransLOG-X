/** Format Rupiah — standar seluruh dashboard
 *  >= 1 T  → "Rp 1,50 T"
 *  >= 1 M  → "Rp 3,00 M"   (Miliar)
 *  >= 1 jt → "Rp 455 jt"   (Juta)
 *  < 1 jt  → "Rp 5.000"    (id-ID locale)
 */
export function fmtRp(n: number): string {
  if (!isFinite(n) || isNaN(n)) return 'Rp 0'
  const a = Math.abs(n)
  const s = n < 0 ? '-' : ''
  if (a >= 1e12) return `${s}Rp ${(a / 1e12).toFixed(2)} T`
  if (a >= 1e9)  return `${s}Rp ${(a / 1e9).toFixed(2)} M`
  if (a >= 1e6)  return `${s}Rp ${Math.round(a / 1e6)} jt`
  return `${s}Rp ${Math.round(a).toLocaleString('id-ID')}`
}

export function fmtNum(n: number): string {
  return Math.round(n).toLocaleString('id-ID')
}

export function fmtPct(n: number, dec = 1): string {
  return `${n.toFixed(dec)}%`
}
