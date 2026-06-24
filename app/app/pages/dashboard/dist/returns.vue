<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Retur' })

const supabase = useSupabaseClient()
const loading = ref(true)
const pos = ref<any[]>([])

async function loadData() {
  loading.value = true
  const { data } = await supabase.from('ksm_purchase_orders')
    .select('id,po_number,total_amount,status,created_at')
    .eq('status','cancelled').order('created_at', { ascending: false }).limit(20)
  pos.value = data ?? []
  loading.value = false
}


onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Manajemen Retur</h1>
      <p class="text-sm text-[#999] mt-0.5">PO yang dibatalkan dan proses retur barang dari KSM / RS mitra</p>
    </div>

    <div class="bg-amber-50 border border-amber-200 rounded-xl p-4 text-xs text-amber-800">
      <p class="font-bold mb-1">Kebijakan Retur</p>
      <p>Retur hanya dapat diproses dalam 14 hari dari tanggal penerimaan. Produk harus dalam kondisi original, belum dibuka, dan tidak mendekati expired (&lt;6 bulan). Ajukan klaim via email ke tim logistik distributor dengan lampiran foto dan BA penerimaan barang.</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>
    <div v-else-if="!pos.length" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-x" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada retur aktif</p>
    </div>
    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] text-left">
          <tr class="text-[#999] font-semibold text-[10px] uppercase">
            <th class="px-4 py-3">No. PO</th>
            <th class="px-4 py-3 text-right">Nilai</th>
            <th class="px-4 py-3">Tgl Batal</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="p in pos" :key="p.id" class="hover:bg-[#ebebeb]">
            <td class="px-4 py-3 font-mono text-[#666]">{{ p.po_number }}</td>
            <td class="px-4 py-3 text-right font-semibold text-red-600">{{ fmtRp(Number(p.total_amount)) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ new Date(p.created_at).toLocaleDateString('id-ID') }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
