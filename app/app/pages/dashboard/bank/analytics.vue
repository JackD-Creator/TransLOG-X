<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Analytics Bank' })

const supabase = useSupabaseClient()
const loading = ref(true)

const stats = ref({
  totalFacilityLimit: 0, totalOutstanding: 0, utilizationPct: 0,
  totalDisbursed: 0, totalInterestEarned: 0, yieldPct: 0,
  overdueCount: 0, overdueAmount: 0, nplRatio: 0,
  activeMitras: 0,
})

async function load() {
  loading.value = true
  const [{ data: fac }, { data: ar }] = await Promise.all([
    supabase.from('scf_facilities').select('facility_limit, outstanding, status'),
    supabase.from('ar_accounts').select('status, disbursed_amount, interest_amount, outstanding_amount'),
  ])

  const activeFac = (fac ?? []).filter(f => ['approved','disbursed','partially_repaid'].includes(f.status))
  const totalLimit = activeFac.reduce((s, f) => s + Number(f.facility_limit ?? 0), 0)
  const totalUsed  = activeFac.reduce((s, f) => s + Number(f.outstanding ?? 0), 0)
  const totalDisbursed = (ar ?? []).reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0)
  const totalInterest  = (ar ?? []).reduce((s, a) => s + Number(a.interest_amount ?? 0), 0)
  const overdueAR = (ar ?? []).filter(a => a.status === 'overdue')
  const overdueAmt = overdueAR.reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0)

  stats.value = {
    totalFacilityLimit: totalLimit,
    totalOutstanding: totalUsed,
    utilizationPct: totalLimit > 0 ? (totalUsed / totalLimit * 100) : 0,
    totalDisbursed,
    totalInterestEarned: totalInterest,
    yieldPct: totalDisbursed > 0 ? (totalInterest / totalDisbursed * 100) : 0,
    overdueCount: overdueAR.length,
    overdueAmount: overdueAmt,
    nplRatio: totalUsed > 0 ? (overdueAmt / totalUsed * 100) : 0,
    activeMitras: activeFac.length,
  }
  loading.value = false
}

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n / 1e9).toFixed(1)} M`
  if (n >= 1e6) return `Rp ${(n / 1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Analytics SCF Portfolio</h1>
      <p class="text-sm text-[#999] mt-0.5">Kinerja portofolio Supply Chain Finance Bank</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-5">
      <!-- KPI row 1 -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] mb-1">Total Limit Portfolio</p>
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(stats.totalFacilityLimit) }}</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] mb-1">Outstanding</p>
          <p class="text-2xl font-bold text-amber-600">{{ fmtRp(stats.totalOutstanding) }}</p>
          <p class="text-xs text-[#999]">{{ stats.utilizationPct.toFixed(1) }}% utilisasi</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] mb-1">Total Dicairkan</p>
          <p class="text-2xl font-bold text-blue-700">{{ fmtRp(stats.totalDisbursed) }}</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] mb-1">Pendapatan Bunga</p>
          <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(stats.totalInterestEarned) }}</p>
          <p class="text-xs text-[#999]">Yield {{ stats.yieldPct.toFixed(2) }}%</p>
        </div>
      </div>

      <!-- KPI row 2 -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-bold text-[#1a1a1a] uppercase tracking-wide mb-3">NPL (Non-Performing Loan)</p>
          <p class="text-3xl font-bold mb-1" :class="stats.nplRatio > 5 ? 'text-red-600' : stats.nplRatio > 2 ? 'text-amber-600' : 'text-emerald-600'">
            {{ stats.nplRatio.toFixed(2) }}%
          </p>
          <p class="text-xs text-[#999]">{{ stats.overdueCount }} AR overdue · {{ fmtRp(stats.overdueAmount) }}</p>
          <p class="text-xs mt-2" :class="stats.nplRatio <= 2 ? 'text-emerald-600' : stats.nplRatio <= 5 ? 'text-amber-600' : 'text-red-600'">
            {{ stats.nplRatio <= 2 ? '✓ Baik (target NPL <2%)' : stats.nplRatio <= 5 ? '⚠ Waspada (target NPL <2%)' : '⚠ Perlu tindakan segera' }}
          </p>
        </div>

        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-bold text-[#1a1a1a] uppercase tracking-wide mb-3">Utilisasi Limit</p>
          <div class="mb-2">
            <div class="flex justify-between text-xs text-[#999] mb-1.5">
              <span>{{ fmtRp(stats.totalOutstanding) }}</span>
              <span>{{ stats.utilizationPct.toFixed(1) }}%</span>
            </div>
            <div class="w-full bg-[#e5e5e5] rounded-full h-3">
              <div class="h-3 rounded-full transition-all"
                :class="stats.utilizationPct > 85 ? 'bg-red-500' : stats.utilizationPct > 65 ? 'bg-amber-500' : 'bg-[#6b1525]'"
                :style="`width:${Math.min(100, stats.utilizationPct)}%`"/>
            </div>
          </div>
          <p class="text-xs text-[#999]">dari {{ fmtRp(stats.totalFacilityLimit) }} total limit</p>
        </div>

        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-bold text-[#1a1a1a] uppercase tracking-wide mb-3">Mitra Aktif</p>
          <p class="text-3xl font-bold text-[#1a1a1a] mb-1">{{ stats.activeMitras }}</p>
          <p class="text-xs text-[#999]">fasilitas aktif dengan mitra KSM/Distributor</p>
        </div>
      </div>
    </div>
  </div>
</template>
