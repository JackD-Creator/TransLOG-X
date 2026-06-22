<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const activeTab = ref('klaim')
const tabs = [
  { key: 'klaim',  label: 'Klaim BPJS',      icon: 'i-lucide-stethoscope' },
  { key: 'rcm',    label: 'RCM & Verifikasi', icon: 'i-lucide-shield-check' },
  { key: 'bridging',label: 'Bridging System', icon: 'i-lucide-link' },
]
const stats = [
  { label: 'Klaim Bulan Ini',      value: '1.284',    icon: 'i-lucide-file-medical',   color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Nilai Klaim',          value: 'Rp 4,87M', icon: 'i-lucide-banknote',       color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Pending Verifikasi',   value: '87',        icon: 'i-lucide-clock',          color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Ditolak / Dispute',    value: '12',        icon: 'i-lucide-x-circle',       color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
]
const klaimList = ref([
  { id: 'KLM-2026-1284', pasien: 'Budi Santoso',    no_kartu: '0001234567890', diagnosa: 'J06.9 ISPA', tipe: 'Rawat Jalan', nominal: 185000,  status: 'submitted', tgl: '2026-06-22' },
  { id: 'KLM-2026-1283', pasien: 'Siti Rahayu',     no_kartu: '0001234567891', diagnosa: 'I10 Hipertensi', tipe: 'Rawat Jalan', nominal: 210000, status: 'verified', tgl: '2026-06-22' },
  { id: 'KLM-2026-1282', pasien: 'Ahmad Fauzi',     no_kartu: '0001234567892', diagnosa: 'E11 DM Tipe 2', tipe: 'Rawat Inap', nominal: 4500000, status: 'paid',     tgl: '2026-06-21' },
  { id: 'KLM-2026-1281', pasien: 'Dewi Lestari',    no_kartu: '0001234567893', diagnosa: 'K29.7 Gastritis', tipe: 'Rawat Jalan', nominal: 175000, status: 'rejected', tgl: '2026-06-21' },
  { id: 'KLM-2026-1280', pasien: 'Eko Prasetyo',    no_kartu: '0001234567894', diagnosa: 'M54.5 LBP',   tipe: 'Rawat Jalan', nominal: 195000,  status: 'submitted', tgl: '2026-06-20' },
])
function badge(s: string) {
  const m: Record<string,string> = {
    submitted: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400',
    verified:  'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-400',
    paid:      'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
    rejected:  'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400',
    pending:   'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400',
    connected: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
    error:     'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400',
  }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
function bl(s: string) {
  const m: Record<string,string> = { submitted: 'Diajukan', verified: 'Terverifikasi', paid: 'Dibayar', rejected: 'Ditolak', pending: 'Pending', connected: 'Terhubung', error: 'Error' }
  return m[s] ?? s
}
const bridgingStatus = ref([
  { sistem: 'VCLAIM BPJS',    versi: 'v3.0', status: 'connected', last_sync: '2026-06-22 08:00' },
  { sistem: 'SATU SEHAT',     versi: 'v2.1', status: 'connected', last_sync: '2026-06-22 07:55' },
  { sistem: 'INACBG',         versi: 'v5.3', status: 'connected', last_sync: '2026-06-22 06:00' },
  { sistem: 'SIM RS Internal',versi: 'v1.8', status: 'error',     last_sync: '2026-06-21 22:10' },
])
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">BPJS & Revenue Cycle Management</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Klaim, verifikasi, bridging & rekonsiliasi BPJS</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Input Klaim</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color, 'text-lg']" /></div>
        <div><p class="text-lg font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="flex border-b border-gray-200 dark:border-gray-800">
        <button v-for="tab in tabs" :key="tab.key" class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab===tab.key?'border-red-600 text-red-600 dark:text-red-400':'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700'"
          @click="activeTab=tab.key"><UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}</button>
      </div>
      <div v-if="activeTab==='klaim'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">ID Klaim</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Pasien</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. Kartu</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Diagnosa</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tipe</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="k in klaimList" :key="k.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ k.id }}</td>
              <td class="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">{{ k.pasien }}</td>
              <td class="px-4 py-3 font-mono text-xs text-gray-500">{{ k.no_kartu }}</td>
              <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">{{ k.diagnosa }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ k.tipe }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-gray-900 dark:text-white">Rp {{ k.nominal.toLocaleString('id-ID') }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(k.status)]">{{ bl(k.status) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="activeTab==='rcm'" class="p-8 text-center text-gray-400">
        <UIcon name="i-lucide-shield-check" class="text-4xl mb-3 block mx-auto text-gray-300 dark:text-gray-700"/>
        <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Dashboard RCM & Verifikasi Koding</p>
        <p class="text-xs text-gray-400 mt-1">Integrasi dengan INA-CBG & VCLAIM sedang dikonfigurasi</p>
      </div>
      <div v-if="activeTab==='bridging'" class="p-5">
        <div class="space-y-3">
          <div v-for="b in bridgingStatus" :key="b.sistem" class="flex items-center justify-between p-4 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-center gap-3">
              <div :class="['w-2.5 h-2.5 rounded-full flex-shrink-0', b.status==='connected'?'bg-emerald-500':'bg-red-500']"/>
              <div>
                <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ b.sistem }}</p>
                <p class="text-xs text-gray-400">Versi {{ b.versi }} · Last sync: {{ b.last_sync }}</p>
              </div>
            </div>
            <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(b.status)]">{{ bl(b.status) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
