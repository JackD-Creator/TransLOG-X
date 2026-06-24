<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Standing Instruction' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const siList = ref<any[]>([])
const showForm = ref(false)
const saving = ref(false)
const actionError = ref<string | null>(null)

const form = ref({
  custodian_bank: '',
  rs_account_number: '',
  ksm_account_number: '',
  si_type: 'bpjs_auto_transfer',
  notes: '',
})

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('standing_instructions')
    .select('*')
    .eq('rs_tenant_id', tenantId.value)
    .order('created_at', { ascending: false })
  siList.value = data ?? []
  loading.value = false
}

async function createSI() {
  if (!tenantId.value) return
  saving.value = true
  actionError.value = null
  try {
    const seq = Date.now().toString().slice(-6)
    const { error } = await supabase.from('standing_instructions').insert({
      rs_tenant_id: tenantId.value,
      bank_tenant_id: '4aa64caa-a1c3-4569-93dd-07487cbca252',
      ksm_tenant_id: 'de0a6815-7098-45ce-b682-1c16def8e154',
      si_number: `SI-RS-${seq}`,
      si_type: form.value.si_type,
      rs_account_number: form.value.rs_account_number,
      ksm_account_number: form.value.ksm_account_number,
      custodian_bank: form.value.custodian_bank,
      is_active: true,
      activated_at: new Date().toISOString(),
      notes: form.value.notes,
    })
    if (error) throw error
    showForm.value = false
    form.value = { custodian_bank: '', rs_account_number: '', ksm_account_number: '', si_type: 'bpjs_auto_transfer', notes: '' }
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal membuat SI'
  }
  saving.value = false
}

function openEditSI(si: any) {
  form.value = {
    custodian_bank: si.custodian_bank,
    rs_account_number: si.rs_account_number,
    ksm_account_number: si.ksm_account_number,
    si_type: si.si_type,
    notes: si.notes ?? '',
  }
  editingSI.value = si.id
  showForm.value = true
}

const editingSI = ref<string | null>(null)

async function updateSI() {
  if (!editingSI.value) return
  saving.value = true
  actionError.value = null
  try {
    const { error } = await supabase.from('standing_instructions').update({
      custodian_bank: form.value.custodian_bank,
      rs_account_number: form.value.rs_account_number,
      ksm_account_number: form.value.ksm_account_number,
      si_type: form.value.si_type,
      notes: form.value.notes,
    }).eq('id', editingSI.value)
    if (error) throw error
    showForm.value = false
    editingSI.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal update SI'
  }
  saving.value = false
}

async function deactivateSI(id: string) {
  await supabase.from('standing_instructions').update({
    is_active: false,
    deactivated_at: new Date().toISOString(),
  }).eq('id', id)
  await load()
}

async function deleteSI(id: string) {
  if (!confirm('Hapus Standing Instruction ini?')) return
  await supabase.from('standing_instructions').delete().eq('id', id)
  await load()
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Standing Instruction (SI)</h1>
        <p class="text-sm text-[#999] mt-0.5">SI bank custodian — auto-transfer ke KSM setelah pembayaran BPJS diterima</p>
      </div>
      <button v-if="!showForm" @click="showForm = true"
        class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] transition-colors flex items-center gap-2">
        <UIcon name="i-lucide-plus" class="text-sm"/>
        Buat SI Baru
      </button>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <!-- Info box -->
    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 flex items-start gap-3">
      <UIcon name="i-lucide-info" class="text-blue-500 text-base mt-0.5 flex-shrink-0"/>
      <div class="text-xs text-blue-700">
        <p class="font-bold mb-1">Cara Kerja Standing Instruction</p>
        <ol class="list-decimal list-inside space-y-0.5 text-blue-600">
          <li>RS menerbitkan SI di bank custodian</li>
          <li>Saat BPJS Kesehatan membayar ke rekening RS, bank otomatis transfer ke rekening KSM sesuai nilai PO</li>
          <li>Jika dana BPJS kurang untuk bayar invoice → bank cover kekurangan sebagai fasilitas kredit</li>
          <li>Bunga harian atas kekurangan ditanggung 50% RS + 50% KSM</li>
        </ol>
      </div>
    </div>

    <!-- Form -->
    <div v-if="showForm" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-sm font-bold text-[#1a1a1a] mb-4">Buat Standing Instruction Baru</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <div>
          <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Bank Custodian</label>
          <input v-model="form.custodian_bank" type="text" placeholder="Nama bank custodian (BCA, Mandiri, dll)"
            class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none focus:border-[#6b1525]">
        </div>
        <div>
          <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Tipe SI</label>
          <select v-model="form.si_type" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none focus:border-[#6b1525]">
            <option value="bpjs_auto_transfer">BPJS Auto Transfer</option>
            <option value="manual_transfer">Manual Transfer</option>
            <option value="escrow">Escrow Account</option>
          </select>
        </div>
        <div>
          <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Nomor Rekening RS</label>
          <input v-model="form.rs_account_number" type="text" placeholder="1234567890"
            class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none focus:border-[#6b1525]">
        </div>
        <div>
          <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Nomor Rekening KSM (tujuan)</label>
          <input v-model="form.ksm_account_number" type="text" placeholder="0987654321"
            class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none focus:border-[#6b1525]">
        </div>
      </div>
      <div class="mb-4">
        <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Catatan</label>
        <textarea v-model="form.notes" rows="2" placeholder="Catatan tambahan..."
          class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none focus:border-[#6b1525] resize-none"/>
      </div>
      <div class="flex gap-3">
        <button @click="editingSI ? updateSI() : createSI()" :disabled="saving || !form.custodian_bank || !form.rs_account_number || !form.ksm_account_number"
          class="px-5 py-2.5 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
          {{ saving ? 'Menyimpan...' : editingSI ? 'Simpan Perubahan' : 'Aktifkan SI' }}
        </button>
        <button @click="showForm = false; editingSI = null" class="px-4 py-2.5 text-[#999] text-xs rounded-lg hover:bg-[#ebebeb] transition-colors">
          Batal
        </button>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="siList.length === 0 && !showForm" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-landmark" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada Standing Instruction aktif</p>
      <p class="text-xs text-[#bbb]">Buat SI untuk mengaktifkan auto-transfer setelah BPJS cair</p>
    </div>

    <!-- SI List -->
    <div v-else class="space-y-3">
      <div v-for="si in siList" :key="si.id"
        :class="['bg-[#f5f5f5] rounded-xl border overflow-hidden', si.is_active ? 'border-emerald-300' : 'border-[#e5e5e5]']">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ si.si_number }}</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                si.is_active ? 'bg-emerald-100 text-emerald-700' : 'bg-[#f0f0f0] text-[#999]']">
                {{ si.is_active ? 'Aktif' : 'Nonaktif' }}
              </span>
              <span class="px-1.5 py-0.5 rounded text-[9px] font-semibold bg-blue-100 text-blue-700">
                {{ si.si_type === 'bpjs_auto_transfer' ? 'BPJS Auto' : si.si_type === 'escrow' ? 'Escrow' : 'Manual' }}
              </span>
            </div>
            <p class="text-xs text-[#999]">Bank: <strong class="text-[#666]">{{ si.custodian_bank }}</strong></p>
          </div>
          <div class="flex gap-2">
            <button @click="openEditSI(si)" class="p-1.5 rounded-lg hover:bg-blue-50 text-blue-600 transition-colors">
              <UIcon name="i-lucide-edit-3" class="text-sm"/>
            </button>
            <button v-if="si.is_active" @click="deactivateSI(si.id)"
              class="px-3 py-1.5 text-amber-600 text-xs font-semibold border border-amber-200 rounded-lg hover:bg-amber-50 transition-colors">
              Nonaktifkan
            </button>
            <button v-if="!si.is_active" @click="deleteSI(si.id)"
              class="p-1.5 rounded-lg hover:bg-red-50 text-red-500 transition-colors">
              <UIcon name="i-lucide-trash-2" class="text-sm"/>
            </button>
          </div>
        </div>
        <div class="px-5 pb-4 grid grid-cols-2 gap-4 text-xs">
          <div>
            <p class="text-[10px] text-[#999] mb-0.5">Rekening RS (sumber)</p>
            <p class="font-mono font-semibold text-[#1a1a1a]">{{ si.rs_account_number }}</p>
          </div>
          <div>
            <p class="text-[10px] text-[#999] mb-0.5">Rekening KSM (tujuan)</p>
            <p class="font-mono font-semibold text-[#1a1a1a]">{{ si.ksm_account_number }}</p>
          </div>
          <div>
            <p class="text-[10px] text-[#999] mb-0.5">Diaktifkan</p>
            <p class="text-[#666]">{{ si.activated_at ? fmtDate(si.activated_at) : '-' }}</p>
          </div>
          <div v-if="si.notes">
            <p class="text-[10px] text-[#999] mb-0.5">Catatan</p>
            <p class="text-[#666]">{{ si.notes }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
