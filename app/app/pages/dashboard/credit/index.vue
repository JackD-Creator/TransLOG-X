<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const stats = [
  { label: 'Credit Limit Total',  value: 'Rp 2,5M',  icon: 'i-lucide-landmark',      color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Limit Terpakai',      value: 'Rp 890Jt',  icon: 'i-lucide-credit-card',   color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Skor Risiko',         value: 'A+ / Low',  icon: 'i-lucide-shield',         color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Alert Risiko Aktif',  value: '2',         icon: 'i-lucide-alert-triangle', color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
]
const suppliers = ref([
  { nama: 'PT. Kimia Farma',       limit: 500000000, terpakai: 125000000, skor: 'A',  risiko: 'low',    payment_term: 'NET 30' },
  { nama: 'PT. Enseval Medika',    limit: 300000000, terpakai: 180000000, skor: 'B+', risiko: 'medium', payment_term: 'NET 45' },
  { nama: 'PT. Rajawali Nusindo',  limit: 250000000, terpakai: 210000000, skor: 'B',  risiko: 'medium', payment_term: 'NET 30' },
  { nama: 'PT. Tempo Scan Pacific',limit: 400000000, terpakai: 95000000,  skor: 'A+', risiko: 'low',    payment_term: 'NET 60' },
  { nama: 'PT. Anugrah Argon',     limit: 200000000, terpakai: 195000000, skor: 'C',  risiko: 'high',   payment_term: 'NET 14' },
])
function riskBadge(r: string) {
  const m: Record<string,string> = { low: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400', medium: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400', high: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400' }
  return m[r] ?? 'bg-gray-100 text-gray-600'
}
function riskLabel(r: string) { return { low: 'Rendah', medium: 'Sedang', high: 'Tinggi' }[r] ?? r }
function usedPct(terpakai: number, limit: number) { return Math.round((terpakai / limit) * 100) }
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Kredit & Manajemen Risiko</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Credit limit supplier, skoring risiko & monitoring eksposur</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Supplier</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color, 'text-lg']" /></div>
        <div><p class="text-lg font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Credit Exposure per Supplier</h2>
      </div>
      <div class="divide-y divide-gray-100 dark:divide-gray-800">
        <div v-for="s in suppliers" :key="s.nama" class="px-5 py-4 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                <span class="text-sm font-bold text-gray-600 dark:text-gray-300">{{ s.skor }}</span>
              </div>
              <div>
                <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ s.nama }}</p>
                <p class="text-xs text-gray-400">{{ s.payment_term }}</p>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', riskBadge(s.risiko)]">{{ riskLabel(s.risiko) }}</span>
              <span class="text-xs text-gray-500">{{ usedPct(s.terpakai, s.limit) }}%</span>
            </div>
          </div>
          <div class="w-full h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
            <div
              :class="['h-full rounded-full transition-all', usedPct(s.terpakai, s.limit) >= 90 ? 'bg-red-500' : usedPct(s.terpakai, s.limit) >= 70 ? 'bg-amber-500' : 'bg-emerald-500']"
              :style="`width:${usedPct(s.terpakai, s.limit)}%`"
            />
          </div>
          <div class="flex justify-between text-xs text-gray-400 mt-1">
            <span>Terpakai: {{ rp(s.terpakai) }}</span>
            <span>Limit: {{ rp(s.limit) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
