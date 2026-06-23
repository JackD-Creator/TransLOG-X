<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const kpis = ref([
  { label: 'Inventory Turnover',   value: '-',       trend: '',      up: true,  icon: 'i-lucide-refresh-cw',    color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Fill Rate',            value: '-',       trend: '',      up: true,  icon: 'i-lucide-package-check', color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'Total SKU',            value: '-',       trend: '',      up: true,  icon: 'i-lucide-clock',         color: 'text-purple-600', bg: 'bg-purple-50' },
  { label: 'Nilai Stok',           value: '-',       trend: '',      up: false, icon: 'i-lucide-trending-down', color: 'text-amber-600',  bg: 'bg-amber-50' },
])
const topItems = ref<any[]>([])
const spendByKategori = ref<any[]>([])

async function fetchData() {
  const [summaryRes, mvRes, productsRes] = await Promise.all([
    supabase.from('stock_summary').select('qty_on_hand, avg_cost, product_id, products(name, category)'),
    supabase.from('stock_movements').select('product_id, qty, movement_type, products(name, category)')
      .eq('movement_type', 'issue').order('created_at', { ascending: false }).limit(500),
    supabase.from('products').select('*', { count: 'exact', head: true }),
  ])

  const summaries = summaryRes.data ?? []
  const movements = mvRes.data ?? []

  // Total stock value
  let totalVal = 0
  const catVal: Record<string, number> = {}
  for (const s of summaries) {
    const val = Number(s.qty_on_hand) * Number(s.avg_cost)
    totalVal += val
    const cat = (s.products as any)?.category ?? 'lain'
    catVal[cat] = (catVal[cat] ?? 0) + val
  }

  // Top items by issue qty
  const itemQty: Record<string, { nama: string; kategori: string; qty: number; val: number }> = {}
  for (const m of movements) {
    const pid = m.product_id
    if (!itemQty[pid]) itemQty[pid] = { nama: (m.products as any)?.name ?? '-', kategori: (m.products as any)?.category ?? '-', qty: 0, val: 0 }
    const q = Math.abs(Number(m.qty))
    itemQty[pid].qty += q
  }
  const sorted = Object.values(itemQty).sort((a, b) => b.qty - a.qty).slice(0, 5)
  const maxQty = sorted[0]?.qty ?? 1
  topItems.value = sorted.map(i => ({
    nama: i.nama, kategori: i.kategori, qty_keluar: i.qty, nilai: 0, pct: Math.round((i.qty / maxQty) * 100)
  }))

  // Spend by category
  const totalCat = Object.values(catVal).reduce((s, v) => s + v, 0)
  const catColors: Record<string, string> = { obat: 'bg-blue-500', alkes: 'bg-purple-500', bmhp: 'bg-amber-500', reagensia: 'bg-emerald-500' }
  spendByKategori.value = Object.entries(catVal)
    .sort(([,a],[,b]) => b - a)
    .map(([cat, val]) => ({
      kategori: cat.charAt(0).toUpperCase() + cat.slice(1),
      pct: totalCat > 0 ? Math.round((val / totalCat) * 100) : 0,
      nilai: val >= 1e9 ? `Rp ${(val/1e9).toFixed(1)}M` : `Rp ${Math.round(val/1e6)}Jt`,
      color: catColors[cat] ?? 'bg-gray-500'
    }))

  // KPIs
  const issueCount = movements.length
  const avgStock = summaries.reduce((s, r) => s + Number(r.qty_on_hand), 0)
  const turnover = avgStock > 0 ? (issueCount / (avgStock / summaries.length || 1)).toFixed(1) : '0'

  kpis.value[0].value = `${turnover}x`
  kpis.value[1].value = summaries.length > 0 ? `${Math.round((summaries.filter(s => Number(s.qty_on_hand) > 0).length / summaries.length) * 100)}%` : '-'
  kpis.value[2].value = String(productsRes.count ?? 0)
  kpis.value[3].value = totalVal >= 1e9 ? `Rp ${(totalVal/1e9).toFixed(2).replace('.',',')}M` : `Rp ${Math.round(totalVal/1e6)}Jt`
}

onMounted(fetchData)
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Analytics & Business Intelligence</h1>
        <p class="text-sm text-[#999] mt-0.5">KPI logistik, spend analysis & laporan manajemen</p>
      </div>
      <div class="flex gap-2">
        <UButton icon="i-lucide-download" color="neutral" variant="outline" size="sm">Export PDF</UButton>
        <UButton icon="i-lucide-calendar" color="neutral" variant="outline" size="sm">Juni 2026</UButton>
      </div>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="k in kpis" :key="k.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <div class="flex items-center justify-between mb-3">
          <div :class="[k.bg,'w-9 h-9 rounded-lg flex items-center justify-center']"><UIcon :name="k.icon" :class="[k.color,'text-base']" /></div>
          <span :class="['text-xs font-semibold', k.up?'text-emerald-600':'text-red-600']">{{ k.trend }}</span>
        </div>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ k.value }}</p>
        <p class="text-xs text-[#999] mt-0.5">{{ k.label }}</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <!-- Top items -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Top 5 Item by Volume (Bulan Ini)</h2></div>
        <div class="divide-y divide-[#e5e5e5]">
          <div v-for="(item, i) in topItems" :key="item.nama" class="px-5 py-3">
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2">
                <span class="text-xs font-bold text-[#999] w-4">{{ i+1 }}</span>
                <div>
                  <p class="text-sm font-medium text-[#1a1a1a]">{{ item.nama }}</p>
                  <p class="text-xs text-[#999]">{{ item.kategori }} · {{ item.qty_keluar.toLocaleString('id-ID') }} unit</p>
                </div>
              </div>
              <p class="text-xs font-semibold text-[#666]">{{ rp(item.nilai) }}</p>
            </div>
            <div class="w-full h-1.5 bg-[#f0f0f0] rounded-full overflow-hidden">
              <div class="h-full bg-red-500 rounded-full" :style="`width:${item.pct}%`" />
            </div>
          </div>
        </div>
      </div>

      <!-- Spend by kategori -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Spend by Kategori (Bulan Ini)</h2></div>
        <div class="p-5 space-y-4">
          <div v-for="s in spendByKategori" :key="s.kategori">
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2">
                <div :class="['w-2.5 h-2.5 rounded-full', s.color]" />
                <span class="text-sm text-[#666]">{{ s.kategori }}</span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-xs text-[#999]">{{ s.nilai }}</span>
                <span class="text-xs font-bold text-[#666] w-8 text-right">{{ s.pct }}%</span>
              </div>
            </div>
            <div class="w-full h-2 bg-[#f0f0f0] rounded-full overflow-hidden">
              <div :class="['h-full rounded-full', s.color]" :style="`width:${s.pct}%`" />
            </div>
          </div>

          <div class="pt-4 border-t border-[#e5e5e5]">
            <div class="grid grid-cols-2 gap-3">
              <div class="bg-[#f0f0f0] rounded-xl p-3 text-center">
                <p class="text-lg font-bold text-[#1a1a1a]">Rp 5,0M</p>
                <p class="text-xs text-[#999]">Total Spend</p>
              </div>
              <div class="bg-[#f0f0f0] rounded-xl p-3 text-center">
                <p class="text-lg font-bold text-emerald-600">-2.3%</p>
                <p class="text-xs text-[#999]">vs Bulan Lalu</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
