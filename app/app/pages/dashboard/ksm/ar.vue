<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'AR — Piutang dari RS' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const invoices = ref<any[]>([])
const filterStatus = ref('all')

async function load() {
  if (!tenantId.value) return
  loading.value = true
  let query = supabase
    .from('ksm_invoices')
    .select('id,invoice_number,invoice_date,due_date,total_amount,paid_amount,outstanding,status,bpjs_amount,bpjs_received_date,shortfall_amount,shortfall_covered_by_bank,metadata')
    .eq('ksm_tenant_id', tenantId.value)
    .order('due_date', { ascending: true })
    .limit(100)
  if (filterStatus.value !== 'all') query = query.eq('status', filterStatus.value)
  const { data } = await query
  invoices.value = data ?? []
  loading.value = false
}

const today = new Date().toISOString().slice(0, 10)

// partially_paid + shortfall_covered_by_bank = Lunas untuk KSM (Bank bayar langsung)
const isUnpaid = (i: any) => i.status !== 'paid' && !(i.status === 'partially_paid' && i.shortfall_covered_by_bank)

// Aging buckets berdasarkan invoice due_date
const aging = computed(() => {
  const unpaid = invoices.value.filter(isUnpaid)
  const sum = (arr: any[]) => arr.reduce((s, i) => s + Number(i.total_amount ?? 0), 0)
  const dd = (i: any) => Math.round((new Date(i.due_date).getTime() - new Date(today).getTime()) / 86400000)

  const current = unpaid.filter(i => dd(i) >= 0)
  const d30 = unpaid.filter(i => dd(i) < 0 && dd(i) >= -30)
  const d60 = unpaid.filter(i => dd(i) < -30 && dd(i) >= -60)
  const d90 = unpaid.filter(i => dd(i) < -60)

  return [
    { label: 'Current', desc: 'Belum jatuh tempo', amount: sum(current), count: current.length, color: 'text-emerald-700' },
    { label: '1–30 Hari', desc: '', amount: sum(d30), count: d30.length, color: 'text-amber-600' },
    { label: '31–60 Hari', desc: '', amount: sum(d60), count: d60.length, color: 'text-orange-600' },
    { label: '60+ Hari', desc: 'Kritis', amount: sum(d90), count: d90.length, color: 'text-red-600' },
  ]
})

const totalOutstanding = computed(() => invoices.value.filter(isUnpaid).reduce((s, i) => s + Number(i.total_amount ?? 0), 0))
const totalPaid = computed(() => invoices.value.filter(i => !isUnpaid(i)).reduce((s, i) => s + Number(i.total_amount), 0))
const totalOverdue = computed(() => {
  return invoices.value.filter(i => isUnpaid(i) && i.due_date < today).reduce((s, i) => s + Number(i.total_amount ?? 0), 0)
})

watch(tenantId, (id) => { if (id) load() })
watch(filterStatus, load)
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">AR — Piutang dari RS</h1>
      <p class="text-sm text-[#999] mt-0.5">Piutang KSM = Invoice yang belum dibayar RS · Sumber: BPJS + SI bank custodian</p>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Total Piutang dari RS</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(totalOutstanding) }}</p>
        <p class="text-xs text-[#999] mt-1">{{ invoices.filter(i => i.status !== 'paid').length }} invoice outstanding</p>
      </div>
      <div class="bg-red-50 rounded-xl border border-red-200 p-5">
        <p class="text-xs text-red-400 uppercase tracking-wide mb-2">Overdue</p>
        <p class="text-2xl font-bold text-red-600">{{ fmtRp(totalOverdue) }}</p>
        <p class="text-xs text-red-400 mt-1">Lewat jatuh tempo</p>
      </div>
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-5">
        <p class="text-xs text-emerald-600 uppercase tracking-wide mb-2">Total Terbayar</p>
        <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(totalPaid) }}</p>
      </div>
    </div>

    <!-- Aging Buckets -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">AR Aging — Umur Piutang dari RS</p>
      </div>
      <div class="grid grid-cols-4 divide-x divide-[#e5e5e5]">
        <div v-for="b in aging" :key="b.label" class="p-4 text-center">
          <p class="text-[10px] text-[#999] mb-1">{{ b.label }}</p>
          <p :class="['text-lg font-bold', b.color]">{{ fmtRp(b.amount) }}</p>
          <p class="text-[10px] text-[#999] mt-0.5">{{ b.count }} invoice</p>
        </div>
      </div>
    </div>

    <!-- Filter -->
    <div class="flex items-center gap-2 flex-wrap">
      <button v-for="s in [
        {key:'all', label:'Semua'}, {key:'draft', label:'Draft'},
        {key:'sent_to_rs', label:'Terkirim'}, {key:'partially_paid', label:'Sebagian'},
        {key:'paid', label:'Lunas'}, {key:'overdue', label:'Overdue'}
      ]" :key="s.key" @click="filterStatus = s.key"
        :class="['px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors',
          filterStatus === s.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ s.label }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="invoices.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-file-text" class="text-3xl text-[#999]"/>
      <p class="text-sm text-[#999]">Belum ada data piutang</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-xs min-w-[900px]">
          <thead class="border-b border-[#e5e5e5] bg-[#ebebeb]">
            <tr class="text-left">
              <th class="px-4 py-3 font-semibold text-[#999]">No. Invoice</th>
              <th class="px-4 py-3 font-semibold text-[#999]">RS</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Total Invoice</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">BPJS Diterima</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Outstanding</th>
              <th class="px-4 py-3 font-semibold text-[#999]">Jatuh Tempo</th>
              <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ inv.invoice_number }}</td>
              <td class="px-4 py-3 text-[#666]">{{ inv.metadata?.rs_name ?? '-' }}</td>
              <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</td>
              <td class="px-4 py-3 text-right">
                <span v-if="inv.bpjs_amount" class="font-semibold text-blue-700">{{ fmtRp(inv.bpjs_amount) }}</span>
                <span v-else class="text-[#999]">—</span>
              </td>
              <td class="px-4 py-3 text-right font-bold" :class="Number(inv.outstanding ?? 0) > 0 ? 'text-amber-700' : 'text-emerald-600'">
                {{ fmtRp(inv.outstanding ?? 0) }}
              </td>
              <td class="px-4 py-3">
                <span :class="inv.due_date < today && inv.status !== 'paid' ? 'text-red-600 font-bold' : 'text-[#666]'">
                  {{ fmtDate(inv.due_date) }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                  inv.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                  inv.status === 'partially_paid' ? 'bg-amber-100 text-amber-700' :
                  inv.status === 'overdue' ? 'bg-red-100 text-red-700' :
                  inv.status === 'sent_to_rs' ? 'bg-purple-100 text-purple-700' :
                  'bg-[#f0f0f0] text-[#999]']">
                  {{ inv.status === 'paid' ? 'Lunas' : inv.status === 'partially_paid' ? 'Sebagian' :
                     inv.status === 'overdue' ? 'Overdue' : inv.status === 'sent_to_rs' ? 'Terkirim' : inv.status }}
                </span>
                <span v-if="inv.shortfall_covered_by_bank" class="ml-1 px-1.5 py-0.5 rounded text-[9px] font-bold bg-red-100 text-red-700">
                  Shortfall
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
