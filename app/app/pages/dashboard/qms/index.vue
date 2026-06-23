<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const stats = ref([
  { label: 'Deviasi Bulan Ini',    value: '-',   icon: 'i-lucide-alert-triangle',  color: 'text-red-600',    bg: 'bg-red-50' },
  { label: 'CAPA Aktif',           value: '-',   icon: 'i-lucide-clipboard-check', color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Item Expiring 30hr',   value: '-',   icon: 'i-lucide-calendar-x',      color: 'text-amber-600',  bg: 'bg-amber-50' },
  { label: 'Keluhan Terbuka',      value: '-',   icon: 'i-lucide-message-circle',  color: 'text-emerald-600',bg: 'bg-emerald-50' },
]
)
const insiden = ref<any[]>([])
const expiring = ref<any[]>([])

async function fetchData() {
  const monthStart = new Date(); monthStart.setDate(1); monthStart.setHours(0,0,0,0)
  const exp30 = new Date(Date.now() + 30*864e5).toISOString().slice(0,10)

  const [devRes, capaRes, expiryRes, complaintRes] = await Promise.all([
    supabase.from('deviations').select('deviation_number, title, category, severity, status, detected_at')
      .order('detected_at', { ascending: false }).limit(20),
    supabase.from('capa_records').select('*', { count: 'exact', head: true })
      .in('status', ['planned','in_progress']),
    supabase.from('stock_lots').select('lot_number, qty_on_hand, expired_at, products(name)')
      .gt('qty_on_hand', 0).not('expired_at','is',null).lt('expired_at', exp30).order('expired_at').limit(10),
    supabase.from('complaints').select('*', { count: 'exact', head: true })
      .in('status', ['open','investigating']),
  ])

  const devs = devRes.data ?? []
  const sevMap: Record<string,string> = { low: 'minor', medium: 'moderate', high: 'major', critical: 'major' }
  const stMap: Record<string,string> = { open: 'investigating', under_review: 'investigating', capa_assigned: 'investigating', closed: 'closed' }

  insiden.value = devs.map(d => ({
    id: d.deviation_number, tanggal: d.detected_at?.slice(0,10) ?? '-',
    tipe: d.title, lokasi: d.category,
    severity: sevMap[d.severity] ?? 'minor',
    status: stMap[d.status] ?? d.status
  }))

  expiring.value = (expiryRes.data ?? []).map(l => ({
    nama: (l.products as any)?.name ?? '-', batch: l.lot_number,
    exp: l.expired_at?.slice(0,10) ?? '-', stok: Number(l.qty_on_hand), lokasi: '-'
  }))

  const monthDevs = devs.filter(d => new Date(d.detected_at) >= monthStart)
  stats.value[0].value = String(monthDevs.length)
  stats.value[1].value = String(capaRes.count ?? 0)
  stats.value[2].value = String(expiryRes.data?.length ?? 0)
  stats.value[3].value = String(complaintRes.count ?? 0)
}

onMounted(fetchData)
function sevBadge(s: string) {
  const m: Record<string,string> = { minor: 'bg-amber-100 text-amber-700', moderate: 'bg-orange-100 text-orange-700', major: 'bg-red-100 text-red-700' }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
function stBadge(s: string) {
  const m: Record<string,string> = { investigating: 'bg-blue-100 text-blue-700', closed: 'bg-emerald-100 text-emerald-700' }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Quality Management System</h1>
        <p class="text-sm text-[#999] mt-0.5">Insiden, audit mutu, expiry & product recall</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Lapor Insiden</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Insiden & Near Miss</h2></div>
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">ID</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Severity</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="i in insiden" :key="i.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-[#6b1525] font-semibold">{{ i.id }}</td>
              <td class="px-4 py-3 text-sm text-[#1a1a1a]">{{ i.tipe }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', sevBadge(i.severity)]">{{ i.severity }}</span></td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', stBadge(i.status)]">{{ i.status === 'investigating' ? 'Investigasi' : 'Selesai' }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5] flex justify-between items-center">
          <h2 class="text-sm font-semibold text-[#666]">Mendekati Expired (30 hari)</h2>
          <span class="text-xs text-amber-600 font-medium">{{ expiring.length }} item</span>
        </div>
        <div class="divide-y divide-[#e5e5e5]">
          <div v-for="e in expiring" :key="e.batch" class="px-5 py-4">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-sm font-medium text-[#1a1a1a]">{{ e.nama }}</p>
                <p class="text-xs text-[#999] mt-0.5">Batch: {{ e.batch }} · {{ e.lokasi }}</p>
              </div>
              <div class="text-right">
                <p class="text-xs font-semibold text-red-600">Exp: {{ e.exp }}</p>
                <p class="text-xs text-[#999]">Stok: {{ e.stok }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
