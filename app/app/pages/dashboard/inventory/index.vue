<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

// ── Filters ───────────────────────────────────────────────────────
const search      = ref('')
const category    = ref('all')
const stockFilter = ref('all')
const page        = ref(1)
const perPage     = 25

const categories = [
  { label: 'Semua',     value: 'all'       },
  { label: 'Obat',      value: 'obat'      },
  { label: 'Alkes',     value: 'alkes'     },
  { label: 'BMHP',      value: 'bmhp'      },
  { label: 'Reagensia', value: 'reagensia' },
]
const stockFilters = [
  { label: 'Semua Status', value: 'all'    },
  { label: 'Stok Normal',  value: 'normal' },
  { label: 'Hampir Habis', value: 'low'    },
  { label: 'Stok Habis',   value: 'empty'  },
]

// ── Data types ────────────────────────────────────────────────────
interface StockSummary {
  qty_on_hand: number
  qty_available: number
  nearest_expiry: string | null
  avg_cost: number | null
}

interface Product {
  id: string
  internal_code: string | null
  name: string
  category: string
  uom_base: string
  min_stock: number
  max_stock: number | null
  standard_price: number | null
  last_purchase_price: number | null
  is_fornas: boolean
  is_narkotika: boolean
  is_psikotropika: boolean
  stock_summary: StockSummary[]
  // computed
  qty: number
  status: 'normal' | 'low' | 'empty'
}

// ── State ─────────────────────────────────────────────────────────
const loading   = ref(true)
const error     = ref<string | null>(null)
const products  = ref<Product[]>([])
const totalCount = ref(0)

// ── Fetch ─────────────────────────────────────────────────────────
async function fetchProducts() {
  loading.value = true
  error.value   = null

  let query = supabase
    .from('products')
    .select(`
      id, internal_code, name, category, uom_base,
      min_stock, max_stock, standard_price, last_purchase_price,
      is_fornas, is_narkotika, is_psikotropika,
      stock_summary(qty_on_hand, qty_available, nearest_expiry, avg_cost)
    `, { count: 'exact' })
    .eq('is_active', true)
    .order('name')

  if (category.value !== 'all') query = query.eq('category', category.value)
  if (search.value)             query = query.ilike('name', `%${search.value}%`)

  const from = (page.value - 1) * perPage
  query = query.range(from, from + perPage - 1)

  const { data, error: err, count } = await query

  if (err) {
    error.value = err.message
    loading.value = false
    return
  }

  // Enrich with computed qty & status
  products.value = (data ?? []).map((p: any) => {
    const ss: StockSummary[] = p.stock_summary ?? []
    const qty = ss.reduce((sum: number, s: StockSummary) => sum + (s.qty_available ?? 0), 0)
    let status: 'normal' | 'low' | 'empty' = 'normal'
    if (qty <= 0)               status = 'empty'
    else if (qty <= p.min_stock) status = 'low'
    return { ...p, qty, status }
  })

  totalCount.value = count ?? 0
  loading.value = false
}

// Filter by stock status (client-side after fetch)
const filtered = computed(() => {
  if (stockFilter.value === 'all') return products.value
  return products.value.filter(p => p.status === stockFilter.value)
})

// ── Summary cards ─────────────────────────────────────────────────
const summary = computed(() => ({
  total:  products.value.length,
  normal: products.value.filter(p => p.status === 'normal').length,
  low:    products.value.filter(p => p.status === 'low').length,
  empty:  products.value.filter(p => p.status === 'empty').length,
}))

// ── Stock badge ───────────────────────────────────────────────────
function stockBadge(p: Product) {
  if (p.status === 'empty') return { label: 'Habis',        cls: 'bg-red-100 text-red-700' }
  if (p.status === 'low')   return { label: 'Hampir Habis', cls: 'bg-amber-100 text-amber-700' }
  return                           { label: 'Normal',        cls: 'bg-emerald-100 text-emerald-700' }
}

function rp(n: number | null) {
  if (!n) return '—'
  return 'Rp ' + n.toLocaleString('id-ID')
}

// ── Watchers: refetch on filter change ────────────────────────────
const searchDebounce = ref<ReturnType<typeof setTimeout>>()
watch(search, () => {
  clearTimeout(searchDebounce.value)
  searchDebounce.value = setTimeout(() => { page.value = 1; fetchProducts() }, 400)
})
watch([category, page], () => fetchProducts())

onMounted(fetchProducts)
</script>

<template>
  <div class="space-y-5">

    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Inventory</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          Kelola stok obat, alkes, BMHP &amp; reagensia
          <span v-if="!loading" class="text-gray-400">· {{ totalCount.toLocaleString('id-ID') }} SKU aktif</span>
        </p>
      </div>
      <div class="flex gap-2">
        <UButton icon="i-lucide-refresh-cw" color="neutral" variant="outline" size="sm" :loading="loading" @click="fetchProducts">
          Refresh
        </UButton>
        <UButton icon="i-lucide-download" color="neutral" variant="outline" size="sm">Export</UButton>
        <NuxtLink to="/dashboard/inventory/add">
          <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah SKU</UButton>
        </NuxtLink>
      </div>
    </div>

    <!-- Error state -->
    <div v-if="error" class="bg-red-50 border border-red-200 rounded-xl p-4 flex items-start gap-3">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-lg flex-shrink-0 mt-0.5"/>
      <div>
        <p class="text-sm font-semibold text-red-700">Gagal memuat data</p>
        <p class="text-xs text-red-500 mt-0.5">{{ error }}</p>
        <p class="text-xs text-red-400 mt-1">
          Pastikan sudah menjalankan <code class="font-mono bg-red-100 px-1 rounded">node supabase/seed_inventory.mjs</code>
          dan login ulang.
        </p>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div
        v-for="card in [
          { label: 'Total SKU',     value: summary.total,  icon: 'i-lucide-package',       color: 'text-blue-600',   bg: 'bg-blue-50' },
          { label: 'Stok Normal',   value: summary.normal, icon: 'i-lucide-check-circle',  color: 'text-emerald-600',bg: 'bg-emerald-50' },
          { label: 'Hampir Habis',  value: summary.low,    icon: 'i-lucide-triangle-alert', color: 'text-amber-600', bg: 'bg-amber-50' },
          { label: 'Stok Habis',    value: summary.empty,  icon: 'i-lucide-x-circle',      color: 'text-red-600',    bg: 'bg-red-50' },
        ]" :key="card.label"
        class="bg-white rounded-xl border border-gray-200 p-4 flex items-center gap-3"
      >
        <div :class="[card.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="card.icon" :class="[card.color, 'text-lg']"/>
        </div>
        <div>
          <p class="text-xl font-bold text-gray-900">
            <span v-if="loading" class="inline-block w-8 h-5 bg-gray-200 rounded animate-pulse"/>
            <span v-else>{{ card.value }}</span>
          </p>
          <p class="text-xs text-gray-500">{{ card.label }}</p>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl border border-gray-200 p-4 flex flex-wrap gap-3 items-center">
      <div class="flex-1 min-w-48 relative">
        <UIcon name="i-lucide-search" class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-sm"/>
        <input
          v-model="search"
          type="text"
          placeholder="Cari nama atau kode SKU..."
          class="w-full bg-gray-50 border border-gray-200 rounded-lg pl-9 pr-3 py-2 text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-500"
        >
      </div>
      <!-- Category -->
      <div class="flex gap-1.5 flex-wrap">
        <button
          v-for="cat in categories" :key="cat.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :class="category === cat.value ? 'bg-red-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
          @click="category = cat.value; page = 1"
        >{{ cat.label }}</button>
      </div>
      <!-- Stock status -->
      <div class="flex gap-1.5 flex-wrap">
        <button
          v-for="sf in stockFilters" :key="sf.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :class="stockFilter === sf.value ? 'bg-gray-800 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
          @click="stockFilter = sf.value"
        >{{ sf.label }}</button>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-200 bg-gray-50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Kode</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Nama Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Kategori</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Stok</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Min</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Status</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Kadaluarsa</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Harga</th>
              <th class="px-4 py-3"/>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">

            <!-- Loading skeleton -->
            <template v-if="loading">
              <tr v-for="i in 8" :key="i" class="animate-pulse">
                <td class="px-4 py-3"><div class="h-3 w-16 bg-gray-200 rounded"/></td>
                <td class="px-4 py-3"><div class="h-3 w-40 bg-gray-200 rounded"/></td>
                <td class="px-4 py-3"><div class="h-3 w-14 bg-gray-200 rounded"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-12 bg-gray-200 rounded ml-auto"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-10 bg-gray-200 rounded ml-auto"/></td>
                <td class="px-4 py-3"><div class="h-4 w-20 bg-gray-200 rounded-full"/></td>
                <td class="px-4 py-3"><div class="h-3 w-20 bg-gray-200 rounded"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-20 bg-gray-200 rounded ml-auto"/></td>
                <td class="px-4 py-3"/>
              </tr>
            </template>

            <!-- Empty state -->
            <tr v-else-if="filtered.length === 0">
              <td colspan="9" class="text-center py-14 text-gray-400">
                <UIcon name="i-lucide-package-open" class="text-4xl mb-3 block mx-auto text-gray-300"/>
                <p class="text-sm font-medium">Tidak ada item ditemukan</p>
                <p class="text-xs mt-1">Coba ubah filter atau jalankan seed inventory</p>
              </td>
            </tr>

            <!-- Data rows -->
            <tr
              v-else
              v-for="item in filtered" :key="item.id"
              class="hover:bg-gray-50 transition-colors cursor-pointer group"
              @click="$router.push(`/dashboard/inventory/${item.id}`)"
            >
              <td class="px-4 py-3">
                <div class="flex items-center gap-1.5">
                  <span class="font-mono text-xs text-gray-500">{{ item.internal_code ?? '—' }}</span>
                  <span v-if="item.is_narkotika"    class="text-[9px] font-bold bg-red-100 text-red-600 px-1 rounded">NAR</span>
                  <span v-if="item.is_psikotropika" class="text-[9px] font-bold bg-purple-100 text-purple-600 px-1 rounded">PSI</span>
                  <span v-if="item.is_fornas"       class="text-[9px] font-bold bg-blue-100 text-blue-600 px-1 rounded">FNS</span>
                </div>
              </td>
              <td class="px-4 py-3 font-medium text-gray-900 group-hover:text-red-700 transition-colors">
                {{ item.name }}
              </td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-600 capitalize">
                  {{ item.category }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <span class="font-semibold text-gray-900">{{ item.qty.toLocaleString('id-ID') }}</span>
                <span class="text-xs text-gray-400 ml-1">{{ item.uom_base }}</span>
              </td>
              <td class="px-4 py-3 text-right text-xs text-gray-400">
                {{ item.min_stock.toLocaleString('id-ID') }}
              </td>
              <td class="px-4 py-3">
                <span :class="['px-2.5 py-0.5 rounded-full text-xs font-medium', stockBadge(item).cls]">
                  {{ stockBadge(item).label }}
                </span>
              </td>
              <td class="px-4 py-3 text-xs">
                <span
                  v-if="item.stock_summary[0]?.nearest_expiry"
                  :class="[
                    'font-mono',
                    new Date(item.stock_summary[0].nearest_expiry) < new Date(Date.now() + 30*86400000)
                      ? 'text-red-500 font-semibold'
                      : 'text-gray-400'
                  ]"
                >
                  {{ item.stock_summary[0].nearest_expiry }}
                </span>
                <span v-else class="text-gray-300">—</span>
              </td>
              <td class="px-4 py-3 text-right text-sm text-gray-700">
                {{ rp(item.standard_price) }}
              </td>
              <td class="px-4 py-3 text-right">
                <UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs"/>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Footer -->
      <div class="px-4 py-3 border-t border-gray-100 flex items-center justify-between">
        <p class="text-xs text-gray-500">
          <template v-if="!loading">
            Menampilkan {{ filtered.length }} dari {{ totalCount.toLocaleString('id-ID') }} item
          </template>
        </p>
        <!-- Pagination -->
        <div v-if="totalCount > perPage" class="flex items-center gap-2">
          <button
            class="px-3 py-1 text-xs rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40"
            :disabled="page <= 1"
            @click="page--"
          >← Prev</button>
          <span class="text-xs text-gray-500">Hal {{ page }} / {{ Math.ceil(totalCount / perPage) }}</span>
          <button
            class="px-3 py-1 text-xs rounded border border-gray-200 hover:bg-gray-50 disabled:opacity-40"
            :disabled="page >= Math.ceil(totalCount / perPage)"
            @click="page++"
          >Next →</button>
        </div>
      </div>
    </div>

  </div>
</template>
