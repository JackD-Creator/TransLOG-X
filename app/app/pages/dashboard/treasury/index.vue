<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const stats = [
  { label: 'Saldo Bank Total',   value: 'Rp 3,42M', icon: 'i-lucide-landmark',    color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Cash Flow Minggu Ini',value: '+Rp 287Jt',icon: 'i-lucide-trending-up', color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Rekening Aktif',     value: '4',        icon: 'i-lucide-credit-card', color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' },
  { label: 'Transaksi Hari Ini', value: '23',       icon: 'i-lucide-arrow-right-left',color:'text-amber-600',bg:'bg-amber-50 dark:bg-amber-950' },
]
const accounts = ref([
  { bank: 'Bank Mandiri',    no_rek: '1230004567890', jenis: 'Giro',      saldo: 1850000000, status: 'active' },
  { bank: 'BRI',             no_rek: '0320012345678', jenis: 'Giro',      saldo: 980000000,  status: 'active' },
  { bank: 'BNI',             no_rek: '0889012345678', jenis: 'Tabungan',  saldo: 420000000,  status: 'active' },
  { bank: 'Bank Syariah Ind',no_rek: '7120034567890', jenis: 'Giro Wadi\'ah', saldo: 170000000, status: 'active' },
])
const cashflow = ref([
  { tanggal: '2026-06-22', keterangan: 'Pembayaran klaim BPJS',          jenis: 'in',  nominal: 487500000 },
  { tanggal: '2026-06-22', keterangan: 'Pembayaran PO Kimia Farma',       jenis: 'out', nominal: 12500000 },
  { tanggal: '2026-06-21', keterangan: 'Pembayaran PO Enseval',           jenis: 'out', nominal: 7800000 },
  { tanggal: '2026-06-21', keterangan: 'Penerimaan SCF cair Bank Mandiri',jenis: 'in',  nominal: 390000000 },
  { tanggal: '2026-06-20', keterangan: 'Biaya operasional RS',            jenis: 'out', nominal: 45000000 },
  { tanggal: '2026-06-20', keterangan: 'Pembayaran gaji karyawan',        jenis: 'out', nominal: 520000000 },
])
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Treasury & Cash Management</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Manajemen rekening, cash flow & rekonsiliasi bank</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Rekening</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-lg font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Rekening Bank</h2></div>
        <div class="divide-y divide-gray-100 dark:divide-gray-800">
          <div v-for="a in accounts" :key="a.no_rek" class="px-5 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-blue-50 dark:bg-blue-950 flex items-center justify-center flex-shrink-0">
                <UIcon name="i-lucide-landmark" class="text-blue-600 dark:text-blue-400 text-lg" />
              </div>
              <div>
                <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ a.bank }}</p>
                <p class="text-xs text-gray-400 font-mono">{{ a.no_rek }} · {{ a.jenis }}</p>
              </div>
            </div>
            <p class="text-sm font-bold text-gray-900 dark:text-white">{{ rp(a.saldo) }}</p>
          </div>
        </div>
      </div>
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800"><h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Mutasi Terbaru</h2></div>
        <div class="divide-y divide-gray-100 dark:divide-gray-800">
          <div v-for="c in cashflow" :key="c.keterangan+c.tanggal" class="px-5 py-3 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div :class="['w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 text-xs', c.jenis==='in'?'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/40 dark:text-emerald-400':'bg-red-100 text-red-600 dark:bg-red-900/40 dark:text-red-400']">
                {{ c.jenis==='in' ? '↑' : '↓' }}
              </div>
              <div>
                <p class="text-xs font-medium text-gray-900 dark:text-white">{{ c.keterangan }}</p>
                <p class="text-[10px] text-gray-400">{{ c.tanggal }}</p>
              </div>
            </div>
            <p :class="['text-sm font-bold', c.jenis==='in'?'text-emerald-600 dark:text-emerald-400':'text-red-600 dark:text-red-400']">
              {{ c.jenis==='in'?'+':'-' }}{{ rp(c.nominal) }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
