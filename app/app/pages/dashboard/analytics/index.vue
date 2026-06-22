<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const kpis = [
  { label: 'Inventory Turnover',   value: '8.4x',    trend: '+0.3',  up: true,  icon: 'i-lucide-refresh-cw',    color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Fill Rate',            value: '96.2%',   trend: '+1.1%', up: true,  icon: 'i-lucide-package-check', color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Avg. Lead Time',       value: '4.2 hari',trend: '-0.8',  up: true,  icon: 'i-lucide-clock',         color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' },
  { label: 'Spend Variance',       value: '-2.3%',   trend: '-2.3%', up: false, icon: 'i-lucide-trending-down', color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
]
const topItems = ref([
  { nama: 'Paracetamol 500mg', kategori: 'Obat', qty_keluar: 4850, nilai: 4122500,  pct: 100 },
  { nama: 'Amoxicillin 500mg', kategori: 'Obat', qty_keluar: 2100, nilai: 4410000,  pct: 90 },
  { nama: 'Spuit 3cc',         kategori: 'Alkes',qty_keluar: 8500, nilai: 12750000, pct: 85 },
  { nama: 'Infus Set Dewasa',  kategori: 'Alkes',qty_keluar: 1200, nilai: 10200000, pct: 72 },
  { nama: 'Omeprazole 20mg',   kategori: 'Obat', qty_keluar: 950,  nilai: 3040000,  pct: 60 },
])
const spendByKategori = ref([
  { kategori: 'Obat',      pct: 58, nilai: 'Rp 2,9M',  color: 'bg-blue-500' },
  { kategori: 'Alkes',     pct: 28, nilai: 'Rp 1,4M',  color: 'bg-purple-500' },
  { kategori: 'BMHP',      pct: 9,  nilai: 'Rp 450Jt', color: 'bg-amber-500' },
  { kategori: 'Reagensia', pct: 5,  nilai: 'Rp 250Jt', color: 'bg-emerald-500' },
])
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Analytics & Business Intelligence</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">KPI logistik, spend analysis & laporan manajemen</p>
      </div>
      <div class="flex gap-2">
        <UButton icon="i-lucide-download" color="neutral" variant="outline" size="sm">Export PDF</UButton>
        <UButton icon="i-lucide-calendar" color="neutral" variant="outline" size="sm">Juni 2026</UButton>
      </div>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="k in kpis" :key="k.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4">
        <div class="flex items-center justify-between mb-3">
          <div :class="[k.bg,'w-9 h-9 rounded-lg flex items-center justify-center']"><UIcon :name="k.icon" :class="[k.color,'text-base']" /></div>
          <span :class="['text-xs font-semibold', k.up?'text-emerald-600 dark:text-emerald-400':'text-red-600 dark:text-red-400']">{{ k.trend }}</span>
        </div>
        <p class="text-xl font-bold text-gray-900 dark:text-white">{{ k.value }}</p>
        <p class="text-xs text-gray-400 mt-0.5">{{ k.label }}</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <!-- Top items -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Top 5 Item by Volume (Bulan Ini)</h2></div>
        <div class="divide-y divide-gray-100 dark:divide-gray-800">
          <div v-for="(item, i) in topItems" :key="item.nama" class="px-5 py-3">
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2">
                <span class="text-xs font-bold text-gray-400 w-4">{{ i+1 }}</span>
                <div>
                  <p class="text-sm font-medium text-gray-900 dark:text-white">{{ item.nama }}</p>
                  <p class="text-xs text-gray-400">{{ item.kategori }} · {{ item.qty_keluar.toLocaleString('id-ID') }} unit</p>
                </div>
              </div>
              <p class="text-xs font-semibold text-gray-700 dark:text-gray-300">{{ rp(item.nilai) }}</p>
            </div>
            <div class="w-full h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
              <div class="h-full bg-red-500 rounded-full" :style="`width:${item.pct}%`" />
            </div>
          </div>
        </div>
      </div>

      <!-- Spend by kategori -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Spend by Kategori (Bulan Ini)</h2></div>
        <div class="p-5 space-y-4">
          <div v-for="s in spendByKategori" :key="s.kategori">
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2">
                <div :class="['w-2.5 h-2.5 rounded-full', s.color]" />
                <span class="text-sm text-gray-700 dark:text-gray-300">{{ s.kategori }}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-xs text-gray-400">{{ s.nilai }}</span>
                <span class="text-xs font-bold text-gray-700 dark:text-gray-300 w-8 text-right">{{ s.pct }}%</span>
              </div>
            </div>
            <div class="w-full h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
              <div :class="['h-full rounded-full', s.color]" :style="`width:${s.pct}%`" />
            </div>
          </div>

          <div class="pt-4 border-t border-gray-100 dark:border-gray-800">
            <div class="grid grid-cols-2 gap-3">
              <div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3 text-center">
                <p class="text-lg font-bold text-gray-900 dark:text-white">Rp 5,0M</p>
                <p class="text-xs text-gray-400">Total Spend</p>
              </div>
              <div class="bg-gray-50 dark:bg-gray-800 rounded-xl p-3 text-center">
                <p class="text-lg font-bold text-emerald-600 dark:text-emerald-400">-2.3%</p>
                <p class="text-xs text-gray-400">vs Bulan Lalu</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
