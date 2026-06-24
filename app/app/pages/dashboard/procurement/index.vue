<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Procurement' })

const supabase = useSupabaseClient()

// ── Tabs ────────────────────────────────────────────────────────
const activeTab = ref<'pr'|'po'>('pr')

// ── Status helpers ───────────────────────────────────────────────
const prStatusMap: Record<string, { label: string; color: string; bg: string; dot: string; border?: string }> = {
  draft:    { label: 'Draft',    color: 'text-[#999]',       bg: 'bg-[#f0f0f0]', dot: 'bg-[#ccc]',       border: 'border-[#e5e5e5]' },
  pending:  { label: 'Pending',  color: 'text-amber-600',    bg: 'bg-amber-50',   dot: 'bg-amber-500',    border: 'border-amber-100' },
  approved: { label: 'Disetujui',color: 'text-emerald-600',  bg: 'bg-emerald-50', dot: 'bg-emerald-500',  border: 'border-emerald-100' },
  rejected: { label: 'Ditolak',  color: 'text-rose-600',     bg: 'bg-rose-50',    dot: 'bg-rose-500',     border: 'border-rose-100' },
  cancelled:{ label: 'Dibatal',  color: 'text-[#999]',       bg: 'bg-[#f0f0f0]', dot: 'bg-[#ccc]',       border: 'border-[#e5e5e5]' },
  expired:  { label: 'Expired',  color: 'text-[#999]',       bg: 'bg-[#f0f0f0]', dot: 'bg-[#ccc]',       border: 'border-[#e5e5e5]' },
}
const poStatusMap: Record<string, { label: string; color: string; bg: string; dot: string; border?: string; pct: number }> = {
  draft:              { label: 'Draft',           color: 'text-[#999]',       bg: 'bg-[#f0f0f0]', dot: 'bg-[#ccc]',       border: 'border-[#e5e5e5]',      pct: 0 },
  submitted:          { label: 'Submitted',        color: 'text-sky-600',      bg: 'bg-sky-50',     dot: 'bg-sky-500',      border: 'border-sky-100',         pct: 20 },
  approved:           { label: 'Disetujui',        color: 'text-violet-600',   bg: 'bg-violet-50',  dot: 'bg-violet-500',   border: 'border-violet-100',      pct: 40 },
  sent_to_supplier:   { label: 'Terkirim',         color: 'text-sky-600',      bg: 'bg-sky-50',     dot: 'bg-sky-500',      border: 'border-sky-100',         pct: 60 },
  partially_received: { label: 'Parsial',          color: 'text-amber-600',    bg: 'bg-amber-50',   dot: 'bg-amber-500',    border: 'border-amber-100',       pct: 80 },
  fully_received:     { label: 'Diterima',         color: 'text-emerald-600',  bg: 'bg-emerald-50', dot: 'bg-emerald-500',  border: 'border-emerald-100',     pct: 100 },
  cancelled:          { label: 'Dibatal',          color: 'text-rose-600',     bg: 'bg-rose-50',    dot: 'bg-rose-500',     border: 'border-rose-100',        pct: 0 },
  closed:             { label: 'Closed',           color: 'text-[#999]',       bg: 'bg-[#f0f0f0]', dot: 'bg-[#ccc]',       border: 'border-[#e5e5e5]',      pct: 100 },
}
const priorityMap: Record<string, { label: string; color: string }> = {
  low:      { label: 'Rendah',  color: 'text-[#999]' },
  medium:   { label: 'Sedang',  color: 'text-blue-600' },
  high:     { label: 'Tinggi',  color: 'text-amber-600' },
  critical: { label: 'Kritis',  color: 'text-rose-600' },
}

const rp = fmtRp

// ── PR State ─────────────────────────────────────────────────────
const prLoading  = ref(true)
const prList     = ref<any[]>([])
const prTotal    = ref(0)
const prPage     = ref(1)
const prPerPage  = 10
const prSearch   = ref('')
const prStatus   = ref('')
let prDebounce: ReturnType<typeof setTimeout>

const prStatusOptions = [
  { value: '', label: 'Semua Status' },
  { value: 'draft',    label: 'Draft' },
  { value: 'pending',  label: 'Pending' },
  { value: 'approved', label: 'Disetujui' },
  { value: 'rejected', label: 'Ditolak' },
]

async function fetchPR() {
  prLoading.value = true
  let q = supabase
    .from('purchase_requests')
    .select(`
      id, pr_number, title, status, priority, required_by,
      total_est_value, trigger_type, submitted_at, approved_at, created_at,
      metadata,
      purchase_request_lines(id)
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((prPage.value - 1) * prPerPage, prPage.value * prPerPage - 1)

  if (prStatus.value) q = q.eq('status', prStatus.value)
  if (prSearch.value.trim()) q = q.ilike('title', `%${prSearch.value.trim()}%`)

  const { data, count, error } = await q
  if (!error) {
    prList.value  = (data ?? []).map(pr => ({
      ...pr,
      line_count: pr.purchase_request_lines?.length ?? 0,
      department: pr.metadata?.department ?? '—'
    }))
    prTotal.value = count ?? 0
  }
  prLoading.value = false
}

watch([prPage, prStatus], fetchPR)
watch(prSearch, () => {
  clearTimeout(prDebounce)
  prDebounce = setTimeout(() => { prPage.value = 1; fetchPR() }, 400)
})

// ── PO State ─────────────────────────────────────────────────────
const poLoading  = ref(true)
const poList     = ref<any[]>([])
const poTotal    = ref(0)
const poPage     = ref(1)
const poPerPage  = 10
const poSearch   = ref('')
const poStatus   = ref('')
let poDebounce: ReturnType<typeof setTimeout>

const poStatusOptions = [
  { value: '', label: 'Semua Status' },
  { value: 'draft',              label: 'Draft' },
  { value: 'submitted',          label: 'Submitted' },
  { value: 'approved',           label: 'Disetujui' },
  { value: 'sent_to_supplier',   label: 'Terkirim' },
  { value: 'partially_received', label: 'Parsial' },
  { value: 'fully_received',     label: 'Diterima' },
]

async function fetchPO() {
  poLoading.value = true
  let q = supabase
    .from('purchase_orders')
    .select(`
      id, po_number, status, priority, order_date, expected_delivery,
      total_amount, payment_terms, sent_at,
      suppliers(short_name, performance_score),
      po_lines(id, qty_ordered, qty_received)
    `, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((poPage.value - 1) * poPerPage, poPage.value * poPerPage - 1)

  if (poStatus.value) q = q.eq('status', poStatus.value)
  if (poSearch.value.trim()) q = q.ilike('po_number', `%${poSearch.value.trim()}%`)

  const { data, count, error } = await q
  if (!error) {
    poList.value = (data ?? []).map(po => {
      const lines   = po.po_lines ?? []
      const ordered  = lines.reduce((s: number, l: any) => s + Number(l.qty_ordered ?? 0), 0)
      const received = lines.reduce((s: number, l: any) => s + Number(l.qty_received ?? 0), 0)
      const recvPct  = ordered > 0 ? Math.round((received / ordered) * 100) : 0
      return { ...po, line_count: lines.length, ordered, received, recvPct }
    })
    poTotal.value = count ?? 0
  }
  poLoading.value = false
}

watch([poPage, poStatus], fetchPO)
watch(poSearch, () => {
  clearTimeout(poDebounce)
  poDebounce = setTimeout(() => { poPage.value = 1; fetchPO() }, 400)
})

// ── Summary KPIs ─────────────────────────────────────────────────
const kpis = ref({ prPending: 0, poActive: 0, poValue: 0, suppliers: 0 })

async function fetchKPIs() {
  const [
    { count: pending },
    { data: activePOs },
    { count: supCount }
  ] = await Promise.all([
    supabase.from('purchase_requests').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('purchase_orders').select('total_amount').in('status', ['sent_to_supplier','partially_received','approved']),
    supabase.from('suppliers').select('*', { count: 'exact', head: true }).eq('status', 'active'),
  ])
  kpis.value = {
    prPending:  pending  ?? 0,
    poActive:   activePOs?.length ?? 0,
    poValue:    (activePOs ?? []).reduce((s, p) => s + Number(p.total_amount ?? 0), 0),
    suppliers:  supCount ?? 0,
  }
}

onMounted(() => {
  fetchKPIs()
  fetchPR()
  fetchPO()
})

const prTotalPages = computed(() => Math.max(1, Math.ceil(prTotal.value / prPerPage)))
const poTotalPages = computed(() => Math.max(1, Math.ceil(poTotal.value / poPerPage)))

function formatDate(d: string | null) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
}
function isOverdue(d: string | null) {
  if (!d) return false
  return new Date(d) < new Date()
}
</script>

<template>
  <div class="space-y-5">

    <!-- ── KPI Cards ──────────────────────────────────────────── -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-amber-50 border-amber-100">
            <UIcon name="i-lucide-clock" class="text-amber-600 text-base"/>
          </div>
          <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-50 text-amber-600 border border-amber-100">Perlu Aksi</span>
        </div>
        <p class="text-2xl font-bold" style="color:#1a1a1a">{{ kpis.prPending }}</p>
        <p class="text-xs mt-0.5" style="color:#999">PR Pending Approval</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-sky-50 border-sky-100">
            <UIcon name="i-lucide-truck" class="text-sky-600 text-base"/>
          </div>
          <span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-sky-50 text-sky-600 border border-sky-100">Aktif</span>
        </div>
        <p class="text-2xl font-bold" style="color:#1a1a1a">{{ kpis.poActive }}</p>
        <p class="text-xs mt-0.5" style="color:#999">PO Dalam Proses</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-violet-50 border-violet-100">
            <UIcon name="i-lucide-banknote" class="text-violet-600 text-base"/>
          </div>
        </div>
        <p class="text-2xl font-bold" style="color:#1a1a1a">{{ fmtRp(kpis.poValue) }}</p>
        <p class="text-xs mt-0.5" style="color:#999">Nilai PO Aktif</p>
      </div>

      <div class="rounded-xl p-4 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-center justify-between mb-3">
          <div class="w-9 h-9 rounded-lg border flex items-center justify-center bg-emerald-50 border-emerald-100">
            <UIcon name="i-lucide-building-2" class="text-emerald-600 text-base"/>
          </div>
          <NuxtLink to="/dashboard/procurement/suppliers" class="text-[10px] text-[#6b1525] hover:underline">Lihat →</NuxtLink>
        </div>
        <p class="text-2xl font-bold" style="color:#1a1a1a">{{ kpis.suppliers }}</p>
        <p class="text-xs mt-0.5" style="color:#999">Supplier Aktif</p>
      </div>
    </div>

    <!-- ── Main Card ───────────────────────────────────────────── -->
    <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">

      <!-- Header + Tabs + Actions -->
      <div class="border-b" style="border-color:#e5e5e5">
        <div class="px-5 pt-4 flex items-center justify-between gap-4">
          <div class="flex gap-1">
            <button
              class="px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 transition-all"
              :class="activeTab === 'pr' ? 'border-[#6b1525] text-[#6b1525] bg-[#fdf2f4]' : 'border-transparent text-[#999] hover:text-[#666]'"
              @click="activeTab = 'pr'"
            >
              <span class="flex items-center gap-1.5">
                <UIcon name="i-lucide-file-plus" class="text-sm"/>
                Purchase Request
                <span v-if="kpis.prPending" class="bg-amber-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{{ kpis.prPending }}</span>
              </span>
            </button>
            <button
              class="px-4 py-2 text-sm font-medium rounded-t-lg border-b-2 transition-all"
              :class="activeTab === 'po' ? 'border-[#6b1525] text-[#6b1525] bg-[#fdf2f4]' : 'border-transparent text-[#999] hover:text-[#666]'"
              @click="activeTab = 'po'"
            >
              <span class="flex items-center gap-1.5">
                <UIcon name="i-lucide-shopping-cart" class="text-sm"/>
                Purchase Order
                <span v-if="kpis.poActive" class="bg-sky-500 text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full">{{ kpis.poActive }}</span>
              </span>
            </button>
          </div>
          <NuxtLink to="/dashboard/procurement/pr/new">
            <button class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-white" style="background:#6b1525">
              <UIcon name="i-lucide-plus" class="text-sm"/>
              Buat PR Baru
            </button>
          </NuxtLink>
        </div>
      </div>

      <!-- ── PR Tab ─────────────────────────────────────────── -->
      <div v-if="activeTab === 'pr'" class="p-4 space-y-3">
        <!-- Filters -->
        <div class="flex flex-wrap gap-2">
          <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg border flex-1 min-w-48" style="background:#f0f0f0; border-color:#e5e5e5">
            <UIcon name="i-lucide-search" class="text-sm flex-shrink-0" style="color:#999"/>
            <input v-model="prSearch" type="text" placeholder="Cari judul PR..." class="bg-transparent text-xs outline-none w-full" style="color:#1a1a1a" placeholder-class="text-[#999]"/>
          </div>
          <select v-model="prStatus" class="px-3 py-1.5 rounded-lg border text-xs outline-none" style="background:#f0f0f0; border-color:#e5e5e5; color:#1a1a1a" @change="prPage = 1">
            <option v-for="o in prStatusOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>

        <!-- Loading skeleton -->
        <div v-if="prLoading" class="space-y-2">
          <div v-for="i in 5" :key="i" class="h-14 rounded-lg animate-pulse" style="background:#e5e5e5"/>
        </div>

        <!-- Table -->
        <div v-else-if="prList.length" class="overflow-x-auto rounded-lg border" style="border-color:#e5e5e5">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b" style="background:#fafafa; border-color:#e5e5e5">
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">No. PR</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Judul</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Dept.</th>
                <th class="px-4 py-2.5 text-center font-semibold" style="color:#666">Item</th>
                <th class="px-4 py-2.5 text-right font-semibold" style="color:#666">Est. Nilai</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Prioritas</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Dibutuhkan</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Status</th>
                <th class="px-4 py-2.5"/>
              </tr>
            </thead>
            <tbody class="divide-y" style="--tw-divide-opacity:1; --tw-divide-color:#e5e5e5">
              <tr v-for="pr in prList" :key="pr.id" class="transition-colors group hover:bg-[#eee]">
                <td class="px-4 py-3 font-mono font-bold" style="color:#1a1a1a">{{ pr.pr_number }}</td>
                <td class="px-4 py-3 max-w-48">
                  <p class="font-medium truncate" style="color:#1a1a1a">{{ pr.title }}</p>
                  <p class="text-[10px] mt-0.5" style="color:#999">{{ formatDate(pr.created_at) }}</p>
                </td>
                <td class="px-4 py-3" style="color:#666">{{ pr.department }}</td>
                <td class="px-4 py-3 text-center">
                  <span class="font-bold" style="color:#1a1a1a">{{ pr.line_count }}</span>
                  <span style="color:#999"> item</span>
                </td>
                <td class="px-4 py-3 text-right font-bold" style="color:#1a1a1a">{{ fmtRp(pr.total_est_value) }}</td>
                <td class="px-4 py-3">
                  <span class="font-semibold" :class="priorityMap[pr.priority]?.color ?? 'text-[#999]'">
                    {{ priorityMap[pr.priority]?.label ?? pr.priority }}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <span :class="isOverdue(pr.required_by) && pr.status !== 'approved' ? 'text-rose-600 font-semibold' : ''" :style="!(isOverdue(pr.required_by) && pr.status !== 'approved') ? 'color:#666' : ''">
                    {{ formatDate(pr.required_by) }}
                  </span>
                </td>
                <td class="px-4 py-3">
                  <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold border"
                    :class="[prStatusMap[pr.status]?.color, prStatusMap[pr.status]?.bg, prStatusMap[pr.status]?.border]">
                    <span class="w-1.5 h-1.5 rounded-full" :class="prStatusMap[pr.status]?.dot"/>
                    {{ prStatusMap[pr.status]?.label ?? pr.status }}
                  </span>
                </td>
                <td class="px-4 py-3 text-right">
                  <button class="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-[#e5e5e5]">
                    <UIcon name="i-lucide-chevron-right" style="color:#999"/>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Empty -->
        <div v-else class="py-12 flex flex-col items-center gap-3">
          <div class="w-12 h-12 rounded-xl flex items-center justify-center" style="background:#e5e5e5">
            <UIcon name="i-lucide-file-x" class="text-xl" style="color:#999"/>
          </div>
          <p class="text-sm" style="color:#666">Tidak ada PR ditemukan</p>
        </div>

        <!-- Pagination -->
        <div v-if="prTotal > prPerPage" class="flex items-center justify-between pt-2">
          <p class="text-xs" style="color:#999">{{ prTotal }} total · halaman {{ prPage }} dari {{ prTotalPages }}</p>
          <div class="flex gap-1">
            <button :disabled="prPage <= 1" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="prPage--">← Prev</button>
            <button :disabled="prPage >= prTotalPages" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="prPage++">Next →</button>
          </div>
        </div>
      </div>

      <!-- ── PO Tab ─────────────────────────────────────────── -->
      <div v-if="activeTab === 'po'" class="p-4 space-y-3">
        <!-- Filters -->
        <div class="flex flex-wrap gap-2">
          <div class="flex items-center gap-2 px-3 py-1.5 rounded-lg border flex-1 min-w-48" style="background:#f0f0f0; border-color:#e5e5e5">
            <UIcon name="i-lucide-search" class="text-sm flex-shrink-0" style="color:#999"/>
            <input v-model="poSearch" type="text" placeholder="Cari nomor PO..." class="bg-transparent text-xs outline-none w-full" style="color:#1a1a1a" placeholder-class="text-[#999]"/>
          </div>
          <select v-model="poStatus" class="px-3 py-1.5 rounded-lg border text-xs outline-none" style="background:#f0f0f0; border-color:#e5e5e5; color:#1a1a1a" @change="poPage = 1">
            <option v-for="o in poStatusOptions" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
        </div>

        <!-- Loading -->
        <div v-if="poLoading" class="space-y-2">
          <div v-for="i in 5" :key="i" class="h-16 rounded-lg animate-pulse" style="background:#e5e5e5"/>
        </div>

        <!-- Table -->
        <div v-else-if="poList.length" class="overflow-x-auto rounded-lg border" style="border-color:#e5e5e5">
          <table class="w-full text-xs">
            <thead>
              <tr class="border-b" style="background:#fafafa; border-color:#e5e5e5">
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">No. PO</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Supplier</th>
                <th class="px-4 py-2.5 text-center font-semibold" style="color:#666">Item</th>
                <th class="px-4 py-2.5 text-right font-semibold" style="color:#666">Total</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">ETA</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Penerimaan</th>
                <th class="px-4 py-2.5 text-left font-semibold" style="color:#666">Status</th>
                <th class="px-4 py-2.5"/>
              </tr>
            </thead>
            <tbody class="divide-y" style="--tw-divide-opacity:1; --tw-divide-color:#e5e5e5">
              <tr v-for="po in poList" :key="po.id" class="transition-colors group hover:bg-[#eee]">
                <td class="px-4 py-3">
                  <p class="font-mono font-bold" style="color:#1a1a1a">{{ po.po_number }}</p>
                  <p class="text-[10px] mt-0.5" style="color:#999">{{ formatDate(po.order_date) }}</p>
                </td>
                <td class="px-4 py-3">
                  <p class="font-medium" style="color:#1a1a1a">{{ po.suppliers?.short_name ?? '—' }}</p>
                  <div v-if="po.suppliers?.performance_score" class="flex items-center gap-0.5 mt-0.5">
                    <UIcon name="i-lucide-star" class="text-amber-500" style="font-size:10px"/>
                    <span class="text-[10px]" style="color:#999">{{ po.suppliers.performance_score }}</span>
                  </div>
                </td>
                <td class="px-4 py-3 text-center">
                  <span class="font-bold" style="color:#1a1a1a">{{ po.line_count }}</span>
                  <span style="color:#999"> item</span>
                </td>
                <td class="px-4 py-3 text-right font-bold" style="color:#1a1a1a">{{ fmtRp(po.total_amount) }}</td>
                <td class="px-4 py-3">
                  <span :class="isOverdue(po.expected_delivery) && !['fully_received','closed'].includes(po.status) ? 'text-rose-600 font-semibold' : ''" :style="!(isOverdue(po.expected_delivery) && !['fully_received','closed'].includes(po.status)) ? 'color:#666' : ''">
                    {{ formatDate(po.expected_delivery) }}
                  </span>
                </td>
                <td class="px-4 py-3 min-w-28">
                  <div class="flex items-center gap-2">
                    <div class="flex-1 h-1.5 rounded-full overflow-hidden" style="background:#e5e5e5">
                      <div
                        class="h-full rounded-full transition-all duration-700"
                        :class="po.recvPct === 100 ? 'bg-emerald-500' : po.recvPct > 0 ? 'bg-amber-500' : ''"
                        :style="[{ width: po.recvPct + '%' }, po.recvPct === 0 && po.recvPct !== 100 ? { background: '#ccc' } : {}]"
                      />
                    </div>
                    <span class="text-[10px] font-bold w-7 text-right" style="color:#666">{{ po.recvPct }}%</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold border"
                    :class="[poStatusMap[po.status]?.color, poStatusMap[po.status]?.bg, poStatusMap[po.status]?.border]">
                    <span class="w-1.5 h-1.5 rounded-full" :class="poStatusMap[po.status]?.dot"/>
                    {{ poStatusMap[po.status]?.label ?? po.status }}
                  </span>
                </td>
                <td class="px-4 py-3 text-right">
                  <button class="opacity-0 group-hover:opacity-100 transition-opacity p-1 rounded hover:bg-[#e5e5e5]">
                    <UIcon name="i-lucide-chevron-right" style="color:#999"/>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Empty -->
        <div v-else class="py-12 flex flex-col items-center gap-3">
          <div class="w-12 h-12 rounded-xl flex items-center justify-center" style="background:#e5e5e5">
            <UIcon name="i-lucide-shopping-cart" class="text-xl" style="color:#999"/>
          </div>
          <p class="text-sm" style="color:#666">Tidak ada PO ditemukan</p>
        </div>

        <!-- Pagination -->
        <div v-if="poTotal > poPerPage" class="flex items-center justify-between pt-2">
          <p class="text-xs" style="color:#999">{{ poTotal }} total · halaman {{ poPage }} dari {{ poTotalPages }}</p>
          <div class="flex gap-1">
            <button :disabled="poPage <= 1" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="poPage--">← Prev</button>
            <button :disabled="poPage >= poTotalPages" class="px-3 py-1 rounded-lg text-xs border disabled:opacity-40 hover:bg-[#eee]" style="border-color:#e5e5e5; color:#666; background:#f5f5f5" @click="poPage++">Next →</button>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>
