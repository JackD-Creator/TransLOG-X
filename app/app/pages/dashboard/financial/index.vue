<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const activeTab = ref('invoice')

const tabs = [
  { key: 'invoice', label: 'Invoice & AR',    icon: 'i-lucide-file-text' },
  { key: 'scf',     label: 'SCF / Financing', icon: 'i-lucide-landmark' },
  { key: 'ap',      label: 'Hutang (AP)',      icon: 'i-lucide-credit-card' },
]

const stats = [
  { label: 'Total AR Outstanding', value: 'Rp 1,24M',  icon: 'i-lucide-trending-up',   color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Invoice Jatuh Tempo',  value: '5',          icon: 'i-lucide-alert-circle',  color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
  { label: 'SCF Aktif',            value: 'Rp 450Jt',   icon: 'i-lucide-zap',           color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Total AP',             value: 'Rp 890Jt',   icon: 'i-lucide-trending-down', color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' },
]

const invoices = ref([
  { id: 'INV-2026-0089', tanggal: '2026-06-20', kepada: 'PT. BPJS Kesehatan',     nominal: 487500000, jatuh_tempo: '2026-07-20', status: 'sent' },
  { id: 'INV-2026-0088', tanggal: '2026-06-15', kepada: 'Asuransi Sinarmas',       nominal: 125000000, jatuh_tempo: '2026-07-15', status: 'overdue' },
  { id: 'INV-2026-0087', tanggal: '2026-06-10', kepada: 'PT. Taspen',              nominal: 78000000,  jatuh_tempo: '2026-07-10', status: 'paid' },
  { id: 'INV-2026-0086', tanggal: '2026-06-05', kepada: 'PT. BPJS Kesehatan',     nominal: 512000000, jatuh_tempo: '2026-07-05', status: 'paid' },
  { id: 'INV-2026-0085', tanggal: '2026-06-01', kepada: 'Asuransi Allianz',        nominal: 45000000,  jatuh_tempo: '2026-07-01', status: 'draft' },
])

const scfList = ref([
  { id: 'SCF-2026-0012', invoice_ref: 'INV-2026-0089', bank: 'Bank Mandiri',  nominal: 390000000, bunga: 1.2, tenor: 30, status: 'active',    cair: '2026-06-21' },
  { id: 'SCF-2026-0011', invoice_ref: 'INV-2026-0088', bank: 'BRI',           nominal: 100000000, bunga: 1.5, tenor: 45, status: 'active',    cair: '2026-06-16' },
  { id: 'SCF-2026-0010', invoice_ref: 'INV-2026-0086', bank: 'Bank Mandiri',  nominal: 409600000, bunga: 1.2, tenor: 30, status: 'settled',   cair: '2026-06-06' },
])

const apList = ref([
  { id: 'AP-2026-0034', supplier: 'PT. Kimia Farma',      po_ref: 'PO-2026-0045', nominal: 12500000,  jatuh_tempo: '2026-07-19', status: 'unpaid' },
  { id: 'AP-2026-0033', supplier: 'PT. Enseval Medika',   po_ref: 'PO-2026-0044', nominal: 7800000,   jatuh_tempo: '2026-07-17', status: 'unpaid' },
  { id: 'AP-2026-0032', supplier: 'PT. Rajawali Nusindo', po_ref: 'PO-2026-0043', nominal: 3200000,   jatuh_tempo: '2026-07-14', status: 'paid' },
])

function badge(s: string) {
  const m: Record<string, string> = {
    sent:    'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400',
    overdue: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400',
    paid:    'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
    draft:   'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
    active:  'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400',
    settled: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
    unpaid:  'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400',
  }
  return m[s] ?? 'bg-gray-100 text-gray-600'
}
function bl(s: string) {
  const m: Record<string, string> = { sent: 'Terkirim', overdue: 'Jatuh Tempo', paid: 'Lunas', draft: 'Draft', active: 'Aktif', settled: 'Selesai', unpaid: 'Belum Bayar' }
  return m[s] ?? s
}
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Finansial & SCF</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Invoice, Supply Chain Financing & Hutang Usaha</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Buat Invoice</UButton>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="s.icon" :class="[s.color, 'text-lg']" />
        </div>
        <div>
          <p class="text-lg font-bold text-gray-900 dark:text-white">{{ s.value }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p>
        </div>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="flex border-b border-gray-200 dark:border-gray-800">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab === tab.key ? 'border-red-600 text-red-600 dark:text-red-400' : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700'"
          @click="activeTab = tab.key">
          <UIcon :name="tab.icon" class="text-base" />{{ tab.label }}
        </button>
      </div>

      <div v-if="activeTab === 'invoice'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. Invoice</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Kepada</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Jatuh Tempo</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
            <th class="px-4 py-3" />
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ inv.id }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ inv.tanggal }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ inv.kepada }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-gray-900 dark:text-white">{{ rp(inv.nominal) }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ inv.jatuh_tempo }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(inv.status)]">{{ bl(inv.status) }}</span></td>
              <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="activeTab === 'scf'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">ID SCF</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Invoice</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Bank / Fintech</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nominal</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Bunga %</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tenor</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Cair</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="s in scfList" :key="s.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ s.id }}</td>
              <td class="px-4 py-3 font-mono text-xs text-gray-500">{{ s.invoice_ref }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ s.bank }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-gray-900 dark:text-white">{{ rp(s.nominal) }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ s.bunga }}%</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ s.tenor }}h</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ s.cair }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(s.status)]">{{ bl(s.status) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="activeTab === 'ap'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">ID AP</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Supplier</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Ref. PO</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Jatuh Tempo</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
            <th class="px-4 py-3" />
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="ap in apList" :key="ap.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ ap.id }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ ap.supplier }}</td>
              <td class="px-4 py-3 font-mono text-xs text-gray-500">{{ ap.po_ref }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-gray-900 dark:text-white">{{ rp(ap.nominal) }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ ap.jatuh_tempo }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(ap.status)]">{{ bl(ap.status) }}</span></td>
              <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
