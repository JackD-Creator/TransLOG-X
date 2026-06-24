<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Cash Flow' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const period = ref('2026-03')

interface CashItem { label: string; amount: number; sub?: string }

const operatingIn = ref<CashItem[]>([])
const operatingOut = ref<CashItem[]>([])
const financingIn = ref<CashItem[]>([])
const financingOut = ref<CashItem[]>([])

const periodOptions = [
  { value: '2026-01', label: 'Januari 2026' },
  { value: '2026-02', label: 'Februari 2026' },
  { value: '2026-03', label: 'Maret 2026' },
  { value: '2026-04', label: 'April 2026' },
  { value: '2026-05', label: 'Mei 2026' },
  { value: 'this_year', label: 'Tahun Ini (Kumulatif)' },
]

async function loadData() {
  if (!tenantId.value) return
  loading.value = true

  let dateFrom: string, dateTo: string | null = null
  if (period.value === 'this_year') {
    dateFrom = '2026-01-01'
  } else {
    const [y, m] = period.value.split('-').map(Number)
    dateFrom = `${y}-${String(m).padStart(2,'0')}-01`
    dateTo = new Date(y, m, 0).toISOString().slice(0, 10)
  }

  let q1 = supabase.from('ksm_invoices').select('paid_amount,bpjs_amount,total_amount').eq('ksm_tenant_id', tenantId.value).in('status', ['paid', 'partially_paid']).gte('invoice_date', dateFrom)
  let q2 = supabase.from('ar_accounts').select('paid_amount,interest_amount,total_payable').eq('ksm_tenant_id', tenantId.value).eq('status', 'paid').gte('paid_date', dateFrom)
  let q3 = supabase.from('ar_accounts').select('disbursed_amount').eq('ksm_tenant_id', tenantId.value).not('disbursement_date', 'is', null).gte('disbursement_date', dateFrom)
  let q4 = supabase.from('daily_interest_accruals').select('ksm_share').gte('accrual_date', dateFrom)
  if (dateTo) { q1 = q1.lte('invoice_date', dateTo); q2 = q2.lte('paid_date', dateTo); q3 = q3.lte('disbursement_date', dateTo); q4 = q4.lte('accrual_date', dateTo) }

  const [{ data: invPaid }, { data: arPaid }, { data: arDisb }, { data: diaData }] = await Promise.all([q1, q2, q3, q4])

  const rsPayments = (invPaid ?? []).reduce((s, i) => s + Number(i.paid_amount ?? 0), 0)
  const bpjsTotal = (invPaid ?? []).reduce((s, i) => s + Number(i.bpjs_amount ?? 0), 0)
  const ksmToBank = (arPaid ?? []).reduce((s, a) => s + Number(a.paid_amount ?? 0), 0)
  const bankInterest = (arPaid ?? []).reduce((s, a) => s + Number(a.interest_amount ?? 0), 0)
  const bankToDist = (arDisb ?? []).reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0)
  const shortfallInterest = (diaData ?? []).reduce((s, d) => s + Number(d.ksm_share ?? 0), 0)

  operatingIn.value = [
    { label: 'Penerimaan dari RS (BPJS + SI transfer)', amount: rsPayments, sub: `BPJS: ${fmtRp(bpjsTotal)}` },
  ]
  operatingOut.value = [
    { label: 'Biaya operasional & SDM (est. 4%)', amount: rsPayments * 0.04 },
  ]
  financingIn.value = [
    { label: 'Bank cair ke Distributor (atas nama KSM)', amount: bankToDist, sub: 'Tidak masuk kas KSM — langsung ke Distributor' },
  ]
  financingOut.value = [
    { label: 'Pelunasan pokok SCF ke Bank', amount: ksmToBank - bankInterest, sub: 'Dari dana RS' },
    { label: 'Bunga fasilitas SCF ke Bank', amount: bankInterest },
    { label: 'Bunga harian shortfall (bagian KSM 50%)', amount: shortfallInterest },
  ]

  loading.value = false
}

const totOpIn = computed(() => operatingIn.value.reduce((s, i) => s + i.amount, 0))
const totOpOut = computed(() => operatingOut.value.reduce((s, i) => s + i.amount, 0))
const netOp = computed(() => totOpIn.value - totOpOut.value)

const totFinOut = computed(() => financingOut.value.reduce((s, i) => s + i.amount, 0))
const netCash = computed(() => netOp.value - totFinOut.value)

watch(period, loadData)
watch(tenantId, (id) => { if (id) loadData() })
onMounted(() => { if (tenantId.value) loadData() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <NuxtLink to="/dashboard/ksm/finance" class="text-[#999] hover:text-[#6b1525]">
          <UIcon name="i-lucide-arrow-left" class="text-sm"/>
        </NuxtLink>
        <div>
          <h1 class="text-xl font-bold text-[#1a1a1a]">Cash Flow</h1>
          <p class="text-sm text-[#999] mt-0.5">Kas masuk: RS→KSM (BPJS+SI) · Kas keluar: KSM→Bank (pelunasan SCF)</p>
        </div>
      </div>
      <select v-model="period" class="text-xs border border-[#e5e5e5] rounded-lg px-3 py-2 bg-[#faf7f3] text-[#1a1a1a] outline-none">
        <option v-for="o in periodOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
      </select>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-4">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Kas Masuk (RS→KSM)</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totOpIn) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Kas Keluar (KSM→Bank)</p>
        <p class="text-xl font-bold text-red-600">{{ fmtRp(totFinOut) }}</p>
      </div>
      <div :class="['rounded-xl border p-4 text-center', netCash >= 0 ? 'bg-emerald-50 border-emerald-200' : 'bg-red-50 border-red-200']">
        <p class="text-[10px] text-[#999] uppercase mb-1">Net Cash Flow</p>
        <p :class="['text-xl font-bold', netCash >= 0 ? 'text-emerald-700' : 'text-red-600']">{{ fmtRp(netCash) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Kas Masuk -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-[#ebebeb] border-b border-[#e0e0e0] px-5 py-3">
          <p class="text-xs font-bold text-[#1a1a1a]">Kas Masuk — RS bayar KSM</p>
          <p class="text-[10px] text-[#777] mt-0.5">BPJS cair → SI auto-transfer → masuk kas KSM</p>
        </div>
        <div class="p-5 text-xs space-y-0">
          <div v-for="i in operatingIn" :key="i.label" class="flex justify-between py-2.5 border-b border-[#ececec]">
            <div>
              <span class="text-[#555]">{{ i.label }}</span>
              <p v-if="i.sub" class="text-[10px] text-[#777]">{{ i.sub }}</p>
            </div>
            <span class="text-emerald-700 font-semibold">+{{ fmtRp(i.amount) }}</span>
          </div>
          <div class="flex justify-between py-2.5 font-bold">
            <span class="text-[#333]">Total Kas Masuk</span>
            <span class="text-emerald-700">+{{ fmtRp(totOpIn) }}</span>
          </div>

          <p class="text-[10px] font-bold text-red-500 uppercase tracking-wide mb-2 mt-4">Biaya Operasional</p>
          <div v-for="i in operatingOut" :key="i.label" class="flex justify-between py-2 border-b border-[#ececec]">
            <span class="text-[#555]">{{ i.label }}</span>
            <span class="text-red-600 font-semibold">-{{ fmtRp(i.amount) }}</span>
          </div>
          <div class="flex justify-between py-2.5 font-bold border-t-2 border-[#e0e0e0] mt-2">
            <span class="text-[#333]">Kas Operasional Bersih</span>
            <span :class="netOp >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(netOp) }}</span>
          </div>
        </div>
      </div>

      <!-- Kas Keluar -->
      <div class="space-y-4">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="bg-[#ebebeb] border-b border-[#e0e0e0] px-5 py-3">
            <p class="text-xs font-bold text-[#1a1a1a]">Kas Keluar — KSM lunasi Bank</p>
            <p class="text-[10px] text-[#777] mt-0.5">Pelunasan hutang SCF (pokok + bunga) dari dana yang diterima RS</p>
          </div>
          <div class="p-5 text-xs space-y-0">
            <div v-for="i in financingOut" :key="i.label" class="flex justify-between py-2.5 border-b border-[#ececec]">
              <span class="text-[#555]">{{ i.label }}</span>
              <span class="text-red-600 font-semibold">-{{ fmtRp(i.amount) }}</span>
            </div>
            <div class="flex justify-between py-2.5 font-bold">
              <span class="text-[#333]">Total Pelunasan ke Bank</span>
              <span class="text-red-600">-{{ fmtRp(totFinOut) }}</span>
            </div>
          </div>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-xs">
          <p class="font-bold text-blue-700 mb-1">Info: Bank→Distributor</p>
          <p class="text-blue-600">Pembayaran Bank ke Distributor ({{ fmtRp(financingIn[0]?.amount ?? 0) }}) tidak masuk kas KSM — dicairkan langsung ke Distributor melalui fasilitas SCF.</p>
        </div>

        <!-- Net Cash -->
        <div :class="['rounded-xl border p-5 flex items-center justify-between',
          netCash >= 0 ? 'bg-emerald-50 border-emerald-200' : 'bg-red-50 border-red-200']">
          <div>
            <p class="text-xs font-bold text-[#1a1a1a]">Net Cash Flow KSM</p>
            <p class="text-[10px] mt-0.5" :class="netCash >= 0 ? 'text-emerald-600' : 'text-red-600'">
              {{ netCash >= 0 ? 'Kas positif — dana RS cukup untuk lunasi Bank + operasional' : 'Kas negatif — percepat collection dari RS' }}
            </p>
          </div>
          <p class="text-2xl font-bold ml-4" :class="netCash >= 0 ? 'text-emerald-700' : 'text-red-600'">
            {{ fmtRp(netCash) }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
