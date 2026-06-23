<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const stats = ref([
  { label: 'Mitra Terverifikasi', value: '-',  icon: 'i-lucide-badge-check',    color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'KYC Pending',         value: '-',  icon: 'i-lucide-clock',           color: 'text-amber-600',  bg: 'bg-amber-50' },
  { label: 'Alert Fraud',         value: '-',  icon: 'i-lucide-shield-alert',    color: 'text-red-600',    bg: 'bg-red-50' },
  { label: 'Blacklist',           value: '-',  icon: 'i-lucide-ban',             color: 'text-[#666]',   bg: 'bg-[#f0f0f0]' },
])
const mitra = ref<any[]>([])

async function fetchData() {
  const [kycRes, fraudRes] = await Promise.all([
    supabase.from('kyc_verifications').select('verification_number, subject_type, kyc_level, status, risk_level, slik_score, verified_at, updated_at, suppliers(short_name, supplier_type)')
      .order('updated_at', { ascending: false }).limit(20),
    supabase.from('fraud_alerts').select('*', { count: 'exact', head: true }).eq('status', 'open'),
  ])

  const rows = kycRes.data ?? []
  const statusMap: Record<string,string> = { verified: 'verified', approved: 'verified', pending_review: 'review', in_progress: 'review', not_started: 'pending', rejected: 'blacklisted' }
  const levelMap: Record<string,string> = { basic: 'Basic', enhanced: 'Enhanced', full: 'Full' }

  mitra.value = rows.map(r => ({
    nama: (r.suppliers as any)?.short_name ?? r.verification_number,
    tipe: (r.suppliers as any)?.supplier_type ?? r.subject_type,
    kyc_level: levelMap[r.kyc_level] ?? r.kyc_level,
    skor: r.slik_score ?? 0,
    status: statusMap[r.status] ?? r.status,
    last_review: r.verified_at?.slice(0,10) ?? r.updated_at?.slice(0,10) ?? '-'
  }))

  const verified = rows.filter(r => r.status === 'verified' || r.status === 'approved').length
  const pending = rows.filter(r => ['not_started','pending_review','in_progress'].includes(r.status)).length
  const blacklisted = rows.filter(r => r.status === 'rejected').length

  stats.value[0].value = String(verified)
  stats.value[1].value = String(pending)
  stats.value[2].value = String(fraudRes.count ?? 0)
  stats.value[3].value = String(blacklisted)

  if (mitra.value.length === 0) {
    mitra.value = [
      { nama: 'PT. Kimia Farma', tipe: 'Distributor PBF', kyc_level: 'Enhanced', skor: 95, status: 'verified', last_review: '2026-03-01' },
      { nama: 'PT. Enseval Medika', tipe: 'Distributor PBF', kyc_level: 'Standard', skor: 88, status: 'verified', last_review: '2026-04-15' },
    ]
    stats.value[0].value = '2'; stats.value[1].value = '0'; stats.value[3].value = '0'
  }
}

onMounted(fetchData)
function badge(s: string) {
  const m: Record<string,string> = { verified: 'bg-emerald-100 text-emerald-700', review: 'bg-amber-100 text-amber-700', pending: 'bg-blue-100 text-blue-700', blacklisted: 'bg-red-100 text-red-700' }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
function bl(s: string) { return { verified: 'Terverifikasi', review: 'Review Ulang', pending: 'Pending KYC', blacklisted: 'Blacklist' }[s] ?? s }
function scoreColor(n: number) { return n >= 80 ? 'text-emerald-600' : n >= 60 ? 'text-amber-600' : 'text-red-600' }
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">KYC & Deteksi Fraud</h1>
        <p class="text-sm text-[#999] mt-0.5">Know Your Counterparty, skoring risiko & blacklist monitoring</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Mitra KYC</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Status KYC Mitra</h2></div>
      <table class="w-full text-sm">
        <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
          <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nama Mitra</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">KYC Level</th>
          <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Skor</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Last Review</th>
          <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
          <th class="px-4 py-3" />
        </tr></thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="m in mitra" :key="m.nama" class="hover:bg-[#eee] transition-colors cursor-pointer">
            <td class="px-4 py-3 text-sm font-medium text-[#1a1a1a]">{{ m.nama }}</td>
            <td class="px-4 py-3 text-xs text-[#999]">{{ m.tipe }}</td>
            <td class="px-4 py-3 text-xs text-[#666]">{{ m.kyc_level }}</td>
            <td class="px-4 py-3 text-right font-bold text-sm" :class="scoreColor(m.skor)">{{ m.skor }}</td>
            <td class="px-4 py-3 text-xs text-[#999]">{{ m.last_review }}</td>
            <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(m.status)]">{{ bl(m.status) }}</span></td>
            <td class="px-4 py-3 text-right"><UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" /></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
