<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Laporan Laba Rugi KSM' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const now = new Date()
const period = ref({ year: now.getFullYear(), month: now.getMonth() + 1 })
const loading = ref(false)
const pl = ref<any>(null)

const months = [
  'Januari','Februari','Maret','April','Mei','Juni',
  'Juli','Agustus','September','Oktober','November','Desember'
]

// Laporan bulan M = data dari bulan M-1
const dataMonth = computed(() => {
  let m = period.value.month - 1
  let y = period.value.year
  if (m === 0) { m = 12; y -= 1 }
  return { year: y, month: m }
})

async function load() {
  if (!tenantId.value) return
  loading.value = true
  pl.value = null

  const startDate = `${dataMonth.value.year}-${String(dataMonth.value.month).padStart(2,'0')}-01`
  const endDate = new Date(dataMonth.value.year, dataMonth.value.month, 0).toISOString().slice(0, 10)

  const [{ data: invData }, { data: arData }, { data: diaData }] = await Promise.all([
    // Revenue = Invoice KSM ke RS (+ po_number untuk match AR)
    supabase.from('ksm_invoices')
      .select('total_amount,subtotal,tax_amount,status,paid_amount,metadata,shortfall_covered_by_bank')
      .eq('ksm_tenant_id', tenantId.value)
      .gte('invoice_date', startDate).lte('invoice_date', endDate),
    // COGS = disbursement Bank ke Distributor untuk PO dalam periode ini
    supabase.from('ar_accounts')
      .select('disbursed_amount,interest_amount')
      .eq('ksm_tenant_id', tenantId.value)
      .gte('invoice_date', startDate).lte('invoice_date', endDate),
    // Bunga harian shortfall (bagian KSM 50%)
    supabase.from('daily_interest_accruals')
      .select('ksm_share, ksm_invoices!inner(ksm_tenant_id)')
      .eq('ksm_invoices.ksm_tenant_id', tenantId.value)
      .gte('accrual_date', startDate).lte('accrual_date', endDate),
  ])

  const allInv = invData ?? []
  const arAccounts = arData ?? []
  const dailyInterest = diaData ?? []

  // Revenue = invoice yang sudah dibayar RS ke KSM (paid atau partially_paid + shortfall covered = lunas)
  const invoices = allInv.filter((i: any) =>
    i.status === 'paid' || (i.status === 'partially_paid' && i.shortfall_covered_by_bank)
  )

  const revenue = invoices.reduce((s: number, i: any) => s + Number(i.total_amount), 0)
  const revenuePPN = invoices.reduce((s: number, i: any) => s + Number(i.tax_amount), 0)
  const revenueNetto = revenue - revenuePPN

  // COGS = disbursement Bank ke Distributor per PO dalam periode (filter by invoice_date)
  const cogs = arAccounts.reduce((s: number, a: any) => s + Number(a.disbursed_amount ?? 0), 0)

  // Gross Profit = Revenue (netto PPN) - COGS
  const grossProfit = revenueNetto - cogs
  const grossMargin = revenueNetto > 0 ? (grossProfit / revenueNetto * 100) : 0

  // Beban bunga SCF ke Bank (matched per PO dari invoice periode ini)
  const arInterestMap: Record<string, number> = {}
  for (const a of arAccounts) { if (a.po_number) arInterestMap[a.po_number] = Number(a.interest_amount ?? 0) }
  const scfInterest = invoices.reduce((s, i) => {
    const poNum = (i as any).metadata?.po_number
    return s + (poNum && arInterestMap[poNum] ? arInterestMap[poNum] : 0)
  }, 0)

  // Beban bunga harian shortfall (bagian KSM 50%)
  const shortfallInterestKSM = dailyInterest.reduce((s, d) => s + Number(d.ksm_share ?? 0), 0)

  const totalInterest = scfInterest + shortfallInterestKSM

  // OpEx estimasi (gaji, sewa, operasional)
  const opex = revenueNetto * 0.04

  const ebit = grossProfit - opex
  const ebt = ebit - totalInterest
  const tax = ebt > 0 ? ebt * 0.22 : 0
  const netIncome = ebt - tax
  const netMargin = revenueNetto > 0 ? (netIncome / revenueNetto * 100) : 0

  pl.value = {
    revenue, revenuePPN, revenueNetto,
    cogs, grossProfit, grossMargin,
    opex, ebit,
    scfInterest, shortfallInterestKSM, totalInterest,
    ebt, tax, netIncome, netMargin,
    invoiceCount: invoices.length,
    arCount: arAccounts.length,
  }
  loading.value = false
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <NuxtLink to="/dashboard/ksm/finance" class="text-[#999] hover:text-[#6b1525]">
          <UIcon name="i-lucide-arrow-left" class="text-sm"/>
        </NuxtLink>
        <div>
          <h1 class="text-xl font-bold text-[#1a1a1a]">Laporan Laba Rugi (P&L)</h1>
          <p class="text-sm text-[#999] mt-0.5">Revenue dari invoice RS · COGS dari disbursement Bank ke Distributor</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <select v-model="period.month" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="(m, i) in months" :key="i" :value="i+1">{{ m }}</option>
        </select>
        <select v-model="period.year" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="y in [2024,2025,2026]" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="px-4 py-2 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] disabled:opacity-60"
          :disabled="loading" @click="load">
          {{ loading ? 'Memuat...' : 'Tampilkan' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else-if="pl">
      <!-- KPI -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Revenue (Invoice RS)</p>
          <p class="text-xl font-bold text-emerald-700">{{ fmtRp(pl.revenueNetto) }}</p>
          <p class="text-[10px] text-[#777] mt-1">{{ pl.invoiceCount }} invoice</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">COGS (Bank→Dist)</p>
          <p class="text-xl font-bold text-red-600">{{ fmtRp(pl.cogs) }}</p>
          <p class="text-[10px] text-[#777] mt-1">{{ pl.arCount }} disbursement</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Gross Margin</p>
          <p class="text-xl font-bold" :class="pl.grossMargin >= 8 ? 'text-emerald-700' : 'text-amber-600'">{{ fmtPct(pl.grossMargin) }}</p>
        </div>
        <div :class="['rounded-xl border p-4', pl.netIncome >= 0 ? 'bg-emerald-50 border-emerald-200' : 'bg-red-50 border-red-200']">
          <p class="text-[10px] text-[#999] uppercase mb-1">Laba Bersih</p>
          <p :class="['text-xl font-bold', pl.netIncome >= 0 ? 'text-emerald-700' : 'text-red-600']">{{ fmtRp(pl.netIncome) }}</p>
        </div>
      </div>

      <!-- P&L Statement -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5] bg-[#ebebeb]">
          <p class="text-sm font-bold text-[#1a1a1a]">Laporan Laba Rugi — {{ months[period.month - 1] }} {{ period.year }}</p>
          <p class="text-[10px] text-[#999] mt-0.5">Data invoice: {{ months[dataMonth.month - 1] }} {{ dataMonth.year }} · Alur: Bank bayar Dist (COGS) → RS bayar KSM (Revenue) → KSM lunasi Bank</p>
        </div>
        <div class="p-5 space-y-0 text-sm">
          <!-- Revenue -->
          <div class="flex justify-between py-2 border-b border-[#e5e5e5]">
            <span class="font-semibold text-[#1a1a1a]">Pendapatan Invoice ke RS (Bruto)</span>
            <span class="font-bold text-[#1a1a1a]">{{ fmtRp(pl.revenue) }}</span>
          </div>
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666]">
            <span>PPN 11%</span>
            <span class="text-red-500">({{ fmtRp(pl.revenuePPN) }})</span>
          </div>
          <div class="flex justify-between py-2 border-b border-[#e5e5e5] bg-[#fafafa] px-2 rounded my-1">
            <span class="font-semibold text-[#1a1a1a]">Revenue Netto</span>
            <span class="font-bold text-emerald-700">{{ fmtRp(pl.revenueNetto) }}</span>
          </div>

          <!-- COGS -->
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666] border-b border-[#e5e5e5]">
            <span>HPP — Disbursement Bank ke Distributor (atas nama KSM)</span>
            <span class="text-red-600">({{ fmtRp(pl.cogs) }})</span>
          </div>

          <!-- Gross Profit -->
          <div class="flex justify-between py-2 bg-[#fafafa] px-2 rounded my-1">
            <span class="font-bold text-[#1a1a1a]">Laba Kotor</span>
            <div class="text-right">
              <span :class="['font-bold', pl.grossProfit >= 0 ? 'text-emerald-700' : 'text-red-600']">{{ fmtRp(pl.grossProfit) }}</span>
              <span class="text-[10px] text-[#999] ml-1">({{ fmtPct(pl.grossMargin) }})</span>
            </div>
          </div>

          <!-- OpEx -->
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666] border-b border-[#e5e5e5]">
            <span>Biaya Operasional (est. 4%)</span>
            <span class="text-red-400">({{ fmtRp(pl.opex) }})</span>
          </div>

          <!-- EBIT -->
          <div class="flex justify-between py-2 border-b border-[#e5e5e5]">
            <span class="font-semibold text-[#1a1a1a]">EBIT</span>
            <span :class="['font-bold', pl.ebit >= 0 ? 'text-emerald-600' : 'text-red-600']">{{ fmtRp(pl.ebit) }}</span>
          </div>

          <!-- Interest -->
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666]">
            <span>Bunga SCF ke Bank (pelunasan fasilitas)</span>
            <span class="text-red-500">({{ fmtRp(pl.scfInterest) }})</span>
          </div>
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666] border-b border-[#e5e5e5]">
            <span>Bunga Harian Shortfall (bagian KSM 50%)</span>
            <span class="text-red-500">({{ fmtRp(pl.shortfallInterestKSM) }})</span>
          </div>

          <!-- EBT -->
          <div class="flex justify-between py-2 border-b border-[#e5e5e5]">
            <span class="font-semibold text-[#1a1a1a]">Laba Sebelum Pajak (EBT)</span>
            <span :class="['font-bold', pl.ebt >= 0 ? 'text-emerald-700' : 'text-red-600']">{{ fmtRp(pl.ebt) }}</span>
          </div>

          <!-- Tax -->
          <div class="flex justify-between py-1.5 pl-5 text-xs text-[#666] border-b border-[#e5e5e5]">
            <span>PPh Badan 22%</span>
            <span class="text-red-400">({{ fmtRp(pl.tax) }})</span>
          </div>

          <!-- Net Income -->
          <div class="flex justify-between py-3 px-3 mt-2 rounded-lg font-bold text-base"
            :class="pl.netIncome >= 0 ? 'bg-emerald-50' : 'bg-red-50'">
            <span class="text-[#1a1a1a]">Laba Bersih (Net Income)</span>
            <div class="text-right">
              <span :class="pl.netIncome >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(pl.netIncome) }}</span>
              <span class="text-[10px] text-[#999] ml-1">({{ fmtPct(pl.netMargin) }})</span>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] flex flex-col items-center justify-center py-16 gap-3">
      <UIcon name="i-lucide-bar-chart-2" class="text-3xl text-[#999]"/>
      <p class="text-sm text-[#999]">Pilih periode dan klik Tampilkan</p>
    </div>
  </div>
</template>
