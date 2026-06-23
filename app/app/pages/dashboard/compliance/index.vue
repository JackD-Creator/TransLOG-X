<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const items = ref<any[]>([])

async function fetchData() {
  const [findingsRes, reportsRes] = await Promise.all([
    supabase.from('audit_findings').select('audit_type, title, severity, status, audit_date, due_date, notes')
      .order('audit_date', { ascending: false }).limit(20),
    supabase.from('regulatory_reports').select('report_type, regulator, status, period_start, period_end, submission_deadline, notes')
      .order('submission_deadline', { ascending: false }).limit(20),
  ])

  const findings = findingsRes.data ?? []
  const reports = reportsRes.data ?? []

  const statusMap = (s: string) => {
    if (['resolved','closed','waived','accepted','submitted'].includes(s)) return 'compliant'
    if (['open','capa_assigned','draft','review'].includes(s)) return 'in_progress'
    if (['rejected','amended'].includes(s)) return 'warning'
    return 'in_progress'
  }

  items.value = [
    ...findings.map(f => ({
      regulasi: `${f.audit_type?.toUpperCase()} — ${f.title}`,
      status: statusMap(f.status),
      last_check: f.audit_date ?? '-',
      next_check: f.due_date ?? '-',
      catatan: f.notes ?? '-'
    })),
    ...reports.map(r => ({
      regulasi: `${r.regulator} — ${r.report_type?.replace(/_/g, ' ')}`,
      status: statusMap(r.status),
      last_check: r.period_end ?? '-',
      next_check: r.submission_deadline ?? '-',
      catatan: r.notes ?? '-'
    })),
  ]

  if (items.value.length === 0) {
    items.value = [
      { regulasi: 'CDOB 2020 — Cara Distribusi Obat yang Baik', status: 'compliant', last_check: '2026-05-15', next_check: '2026-08-15', catatan: 'Sertifikasi aktif' },
      { regulasi: 'BPOM — Izin PBF & Apotek', status: 'warning', last_check: '2026-03-01', next_check: '2026-09-01', catatan: 'Izin perlu diperpanjang' },
      { regulasi: 'Akreditasi SNARS RS', status: 'compliant', last_check: '2025-12-01', next_check: '2028-12-01', catatan: 'Akreditasi Paripurna' },
    ]
  }
}

onMounted(fetchData)
function badge(s: string) {
  const m: Record<string,string> = { compliant: 'bg-emerald-100 text-emerald-700', warning: 'bg-amber-100 text-amber-700', non_compliant: 'bg-red-100 text-red-700', in_progress: 'bg-blue-100 text-blue-700' }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
function bl(s: string) { return { compliant: 'Compliant', warning: 'Perlu Perhatian', non_compliant: 'Tidak Sesuai', in_progress: 'Dalam Proses' }[s] ?? s }
function icon(s: string) { return { compliant: 'i-lucide-check-circle', warning: 'i-lucide-alert-triangle', non_compliant: 'i-lucide-x-circle', in_progress: 'i-lucide-clock' }[s] ?? 'i-lucide-circle' }
const compliantCount = computed(() => items.value.filter(i => i.status === 'compliant').length)
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Kepatuhan Regulasi</h1>
        <p class="text-sm text-[#999] mt-0.5">Monitoring regulasi, perizinan & audit kepatuhan</p>
      </div>
      <div class="flex items-center gap-2 bg-emerald-50 border border-emerald-200 rounded-xl px-4 py-2">
        <UIcon name="i-lucide-shield-check" class="text-emerald-600 text-lg" />
        <span class="text-sm font-bold text-emerald-700">{{ compliantCount }}/{{ items.length }} Compliant</span>
      </div>
    </div>
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-4 border-b border-[#e5e5e5]">
        <h2 class="text-sm font-semibold text-[#666]">Status Kepatuhan Regulasi</h2>
      </div>
      <div class="divide-y divide-[#e5e5e5]">
        <div v-for="item in items" :key="item.regulasi" class="px-5 py-4 flex items-start gap-4 hover:bg-[#eee] transition-colors">
          <div class="mt-0.5 flex-shrink-0">
            <UIcon :name="icon(item.status)" :class="[
              'text-xl',
              item.status==='compliant'?'text-emerald-500':item.status==='warning'?'text-amber-500':item.status==='in_progress'?'text-blue-500':'text-red-500'
            ]" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-[#1a1a1a]">{{ item.regulasi }}</p>
            <p class="text-xs text-[#999] mt-0.5">{{ item.catatan }}</p>
            <div class="flex gap-4 mt-1.5 text-xs text-[#999]">
              <span>Cek terakhir: {{ item.last_check }}</span>
              <span>Cek berikutnya: {{ item.next_check }}</span>
            </div>
          </div>
          <span :class="['px-2 py-0.5 rounded-full text-xs font-medium flex-shrink-0', badge(item.status)]">{{ bl(item.status) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
