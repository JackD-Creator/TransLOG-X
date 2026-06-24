<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Aktivasi Term of Payment' })

const supabase = useSupabaseClient()
const loading = ref(true)
const pending = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('id,ar_number,po_number,invoice_ref,invoice_amount,disbursed_amount,due_date,status,top_activated_at')
    .eq('status', 'disbursed')
    .is('top_activated_at', null)
    .order('due_date', { ascending: true })
    .limit(50)
  pending.value = data ?? []
  loading.value = false
}

async function activateToP(id: string) {
  await supabase.from('ar_accounts').update({ top_activated_at: new Date().toISOString() }).eq('id', id)
  await load()
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
      <h1 class="text-xl font-bold text-[#1a1a1a]">Aktivasi Term of Payment (ToP)</h1>
      <p class="text-sm text-[#999] mt-0.5">AR yang sudah cair ke Distributor namun ToP belum diaktifkan ke KSM</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="pending.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Semua AR sudah diaktivasi ToP</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No AR</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KSM Mitra</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total Tagih</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Due Date</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Aktivasi ToP</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in pending" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">KSM Mitra</td>
            <td class="px-4 py-3 font-mono text-[#666]">{{ ar.invoice_ref ?? '-' }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
            <td class="px-4 py-3">
              <button class="px-3 py-1.5 bg-[#6b1525] text-white text-[10px] font-bold rounded-lg hover:bg-[#5a1120] transition-colors"
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
