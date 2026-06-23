<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Analytics KSM' })

const supabase = useSupabaseClient()
const loading = ref(true)

const stats = ref({
  totalRevenue: 0,
  totalCogs: 0,
  grossMargin: 0,
  pendingNotifications: 0,
  activePOs: 0,
  overdueAR: 0,
  utilizationPct: 0,
})

async function load() {
  loading.value = true

  const [{ data: notifs }, { data: pos }, { data: ar }, { data: scf }] = await Promise.all([
    supabase.from('hospital_notifications').select('id, status'),
    supabase.from('ksm_purchase_orders').select('id, status, total_amount'),
    supabase.from('ar_accounts').select('id, status, outstanding_amount'),
    supabase.from('scf_facilities').select('facility_limit, outstanding').eq('status', 'approved'),
  ])

  const totalRevAR = (ar ?? []).reduce((s: number, a: any) => s + Number(a.outstanding_amount ?? 0), 0)
  const totalPOCost = (pos ?? []).reduce((s: number, p: any) => s + Number(p.total_amount ?? 0), 0)
  const totalLimit = (scf ?? []).reduce((s: number, f: any) => s + Number(f.facility_limit ?? 0), 0)
  const totalUsed  = (scf ?? []).reduce((s: number, f: any) => s + Number(f.outstanding ?? 0), 0)

  stats.value = {
    totalRevenue:         totalRevAR,
    totalCogs:            totalPOCost,
    grossMargin:          totalRevAR > 0 ? ((totalRevAR - totalPOCost) / totalRevAR * 100) : 0,
    pendingNotifications: (notifs ?? []).filter(n => n.status === 'pending').length,
    activePOs:            (pos ?? []).filter(p => ['submitted','sent_to_supplier','partially_received'].includes(p.status)).length,
    overdueAR:            (ar ?? []).filter(a => a.status === 'overdue').length,
    utilizationPct:       totalLimit > 0 ? (totalUsed / totalLimit * 100) : 0,
  }

  loading.value = false
}

function fmtRp(n: number) {
  if (n >= 1e9)  return `Rp ${(n / 1e9).toFixed(1)} M`
  if (n >= 1e6)  return `Rp ${(n / 1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Analytics & Kinerja KSM</h1>
      <p class="text-sm text-[#999] mt-0.5">Overview operasional dan keuangan KSM secara real-time</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-5">
      <!-- KPI Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Total AR</p>
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(stats.totalRevenue) }}</p>
          <p class="text-xs text-emerald-600 mt-1">Piutang aktif ke Bank</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Gross Margin</p>
          <p class="text-2xl font-bold" :class="stats.grossMargin >= 10 ? 'text-emerald-600' : 'text-amber-600'">
            {{ stats.grossMargin.toFixed(1) }}%
          </p>
          <p class="text-xs text-[#999] mt-1">Target ≥ 10%</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] uppercase tracking-wide mb-2">PO Aktif</p>
          <p class="text-2xl font-bold text-blue-600">{{ stats.activePOs }}</p>
          <p class="text-xs text-[#999] mt-1">Sedang berjalan</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] uppercase tracking-wide mb-2">AR Overdue</p>
          <p class="text-2xl font-bold" :class="stats.overdueAR > 0 ? 'text-red-600' : 'text-emerald-600'">
            {{ stats.overdueAR }}
          </p>
          <p class="text-xs text-[#999] mt-1">Tagihan jatuh tempo</p>
        </div>
      </div>

      <!-- Ops + SCF -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <h3 class="text-sm font-bold text-[#1a1a1a] mb-4">Status Operasional</h3>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <UIcon name="i-lucide-bell-ring" class="text-amber-500 text-sm"/>
                <span class="text-sm text-[#666]">Notifikasi RS Pending</span>
              </div>
              <span class="font-bold text-[#1a1a1a]">{{ stats.pendingNotifications }}</span>
            </div>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <UIcon name="i-lucide-shopping-cart" class="text-blue-500 text-sm"/>
                <span class="text-sm text-[#666]">PO Aktif ke Distributor</span>
              </div>
              <span class="font-bold text-[#1a1a1a]">{{ stats.activePOs }}</span>
            </div>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <UIcon name="i-lucide-alert-triangle" class="text-red-500 text-sm"/>
                <span class="text-sm text-[#666]">AR Overdue ke Bank</span>
              </div>
              <span class="font-bold" :class="stats.overdueAR > 0 ? 'text-red-600' : 'text-emerald-600'">{{ stats.overdueAR }}</span>
            </div>
          </div>
        </div>

        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <h3 class="text-sm font-bold text-[#1a1a1a] mb-4">Utilisasi Fasilitas SCF</h3>
          <div class="mb-3">
            <div class="flex justify-between text-xs text-[#999] mb-2">
              <span>Terpakai vs Limit</span>
              <span class="font-bold text-[#1a1a1a]">{{ stats.utilizationPct.toFixed(1) }}%</span>
            </div>
            <div class="w-full bg-[#e5e5e5] rounded-full h-3">
              <div class="h-3 rounded-full transition-all"
                :class="stats.utilizationPct > 80 ? 'bg-red-500' : stats.utilizationPct > 60 ? 'bg-amber-500' : 'bg-[#6b1525]'"
                :style="`width:${Math.min(100, stats.utilizationPct)}%`"/>
            </div>
          </div>
          <div class="flex gap-2">
            <NuxtLink to="/dashboard/ksm/scf" class="text-xs text-[#6b1525] font-semibold hover:text-[#5a1120]">
              Lihat Detail Fasilitas →
            </NuxtLink>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
