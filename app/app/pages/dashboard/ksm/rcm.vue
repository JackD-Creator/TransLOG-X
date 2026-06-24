<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Revenue Cycle Management KSM' })

const supabase = useSupabaseClient()

const loading = ref(true)
const period = ref({ year: 2026, month: 2 })

const metrics = ref({
  // Revenue & Margin
  totalRevenue:       0,   // invoice amount ke RS
  totalCogs:          0,   // pembelian dari Distributor
  grossProfit:        0,
  grossMarginPct:     0,
  interestExpense:    0,
  netProfit:          0,
  netMarginPct:       0,

  // Cycle metrics
  avgCycleTimeDays:   0,   // notif → invoice
  avgDSO:             0,   // invoice → paid (Days Sales Outstanding)
  avgDPO:             0,   // PO sent → Bank paid (Days Payable Outstanding via SCF)
  cashConversionCycle:0,   // DSO - DPO (idealnya < 0)

  // Volume
  totalPOs:           0,
  totalNotifications: 0,
  fulfilmentRate:     0,   // berapa % notif yang jadi PO selesai

  // AR Health
  arCurrent:          0,   // < 30 hari
  ar30:               0,   // 30–60 hari
  ar60:               0,   // 60–90 hari
  ar90plus:           0,   // > 90 hari
  arOverdueCount:     0,
})

const months = [
  'Januari','Februari','Maret','April','Mei','Juni',
  'Juli','Agustus','September','Oktober','November','Desember'
]

async function load() {
  loading.value = true

  const startDate = `${period.value.year}-${String(period.value.month).padStart(2,'0')}-01`
  const endDate   = new Date(period.value.year, period.value.month, 0).toISOString().slice(0, 10)
  const today     = new Date().toISOString().slice(0, 10)

  const [{ data: arData }, { data: poData }, { data: notifData }] = await Promise.all([
    supabase.from('ar_accounts').select('*').gte('invoice_date', startDate).lte('invoice_date', endDate),
    supabase.from('ksm_purchase_orders').select('*').gte('po_date', startDate).lte('po_date', endDate),
    supabase.from('hospital_notifications').select('*').gte('notif_date', startDate).lte('notif_date', endDate),
  ])

  const ar = arData ?? []
  const po = poData ?? []
  const notif = notifData ?? []

  // Revenue
  const totalRevenue   = ar.reduce((s, a) => s + Number(a.invoice_amount ?? 0), 0)
  const totalCogs      = po.reduce((s, p) => s + Number(p.total_amount ?? 0), 0)
  const interestExp    = ar.reduce((s, a) => s + Number(a.interest_amount ?? 0), 0)
  const grossProfit    = totalRevenue - totalCogs
  const grossMarginPct = totalRevenue > 0 ? (grossProfit / totalRevenue * 100) : 0
  const netProfit      = grossProfit - interestExp
  const netMarginPct   = totalRevenue > 0 ? (netProfit / totalRevenue * 100) : 0

  // DSO: avg days dari invoice_date ke paid_date
  const paidAR = ar.filter(a => a.status === 'paid' && a.paid_date && a.invoice_date)
  const avgDSO = paidAR.length > 0
    ? paidAR.reduce((s, a) => {
        const diff = (new Date(a.paid_date).getTime() - new Date(a.invoice_date).getTime()) / 86400000
        return s + diff
      }, 0) / paidAR.length
    : 0

  // DPO: avg days dari po_date ke disbursement_date (Bank cair ke Distributor)
  const disbAR = ar.filter(a => a.disbursement_date && a.invoice_date)
  const avgDPO = disbAR.length > 0
    ? disbAR.reduce((s, a) => {
        const diff = (new Date(a.disbursement_date).getTime() - new Date(a.invoice_date).getTime()) / 86400000
        return s + diff
      }, 0) / disbAR.length
    : 0

  // Fulfilment rate: notif yang sudah completed / total notif
  const completedNotif = notif.filter(n => n.status === 'completed').length
  const fulfilmentRate = notif.length > 0 ? (completedNotif / notif.length * 100) : 0

  // AR Aging (berdasarkan due_date vs today)
  const arCurrent = ar.filter(a => {
    const days = (new Date(today).getTime() - new Date(a.due_date).getTime()) / 86400000
    return days <= 0 && !['paid','defaulted'].includes(a.status)
  }).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)
  const ar30 = ar.filter(a => {
    const days = (new Date(today).getTime() - new Date(a.due_date).getTime()) / 86400000
    return days > 0 && days <= 30 && !['paid','defaulted'].includes(a.status)
  }).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)
  const ar60 = ar.filter(a => {
    const days = (new Date(today).getTime() - new Date(a.due_date).getTime()) / 86400000
    return days > 30 && days <= 60 && !['paid','defaulted'].includes(a.status)
  }).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)
  const ar90plus = ar.filter(a => {
    const days = (new Date(today).getTime() - new Date(a.due_date).getTime()) / 86400000
    return days > 60 && !['paid','defaulted'].includes(a.status)
  }).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)

  metrics.value = {
    totalRevenue, totalCogs, grossProfit, grossMarginPct,
    interestExpense: interestExp, netProfit, netMarginPct,
    avgCycleTimeDays: 0, avgDSO, avgDPO,
    cashConversionCycle: avgDSO - avgDPO,
    totalPOs: po.length,
    totalNotifications: notif.length,
    fulfilmentRate,
    arCurrent, ar30, ar60, ar90plus,
    arOverdueCount: ar.filter(a => a.status === 'overdue').length,
  }

  loading.value = false
}



onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Revenue Cycle Management</h1>
        <p class="text-sm text-[#999] mt-0.5">Analisis siklus pendapatan, margin, dan efisiensi working capital KSM</p>
      </div>
      <div class="flex items-center gap-3">
        <select v-model="period.month" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="(m, i) in months" :key="i" :value="i+1">{{ m }}</option>
        </select>
        <select v-model="period.year" class="px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-xs text-[#1a1a1a] outline-none">
          <option v-for="y in [2024,2025,2026]" :key="y" :value="y">{{ y }}</option>
        </select>
        <button class="px-4 py-2 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors" :disabled="loading" @click="load">
          {{ loading ? '...' : 'Tampilkan' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-5">

      <!-- Revenue Waterfall -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5]">
            <p class="text-sm font-bold text-[#1a1a1a]">Revenue Waterfall</p>
            <p class="text-xs text-[#999]">{{ months[period.month - 1] }} {{ period.year }}</p>
          </div>
          <div class="p-5 space-y-2 text-sm">
            <div class="flex justify-between py-2 border-b border-[#e5e5e5]">
              <span class="text-[#666]">Revenue (Penjualan ke RS)</span>
              <span class="font-bold text-emerald-600">{{ fmtRp(metrics.totalRevenue) }}</span>
            </div>
            <div class="flex justify-between py-2">
              <span class="text-[#666] pl-3">HPP (Beli dari Distributor)</span>
              <span class="text-red-600">({{ fmtRp(metrics.totalCogs) }})</span>
            </div>
            <div class="flex justify-between py-2 border-b border-[#e5e5e5] font-semibold">
              <span class="text-[#1a1a1a]">Gross Profit</span>
              <span :class="metrics.grossProfit >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(metrics.grossProfit) }}</span>
            </div>
            <div class="flex justify-between py-1 text-xs text-[#999] pl-3">
              <span>Gross Margin</span>
              <span class="font-bold" :class="metrics.grossMarginPct >= 10 ? 'text-emerald-600' : 'text-amber-600'">{{ metrics.grossMarginPct.toFixed(1) }}%</span>
            </div>
            <div class="flex justify-between py-2">
              <span class="text-[#666] pl-3">Bunga SCF / Bank</span>
              <span class="text-red-600">({{ fmtRp(metrics.interestExpense) }})</span>
            </div>
            <div class="flex justify-between py-2.5 bg-[#ebebeb] rounded-lg px-3 font-bold">
              <span class="text-[#1a1a1a]">Net Profit (Est.)</span>
              <span :class="metrics.netProfit >= 0 ? 'text-emerald-600' : 'text-red-600'">{{ fmtRp(metrics.netProfit) }}</span>
            </div>
            <div class="text-xs text-[#999] text-right">Net Margin: <span class="font-bold" :class="metrics.netMarginPct >= 5 ? 'text-emerald-600' : 'text-amber-600'">{{ metrics.netMarginPct.toFixed(1) }}%</span></div>
          </div>
        </div>

        <!-- Cycle Metrics -->
        <div class="space-y-3">
          <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
            <p class="text-xs font-bold text-[#1a1a1a] uppercase tracking-wide mb-3">Siklus Kas (Cash Conversion)</p>
            <div class="grid grid-cols-3 gap-3 text-center">
              <div>
                <p class="text-2xl font-bold text-blue-600">{{ metrics.avgDSO.toFixed(0) }}</p>
                <p class="text-[10px] text-[#999] mt-0.5">hari DSO</p>
                <p class="text-[10px] text-[#666]">Invoice → RS Bayar</p>
              </div>
              <div>
                <p class="text-2xl font-bold text-purple-600">{{ metrics.avgDPO.toFixed(0) }}</p>
                <p class="text-[10px] text-[#999] mt-0.5">hari DPO</p>
                <p class="text-[10px] text-[#666]">Invoice → Bank Cair</p>
              </div>
              <div>
                <p class="text-2xl font-bold" :class="metrics.cashConversionCycle <= 0 ? 'text-emerald-600' : 'text-red-600'">
                  {{ metrics.cashConversionCycle.toFixed(0) }}
                </p>
                <p class="text-[10px] text-[#999] mt-0.5">hari CCC</p>
                <p class="text-[10px] text-[#666]">{{ metrics.cashConversionCycle <= 0 ? '✓ Cash positive' : '⚠ Cash negative' }}</p>
              </div>
            </div>
            <p class="text-[10px] text-[#999] mt-3">CCC = DSO − DPO. Negatif berarti Bank bayar Distributor sebelum RS bayar KSM → working capital efisien.</p>
          </div>

          <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
            <p class="text-xs font-bold text-[#1a1a1a] uppercase tracking-wide mb-3">Operasional</p>
            <div class="grid grid-cols-3 gap-3 text-center">
              <div>
                <p class="text-2xl font-bold text-[#1a1a1a]">{{ metrics.totalNotifications }}</p>
                <p class="text-[10px] text-[#999] mt-0.5">Notif Masuk</p>
              </div>
              <div>
                <p class="text-2xl font-bold text-[#1a1a1a]">{{ metrics.totalPOs }}</p>
                <p class="text-[10px] text-[#999] mt-0.5">PO Dibuat</p>
              </div>
              <div>
                <p class="text-2xl font-bold" :class="metrics.fulfilmentRate >= 90 ? 'text-emerald-600' : 'text-amber-600'">
                  {{ metrics.fulfilmentRate.toFixed(0) }}%
                </p>
                <p class="text-[10px] text-[#999] mt-0.5">Fulfilment Rate</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- AR Aging -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <div class="flex items-center justify-between mb-4">
          <p class="text-sm font-bold text-[#1a1a1a]">AR Aging — Analisis Umur Piutang ke Bank</p>
          <span v-if="metrics.arOverdueCount > 0" class="text-xs text-red-600 font-semibold">
            {{ metrics.arOverdueCount }} overdue
          </span>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div class="bg-emerald-50 rounded-xl p-4 border border-emerald-100">
            <p class="text-xs text-emerald-700 font-semibold mb-1">Current (Belum Jatuh)</p>
            <p class="text-xl font-bold text-emerald-700">{{ fmtRp(metrics.arCurrent) }}</p>
          </div>
          <div class="bg-amber-50 rounded-xl p-4 border border-amber-100">
            <p class="text-xs text-amber-700 font-semibold mb-1">1–30 Hari</p>
            <p class="text-xl font-bold text-amber-700">{{ fmtRp(metrics.ar30) }}</p>
          </div>
          <div class="bg-orange-50 rounded-xl p-4 border border-orange-100">
            <p class="text-xs text-orange-700 font-semibold mb-1">31–60 Hari</p>
            <p class="text-xl font-bold text-orange-700">{{ fmtRp(metrics.ar60) }}</p>
          </div>
          <div class="bg-red-50 rounded-xl p-4 border border-red-100">
            <p class="text-xs text-red-700 font-semibold mb-1">&gt;60 Hari</p>
            <p class="text-xl font-bold text-red-700">{{ fmtRp(metrics.ar90plus) }}</p>
          </div>
        </div>

        <!-- Aging bar -->
        <div class="mt-4">
          <div class="flex h-3 rounded-full overflow-hidden gap-0.5">
            <div v-if="(metrics.arCurrent + metrics.ar30 + metrics.ar60 + metrics.ar90plus) > 0"
              class="bg-emerald-500 transition-all"
              :style="`width:${metrics.arCurrent / (metrics.arCurrent + metrics.ar30 + metrics.ar60 + metrics.ar90plus) * 100}%`"/>
            <div class="bg-amber-400 transition-all"
              :style="`width:${metrics.ar30 / (metrics.arCurrent + metrics.ar30 + metrics.ar60 + metrics.ar90plus || 1) * 100}%`"/>
            <div class="bg-orange-500 transition-all"
              :style="`width:${metrics.ar60 / (metrics.arCurrent + metrics.ar30 + metrics.ar60 + metrics.ar90plus || 1) * 100}%`"/>
            <div class="bg-red-600 transition-all"
              :style="`width:${metrics.ar90plus / (metrics.arCurrent + metrics.ar30 + metrics.ar60 + metrics.ar90plus || 1) * 100}%`"/>
          </div>
          <div class="flex justify-between text-[10px] text-[#999] mt-1">
            <span class="text-emerald-600">■ Current</span>
            <span class="text-amber-600">■ 1–30 hari</span>
            <span class="text-orange-600">■ 31–60 hari</span>
            <span class="text-red-600">■ &gt;60 hari</span>
          </div>
        </div>
      </div>

      <!-- Insight box -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#6b1525]/20 p-5">
        <div class="flex items-start gap-3">
          <UIcon name="i-lucide-lightbulb" class="text-[#6b1525] text-xl flex-shrink-0 mt-0.5"/>
          <div class="text-xs text-[#666] space-y-1.5">
            <p class="font-bold text-[#1a1a1a] text-sm">Insight Revenue Cycle KSM</p>
            <p v-if="metrics.grossMarginPct < 5" class="text-amber-700">
              ⚠ Gross margin <5% — terlalu tipis. Negosiasi harga distributor lebih agresif atau naikkan sell price ke RS hingga mendekati HET.
            </p>
            <p v-if="metrics.interestExpense > metrics.grossProfit * 0.3" class="text-red-700">
              ⚠ Beban bunga >30% dari gross profit — SCF menggerus margin. Pertimbangkan tenor lebih pendek atau cari Bank dengan bunga lebih rendah.
            </p>
            <p v-if="metrics.cashConversionCycle > 30" class="text-amber-700">
              ⚠ Cash Conversion Cycle tinggi ({{ metrics.cashConversionCycle.toFixed(0) }} hari) — RS lambat bayar. Negosiasi DP atau percepat penagihan.
            </p>
            <p v-if="metrics.ar90plus > 0" class="text-red-700">
              ⚠ Ada AR >60 hari ({{ fmtRp(metrics.ar90plus) }}) — risiko gagal bayar. Prioritaskan penagihan ke Bank.
            </p>
            <p v-if="metrics.netMarginPct >= 8" class="text-emerald-700">
              ✓ Net margin {{ metrics.netMarginPct.toFixed(1) }}% — bisnis sehat. Target optimal 8–12% net margin untuk KSM.
            </p>
            <p v-if="metrics.totalRevenue === 0" class="text-[#999]">
              Belum ada data transaksi di periode ini. Pilih periode dengan aktivitas untuk melihat analisis.
            </p>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>
