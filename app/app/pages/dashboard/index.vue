<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const { portalType, tenantName, tenantId, isKSM, isDistributor, isBank, isRS, loading: roleLoading } = useUserRole()

const loading = ref(true)
const kpi = ref<any>(null)
const trends = ref<any[]>([])
const forecast = ref<any[]>([])
const riskScores = ref<any[]>([])
const demandData = ref<any[]>([])
const recentPOs = ref<any[]>([])
const recentAR = ref<any[]>([])
const recentNotifs = ref<any[]>([])
const recentInvoices = ref<any[]>([])

const now = new Date()
const greeting = now.getHours() < 12 ? 'Selamat Pagi' : now.getHours() < 15 ? 'Selamat Siang' : now.getHours() < 19 ? 'Selamat Sore' : 'Selamat Malam'
const todayStr = now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const displayName = computed(() => {
  const email = user.value?.email ?? ''
  return email.split('@')[0].replace(/\./g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase()) || 'Admin'
})

async function loadDashboard() {
  if (!tenantId.value) return
  loading.value = true

  if (isKSM.value) {
    const [kpiRes, trendRes, fcRes, riskRes, demRes, { data: pos }, { data: ar }, { data: notifs }, { data: inv }] = await Promise.all([
      supabase.rpc('get_ksm_dashboard_kpi', { p_ksm_tenant_id: tenantId.value }),
      supabase.rpc('get_monthly_trends', { p_ksm_tenant_id: tenantId.value, p_months: 6 }),
      supabase.rpc('forecast_next_months', { p_ksm_tenant_id: tenantId.value, p_forecast_months: 3 }),
      supabase.rpc('get_rs_risk_scores', { p_ksm_tenant_id: tenantId.value }),
      supabase.rpc('get_demand_analysis', { p_ksm_tenant_id: tenantId.value }),
      supabase.from('ksm_purchase_orders').select('id,po_number,po_date,status,total_amount,metadata')
        .eq('ksm_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(5),
      supabase.from('ar_accounts').select('id,ar_number,disbursed_amount,outstanding_amount,due_date,status')
        .eq('ksm_tenant_id', tenantId.value).neq('status', 'paid').order('due_date').limit(5),
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,metadata')
        .eq('ksm_tenant_id', tenantId.value).eq('status', 'pending').order('notif_date', { ascending: false }).limit(4),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,outstanding,status,due_date,metadata')
        .eq('ksm_tenant_id', tenantId.value).order('invoice_date', { ascending: false }).limit(5),
    ])
    kpi.value = kpiRes.data; trends.value = trendRes.data ?? []; forecast.value = fcRes.data ?? []
    riskScores.value = riskRes.data ?? []; demandData.value = demRes.data ?? []
    recentPOs.value = pos ?? []; recentAR.value = ar ?? []; recentNotifs.value = notifs ?? []; recentInvoices.value = inv ?? []
  } else if (isBank.value) {
    const [{ data: fac }, { data: ar }, { data: inv }] = await Promise.all([
      supabase.from('scf_facilities').select('facility_limit,outstanding,status').eq('status', 'approved'),
      supabase.from('ar_accounts').select('id,ar_number,disbursed_amount,outstanding_amount,interest_amount,due_date,status').order('due_date').limit(8),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,status,shortfall_amount,shortfall_covered_by_bank').in('status', ['sent_to_rs','payment_pending','partially_paid','overdue']).limit(5),
    ])
    const f = fac ?? []
    kpi.value = { total_limit: f.reduce((s: number, x: any) => s + Number(x.facility_limit), 0), total_outstanding: f.reduce((s: number, x: any) => s + Number(x.outstanding), 0), total_disbursed: (ar ?? []).reduce((s: number, a: any) => s + Number(a.disbursed_amount ?? 0), 0), total_interest: (ar ?? []).reduce((s: number, a: any) => s + Number(a.interest_amount ?? 0), 0), overdue_count: (ar ?? []).filter((a: any) => a.status === 'overdue').length, shortfall_total: (inv ?? []).filter((i: any) => i.shortfall_covered_by_bank).reduce((s: number, i: any) => s + Number(i.shortfall_amount ?? 0), 0), facility_count: f.length, pending_invoices: (inv ?? []).length }
    recentAR.value = ar ?? []
  } else if (isDistributor.value) {
    const { data: pos } = await supabase.from('ksm_purchase_orders').select('id,po_number,po_date,status,total_amount,metadata').eq('supplier_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(8)
    const all = pos ?? []
    kpi.value = { need_confirm: all.filter((p: any) => p.status === 'submitted').length, shipping: all.filter((p: any) => p.status === 'sent_to_supplier').length, completed: all.filter((p: any) => ['fully_received','partially_received'].includes(p.status)).length, total_value: all.reduce((s: number, p: any) => s + Number(p.total_amount), 0) }
    recentPOs.value = all
  } else if (isRS.value) {
    const [{ data: notifs }, { data: inv }, { data: pos }] = await Promise.all([
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,ksm_confirmation_status,metadata').eq('rs_tenant_id', tenantId.value).order('notif_date', { ascending: false }).limit(4),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,outstanding,status,due_date').eq('rs_tenant_id', tenantId.value).order('due_date').limit(5),
      supabase.from('ksm_purchase_orders').select('id,po_number,status,total_amount,metadata').eq('rs_tenant_id', tenantId.value).in('status', ['sent_to_supplier','partially_received']).limit(4),
    ])
    kpi.value = { pending_confirm: (notifs ?? []).filter((n: any) => n.ksm_confirmation_status === 'pending_rs_approval').length, active_alerts: (notifs ?? []).filter((n: any) => n.status === 'pending').length, pending_delivery: (pos ?? []).length, outstanding_invoice: (inv ?? []).reduce((s: number, i: any) => s + Number(i.outstanding ?? 0), 0) }
    recentNotifs.value = notifs ?? []; recentPOs.value = pos ?? []; recentInvoices.value = inv ?? []
  }
  loading.value = false
}

// ── Chart configs ──────────────────────────────────────────────────────────
const chartTheme = { palette: 'palette1', monochrome: { enabled: false } }
const darkText = '#1a1a1a'
const muted = '#999'
const bordeaux = '#6b1525'

const revenueChartOpts = computed(() => ({
  chart: { type: 'area', height: 220, toolbar: { show: false }, sparkline: { enabled: false }, fontFamily: 'inherit' },
  colors: [bordeaux, '#e5c4cb'],
  stroke: { curve: 'smooth', width: [3, 2] },
  fill: { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.4, opacityTo: 0.05, stops: [0, 100] } },
  dataLabels: { enabled: false },
  xaxis: { categories: trends.value.map((t: any) => t.month_label), labels: { style: { colors: muted, fontSize: '10px' } } },
  yaxis: { labels: { style: { colors: muted, fontSize: '10px' }, formatter: (v: number) => v >= 1e9 ? `${(v/1e9).toFixed(1)}M` : v >= 1e6 ? `${(v/1e6).toFixed(0)}jt` : `${v}` } },
  grid: { borderColor: '#f0f0f0', strokeDashArray: 4 },
  tooltip: { y: { formatter: (v: number) => fmtRp(v) } },
  legend: { show: true, position: 'top', horizontalAlign: 'right', fontSize: '10px' },
}))
const revenueChartSeries = computed(() => [
  { name: 'Revenue (Invoice RS)', data: trends.value.map((t: any) => Number(t.revenue ?? 0)) },
  { name: 'COGS (Bank→Dist)', data: trends.value.map((t: any) => Number(t.cogs ?? 0)) },
])

const scfDonutOpts = computed(() => ({
  chart: { type: 'donut', height: 200, fontFamily: 'inherit' },
  colors: [bordeaux, '#e0e0e0'],
  labels: ['Terpakai', 'Sisa Limit'],
  plotOptions: { pie: { donut: { size: '70%', labels: { show: true, total: { show: true, label: 'Utilisasi', fontSize: '10px', color: muted, formatter: () => `${kpi.value?.scf_limit > 0 ? ((kpi.value.scf_outstanding/kpi.value.scf_limit)*100).toFixed(1) : 0}%` } } } } },
  dataLabels: { enabled: false },
  legend: { show: false },
  stroke: { width: 0 },
}))
const scfDonutSeries = computed(() => [Number(kpi.value?.scf_outstanding ?? 0), Math.max(0, Number(kpi.value?.scf_limit ?? 0) - Number(kpi.value?.scf_outstanding ?? 0))])

const demandBarOpts = computed(() => ({
  chart: { type: 'bar', height: 200, toolbar: { show: false }, fontFamily: 'inherit' },
  colors: [bordeaux],
  plotOptions: { bar: { horizontal: true, borderRadius: 3, barHeight: '60%' } },
  xaxis: { labels: { style: { fontSize: '9px', colors: muted } } },
  yaxis: { labels: { style: { fontSize: '9px', colors: darkText }, maxWidth: 150 } },
  grid: { borderColor: '#f5f5f5' },
  dataLabels: { enabled: false },
  tooltip: { y: { formatter: (v: number) => `${v.toLocaleString('id-ID')} unit` } },
}))
const demandBarSeries = computed(() => [{
  name: 'Demand',
  data: demandData.value.slice(0, 8).map((d: any) => ({ x: String(d.item_name).substring(0, 25), y: Number(d.total_requested) }))
}])

const grossMargin = computed(() => { const r = Number(kpi.value?.revenue_total ?? 0), c = Number(kpi.value?.bank_to_dist_total ?? 0); return r > 0 ? ((r-c)/r*100) : 0 })
const collectionRate = computed(() => { const r = Number(kpi.value?.revenue_total ?? 0), o = Number(kpi.value?.outstanding_from_rs ?? 0); return r > 0 ? ((r-o)/r*100) : 0 })
const scfUtil = computed(() => Number(kpi.value?.scf_limit) > 0 ? (Number(kpi.value?.scf_outstanding)/Number(kpi.value?.scf_limit)*100) : 0)

const poStatusColor: Record<string, string> = { draft: 'bg-[#e5e5e5] text-[#999]', submitted: 'bg-blue-500/10 text-blue-700', approved: 'bg-purple-500/10 text-purple-700', sent_to_supplier: 'bg-amber-500/10 text-amber-700', partially_received: 'bg-orange-500/10 text-orange-700', fully_received: 'bg-emerald-500/10 text-emerald-700' }

watch(tenantId, (id) => { if (id) loadDashboard() })
onMounted(() => { if (tenantId.value) loadDashboard() })
</script>

<template>
  <div v-if="roleLoading || loading" class="flex items-center justify-center py-20">
    <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
  </div>

  <div v-else class="space-y-4">

    <!-- ═══ KSM DASHBOARD ═══════════════════════════════════════════════════ -->
    <template v-if="isKSM && kpi">
      <!-- Hero -->
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div>
          <p class="text-[#555] text-xs">{{ greeting }},</p>
          <h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1>
          <p class="text-[#444] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p>
        </div>
        <div class="flex items-center gap-8">
          <div class="text-right">
            <p class="text-[#555] text-[10px] uppercase tracking-wider">Revenue Total</p>
            <p class="text-white text-2xl font-bold mt-0.5">{{ fmtRp(kpi.revenue_total) }}</p>
          </div>
          <div class="h-10 w-px bg-[#333]"/>
          <div class="text-right">
            <p class="text-[#555] text-[10px] uppercase tracking-wider">Bulan Ini</p>
            <p class="text-emerald-400 text-lg font-bold mt-0.5">{{ fmtRp(kpi.revenue_this_month) }}</p>
          </div>
          <div class="h-10 w-px bg-[#333]"/>
          <div class="text-right">
            <p class="text-[#555] text-[10px] uppercase tracking-wider">Gross Margin</p>
            <p :class="['text-lg font-bold mt-0.5', grossMargin >= 8 ? 'text-emerald-400' : 'text-amber-400']">{{ fmtPct(grossMargin) }}</p>
          </div>
        </div>
      </div>

      <!-- KPI Row -->
      <div class="grid grid-cols-4 md:grid-cols-8 gap-2">
        <NuxtLink v-for="m in [
          { to: '/dashboard/ksm/invoices', label: 'Invoice', value: kpi.total_invoices, color: 'emerald' },
          { to: '/dashboard/ksm/purchase-orders', label: 'PO Aktif', value: kpi.active_pos, color: 'blue' },
          { to: '/dashboard/ksm/notifications', label: 'Alert', value: kpi.pending_notifs, color: 'amber' },
          { to: '/dashboard/ksm/notifications', label: 'Tunggu RS', value: kpi.pending_rs_approval, color: 'purple' },
          { to: '/dashboard/ksm/ar', label: 'Overdue', value: kpi.overdue_invoices, color: 'red' },
        ]" :key="m.label" :to="m.to"
          class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:shadow-sm transition-all group">
          <p class="text-[8px] text-[#999] uppercase tracking-wider">{{ m.label }}</p>
          <p class="text-lg font-bold text-[#1a1a1a] mt-1 group-hover:text-[#6b1525] transition-colors">{{ m.value }}</p>
        </NuxtLink>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-3">
          <p class="text-[8px] text-[#999] uppercase tracking-wider">Collection</p>
          <p :class="['text-lg font-bold mt-1', collectionRate >= 70 ? 'text-emerald-600' : 'text-red-600']">{{ fmtPct(collectionRate) }}</p>
        </div>
        <NuxtLink to="/dashboard/ksm/ar" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:shadow-sm group">
          <p class="text-[8px] text-[#999] uppercase tracking-wider">Piutang RS</p>
          <p class="text-sm font-bold text-amber-600 mt-1">{{ fmtRp(kpi.outstanding_from_rs) }}</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/payments" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:shadow-sm group">
          <p class="text-[8px] text-[#999] uppercase tracking-wider">Shortfall</p>
          <p class="text-sm font-bold mt-1" :class="Number(kpi.total_shortfall) > 0 ? 'text-red-600' : 'text-emerald-600'">{{ fmtRp(kpi.total_shortfall) }}</p>
        </NuxtLink>
      </div>

      <!-- Charts Row -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Revenue Area Chart -->
        <div class="lg:col-span-2 bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <div>
              <p class="text-xs font-bold text-[#1a1a1a]">Revenue vs COGS — 6 Bulan</p>
              <p class="text-[10px] text-[#999]">Revenue = Invoice RS · COGS = Disbursement Bank ke Distributor</p>
            </div>
            <NuxtLink to="/dashboard/ksm/finance/pl" class="text-[10px] text-[#6b1525] font-semibold hover:underline">P&L →</NuxtLink>
          </div>
          <div class="px-3 pt-2">
            <ClientOnly>
              <apexchart v-if="trends.length > 0" type="area" :options="revenueChartOpts" :series="revenueChartSeries" height="220"/>
              <p v-else class="text-center text-xs text-[#ccc] py-16">Belum ada data</p>
            </ClientOnly>
          </div>
        </div>

        <!-- SCF Donut -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]">
            <p class="text-xs font-bold text-[#1a1a1a]">Utilisasi SCF</p>
            <p class="text-[10px] text-[#999]">Fasilitas Bank — Reverse Factoring</p>
          </div>
          <div class="p-3 flex flex-col items-center">
            <ClientOnly>
              <apexchart type="donut" :options="scfDonutOpts" :series="scfDonutSeries" height="200"/>
            </ClientOnly>
            <div class="grid grid-cols-2 gap-4 text-center mt-2 w-full px-4">
              <div>
                <p class="text-[10px] text-[#999]">Outstanding</p>
                <p class="text-xs font-bold text-[#6b1525]">{{ fmtRp(kpi.scf_outstanding) }}</p>
              </div>
              <div>
                <p class="text-[10px] text-[#999]">Sisa Limit</p>
                <p class="text-xs font-bold text-emerald-600">{{ fmtRp(Number(kpi.scf_limit) - Number(kpi.scf_outstanding)) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Financial Dark Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-[#555] uppercase">Hutang SCF Bank</p>
            <div class="w-5 h-5 rounded-full bg-blue-500/10 flex items-center justify-center"><UIcon name="i-lucide-landmark" class="text-blue-400 text-[10px]"/></div>
          </div>
          <p class="text-white text-lg font-bold">{{ fmtRp(kpi.hutang_bank) }}</p>
          <p class="text-[9px] text-[#444] mt-1">Bank→Dist: {{ fmtRp(kpi.bank_to_dist_total) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-[#555] uppercase">Overdue</p>
            <div class="w-5 h-5 rounded-full bg-red-500/10 flex items-center justify-center"><UIcon name="i-lucide-alert-circle" class="text-red-400 text-[10px]"/></div>
          </div>
          <p :class="['text-lg font-bold', Number(kpi.overdue_amount) > 0 ? 'text-red-400' : 'text-emerald-400']">{{ fmtRp(kpi.overdue_amount) }}</p>
          <p class="text-[9px] text-[#444] mt-1">{{ kpi.overdue_invoices }} invoice</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-[#555] uppercase">Total PO Value</p>
            <div class="w-5 h-5 rounded-full bg-purple-500/10 flex items-center justify-center"><UIcon name="i-lucide-shopping-cart" class="text-purple-400 text-[10px]"/></div>
          </div>
          <p class="text-white text-lg font-bold">{{ fmtRp(kpi.po_total_value) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-[#555] uppercase">Bunga KSM 50%</p>
            <div class="w-5 h-5 rounded-full bg-amber-500/10 flex items-center justify-center"><UIcon name="i-lucide-percent" class="text-amber-400 text-[10px]"/></div>
          </div>
          <p class="text-amber-400 text-lg font-bold">{{ fmtRp(kpi.total_daily_interest_ksm) }}</p>
        </div>
      </div>

      <!-- Risk + Demand + Forecast -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- RS Risk -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">RS Risk Score</p>
            <NuxtLink to="/dashboard/ksm/analytics" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Detail</NuxtLink>
          </div>
          <div v-if="riskScores.length === 0" class="p-5 text-center text-xs text-[#ccc]">No data</div>
          <div v-else class="divide-y divide-[#f5f5f5]">
            <div v-for="rs in riskScores.slice(0, 5)" :key="rs.rs_tenant_id" class="px-5 py-2.5 flex items-center gap-3">
              <div :class="['w-1.5 h-6 rounded-full', rs.risk_score === 'HIGH' ? 'bg-red-500' : rs.risk_score === 'MEDIUM' ? 'bg-amber-500' : 'bg-emerald-500']"/>
              <div class="flex-1 min-w-0">
                <p class="text-[11px] font-semibold text-[#1a1a1a] truncate">{{ rs.rs_name }}</p>
                <p class="text-[9px] text-[#999]">{{ rs.total_invoices }} inv</p>
              </div>
              <p class="text-xs font-bold" :class="Number(rs.collection_rate) >= 70 ? 'text-emerald-600' : 'text-red-600'">{{ rs.collection_rate }}%</p>
            </div>
          </div>
        </div>

        <!-- Top Demand Bar Chart -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]">
            <p class="text-xs font-bold text-[#1a1a1a]">Top Demand Items</p>
            <p class="text-[10px] text-[#999]">Paling banyak diminta RS</p>
          </div>
          <div class="px-2">
            <ClientOnly>
              <apexchart v-if="demandData.length > 0" type="bar" :options="demandBarOpts" :series="demandBarSeries" height="200"/>
              <p v-else class="text-center text-xs text-[#ccc] py-12">No data</p>
            </ClientOnly>
          </div>
        </div>

        <!-- Forecast -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]">
            <p class="text-xs font-bold text-[#1a1a1a]">Prediksi Revenue</p>
            <p class="text-[10px] text-[#999]">WMA + Growth Trend</p>
          </div>
          <div class="p-5 space-y-4">
            <div v-for="f in forecast" :key="f.month" class="flex items-center gap-3">
              <p class="text-xs font-semibold text-[#666] w-14">{{ f.month_label }}</p>
              <div class="flex-1">
                <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(f.predicted_revenue) }}</p>
                <div class="w-full bg-[#f0f0f0] rounded-full h-1.5 mt-1">
                  <div class="bg-[#6b1525]/60 h-1.5 rounded-full transition-all" :style="`width:${f.confidence==='high'?85:f.confidence==='medium'?60:35}%`"/>
                </div>
              </div>
              <span :class="['px-1.5 py-0.5 rounded text-[8px] font-bold', f.confidence==='high'?'bg-emerald-100 text-emerald-700':f.confidence==='medium'?'bg-amber-100 text-amber-700':'bg-[#f0f0f0] text-[#999]']">{{ f.confidence }}</span>
            </div>
            <NuxtLink to="/dashboard/ksm/analytics" class="block text-center text-[10px] text-[#6b1525] font-semibold hover:underline pt-2">AI Intelligence →</NuxtLink>
          </div>
        </div>
      </div>

      <!-- Recent Tables -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div v-for="section in [
          { title: 'PO Terbaru', link: '/dashboard/ksm/purchase-orders', items: recentPOs, type: 'po' },
          { title: 'Invoice Terbaru', link: '/dashboard/ksm/invoices', items: recentInvoices, type: 'inv' },
          { title: 'Hutang SCF Bank', link: '/dashboard/ksm/scf', items: recentAR, type: 'ar' },
        ]" :key="section.title" class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">{{ section.title }}</p>
            <NuxtLink :to="section.link" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink>
          </div>
          <div v-if="section.items.length === 0" class="p-5 text-center text-xs text-[#ccc]">Kosong</div>
          <div v-else class="divide-y divide-[#f5f5f5]">
            <component :is="section.type === 'ar' ? 'div' : 'NuxtLink'"
              v-for="item in section.items" :key="item.id"
              :to="section.type === 'po' ? `/dashboard/ksm/purchase-orders/${item.id}` : section.link"
              class="px-5 py-2 flex items-center justify-between hover:bg-[#fafafa] transition-colors block">
              <div class="min-w-0">
                <p class="text-[11px] font-mono font-semibold text-[#1a1a1a] truncate">{{ item.po_number ?? item.invoice_number ?? item.ar_number }}</p>
                <p class="text-[9px] text-[#999] truncate">{{ item.metadata?.rs_name ?? (section.type === 'ar' ? 'JT: ' + fmtDate(item.due_date) : '') }}</p>
              </div>
              <div class="text-right flex-shrink-0 ml-2">
                <p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(item.total_amount ?? item.outstanding_amount ?? item.disbursed_amount) }}</p>
                <span v-if="item.status" :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold', poStatusColor[item.status] ?? 'bg-[#f0f0f0] text-[#999]']">{{ item.status }}</span>
              </div>
            </component>
          </div>
        </div>
      </div>

      <!-- Alert SIMRS -->
      <div v-if="recentNotifs.length > 0" class="bg-[#6b1525]/5 border border-[#6b1525]/20 rounded-xl overflow-hidden">
        <div class="px-5 py-3 border-b border-[#6b1525]/10 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="w-2 h-2 rounded-full bg-red-500 animate-pulse"/>
            <p class="text-xs font-bold text-[#6b1525]">Alert SIMRS — Perlu Tindakan</p>
          </div>
          <NuxtLink to="/dashboard/ksm/notifications" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Buka Semua</NuxtLink>
        </div>
        <div class="divide-y divide-[#6b1525]/10">
          <NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/ksm/notifications"
            class="px-5 py-3 flex items-center gap-3 hover:bg-[#6b1525]/5 transition-colors block">
            <UIcon name="i-lucide-bell-ring" :class="n.metadata?.urgency === 'critical' ? 'text-red-600 animate-pulse' : 'text-amber-600'" class="text-sm flex-shrink-0"/>
            <div class="flex-1">
              <p class="text-xs font-semibold text-[#1a1a1a]">{{ n.metadata?.rs_name ?? n.notif_number }}</p>
              <p class="text-[9px] text-[#999]">{{ fmtDate(n.notif_date) }} · Stok kritis</p>
            </div>
            <UIcon name="i-lucide-chevron-right" class="text-xs text-[#ccc]"/>
          </NuxtLink>
        </div>
      </div>
    </template>

    <!-- ═══ BANK DASHBOARD ══════════════════════════════════════════════════ -->
    <template v-else-if="isBank && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div><p class="text-[#555] text-xs">{{ greeting }},</p><h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1><p class="text-[#444] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p></div>
        <div class="flex items-center gap-6">
          <div class="text-right"><p class="text-[#555] text-[10px] uppercase">Total Limit</p><p class="text-white text-2xl font-bold">{{ fmtRp(kpi.total_limit) }}</p></div>
          <div class="h-10 w-px bg-[#333]"/>
          <div class="text-right"><p class="text-[#555] text-[10px] uppercase">Interest</p><p class="text-emerald-400 text-lg font-bold">{{ fmtRp(kpi.total_interest) }}</p></div>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4"><p class="text-[9px] text-[#999] uppercase">Outstanding</p><p class="text-xl font-bold text-amber-600 mt-1">{{ fmtRp(kpi.total_outstanding) }}</p><p class="text-[9px] text-[#bbb]">{{ kpi.total_limit > 0 ? ((kpi.total_outstanding/kpi.total_limit)*100).toFixed(1) : 0 }}% utilisasi</p></div>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4"><p class="text-[9px] text-[#999] uppercase">Disbursed→Dist</p><p class="text-xl font-bold text-blue-600 mt-1">{{ fmtRp(kpi.total_disbursed) }}</p></div>
        <NuxtLink to="/dashboard/bank/ar-monitoring" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">AR Overdue</p><p class="text-xl font-bold text-red-600 mt-1">{{ kpi.overdue_count }}</p></NuxtLink>
        <NuxtLink to="/dashboard/bank/daily-interest" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Shortfall</p><p class="text-xl font-bold mt-1" :class="Number(kpi.shortfall_total) > 0 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtRp(kpi.shortfall_total) }}</p></NuxtLink>
      </div>
      <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">AR Monitoring</p></div>
        <div class="divide-y divide-[#f5f5f5]">
          <div v-for="ar in recentAR" :key="ar.id" class="px-5 py-2.5 flex items-center justify-between">
            <div><p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</p><p class="text-[9px] text-[#999]">JT: {{ fmtDate(ar.due_date) }}</p></div>
            <div class="text-right"><p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(ar.disbursed_amount) }}</p><span :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold', ar.status==='paid'?'bg-emerald-100 text-emerald-700':ar.status==='overdue'?'bg-red-100 text-red-700':'bg-blue-100 text-blue-700']">{{ ar.status }}</span></div>
          </div>
        </div>
      </div>
    </template>

    <!-- ═══ DISTRIBUTOR DASHBOARD ═══════════════════════════════════════════ -->
    <template v-else-if="isDistributor && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div><p class="text-[#555] text-xs">{{ greeting }},</p><h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1><p class="text-[#444] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p></div>
        <div class="text-right"><p class="text-[#555] text-[10px] uppercase">Total Diterima Bank</p><p class="text-emerald-400 text-2xl font-bold">{{ fmtRp(kpi.total_value) }}</p></div>
      </div>
      <div class="grid grid-cols-3 gap-3">
        <NuxtLink to="/dashboard/dist/purchase-orders" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Perlu Konfirmasi</p><p class="text-2xl font-bold text-blue-600 mt-1">{{ kpi.need_confirm }}</p></NuxtLink>
        <NuxtLink to="/dashboard/dist/delivery" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Pengiriman</p><p class="text-2xl font-bold text-amber-600 mt-1">{{ kpi.shipping }}</p></NuxtLink>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4"><p class="text-[9px] text-[#999] uppercase">Diterima RS</p><p class="text-2xl font-bold text-emerald-600 mt-1">{{ kpi.completed }}</p></div>
      </div>
      <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between"><p class="text-xs font-bold text-[#1a1a1a]">PO dari KSM</p><NuxtLink to="/dashboard/dist/purchase-orders" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink></div>
        <div class="divide-y divide-[#f5f5f5]">
          <NuxtLink v-for="po in recentPOs" :key="po.id" to="/dashboard/dist/purchase-orders" class="px-5 py-2.5 flex items-center justify-between hover:bg-[#fafafa] block">
            <div><p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p><p class="text-[9px] text-[#999]">{{ po.metadata?.rs_name }}</p></div>
            <div class="text-right"><p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p><span :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold', poStatusColor[po.status] ?? '']">{{ po.status }}</span></div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <!-- ═══ RS DASHBOARD ════════════════════════════════════════════════════ -->
    <template v-else-if="isRS && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div><p class="text-[#555] text-xs">{{ greeting }},</p><h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1><p class="text-[#444] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p></div>
        <div class="text-right"><p class="text-[#555] text-[10px] uppercase">Outstanding Invoice</p><p class="text-amber-400 text-2xl font-bold">{{ fmtRp(kpi.outstanding_invoice) }}</p></div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <NuxtLink to="/dashboard/rs/confirmations" class="bg-white rounded-xl border-2 border-amber-300 p-4 hover:border-amber-500"><p class="text-[9px] text-amber-600 uppercase font-bold">Perlu Persetujuan</p><p class="text-2xl font-bold text-amber-700 mt-1">{{ kpi.pending_confirm }}</p></NuxtLink>
        <NuxtLink to="/dashboard/rs/alerts" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Alert SIMRS</p><p class="text-2xl font-bold text-red-600 mt-1">{{ kpi.active_alerts }}</p></NuxtLink>
        <NuxtLink to="/dashboard/rs/receiving" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Pengiriman</p><p class="text-2xl font-bold text-blue-600 mt-1">{{ kpi.pending_delivery }}</p></NuxtLink>
        <NuxtLink to="/dashboard/rs/invoices" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:shadow-sm"><p class="text-[9px] text-[#999] uppercase">Invoice</p><p class="text-xl font-bold text-[#1a1a1a] mt-1">{{ fmtRp(kpi.outstanding_invoice) }}</p></NuxtLink>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">Alert SIMRS</p></div>
          <div v-if="recentNotifs.length===0" class="p-5 text-center text-xs text-[#ccc]">Stok aman</div>
          <div v-else class="divide-y divide-[#f5f5f5]"><NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/rs/alerts" class="px-5 py-3 flex items-center gap-3 hover:bg-[#fafafa] block"><div :class="['w-2 h-2 rounded-full', n.ksm_confirmation_status==='pending_rs_approval'?'bg-amber-500 animate-pulse':'bg-blue-400']"/><div class="flex-1"><p class="text-xs font-semibold text-[#1a1a1a]">{{ n.notif_number }}</p><p class="text-[9px] text-[#999]">{{ n.status }}</p></div></NuxtLink></div>
        </div>
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">Pengiriman Aktif</p></div>
          <div v-if="recentPOs.length===0" class="p-5 text-center text-xs text-[#ccc]">Tidak ada</div>
          <div v-else class="divide-y divide-[#f5f5f5]"><div v-for="po in recentPOs" :key="po.id" class="px-5 py-2.5 flex items-center justify-between"><div><p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p><p class="text-[9px] text-[#999]">{{ po.metadata?.supplier_name }}</p></div><p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p></div></div>
        </div>
      </div>
    </template>
  </div>
</template>
