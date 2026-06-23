<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const activeTab = ref('klaim')
const tabs = [
  { key: 'klaim',  label: 'Klaim BPJS',      icon: 'i-lucide-stethoscope' },
  { key: 'rcm',    label: 'RCM & Verifikasi', icon: 'i-lucide-shield-check' },
  { key: 'bridging',label: 'Bridging System', icon: 'i-lucide-link' },
]
const stats = ref([
  { label: 'Klaim Bulan Ini',      value: '-',  icon: 'i-lucide-file-medical',   color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Nilai Klaim',          value: '-',  icon: 'i-lucide-banknote',       color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'Pending Verifikasi',   value: '-',  icon: 'i-lucide-clock',          color: 'text-amber-600',  bg: 'bg-amber-50' },
  { label: 'Ditolak / Dispute',    value: '-',  icon: 'i-lucide-x-circle',       color: 'text-red-600',    bg: 'bg-red-50' },
])
const klaimList = ref<any[]>([])

async function fetchData() {
  const monthStart = new Date(); monthStart.setDate(1); monthStart.setHours(0,0,0,0)

  const [claimsRes, pendingRes, rejectedRes] = await Promise.all([
    supabase.from('bpjs_claims').select('claim_number, patient_name, bpjs_card_no, primary_icd10, claim_type, claimed_amount, status, created_at')
      .order('created_at', { ascending: false }).limit(20),
    supabase.from('bpjs_claims').select('*', { count: 'exact', head: true })
      .in('status', ['submitted','under_review']),
    supabase.from('bpjs_claims').select('*', { count: 'exact', head: true })
      .in('status', ['rejected','disputed']),
  ])

  const rows = claimsRes.data ?? []
  const tipeLabel: Record<string,string> = { rawat_inap: 'Rawat Inap', rawat_jalan: 'Rawat Jalan', igd: 'IGD', kronis: 'Kronis', bayi_baru_lahir: 'BBL' }

  klaimList.value = rows.map(c => ({
    id: c.claim_number, pasien: c.patient_name ?? '-', no_kartu: c.bpjs_card_no,
    diagnosa: c.primary_icd10, tipe: tipeLabel[c.claim_type] ?? c.claim_type,
    nominal: Number(c.claimed_amount), status: c.status, tgl: c.created_at?.slice(0,10) ?? '-'
  }))

  const monthClaims = rows.filter(c => new Date(c.created_at) >= monthStart)
  const totalVal = monthClaims.reduce((s, c) => s + Number(c.claimed_amount), 0)

  stats.value[0].value = monthClaims.length.toLocaleString('id-ID')
  stats.value[1].value = totalVal >= 1e9 ? `Rp ${(totalVal/1e9).toFixed(2).replace('.',',')}M` : `Rp ${Math.round(totalVal/1e6)}Jt`
  stats.value[2].value = String(pendingRes.count ?? 0)
  stats.value[3].value = String(rejectedRes.count ?? 0)
}

onMounted(fetchData)
function badge(s: string) {
  const m: Record<string,string> = {
    submitted: 'bg-blue-100 text-blue-700',
    verified:  'bg-purple-100 text-purple-700',
    paid:      'bg-emerald-100 text-emerald-700',
    rejected:  'bg-red-100 text-red-700',
    pending:   'bg-amber-100 text-amber-700',
    connected: 'bg-emerald-100 text-emerald-700',
    error:     'bg-red-100 text-red-700',
  }
  return m[s] ?? 'bg-[#f0f0f0] text-[#666]'
}
function bl(s: string) {
  const m: Record<string,string> = { submitted: 'Diajukan', verified: 'Terverifikasi', paid: 'Dibayar', rejected: 'Ditolak', pending: 'Pending', connected: 'Terhubung', error: 'Error' }
  return m[s] ?? s
}
const bridgingStatus = ref([
  { sistem: 'VCLAIM BPJS',    versi: 'v3.0', status: 'connected', last_sync: '2026-06-22 08:00' },
  { sistem: 'SATU SEHAT',     versi: 'v2.1', status: 'connected', last_sync: '2026-06-22 07:55' },
  { sistem: 'INACBG',         versi: 'v5.3', status: 'connected', last_sync: '2026-06-22 06:00' },
  { sistem: 'SIM RS Internal',versi: 'v1.8', status: 'error',     last_sync: '2026-06-21 22:10' },
])
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">BPJS & Revenue Cycle Management</h1>
        <p class="text-sm text-[#999] mt-0.5">Klaim, verifikasi, bridging & rekonsiliasi BPJS</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Input Klaim</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color, 'text-lg']" /></div>
        <div><p class="text-lg font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="flex border-b border-[#e5e5e5]">
        <button v-for="tab in tabs" :key="tab.key" class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab===tab.key?'border-[#6b1525] text-[#6b1525]':'border-transparent text-[#999] hover:text-[#666]'"
          @click="activeTab=tab.key"><UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}</button>
      </div>
      <div v-if="activeTab==='klaim'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">ID Klaim</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Pasien</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">No. Kartu</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Diagnosa</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nominal</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="k in klaimList" :key="k.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-[#6b1525] font-semibold">{{ k.id }}</td>
              <td class="px-4 py-3 text-sm font-medium text-[#1a1a1a]">{{ k.pasien }}</td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ k.no_kartu }}</td>
              <td class="px-4 py-3 text-xs text-[#666]">{{ k.diagnosa }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ k.tipe }}</td>
              <td class="px-4 py-3 text-right text-sm font-semibold text-[#1a1a1a]">Rp {{ k.nominal.toLocaleString('id-ID') }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(k.status)]">{{ bl(k.status) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="activeTab==='rcm'" class="p-8 text-center text-[#999]">
        <UIcon name="i-lucide-shield-check" class="text-4xl mb-3 block mx-auto text-[#999]"/>
        <p class="text-sm font-medium text-[#999]">Dashboard RCM & Verifikasi Koding</p>
        <p class="text-xs text-[#999] mt-1">Integrasi dengan INA-CBG & VCLAIM sedang dikonfigurasi</p>
      </div>
      <div v-if="activeTab==='bridging'" class="p-5">
        <div class="space-y-3">
          <div v-for="b in bridgingStatus" :key="b.sistem" class="flex items-center justify-between p-4 rounded-xl border border-[#e5e5e5]">
            <div class="flex items-center gap-3">
              <div :class="['w-2.5 h-2.5 rounded-full flex-shrink-0', b.status==='connected'?'bg-emerald-500':'bg-red-500']"/>
              <div>
                <p class="text-sm font-semibold text-[#1a1a1a]">{{ b.sistem }}</p>
                <p class="text-xs text-[#999]">Versi {{ b.versi }} · Last sync: {{ b.last_sync }}</p>
              </div>
            </div>
            <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(b.status)]">{{ bl(b.status) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
