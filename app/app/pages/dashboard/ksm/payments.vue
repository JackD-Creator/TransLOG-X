<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pembayaran & BPJS' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const invoices = ref<any[]>([])
const interestData = ref<any[]>([])
const activeTab = ref<'bpjs' | 'shortfall' | 'interest'>('bpjs')

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const [{ data: inv }, { data: dia }] = await Promise.all([
    supabase.from('ksm_invoices')
      .select('id,invoice_number,invoice_date,due_date,total_amount,paid_amount,outstanding,status,bpjs_amount,bpjs_received_date,bpjs_expected_date,shortfall_amount,shortfall_covered_by_bank,metadata')
      .eq('ksm_tenant_id', tenantId.value)
      .in('status', ['sent_to_rs', 'payment_pending', 'partially_paid', 'overdue'])
      .order('due_date', { ascending: true }),
    supabase.from('daily_interest_accruals')
      .select('id,invoice_id,accrual_date,outstanding_principal,daily_rate,interest_amount,ksm_share,rs_share')
      .order('accrual_date', { ascending: false })
      .limit(100),
  ])
  invoices.value = inv ?? []
  interestData.value = dia ?? []
  loading.value = false
}

const totalWaiting = computed(() => invoices.value.filter(i => !i.bpjs_received_date).reduce((s, i) => s + Number(i.total_amount), 0))
const totalReceived = computed(() => invoices.value.filter(i => i.bpjs_received_date).reduce((s, i) => s + Number(i.bpjs_amount ?? 0), 0))
const totalShortfall = computed(() => invoices.value.reduce((s, i) => s + Number(i.shortfall_amount ?? 0), 0))
const totalKSMInterest = computed(() => interestData.value.reduce((s, d) => s + Number(d.ksm_share ?? 0), 0))

const shortfallInvoices = computed(() => invoices.value.filter(i => i.shortfall_covered_by_bank && Number(i.shortfall_amount) > 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pembayaran & BPJS Tracking</h1>
      <p class="text-sm text-[#999] mt-0.5">Tracking BPJS → SI auto-transfer → jika BPJS kurang, Bank buka kredit untuk RS bayar KSM → bunga harian 50% KSM + 50% RS</p>
    </div>

    <!-- KPI -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Tunggu BPJS</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalWaiting) }}</p>
        <p class="text-[10px] text-amber-500 mt-1">{{ invoices.filter(i => !i.bpjs_received_date).length }} invoice</p>
      </div>
      <div class="bg-blue-50 rounded-xl border border-blue-200 p-4">
        <p class="text-[10px] text-blue-500 uppercase mb-1">BPJS Diterima</p>
        <p class="text-xl font-bold text-blue-700">{{ fmtRp(totalReceived) }}</p>
      </div>
      <div :class="['rounded-xl border p-4', totalShortfall > 0 ? 'bg-red-50 border-red-200' : 'bg-emerald-50 border-emerald-200']">
        <p :class="['text-[10px] uppercase mb-1', totalShortfall > 0 ? 'text-red-400' : 'text-emerald-500']">Shortfall Bank</p>
        <p :class="['text-xl font-bold', totalShortfall > 0 ? 'text-red-600' : 'text-emerald-700']">{{ fmtRp(totalShortfall) }}</p>
        <p v-if="totalShortfall > 0" class="text-[10px] text-red-400 mt-1">Kredit Bank untuk RS → bayar KSM</p>
      </div>
      <div v-if="totalKSMInterest > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Bunga KSM (50%)</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalKSMInterest) }}</p>
        <p class="text-[10px] text-[#777] mt-1">50% dari bunga kredit shortfall RS</p>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1.5">
      <button v-for="t in [
        { key: 'bpjs', label: 'BPJS Tracking' },
        { key: 'shortfall', label: 'Shortfall Bank' },
        { key: 'interest', label: 'Bunga Harian' },
      ]" :key="t.key" @click="activeTab = t.key as any"
        :class="['px-4 py-2 rounded-lg text-xs font-semibold transition-colors',
          activeTab === t.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ t.label }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <!-- BPJS Tracking -->
    <div v-else-if="activeTab === 'bpjs'" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Invoice Menunggu Pembayaran BPJS</p>
        <p class="text-[10px] text-[#777] mt-0.5">RS terima BPJS → SI auto-transfer ke KSM → selesai</p>
      </div>
      <div v-if="invoices.length === 0" class="flex flex-col items-center justify-center py-12 gap-2">
        <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
        <p class="text-sm text-[#999]">Semua invoice sudah lunas</p>
      </div>
      <table v-else class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999]">Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999]">RS</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Jatuh Tempo</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Total</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">BPJS</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Outstanding</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Status BPJS</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ inv.invoice_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ inv.metadata?.rs_name ?? '-' }}</td>
            <td class="px-4 py-3" :class="inv.due_date < new Date().toISOString().slice(0,10) ? 'text-red-600 font-bold' : 'text-[#666]'">
              {{ fmtDate(inv.due_date) }}
            </td>
            <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</td>
            <td class="px-4 py-3 text-right">
              <span v-if="inv.bpjs_amount" class="font-bold text-blue-700">{{ fmtRp(inv.bpjs_amount) }}</span>
              <span v-else class="text-[#999]">—</span>
            </td>
            <td class="px-4 py-3 text-right font-bold" :class="Number(inv.outstanding ?? 0) > 0 ? 'text-amber-700' : 'text-emerald-600'">
              {{ fmtRp(inv.outstanding ?? 0) }}
            </td>
            <td class="px-4 py-3">
              <span v-if="inv.bpjs_received_date" class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-700">
                Diterima {{ fmtDate(inv.bpjs_received_date) }}
              </span>
              <span v-else class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-100 text-amber-700 animate-pulse">
                Menunggu BPJS
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Shortfall -->
    <div v-else-if="activeTab === 'shortfall'" class="space-y-3">
      <div v-if="shortfallInvoices.length === 0" class="flex flex-col items-center justify-center py-12 gap-2 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
        <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
        <p class="text-sm text-[#999]">Tidak ada shortfall aktif</p>
      </div>
      <div v-for="inv in shortfallInvoices" :key="inv.id"
        class="bg-red-50 rounded-xl border border-red-200 p-5">
        <div class="flex items-start justify-between mb-3">
          <div>
            <p class="font-mono text-sm font-bold text-red-800">{{ inv.invoice_number }}</p>
            <p class="text-xs text-red-600">RS: {{ inv.metadata?.rs_name ?? '-' }}</p>
          </div>
          <div class="text-right">
            <p class="text-lg font-bold text-red-700">{{ fmtRp(inv.shortfall_amount) }}</p>
            <p class="text-[10px] text-red-500">Bank buka kredit untuk RS, bayar KSM</p>
          </div>
        </div>
        <div class="grid grid-cols-4 gap-3 text-xs">
          <div>
            <p class="text-red-400 text-[10px]">Total Invoice</p>
            <p class="font-bold text-red-800">{{ fmtRp(inv.total_amount) }}</p>
          </div>
          <div>
            <p class="text-red-400 text-[10px]">BPJS Diterima</p>
            <p class="font-bold text-blue-700">{{ fmtRp(inv.bpjs_amount ?? 0) }}</p>
          </div>
          <div>
            <p class="text-red-400 text-[10px]">Shortfall</p>
            <p class="font-bold text-red-700">{{ fmtRp(inv.shortfall_amount) }}</p>
          </div>
          <div>
            <p class="text-red-400 text-[10px]">Bunga</p>
            <p class="font-bold text-red-700">Harian · 50% KSM + 50% RS</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Daily Interest -->
    <div v-else-if="activeTab === 'interest'" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Accrued Daily Interest (Bunga Harian Shortfall)</p>
        <p class="text-[10px] text-[#777] mt-0.5">KSM tanggung 50% karena sudah berhutang SCF ke Bank · RS tanggung 50% karena BPJS-nya yang kurang</p>
      </div>
      <div v-if="interestData.length === 0" class="flex flex-col items-center justify-center py-12 gap-2">
        <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
        <p class="text-sm text-[#999]">Belum ada bunga harian yang di-accrue</p>
      </div>
      <table v-else class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999]">Tanggal</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Pokok</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Rate Harian</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Total Bunga</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Bagian KSM (50%)</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Bagian RS (50%)</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="d in interestData" :key="d.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(d.accrual_date) }}</td>
            <td class="px-4 py-3 text-right font-semibold text-[#1a1a1a]">{{ fmtRp(d.outstanding_principal) }}</td>
            <td class="px-4 py-3 text-right font-mono text-[#666]">{{ (Number(d.daily_rate) * 100).toFixed(6) }}%</td>
            <td class="px-4 py-3 text-right font-bold text-red-600">{{ fmtRp(d.interest_amount) }}</td>
            <td class="px-4 py-3 text-right font-semibold text-amber-700">{{ fmtRp(d.ksm_share) }}</td>
            <td class="px-4 py-3 text-right font-semibold text-amber-700">{{ fmtRp(d.rs_share) }}</td>
          </tr>
        </tbody>
        <tfoot class="border-t-2 border-[#e0e0e0] bg-[#ebebeb]">
          <tr>
            <td colspan="3" class="px-4 py-3 font-bold text-[#666]">TOTAL</td>
            <td class="px-4 py-3 text-right font-bold text-red-600">{{ fmtRp(interestData.reduce((s, d) => s + Number(d.interest_amount), 0)) }}</td>
            <td class="px-4 py-3 text-right font-bold text-amber-700">{{ fmtRp(totalKSMInterest) }}</td>
            <td class="px-4 py-3 text-right font-bold text-amber-700">{{ fmtRp(interestData.reduce((s, d) => s + Number(d.rs_share), 0)) }}</td>
          </tr>
        </tfoot>
      </table>
    </div>
  </div>
</template>
