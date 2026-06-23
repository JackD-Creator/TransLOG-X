<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Stok Gudang Distributor' })

const supabase = useSupabaseClient()
const loading = ref(true)
const items = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('supplier_catalog_items')
    .select('*')
    .order('stock_available', { ascending: true })
    .limit(100)
  items.value = data ?? []
  loading.value = false
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Stok Gudang</h1>
      <p class="text-sm text-[#999] mt-0.5">Posisi stok produk di gudang distributor</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="items.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-warehouse" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada data stok</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Produk</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Kode KFA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Stok</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Min Order</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Lead Time</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in items" :key="item.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-2.5">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p class="text-[#999]">{{ item.uom }}</p>
            </td>
            <td class="px-4 py-2.5 font-mono text-[#666]">{{ item.kfa_code }}</td>
            <td class="px-4 py-2.5">
              <span :class="['font-bold text-sm', item.stock_available === 0 ? 'text-red-600' : item.stock_available < 10 ? 'text-amber-600' : 'text-emerald-600']">
                {{ item.stock_available.toLocaleString('id-ID') }}
              </span>
            </td>
            <td class="px-4 py-2.5 text-[#666]">{{ item.min_order_qty }} {{ item.min_order_uom }}</td>
            <td class="px-4 py-2.5 text-[#666]">{{ item.lead_time_days }} hari</td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium', item.is_available && item.stock_available > 0 ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700']">
                {{ item.is_available && item.stock_available > 0 ? 'Ready' : 'Kosong' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
