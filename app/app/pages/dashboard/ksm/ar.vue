<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'AR & Tagihan' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const arList = ref<any[]>([])
const filterStatus = ref('all')

const statusColor: Record<string, string> = {
  pending:        'bg-[#f0f0f0] text-[#999]',
  disbursed:      'bg-blue-100 text-blue-700',
  partially_paid: 'bg-amber-100 text-amber-700',
  paid:           'bg-emerald-100 text-emerald-700',
  overdue:        'bg-red-100 text-red-700',
  defaulted:      'bg-red-200 text-red-800',
}
const statusLabel: Record<string, string> = {
  pending: 'Pending', disbursed: 'Cair ke Dist.', partially_paid: 'Dibayar Sebagian',
  paid: 'Lunas', overdue: 'Jatuh Tempo', defaulted: 'Default',
}

async function load() {
  if (!tenantId.value) return
  loading.value = true
  let query = supabase
    .from('ar_accounts')
    .select('id,ar_number,po_number,invoice_ref,invoice_amount,disbursed_amount,interest_amount,total_payable,paid_amount,outstanding_amount,invoice_date,disbursement_date,due_date,paid_date,status')
    .eq('ksm_tenant_id', tenantId.value)
    .order('due_date', { ascending: true })
    .limit(100)
  if (filterStatus.value !== 'all') query = query.eq('status', filterStatus.value)
  const { data } = await query
  arList.value = data ?? []
  loading.value = false
}

function fmtRp(n: number | null) {
  if (!n) return 'Rp 0'
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(2)}M`
  if (n >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return 'Rp ' + Math.round(n).toLocaleString('id-ID')
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const today = new Date().toISOString().slice(0, 10)
function daysDiff(d: string) {
  return Math.round((new Date(d).getTime() - new Date(today).getTime()) / 86400000)
}

// AR Aging buckets
const aging = computed(() => {
  const unpaid = arList.value.filter(a => !['paid'].includes(a.status))
  const current  = unpaid.filter(a => daysDiff(a.due_date) >= 0)
  const d30      = unpaid.filter(a => daysDiff(a.due_date) < 0 && daysDiff(a.due_date) >= -30)
  const d60      = unpaid.filter(a => daysDiff(a.due_date) < -30 && daysDiff(a.due_date) >= -60)
  const d90plus  = unpaid.filter(a => daysDiff(a.due_date) < -60)
  const sum = (arr: any[]) => arr.reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)
  return [
    { label: 'Current', range: '(belum jatuh tempo)', amount: sum(current), count: current.length, color: 'text-emerald-700' },
    { label: '1–30 Hari', range: '', amount: sum(d30), count: d30.length, color: 'text-amber-600' },
    { label: '31–60 Hari', range: '', amount: sum(d60), count: d60.length, color: 'text-orange-600' },
    { label: '60+ Hari', range: '(kritis)', amount: sum(d90plus), count: d90plus.length, color: 'text-red-600' },
  ]
})

const totalOutstanding = computed(() => arList.value.filter(a => a.status !== 'paid').reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))
const totalOverdue = computed(() => arList.value.filter(a => a.status === 'overdue' || (a.status !== 'paid' && daysDiff(a.due_date) < 0)).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))
const totalPaid = computed(() => arList.value.filter(a => a.status === 'paid').reduce((s, a) => s + Number(a.total_payable ?? 0), 0))

const filtered = computed(() => {
  if (filterStatus.value === 'all') return arList.value
  return arList.value.filter(a => a.status === filterStatus.value)
})

watch(tenantId, (id) => { if (id) load() })
watch(filterStatus, load)
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">AR & Tagihan ke Bank</h1>
        <p class="text-sm text-[#999] mt-0.5">Piutang KSM — SCF/Reverse Factoring — Aging Analysis</p>
      </div>
      <NuxtLink to="/dashboard/ksm/finance" class="text-xs text-[#6b1525] hover:underline flex items-center gap-1">
        <UIcon name="i-lucide-arrow-left" class="text-xs"/>
        Kembali ke Finance
      </NuxtLink>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Total AR Outstanding</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(totalOutstanding) }}</p>
        <p class="text-xs text-[#999] mt-1">{{ arList.filter(a => !['paid','defaulted'].includes(a.status)).length }} tagihan aktif</p>
      </div>
      <div class="bg-red-50 rounded-xl border border-red-200 p-5">
        <p class="text-xs text-red-400 uppercase tracking-wide mb-2">Jatuh Tempo / Overdue</p>
        <p class="text-2xl font-bold text-red-600">{{ fmtRp(totalOverdue) }}</p>
        <p class="text-xs text-red-400 mt-1">Perlu segera ditagih</p>
      </div>
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-5">
        <p class="text-xs text-emerald-600 uppercase tracking-wide mb-2">Total Lunas</p>
        <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(totalPaid) }}</p>
        <p class="text-xs text-emerald-600 mt-1">{{ arList.filter(a => a.status === 'paid').length }} tagihan lunas</p>
      </div>
    </div>

    <!-- AR Aging Buckets -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">AR Aging (Analisis Umur Piutang)</p>
      </div>
      <div class="grid grid-cols-4 divide-x divide-[#e5e5e5]">
        <div v-for="b in aging" :key="b.label" class="p-4 text-center">
          <p class="text-[10px] text-[#999] mb-1">{{ b.label }}</p>
          <p v-if="b.range" class="text-[9px] text-[#bbb] mb-1">{{ b.range }}</p>
          <p :class="['text-lg font-bold', b.color]">{{ fmtRp(b.amount) }}</p>
          <p class="text-[10px] text-[#999] mt-0.5">{{ b.count }} tagihan</p>
        </div>
      </div>
    </div>

    <!-- Filter -->
    <div class="flex items-center gap-2 flex-wrap">
      <button v-for="s in [
        {key:'all', label:'Semua'}, {key:'pending', label:'Pending'},
        {key:'disbursed', label:'Cair'}, {key:'partially_paid', label:'Sebagian'},
        {key:'paid', label:'Lunas'}, {key:'overdue', label:'Overdue'}
      ]" :key="s.key" @click="filterStatus = s.key"
        :class="['px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors',
          filterStatus === s.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ s.label }}
      </button>
    </div>

    <!-- AR Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div v-if="loading" class="flex items-center justify-center py-16">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>
      <div v-else-if="filtered.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-file-text" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada AR tercatat</p>
        <p class="text-xs text-[#bbb]">AR akan muncul setelah PO diproses melalui SCF bank</p>
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs min-w-[900px]">
          <thead class="border-b border-[#e5e5e5] bg-[#ebebeb]">
            <tr class="text-left">
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Ref PO / Invoice</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide text-right">Nilai Invoice</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide text-right">Cair ke Dist.</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide text-right">Bunga SCF</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide text-right">Outstanding</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Jatuh Tempo</th>
              <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="ar in filtered" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</td>
              <td class="px-4 py-3">
                <p class="font-mono text-[#666]">{{ ar.po_number ?? '-' }}</p>
                <p class="text-[10px] text-[#aaa]">{{ ar.invoice_ref ?? '' }}</p>
              </td>
              <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(ar.invoice_amount) }}</td>
              <td class="px-4 py-3 text-right text-blue-700 font-semibold">{{ fmtRp(ar.disbursed_amount) }}</td>
              <td class="px-4 py-3 text-right text-red-500">{{ fmtRp(ar.interest_amount) }}</td>
              <td class="px-4 py-3 text-right font-bold" :class="Number(ar.outstanding_amount ?? 0) > 0 ? 'text-amber-700' : 'text-emerald-600'">
                {{ fmtRp(Number(ar.outstanding_amount ?? 0)) }}
              </td>
              <td class="px-4 py-3">
                <p :class="['font-medium', daysDiff(ar.due_date) < 0 && ar.status !== 'paid' ? 'text-red-600 font-bold' : daysDiff(ar.due_date) <= 7 ? 'text-amber-600' : 'text-[#666]']">
                  {{ fmtDate(ar.due_date) }}
                </p>
                <p v-if="ar.status !== 'paid' && daysDiff(ar.due_date) >= 0" class="text-[10px] text-[#999]">
                  {{ daysDiff(ar.due_date) }} hari lagi
                </p>
                <p v-else-if="ar.status !== 'paid'" class="text-[10px] text-red-500 font-medium">
                  {{ Math.abs(daysDiff(ar.due_date)) }} hari lalu
                </p>
              </td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full font-medium text-[10px]', statusColor[ar.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                  {{ statusLabel[ar.status] ?? ar.status }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
