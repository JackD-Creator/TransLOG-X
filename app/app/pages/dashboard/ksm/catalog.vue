<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Katalog Supplier' })

const supabase = useSupabaseClient()

const loading = ref(true)
const items = ref<any[]>([])
const search = ref('')
const activeType = ref('semua')

const filtered = computed(() => {
  let list = items.value
  if (activeType.value !== 'semua') list = list.filter(i => i.catalog_type === activeType.value)
  if (search.value.trim()) {
    const q = search.value.toLowerCase()
    list = list.filter(i =>
      i.name.toLowerCase().includes(q) ||
      (i.kfa_code ?? '').includes(q) ||
      (i.distributor ?? '').toLowerCase().includes(q)
    )
  }
  return list
})

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('supplier_catalog_items')
    .select('*, tenants:tenant_id(name, city)')
    .order('name', { ascending: true })
    .limit(500)
  items.value = (data ?? []).map(d => ({
    ...d,
    distributor: (d.tenants as any)?.name ?? '-',
    kota: (d.tenants as any)?.city ?? '',
  }))
  loading.value = false
}

const typeColor: Record<string, string> = {
  obat:  'bg-blue-100 text-blue-700',
  alkes: 'bg-purple-100 text-purple-700',
  bmhp:  'bg-amber-100 text-amber-700',
}

const totalDistributor = computed(() => new Set(items.value.map(i => i.tenant_id)).size)

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Katalog Supplier</h1>
        <p class="text-sm text-[#999] mt-0.5">Item yang ditawarkan distributor mitra — harga & ketersediaan stok</p>
      </div>
      <NuxtLink to="/dashboard/ksm/purchase-orders/new"
        class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors">
        <UIcon name="i-lucide-plus" class="text-sm"/>
        Buat PO
      </NuxtLink>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Item</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ items.length }}</p>
        <p class="text-[10px] text-[#aaa]">item di katalog</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Distributor</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ totalDistributor }}</p>
        <p class="text-[10px] text-[#aaa]">supplier aktif</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Tersedia (Stok)</p>
        <p class="text-2xl font-bold text-emerald-700">{{ items.filter(i => (i.stock_available ?? 0) > 0).length }}</p>
        <p class="text-[10px] text-[#aaa]">item ada stok</p>
      </div>
    </div>

    <!-- Filter + Search -->
    <div class="flex items-center gap-3 flex-wrap">
      <div class="flex gap-1.5">
        <button v-for="f in ['semua','obat','alkes','bmhp']" :key="f" @click="activeType = f"
          :class="['px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors',
            activeType === f ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
          {{ f === 'semua' ? 'Semua' : f.toUpperCase() }}
        </button>
      </div>
      <div class="flex items-center gap-2 px-4 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] flex-1 max-w-xs">
        <UIcon name="i-lucide-search" class="text-sm text-[#999]"/>
        <input v-model="search" type="text" placeholder="Nama obat, kode KFA, atau distributor..."
          class="bg-transparent text-xs text-[#1a1a1a] outline-none placeholder:text-[#999] w-full">
      </div>
      <span class="text-xs text-[#999] ml-auto">{{ filtered.length }} item</span>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <!-- Belum ada data -->
    <div v-else-if="items.length === 0"
      class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-store" class="text-4xl text-[#ccc]"/>
      <div class="text-center">
        <p class="text-sm font-semibold text-[#666]">Katalog Distributor Kosong</p>
        <p class="text-xs text-[#999] mt-1">Distributor belum menambahkan produk ke katalog mereka.</p>
        <p class="text-xs text-[#999]">Login sebagai akun Distributor untuk mengisi katalog.</p>
      </div>
      <NuxtLink to="/dashboard/ksm/supplier-check"
        class="mt-2 px-4 py-2 rounded-lg border border-[#e5e5e5] text-xs font-semibold text-[#6b1525] hover:bg-[#f5f5f5] transition-colors">
        Cek Harga dari Referensi KFA →
      </NuxtLink>
    </div>

    <div v-else-if="filtered.length === 0"
      class="flex flex-col items-center justify-center py-10 gap-2 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-search-x" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada item cocok untuk "{{ search }}"</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] bg-[#ebebeb]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Kode KFA</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Nama Item</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Tipe</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Distributor</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-right">Harga Jual</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-center">Stok</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-center">Lead Time</th>
            <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-center">Termin</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in filtered" :key="item.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#666]">{{ item.kfa_code }}</td>
            <td class="px-4 py-3">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p class="text-[#aaa]">{{ item.uom }}</p>
            </td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', typeColor[item.catalog_type] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ (item.catalog_type ?? '').toUpperCase() }}
              </span>
            </td>
            <td class="px-4 py-3">
              <p class="text-[#1a1a1a] font-medium">{{ item.distributor }}</p>
              <p v-if="item.kota" class="text-[#aaa]">{{ item.kota }}</p>
            </td>
            <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(item.sell_price ?? 0) }}</td>
            <td class="px-4 py-3 text-center">
              <span :class="['font-semibold', (item.stock_available ?? 0) > 0 ? 'text-emerald-600' : 'text-red-500']">
                {{ (item.stock_available ?? 0) > 0 ? item.stock_available.toLocaleString('id-ID') : 'Habis' }}
              </span>
            </td>
            <td class="px-4 py-3 text-center text-[#666]">{{ item.lead_time_days ?? '-' }} hari</td>
            <td class="px-4 py-3 text-center text-[#666]">{{ (item.payment_terms ?? '-').replace('net_', 'Net ') }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
