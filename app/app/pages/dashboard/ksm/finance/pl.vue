<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Laporan Laba Rugi KSM' })

const supabase = useSupabaseClient()

const period = ref({ year: new Date().getFullYear(), month: new Date().getMonth() + 1 })
const loading = ref(false)
const pl = ref<any>(null)

const months = [
  'Januari','Februari','Maret','April','Mei','Juni',
  'Juli','Agustus','September','Oktober','November','Desember'
]

async function load() {
  loading.value = true
  pl.value = null

  // Revenue: dari PO yang fully_received dalam periode ini
  // KSM margin = sell price to RS - buy price from distributor
  // Simplified: hitung dari PO KSM yang selesai

  const startDate = `${period.value.year}-${String(period.value.month).padStart(2,'0')}-01`
  const endDate   = new Date(period.value.year, period.value.month, 0).toISOString().slice(0, 10)

  // Ambil semua PO selesai (fully_received) dalam periode
  const { data: pos } = await supabase
    .from('ksm_purchase_orders')
    .select('total_amount, subtotal, tax_amount')
    .eq('status', 'fully_received')
    .gte('po_date', startDate)
    .lte('po_date', endDate)

  // AR hanya untuk biaya bunga SCF — filter sesuai periode
  const { data: arData } = await supabase
    .from('ar_accounts')
    .select('interest_amount')
    .gte('invoice_date', startDate)
    .lte('invoice_date', endDate)

  // COGS = total pembelian dari distributor (harga beli KSM)
  const cogsBase = (pos ?? []).reduce((s: number, po: any) => s + Number(po.subtotal ?? po.total_amount), 0)
  const cogs = cogsBase

  // Revenue = harga jual KSM ke RS = COGS + margin 12% (blended margin KSM)
  // Ini adalah estimasi berdasarkan model bisnis KSM — sell price = buy price × (1 + margin)
  const MARGIN = 0.12
  const revenue = cogs * (1 + MARGIN)

  // Biaya bunga SCF — beban keuangan ke Bank
  const interestExpense = (arData ?? []).reduce((s: number, a: any) => s + Number(a.interest_amount ?? 0), 0)

  const grossProfit = revenue - cogs
  const grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0

  // Operating expenses (placeholder — akan di-enrich dengan data aktual)
  const opex = 0
  const ebit = grossProfit - opex
  const ebitda = ebit  // simplified, no D&A tracked yet
  const ebt = ebit - interestExpense
  const tax = ebt > 0 ? ebt * 0.22 : 0  // PPh Badan 22%
  const netIncome = ebt - tax

  pl.value = { revenue, cogs, grossProfit, grossMargin, opex, ebit, ebitda, interestExpense, ebt, tax, netIncome, poCount: (pos ?? []).length, arCount: (arData ?? []).length }
  loading.value = false
}

function fmtRp(n: number) {
  if (n < 0) return `(${new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(Math.abs(n))})`
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Laporan Laba Rugi (P&L)</h1>
        <p class="text-sm text-[#999] mt-0.5">Kinerja keuangan KSM Mitra per periode</p>
      </div>
      <div class="flex items-center gap-3">
        <select v-model="period.month" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="(m, i) in months" :key="i" :value="i+1">{{ m }}</option>
        </select>
        <select v-model="period.year" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="y in [2024,2025,2026]" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="px-4 py-2 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors" :disabled="loading" @click="load">
          {{ loading ? 'Memuat...' : 'Tampilkan' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="pl" class="grid grid-cols-1 lg:grid-cols-3 gap-5">

      <!-- P&L Statement -->
      <div class="lg:col-span-2 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]">
          <p class="text-sm font-bold text-[#1a1a1a]">Laporan Laba Rugi</p>
          <p class="text-xs text-[#999]">{{ months[period.month - 1] }} {{ period.year }}</p>
        </div>
        <div class="p-5 space-y-1 text-sm">
          <div class="flex justify-between py-1.5 border-b border-[#e5e5e5]">
            <span class="font-semibold text-[#1a1a1a]">Pendapatan (Revenue)</span>
            <span class="font-bold text-emerald-600">{{ fmtRp(pl.revenue) }}</span>
          </div>
          <div class="flex justify-between py-1.5 text-[#666] pl-4">
            <span>HPP / COGS (Pembelian ke Distributor)</span>
            <span class="text-red-600">({{ fmtRp(pl.cogs) }})</span>
          </div>
          <div class="flex justify-between py-1.5 border-b border-[#e5e5e5] font-semibold">
            <span class="text-[#1a1a1a]">Laba Kotor (Gross Profit)</span>
            <span :class="pl.grossProfit >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(pl.grossProfit) }}</span>
          </div>
          <div class="flex justify-between py-1 text-xs text-[#999] pl-4">
            <span>Gross Margin</span>
            <span>{{ pl.grossMargin.toFixed(1) }}%</span>
          </div>
          <div class="flex justify-between py-1.5 text-[#666] pl-4">
            <span>Biaya Operasional (OpEx)</span>
            <span class="text-red-600">({{ fmtRp(pl.opex) }})</span>
          </div>
          <div class="flex justify-between py-1.5 border-b border-[#e5e5e5] font-semibold">
            <span class="text-[#1a1a1a]">EBIT</span>
            <span :class="pl.ebit >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(pl.ebit) }}</span>
          </div>
          <div class="flex justify-between py-1.5 text-[#666] pl-4">
            <span>Beban Bunga Bank (SCF Interest)</span>
            <span class="text-red-600">({{ fmtRp(pl.interestExpense) }})</span>
          </div>
          <div class="flex justify-between py-1.5 border-b border-[#e5e5e5] font-semibold">
            <span class="text-[#1a1a1a]">Laba Sebelum Pajak (EBT)</span>
            <span :class="pl.ebt >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(pl.ebt) }}</span>
          </div>
          <div class="flex justify-between py-1.5 text-[#666] pl-4">
            <span>Pajak PPh Badan (22%)</span>
            <span class="text-red-600">({{ fmtRp(pl.tax) }})</span>
          </div>
          <div class="flex justify-between py-2 mt-1 rounded-lg bg-[#ebebeb] px-3 font-bold text-base">
            <span class="text-[#1a1a1a]">Laba Bersih (Net Income)</span>
            <span :class="pl.netIncome >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(pl.netIncome) }}</span>
          </div>
        </div>
      </div>

      <!-- KPIs -->
      <div class="space-y-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-xs text-[#999] mb-1">Gross Margin</p>
          <p class="text-2xl font-bold" :class="pl.grossMargin >= 10 ? 'text-emerald-600' : 'text-amber-600'">
            {{ pl.grossMargin.toFixed(1) }}%
          </p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-xs text-[#999] mb-1">Total PO Selesai</p>
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ pl.poCount }}</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-xs text-[#999] mb-1">Beban Bunga SCF</p>
          <p class="text-2xl font-bold text-red-600">{{ fmtRp(pl.interestExpense) }}</p>
          <p class="text-xs text-[#999] mt-1">{{ pl.arCount }} AR aktif periode ini</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#6b1525]/20 p-4">
          <p class="text-xs text-[#999] mb-1">Net Income</p>
          <p class="text-2xl font-bold" :class="pl.netIncome >= 0 ? 'text-emerald-600' : 'text-red-600'">
            {{ fmtRp(pl.netIncome) }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
