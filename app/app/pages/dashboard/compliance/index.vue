<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const items = ref([
  { regulasi: 'Permenkes No. 3/2015 — Narkotika & Psikotropika', status: 'compliant',     last_check: '2026-06-01', next_check: '2026-09-01', catatan: 'Laporan bulanan terkirim' },
  { regulasi: 'CDOB 2020 — Cara Distribusi Obat yang Baik',       status: 'compliant',     last_check: '2026-05-15', next_check: '2026-08-15', catatan: 'Sertifikasi aktif' },
  { regulasi: 'BPOM — Izin PBF & Apotek',                         status: 'warning',       last_check: '2026-03-01', next_check: '2026-09-01', catatan: 'Izin perlu diperpanjang' },
  { regulasi: 'Akreditasi SNARS RS',                               status: 'compliant',     last_check: '2025-12-01', next_check: '2028-12-01', catatan: 'Akreditasi Paripurna' },
  { regulasi: 'Perpajakan — Faktur Pajak & e-Faktur',             status: 'compliant',     last_check: '2026-06-20', next_check: '2026-07-20', catatan: 'Pelaporan SPT tepat waktu' },
  { regulasi: 'UU No. 27/2022 — Perlindungan Data Pribadi',       status: 'in_progress',   last_check: '2026-06-01', next_check: '2026-12-01', catatan: 'DPA dalam proses penunjukan' },
])
function badge(s: string) {
  const m: Record<string,string> = { compliant: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400', warning: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400', non_compliant: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400', in_progress: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400' }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
function bl(s: string) { return { compliant: 'Compliant', warning: 'Perlu Perhatian', non_compliant: 'Tidak Sesuai', in_progress: 'Dalam Proses' }[s] ?? s }
function icon(s: string) { return { compliant: 'i-lucide-check-circle', warning: 'i-lucide-alert-triangle', non_compliant: 'i-lucide-x-circle', in_progress: 'i-lucide-clock' }[s] ?? 'i-lucide-circle' }
const compliantCount = computed(() => items.value.filter(i => i.status === 'compliant').length)
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Kepatuhan Regulasi</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Monitoring regulasi, perizinan & audit kepatuhan</p>
      </div>
      <div class="flex items-center gap-2 bg-emerald-50 dark:bg-emerald-950 border border-emerald-200 dark:border-emerald-800 rounded-xl px-4 py-2">
        <UIcon name="i-lucide-shield-check" class="text-emerald-600 dark:text-emerald-400 text-lg" />
        <span class="text-sm font-bold text-emerald-700 dark:text-emerald-400">{{ compliantCount }}/{{ items.length }} Compliant</span>
      </div>
    </div>
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Status Kepatuhan Regulasi</h2>
      </div>
      <div class="divide-y divide-gray-100 dark:divide-gray-800">
        <div v-for="item in items" :key="item.regulasi" class="px-5 py-4 flex items-start gap-4 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
          <div class="mt-0.5 flex-shrink-0">
            <UIcon :name="icon(item.status)" :class="[
              'text-xl',
              item.status==='compliant'?'text-emerald-500':item.status==='warning'?'text-amber-500':item.status==='in_progress'?'text-blue-500':'text-red-500'
            ]" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900 dark:text-white">{{ item.regulasi }}</p>
            <p class="text-xs text-gray-400 mt-0.5">{{ item.catatan }}</p>
            <div class="flex gap-4 mt-1.5 text-xs text-gray-400">
              <span>Cek terakhir: {{ item.last_check }}</span>
              <span>Cek berikutnya: {{ item.next_check }}</span>
            </div>
          </div>
          <span :class="['px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0', badge(item.status)]">{{ bl(item.status) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
