<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const stats = ref([
  { label: 'Credit Limit Total',  value: '-',  icon: 'i-lucide-landmark',      color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Limit Terpakai',      value: '-',  icon: 'i-lucide-credit-card',   color: 'text-amber-600',  bg: 'bg-amber-50' },
  { label: 'Skor Risiko',         value: '-',  icon: 'i-lucide-shield',         color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'Alert Risiko Aktif',  value: '-',  icon: 'i-lucide-alert-triangle', color: 'text-red-600',    bg: 'bg-red-50' },
])
const suppliers = ref<any[]>([])

async function fetchData() {
  const [limitsRes, alertsRes] = await Promise.all([
    supabase.from('credit_limits').select('total_limit, used_amount, available_amount, interest_rate, valid_until, is_active, borrower_tenant_id, assessment_id, credit_assessments(overall_score, risk_grade)')
      .eq('is_active', true).order('total_limit', { ascending: false }),
    supabase.from('risk_alerts').select('*', { count: 'exact', head: true }).eq('status', 'open'),
  ])

  const rows = limitsRes.data ?? []
  let totalLimit = 0, totalUsed = 0
  const gradeMap: Record<string, string> = { A: 'low', B: 'medium', C: 'high', D: 'high', E: 'high' }

  suppliers.value = rows.map(r => {
    const lim = Number(r.total_limit)
    const used = Number(r.used_amount)
    totalLimit += lim; totalUsed += used
    const assess = r.credit_assessments as any
    const grade = assess?.risk_grade ?? '-'
    return {
      nama: r.borrower_tenant_id?.slice(0, 8) ?? '-',
      limit: lim, terpakai: used,
      skor: grade, risiko: gradeMap[grade] ?? 'medium',
      payment_term: `${Math.round(Number(r.interest_rate ?? 0) * 100)}bps`
    }
  })

  stats.value[0].value = fmtRp(totalLimit)
  stats.value[1].value = fmtRp(totalUsed)
  stats.value[2].value = rows.length > 0 ? (rows[0].credit_assessments as any)?.risk_grade ?? '-' : '-'
  stats.value[3].value = String(alertsRes.count ?? 0)
}

onMounted(fetchData)
function riskBadge(r: string) {
  const m: Record<string,string> = { low: 'bg-emerald-100 text-emerald-700', medium: 'bg-amber-100 text-amber-700', high: 'bg-red-100 text-red-700' }
  return m[r] ?? 'bg-[#f0f0f0] text-[#666]'
}
function riskLabel(r: string) { return { low: 'Rendah', medium: 'Sedang', high: 'Tinggi' }[r] ?? r }
function usedPct(terpakai: number, limit: number) { return Math.round((terpakai / limit) * 100) }
const rp = fmtRp
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Kredit & Manajemen Risiko</h1>
        <p class="text-sm text-[#999] mt-0.5">Credit limit supplier, skoring risiko & monitoring eksposur</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Supplier</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color, 'text-lg']" /></div>
        <div><p class="text-lg font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-4 border-b border-[#e5e5e5]">
        <h2 class="text-sm font-semibold text-[#666]">Credit Exposure per Supplier</h2>
      </div>
      <div class="divide-y divide-[#e5e5e5]">
        <div v-for="s in suppliers" :key="s.nama" class="px-5 py-4 hover:bg-[#eee] transition-colors">
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-3">
              <div class="w-9 h-9 rounded-lg bg-[#f0f0f0] flex items-center justify-center">
                <span class="text-sm font-bold text-[#666]">{{ s.skor }}</span>
              </div>
              <div>
                <p class="text-sm font-semibold text-[#1a1a1a]">{{ s.nama }}</p>
                <p class="text-xs text-[#999]">{{ s.payment_term }}</p>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', riskBadge(s.risiko)]">{{ riskLabel(s.risiko) }}</span>
              <span class="text-xs text-[#999]">{{ usedPct(s.terpakai, s.limit) }}%</span>
            </div>
          </div>
          <div class="w-full h-2 bg-[#f0f0f0] rounded-full overflow-hidden">
            <div
              :class="['h-full rounded-full transition-all', usedPct(s.terpakai, s.limit) >= 90 ? 'bg-red-500' : usedPct(s.terpakai, s.limit) >= 70 ? 'bg-amber-500' : 'bg-emerald-500']"
              :style="`width:${usedPct(s.terpakai, s.limit)}%`"
            />
          </div>
          <div class="flex justify-between text-xs text-[#999] mt-1">
            <span>Terpakai: {{ fmtRp(s.terpakai) }}</span>
            <span>Limit: {{ fmtRp(s.limit) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
