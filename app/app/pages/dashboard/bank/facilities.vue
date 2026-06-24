<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Fasilitas SCF Aktif' })

const supabase = useSupabaseClient()
const loading = ref(true)
const facilities = ref<any[]>([])
const showModal = ref(false)
const editingFac = ref<any>(null)
const saving = ref(false)
const actionError = ref<string | null>(null)

const facForm = ref({
  facility_limit: 5_000_000_000, interest_rate_pa: 0.11, tenor_days: 30,
  payment_terms: 'net_30', facility_start: new Date().toISOString().slice(0, 10),
  facility_end: new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10),
})

function openAddFac() {
  editingFac.value = null
  facForm.value = { facility_limit: 5_000_000_000, interest_rate_pa: 0.11, tenor_days: 30, payment_terms: 'net_30', facility_start: new Date().toISOString().slice(0, 10), facility_end: new Date(Date.now() + 365 * 86400000).toISOString().slice(0, 10) }
  showModal.value = true
}

function openEditFac(f: any) {
  editingFac.value = f
  facForm.value = { facility_limit: f.facility_limit, interest_rate_pa: f.interest_rate_pa, tenor_days: f.tenor_days, payment_terms: f.payment_terms, facility_start: f.facility_start, facility_end: f.facility_end }
  showModal.value = true
}

async function saveFacility() {
  saving.value = true
  actionError.value = null
  try {
    if (editingFac.value) {
      const { error } = await supabase.from('scf_facilities').update({
        facility_limit: facForm.value.facility_limit,
        interest_rate_pa: facForm.value.interest_rate_pa,
        tenor_days: facForm.value.tenor_days,
        payment_terms: facForm.value.payment_terms,
        facility_start: facForm.value.facility_start,
        facility_end: facForm.value.facility_end,
      }).eq('id', editingFac.value.id)
      if (error) throw error
    } else {
      const seq = Date.now().toString().slice(-4)
      const { error } = await supabase.from('scf_facilities').insert({
        bank_tenant_id: '4aa64caa-a1c3-4569-93dd-07487cbca252',
        borrower_tenant_id: 'de0a6815-7098-45ce-b682-1c16def8e154',
        facility_number: `SCF-KSM-${new Date().getFullYear()}-${seq}`,
        financing_type: 'reverse_factoring',
        ...facForm.value,
        status: 'approved',
        approved_at: new Date().toISOString(),
      })
      if (error) throw error
    }
    showModal.value = false
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal simpan'
  }
  saving.value = false
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('scf_facilities')
    .select('id,facility_number,financing_type,facility_limit,outstanding,available_limit,interest_rate_pa,tenor_days,payment_terms,status,facility_start,facility_end,standing_instruction_active')
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
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Fasilitas SCF Aktif</h1>
        <p class="text-sm text-[#999] mt-0.5">Portofolio fasilitas Supply Chain Finance yang dikelola Bank</p>
      </div>
      <button @click="openAddFac" class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] transition-colors flex items-center gap-2">
        <UIcon name="i-lucide-plus" class="text-sm"/> Tambah Fasilitas
      </button>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
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
            <p class="text-xs text-[#999]">KSM Mitra · {{ ftypeLabel[f.financing_type] ?? f.financing_type }}</p>
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

        <div class="flex items-center justify-between mt-2">
          <div class="flex gap-4 text-[10px] text-[#999]">
            <span>{{ fmtDate(f.facility_start) }} – {{ fmtDate(f.facility_end) }}</span>
            <span v-if="f.standing_instruction_active" class="text-emerald-600 font-semibold">● SI Aktif</span>
          </div>
          <button @click="openEditFac(f)" class="px-2.5 py-1 text-[10px] font-bold text-blue-600 border border-blue-200 rounded-lg hover:bg-blue-50 transition-colors flex items-center gap-1">
            <UIcon name="i-lucide-edit-3" class="text-xs"/> Edit
          </button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Facility Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">{{ editingFac ? 'Edit Fasilitas SCF' : 'Tambah Fasilitas SCF Baru' }}</h3>
        </div>
        <div class="p-6 space-y-3">
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Limit Fasilitas (Rp)</label>
            <input v-model.number="facForm.facility_limit" type="number" min="0"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Bunga p.a. (desimal)</label>
              <input v-model.number="facForm.interest_rate_pa" type="number" step="0.01" min="0"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Tenor (hari)</label>
              <input v-model.number="facForm.tenor_days" type="number" min="1"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Mulai</label>
              <input v-model="facForm.facility_start" type="date"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Berakhir</label>
              <input v-model="facForm.facility_end" type="date"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="saveFacility" :disabled="saving"
            class="flex-1 py-2.5 bg-[#6b1525] text-white text-sm font-bold rounded-xl hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
            {{ saving ? 'Menyimpan...' : editingFac ? 'Simpan Perubahan' : 'Tambah Fasilitas' }}
          </button>
          <button @click="showModal = false" class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5]">Batal</button>
        </div>
      </div>
    </div>
  </div>
</template>
