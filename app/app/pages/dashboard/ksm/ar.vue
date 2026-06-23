<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'AR & Tagihan' })

const supabase = useSupabaseClient()

const loading = ref(true)
const arList = ref<any[]>([])

const statusColor: Record<string, string> = {
  pending:         'bg-[#f0f0f0] text-[#999]',
  disbursed:       'bg-blue-100 text-blue-700',
  partially_paid:  'bg-amber-100 text-amber-700',
  paid:            'bg-emerald-100 text-emerald-700',
  overdue:         'bg-red-100 text-red-700',
  defaulted:       'bg-red-200 text-red-800',
}
const statusLabel: Record<string, string> = {
  pending: 'Pending', disbursed: 'Cair', partially_paid: 'Dibayar Sebagian',
  paid: 'Lunas', overdue: 'Jatuh Tempo', defaulted: 'Default',
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('*, tenants:bank_tenant_id(name)')
    .order('due_date', { ascending: true })
    .limit(50)
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
  const diff = Math.round((new Date(d).getTime() - new Date(today).getTime()) / 86400000)
  return diff
}

const totalOutstanding = computed(() => arList.value.reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))
const totalOverdue = computed(() => arList.value.filter(a => a.status === 'overdue').reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">AR & Tagihan ke Bank</h1>
      <p class="text-sm text-[#999] mt-0.5">Posisi piutang KSM ke Bank dalam fasilitas SCF / Reverse Factoring</p>
    </div>

    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Total AR Outstanding</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(totalOutstanding) }}</p>
        <p class="text-xs text-[#999] mt-1">{{ arList.filter(a => !['paid','defaulted'].includes(a.status)).length }} tagihan aktif</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Jatuh Tempo / Overdue</p>
        <p class="text-2xl font-bold text-red-600">{{ fmtRp(totalOverdue) }}</p>
        <p class="text-xs text-[#999] mt-1">{{ arList.filter(a => a.status === 'overdue').length }} tagihan overdue</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Lunas Bulan Ini</p>
        <p class="text-2xl font-bold text-emerald-600">{{ fmtRp(arList.filter(a => a.status === 'paid').reduce((s,a) => s + Number(a.total_payable), 0)) }}</p>
        <p class="text-xs text-[#999] mt-1">{{ arList.filter(a => a.status === 'paid').length }} tagihan lunas</p>
      </div>
    </div>

    <!-- AR Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div v-if="loading" class="flex items-center justify-center py-16">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>
      <div v-else-if="arList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-file-text" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada AR tercatat</p>
      </div>
      <table v-else class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Bank</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nilai Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Outstanding</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Jatuh Tempo</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ (ar.tenants as any)?.name ?? '-' }}</td>
            <td class="px-4 py-3 font-mono text-[#666]">{{ ar.invoice_ref ?? '-' }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.invoice_amount) }}</td>
            <td class="px-4 py-3 font-bold" :class="Number(ar.outstanding_amount) > 0 ? 'text-amber-700' : 'text-emerald-600'">
              {{ fmtRp(Number(ar.outstanding_amount ?? 0)) }}
            </td>
            <td class="px-4 py-3">
              <p :class="['font-medium', daysDiff(ar.due_date) < 0 ? 'text-red-600' : daysDiff(ar.due_date) <= 7 ? 'text-amber-600' : 'text-[#666]']">
                {{ fmtDate(ar.due_date) }}
              </p>
              <p v-if="daysDiff(ar.due_date) >= 0" class="text-[#999]">{{ daysDiff(ar.due_date) }} hari lagi</p>
              <p v-else class="text-red-500">{{ Math.abs(daysDiff(ar.due_date)) }} hari lalu</p>
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
