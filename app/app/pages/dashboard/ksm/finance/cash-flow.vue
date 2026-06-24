<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Cash Flow' })

const supabase = useSupabaseClient()
const loading = ref(true)
const period = ref('this_month')

interface CashItem { label: string; amount: number; sub?: string }

const operatingIn = ref<CashItem[]>([])
const operatingOut = ref<CashItem[]>([])
const financingIn = ref<CashItem[]>([])
const financingOut = ref<CashItem[]>([])

async function loadData() {
  loading.value = true

  const now = new Date()
  let dateFrom: string
  if (period.value === 'this_month') {
    dateFrom = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  } else if (period.value === 'last_month') {
    dateFrom = new Date(now.getFullYear(), now.getMonth() - 1, 1).toISOString()
  } else {
    dateFrom = new Date(now.getFullYear(), 0, 1).toISOString()
  }

  const [{ data: arPaid }, { data: poSent }, { data: scfIn }, { data: scfOut }] = await Promise.all([
    // Kas masuk dari RS (AR yang sudah dibayar)
    supabase.from('ar_accounts').select('invoice_amount, interest_amount')
      .eq('status','paid').gte('paid_date', dateFrom),
    // Kas keluar ke distributor (PO yang sudah delivered)
    supabase.from('ksm_purchase_orders').select('total_amount')
      .in('status',['fully_received','approved']).gte('created_at', dateFrom),
    // Kas masuk dari pencairan SCF
    supabase.from('ar_accounts').select('invoice_amount')
      .not('disbursement_date','is',null).gte('disbursement_date', dateFrom),
    // Kas keluar pembayaran ke bank (pelunasan AR)
    supabase.from('ar_accounts').select('invoice_amount, interest_amount')
      .eq('status','paid').gte('paid_date', dateFrom),
  ])

  const paidInvoice  = (arPaid ?? []).reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0)
  const paidInterest = (arPaid ?? []).reduce((s,a) => s + Number(a.interest_amount ?? 0), 0)
  const totalPO      = (poSent ?? []).reduce((s,p) => s + Number(p.total_amount ?? 0), 0)
  const scfDisb      = (scfIn ?? []).reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0)
  const scfRepay     = (scfOut ?? []).reduce((s,a) => s + Number(a.invoice_amount ?? 0) + Number(a.interest_amount ?? 0), 0)

  operatingIn.value = [
    { label: 'Penerimaan dari RS (piutang terlunasi)', amount: paidInvoice },
    { label: 'Service fee & jasa managed logistics', amount: paidInvoice * 0.05 },
  ]
  operatingOut.value = [
    { label: 'Pembayaran ke distributor (PO)', amount: totalPO },
    { label: 'Biaya operasional & SDM (est.)', amount: totalPO * 0.03 },
  ]
  financingIn.value = [
    { label: 'Pencairan fasilitas SCF dari Bank', amount: scfDisb },
  ]
  financingOut.value = [
    { label: 'Pelunasan fasilitas SCF ke Bank', amount: scfRepay * 0.90, sub: 'Pokok' },
    { label: 'Pembayaran bunga SCF ke Bank', amount: paidInterest, sub: 'Bunga' },
  ]

  loading.value = false
}

const totOpIn  = computed(() => operatingIn.value.reduce((s,i) => s + i.amount, 0))
const totOpOut = computed(() => operatingOut.value.reduce((s,i) => s + i.amount, 0))
const netOp    = computed(() => totOpIn.value - totOpOut.value)

const totFinIn  = computed(() => financingIn.value.reduce((s,i) => s + i.amount, 0))
const totFinOut = computed(() => financingOut.value.reduce((s,i) => s + i.amount, 0))
const netFin    = computed(() => totFinIn.value - totFinOut.value)

const netCash   = computed(() => netOp.value + netFin.value)

function fmtRp(n: number) {
  if (Math.abs(n) >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (Math.abs(n) >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',minimumFractionDigits:0}).format(n)
}

watch(period, loadData)
onMounted(loadData)
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
          <p class="text-sm text-[#999] mt-0.5">Cash flow dari aktivitas operasional dan pembiayaan KSM</p>
        </div>
      </div>
      <select v-model="period" class="text-xs border border-[#e5e5e5] rounded-lg px-3 py-2 bg-[#f5f5f5] text-[#1a1a1a] outline-none">
        <option value="this_month">Bulan Ini</option>
        <option value="last_month">Bulan Lalu</option>
        <option value="this_year">Tahun Ini</option>
      </select>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-3 gap-4">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Kas Ops Bersih</p>
        <p class="text-xl font-bold" :class="netOp >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(netOp) }}</p>
        <p class="text-[10px] text-[#999] mt-0.5">Operasional</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Kas Fin. Bersih</p>
        <p class="text-xl font-bold" :class="netFin >= 0 ? 'text-blue-700' : 'text-amber-600'">{{ fmtRp(netFin) }}</p>
        <p class="text-[10px] text-[#999] mt-0.5">Pembiayaan SCF</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Net Cash Flow</p>
        <p class="text-xl font-bold" :class="netCash >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(netCash) }}</p>
        <p class="text-[10px] text-[#aaa] mt-0.5">{{ netCash >= 0 ? 'Positif ✓' : 'Negatif ⚠' }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-4">

      <!-- Operasional -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-[#ebebeb] border-b border-[#e0e0e0] px-5 py-3 flex items-center justify-between">
          <p class="text-xs font-bold text-[#1a1a1a]">Aktivitas Operasional</p>
          <p class="text-xs font-bold" :class="netOp >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(netOp) }}</p>
        </div>
        <div class="p-5 text-xs space-y-1">
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2">Kas Masuk</p>
          <div v-for="i in operatingIn" :key="i.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ i.label }}</span>
            <span class="text-emerald-700 font-semibold">+{{ fmtRp(i.amount) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold">
            <span class="text-[#333]">Subtotal Masuk</span>
            <span class="text-emerald-700">+{{ fmtRp(totOpIn) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Kas Keluar</p>
          <div v-for="i in operatingOut" :key="i.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ i.label }}</span>
            <span class="text-red-600 font-semibold">-{{ fmtRp(i.amount) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold">
            <span class="text-[#333]">Subtotal Keluar</span>
            <span class="text-red-600">-{{ fmtRp(totOpOut) }}</span>
          </div>
        </div>
      </div>

      <!-- Pembiayaan -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-[#ebebeb] border-b border-[#e0e0e0] px-5 py-3 flex items-center justify-between">
          <p class="text-xs font-bold text-[#1a1a1a]">Aktivitas Pembiayaan (SCF)</p>
          <p class="text-xs font-bold" :class="netFin >= 0 ? 'text-blue-700' : 'text-amber-700'">{{ fmtRp(netFin) }}</p>
        </div>
        <div class="p-5 text-xs space-y-1">
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2">Kas Masuk</p>
          <div v-for="i in financingIn" :key="i.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ i.label }}</span>
            <span class="text-emerald-700 font-semibold">+{{ fmtRp(i.amount) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Kas Keluar</p>
          <div v-for="i in financingOut" :key="i.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ i.label }} <span v-if="i.sub" class="text-[10px] text-[#aaa]">({{ i.sub }})</span></span>
            <span class="text-red-600 font-semibold">-{{ fmtRp(i.amount) }}</span>
          </div>
        </div>
      </div>

      <!-- Net Change -->
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-5 flex items-center justify-between">
        <div>
          <p class="text-xs font-bold text-[#1a1a1a]">
            Kenaikan (Penurunan) Bersih Kas & Setara Kas
          </p>
          <p class="text-[11px] mt-0.5" :class="netCash >= 0 ? 'text-emerald-700' : 'text-red-600'">
            {{ netCash >= 0 ? 'Cashflow positif — operasional menghasilkan kas melebihi pembiayaan' : 'Cashflow negatif — perlu optimasi collection AR atau kurangi outstanding SCF' }}
          </p>
        </div>
        <p class="text-2xl font-bold" :class="netCash >= 0 ? 'text-emerald-700' : 'text-red-600'">
          {{ netCash >= 0 ? '+' : '' }}{{ fmtRp(netCash) }}
        </p>
      </div>
    </div>
  </div>
</template>
