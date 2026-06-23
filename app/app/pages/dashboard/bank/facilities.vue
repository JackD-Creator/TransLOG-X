<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Fasilitas SCF Aktif' })

const supabase = useSupabaseClient()
const loading = ref(true)
const facilities = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('scf_facilities')
    .select('*, borrower:borrower_tenant_id(name, type)')
    .in('status', ['approved', 'disbursed', 'partially_repaid'])
    .order('facility_start', { ascending: false })
  facilities.value = data ?? []
  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}
function fmtDate(d: string) {
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const ftypeLabel: Record<string, string> = {
  reverse_factoring: 'Reverse Factoring',
  invoice_financing: 'Invoice Financing',
  bpjs_bridging: 'BPJS Bridging',
  po_financing: 'PO Financing',
  inventory_financing: 'Inventory Financing',
}

const totalLimit = computed(() => facilities.value.reduce((s, f) => s + Number(f.facility_limit ?? 0), 0))
const totalUsed = computed(() => facilities.value.reduce((s, f) => s + Number(f.outstanding ?? 0), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Fasilitas SCF Aktif</h1>
      <p class="text-sm text-[#999] mt-0.5">Portofolio fasilitas Supply Chain Finance yang dikelola Bank</p>
    </div>

    <!-- Portfolio Summary -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total Limit Portfolio</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(totalLimit) }}</p>
        <p class="text-xs text-[#999]">{{ facilities.length }} fasilitas aktif</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total Outstanding</p>
        <p class="text-2xl font-bold text-amber-600">{{ fmtRp(totalUsed) }}</p>
        <p class="text-xs text-[#999]">{{ totalLimit > 0 ? (totalUsed / totalLimit * 100).toFixed(1) : 0 }}% utilisasi</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Available</p>
        <p class="text-2xl font-bold text-emerald-600">{{ fmtRp(totalLimit - totalUsed) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="facilities.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-landmark" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada fasilitas aktif</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="f in facilities" :key="f.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <div class="flex items-start justify-between mb-4">
          <div>
            <p class="text-sm font-bold text-[#1a1a1a]">{{ f.facility_number }}</p>
            <p class="text-xs text-[#999]">{{ (f.borrower as any)?.name ?? '-' }} · {{ ftypeLabel[f.financing_type] ?? f.financing_type }}</p>
          </div>
          <div class="text-right text-xs">
            <p class="text-[#999]">{{ (Number(f.interest_rate_pa) * 100).toFixed(2) }}% p.a.</p>
            <p class="text-[#999]">Tenor {{ f.tenor_days }} hari</p>
          </div>
        </div>

        <div class="grid grid-cols-3 gap-4 text-xs mb-3">
          <div>
            <p class="text-[#999]">Limit</p>
            <p class="font-bold text-[#1a1a1a]">{{ fmtRp(f.facility_limit) }}</p>
          </div>
          <div>
            <p class="text-[#999]">Outstanding</p>
            <p class="font-bold text-amber-600">{{ fmtRp(f.outstanding) }}</p>
          </div>
          <div>
            <p class="text-[#999]">Available</p>
            <p class="font-bold text-emerald-600">{{ fmtRp(f.available_limit) }}</p>
          </div>
        </div>

        <div class="w-full bg-[#e5e5e5] rounded-full h-2 mb-2">
          <div class="h-2 rounded-full transition-all"
            :class="f.facility_limit > 0 && f.outstanding / f.facility_limit > 0.8 ? 'bg-red-500' : 'bg-[#6b1525]'"
            :style="`width:${f.facility_limit > 0 ? Math.min(100, f.outstanding / f.facility_limit * 100) : 0}%`"/>
        </div>

        <div class="flex gap-4 text-[10px] text-[#999]">
          <span>{{ fmtDate(f.facility_start) }} – {{ fmtDate(f.facility_end) }}</span>
          <span v-if="f.standing_instruction_active" class="text-emerald-600 font-semibold">● SI Aktif</span>
        </div>
      </div>
    </div>
  </div>
</template>
