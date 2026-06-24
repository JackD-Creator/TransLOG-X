<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pencairan Dana' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arList = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('id,ar_number,po_number,invoice_ref,invoice_amount,disbursed_amount,interest_amount,total_payable,paid_amount,outstanding_amount,disbursement_date,due_date,paid_date,status')
    .in('status', ['disbursed', 'partially_paid', 'paid', 'overdue'])
    .order('disbursement_date', { ascending: false })
    .limit(50)
  arList.value = data ?? []
  loading.value = false
}



const totalDisbursed = computed(() => arList.value.reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pencairan Dana ke Distributor</h1>
      <p class="text-sm text-[#999] mt-0.5">History pencairan Bank ke Distributor atas PO KSM (Reverse Factoring)</p>
    </div>

    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs text-[#999] mb-1">Total Dana Dicairkan</p>
      <p class="text-3xl font-bold text-blue-700">{{ fmtRp(totalDisbursed) }}</p>
      <p class="text-xs text-[#999] mt-1">{{ arList.length }} transaksi</p>
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
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Cair</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Cair ke Dist.</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Bunga</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total Tagih KSM</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Due Date</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">KSM Mitra</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.disbursement_date) }}</td>
            <td class="px-4 py-3 font-bold text-blue-700">{{ fmtRp(ar.disbursed_amount) }}</td>
            <td class="px-4 py-3 text-emerald-700">+{{ fmtRp(ar.interest_amount) }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium',
                ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                ar.status === 'overdue' ? 'bg-red-100 text-red-700' :
                ar.status === 'partially_paid' ? 'bg-amber-100 text-amber-700' :
                'bg-blue-100 text-blue-700']">
                {{ ar.status === 'paid' ? 'Lunas' : ar.status === 'overdue' ? 'Overdue' : ar.status === 'partially_paid' ? 'Sebagian' : 'Cair' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
