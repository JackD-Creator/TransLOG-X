<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const activeTab = ref('invoice')

const tabs = [
  { key: 'invoice', label: 'Invoice & AR',    icon: 'i-lucide-file-text' },
  { key: 'scf',     label: 'SCF / Financing', icon: 'i-lucide-landmark' },
  { key: 'ap',      label: 'Hutang (AP)',      icon: 'i-lucide-credit-card' },
]

const stats = ref([
  { label: 'Total AR Outstanding', value: '-',  icon: 'i-lucide-trending-up',   color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Invoice Jatuh Tempo',  value: '-',  icon: 'i-lucide-alert-circle',  color: 'text-red-600',    bg: 'bg-red-50' },
  { label: 'SCF Aktif',            value: '-',  icon: 'i-lucide-zap',           color: 'text-amber-600',  bg: 'bg-amber-50' },
  { label: 'Total AP',             value: '-',  icon: 'i-lucide-trending-down', color: 'text-purple-600', bg: 'bg-purple-50' },
])

const invoices = ref<any[]>([])
const scfList = ref<any[]>([])
const apList = ref<any[]>([])

async function fetchData() {
  const today = new Date().toISOString().slice(0, 10)

  const [arRes, apRes, scfRes, overdueRes] = await Promise.all([
    supabase.from('invoices').select('invoice_number, invoice_date, customer_name, total_amount, due_date, status, suppliers(short_name)')
      .eq('direction', 'receivable').order('invoice_date', { ascending: false }).limit(20),
    supabase.from('invoices').select('invoice_number, total_amount, due_date, status, po_id, suppliers(short_name)')
      .eq('direction', 'payable').order('invoice_date', { ascending: false }).limit(20),
    supabase.from('financing_transactions').select('transaction_number, financing_type, amount, interest_rate, tenor_days, status, disbursed_at, invoices(invoice_number), financing_facilities(facility_name)')
      .order('created_at', { ascending: false }).limit(20),
    supabase.from('invoices').select('*', { count: 'exact', head: true })
      .eq('direction', 'receivable').lt('due_date', today).not('status', 'in', '("paid","cancelled")'),
  ])

  // AR invoices
  invoices.value = (arRes.data ?? []).map(i => ({
    id: i.invoice_number, tanggal: i.invoice_date, kepada: i.customer_name ?? (i.suppliers as any)?.short_name ?? '-',
    nominal: Number(i.total_amount), jatuh_tempo: i.due_date, status: i.status
  }))

  // AP invoices
  apList.value = (apRes.data ?? []).map(i => ({
    id: i.invoice_number, supplier: (i.suppliers as any)?.short_name ?? '-', po_ref: '-',
    nominal: Number(i.total_amount), jatuh_tempo: i.due_date,
    status: i.status === 'paid' ? 'paid' : 'unpaid'
  }))

  // SCF
  scfList.value = (scfRes.data ?? []).map(s => ({
    id: s.transaction_number, invoice_ref: (s.invoices as any)?.invoice_number ?? '-',
    bank: (s.financing_facilities as any)?.facility_name ?? s.financing_type,
    nominal: Number(s.amount), bunga: Number(s.interest_rate ?? 0), tenor: s.tenor_days ?? 0,
    status: s.status === 'settled' ? 'settled' : s.status === 'disbursed' ? 'active' : s.status,
    cair: s.disbursed_at ? s.disbursed_at.slice(0, 10) : '-'
  }))

  // Stats
  const arTotal = invoices.value.filter(i => i.status !== 'paid' && i.status !== 'cancelled').reduce((s, i) => s + i.nominal, 0)
  const apTotal = apList.value.filter(i => i.status !== 'paid').reduce((s, i) => s + i.nominal, 0)
  const scfActive = scfList.value.filter(s => s.status === 'active').reduce((s, i) => s + i.nominal, 0)

  stats.value[0].value = arTotal >= 1e9 ? `Rp ${(arTotal/1e9).toFixed(2).replace('.',',')}M` : `Rp ${Math.round(arTotal/1e6)}Jt`
  stats.value[1].value = String(overdueRes.count ?? 0)
  stats.value[2].value = scfActive >= 1e9 ? `Rp ${(scfActive/1e9).toFixed(2).replace('.',',')}M` : `Rp ${Math.round(scfActive/1e6)}Jt`
  stats.value[3].value = apTotal >= 1e9 ? `Rp ${(apTotal/1e9).toFixed(2).replace('.',',')}M` : `Rp ${Math.round(apTotal/1e6)}Jt`
}

onMounted(fetchData)

function badge(s: string) {
  const m: Record<string, string> = {
    sent:    'bg-blue-100 text-blue-700',
    overdue: 'bg-red-100 text-red-700',
    paid:    'bg-emerald-100 text-emerald-700',
    draft:   'bg-[#f0f0f0] text-[#666]',
    active:  'bg-amber-100 text-amber-700',
    settled: 'bg-emerald-100 text-emerald-700',
    unpaid:  'bg-red-100 text-red-700',
  }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
function bl(s: string) {
  const m: Record<string, string> = { sent: 'Terkirim', overdue: 'Jatuh Tempo', paid: 'Lunas', draft: 'Draft', active: 'Aktif', settled: 'Selesai', unpaid: 'Belum Bayar' }
  return m[s] ?? s
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Finansial & SCF</h1>
        <p class="text-sm text-[#999] mt-0.5">Invoice, Supply Chain Financing & Hutang Usaha</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Buat Invoice</UButton>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="s.icon" :class="[s.color, 'text-lg']" />
        </div>
        <div>
          <p class="text-lg font-bold text-[#1a1a1a]">{{ s.value }}</p>
          <p class="text-xs text-[#999] leading-tight">{{ s.label }}</p>
        </div>
      </div>
    </div>

    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="flex border-b border-[#e5e5e5]">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab === tab.key ? 'border-[#6b1525] text-[#6b1525]' : 'border-transparent text-[#999] hover:text-[#666]'"
          @click="activeTab = tab.key">
          <UIcon :name="tab.icon" class="text-base" />{{ tab.label }}
        </button>
      </div>

      <div v-if="activeTab === 'invoice'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">No. Invoice</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tanggal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Kepada</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Jatuh Tempo</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3" />
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-[#6b1525] font-semibold">{{ inv.id }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ inv.tanggal }}</td>
              <td class="px-4 py-3 text-sm text-[#1a1a1a]">{{ inv.kepada }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-[#1a1a1a]">{{ fmtRp(inv.nominal) }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ inv.jatuh_tempo }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(inv.status)]">{{ bl(inv.status) }}</span></td>
              <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="activeTab === 'scf'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">ID SCF</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Invoice</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Bank / Fintech</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nominal</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Bunga %</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tenor</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Cair</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="s in scfList" :key="s.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-[#6b1525] font-semibold">{{ s.id }}</td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ s.invoice_ref }}</td>
              <td class="px-4 py-3 text-sm text-[#1a1a1a]">{{ s.bank }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-[#1a1a1a]">{{ fmtRp(s.nominal) }}</td>
              <td class="px-4 py-3 text-right text-sm text-[#666]">{{ s.bunga }}%</td>
              <td class="px-4 py-3 text-right text-sm text-[#666]">{{ s.tenor }}h</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ s.cair }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(s.status)]">{{ bl(s.status) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="activeTab === 'ap'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">ID AP</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Supplier</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Ref. PO</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Jatuh Tempo</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3" />
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="ap in apList" :key="ap.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-[#6b1525] font-semibold">{{ ap.id }}</td>
              <td class="px-4 py-3 text-sm text-[#1a1a1a]">{{ ap.supplier }}</td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ ap.po_ref }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-[#1a1a1a]">{{ fmtRp(ap.nominal) }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ ap.jatuh_tempo }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(ap.status)]">{{ bl(ap.status) }}</span></td>
              <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
