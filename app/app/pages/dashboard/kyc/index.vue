<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const stats = [
  { label: 'Mitra Terverifikasi', value: '28',  icon: 'i-lucide-badge-check',    color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'KYC Pending',         value: '4',   icon: 'i-lucide-clock',           color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Alert Fraud',         value: '1',   icon: 'i-lucide-shield-alert',    color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
  { label: 'Blacklist',           value: '2',   icon: 'i-lucide-ban',             color: 'text-gray-600',   bg: 'bg-gray-100 dark:bg-gray-800' },
]
const mitra = ref([
  { nama: 'PT. Kimia Farma',       tipe: 'Distributor PBF', kyc_level: 'Enhanced', skor: 95, status: 'verified',   last_review: '2026-03-01' },
  { nama: 'PT. Enseval Medika',    tipe: 'Distributor PBF', kyc_level: 'Standard', skor: 88, status: 'verified',   last_review: '2026-04-15' },
  { nama: 'PT. Anugrah Argon',     tipe: 'Distributor PBF', kyc_level: 'Standard', skor: 62, status: 'review',     last_review: '2026-01-10' },
  { nama: 'CV. Medika Sejahtera',  tipe: 'Supplier Lokal',  kyc_level: 'Basic',    skor: 45, status: 'pending',    last_review: '-' },
  { nama: 'PT. Farma Abadi',       tipe: 'Supplier Lokal',  kyc_level: 'Basic',    skor: 20, status: 'blacklisted',last_review: '2025-11-01' },
])
function badge(s: string) {
  const m: Record<string,string> = { verified: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400', review: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400', pending: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400', blacklisted: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400' }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
function bl(s: string) { return { verified: 'Terverifikasi', review: 'Review Ulang', pending: 'Pending KYC', blacklisted: 'Blacklist' }[s] ?? s }
function scoreColor(n: number) { return n >= 80 ? 'text-emerald-600 dark:text-emerald-400' : n >= 60 ? 'text-amber-600 dark:text-amber-400' : 'text-red-600 dark:text-red-400' }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">KYC & Deteksi Fraud</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Know Your Counterparty, skoring risiko & blacklist monitoring</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Mitra KYC</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Status KYC Mitra</h2></div>
      <table class="w-full text-sm">
        <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
          <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nama Mitra</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tipe</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">KYC Level</th>
          <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Skor</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Last Review</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
          <th class="px-4 py-3" />
        </tr></thead>
        <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
          <tr v-for="m in mitra" :key="m.nama" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
            <td class="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">{{ m.nama }}</td>
            <td class="px-4 py-3 text-xs text-gray-500">{{ m.tipe }}</td>
            <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">{{ m.kyc_level }}</td>
            <td class="px-4 py-3 text-right font-bold text-sm" :class="scoreColor(m.skor)">{{ m.skor }}</td>
            <td class="px-4 py-3 text-xs text-gray-500">{{ m.last_review }}</td>
            <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(m.status)]">{{ bl(m.status) }}</span></td>
            <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
