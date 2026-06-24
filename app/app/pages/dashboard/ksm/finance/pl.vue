<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Laporan Laba Rugi KSM' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const period = ref({ year: new Date().getFullYear(), month: new Date().getMonth() + 1 })
const loading = ref(false)
const pl = ref<any>(null)
const monthlyTrend = ref<any[]>([])

const months = [
  'Januari','Februari','Maret','April','Mei','Juni',
  'Juli','Agustus','September','Oktober','November','Desember'
]

async function load() {
  if (!tenantId.value) return
  loading.value = true
  pl.value = null

  const startDate = `${period.value.year}-${String(period.value.month).padStart(2,'0')}-01`
  const endDate   = new Date(period.value.year, period.value.month, 0).toISOString().slice(0, 10)

  const [{ data: pos }, { data: arData }] = await Promise.all([
    supabase.from('ksm_purchase_orders')
      .select('total_amount,subtotal,tax_amount,status,po_date')
      .eq('ksm_tenant_id', tenantId.value)
      .eq('status', 'fully_received')
      .gte('po_date', startDate)
      .lte('po_date', endDate),
    supabase.from('ar_accounts')
      .select('interest_amount,invoice_amount,status')
      .eq('ksm_tenant_id', tenantId.value)
      .gte('invoice_date', startDate)
      .lte('invoice_date', endDate),
  ])

  const cogsBase = (pos ?? []).reduce((s: number, po: any) => s + Number(po.subtotal ?? po.total_amount), 0)
  const cogs     = cogsBase
  const MARGIN   = 0.12
  const revenue  = cogs * (1 + MARGIN)
  const interestExpense = (arData ?? []).reduce((s: number, a: any) => s + Number(a.interest_amount ?? 0), 0)

  const grossProfit = revenue - cogs
  const grossMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0
  const opex        = revenue * 0.04 // ~4% opex estimate
  const ebit        = grossProfit - opex
  const ebt         = ebit - interestExpense
  const tax         = ebt > 0 ? ebt * 0.22 : 0
  const netIncome   = ebt - tax

  pl.value = {
    revenue, cogs, grossProfit, grossMargin,
    opex, ebit, interestExpense, ebt, tax, netIncome,
    poCount: (pos ?? []).length,
    arCount: (arData ?? []).length,
    netMargin: revenue > 0 ? (netIncome/revenue*100) : 0,
  }

  // Load 6-month trend
  await loadTrend()
  loading.value = false
}

async function loadTrend() {
  if (!tenantId.value) return
  // Get PO data for last 6 months
  const sixMonthAgo = new Date()
  sixMonthAgo.setMonth(sixMonthAgo.getMonth() - 5)
  const from = `${sixMonthAgo.getFullYear()}-${String(sixMonthAgo.getMonth()+1).padStart(2,'0')}-01`

  const { data: pos } = await supabase.from('ksm_purchase_orders')
    .select('total_amount,subtotal,po_date')
    .eq('ksm_tenant_id', tenantId.value)
    .eq('status', 'fully_received')
    .gte('po_date', from)

  const map: Record<string, { revenue: number; cogs: number }> = {}
  for (const p of pos ?? []) {
    const key = p.po_date?.slice(0, 7) ?? ''
    if (!key) continue
    if (!map[key]) map[key] = { revenue: 0, cogs: 0 }
    const c = Number(p.subtotal ?? p.total_amount)
    map[key].cogs    += c
    map[key].revenue += c * 1.12
  }
  monthlyTrend.value = Object.entries(map)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => ({ bulan: k, ...v, gp: v.revenue - v.cogs }))
}

const maxRevenue = computed(() => Math.max(...monthlyTrend.value.map(m => m.revenue), 1))

function fmtRp(n: number) {
  if (Math.abs(n) >= 1e9) return `Rp ${(n/1e9).toFixed(2)}M`
  if (Math.abs(n) >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  if (Math.abs(n) >= 1e3) return `Rp ${Math.round(n/1e3).toLocaleString('id-ID')} rb`
  return 'Rp ' + Math.round(n).toLocaleString('id-ID')
}

function monthLabel(key: string) {
  const [y, m] = key.split('-')
  const names = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']
  return names[parseInt(m)-1] + ' ' + y.slice(2)
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
          <p class="text-sm text-[#999] mt-0.5">Kinerja keuangan KSM Mitra per periode</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <select v-model="period.month" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="(m, i) in months" :key="i" :value="i+1">{{ m }}</option>
        </select>
        <select v-model="period.year" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="y in [2024,2025,2026]" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="px-4 py-2 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors disabled:opacity-60"
          :disabled="loading" @click="load">
          {{ loading ? 'Memuat...' : 'Tampilkan' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else-if="pl">
      <!-- KPI Row -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Revenue</p>
          <p class="text-xl font-bold text-emerald-700">{{ fmtRp(pl.revenue) }}</p>
          <p class="text-[10px] text-[#aaa] mt-1">{{ pl.poCount }} PO selesai</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Gross Margin</p>
          <p class="text-xl font-bold" :class="pl.grossMargin >= 10 ? 'text-emerald-700' : 'text-amber-600'">
            {{ pl.grossMargin.toFixed(1) }}%
          </p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Net Margin</p>
          <p class="text-xl font-bold" :class="pl.netMargin >= 5 ? 'text-emerald-700' : pl.netMargin >= 0 ? 'text-amber-600' : 'text-red-600'">
            {{ pl.netMargin.toFixed(1) }}%
          </p>
        </div>
        <div :class="['rounded-xl border p-4', pl.netIncome >= 0 ? 'bg-emerald-50 border-emerald-200' : 'bg-red-50 border-red-200']">
          <p class="text-[10px] text-[#999] uppercase mb-1">Laba Bersih</p>
          <p :class="['text-xl font-bold', pl.netIncome >= 0 ? 'text-emerald-700' : 'text-red-600']">
            {{ fmtRp(pl.netIncome) }}
          </p>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
        <!-- P&L Statement -->
        <div class="lg:col-span-2 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] bg-[#ebebeb]">
            <p class="text-sm font-bold text-[#1a1a1a]">Laporan Laba Rugi</p>
            <p class="text-xs text-[#999]">{{ months[period.month - 1] }} {{ period.year }}</p>
          </div>
          <div class="p-5 space-y-0 text-sm">
            <div v-for="row in [
              { label:'Pendapatan (Revenue)', val: pl.revenue, color:'text-emerald-600', bold: true, line: true },
              { label:'HPP / COGS (Pembelian ke Distributor)', val: -pl.cogs, color:'text-red-500', indent: true, line: true },
              { label:'Laba Kotor (Gross Profit)', val: pl.grossProfit, color: pl.grossProfit >= 0 ? 'text-emerald-700' : 'text-red-600', bold: true, line: true, pct: pl.grossMargin.toFixed(1)+'%' },
              { label:'Biaya Operasional (est. 4%)', val: -pl.opex, color:'text-red-400', indent: true },
              { label:'EBIT', val: pl.ebit, color: pl.ebit >= 0 ? 'text-emerald-600' : 'text-red-600', bold: true, line: true },
              { label:'Beban Bunga SCF ('+pl.arCount+' AR)', val: -pl.interestExpense, color:'text-red-500', indent: true, line: true },
              { label:'Laba Sebelum Pajak (EBT)', val: pl.ebt, color: pl.ebt >= 0 ? 'text-emerald-700' : 'text-red-600', bold: true },
              { label:'Pajak PPh Badan (22%)', val: -pl.tax, color:'text-red-400', indent: true, line: true },
            ]" :key="row.label"
              :class="['flex justify-between py-2', row.line ? 'border-b border-[#e5e5e5]', row.bold ? 'bg-[#fafafa] px-2 rounded my-0.5' : '']">
              <span :class="['text-xs', row.indent ? 'pl-5 text-[#666]' : 'font-semibold text-[#1a1a1a]']">{{ row.label }}</span>
              <div class="text-right">
                <span :class="['text-xs font-semibold', row.color]">
                  {{ row.val >= 0 ? fmtRp(row.val) : '(' + fmtRp(Math.abs(row.val)) + ')' }}
                </span>
                <span v-if="row.pct" class="text-[10px] text-[#999] ml-1">({{ row.pct }})</span>
              </div>
            </div>
            <div class="flex justify-between py-3 px-2 mt-1 rounded-lg font-bold text-base" :class="pl.netIncome >= 0 ? 'bg-emerald-50' : 'bg-red-50'">
              <span class="text-[#1a1a1a]">Laba Bersih (Net Income)</span>
              <span :class="pl.netIncome >= 0 ? 'text-emerald-600' : 'text-red-600'">
                {{ pl.netIncome >= 0 ? fmtRp(pl.netIncome) : '('+fmtRp(Math.abs(pl.netIncome))+')' }}
              </span>
            </div>
          </div>
        </div>

        <!-- Trend Chart -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] bg-[#ebebeb]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Tren Revenue 6 Bulan</p>
          </div>
          <div class="p-5">
            <div v-if="monthlyTrend.length === 0" class="flex items-center justify-center py-10 text-[#ccc] text-xs">
              Belum ada data trend
            </div>
            <div v-else>
              <div class="flex items-end gap-1.5 h-36 mb-3">
                <div v-for="m in monthlyTrend" :key="m.bulan" class="flex-1 flex flex-col items-center gap-1">
                  <div class="w-full flex flex-col gap-0.5" :style="`height: ${(m.revenue / maxRevenue) * 130}px`">
                    <!-- Gross Profit portion (top, green) -->
                    <div class="w-full rounded-t bg-emerald-400 transition-all" :style="`height: ${(m.gp / m.revenue) * 100}%`"/>
                    <!-- COGS portion (bottom, bordeaux) -->
                    <div class="w-full bg-[#6b1525] transition-all" :style="`height: ${(m.cogs / m.revenue) * 100}%`"/>
                  </div>
                  <p class="text-[8px] text-[#999] whitespace-nowrap">{{ monthLabel(m.bulan) }}</p>
                </div>
              </div>
              <div class="flex items-center gap-4 text-[10px] text-[#999]">
                <div class="flex items-center gap-1"><div class="w-2 h-2 rounded bg-emerald-400"/><span>Gross Profit</span></div>
                <div class="flex items-center gap-1"><div class="w-2 h-2 rounded bg-[#6b1525]"/><span>COGS</span></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] flex flex-col items-center justify-center py-16 gap-3">
      <UIcon name="i-lucide-bar-chart-2" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Pilih periode dan klik Tampilkan</p>
    </div>
  </div>
</template>
