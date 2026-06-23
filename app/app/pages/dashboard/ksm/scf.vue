<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Fasilitas SCF' })

const supabase = useSupabaseClient()

const loading = ref(true)
const facilities = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('scf_facilities')
    .select('*, tenants:bank_tenant_id(name, city)')
    .order('facility_start', { ascending: false })
    .limit(20)
  facilities.value = data ?? []
  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}
function fmtDate(d: string) {
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const statusColor: Record<string, string> = {
  draft: 'bg-[#f0f0f0] text-[#999]',
  approved: 'bg-emerald-100 text-emerald-700',
  disbursed: 'bg-blue-100 text-blue-700',
  partially_repaid: 'bg-amber-100 text-amber-700',
  fully_repaid: 'bg-[#f0f0f0] text-[#666]',
  defaulted: 'bg-red-100 text-red-700',
}
const ftypeLabel: Record<string, string> = {
  reverse_factoring: 'Reverse Factoring',
  invoice_financing: 'Invoice Financing',
  bpjs_bridging: 'BPJS Bridging',
  po_financing: 'PO Financing',
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Fasilitas SCF / Pembiayaan</h1>
      <p class="text-sm text-[#999] mt-0.5">Fasilitas Supply Chain Finance dari Bank untuk KSM</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="facilities.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-landmark" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada fasilitas SCF aktif</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="f in facilities" :key="f.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <div class="flex items-start justify-between mb-4">
          <div>
            <p class="text-sm font-bold text-[#1a1a1a]">{{ f.facility_number }}</p>
            <p class="text-xs text-[#999]">{{ (f.tenants as any)?.name ?? '-' }} · {{ ftypeLabel[f.financing_type] ?? f.financing_type }}</p>
          </div>
          <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', statusColor[f.status] ?? 'bg-[#f0f0f0] text-[#999]']">
            {{ f.status }}
          </span>
        </div>

        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs mb-4">
          <div>
            <p class="text-[#999] mb-0.5">Limit Fasilitas</p>
            <p class="font-bold text-[#1a1a1a]">{{ fmtRp(f.facility_limit) }}</p>
          </div>
          <div>
            <p class="text-[#999] mb-0.5">Outstanding</p>
            <p class="font-bold text-amber-600">{{ fmtRp(f.outstanding) }}</p>
          </div>
          <div>
            <p class="text-[#999] mb-0.5">Available Limit</p>
            <p class="font-bold text-emerald-600">{{ fmtRp(f.available_limit) }}</p>
          </div>
          <div>
            <p class="text-[#999] mb-0.5">Bunga p.a.</p>
            <p class="font-bold text-[#1a1a1a]">{{ (Number(f.interest_rate_pa) * 100).toFixed(2) }}%</p>
          </div>
        </div>

        <!-- Utilization bar -->
        <div class="mb-3">
          <div class="flex justify-between text-[10px] text-[#999] mb-1">
            <span>Utilisasi Limit</span>
            <span>{{ f.facility_limit > 0 ? (f.outstanding / f.facility_limit * 100).toFixed(1) : 0 }}%</span>
          </div>
          <div class="w-full bg-[#e5e5e5] rounded-full h-2">
            <div class="bg-[#6b1525] h-2 rounded-full transition-all"
              :style="`width:${f.facility_limit > 0 ? Math.min(100, f.outstanding / f.facility_limit * 100) : 0}%`"/>
          </div>
        </div>

        <div class="flex gap-4 text-[10px] text-[#999]">
          <span>Tenor: {{ f.tenor_days }} hari</span>
          <span>Aktif: {{ fmtDate(f.facility_start) }} – {{ fmtDate(f.facility_end) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
