<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pembayaran KSM' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arList = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('*, tenants:bank_tenant_id(name)')
    .in('status', ['disbursed', 'partially_paid', 'paid'])
    .order('disbursement_date', { ascending: false })
    .limit(30)
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

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Rekonsiliasi Pembayaran</h1>
      <p class="text-sm text-[#999] mt-0.5">Pembayaran dari Bank ke Distributor atas nama KSM & cicilan KSM ke Bank</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="arList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-banknote" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada data pembayaran</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Bank</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Cair</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Dicairkan ke Dist.</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Bunga</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total Bayar ke Bank</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Sudah Dibayar</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ (ar.tenants as any)?.name ?? '-' }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.disbursement_date) }}</td>
            <td class="px-4 py-3 font-bold text-blue-700">{{ fmtRp(ar.disbursed_amount) }}</td>
            <td class="px-4 py-3 text-red-600">{{ fmtRp(ar.interest_amount) }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
            <td class="px-4 py-3 text-emerald-600 font-bold">{{ fmtRp(ar.paid_amount) }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium',
                ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                ar.status === 'partially_paid' ? 'bg-amber-100 text-amber-700' :
                'bg-blue-100 text-blue-700']">
                {{ ar.status === 'paid' ? 'Lunas' : ar.status === 'partially_paid' ? 'Sebagian' : 'Cair' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
