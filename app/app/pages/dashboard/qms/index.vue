<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const stats = [
  { label: 'Insiden Bulan Ini',    value: '3',   icon: 'i-lucide-alert-triangle',  color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
  { label: 'Audit Terjadwal',      value: '2',   icon: 'i-lucide-clipboard-check', color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Item Expiring 30hr',   value: '12',  icon: 'i-lucide-calendar-x',      color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Recall Aktif',         value: '0',   icon: 'i-lucide-rotate-ccw',      color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
]
const insiden = ref([
  { id: 'INC-2026-003', tanggal: '2026-06-20', tipe: 'Medication Error', lokasi: 'Poli Umum',    severity: 'minor',    status: 'investigating' },
  { id: 'INC-2026-002', tanggal: '2026-06-15', tipe: 'Near Miss',       lokasi: 'IGD',           severity: 'moderate', status: 'closed' },
  { id: 'INC-2026-001', tanggal: '2026-06-10', tipe: 'Stok Habis Darurat',lokasi:'Farmasi',      severity: 'minor',    status: 'closed' },
])
const expiring = ref([
  { nama: 'Insulin Novomix 30', batch: 'BTH-001', exp: '2026-07-15', stok: 24,  lokasi: 'GD-A/R02' },
  { nama: 'Epinephrine 1mg/mL', batch: 'BTH-012', exp: '2026-07-20', stok: 10,  lokasi: 'GD-A/R01' },
  { nama: 'Midazolam 5mg/mL',   batch: 'BTH-008', exp: '2026-07-22', stok: 5,   lokasi: 'GD-A/R03' },
])
function sevBadge(s: string) {
  const m: Record<string,string> = { minor: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400', moderate: 'bg-orange-100 text-orange-700 dark:bg-orange-900/40 dark:text-orange-400', major: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400' }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
function stBadge(s: string) {
  const m: Record<string,string> = { investigating: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400', closed: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400' }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Quality Management System</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Insiden, audit mutu, expiry & product recall</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Lapor Insiden</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Insiden & Near Miss</h2></div>
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">ID</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tipe</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Severity</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="i in insiden" :key="i.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ i.id }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ i.tipe }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', sevBadge(i.severity)]">{{ i.severity }}</span></td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', stBadge(i.status)]">{{ i.status === 'investigating' ? 'Investigasi' : 'Selesai' }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex justify-between items-center">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Mendekati Expired (30 hari)</h2>
          <span class="text-xs text-amber-600 font-medium">{{ expiring.length }} item</span>
        </div>
        <div class="divide-y divide-gray-100 dark:divide-gray-800">
          <div v-for="e in expiring" :key="e.batch" class="px-5 py-4">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-sm font-medium text-gray-900 dark:text-white">{{ e.nama }}</p>
                <p class="text-xs text-gray-400 mt-0.5">Batch: {{ e.batch }} · {{ e.lokasi }}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-semibold text-red-600 dark:text-red-400">Exp: {{ e.exp }}</p>
                <p class="text-xs text-gray-400">Stok: {{ e.stok }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
