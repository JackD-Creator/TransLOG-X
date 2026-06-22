<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const search   = ref('')
const category = ref('all')
const page     = ref(1)
const perPage  = 20

const categories = [
  { label: 'Semua',       value: 'all' },
  { label: 'Obat',        value: 'obat' },
  { label: 'Alkes',       value: 'alkes' },
  { label: 'BMHP',        value: 'bmhp' },
  { label: 'Reagensia',   value: 'reagensia' },
]

const stockFilters = [
  { label: 'Semua Status', value: 'all' },
  { label: 'Stok Normal',  value: 'normal' },
  { label: 'Hampir Habis', value: 'low' },
  { label: 'Habis',        value: 'empty' },
]
const stockFilter = ref('all')

// Mock data — akan diganti dengan query Supabase
const items = ref([
  { id: 1, kode: 'OBT-001', nama: 'Paracetamol 500mg', kategori: 'Obat', satuan: 'Tablet', stok: 1250, min_stok: 200, max_stok: 2000, harga: 850, lokasi: 'GD-A/R01' },
  { id: 2, kode: 'OBT-002', nama: 'Amoxicillin 500mg', kategori: 'Obat', satuan: 'Kapsul', stok: 80,   min_stok: 100, max_stok: 1000, harga: 2100, lokasi: 'GD-A/R01' },
  { id: 3, kode: 'OBT-003', nama: 'Omeprazole 20mg',   kategori: 'Obat', satuan: 'Kapsul', stok: 0,    min_stok: 50,  max_stok: 500,  harga: 3200, lokasi: 'GD-A/R02' },
  { id: 4, kode: 'ALK-001', nama: 'Spuit 3cc',          kategori: 'Alkes', satuan: 'Pcs',  stok: 4500, min_stok: 500, max_stok: 5000, harga: 1500, lokasi: 'GD-B/R01' },
  { id: 5, kode: 'ALK-002', nama: 'Infus Set Dewasa',   kategori: 'Alkes', satuan: 'Set',  stok: 320,  min_stok: 100, max_stok: 1000, harga: 8500, lokasi: 'GD-B/R01' },
  { id: 6, kode: 'BMH-001', nama: 'Handscoon Latex M',  kategori: 'BMHP',  satuan: 'Pasang', stok: 60, min_stok: 200, max_stok: 2000, harga: 3500, lokasi: 'GD-B/R02' },
  { id: 7, kode: 'REG-001', nama: 'Strip Gula Darah',   kategori: 'Reagensia', satuan: 'Strip', stok: 150, min_stok: 100, max_stok: 500, harga: 6000, lokasi: 'GD-C/R01' },
])

const filtered = computed(() => {
  return items.value.filter(i => {
    const matchSearch = search.value === '' ||
      i.nama.toLowerCase().includes(search.value.toLowerCase()) ||
      i.kode.toLowerCase().includes(search.value.toLowerCase())
    const matchCat = category.value === 'all' || i.kategori.toLowerCase() === category.value
    const matchStock =
      stockFilter.value === 'all'    ? true :
      stockFilter.value === 'empty'  ? i.stok === 0 :
      stockFilter.value === 'low'    ? i.stok > 0 && i.stok <= i.min_stok :
      i.stok > i.min_stok
    return matchSearch && matchCat && matchStock
  })
})

function stockBadge(item: any) {
  if (item.stok === 0)               return { label: 'Habis',        class: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400' }
  if (item.stok <= item.min_stok)    return { label: 'Hampir Habis', class: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400' }
  return                                    { label: 'Normal',        class: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400' }
}

const summary = computed(() => ({
  total:  items.value.length,
  normal: items.value.filter(i => i.stok > i.min_stok).length,
  low:    items.value.filter(i => i.stok > 0 && i.stok <= i.min_stok).length,
  empty:  items.value.filter(i => i.stok === 0).length,
}))
</script>

<template>
  <div class="space-y-5">

    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Inventory</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Kelola stok obat, alkes, BMHP & reagensia</p>
      </div>
      <div class="flex gap-2">
        <UButton icon="i-lucide-download" color="neutral" variant="outline" size="sm">Export</UButton>
        <NuxtLink to="/dashboard/inventory/add">
          <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah SKU</UButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div
        v-for="(val, key) in [
          { label: 'Total SKU',     value: summary.total,  icon: 'i-lucide-package',      color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
          { label: 'Stok Normal',   value: summary.normal, icon: 'i-lucide-check-circle', color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
          { label: 'Hampir Habis',  value: summary.low,    icon: 'i-lucide-alert-triangle',color: 'text-amber-600', bg: 'bg-amber-50 dark:bg-amber-950' },
          { label: 'Stok Habis',    value: summary.empty,  icon: 'i-lucide-x-circle',     color: 'text-red-600',    bg: 'bg-red-50 dark:bg-red-950' },
        ]"
        :key="key"
        class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3"
      >
        <div :class="[val.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="val.icon" :class="[val.color, 'text-lg']" />
        </div>
        <div>
          <p class="text-xl font-bold text-gray-900 dark:text-white">{{ val.value }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400">{{ val.label }}</p>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex flex-wrap gap-3 items-center">
      <div class="flex-1 min-w-48">
        <input
          v-model="search"
          type="text"
          placeholder="Cari nama atau kode SKU..."
          class="w-full bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-500"
        >
      </div>
      <div class="flex gap-2 flex-wrap">
        <button
          v-for="cat in categories"
          :key="cat.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :class="category === cat.value
            ? 'bg-red-600 text-white'
            : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'"
          @click="category = cat.value"
        >
          {{ cat.label }}
        </button>
      </div>
      <div class="flex gap-2 flex-wrap">
        <button
          v-for="sf in stockFilters"
          :key="sf.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :class="stockFilter === sf.value
            ? 'bg-gray-700 text-white dark:bg-gray-200 dark:text-gray-900'
            : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'"
          @click="stockFilter = sf.value"
        >
          {{ sf.label }}
        </button>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Kode</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Nama Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Kategori</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Stok</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Status</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Lokasi</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Harga</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-if="filtered.length === 0">
              <td colspan="8" class="text-center py-12 text-gray-400 dark:text-gray-600">
                <UIcon name="i-lucide-package-open" class="text-3xl mb-2 block mx-auto" />
                Tidak ada item ditemukan
              </td>
            </tr>
            <tr
              v-for="item in filtered"
              :key="item.id"
              class="hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors cursor-pointer"
              @click="$router.push(`/dashboard/inventory/${item.id}`)"
            >
              <td class="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">{{ item.kode }}</td>
              <td class="px-4 py-3 font-medium text-gray-900 dark:text-white">{{ item.nama }}</td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded text-xs bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400">
                  {{ item.kategori }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <span class="font-semibold text-gray-900 dark:text-white">{{ item.stok.toLocaleString('id-ID') }}</span>
                <span class="text-xs text-gray-400 ml-1">{{ item.satuan }}</span>
              </td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', stockBadge(item).class]">
                  {{ stockBadge(item).label }}
                </span>
              </td>
              <td class="px-4 py-3 text-xs text-gray-500 dark:text-gray-400 font-mono">{{ item.lokasi }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">
                Rp {{ item.harga.toLocaleString('id-ID') }}
              </td>
              <td class="px-4 py-3 text-right">
                <UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Footer -->
      <div class="px-4 py-3 border-t border-gray-100 dark:border-gray-800 flex items-center justify-between">
        <p class="text-xs text-gray-500 dark:text-gray-400">
          Menampilkan {{ filtered.length }} dari {{ items.length }} item
        </p>
      </div>
    </div>

  </div>
</template>
