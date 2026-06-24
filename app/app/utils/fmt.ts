/**
 * Format Rupiah — STANDAR SELURUH APLIKASI
 * Selalu tampilkan angka penuh, TIDAK disingkat (jt/M/T)
 * Contoh: Rp 5.400.000 — bukan "Rp 5,4 jt"
 */
export function fmtRp(n: number | null | undefined): string {
  if (n == null || !isFinite(n) || isNaN(n)) return 'Rp 0'
  const abs = Math.abs(Math.round(n))
  const formatted = abs.toLocaleString('id-ID')
  return n < 0 ? `-Rp ${formatted}` : `Rp ${formatted}`
}

/**
 * Format angka biasa (tanpa Rp)
 */
export function fmtNum(n: number | null | undefined): string {
  if (n == null || !isFinite(n)) return '0'
  return Math.round(n).toLocaleString('id-ID')
}

/**
 * Format persentase
 */
export function fmtPct(n: number | null | undefined, dec = 1): string {
  if (n == null || !isFinite(n)) return '0%'
  return `${n.toFixed(dec)}%`
}
