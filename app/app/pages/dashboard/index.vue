<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const { portalType, tenantName, tenantId, isKSM, isDistributor, isBank, isRS, loading: roleLoading } = useUserRole()

const loading = ref(true)
const kpi = ref<any>(null)
const trends = ref<any[]>([])
const recentPOs = ref<any[]>([])
const recentAR = ref<any[]>([])
const recentNotifs = ref<any[]>([])

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
    const [kpiRes, trendRes, { data: pos }, { data: ar }, { data: notifs }] = await Promise.all([
      supabase.rpc('get_ksm_dashboard_kpi', { p_ksm_tenant_id: tenantId.value }),
      supabase.rpc('get_monthly_trends', { p_ksm_tenant_id: tenantId.value, p_months: 6 }),
      supabase.from('ksm_purchase_orders').select('id,po_number,po_date,status,total_amount,metadata')
        .eq('ksm_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(8),
      supabase.from('ar_accounts').select('id,ar_number,po_number,disbursed_amount,outstanding_amount,due_date,status')
        .eq('ksm_tenant_id', tenantId.value).neq('status', 'paid').order('due_date').limit(6),
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,metadata')
        .eq('ksm_tenant_id', tenantId.value).eq('status', 'pending').order('notif_date', { ascending: false }).limit(5),
    ])
    kpi.value = kpiRes.data
    trends.value = trendRes.data ?? []
    recentPOs.value = pos ?? []
    recentAR.value = ar ?? []
    recentNotifs.value = notifs ?? []
  } else if (isBank.value) {
    const [{ data: fac }, { data: ar }, { data: inv }] = await Promise.all([
      supabase.from('scf_facilities').select('facility_limit,outstanding,status').eq('status', 'approved'),
      supabase.from('ar_accounts').select('id,ar_number,disbursed_amount,outstanding_amount,interest_amount,due_date,status').order('due_date').limit(8),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,status,shortfall_amount,shortfall_covered_by_bank').in('status', ['sent_to_rs','payment_pending','partially_paid','overdue']).limit(6),
    ])
    const facData = fac ?? []
    kpi.value = {
      total_limit: facData.reduce((s: number, f: any) => s + Number(f.facility_limit), 0),
      total_outstanding: facData.reduce((s: number, f: any) => s + Number(f.outstanding), 0),
      total_disbursed: (ar ?? []).reduce((s: number, a: any) => s + Number(a.disbursed_amount ?? 0), 0),
      total_interest: (ar ?? []).reduce((s: number, a: any) => s + Number(a.interest_amount ?? 0), 0),
      overdue_count: (ar ?? []).filter((a: any) => a.status === 'overdue').length,
      shortfall_total: (inv ?? []).filter((i: any) => i.shortfall_covered_by_bank).reduce((s: number, i: any) => s + Number(i.shortfall_amount ?? 0), 0),
      facility_count: facData.length,
      pending_invoices: (inv ?? []).length,
    }
    recentAR.value = ar ?? []
  } else if (isDistributor.value) {
    const [{ data: pos }, { data: paid }] = await Promise.all([
      supabase.from('ksm_purchase_orders').select('id,po_number,po_date,status,total_amount,metadata')
        .eq('supplier_tenant_id', tenantId.value).order('po_date', { ascending: false }).limit(8),
      supabase.from('ar_accounts').select('disbursed_amount').not('disbursement_date', 'is', null),
    ])
    kpi.value = {
      active_pos: (pos ?? []).filter((p: any) => ['submitted','approved'].includes(p.status)).length,
      shipping: (pos ?? []).filter((p: any) => p.status === 'sent_to_supplier').length,
      completed: (pos ?? []).filter((p: any) => ['fully_received','partially_received'].includes(p.status)).length,
      total_received: (paid ?? []).reduce((s: number, a: any) => s + Number(a.disbursed_amount ?? 0), 0),
    }
    recentPOs.value = pos ?? []
  } else if (isRS.value) {
    const [{ data: notifs }, { data: inv }, { data: pos }] = await Promise.all([
      supabase.from('hospital_notifications').select('id,notif_number,notif_date,status,ksm_confirmation_status,metadata')
        .eq('rs_tenant_id', tenantId.value).order('notif_date', { ascending: false }).limit(5),
      supabase.from('ksm_invoices').select('id,invoice_number,total_amount,outstanding,status,due_date')
        .eq('rs_tenant_id', tenantId.value).order('due_date').limit(6),
      supabase.from('ksm_purchase_orders').select('id,po_number,status,total_amount,metadata')
        .eq('rs_tenant_id', tenantId.value).in('status', ['sent_to_supplier','partially_received']).limit(5),
    ])
    kpi.value = {
      pending_confirm: (notifs ?? []).filter((n: any) => n.ksm_confirmation_status === 'pending_rs_approval').length,
      active_alerts: (notifs ?? []).filter((n: any) => n.status === 'pending').length,
      pending_delivery: (pos ?? []).length,
      outstanding_invoice: (inv ?? []).reduce((s: number, i: any) => s + Number(i.outstanding ?? 0), 0),
      invoice_count: (inv ?? []).length,
    }
    recentNotifs.value = notifs ?? []
    recentPOs.value = pos ?? []
  }

  loading.value = false
}

const maxTrend = computed(() => Math.max(...trends.value.map((t: any) => Number(t.revenue ?? 0)), 1))

const poStatusColor: Record<string, string> = {
  draft: 'bg-[#e5e5e5] text-[#999]', submitted: 'bg-blue-100 text-blue-700',
  approved: 'bg-purple-100 text-purple-700', sent_to_supplier: 'bg-amber-100 text-amber-700',
  partially_received: 'bg-orange-100 text-orange-700', fully_received: 'bg-emerald-100 text-emerald-700',
}

watch(tenantId, (id) => { if (id) loadDashboard() })
onMounted(() => { if (tenantId.value) loadDashboard() })
</script>

<template>
  <div v-if="roleLoading || loading" class="flex items-center justify-center py-20">
    <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
  </div>

  <div v-else class="space-y-5">
    <!-- Header -->
    <div class="flex items-end justify-between">
      <div>
        <p class="text-sm text-[#999]">{{ greeting }},</p>
        <h1 class="text-xl font-bold text-[#1a1a1a]">{{ displayName }}</h1>
        <p class="text-xs text-[#bbb] mt-0.5">{{ todayStr }} · {{ tenantName }}</p>
      </div>
      <button @click="loadDashboard" class="px-3 py-1.5 text-xs text-[#999] border border-[#e5e5e5] rounded-lg hover:bg-[#ebebeb] flex items-center gap-1.5">
        <UIcon name="i-lucide-refresh-cw" class="text-xs"/> Refresh
      </button>
    </div>

    <!-- ════════════════════════════════════════════════════════════════════ -->
    <!-- KSM DASHBOARD -->
    <!-- ════════════════════════════════════════════════════════════════════ -->
    <template v-if="isKSM && kpi">
      <!-- KPI Row -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-white/50 uppercase">Revenue (Invoice RS)</p>
            <UIcon name="i-lucide-trending-up" class="text-emerald-400 text-sm"/>
          </div>
          <p class="text-xl font-bold">{{ fmtRp(kpi.revenue_total) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Bulan ini: {{ fmtRp(kpi.revenue_this_month) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-white/50 uppercase">Piutang RS</p>
            <UIcon name="i-lucide-file-text" class="text-amber-400 text-sm"/>
          </div>
          <p class="text-xl font-bold text-amber-400">{{ fmtRp(kpi.outstanding_from_rs) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Overdue: {{ fmtRp(kpi.overdue_amount) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-white/50 uppercase">Hutang SCF Bank</p>
            <UIcon name="i-lucide-landmark" class="text-blue-400 text-sm"/>
          </div>
          <p class="text-xl font-bold text-blue-400">{{ fmtRp(kpi.hutang_bank) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Bank→Dist: {{ fmtRp(kpi.bank_to_dist_total) }}</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <div class="flex items-center justify-between mb-2">
            <p class="text-[10px] text-white/50 uppercase">SCF Utilisasi</p>
            <UIcon name="i-lucide-gauge" class="text-[#6b1525] text-sm"/>
          </div>
          <p class="text-xl font-bold">{{ kpi.scf_limit > 0 ? ((kpi.scf_outstanding / kpi.scf_limit) * 100).toFixed(1) : 0 }}%</p>
          <div class="w-full bg-white/10 rounded-full h-1.5 mt-2">
            <div class="bg-[#6b1525] h-1.5 rounded-full" :style="`width: ${kpi.scf_limit > 0 ? Math.min(100, kpi.scf_outstanding/kpi.scf_limit*100) : 0}%`"/>
          </div>
        </div>
      </div>

      <!-- Stat Cards (colored) -->
      <div class="grid grid-cols-3 md:grid-cols-6 gap-3">
        <NuxtLink to="/dashboard/ksm/purchase-orders" class="bg-blue-600 rounded-xl p-4 text-white hover:bg-blue-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.active_pos }}</p>
          <p class="text-[10px] text-white/70 mt-1">PO Aktif</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/notifications" class="bg-amber-600 rounded-xl p-4 text-white hover:bg-amber-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.pending_notifs }}</p>
          <p class="text-[10px] text-white/70 mt-1">Alert SIMRS</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/notifications" class="bg-purple-600 rounded-xl p-4 text-white hover:bg-purple-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.pending_rs_approval }}</p>
          <p class="text-[10px] text-white/70 mt-1">Tunggu RS</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/invoices" class="bg-emerald-600 rounded-xl p-4 text-white hover:bg-emerald-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.total_invoices }}</p>
          <p class="text-[10px] text-white/70 mt-1">Total Invoice</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/ar" class="bg-red-600 rounded-xl p-4 text-white hover:bg-red-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.overdue_invoices }}</p>
          <p class="text-[10px] text-white/70 mt-1">Overdue</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/payments" class="bg-teal-600 rounded-xl p-4 text-white hover:bg-teal-700 transition-colors">
          <p class="text-2xl font-bold">{{ fmtRp(kpi.total_shortfall) }}</p>
          <p class="text-[10px] text-white/70 mt-1">Shortfall</p>
        </NuxtLink>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <!-- Revenue Trend Chart -->
        <div class="lg:col-span-2 bg-[#1a1a1a] rounded-xl p-5">
          <p class="text-xs font-bold text-white/60 uppercase tracking-wide mb-4">Revenue Trend 6 Bulan</p>
          <div v-if="trends.length > 0" class="flex items-end gap-2 h-32">
            <div v-for="t in trends" :key="t.month" class="flex-1 flex flex-col items-center gap-1">
              <p class="text-[8px] text-white/40">{{ fmtRp(t.revenue) }}</p>
              <div class="w-full rounded-t bg-[#6b1525] transition-all" :style="`height: ${Math.max(4, (Number(t.revenue)/maxTrend)*110)}px`"/>
              <p class="text-[8px] text-white/40">{{ t.month_label }}</p>
            </div>
          </div>
          <p v-else class="text-white/30 text-xs text-center py-10">Belum ada data trend</p>
        </div>

        <!-- Recent Notifications -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
            <p class="text-xs font-bold text-[#666] uppercase">Alert SIMRS Terbaru</p>
            <NuxtLink to="/dashboard/ksm/notifications" class="text-[10px] text-[#6b1525] font-semibold">Lihat semua</NuxtLink>
          </div>
          <div v-if="recentNotifs.length === 0" class="p-4 text-center text-xs text-[#ccc]">Tidak ada alert</div>
          <div v-else class="divide-y divide-[#e5e5e5]">
            <NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/ksm/notifications"
              class="px-4 py-3 flex items-center gap-3 hover:bg-[#ebebeb] transition-colors block">
              <div :class="['w-2 h-2 rounded-full flex-shrink-0', n.metadata?.urgency === 'critical' ? 'bg-red-500 animate-pulse' : 'bg-amber-500']"/>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ n.metadata?.rs_name ?? n.notif_number }}</p>
                <p class="text-[10px] text-[#999]">{{ fmtDate(n.notif_date) }}</p>
              </div>
            </NuxtLink>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Recent POs -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
            <p class="text-xs font-bold text-[#666] uppercase">PO Terbaru</p>
            <NuxtLink to="/dashboard/ksm/purchase-orders" class="text-[10px] text-[#6b1525] font-semibold">Lihat semua</NuxtLink>
          </div>
          <div class="divide-y divide-[#e5e5e5]">
            <NuxtLink v-for="po in recentPOs" :key="po.id" :to="`/dashboard/ksm/purchase-orders/${po.id}`"
              class="px-4 py-2.5 flex items-center justify-between hover:bg-[#ebebeb] transition-colors block">
              <div>
                <p class="text-xs font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p>
                <p class="text-[10px] text-[#999]">{{ po.metadata?.rs_name ?? '-' }} · {{ fmtDate(po.po_date) }}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
                <span :class="['px-1.5 py-0.5 rounded text-[9px] font-semibold', poStatusColor[po.status] ?? 'bg-[#e5e5e5] text-[#999]']">
                  {{ po.status }}
                </span>
              </div>
            </NuxtLink>
          </div>
        </div>

        <!-- AR Outstanding -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
            <p class="text-xs font-bold text-[#666] uppercase">Hutang SCF ke Bank</p>
            <NuxtLink to="/dashboard/ksm/scf" class="text-[10px] text-[#6b1525] font-semibold">Lihat semua</NuxtLink>
          </div>
          <div v-if="recentAR.length === 0" class="p-4 text-center text-xs text-[#ccc]">Semua lunas</div>
          <div v-else class="divide-y divide-[#e5e5e5]">
            <div v-for="ar in recentAR" :key="ar.id" class="px-4 py-2.5 flex items-center justify-between">
              <div>
                <p class="text-xs font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</p>
                <p class="text-[10px] text-[#999]">JT: {{ fmtDate(ar.due_date) }}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-bold text-amber-700">{{ fmtRp(ar.outstanding_amount) }}</p>
                <p class="text-[10px] text-blue-600">Bank→Dist: {{ fmtRp(ar.disbursed_amount) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ════════════════════════════════════════════════════════════════════ -->
    <!-- BANK DASHBOARD -->
    <!-- ════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isBank && kpi">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Total Limit SCF</p>
          <p class="text-xl font-bold">{{ fmtRp(kpi.total_limit) }}</p>
          <p class="text-[10px] text-white/40 mt-1">{{ kpi.facility_count }} fasilitas</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Outstanding</p>
          <p class="text-xl font-bold text-amber-400">{{ fmtRp(kpi.total_outstanding) }}</p>
          <p class="text-[10px] text-white/40 mt-1">{{ kpi.total_limit > 0 ? ((kpi.total_outstanding/kpi.total_limit)*100).toFixed(1) : 0 }}% utilisasi</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Total Dicairkan</p>
          <p class="text-xl font-bold text-blue-400">{{ fmtRp(kpi.total_disbursed) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Bank → Distributor</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Interest Earned</p>
          <p class="text-xl font-bold text-emerald-400">{{ fmtRp(kpi.total_interest) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Bunga SCF</p>
        </div>
      </div>
      <div class="grid grid-cols-3 gap-3">
        <NuxtLink to="/dashboard/bank/bpjs-monitoring" class="bg-amber-600 rounded-xl p-4 text-white hover:bg-amber-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.pending_invoices }}</p>
          <p class="text-[10px] text-white/70 mt-1">Invoice Pending BPJS</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/bank/ar-monitoring" class="bg-red-600 rounded-xl p-4 text-white hover:bg-red-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.overdue_count }}</p>
          <p class="text-[10px] text-white/70 mt-1">AR Overdue</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/bank/daily-interest" class="bg-teal-600 rounded-xl p-4 text-white hover:bg-teal-700 transition-colors">
          <p class="text-2xl font-bold">{{ fmtRp(kpi.shortfall_total) }}</p>
          <p class="text-[10px] text-white/70 mt-1">Shortfall (Bunga 50/50)</p>
        </NuxtLink>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-4 py-3 border-b border-[#e5e5e5]"><p class="text-xs font-bold text-[#666] uppercase">AR Monitoring</p></div>
        <div class="divide-y divide-[#e5e5e5]">
          <div v-for="ar in recentAR" :key="ar.id" class="px-4 py-2.5 flex items-center justify-between">
            <div>
              <p class="text-xs font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</p>
              <p class="text-[10px] text-[#999]">JT: {{ fmtDate(ar.due_date) }}</p>
            </div>
            <div class="text-right">
              <p class="text-xs font-bold text-[#1a1a1a]">{{ fmtRp(ar.disbursed_amount) }}</p>
              <span :class="['px-1.5 py-0.5 rounded text-[9px] font-semibold',
                ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                ar.status === 'overdue' ? 'bg-red-100 text-red-700' : 'bg-blue-100 text-blue-700']">
                {{ ar.status }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- ════════════════════════════════════════════════════════════════════ -->
    <!-- DISTRIBUTOR DASHBOARD -->
    <!-- ════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isDistributor && kpi">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-blue-600 rounded-xl p-4 text-white">
          <p class="text-2xl font-bold">{{ kpi.active_pos }}</p>
          <p class="text-[10px] text-white/70 mt-1">PO Perlu Konfirmasi</p>
        </div>
        <div class="bg-amber-600 rounded-xl p-4 text-white">
          <p class="text-2xl font-bold">{{ kpi.shipping }}</p>
          <p class="text-[10px] text-white/70 mt-1">Dalam Pengiriman</p>
        </div>
        <div class="bg-emerald-600 rounded-xl p-4 text-white">
          <p class="text-2xl font-bold">{{ kpi.completed }}</p>
          <p class="text-[10px] text-white/70 mt-1">Diterima RS</p>
        </div>
        <div class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Total Diterima Bank</p>
          <p class="text-xl font-bold text-emerald-400">{{ fmtRp(kpi.total_received) }}</p>
          <p class="text-[10px] text-white/40 mt-1">Pembayaran SCF D+1</p>
        </div>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
          <p class="text-xs font-bold text-[#666] uppercase">PO Terbaru dari KSM</p>
          <NuxtLink to="/dashboard/dist/purchase-orders" class="text-[10px] text-[#6b1525] font-semibold">Lihat semua</NuxtLink>
        </div>
        <div class="divide-y divide-[#e5e5e5]">
          <NuxtLink v-for="po in recentPOs" :key="po.id" to="/dashboard/dist/purchase-orders"
            class="px-4 py-2.5 flex items-center justify-between hover:bg-[#ebebeb] transition-colors block">
            <div>
              <p class="text-xs font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p>
              <p class="text-[10px] text-[#999]">{{ po.metadata?.rs_name ?? '-' }}</p>
            </div>
            <div class="text-right">
              <p class="text-xs font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
              <span :class="['px-1.5 py-0.5 rounded text-[9px] font-semibold', poStatusColor[po.status] ?? 'bg-[#e5e5e5] text-[#999]']">{{ po.status }}</span>
            </div>
          </NuxtLink>
        </div>
      </div>
    </template>

    <!-- ════════════════════════════════════════════════════════════════════ -->
    <!-- RS DASHBOARD -->
    <!-- ════════════════════════════════════════════════════════════════════ -->
    <template v-else-if="isRS && kpi">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <NuxtLink to="/dashboard/rs/confirmations" class="bg-amber-600 rounded-xl p-4 text-white hover:bg-amber-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.pending_confirm }}</p>
          <p class="text-[10px] text-white/70 mt-1">Perlu Persetujuan</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/alerts" class="bg-red-600 rounded-xl p-4 text-white hover:bg-red-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.active_alerts }}</p>
          <p class="text-[10px] text-white/70 mt-1">Alert SIMRS</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/receiving" class="bg-blue-600 rounded-xl p-4 text-white hover:bg-blue-700 transition-colors">
          <p class="text-2xl font-bold">{{ kpi.pending_delivery }}</p>
          <p class="text-[10px] text-white/70 mt-1">Dalam Pengiriman</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/rs/invoices" class="bg-[#1a1a1a] rounded-xl p-4 text-white">
          <p class="text-[10px] text-white/50 uppercase mb-2">Outstanding Invoice</p>
          <p class="text-xl font-bold text-amber-400">{{ fmtRp(kpi.outstanding_invoice) }}</p>
          <p class="text-[10px] text-white/40 mt-1">{{ kpi.invoice_count }} invoice</p>
        </NuxtLink>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-4 py-3 border-b border-[#e5e5e5]"><p class="text-xs font-bold text-[#666] uppercase">Alert SIMRS Terbaru</p></div>
          <div v-if="recentNotifs.length === 0" class="p-4 text-center text-xs text-[#ccc]">Stok aman</div>
          <div v-else class="divide-y divide-[#e5e5e5]">
            <NuxtLink v-for="n in recentNotifs" :key="n.id" to="/dashboard/rs/alerts"
              class="px-4 py-2.5 flex items-center gap-3 hover:bg-[#ebebeb] block">
              <div :class="['w-2 h-2 rounded-full', n.ksm_confirmation_status === 'pending_rs_approval' ? 'bg-amber-500 animate-pulse' : 'bg-blue-400']"/>
              <div class="flex-1">
                <p class="text-xs font-semibold text-[#1a1a1a]">{{ n.notif_number }}</p>
                <p class="text-[10px] text-[#999]">{{ fmtDate(n.notif_date) }} · {{ n.status }}</p>
              </div>
            </NuxtLink>
          </div>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-4 py-3 border-b border-[#e5e5e5]"><p class="text-xs font-bold text-[#666] uppercase">Pengiriman Aktif</p></div>
          <div v-if="recentPOs.length === 0" class="p-4 text-center text-xs text-[#ccc]">Tidak ada pengiriman</div>
          <div v-else class="divide-y divide-[#e5e5e5]">
            <div v-for="po in recentPOs" :key="po.id" class="px-4 py-2.5 flex items-center justify-between">
              <div>
                <p class="text-xs font-mono font-semibold text-[#1a1a1a]">{{ po.po_number }}</p>
                <p class="text-[10px] text-[#999]">{{ po.metadata?.supplier_name ?? '-' }}</p>
              </div>
              <p class="text-xs font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Fallback -->
    <div v-else class="flex flex-col items-center justify-center py-20 gap-3">
      <UIcon name="i-lucide-layout-dashboard" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Dashboard</p>
    </div>
  </div>
</template>
