<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Gudang' })

const supabase = useSupabaseClient()

// ── Helpers ──────────────────────────────────────────────────────
const mvTypeMap: Record<string, { label: string; icon: string; color: string; bg: string }> = {
  receive:    { label: 'Terima (GRN)',  icon: 'i-lucide-arrow-down-circle', color: 'text-emerald-600', bg: 'bg-emerald-50 border-emerald-200' },
  issue:      { label: 'Keluar (DO)',   icon: 'i-lucide-arrow-up-circle',   color: 'text-blue-600',    bg: 'bg-blue-50 border-blue-200' },
  transfer:   { label: 'Transfer',      icon: 'i-lucide-arrow-right-left',  color: 'text-violet-600',  bg: 'bg-violet-50 border-violet-200' },
  adjustment: { label: 'Adjustment',    icon: 'i-lucide-refresh-cw',        color: 'text-amber-600',   bg: 'bg-amber-50 border-amber-200' },
  return_in:  { label: 'Return Masuk',  icon: 'i-lucide-undo-2',            color: 'text-teal-600',    bg: 'bg-teal-50 border-teal-200' },
  return_out: { label: 'Return Keluar', icon: 'i-lucide-redo-2',            color: 'text-orange-600',  bg: 'bg-orange-50 border-orange-200' },
  disposal:   { label: 'Disposal',      icon: 'i-lucide-trash-2',           color: 'text-rose-600',    bg: 'bg-rose-50 border-rose-200' },
}



function fDate(d: string | null, withTime = false) {
  if (!d) return '—'
  const opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' }
  if (withTime) { opts.hour = '2-digit'; opts.minute = '2-digit' }
  return new Date(d).toLocaleDateString('id-ID', opts)
}

function daysLeft(d: string | null) {
  if (!d) return null
  return Math.ceil((new Date(d).getTime() - Date.now()) / 86400000)
}

// ── KPIs ─────────────────────────────────────────────────────────
const kpis = ref({ totalValue: 0, totalItems: 0, nearExpiry: 0, lowStock: 0 })

async function fetchKPIs() {
  const [
    { data: summary },
    { count: nearExp },
    { data: products }
  ] = await Promise.all([
    supabase.from('stock_summary').select('qty_on_hand, avg_cost, nearest_expiry, product_id'),
    supabase.from('stock_summary').select('*', { count: 'exact', head: true })
      .not('nearest_expiry', 'is', null)
      .lt('nearest_expiry', new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10)),
    supabase.from('products').select('id, min_stock').eq('is_active', true),
  ])
  const prodMinMap: Record<string, number> = {}
  for (const p of (products ?? [])) prodMinMap[p.id] = p.min_stock

  let totalValue = 0, totalItems = 0, lowStock = 0
  for (const s of (summary ?? [])) {
    const qty = Number(s.qty_on_hand ?? 0)
    const cost = Number(s.avg_cost ?? 0)
    totalValue += qty * cost
    totalItems += qty
    if (qty < (prodMinMap[s.product_id] ?? 0)) lowStock++
  }
  kpis.value = { totalValue, totalItems: Math.round(totalItems), nearExpiry: nearExp ?? 0, lowStock }
}

// ── Stock by Category ────────────────────────────────────────────
const categorySummary = ref<any[]>([])
const categoryColors: Record<string, string> = {
  obat: '#3b82f6', alkes: '#8b5cf6', bmhp: '#f59e0b', reagensia: '#10b981',
}

async function fetchCategorySummary() {
  const { data } = await supabase.from('stock_summary').select('qty_on_hand, avg_cost, products(category)')
  const catMap: Record<string, { qty: number; value: number }> = {}
  for (const s of (data ?? [])) {
    const cat = (s.products as any)?.category ?? 'lain'
    if (!catMap[cat]) catMap[cat] = { qty: 0, value: 0 }
    catMap[cat].qty   += Number(s.qty_on_hand ?? 0)
    catMap[cat].value += Number(s.qty_on_hand ?? 0) * Number(s.avg_cost ?? 0)
  }
  const total = Object.values(catMap).reduce((s, c) => s + c.value, 0)
  categorySummary.value = Object.entries(catMap).map(([cat, v]) => ({
    cat, qty: Math.round(v.qty), value: v.value,
    pct: total > 0 ? Math.round((v.value / total) * 100) : 0,
    color: categoryColors[cat] ?? '#94a3b8',
    label: { obat: 'Obat', alkes: 'Alkes', bmhp: 'BMHP', reagensia: 'Reagensia' }[cat] ?? 'Lainnya'
  })).sort((a, b) => b.value - a.value)
}

// ── Near Expiry Lots ─────────────────────────────────────────────
const nearExpiryLots = ref<any[]>([])

async function fetchNearExpiry() {
  const { data } = await supabase
    .from('stock_lots')
    .select('id, lot_number, qty_on_hand, expired_at, products(name, category)')
    .gt('qty_on_hand', 0)
    .not('expired_at', 'is', null)
    .lt('expired_at', new Date(Date.now() + 45 * 86400000).toISOString().slice(0, 10))
    .order('expired_at')
    .limit(8)

  nearExpiryLots.value = (data ?? []).map(l => ({
    ...l,
    daysLeft: daysLeft(l.expired_at),
    productName: (l.products as any)?.name ?? '—',
    category: (l.products as any)?.category ?? '—',
  }))
}

// ── Stock Movements ───────────────────────────────────────────────
const mvLoading    = ref(true)
const mvList       = ref<any[]>([])
const mvTotal      = ref(0)
const mvPage       = ref(1)
const mvPerPage    = 15
const mvTypeFilter = ref('')
const mvSearch     = ref('')
let mvDebounce: ReturnType<typeof setTimeout>

const mvTypeOptions = [
  { value: '', label: 'Semua' },
  { value: 'receive',    label: 'Terima' },
  { value: 'issue',      label: 'Keluar' },
  { value: 'adjustment', label: 'Adjst' },
  { value: 'return_in',  label: 'Return' },
]

async function fetchMovements() {
  mvLoading.value = true
  let q = supabase
    .from('stock_movements')
    .select(`
      id, movement_type, qty, qty_before, qty_after,
      ref_type, ref_number, notes, unit_cost, created_at,
      products(name, category, uom_base)
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((mvPage.value - 1) * mvPerPage, mvPage.value * mvPerPage - 1)

  if (mvTypeFilter.value) q = q.eq('movement_type', mvTypeFilter.value)
  if (mvSearch.value.trim()) q = q.ilike('ref_number', `%${mvSearch.value.trim()}%`)

  const { data, count, error } = await q
  if (!error) {
    mvList.value  = (data ?? []).map(m => ({
      ...m,
      productName: (m.products as any)?.name ?? '—',
      category:    (m.products as any)?.category ?? '—',
      uom:         (m.products as any)?.uom_base ?? '',
      value:       Math.abs(Number(m.qty)) * Number(m.unit_cost ?? 0)
    }))
    mvTotal.value = count ?? 0
  }
  mvLoading.value = false
}

watch([mvPage, mvTypeFilter], fetchMovements)
watch(mvSearch, () => {
  clearTimeout(mvDebounce)
  mvDebounce = setTimeout(() => { mvPage.value = 1; fetchMovements() }, 400)
})

onMounted(() => { fetchKPIs(); fetchCategorySummary(); fetchNearExpiry(); fetchMovements() })

const mvTotalPages = computed(() => Math.max(1, Math.ceil(mvTotal.value / mvPerPage)))
</script>

<template>
  <div class="space-y-5">

    <!-- ── KPI Cards ──────────────────────────────────────────── -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="w-9 h-9 rounded-lg border flex items-center justify-center mb-3 bg-blue-50 border-blue-100">
          <UIcon name="i-lucide-package" class="text-blue-600"/>
        </div>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(kpis.totalValue) }}</p>
        <p class="text-xs mt-0.5 text-[#999]">Nilai Stok Total</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="w-9 h-9 rounded-lg border flex items-center justify-center mb-3 bg-emerald-50 border-emerald-100">
          <UIcon name="i-lucide-layers" class="text-emerald-600"/>
        </div>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ kpis.totalItems.toLocaleString('id-ID') }}</p>
        <p class="text-xs mt-0.5 text-[#999]">Total Unit Stok</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-amber-50 border-amber-100">
            <UIcon name="i-lucide-calendar-x" class="text-amber-600"/>
          </div>
          <span v-if="kpis.nearExpiry" class="text-[10px] font-bold px-2 py-0.5 rounded-full border bg-amber-50 text-amber-600 border-amber-200">Perhatian</span>
        </div>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ kpis.nearExpiry }}</p>
        <p class="text-xs mt-0.5 text-[#999]">Lot Kadaluarsa ≤ 30 Hari</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-red-50 border-red-100">
            <UIcon name="i-lucide-triangle-alert" class="text-red-600"/>
          </div>
          <span v-if="kpis.lowStock" class="text-[10px] font-bold px-2 py-0.5 rounded-full border bg-red-50 text-red-600 border-red-200">Alert</span>
        </div>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ kpis.lowStock }}</p>
        <p class="text-xs mt-0.5 text-[#999]">Item Di Bawah Min Stok</p>
      </div>
    </div>

    <!-- ── Komposisi + Near Expiry ─────────────────────────────── -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-5">

      <!-- Komposisi stok per kategori -->
      <div class="rounded-xl p-5 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <h2 class="text-sm font-bold text-[#1a1a1a]">Komposisi Stok</h2>
        <p class="text-xs mb-4 text-[#666]">Berdasarkan nilai gudang</p>
        <div class="space-y-3">
          <div v-for="cat in categorySummary" :key="cat.cat">
            <div class="flex items-center justify-between mb-1">
              <div class="flex items-center gap-2">
                <span class="w-2.5 h-2.5 rounded-full" :style="{ background: cat.color }"/>
                <span class="text-xs font-medium text-[#1a1a1a]">{{ cat.label }}</span>
              </div>
              <div class="flex items-center gap-3 text-xs">
                <span class="text-[#999]">{{ cat.qty.toLocaleString('id-ID') }} unit</span>
                <span class="font-bold w-20 text-right text-[#1a1a1a]">{{ fmtRp(cat.value) }}</span>
                <span class="font-bold w-7 text-right" :style="{ color: cat.color }">{{ cat.pct }}%</span>
              </div>
            </div>
            <div class="h-2 rounded-full overflow-hidden bg-[#e5e5e5]">
              <div class="h-full rounded-full transition-all duration-700" :style="{ width: cat.pct + '%', background: cat.color }"/>
            </div>
          </div>
          <div v-if="!categorySummary.length" class="py-6 text-center text-xs text-[#999]">Memuat...</div>
        </div>
      </div>

      <!-- Near Expiry Lots -->
      <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 flex items-center justify-between" style="border-bottom:1px solid #e5e5e5">
          <div>
            <h2 class="text-sm font-bold text-[#1a1a1a]">Lot Mendekati Kadaluarsa</h2>
            <p class="text-xs mt-0.5 text-[#666]">Dalam 45 hari ke depan</p>
          </div>
          <span v-if="nearExpiryLots.length" class="text-xs font-bold px-2 py-0.5 rounded-full border bg-amber-50 text-amber-600 border-amber-200">{{ nearExpiryLots.length }}</span>
        </div>
        <div v-if="nearExpiryLots.length">
          <div v-for="(lot, idx) in nearExpiryLots" :key="lot.id"
            class="px-5 py-3 flex items-center gap-3 transition-colors hover:bg-[#eee]"
            :style="idx < nearExpiryLots.length - 1 ? 'border-bottom:1px solid #e5e5e5' : ''">
            <div class="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 text-sm font-bold"
              :class="(lot.daysLeft ?? 99) <= 9 ? 'bg-red-50 text-red-600' : (lot.daysLeft ?? 99) <= 20 ? 'bg-amber-50 text-amber-600' : 'bg-emerald-50 text-emerald-600'">
              {{ lot.daysLeft }}
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-xs font-medium truncate text-[#1a1a1a]">{{ lot.productName }}</p>
              <p class="text-[10px] mt-0.5 text-[#999]">Lot {{ lot.lot_number }} · {{ Number(lot.qty_on_hand).toLocaleString('id-ID') }} unit · Exp {{ fDate(lot.expired_at) }}</p>
            </div>
            <span class="text-[10px] font-bold px-2 py-0.5 rounded-full flex-shrink-0 border"
              :class="(lot.daysLeft ?? 99) <= 9
                ? 'bg-red-50 text-rose-600 border-red-200'
                : (lot.daysLeft ?? 99) <= 20
                  ? 'bg-amber-50 text-amber-600 border-amber-200'
                  : 'bg-emerald-50 text-emerald-600 border-emerald-200'">
              {{ lot.daysLeft }}h
            </span>
          </div>
        </div>
        <div v-else class="py-10 text-center">
          <UIcon name="i-lucide-check-circle" class="text-emerald-600 text-2xl mb-2"/>
          <p class="text-xs text-[#666]">Tidak ada lot kadaluarsa dalam 45 hari</p>
        </div>
      </div>
    </div>

    <!-- ── Mutasi Stok ─────────────────────────────────────────── -->
    <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
      <div class="px-5 py-4 flex items-center justify-between gap-4" style="border-bottom:1px solid #e5e5e5">
        <div>
          <h2 class="text-sm font-bold text-[#1a1a1a]">Mutasi Stok</h2>
          <p class="text-xs mt-0.5 text-[#666]">{{ mvTotal }} transaksi tercatat</p>
        </div>
        <div class="flex items-center gap-1.5">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"/>
          <span class="text-[10px] text-emerald-600 font-medium">Live</span>
        </div>
      </div>

      <!-- Filters -->
      <div class="px-5 py-3 flex flex-wrap gap-2 items-center" style="border-bottom:1px solid #e5e5e5">
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg border flex-1 min-w-40" style="background:#f0f0f0; border-color:#e5e5e5">
          <UIcon name="i-lucide-search" class="text-sm flex-shrink-0 text-[#999]"/>
          <input v-model="mvSearch" type="text" placeholder="Cari no. referensi..." class="bg-transparent text-xs outline-none w-full" style="color:#1a1a1a"/>
        </div>
        <div class="flex gap-1">
          <button
            v-for="opt in mvTypeOptions" :key="opt.value"
            class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all"
            :style="mvTypeFilter === opt.value
              ? 'background:#1a1a1a; color:white; border-color:#1a1a1a'
              : 'background:#f0f0f0; color:#666; border-color:#e5e5e5'"
            @click="mvTypeFilter = opt.value; mvPage = 1"
          >{{ opt.label }}</button>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="mvLoading" class="p-4 space-y-2">
        <div v-for="i in 6" :key="i" class="h-11 rounded-lg animate-pulse" style="background:#e5e5e5"/>
      </div>

      <!-- Table -->
      <div v-else-if="mvList.length" class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr style="background:#fafafa; border-bottom:1px solid #e5e5e5">
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Waktu</th>
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Tipe</th>
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Produk</th>
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Ref</th>
              <th class="px-4 py-2.5 text-right font-semibold text-[#666]">Qty</th>
              <th class="px-4 py-2.5 text-right font-semibold text-[#666]">Nilai</th>
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Stok Sebelum → Sesudah</th>
              <th class="px-4 py-2.5 text-left font-semibold text-[#666]">Catatan</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="mv in mvList" :key="mv.id" class="transition-colors hover:bg-[#eee]" style="border-bottom:1px solid #e5e5e5">
              <td class="px-4 py-3 whitespace-nowrap text-[#666]">{{ fDate(mv.created_at, true) }}</td>
              <td class="px-4 py-3">
                <div class="flex items-center gap-1.5">
                  <div class="w-6 h-6 rounded-md border flex items-center justify-center flex-shrink-0" :class="mvTypeMap[mv.movement_type]?.bg ?? 'bg-[#f5f5f5] border-[#e5e5e5]'">
                    <UIcon :name="mvTypeMap[mv.movement_type]?.icon ?? 'i-lucide-activity'" :class="['text-xs', mvTypeMap[mv.movement_type]?.color ?? 'text-[#666]']"/>
                  </div>
                  <span class="font-medium" :class="mvTypeMap[mv.movement_type]?.color ?? 'text-[#1a1a1a]'">
                    {{ mvTypeMap[mv.movement_type]?.label ?? mv.movement_type }}
                  </span>
                </div>
              </td>
              <td class="px-4 py-3 max-w-40">
                <p class="font-medium truncate text-[#1a1a1a]">{{ mv.productName }}</p>
                <p class="text-[10px] capitalize text-[#999]">{{ mv.category }}</p>
              </td>
              <td class="px-4 py-3 font-mono whitespace-nowrap text-[#666]">{{ mv.ref_number ?? '—' }}</td>
              <td class="px-4 py-3 text-right whitespace-nowrap">
                <span class="font-bold" :class="mv.qty > 0 ? 'text-emerald-600' : mv.qty < 0 ? 'text-rose-600' : 'text-amber-600'">
                  {{ mv.qty > 0 ? '+' : '' }}{{ Number(mv.qty).toLocaleString('id-ID') }}
                </span>
                <span class="ml-0.5 text-[#999]">{{ mv.uom }}</span>
              </td>
              <td class="px-4 py-3 text-right font-medium whitespace-nowrap text-[#1a1a1a]">{{ fmtRp(mv.value) }}</td>
              <td class="px-4 py-3 font-mono whitespace-nowrap text-[#999]">
                {{ Number(mv.qty_before).toLocaleString('id-ID') }}
                <span class="mx-1 text-[#ccc]">&rarr;</span>
                <span class="font-bold text-[#1a1a1a]">{{ Number(mv.qty_after).toLocaleString('id-ID') }}</span>
              </td>
              <td class="px-4 py-3 max-w-44 truncate text-[#666]">{{ mv.notes ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-else class="py-12 flex flex-col items-center gap-2">
        <UIcon name="i-lucide-inbox" class="text-3xl text-[#999]"/>
        <p class="text-sm text-[#666]">Tidak ada mutasi ditemukan</p>
      </div>

      <!-- Pagination -->
      <div v-if="mvTotal > mvPerPage" class="px-5 py-3 flex items-center justify-between" style="border-top:1px solid #e5e5e5">
        <p class="text-xs text-[#999]">{{ mvTotal }} mutasi · hal. {{ mvPage }} / {{ mvTotalPages }}</p>
        <div class="flex gap-1">
          <button :disabled="mvPage <= 1" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 transition-colors hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="mvPage--">&larr; Prev</button>
          <button :disabled="mvPage >= mvTotalPages" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 transition-colors hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="mvPage++">Next &rarr;</button>
        </div>
      </div>
    </div>

  </div>
</template>
