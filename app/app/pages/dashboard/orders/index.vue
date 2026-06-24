<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Order & Distribusi' })

const supabase = useSupabaseClient()

const activeTab = ref<'issue'|'return'>('issue')
const loading = ref(true)
const issueList = ref<any[]>([])
const returnList = ref<any[]>([])
const issueTotal = ref(0)
const returnTotal = ref(0)
const page = ref(1)
const perPage = 15
const search = ref('')
let debounce: ReturnType<typeof setTimeout>

const kpis = ref({ today: 0, issueTotal: 0, returnTotal: 0, totalQty: 0 })

function fDate(d: string | null, withTime = false) {
  if (!d) return '—'
  const opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' }
  if (withTime) { opts.hour = '2-digit'; opts.minute = '2-digit' }
  return new Date(d).toLocaleDateString('id-ID', opts)
}

async function fetchKPIs() {
  const todayStart = new Date(); todayStart.setHours(0,0,0,0)
  const [
    { count: todayCount },
    { count: issueCount },
    { count: retCount },
  ] = await Promise.all([
    supabase.from('stock_movements').select('*', { count:'exact', head:true }).eq('movement_type','issue').gte('created_at', todayStart.toISOString()),
    supabase.from('stock_movements').select('*', { count:'exact', head:true }).eq('movement_type','issue'),
    supabase.from('stock_movements').select('*', { count:'exact', head:true }).in('movement_type',['return_in','return_out']),
  ])
  kpis.value = { today: todayCount ?? 0, issueTotal: issueCount ?? 0, returnTotal: retCount ?? 0, totalQty: 0 }
}

async function fetchIssues() {
  loading.value = true
  let q = supabase
    .from('stock_movements')
    .select('id, movement_type, qty, ref_number, notes, created_at, products(name, category, uom_base)', { count: 'exact' })
    .eq('movement_type', 'issue')
    .order('created_at', { ascending: false })
    .range((page.value - 1) * perPage, page.value * perPage - 1)
  if (search.value.trim()) q = q.ilike('ref_number', `%${search.value.trim()}%`)
  const { data, count } = await q
  issueList.value = (data ?? []).map(m => ({
    ...m, prodName: (m.products as any)?.name ?? '—', uom: (m.products as any)?.uom_base ?? '',
    category: (m.products as any)?.category ?? '', unit: extractUnit(m.notes),
  }))
  issueTotal.value = count ?? 0
  loading.value = false
}

async function fetchReturns() {
  loading.value = true
  let q = supabase
    .from('stock_movements')
    .select('id, movement_type, qty, ref_number, notes, created_at, products(name, category, uom_base)', { count: 'exact' })
    .in('movement_type', ['return_in', 'return_out'])
    .order('created_at', { ascending: false })
    .range((page.value - 1) * perPage, page.value * perPage - 1)
  if (search.value.trim()) q = q.ilike('ref_number', `%${search.value.trim()}%`)
  const { data, count } = await q
  returnList.value = (data ?? []).map(m => ({
    ...m, prodName: (m.products as any)?.name ?? '—', uom: (m.products as any)?.uom_base ?? '',
    unit: extractUnit(m.notes),
  }))
  returnTotal.value = count ?? 0
  loading.value = false
}

function extractUnit(notes: string | null): string {
  if (!notes) return '—'
  return notes.split('—')[0]?.trim() ?? notes.slice(0, 30)
}

function fetchTab() {
  if (activeTab.value === 'issue') fetchIssues()
  else fetchReturns()
}

watch([page], fetchTab)
watch(activeTab, () => { page.value = 1; fetchTab() })
watch(search, () => { clearTimeout(debounce); debounce = setTimeout(() => { page.value = 1; fetchTab() }, 400) })
onMounted(() => { fetchKPIs(); fetchTab() })

const currentList = computed(() => activeTab.value === 'issue' ? issueList.value : returnList.value)
const currentTotal = computed(() => activeTab.value === 'issue' ? issueTotal.value : returnTotal.value)
const totalPages = computed(() => Math.max(1, Math.ceil(currentTotal.value / perPage)))
</script>

<template>
  <div class="space-y-5">

    <!-- Header -->
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Order & Distribusi</h1>
        <p class="text-sm mt-0.5 text-[#999]">Distribusi internal, retur & tracking pengiriman</p>
      </div>
      <button class="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-bold text-white bg-[#6b1525] hover:bg-[#4a0e1a] transition-colors">
        <UIcon name="i-lucide-plus" class="text-sm"/>
        Buat Order
      </button>
    </div>

    <!-- KPI Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="card in [
        { label: 'Distribusi Hari Ini', value: kpis.today,       icon: 'i-lucide-clipboard-list', color: 'text-blue-600',    bg: 'bg-blue-50' },
        { label: 'Total Distribusi',    value: kpis.issueTotal,  icon: 'i-lucide-arrow-up-circle', color: 'text-violet-600', bg: 'bg-violet-50' },
        { label: 'Total Retur',         value: kpis.returnTotal, icon: 'i-lucide-undo-2',          color: 'text-amber-600',  bg: 'bg-amber-50' },
        { label: 'Dokumen Total',       value: kpis.issueTotal + kpis.returnTotal, icon: 'i-lucide-check-circle', color: 'text-emerald-600', bg: 'bg-emerald-50' },
      ]" :key="card.label"
        class="rounded-xl border border-[#e5e5e5] bg-[#f5f5f5] p-4 flex items-center gap-3"
      >
        <div :class="[card.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="card.icon" :class="[card.color, 'text-lg']"/>
        </div>
        <div>
          <p class="text-xl font-bold text-[#1a1a1a]">{{ card.value }}</p>
          <p class="text-xs text-[#999]">{{ card.label }}</p>
        </div>
      </div>
    </div>

    <!-- Main Card -->
    <div class="rounded-xl border border-[#e5e5e5] bg-[#f5f5f5] overflow-hidden">

      <!-- Tabs + Search -->
      <div class="flex items-center justify-between gap-4 px-5 pt-4 pb-0 border-b border-[#e5e5e5]">
        <div class="flex gap-1 -mb-px">
          <button
            v-for="tab in [
              { key: 'issue',  label: 'Distribusi Internal', icon: 'i-lucide-arrow-up-circle', count: kpis.issueTotal },
              { key: 'return', label: 'Retur',               icon: 'i-lucide-undo-2',          count: kpis.returnTotal },
            ]" :key="tab.key"
            class="flex items-center gap-2 px-4 py-3 text-xs font-medium transition-colors border-b-2 -mb-px"
            :class="activeTab === tab.key
              ? 'border-[#6b1525] text-[#6b1525]'
              : 'border-transparent text-[#999] hover:text-[#666]'"
            @click="activeTab = tab.key as any"
          >
            <UIcon :name="tab.icon" class="text-sm"/>
            {{ tab.label }}
            <span class="text-[10px] font-bold px-1.5 py-0.5 rounded-full"
              :class="activeTab === tab.key ? 'bg-[#fdf2f4] text-[#6b1525]' : 'bg-[#f0f0f0] text-[#999]'">{{ tab.count }}</span>
          </button>
        </div>
        <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
          <UIcon name="i-lucide-search" class="text-sm text-[#999]"/>
          <input v-model="search" type="text" placeholder="Cari ref number..." class="bg-transparent text-xs outline-none w-36 text-[#1a1a1a] placeholder:text-[#888]"/>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="p-4 space-y-2">
        <div v-for="i in 6" :key="i" class="h-11 rounded-lg bg-[#e5e5e5] animate-pulse"/>
      </div>

      <!-- Table -->
      <div v-else-if="currentList.length" class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="bg-[#fafafa] border-b border-[#e5e5e5]">
              <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Waktu</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Ref</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Produk</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Unit Tujuan</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Qty</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="mv in currentList" :key="mv.id" class="transition-colors cursor-pointer hover:bg-[#eee] border-b border-[#f0f0f0]">
              <td class="px-4 py-3 text-[#999]">{{ fDate(mv.created_at, true) }}</td>
              <td class="px-4 py-3 font-mono font-semibold text-[#6b1525]">{{ mv.ref_number ?? '—' }}</td>
              <td class="px-4 py-3">
                <p class="font-medium text-[#1a1a1a]">{{ mv.prodName }}</p>
                <p class="text-[10px] text-[#888] capitalize">{{ mv.category }}</p>
              </td>
              <td class="px-4 py-3 text-[#666]">{{ mv.unit }}</td>
              <td class="px-4 py-3 text-right font-bold" :class="mv.qty > 0 ? 'text-emerald-600' : 'text-rose-600'">
                {{ mv.qty > 0 ? '+' : '' }}{{ Math.abs(Number(mv.qty)).toLocaleString('id-ID') }}
                <span class="text-[#888] font-normal ml-0.5">{{ mv.uom }}</span>
              </td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded-full text-[10px] font-medium"
                  :class="mv.movement_type === 'issue' ? 'bg-blue-50 text-blue-600 border border-blue-200'
                    : mv.movement_type === 'return_in' ? 'bg-teal-50 text-teal-600 border border-teal-200'
                    : 'bg-orange-50 text-orange-600 border border-orange-200'">
                  {{ mv.movement_type === 'issue' ? 'Distribusi' : mv.movement_type === 'return_in' ? 'Return Masuk' : 'Return Keluar' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Empty -->
      <div v-else class="py-14 flex flex-col items-center gap-3">
        <UIcon name="i-lucide-inbox" class="text-3xl text-[#999]"/>
        <p class="text-sm text-[#999]">Tidak ada data ditemukan</p>
      </div>

      <!-- Footer -->
      <div class="px-5 py-3 flex items-center justify-between border-t border-[#e5e5e5]">
        <p class="text-xs text-[#999]">{{ currentTotal }} dokumen</p>
        <div v-if="currentTotal > perPage" class="flex items-center gap-2">
          <button class="px-3 py-1 text-xs rounded border border-[#e5e5e5] text-[#666] hover:bg-[#eee] disabled:opacity-40 transition-colors" :disabled="page <= 1" @click="page--">← Prev</button>
          <span class="text-xs text-[#999]">{{ page }} / {{ totalPages }}</span>
          <button class="px-3 py-1 text-xs rounded border border-[#e5e5e5] text-[#666] hover:bg-[#eee] disabled:opacity-40 transition-colors" :disabled="page >= totalPages" @click="page++">Next →</button>
        </div>
      </div>
    </div>
  </div>
</template>
