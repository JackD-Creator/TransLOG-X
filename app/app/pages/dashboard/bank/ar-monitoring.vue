<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Monitoring AR' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arList = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('*, ksm_tenant:ksm_tenant_id(name), facility:facility_id(facility_number, interest_rate_pa, tenor_days)')
    .not('status', 'in', '("pending")')
    .order('due_date', { ascending: true })
    .limit(100)
  arList.value = data ?? []
  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const today = new Date().toISOString().slice(0, 10)
function daysDiff(d: string) {
  return Math.round((new Date(d).getTime() - new Date(today).getTime()) / 86400000)
}

const totalDisbursed  = computed(() => arList.value.reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0))
const totalOutstanding = computed(() => arList.value.filter(a => !['paid','defaulted'].includes(a.status)).reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))
const totalInterest   = computed(() => arList.value.reduce((s, a) => s + Number(a.interest_amount ?? 0), 0))

const statusColor: Record<string, string> = {
  disbursed:       'bg-blue-100 text-blue-700',
  partially_paid:  'bg-amber-100 text-amber-700',
  paid:            'bg-emerald-100 text-emerald-700',
  overdue:         'bg-red-100 text-red-700',
  defaulted:       'bg-red-200 text-red-900',
}
const statusLabel: Record<string, string> = {
  disbursed: 'Cair', partially_paid: 'Sebagian', paid: 'Lunas', overdue: 'Overdue', defaulted: 'Default',
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Monitoring AR — Posisi Bank</h1>
      <p class="text-sm text-[#999] mt-0.5">Seluruh AR aktif Bank ke KSM Mitra dalam fasilitas SCF</p>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total Dicairkan ke Distributor</p>
        <p class="text-2xl font-bold text-blue-700">{{ fmtRp(totalDisbursed) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Outstanding (Belum Dibayar KSM)</p>
        <p class="text-2xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total Pendapatan Bunga</p>
        <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(totalInterest) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KSM Mitra</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Cair ke Dist.</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Bunga</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total Tagih ke KSM</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Outstanding</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Due / Sisa</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ (ar.ksm_tenant as any)?.name ?? '-' }}</td>
            <td class="px-4 py-3 text-blue-700 font-bold">{{ fmtRp(ar.disbursed_amount) }}</td>
            <td class="px-4 py-3 text-emerald-700">{{ fmtRp(ar.interest_amount) }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
            <td class="px-4 py-3 font-bold" :class="Number(ar.outstanding_amount) > 0 ? 'text-amber-700' : 'text-emerald-600'">
              {{ fmtRp(Number(ar.outstanding_amount ?? 0)) }}
            </td>
            <td class="px-4 py-3">
              <p class="font-medium" :class="daysDiff(ar.due_date) < 0 ? 'text-red-600' : 'text-[#666]'">{{ fmtDate(ar.due_date) }}</p>
              <p class="text-[#999]" :class="daysDiff(ar.due_date) < 0 ? 'text-red-500' : ''">
                {{ daysDiff(ar.due_date) >= 0 ? `${daysDiff(ar.due_date)} hari lagi` : `${Math.abs(daysDiff(ar.due_date))} hari lalu` }}
              </p>
            </td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full font-medium', statusColor[ar.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[ar.status] ?? ar.status }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
