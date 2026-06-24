<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Detail PO' })

const supabase = useSupabaseClient()
const route = useRoute()

const po = ref<any>(null)
const lines = ref<any[]>([])
const loading = ref(true)
const updating = ref(false)

const STATUS_STEPS = [
  { key: 'draft',             label: 'Draft',               icon: 'i-lucide-file-edit',       desc: 'PO dibuat KSM' },
  { key: 'submitted',         label: 'Diajukan',            icon: 'i-lucide-send',            desc: 'PO dikirim ke Distributor' },
  { key: 'approved',          label: 'Dist. Konfirmasi',    icon: 'i-lucide-check-circle',    desc: 'Distributor setuju & siapkan' },
  { key: 'sent_to_supplier',  label: 'Dikirim ke RS',       icon: 'i-lucide-truck',           desc: 'Dist. kirim langsung ke RS' },
  { key: 'partially_received',label: 'RS Terima Sebagian',  icon: 'i-lucide-package-open',    desc: 'RS terima sebagian item' },
  { key: 'fully_received',    label: 'RS Terima Lengkap',   icon: 'i-lucide-package-check',   desc: 'RS konfirmasi semua diterima' },
]

const STATUS_ORDER = STATUS_STEPS.map(s => s.key)

const currentStepIndex = computed(() => {
  const idx = STATUS_ORDER.indexOf(po.value?.status)
  return idx === -1 ? 0 : idx
})

function stepState(i: number) {
  if (i < currentStepIndex.value) return 'done'
  if (i === currentStepIndex.value) return 'active'
  return 'pending'
}

const supplierName = computed(() => po.value?.metadata?.supplier_name ?? '-')
const rsName = computed(() => po.value?.metadata?.rs_name ?? po.value?.metadata?.rs_address ?? '-')
const trackingNo = computed(() => po.value?.metadata?.tracking_number ?? null)

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('*, ksm_po_lines(*)')
    .eq('id', route.params.id as string)
    .single()
  po.value = data
  lines.value = data?.ksm_po_lines ?? []
  loading.value = false
}

const actionError = ref<string | null>(null)

async function updateStatus(newStatus: string) {
  updating.value = true
  actionError.value = null
  try {
    if (newStatus === 'submitted') {
      const { error } = await supabase.from('ksm_purchase_orders').update({ status: newStatus }).eq('id', po.value.id)
      if (error) throw error
    } else if (newStatus === 'cancelled') {
      const { error } = await supabase.from('ksm_purchase_orders').update({ status: newStatus }).eq('id', po.value.id)
      if (error) throw error
    }
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal update status'
  }
  updating.value = false
}

async function approvePO() {
  updating.value = true
  actionError.value = null
  try {
    const { data, error } = await supabase.rpc('ksm_approve_po', { p_po_id: po.value.id })
    if (error) throw error
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal approve PO'
  }
  updating.value = false
}

async function requestCorrection() {
  const reason = prompt('Alasan koreksi:')
  if (!reason) return
  updating.value = true
  actionError.value = null
  try {
    const { data, error } = await supabase.rpc('ksm_request_po_correction', { p_po_id: po.value.id, p_reason: reason })
    if (error) throw error
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal kirim koreksi'
  }
  updating.value = false
}

const receiveModal = ref(false)
const receiveQtys = ref<Record<string, number>>({})

function openReceiveModal() {
  receiveQtys.value = {}
  for (const l of lines.value) receiveQtys.value[l.id] = l.ordered_qty
  receiveModal.value = true
}

async function confirmReceive() {
  updating.value = true
  actionError.value = null
  try {
    const items = lines.value.map(l => ({ line_id: l.id, received_qty: receiveQtys.value[l.id] ?? 0 }))
    const { data, error } = await supabase.rpc('rs_confirm_receipt', { p_po_id: po.value.id, p_received_items: items })
    if (error) throw error
    receiveModal.value = false
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal konfirmasi penerimaan'
  }
  updating.value = false
}

const statusColor: Record<string, string> = {
  draft: 'bg-[#f0f0f0] text-[#999]',
  submitted: 'bg-blue-100 text-blue-700',
  approved: 'bg-purple-100 text-purple-700',
  sent_to_supplier: 'bg-amber-100 text-amber-700',
  partially_received: 'bg-orange-100 text-orange-700',
  fully_received: 'bg-emerald-100 text-emerald-700',
  cancelled: 'bg-red-100 text-red-700',
}
const statusLabel: Record<string, string> = {
  draft: 'Draft', submitted: 'Diajukan ke Dist.', approved: 'Dist. Konfirmasi',
  sent_to_supplier: 'Dikirim ke RS', partially_received: 'RS Terima Sebagian',
  fully_received: 'RS Terima Lengkap', cancelled: 'Dibatalkan',
}

function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })
}

onMounted(load)
</script>

<template>
  <div v-if="loading" class="flex items-center justify-center py-20">
    <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
  </div>

  <div v-else-if="!po" class="text-center py-20 text-[#999]">PO tidak ditemukan.</div>

  <div v-else class="space-y-5 max-w-5xl">
    <!-- Header -->
    <div class="flex items-start justify-between">
      <div class="flex items-start gap-3">
        <NuxtLink to="/dashboard/ksm/purchase-orders"
          class="w-8 h-8 rounded-lg bg-[#ebebeb] flex items-center justify-center hover:bg-[#e0e0e0] mt-0.5">
          <UIcon name="i-lucide-arrow-left" class="text-sm text-[#666]"/>
        </NuxtLink>
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-xl font-bold text-[#1a1a1a]">{{ po.po_number }}</h1>
            <span :class="['px-2 py-0.5 rounded-full text-[11px] font-semibold', statusColor[po.status]]">
              {{ statusLabel[po.status] ?? po.status }}
            </span>
          </div>
          <p class="text-sm text-[#999] mt-0.5">{{ fmtDate(po.po_date) }} · {{ supplierName }} → <strong class="text-[#1a1a1a]">{{ rsName }}</strong></p>
        </div>
      </div>
      <div class="text-right">
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
        <p class="text-xs text-[#999]">{{ po.payment_terms?.replace('net_', 'Net ') }}</p>
      </div>
    </div>

    <!-- Timeline -->
    <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl p-6">
      <p class="text-xs font-bold text-[#666] uppercase tracking-wide mb-5">Tracking Pengiriman</p>
      <div class="relative">
        <!-- Line -->
        <div class="absolute top-5 left-5 right-5 h-0.5 bg-[#e0e0e0] z-0"/>
        <div class="absolute top-5 left-5 h-0.5 bg-[#6b1525] z-0 transition-all duration-500"
          :style="`width: calc(${(currentStepIndex / (STATUS_STEPS.length - 1)) * 100}% - 0px)`"/>

        <div class="relative z-10 grid grid-cols-6 gap-2">
          <div v-for="(step, i) in STATUS_STEPS" :key="step.key" class="flex flex-col items-center text-center">
            <div :class="['w-10 h-10 rounded-full flex items-center justify-center transition-all duration-300 mb-2',
              stepState(i) === 'done'   ? 'bg-[#6b1525] text-white' :
              stepState(i) === 'active' ? 'bg-[#6b1525] text-white ring-4 ring-[#6b1525]/20' :
              'bg-white border-2 border-[#e0e0e0] text-[#ccc]']">
              <UIcon v-if="stepState(i) === 'done'" name="i-lucide-check" class="text-sm"/>
              <UIcon v-else :name="step.icon" class="text-sm"/>
            </div>
            <p :class="['text-[10px] font-semibold leading-tight',
              stepState(i) === 'pending' ? 'text-[#ccc]' : 'text-[#1a1a1a]']">
              {{ step.label }}
            </p>
            <p class="text-[9px] text-[#aaa] mt-0.5 leading-tight hidden md:block">{{ step.desc }}</p>
          </div>
        </div>
      </div>

      <!-- Tracking info -->
      <div v-if="trackingNo" class="mt-5 bg-amber-50 border border-amber-200 rounded-xl p-3 flex items-center gap-3">
        <UIcon name="i-lucide-truck" class="text-amber-600 text-base flex-shrink-0"/>
        <div>
          <p class="text-xs font-bold text-amber-800">No. Resi: {{ trackingNo }}</p>
          <p v-if="po.metadata?.courier" class="text-[10px] text-amber-600">{{ po.metadata.courier }}</p>
        </div>
      </div>

      <!-- Error display -->
      <div v-if="actionError" class="mt-4 px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
        <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
        <div>
          <p class="text-xs font-semibold text-red-700">Gagal</p>
          <p class="text-[10px] text-red-600">{{ actionError }}</p>
        </div>
        <button @click="actionError = null" class="ml-auto text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
      </div>

      <!-- Aksi sesuai status -->
      <div class="mt-5 flex gap-2 flex-wrap">
        <button v-if="po.status === 'draft'" @click="updateStatus('submitted')" :disabled="updating"
          class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2">
          <UIcon name="i-lucide-send" class="text-sm"/> Ajukan ke Distributor
        </button>

        <!-- Supplier sudah konfirmasi → KSM review: approve atau minta koreksi -->
        <template v-if="po.status === 'approved' && po.metadata?.needs_ksm_review">
          <div class="flex items-center gap-2 px-3 py-2 bg-blue-50 border border-blue-200 rounded-lg text-xs text-blue-700">
            <UIcon name="i-lucide-info" class="text-sm"/>
            Supplier sudah konfirmasi — review dan approve atau minta koreksi
          </div>
          <button @click="approvePO" :disabled="updating"
            class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
            <UIcon name="i-lucide-check" class="text-sm"/> Approve & Kirim Info ke RS
          </button>
          <button @click="requestCorrection" :disabled="updating"
            class="px-4 py-2 bg-white border border-amber-300 text-amber-700 text-xs font-semibold rounded-lg hover:bg-amber-50 disabled:opacity-50 transition-colors flex items-center gap-2">
            <UIcon name="i-lucide-rotate-ccw" class="text-sm"/> Minta Koreksi ke Supplier
          </button>
        </template>

        <!-- Approve tanpa review flag (approve biasa) -->
        <button v-else-if="po.status === 'approved'" @click="approvePO" :disabled="updating"
          class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
          <UIcon name="i-lucide-check" class="text-sm"/> Approve & Kirim Info ke RS
        </button>

        <button v-if="po.status === 'sent_to_supplier'" @click="openReceiveModal" :disabled="updating"
          class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
          <UIcon name="i-lucide-package-check" class="text-sm"/> Input Info Penerimaan RS
        </button>
        <button v-if="po.status === 'fully_received'"
          class="px-4 py-2 bg-blue-600 text-white text-xs font-bold rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2">
          <UIcon name="i-lucide-file-text" class="text-sm"/> Buat Invoice ke RS
        </button>
        <button v-if="po.status === 'draft'" @click="updateStatus('cancelled')" :disabled="updating"
          class="px-4 py-2 bg-white border border-[#e5e5e5] text-[#999] text-xs font-semibold rounded-lg hover:bg-red-50 hover:border-red-200 hover:text-red-600 disabled:opacity-50 transition-colors">
          Batalkan PO
        </button>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
      <!-- Item Lines -->
      <div class="lg:col-span-2">
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-3 border-b border-[#ebebeb] bg-[#ebebeb]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Item Pesanan ({{ lines.length }})</p>
          </div>
          <table class="w-full text-xs">
            <thead class="border-b border-[#e5e5e5]">
              <tr class="text-left">
                <th class="px-4 py-3 font-semibold text-[#999]">Item</th>
                <th class="px-3 py-3 font-semibold text-[#999] text-center">Pesan</th>
                <th class="px-3 py-3 font-semibold text-[#999] text-center">Diterima RS</th>
                <th class="px-3 py-3 font-semibold text-[#999] text-right">Harga</th>
                <th class="px-3 py-3 font-semibold text-[#999] text-right">Total</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#f0f0f0]">
              <tr v-for="line in lines" :key="line.id" class="hover:bg-[#ebebeb] transition-colors">
                <td class="px-4 py-3">
                  <p class="font-semibold text-[#1a1a1a]">{{ line.item_name }}</p>
                  <p class="text-[10px] font-mono text-[#aaa] mt-0.5">{{ line.kfa_code }} · {{ line.uom }}</p>
                </td>
                <td class="px-3 py-3 text-center font-semibold text-[#1a1a1a]">{{ line.ordered_qty }}</td>
                <td class="px-3 py-3 text-center">
                  <span :class="['font-semibold',
                    line.received_qty >= line.ordered_qty ? 'text-emerald-600' :
                    line.received_qty > 0 ? 'text-amber-600' : 'text-[#ccc]']">
                    {{ line.received_qty || '—' }}
                  </span>
                </td>
                <td class="px-3 py-3 text-right text-[#666]">{{ fmtRp(line.unit_price) }}</td>
                <td class="px-3 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(line.line_total) }}</td>
              </tr>
            </tbody>
            <tfoot class="border-t border-[#e5e5e5] bg-[#fafafa]">
              <tr>
                <td colspan="4" class="px-4 py-2.5 text-xs text-right text-[#666]">Subtotal</td>
                <td class="px-3 py-2.5 text-right text-xs font-semibold text-[#1a1a1a]">{{ fmtRp(po.subtotal) }}</td>
              </tr>
              <tr>
                <td colspan="4" class="px-4 py-2 text-xs text-right text-[#666]">PPN 11%</td>
                <td class="px-3 py-2 text-right text-xs text-[#666]">{{ fmtRp(po.tax_amount) }}</td>
              </tr>
              <tr class="border-t border-[#e5e5e5]">
                <td colspan="4" class="px-4 py-3 text-sm font-bold text-right text-[#1a1a1a]">Total</td>
                <td class="px-3 py-3 text-right text-sm font-bold text-[#6b1525]">{{ fmtRp(po.total_amount) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <!-- Info Sidebar -->
      <div class="space-y-4">
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-3 border-b border-[#ebebeb] bg-[#ebebeb]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Detail PO</p>
          </div>
          <div class="p-5 space-y-3 text-xs">
            <div>
              <p class="text-[#999] mb-0.5">Distributor</p>
              <p class="font-semibold text-[#1a1a1a]">{{ supplierName }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">RS Tujuan Pengiriman</p>
              <p class="font-semibold text-[#1a1a1a]">{{ rsName }}</p>
              <p v-if="po.metadata?.rs_address" class="text-[#aaa]">{{ po.metadata.rs_address }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Estimasi Tiba</p>
              <p class="font-semibold text-[#1a1a1a]">{{ fmtDate(po.expected_delivery) }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Termin Pembayaran</p>
              <p class="font-semibold text-[#1a1a1a]">{{ po.payment_terms?.replace('net_', 'Net ') ?? '-' }}</p>
            </div>
            <div v-if="po.notes">
              <p class="text-[#999] mb-0.5">Catatan</p>
              <p class="text-[#555]">{{ po.notes }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Dibuat</p>
              <p class="text-[#555]">{{ fmtDate(po.created_at) }}</p>
            </div>
            <div v-if="po.submitted_at">
              <p class="text-[#999] mb-0.5">Diajukan</p>
              <p class="text-[#555]">{{ fmtDate(po.submitted_at) }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Input Info Penerimaan dari RS -->
    <div v-if="receiveModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">Info Penerimaan dari RS</h3>
          <p class="text-xs text-[#999] mt-0.5">RS <strong>{{ rsName }}</strong> mengirim info barang yang diterima dari {{ supplierName }}</p>
        </div>
        <div class="p-6 space-y-3 max-h-96 overflow-y-auto">
          <div v-for="line in lines" :key="line.id"
            class="flex items-center gap-4 p-3 bg-[#f5f5f5] rounded-xl">
            <div class="flex-1 min-w-0">
              <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ line.item_name }}</p>
              <p class="text-[10px] text-[#999]">Dipesan: {{ line.ordered_qty }} {{ line.uom }}</p>
            </div>
            <div class="flex items-center gap-2">
              <label class="text-[10px] text-[#999]">Terima:</label>
              <input v-model.number="receiveQtys[line.id]" type="number"
                :min="0" :max="line.ordered_qty"
                class="w-16 text-center border border-[#e5e5e5] rounded-lg px-2 py-1.5 text-xs outline-none focus:border-[#6b1525]">
              <span class="text-[10px] text-[#999]">/ {{ line.ordered_qty }}</span>
            </div>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="confirmReceive" :disabled="updating"
            class="flex-1 py-2.5 bg-emerald-600 text-white text-sm font-bold rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors">
            {{ updating ? 'Menyimpan...' : 'Simpan Info Penerimaan RS' }}
          </button>
          <button @click="receiveModal = false"
            class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5] transition-colors">
            Batal
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
