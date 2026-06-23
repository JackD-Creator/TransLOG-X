<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pengiriman' })

const supabase = useSupabaseClient()
const loading = ref(true)
const items = ref<any[]>([])

async function loadData() {
  loading.value = true
  const { data } = await supabase.from('ksm_purchase_orders')
    .select('id,po_number,total_amount,status,expected_delivery')
    .in('status',['confirmed','processing','delivered'])
    .order('expected_delivery', { ascending: true }).limit(30)
  items.value = data ?? []
  loading.value = false
}

const statusMap: Record<string,{label:string;cls:string}> = {
  confirmed:  { label:'Dikonfirmasi', cls:'bg-blue-100 text-blue-700' },
  processing: { label:'Dalam Perjalanan', cls:'bg-amber-100 text-amber-700' },
  delivered:  { label:'Terkirim', cls:'bg-emerald-100 text-emerald-700' },
}

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(1)} M`
  return `Rp ${(n/1e6).toFixed(0)} jt`
}

onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pengiriman & Delivery</h1>
      <p class="text-sm text-[#999] mt-0.5">Status pengiriman PO yang sedang diproses atau sudah terkirim ke KSM/RS mitra</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>
    <div v-else-if="!items.length" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-truck" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada pengiriman aktif</p>
    </div>
    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 border-b border-[#e5e5e5]">
        <p class="text-xs text-[#999]">{{ items.length }} pengiriman</p>
      </div>
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] text-left">
          <tr class="text-[#999] font-semibold text-[10px] uppercase">
            <th class="px-4 py-3">No. PO</th>
            <th class="px-4 py-3 text-right">Nilai</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3">Est. Tiba</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="d in items" :key="d.id" class="hover:bg-[#ebebeb]">
            <td class="px-4 py-3 font-mono text-[#666]">{{ d.po_number }}</td>
            <td class="px-4 py-3 text-right font-semibold text-[#1a1a1a]">{{ fmtRp(Number(d.total_amount)) }}</td>
            <td class="px-4 py-3">
              <span :class="['text-[10px] px-2 py-0.5 rounded-full font-medium', (statusMap[d.status]?.cls ?? 'bg-gray-100 text-gray-600')]">
                {{ statusMap[d.status]?.label ?? d.status }}
              </span>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ d.expected_delivery ? new Date(d.expected_delivery).toLocaleDateString('id-ID') : '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
