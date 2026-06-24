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
    const [kpiRes, trendRes, fcRes, riskRes, { data: pos }, { data: ar }, { data: notifs }, { data: inv }] = await Promise.all([
      supabase.rpc('get_ksm_dashboard_kpi', { p_ksm_tenant_id: tenantId.value }),
      supabase.rpc('get_monthly_trends', { p_ksm_tenant_id: tenantId.value, p_months: 6 }),
      supabase.rpc('forecast_next_months', { p_ksm_tenant_id: tenantId.value, p_forecast_months: 3 }),
      supabase.rpc('get_rs_risk_scores', { p_ksm_tenant_id: tenantId.value }),
      supabase.from('ksm_purchase_orders').select('id,po_number,po_date,status,total_amount,metadata')
        .eq('ksm_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(5),
      supabase.from('ar_accounts').select('id,ar_number,disbursed_amount,outstanding_amount,due_date,status')
        .eq('ksm_tenant_id', tenantId.value).neq('status', 'paid').order('due_date').limit(5),
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,metadata')
        .eq('ksm_tenant_id', tenantId.value).eq('status', 'pending').order('notif_date', { ascending: false }).limit(4),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,outstanding,status,due_date,metadata')
        .eq('ksm_tenant_id', tenantId.value).order('invoice_date', { ascending: false }).limit(5),
    ])
    kpi.value = kpiRes.data
    trends.value = trendRes.data ?? []
    forecast.value = fcRes.data ?? []
    riskScores.value = riskRes.data ?? []
    recentPOs.value = pos ?? []
    recentAR.value = ar ?? []
    recentNotifs.value = notifs ?? []
    recentInvoices.value = inv ?? []
  } else if (isBank.value) {
    const [{ data: fac }, { data: ar }, { data: inv }] = await Promise.all([
      supabase.from('scf_facilities').select('facility_limit,outstanding,status').eq('status', 'approved'),
      supabase.from('ar_accounts').select('id,ar_number,disbursed_amount,outstanding_amount,interest_amount,due_date,status').order('due_date').limit(6),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,status,shortfall_amount,shortfall_covered_by_bank').in('status', ['sent_to_rs','payment_pending','partially_paid','overdue']).limit(5),
    ])
    const f = fac ?? []
    kpi.value = {
      total_limit: f.reduce((s: number, x: any) => s + Number(x.facility_limit), 0),
      total_outstanding: f.reduce((s: number, x: any) => s + Number(x.outstanding), 0),
      total_disbursed: (ar ?? []).reduce((s: number, a: any) => s + Number(a.disbursed_amount ?? 0), 0),
      total_interest: (ar ?? []).reduce((s: number, a: any) => s + Number(a.interest_amount ?? 0), 0),
      overdue_count: (ar ?? []).filter((a: any) => a.status === 'overdue').length,
      shortfall_total: (inv ?? []).filter((i: any) => i.shortfall_covered_by_bank).reduce((s: number, i: any) => s + Number(i.shortfall_amount ?? 0), 0),
      facility_count: f.length, pending_invoices: (inv ?? []).length,
    }
    recentAR.value = ar ?? []
  } else if (isDistributor.value) {
    const { data: pos } = await supabase.from('ksm_purchase_orders')
      .select('id,po_number,po_date,status,total_amount,metadata')
      .eq('supplier_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(6)
    const all = pos ?? []
    kpi.value = {
      need_confirm: all.filter((p: any) => p.status === 'submitted').length,
      shipping: all.filter((p: any) => p.status === 'sent_to_supplier').length,
      completed: all.filter((p: any) => ['fully_received','partially_received'].includes(p.status)).length,
      total_value: all.reduce((s: number, p: any) => s + Number(p.total_amount), 0),
    }
    recentPOs.value = all
  } else if (isRS.value) {
    const [{ data: notifs }, { data: inv }, { data: pos }] = await Promise.all([
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,ksm_confirmation_status,metadata')
        .eq('rs_tenant_id', tenantId.value).order('notif_date', { ascending: false }).limit(4),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,outstanding,status,due_date')
        .eq('rs_tenant_id', tenantId.value).order('due_date').limit(5),
      supabase.from('ksm_purchase_orders').select('id,po_number,status,total_amount,metadata')
        .eq('rs_tenant_id', tenantId.value).in('status', ['sent_to_supplier','partially_received']).limit(4),
    ])
    kpi.value = {
      pending_confirm: (notifs ?? []).filter((n: any) => n.ksm_confirmation_status === 'pending_rs_approval').length,
      active_alerts: (notifs ?? []).filter((n: any) => n.status === 'pending').length,
      pending_delivery: (pos ?? []).length,
      outstanding_invoice: (inv ?? []).reduce((s: number, i: any) => s + Number(i.outstanding ?? 0), 0),
    }
    recentNotifs.value = notifs ?? []
    recentPOs.value = pos ?? []
    recentInvoices.value = inv ?? []
  }
  loading.value = false
}

// Computed metrics
const maxTrend = computed(() => Math.max(...trends.value.map((t: any) => Number(t.revenue ?? 0)), 1))
const grossMargin = computed(() => {
  if (!kpi.value) return 0
  const rev = Number(kpi.value.revenue_total ?? 0)
  const cogs = Number(kpi.value.bank_to_dist_total ?? 0)
  return rev > 0 ? ((rev - cogs) / rev * 100) : 0
})
const collectionRate = computed(() => {
  if (!kpi.value) return 0
  const rev = Number(kpi.value.revenue_total ?? 0)
  const out = Number(kpi.value.outstanding_from_rs ?? 0)
  return rev > 0 ? ((rev - out) / rev * 100) : 0
})
const scfUtil = computed(() => {
  if (!kpi.value) return 0
  return Number(kpi.value.scf_limit) > 0 ? (Number(kpi.value.scf_outstanding) / Number(kpi.value.scf_limit) * 100) : 0
})

const poStatusColor: Record<string, string> = {
  draft: 'bg-[#e5e5e5] text-[#999]', submitted: 'bg-blue-500/10 text-blue-700',
  approved: 'bg-purple-500/10 text-purple-700', sent_to_supplier: 'bg-amber-500/10 text-amber-700',
  partially_received: 'bg-orange-500/10 text-orange-700', fully_received: 'bg-emerald-500/10 text-emerald-700',
}

watch(tenantId, (id) => { if (id) loadDashboard() })
onMounted(() => { if (tenantId.value) loadDashboard() })
</script>

<template>
  <div v-if="roleLoading || loading" class="flex items-center justify-center py-20">
    <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
  </div>

  <div v-else class="space-y-4">

    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <!-- KSM DASHBOARD — PREMIUM ANALYTICS -->
    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <template v-if="isKSM && kpi">

      <!-- Hero Header -->
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div>
          <p class="text-[#666] text-xs">{{ greeting }},</p>
          <h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1>
          <p class="text-[#555] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p>
        </div>
        <div class="flex items-center gap-6">
          <div class="text-right">
            <p class="text-[#666] text-[10px] uppercase tracking-wider">Total Revenue</p>
            <p class="text-white text-2xl font-bold mt-0.5">{{ fmtRp(kpi.revenue_total) }}</p>
          </div>
          <div class="h-10 w-px bg-[#333]"/>
          <div class="text-right">
            <p class="text-[#666] text-[10px] uppercase tracking-wider">Bulan Ini</p>
            <p class="text-emerald-400 text-lg font-bold mt-0.5">{{ fmtRp(kpi.revenue_this_month) }}</p>
          </div>
        </div>
      </div>

      <!-- KPI Metrics Row — 8 cards -->
      <div class="grid grid-cols-4 md:grid-cols-8 gap-2">
        <NuxtLink to="/dashboard/ksm/invoices" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Invoice RS</p>
          <p class="text-lg font-bold text-[#1a1a1a] mt-1 group-hover:text-[#6b1525]">{{ kpi.total_invoices }}</p>
          <div class="w-full bg-[#f0f0f0] rounded-full h-1 mt-2">
            <div class="bg-emerald-500 h-1 rounded-full" style="width:70%"/>
          </div>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/purchase-orders" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">PO Aktif</p>
          <p class="text-lg font-bold text-[#1a1a1a] mt-1 group-hover:text-[#6b1525]">{{ kpi.active_pos }}</p>
          <div class="w-full bg-[#f0f0f0] rounded-full h-1 mt-2">
            <div class="bg-blue-500 h-1 rounded-full" style="width:60%"/>
          </div>
        </NuxtLink>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-3">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Gross Margin</p>
          <p class="text-lg font-bold mt-1" :class="grossMargin >= 8 ? 'text-emerald-600' : 'text-amber-600'">{{ fmtPct(grossMargin) }}</p>
          <div class="w-full bg-[#f0f0f0] rounded-full h-1 mt-2">
            <div :class="grossMargin >= 8 ? 'bg-emerald-500' : 'bg-amber-500'" class="h-1 rounded-full" :style="`width:${Math.min(100, grossMargin*5)}%`"/>
          </div>
        </div>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-3">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Collection</p>
          <p class="text-lg font-bold mt-1" :class="collectionRate >= 70 ? 'text-emerald-600' : 'text-red-600'">{{ fmtPct(collectionRate) }}</p>
          <div class="w-full bg-[#f0f0f0] rounded-full h-1 mt-2">
            <div :class="collectionRate >= 70 ? 'bg-emerald-500' : 'bg-red-500'" class="h-1 rounded-full" :style="`width:${collectionRate}%`"/>
          </div>
        </div>
        <NuxtLink to="/dashboard/ksm/ar" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Piutang RS</p>
          <p class="text-sm font-bold text-amber-600 mt-1">{{ fmtRp(kpi.outstanding_from_rs) }}</p>
          <p class="text-[9px] text-[#bbb] mt-1">{{ kpi.overdue_invoices }} overdue</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/scf" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">SCF Utilisasi</p>
          <p class="text-lg font-bold mt-1" :class="scfUtil > 70 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtPct(scfUtil) }}</p>
          <div class="w-full bg-[#f0f0f0] rounded-full h-1 mt-2">
            <div :class="scfUtil > 70 ? 'bg-red-500' : 'bg-[#6b1525]'" class="h-1 rounded-full" :style="`width:${scfUtil}%`"/>
          </div>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/notifications" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Alert SIMRS</p>
          <p class="text-lg font-bold text-[#1a1a1a] mt-1 group-hover:text-[#6b1525]">{{ kpi.pending_notifs }}</p>
          <p class="text-[9px] text-amber-600 mt-1">{{ kpi.pending_rs_approval }} tunggu RS</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/payments" class="bg-white rounded-xl border border-[#ebebeb] p-3 hover:border-[#6b1525]/30 transition-all group">
          <p class="text-[9px] text-[#999] uppercase tracking-wider">Shortfall</p>
          <p class="text-sm font-bold mt-1" :class="Number(kpi.total_shortfall) > 0 ? 'text-red-600' : 'text-emerald-600'">{{ fmtRp(kpi.total_shortfall) }}</p>
          <p class="text-[9px] text-[#bbb] mt-1">Bunga 50/50</p>
        </NuxtLink>
      </div>

      <!-- Financial Summary — 4 cards dark -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <p class="text-[10px] text-[#666] uppercase tracking-wider">Hutang SCF Bank</p>
            <div class="w-6 h-6 rounded-full bg-blue-500/10 flex items-center justify-center">
              <UIcon name="i-lucide-landmark" class="text-blue-400 text-xs"/>
            </div>
          </div>
          <p class="text-white text-xl font-bold">{{ fmtRp(kpi.hutang_bank) }}</p>
          <p class="text-[10px] text-[#555] mt-1">Bank→Dist: {{ fmtRp(kpi.bank_to_dist_total) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <p class="text-[10px] text-[#666] uppercase tracking-wider">Overdue Amount</p>
            <div class="w-6 h-6 rounded-full bg-red-500/10 flex items-center justify-center">
              <UIcon name="i-lucide-alert-circle" class="text-red-400 text-xs"/>
            </div>
          </div>
          <p :class="['text-xl font-bold', Number(kpi.overdue_amount) > 0 ? 'text-red-400' : 'text-emerald-400']">{{ fmtRp(kpi.overdue_amount) }}</p>
          <p class="text-[10px] text-[#555] mt-1">{{ kpi.overdue_invoices }} invoice lewat JT</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <p class="text-[10px] text-[#666] uppercase tracking-wider">Total PO Value</p>
            <div class="w-6 h-6 rounded-full bg-purple-500/10 flex items-center justify-center">
              <UIcon name="i-lucide-shopping-cart" class="text-purple-400 text-xs"/>
            </div>
          </div>
          <p class="text-white text-xl font-bold">{{ fmtRp(kpi.po_total_value) }}</p>
          <p class="text-[10px] text-[#555] mt-1">{{ kpi.active_pos }} PO aktif</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <p class="text-[10px] text-[#666] uppercase tracking-wider">Bunga KSM (50%)</p>
            <div class="w-6 h-6 rounded-full bg-amber-500/10 flex items-center justify-center">
              <UIcon name="i-lucide-percent" class="text-amber-400 text-xs"/>
            </div>
          </div>
          <p class="text-amber-400 text-xl font-bold">{{ fmtRp(kpi.total_daily_interest_ksm) }}</p>
          <p class="text-[10px] text-[#555] mt-1">Harian dari shortfall</p>
        </div>
      </div>

      <!-- Charts Row -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Revenue Trend -->
        <div class="lg:col-span-2 bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <div>
              <p class="text-xs font-bold text-[#1a1a1a]">Revenue Trend</p>
              <p class="text-[10px] text-[#999]">Invoice RS — 6 bulan terakhir</p>
            </div>
            <NuxtLink to="/dashboard/ksm/finance/pl" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Detail P&L →</NuxtLink>
          </div>
          <div class="p-5">
            <div v-if="trends.length > 0" class="flex items-end gap-3 h-36">
              <div v-for="(t, idx) in trends" :key="t.month" class="flex-1 flex flex-col items-center gap-1">
                <p class="text-[8px] text-[#999] font-semibold">{{ fmtRp(t.revenue) }}</p>
                <div class="w-full flex flex-col gap-0.5" :style="`height: ${Math.max(6, (Number(t.revenue)/maxTrend)*120)}px`">
                  <div class="flex-1 rounded-t-md bg-[#6b1525] opacity-90 transition-all hover:opacity-100"/>
                </div>
                <p class="text-[9px] text-[#999]">{{ t.month_label }}</p>
                <p class="text-[8px] text-[#ccc]">{{ t.po_count }} PO</p>
              </div>
            </div>
            <p v-else class="text-[#ccc] text-xs text-center py-10">Belum ada data trend</p>
          </div>
        </div>

        <!-- Forecast -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]">
            <p class="text-xs font-bold text-[#1a1a1a]">Prediksi Revenue</p>
            <p class="text-[10px] text-[#999]">WMA + Growth · 3 bulan ke depan</p>
          </div>
          <div class="p-5 space-y-4">
            <div v-for="f in forecast" :key="f.month" class="flex items-center gap-3">
              <p class="text-xs font-semibold text-[#666] w-14">{{ f.month_label }}</p>
              <div class="flex-1">
                <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(f.predicted_revenue) }}</p>
                <div class="w-full bg-[#f0f0f0] rounded-full h-1.5 mt-1">
                  <div class="bg-[#6b1525]/50 h-1.5 rounded-full" :style="`width:${f.confidence === 'high' ? 85 : f.confidence === 'medium' ? 60 : 35}%`"/>
                </div>
              </div>
              <span :class="['px-1.5 py-0.5 rounded text-[8px] font-bold',
                f.confidence === 'high' ? 'bg-emerald-100 text-emerald-700' :
                f.confidence === 'medium' ? 'bg-amber-100 text-amber-700' : 'bg-[#f0f0f0] text-[#999]']">
                {{ f.confidence }}
              </span>
            </div>
            <NuxtLink to="/dashboard/ksm/analytics" class="block text-center text-[10px] text-[#6b1525] font-semibold hover:underline pt-2">
              AI Business Intelligence →
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- RS Risk + Alerts -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- RS Risk Scoring -->
        <div class="lg:col-span-2 bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <div>
              <p class="text-xs font-bold text-[#1a1a1a]">Risk Scoring RS Mitra</p>
              <p class="text-[10px] text-[#999]">Collection rate · overdue · shortfall history</p>
            </div>
            <NuxtLink to="/dashboard/ksm/analytics" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Detail →</NuxtLink>
          </div>
          <div v-if="riskScores.length === 0" class="p-5 text-center text-xs text-[#ccc]">Belum ada data RS</div>
          <div v-else class="p-4 grid grid-cols-1 md:grid-cols-2 gap-2">
            <div v-for="rs in riskScores.slice(0, 6)" :key="rs.rs_tenant_id"
              class="flex items-center gap-3 p-3 rounded-lg border border-[#f0f0f0] hover:border-[#e0e0e0] transition-colors">
              <div :class="['w-2 h-8 rounded-full flex-shrink-0',
                rs.risk_score === 'HIGH' ? 'bg-red-500' : rs.risk_score === 'MEDIUM' ? 'bg-amber-500' : 'bg-emerald-500']"/>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ rs.rs_name }}</p>
                <p class="text-[10px] text-[#999]">{{ rs.total_invoices }} inv · {{ fmtRp(rs.total_value) }}</p>
              </div>
              <div class="text-right flex-shrink-0">
                <p class="text-xs font-bold" :class="Number(rs.collection_rate) >= 70 ? 'text-emerald-600' : 'text-red-600'">{{ rs.collection_rate }}%</p>
                <p class="text-[9px] text-[#bbb]">collection</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Alert SIMRS -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">Alert SIMRS</p>
            <NuxtLink to="/dashboard/ksm/notifications" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Lihat semua</NuxtLink>
          </div>
          <div v-if="recentNotifs.length === 0" class="p-5 text-center text-xs text-[#ccc]">Tidak ada alert aktif</div>
          <div v-else class="divide-y divide-[#f0f0f0]">
            <NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/ksm/notifications"
              class="px-5 py-3 flex items-center gap-3 hover:bg-[#fafafa] transition-colors block">
              <div :class="['w-2 h-2 rounded-full flex-shrink-0',
                n.metadata?.urgency === 'critical' ? 'bg-red-500 animate-pulse' : 'bg-amber-500']"/>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ n.metadata?.rs_name ?? n.notif_number }}</p>
                <p class="text-[10px] text-[#999]">{{ fmtDate(n.notif_date) }}</p>
              </div>
              <UIcon name="i-lucide-chevron-right" class="text-xs text-[#ccc]"/>
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- Recent Tables Row -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Recent POs -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">PO Terbaru</p>
            <NuxtLink to="/dashboard/ksm/purchase-orders" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink>
          </div>
          <div class="divide-y divide-[#f5f5f5]">
            <NuxtLink v-for="po in recentPOs" :key="po.id" :to="`/dashboard/ksm/purchase-orders/${po.id}`"
              class="px-5 py-2.5 flex items-center justify-between hover:bg-[#fafafa] transition-colors block">
              <div class="min-w-0">
                <p class="text-[11px] font-mono font-semibold text-[#1a1a1a] truncate">{{ po.po_number }}</p>
                <p class="text-[9px] text-[#999] truncate">{{ po.metadata?.rs_name ?? '' }}</p>
              </div>
              <div class="text-right flex-shrink-0 ml-2">
                <p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
                <span :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold', poStatusColor[po.status] ?? '']">{{ po.status }}</span>
              </div>
            </NuxtLink>
          </div>
        </div>

        <!-- Recent Invoices -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">Invoice Terbaru</p>
            <NuxtLink to="/dashboard/ksm/invoices" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink>
          </div>
          <div class="divide-y divide-[#f5f5f5]">
            <NuxtLink v-for="inv in recentInvoices" :key="inv.id" to="/dashboard/ksm/invoices"
              class="px-5 py-2.5 flex items-center justify-between hover:bg-[#fafafa] transition-colors block">
              <div class="min-w-0">
                <p class="text-[11px] font-mono font-semibold text-[#1a1a1a] truncate">{{ inv.invoice_number }}</p>
                <p class="text-[9px] text-[#999] truncate">{{ inv.metadata?.rs_name ?? '' }}</p>
              </div>
              <div class="text-right flex-shrink-0 ml-2">
                <p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</p>
                <p class="text-[9px]" :class="Number(inv.outstanding ?? 0) > 0 ? 'text-amber-600' : 'text-emerald-600'">
                  {{ Number(inv.outstanding ?? 0) > 0 ? 'Sisa: ' + fmtRp(inv.outstanding) : 'Lunas' }}
                </p>
              </div>
            </NuxtLink>
          </div>
        </div>

        <!-- AR Outstanding (Hutang ke Bank) -->
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
            <p class="text-xs font-bold text-[#1a1a1a]">Hutang SCF ke Bank</p>
            <NuxtLink to="/dashboard/ksm/scf" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink>
          </div>
          <div v-if="recentAR.length === 0" class="p-5 text-center text-xs text-[#ccc]">Semua lunas</div>
          <div v-else class="divide-y divide-[#f5f5f5]">
            <div v-for="ar in recentAR" :key="ar.id" class="px-5 py-2.5 flex items-center justify-between">
              <div>
                <p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</p>
                <p class="text-[9px] text-[#999]">JT: {{ fmtDate(ar.due_date) }}</p>
              </div>
              <p class="text-[11px] font-bold text-amber-600">{{ fmtRp(ar.outstanding_amount) }}</p>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <!-- BANK DASHBOARD -->
    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isBank && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div>
          <p class="text-[#666] text-xs">{{ greeting }},</p>
          <h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1>
          <p class="text-[#555] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p>
        </div>
        <div class="text-right">
          <p class="text-[#666] text-[10px] uppercase">Total Limit SCF</p>
          <p class="text-white text-2xl font-bold mt-0.5">{{ fmtRp(kpi.total_limit) }}</p>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4">
          <p class="text-[9px] text-[#999] uppercase">Outstanding</p>
          <p class="text-xl font-bold text-amber-600 mt-1">{{ fmtRp(kpi.total_outstanding) }}</p>
          <p class="text-[9px] text-[#bbb] mt-1">{{ kpi.total_limit > 0 ? ((kpi.total_outstanding/kpi.total_limit)*100).toFixed(1) : 0 }}% utilisasi</p>
        </div>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4">
          <p class="text-[9px] text-[#999] uppercase">Disbursed → Dist</p>
          <p class="text-xl font-bold text-blue-600 mt-1">{{ fmtRp(kpi.total_disbursed) }}</p>
        </div>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4">
          <p class="text-[9px] text-[#999] uppercase">Interest Earned</p>
          <p class="text-xl font-bold text-emerald-600 mt-1">{{ fmtRp(kpi.total_interest) }}</p>
        </div>
        <NuxtLink to="/dashboard/bank/daily-interest" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Shortfall</p>
          <p class="text-xl font-bold mt-1" :class="Number(kpi.shortfall_total) > 0 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtRp(kpi.shortfall_total) }}</p>
          <p class="text-[9px] text-[#bbb] mt-1">Bunga harian 50/50</p>
        </NuxtLink>
      </div>
      <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">AR Monitoring</p></div>
        <div class="divide-y divide-[#f5f5f5]">
          <div v-for="ar in recentAR" :key="ar.id" class="px-5 py-2.5 flex items-center justify-between">
            <div>
              <p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</p>
              <p class="text-[9px] text-[#999]">JT: {{ fmtDate(ar.due_date) }}</p>
            </div>
            <div class="text-right">
              <p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(ar.disbursed_amount) }}</p>
              <span :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold',
                ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' : ar.status === 'overdue' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700']">
                {{ ar.status }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <!-- DISTRIBUTOR DASHBOARD -->
    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isDistributor && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div>
          <p class="text-[#666] text-xs">{{ greeting }},</p>
          <h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1>
          <p class="text-[#555] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p>
        </div>
        <div class="text-right">
          <p class="text-[#666] text-[10px] uppercase">Total Diterima Bank</p>
          <p class="text-emerald-400 text-2xl font-bold mt-0.5">{{ fmtRp(kpi.total_value) }}</p>
        </div>
      </div>
      <div class="grid grid-cols-3 gap-3">
        <NuxtLink to="/dashboard/dist/purchase-orders" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Perlu Konfirmasi</p>
          <p class="text-2xl font-bold text-blue-600 mt-1">{{ kpi.need_confirm }}</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/dist/delivery" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Dalam Pengiriman</p>
          <p class="text-2xl font-bold text-amber-600 mt-1">{{ kpi.shipping }}</p>
        </NuxtLink>
        <div class="bg-white rounded-xl border border-[#ebebeb] p-4">
          <p class="text-[9px] text-[#999] uppercase">Diterima RS</p>
          <p class="text-2xl font-bold text-emerald-600 mt-1">{{ kpi.completed }}</p>
        </div>
      </div>
      <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#f0f0f0] flex items-center justify-between">
          <p class="text-xs font-bold text-[#1a1a1a]">PO dari KSM</p>
          <NuxtLink to="/dashboard/dist/purchase-orders" class="text-[10px] text-[#6b1525] font-semibold hover:underline">Semua</NuxtLink>
        </div>
        <div class="divide-y divide-[#f5f5f5]">
          <NuxtLink v-for="po in recentPOs" :key="po.id" to="/dashboard/dist/purchase-orders"
            class="px-5 py-2.5 flex items-center justify-between hover:bg-[#fafafa] block">
            <div><p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p><p class="text-[9px] text-[#999]">{{ po.metadata?.rs_name }}</p></div>
            <div class="text-right"><p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
              <span :class="['px-1.5 py-0.5 rounded text-[8px] font-semibold', poStatusColor[po.status] ?? '']">{{ po.status }}</span></div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <!-- RS DASHBOARD -->
    <!-- ═══════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isRS && kpi">
      <div class="bg-[#1a1a1a] rounded-2xl p-6 flex items-end justify-between">
        <div>
          <p class="text-[#666] text-xs">{{ greeting }},</p>
          <h1 class="text-white text-xl font-bold mt-0.5">{{ displayName }}</h1>
          <p class="text-[#555] text-[10px] mt-1">{{ todayStr }} · {{ tenantName }}</p>
        </div>
        <div class="text-right">
          <p class="text-[#666] text-[10px] uppercase">Outstanding Invoice</p>
          <p class="text-amber-400 text-2xl font-bold mt-0.5">{{ fmtRp(kpi.outstanding_invoice) }}</p>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <NuxtLink to="/dashboard/rs/confirmations" class="bg-white rounded-xl border-2 border-amber-300 p-4 hover:border-amber-500">
          <p class="text-[9px] text-amber-600 uppercase font-bold">Perlu Persetujuan</p>
          <p class="text-2xl font-bold text-amber-700 mt-1">{{ kpi.pending_confirm }}</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/alerts" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Alert SIMRS</p>
          <p class="text-2xl font-bold text-red-600 mt-1">{{ kpi.active_alerts }}</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/receiving" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Pengiriman</p>
          <p class="text-2xl font-bold text-blue-600 mt-1">{{ kpi.pending_delivery }}</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/invoices" class="bg-white rounded-xl border border-[#ebebeb] p-4 hover:border-[#6b1525]/30">
          <p class="text-[9px] text-[#999] uppercase">Invoice</p>
          <p class="text-xl font-bold text-[#1a1a1a] mt-1">{{ fmtRp(kpi.outstanding_invoice) }}</p>
        </NuxtLink>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">Alert SIMRS</p></div>
          <div v-if="recentNotifs.length === 0" class="p-5 text-center text-xs text-[#ccc]">Stok aman</div>
          <div v-else class="divide-y divide-[#f5f5f5]">
            <NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/rs/alerts" class="px-5 py-3 flex items-center gap-3 hover:bg-[#fafafa] block">
              <div :class="['w-2 h-2 rounded-full', n.ksm_confirmation_status === 'pending_rs_approval' ? 'bg-amber-500 animate-pulse' : 'bg-blue-400']"/>
              <div class="flex-1"><p class="text-xs font-semibold text-[#1a1a1a]">{{ n.notif_number }}</p><p class="text-[9px] text-[#999]">{{ n.status }}</p></div>
            </NuxtLink>
          </div>
        </div>
        <div class="bg-white rounded-xl border border-[#ebebeb] overflow-hidden">
          <div class="px-5 py-3 border-b border-[#f0f0f0]"><p class="text-xs font-bold text-[#1a1a1a]">Pengiriman Aktif</p></div>
          <div v-if="recentPOs.length === 0" class="p-5 text-center text-xs text-[#ccc]">Tidak ada</div>
          <div v-else class="divide-y divide-[#f5f5f5]">
            <div v-for="po in recentPOs" :key="po.id" class="px-5 py-2.5 flex items-center justify-between">
              <div><p class="text-[11px] font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p><p class="text-[9px] text-[#999]">{{ po.metadata?.supplier_name }}</p></div>
              <p class="text-[11px] font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
