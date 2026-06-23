<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pembayaran Distributor' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arItems = ref<any[]>([])

async function loadData() {
  loading.value = true
  const { data } = await supabase.from('ar_accounts')
    .select('id,invoice_number,invoice_amount,interest_amount,status,disbursement_date,paid_date,due_date')
    .order('invoice_date', { ascending: false }).limit(30)
  arItems.value = data ?? []
  loading.value = false
}

const totalReceived  = computed(() => arItems.value.filter(a => a.status === 'paid').reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0))
const totalPending   = computed(() => arItems.value.filter(a => a.status !== 'paid').reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0))
const totalInterest  = computed(() => arItems.value.reduce((s,a) => s + Number(a.interest_amount ?? 0), 0))

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (n >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return `Rp ${n.toLocaleString('id-ID')}`
}

const statusCls: Record<string,string> = {
  paid: 'bg-emerald-100 text-emerald-700',
  disbursed: 'bg-blue-100 text-blue-700',
  active: 'bg-amber-100 text-amber-700',
  overdue: 'bg-red-100 text-red-700',
}

onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Rekonsiliasi Pembayaran</h1>
      <p class="text-sm text-[#999] mt-0.5">Status pembayaran dari Bank via SCF (reverse factoring) untuk invoice distributor</p>
    </div>

    <div class="grid grid-cols-3 gap-4">
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Sudah Diterima</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalReceived) }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Menunggu Cair</p>
        <p class="text-xl font-bold text-amber-600">{{ fmtRp(totalPending) }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Bunga SCF</p>
        <p class="text-xl font-bold text-[#6b1525]">{{ fmtRp(totalInterest) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>
    <div v-else-if="!arItems.length" class="flex flex-col items-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-banknote" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada data pembayaran</p>
    </div>
    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] text-left">
          <tr class="text-[#999] font-semibold text-[10px] uppercase">
            <th class="px-4 py-3">Invoice</th>
            <th class="px-4 py-3 text-right">Nilai</th>
            <th class="px-4 py-3 text-right">Bunga SCF</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3">Cair / Lunas</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="a in arItems" :key="a.id" class="hover:bg-[#ebebeb]">
            <td class="px-4 py-3 font-mono text-[10px] text-[#666]">{{ a.invoice_number }}</td>
            <td class="px-4 py-3 text-right font-semibold text-[#1a1a1a]">{{ fmtRp(Number(a.invoice_amount)) }}</td>
            <td class="px-4 py-3 text-right text-[#6b1525]">{{ a.interest_amount ? fmtRp(Number(a.interest_amount)) : '—' }}</td>
            <td class="px-4 py-3">
              <span :class="['text-[10px] px-2 py-0.5 rounded-full font-medium', statusCls[a.status] ?? 'bg-gray-100 text-gray-600']">{{ a.status }}</span>
            </td>
            <td class="px-4 py-3 text-[#666]">
              {{ a.paid_date ? new Date(a.paid_date).toLocaleDateString('id-ID') : a.disbursement_date ? new Date(a.disbursement_date).toLocaleDateString('id-ID') : '—' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
