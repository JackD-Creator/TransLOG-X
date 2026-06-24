<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Purchase Order Masuk' })

const supabase = useSupabaseClient()
const { apiPost } = useApi()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])
const filterStatus = ref('pending')
const confirmModal = ref<any>(null)
const shipModal = ref<any>(null)

// Confirm form state
const confirmForm = ref({
  estimated_arrival: '',
  tracking_number: '',
  courier: '',
  notes: '',
  lineAdjustments: [] as { line_id: string; item_name: string; ordered_qty: number; adjusted_qty: number; adjusted_price: number; note: string }[],
})

// Ship form state
const shipForm = ref({ tracking_number: '', courier: '', notes: '' })

const actionLoading = ref(false)
const actionError = ref<string | null>(null)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  let query = supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,subtotal,payment_terms,notes,metadata,ksm_po_lines(id,item_name,kfa_code,uom,ordered_qty,received_qty,unit_price,line_total)')
    .eq('supplier_tenant_id', tenantId.value)
    .order('po_date', { ascending: false })
    .limit(50)

  if (filterStatus.value === 'pending') {
    query = query.eq('status', 'submitted')
  } else if (filterStatus.value === 'confirmed') {
    query = query.in('status', ['approved', 'sent_to_supplier'])
  } else if (filterStatus.value === 'done') {
    query = query.in('status', ['partially_received', 'fully_received'])
  }

  const { data } = await query
  orders.value = data ?? []
  loading.value = false
}

function openConfirmModal(po: any) {
  confirmModal.value = po
  const eta = new Date()
  eta.setDate(eta.getDate() + 5)
  confirmForm.value = {
    estimated_arrival: eta.toISOString().slice(0, 10),
    tracking_number: '',
    courier: '',
    notes: '',
    lineAdjustments: (po.ksm_po_lines ?? []).map((l: any) => ({
      line_id: l.id,
      item_name: l.item_name,
      ordered_qty: l.ordered_qty,
      adjusted_qty: l.ordered_qty,
      adjusted_price: l.unit_price,
      note: '',
    })),
  }
}

async function submitConfirmation() {
  if (!confirmModal.value) return
  actionLoading.value = true
  actionError.value = null
  try {
    const hasAdjustments = confirmForm.value.lineAdjustments.some(
      (l, i) => l.adjusted_qty !== (confirmModal.value.ksm_po_lines[i]?.ordered_qty) ||
                l.adjusted_price !== (confirmModal.value.ksm_po_lines[i]?.unit_price)
    )
    const confirmation: Record<string, any> = {
      estimated_arrival: confirmForm.value.estimated_arrival,
      tracking_number: confirmForm.value.tracking_number,
      courier: confirmForm.value.courier,
      notes: confirmForm.value.notes,
    }
    if (hasAdjustments) {
      confirmation.line_adjustments = confirmForm.value.lineAdjustments.map(l => ({
        line_id: l.line_id,
        adjusted_qty: l.adjusted_qty,
        adjusted_price: l.adjusted_price,
        note: l.note,
      }))
    }
    await apiPost('/api/dist/confirm-po', {
      po_id: confirmModal.value.id,
      confirmation,
    })
    confirmModal.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal konfirmasi PO'
  }
  actionLoading.value = false
}

function openShipModal(po: any) {
  shipModal.value = po
  shipForm.value = {
    tracking_number: po.metadata?.tracking_number ?? '',
    courier: po.metadata?.courier ?? '',
    notes: '',
  }
}

async function submitShipment() {
  if (!shipModal.value) return
  actionLoading.value = true
  actionError.value = null
  try {
    const { error } = await supabase.from('ksm_purchase_orders').update({
      status: 'sent_to_supplier',
      sent_at: new Date().toISOString(),
      metadata: {
        ...shipModal.value.metadata,
        tracking_number: shipForm.value.tracking_number,
        courier: shipForm.value.courier,
        shipped_at: new Date().toISOString(),
        ship_notes: shipForm.value.notes,
      },
    }).eq('id', shipModal.value.id)
    if (error) throw error
    shipModal.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal update pengiriman'
  }
  actionLoading.value = false
}

watch(tenantId, (id) => { if (id) load() })
watch(filterStatus, load)
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Purchase Order Masuk</h1>
      <p class="text-sm text-[#999] mt-0.5">PO dari KSM — konfirmasi harga, jumlah & jadwal kirim, lalu proses pengiriman ke RS</p>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <!-- Filter -->
    <div class="flex gap-2">
      <button v-for="f in [{key:'pending',label:'Perlu Konfirmasi'},{key:'confirmed',label:'Dikonfirmasi'},{key:'done',label:'Selesai'},{key:'all',label:'Semua'}]"
        :key="f.key" @click="filterStatus = f.key"
        :class="['px-4 py-2 rounded-lg text-xs font-semibold transition-colors',
          filterStatus === f.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ f.label }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-inbox" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada PO</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="po in orders" :key="po.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ po.po_number }}</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                po.status === 'submitted' ? 'bg-blue-100 text-blue-700' :
                po.status === 'approved' ? 'bg-purple-100 text-purple-700' :
                po.status === 'sent_to_supplier' ? 'bg-amber-100 text-amber-700' :
                'bg-emerald-100 text-emerald-700']">
                {{ po.status === 'submitted' ? 'Perlu Konfirmasi' :
                   po.status === 'approved' ? 'Dikonfirmasi — Siap Kirim' :
                   po.status === 'sent_to_supplier' ? 'Dalam Pengiriman' : 'Diterima RS' }}
              </span>
              <span v-if="po.metadata?.correction_requested" class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-red-100 text-red-700">
                KSM Minta Revisi
              </span>
            </div>
            <p class="text-xs text-[#999]">
              RS Tujuan: <strong class="text-[#1a1a1a]">{{ po.metadata?.rs_name ?? '-' }}</strong>
              · {{ (po.ksm_po_lines ?? []).length }} item · {{ po.payment_terms?.replace('net_','Net ') }}
            </p>
            <p v-if="po.metadata?.correction_reason" class="text-xs text-red-600 mt-1">
              Revisi: {{ po.metadata.correction_reason }}
            </p>
          </div>
          <div class="text-right">
            <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            <p class="text-[10px] text-[#999]">{{ fmtDate(po.po_date) }}</p>
          </div>
        </div>

        <!-- Items preview -->
        <div class="px-5 pb-3">
          <div class="flex flex-wrap gap-1.5 mb-3">
            <span v-for="l in (po.ksm_po_lines ?? []).slice(0, 5)" :key="l.id"
              class="px-2 py-0.5 rounded text-[10px] bg-[#ebebeb] text-[#666]">
              {{ l.item_name?.split(' ').slice(0, 3).join(' ') }} × {{ l.ordered_qty }}
            </span>
            <span v-if="(po.ksm_po_lines ?? []).length > 5" class="text-[10px] text-[#999]">
              +{{ (po.ksm_po_lines ?? []).length - 5 }} lainnya
            </span>
          </div>

          <!-- Action buttons -->
          <div class="flex gap-2">
            <button v-if="po.status === 'submitted'" @click="openConfirmModal(po)"
              class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] transition-colors flex items-center gap-2">
              <UIcon name="i-lucide-check-circle" class="text-sm"/>
              Konfirmasi PO
            </button>
            <button v-if="po.status === 'approved'" @click="openShipModal(po)"
              class="px-4 py-2 bg-amber-600 text-white text-xs font-bold rounded-lg hover:bg-amber-700 transition-colors flex items-center gap-2">
              <UIcon name="i-lucide-truck" class="text-sm"/>
              Input Pengiriman
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Konfirmasi PO -->
    <div v-if="confirmModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-2xl overflow-hidden shadow-2xl max-h-[90vh] flex flex-col">
        <div class="px-6 py-4 border-b border-[#f0f0f0] flex-shrink-0">
          <h3 class="font-bold text-[#1a1a1a]">Konfirmasi PO {{ confirmModal.po_number }}</h3>
          <p class="text-xs text-[#999] mt-0.5">Konfirmasi detail item, harga, jumlah, dan jadwal pengiriman ke RS</p>
        </div>

        <div class="p-6 space-y-4 overflow-y-auto flex-1">
          <!-- Jadwal & info pengiriman -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Estimasi Tiba di RS</label>
              <input v-model="confirmForm.estimated_arrival" type="date"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Kurir / Ekspedisi</label>
              <input v-model="confirmForm.courier" type="text" placeholder="JNE, SiCepat, dll"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
          </div>
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">No. Resi (opsional — bisa diisi nanti)</label>
            <input v-model="confirmForm.tracking_number" type="text" placeholder="Nomor resi pengiriman"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>

          <!-- Item lines — editable -->
          <div>
            <p class="text-[10px] text-[#999] uppercase font-semibold mb-2">Detail Item (sesuaikan jika perlu)</p>
            <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
              <table class="w-full text-xs">
                <thead class="bg-[#ebebeb] border-b border-[#e5e5e5]">
                  <tr>
                    <th class="px-3 py-2.5 text-left font-semibold text-[#999]">Item</th>
                    <th class="px-3 py-2.5 text-center font-semibold text-[#999]">Qty Order</th>
                    <th class="px-3 py-2.5 text-center font-semibold text-[#999]">Qty Konfirmasi</th>
                    <th class="px-3 py-2.5 text-right font-semibold text-[#999]">Harga/Unit</th>
                    <th class="px-3 py-2.5 text-right font-semibold text-[#999]">Total</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-[#e5e5e5]">
                  <tr v-for="adj in confirmForm.lineAdjustments" :key="adj.line_id">
                    <td class="px-3 py-2.5 font-semibold text-[#1a1a1a]">{{ adj.item_name }}</td>
                    <td class="px-3 py-2.5 text-center text-[#999]">{{ adj.ordered_qty }}</td>
                    <td class="px-3 py-2.5 text-center">
                      <input v-model.number="adj.adjusted_qty" type="number" min="0"
                        class="w-16 text-center border border-[#e5e5e5] rounded px-1 py-1 text-xs outline-none focus:border-[#6b1525]">
                    </td>
                    <td class="px-3 py-2.5 text-right">
                      <input v-model.number="adj.adjusted_price" type="number" min="0"
                        class="w-24 text-right border border-[#e5e5e5] rounded px-1 py-1 text-xs outline-none focus:border-[#6b1525]">
                    </td>
                    <td class="px-3 py-2.5 text-right font-bold text-[#1a1a1a]">
                      {{ fmtRp(adj.adjusted_qty * adj.adjusted_price) }}
                    </td>
                  </tr>
                </tbody>
                <tfoot class="bg-[#ebebeb] border-t border-[#e5e5e5]">
                  <tr>
                    <td colspan="4" class="px-3 py-2.5 text-right font-bold text-[#666]">Total Konfirmasi</td>
                    <td class="px-3 py-2.5 text-right font-bold text-[#6b1525]">
                      {{ fmtRp(confirmForm.lineAdjustments.reduce((s, l) => s + l.adjusted_qty * l.adjusted_price, 0)) }}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </div>

          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Catatan (opsional)</label>
            <textarea v-model="confirmForm.notes" rows="2" placeholder="Catatan untuk KSM..."
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525] resize-none"/>
          </div>
        </div>

        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3 flex-shrink-0">
          <button @click="submitConfirmation" :disabled="actionLoading"
            class="flex-1 py-2.5 bg-[#6b1525] text-white text-sm font-bold rounded-xl hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
            {{ actionLoading ? 'Memproses...' : 'Konfirmasi & Kirim ke KSM' }}
          </button>
          <button @click="confirmModal = null"
            class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5] transition-colors">
            Batal
          </button>
        </div>
      </div>
    </div>

    <!-- Modal Input Pengiriman -->
    <div v-if="shipModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">Kirim ke RS — {{ shipModal.po_number }}</h3>
          <p class="text-xs text-[#999] mt-0.5">Input info pengiriman langsung ke {{ shipModal.metadata?.rs_name ?? 'RS' }}</p>
        </div>
        <div class="p-6 space-y-3">
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">No. Resi Pengiriman</label>
            <input v-model="shipForm.tracking_number" type="text" placeholder="JNE1234567890"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Kurir</label>
            <input v-model="shipForm.courier" type="text" placeholder="JNE, SiCepat, Anteraja..."
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Catatan</label>
            <textarea v-model="shipForm.notes" rows="2"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525] resize-none"/>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="submitShipment" :disabled="actionLoading"
            class="flex-1 py-2.5 bg-amber-600 text-white text-sm font-bold rounded-xl hover:bg-amber-700 disabled:opacity-50 transition-colors">
            {{ actionLoading ? 'Memproses...' : 'Tandai Terkirim ke RS' }}
          </button>
          <button @click="shipModal = null"
            class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5] transition-colors">
            Batal
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
