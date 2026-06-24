<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Notifikasi Invoice' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arList = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('id,ar_number,po_number,invoice_ref,invoice_amount,disbursed_amount,interest_amount,total_payable,invoice_date,due_date,status,ksm_tenant_id')
    .eq('status', 'pending')
    .order('invoice_date', { ascending: false })
    .limit(50)
  arList.value = data ?? []
  loading.value = false
}

async function activateToP(id: string) {
  await supabase.from('ar_accounts')
    .update({ status: 'disbursed', top_activated_at: new Date().toISOString() })
    .eq('id', id)
  await load()
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
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Notifikasi Invoice Masuk</h1>
        <p class="text-sm text-[#999] mt-0.5">Invoice dari KSM yang perlu diverifikasi sebelum Bank aktivasi ToP</p>
      </div>
      <span class="px-3 py-1.5 rounded-full bg-amber-100 text-amber-700 text-xs font-semibold">
        {{ arList.length }} invoice pending
      </span>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="arList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Tidak ada invoice pending — semua sudah diproses</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR / Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KSM Mitra</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nilai Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Due Date</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3">
              <p class="font-mono text-[#1a1a1a]">{{ ar.ar_number }}</p>
              <p class="text-[#999]">{{ ar.invoice_ref ?? '-' }}</p>
            </td>
            <td class="px-4 py-3 text-[#666]">KSM Mitra</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.invoice_date) }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.invoice_amount) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
            <td class="px-4 py-3">
              <button class="px-3 py-1.5 bg-[#6b1525] text-white rounded-lg text-[10px] font-bold hover:bg-[#5a1120] transition-colors"
                @click="activateToP(ar.id)">
                Aktivasi ToP
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
