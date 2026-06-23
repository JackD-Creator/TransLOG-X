<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

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
  qty: number
  status: 'normal' | 'low' | 'empty'
}

const loading   = ref(true)
const error     = ref<string | null>(null)
const products  = ref<Product[]>([])
const totalCount = ref(0)

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

const filtered = computed(() => {
  if (stockFilter.value === 'all') return products.value
  return products.value.filter(p => p.status === stockFilter.value)
})

const summary = computed(() => ({
  total:  products.value.length,
  normal: products.value.filter(p => p.status === 'normal').length,
  low:    products.value.filter(p => p.status === 'low').length,
  empty:  products.value.filter(p => p.status === 'empty').length,
}))

function stockBadge(p: Product) {
  if (p.status === 'empty') return { label: 'Habis',        cls: 'bg-rose-500/10 text-rose-400 border border-rose-500/20' }
  if (p.status === 'low')   return { label: 'Hampir Habis', cls: 'bg-amber-500/10 text-amber-400 border border-amber-500/20' }
  return                           { label: 'Normal',        cls: 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' }
}

function rp(n: number | null) {
  if (!n) return '—'
  return 'Rp ' + n.toLocaleString('id-ID')
}

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
        <h1 class="text-xl font-bold" style="color:#1a1a1a">Inventory</h1>
        <p class="text-sm mt-0.5" style="color:#666">
          Kelola stok obat, alkes, BMHP &amp; reagensia
          <span v-if="!loading" style="color:#999">· {{ totalCount.toLocaleString('id-ID') }} SKU aktif</span>
        </p>
      </div>
      <div class="flex gap-2">
        <button class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-medium transition-colors" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="fetchProducts">
          <UIcon name="i-lucide-refresh-cw" class="text-sm" :class="loading ? 'animate-spin' : ''"/>
          Refresh
        </button>
        <button class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-medium" style="border-color:#e5e5e5; color:#666; background:#f5f5f5">
          <UIcon name="i-lucide-download" class="text-sm"/>
          Export
        </button>
        <NuxtLink to="/dashboard/inventory/add">
          <button class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-white" style="background:#6b1525">
            <UIcon name="i-lucide-plus" class="text-sm"/>
            Tambah SKU
          </button>
        </NuxtLink>
      </div>
    </div>

    <!-- Error state -->
    <div v-if="error" class="rounded-xl p-4 flex items-start gap-3 border" style="background:#f5f5f5; border-color:#6b1525">
      <UIcon name="i-lucide-alert-circle" class="text-rose-400 text-lg flex-shrink-0 mt-0.5"/>
      <div>
        <p class="text-sm font-semibold text-rose-400">Gagal memuat data</p>
        <p class="text-xs mt-0.5" style="color:#666">{{ error }}</p>
        <p class="text-xs mt-1" style="color:#999">
          Pastikan sudah menjalankan <code class="font-mono px-1 rounded" style="background:#e5e5e5">node supabase/seed_inventory.mjs</code>
          dan login ulang.
        </p>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div
        v-for="card in [
          { label: 'Total SKU',     value: summary.total,  icon: 'i-lucide-package',        color: '#38bdf8', bg: 'rgba(56,189,248,0.1)' },
          { label: 'Stok Normal',   value: summary.normal, icon: 'i-lucide-check-circle',   color: '#34d399', bg: 'rgba(52,211,153,0.1)' },
          { label: 'Hampir Habis',  value: summary.low,    icon: 'i-lucide-triangle-alert', color: '#fbbf24', bg: 'rgba(251,191,36,0.1)' },
          { label: 'Stok Habis',    value: summary.empty,  icon: 'i-lucide-x-circle',       color: '#f43f5e', bg: 'rgba(244,63,94,0.1)' },
        ]" :key="card.label"
        class="rounded-xl border p-4 flex items-center gap-3" style="background:#f5f5f5; border-color:#e5e5e5"
      >
        <div class="w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0" :style="{ background: card.bg }">
          <UIcon :name="card.icon" class="text-lg" :style="{ color: card.color }"/>
        </div>
        <div>
          <p class="text-xl font-bold" style="color:#1a1a1a">
            <span v-if="loading" class="inline-block w-8 h-5 rounded animate-pulse" style="background:#e5e5e5"/>
            <span v-else>{{ card.value }}</span>
          </p>
          <p class="text-xs" style="color:#999">{{ card.label }}</p>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="rounded-xl border p-4 flex flex-wrap gap-3 items-center" style="background:#f5f5f5; border-color:#e5e5e5">
      <div class="flex-1 min-w-48 relative">
        <UIcon name="i-lucide-search" class="absolute left-3 top-1/2 -translate-y-1/2 text-sm" style="color:#999"/>
        <input
          v-model="search"
          type="text"
          placeholder="Cari nama atau kode SKU..."
          class="w-full rounded-lg pl-9 pr-3 py-2 text-sm border outline-none transition-all focus:ring-2"
          style="background:#f0f0f0; border-color:#e5e5e5; color:#1a1a1a; --tw-ring-color: rgba(107,21,37,0.4)"
        >
      </div>
      <div class="flex gap-1.5 flex-wrap">
        <button
          v-for="cat in categories" :key="cat.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :style="category === cat.value
            ? 'background:#6b1525; color:white'
            : 'background:#eee; color:#666; border:1px solid #e5e5e5'"
          @click="category = cat.value; page = 1"
        >{{ cat.label }}</button>
      </div>
      <div class="flex gap-1.5 flex-wrap">
        <button
          v-for="sf in stockFilters" :key="sf.value"
          class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
          :style="stockFilter === sf.value
            ? 'background:#1a1a1a; color:white'
            : 'background:#eee; color:#666; border:1px solid #e5e5e5'"
          @click="stockFilter = sf.value"
        >{{ sf.label }}</button>
      </div>
    </div>

    <!-- Table -->
    <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr style="border-bottom:1px solid #e5e5e5; background:#fafafa">
              <th class="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Kode</th>
              <th class="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Nama Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Kategori</th>
              <th class="text-right px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Stok</th>
              <th class="text-right px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Min</th>
              <th class="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Status</th>
              <th class="text-left px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Kadaluarsa</th>
              <th class="text-right px-4 py-3 text-xs font-semibold uppercase tracking-wide" style="color:#999">Harga</th>
              <th class="px-4 py-3"/>
            </tr>
          </thead>
          <tbody>
            <template v-if="loading">
              <tr v-for="i in 8" :key="i" class="animate-pulse" :style="i < 8 ? 'border-bottom:1px solid #f5f5f5' : ''">
                <td class="px-4 py-3"><div class="h-3 w-16 rounded" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3"><div class="h-3 w-40 rounded" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3"><div class="h-3 w-14 rounded" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-12 rounded ml-auto" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-10 rounded ml-auto" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3"><div class="h-4 w-20 rounded-full" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3"><div class="h-3 w-20 rounded" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3 text-right"><div class="h-3 w-20 rounded ml-auto" style="background:#e5e5e5"/></td>
                <td class="px-4 py-3"/>
              </tr>
            </template>

            <tr v-else-if="filtered.length === 0">
              <td colspan="9" class="text-center py-14" style="color:#999">
                <UIcon name="i-lucide-package-open" class="text-4xl mb-3 block mx-auto" style="color:#e5e5e5"/>
                <p class="text-sm font-medium">Tidak ada item ditemukan</p>
                <p class="text-xs mt-1">Coba ubah filter atau jalankan seed inventory</p>
              </td>
            </tr>

            <tr
              v-else
              v-for="item in filtered" :key="item.id"
              class="transition-colors cursor-pointer group hover:bg-[#eee]"
              style="border-bottom:1px solid #f5f5f5"
              @click="$router.push(`/dashboard/inventory/${item.id}`)"
            >
              <td class="px-4 py-3">
                <div class="flex items-center gap-1.5">
                  <span class="font-mono text-xs" style="color:#666">{{ item.internal_code ?? '—' }}</span>
                  <span v-if="item.is_narkotika"    class="text-[9px] font-bold bg-rose-100 text-rose-600 border border-rose-200 px-1 rounded">NAR</span>
                  <span v-if="item.is_psikotropika" class="text-[9px] font-bold bg-violet-100 text-violet-600 border border-violet-200 px-1 rounded">PSI</span>
                  <span v-if="item.is_fornas"       class="text-[9px] font-bold bg-sky-100 text-sky-600 border border-sky-200 px-1 rounded">FNS</span>
                </div>
              </td>
              <td class="px-4 py-3 font-medium transition-colors" :style="'color:#1a1a1a'" @mouseenter="($event.target as HTMLElement).style.color='#6b1525'" @mouseleave="($event.target as HTMLElement).style.color='#1a1a1a'">
                {{ item.name }}
              </td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded text-xs border capitalize" style="background:#eee; border-color:#e5e5e5; color:#666">
                  {{ item.category }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
                <span class="font-semibold" style="color:#1a1a1a">{{ item.qty.toLocaleString('id-ID') }}</span>
                <span class="text-xs ml-1" style="color:#999">{{ item.uom_base }}</span>
              </td>
              <td class="px-4 py-3 text-right text-xs" style="color:#999">
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
                  class="font-mono"
                  :style="new Date(item.stock_summary[0].nearest_expiry) < new Date(Date.now() + 30*86400000)
                    ? 'color:#f43f5e; font-weight:600'
                    : 'color:#999'"
                >
                  {{ item.stock_summary[0].nearest_expiry }}
                </span>
                <span v-else style="color:#e5e5e5">—</span>
              </td>
              <td class="px-4 py-3 text-right text-sm" style="color:#333">
                {{ rp(item.standard_price) }}
              </td>
              <td class="px-4 py-3 text-right">
                <UIcon name="i-lucide-chevron-right" class="text-sm" style="color:#e5e5e5"/>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="px-4 py-3 flex items-center justify-between" style="border-top:1px solid #e5e5e5">
        <p class="text-xs" style="color:#999">
          <template v-if="!loading">
            Menampilkan {{ filtered.length }} dari {{ totalCount.toLocaleString('id-ID') }} item
          </template>
        </p>
        <div v-if="totalCount > perPage" class="flex items-center gap-2">
          <button
            class="px-3 py-1 text-xs rounded border transition-colors disabled:opacity-40"
            style="border-color:#e5e5e5; color:#666; background:#f5f5f5"
            :disabled="page <= 1"
            @click="page--"
          >← Prev</button>
          <span class="text-xs" style="color:#999">Hal {{ page }} / {{ Math.ceil(totalCount / perPage) }}</span>
          <button
            class="px-3 py-1 text-xs rounded border transition-colors disabled:opacity-40"
            style="border-color:#e5e5e5; color:#666; background:#f5f5f5"
            :disabled="page >= Math.ceil(totalCount / perPage)"
            @click="page++"
          >Next →</button>
        </div>
      </div>
    </div>

  </div>
</template>
