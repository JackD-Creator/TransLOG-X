<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Cek Supplier' })

const supabase = useSupabaseClient()

const search = ref('')
const loading = ref(false)
const results = ref<any[]>([])
const searched = ref(false)

async function doSearch() {
  if (!search.value.trim()) return
  loading.value = true
  searched.value = true

  const q = search.value.trim()
  const { data } = await supabase
    .from('supplier_catalog_items')
    .select('*, tenants:tenant_id(name, city)')
    .ilike('name', `%${q}%`)
    .eq('is_available', true)
    .order('sell_price', { ascending: true })
    .limit(30)

  results.value = data ?? []
  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

const paymentLabels: Record<string, string> = {
  cod: 'COD', net_7: 'Net 7', net_14: 'Net 14',
  net_30: 'Net 30', net_45: 'Net 45', net_60: 'Net 60',
  net_90: 'Net 90', net_120: 'Net 120',
}
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Cek Ketersediaan Supplier</h1>
      <p class="text-sm text-[#999] mt-0.5">Cari item dari katalog distributor — bandingkan harga & ketersediaan</p>
    </div>

    <!-- Search -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <form class="flex gap-3" @submit.prevent="doSearch">
        <div class="flex-1 flex items-center gap-2 px-4 py-2.5 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
          <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
          <input
            v-model="search"
            type="text"
            placeholder="Nama obat, alkes, atau kode KFA..."
            class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#999]"
          >
        </div>
        <button type="submit" :disabled="loading"
          class="px-5 py-2.5 bg-[#6b1525] text-white text-sm font-semibold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
          {{ loading ? 'Mencari...' : 'Cari' }}
        </button>
      </form>
    </div>

    <!-- Results -->
    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="searched && results.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-x" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada item ditemukan untuk "<strong>{{ search }}</strong>"</p>
    </div>

    <div v-else-if="results.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-4 py-3 border-b border-[#e5e5e5]">
        <p class="text-xs text-[#999]">Ditemukan <strong class="text-[#1a1a1a]">{{ results.length }}</strong> hasil untuk "{{ search }}"</p>
      </div>
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Item / KFA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Distributor</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Harga Jual</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Stok</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Lead Time</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Termin</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in results" :key="item.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p class="text-[#999] font-mono">{{ item.kfa_code }}</p>
            </td>
            <td class="px-4 py-3">
              <p class="text-[#666]">{{ (item.tenants as any)?.name ?? '-' }}</p>
              <p class="text-[#999]">{{ (item.tenants as any)?.city ?? '' }}</p>
            </td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(item.sell_price) }}</td>
            <td class="px-4 py-3">
              <span :class="['font-semibold', item.stock_available > 0 ? 'text-emerald-600' : 'text-red-500']">
                {{ item.stock_available > 0 ? item.stock_available.toLocaleString('id-ID') : 'Habis' }}
              </span>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ item.lead_time_days }} hari</td>
            <td class="px-4 py-3 text-[#666]">{{ paymentLabels[item.payment_terms] ?? item.payment_terms }}</td>
            <td class="px-4 py-3">
              <button class="text-[#6b1525] font-semibold hover:text-[#5a1120] whitespace-nowrap">
                + Pilih
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
