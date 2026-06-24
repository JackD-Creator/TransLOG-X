<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Penerimaan Barang' })

const supabase = useSupabaseClient()
const { apiPost } = useApi()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])
const receiveModal = ref<string | null>(null)
const receiveQtys = ref<Record<string, number>>({})
const actionLoading = ref(false)
const actionError = ref<string | null>(null)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,metadata,ksm_po_lines(id,item_name,kfa_code,uom,ordered_qty,received_qty,unit_price)')
    .eq('rs_tenant_id', tenantId.value)
    .in('status', ['sent_to_supplier', 'partially_received'])
    .order('expected_delivery', { ascending: true })
  orders.value = data ?? []
  loading.value = false
}

function openReceive(po: any) {
  receiveModal.value = po.id
  receiveQtys.value = {}
  for (const l of po.ksm_po_lines ?? []) {
    receiveQtys.value[l.id] = l.ordered_qty
  }
}

async function confirmReceipt(poId: string) {
  actionLoading.value = true
  actionError.value = null
  try {
    const po = orders.value.find(o => o.id === poId)
    const items = (po?.ksm_po_lines ?? []).map((l: any) => ({
      line_id: l.id,
      received_qty: receiveQtys.value[l.id] ?? 0,
    }))
    await apiPost('/api/rs/receiving', { po_id: poId, received_items: items })
    receiveModal.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal konfirmasi penerimaan'
  }
  actionLoading.value = false
}

const today = new Date().toISOString().slice(0, 10)

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Penerimaan Barang dari Distributor</h1>
      <p class="text-sm text-[#999] mt-0.5">Konfirmasi barang yang diterima dari distributor atas pesanan KSM — cek kesesuaian item & jumlah</p>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-check" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Tidak ada pengiriman yang perlu dikonfirmasi</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="po in orders" :key="po.id"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ po.po_number }}</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                po.status === 'sent_to_supplier' ? 'bg-amber-100 text-amber-700' : 'bg-orange-100 text-orange-700']">
                {{ po.status === 'sent_to_supplier' ? 'Dalam Pengiriman' : 'Diterima Sebagian' }}
              </span>
            </div>
            <p class="text-xs text-[#999]">
              Dari {{ po.metadata?.supplier_name ?? 'Distributor' }}
              · {{ (po.ksm_po_lines ?? []).length }} item
              · {{ fmtRp(po.total_amount) }}
            </p>
            <p v-if="po.metadata?.tracking_number" class="text-xs text-amber-700 mt-1 font-mono">
              Resi: {{ po.metadata.tracking_number }} {{ po.metadata?.courier ? '· ' + po.metadata.courier : '' }}
            </p>
            <p :class="['text-[10px] mt-1', po.expected_delivery && po.expected_delivery < today ? 'text-red-600 font-semibold' : 'text-[#777]']">
              ETA: {{ fmtDate(po.expected_delivery) }}
              {{ po.expected_delivery && po.expected_delivery < today ? '(Terlambat)' : '' }}
            </p>
          </div>
          <button @click="openReceive(po)"
            class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 transition-colors flex items-center gap-2">
            <UIcon name="i-lucide-package-check" class="text-sm"/>
            Konfirmasi Terima
          </button>
        </div>

        <!-- Item summary -->
        <div class="px-5 pb-4">
          <div class="flex flex-wrap gap-1.5">
            <span v-for="l in po.ksm_po_lines" :key="l.id"
              :class="['px-2 py-1 rounded text-[10px] font-medium',
                l.received_qty >= l.ordered_qty ? 'bg-emerald-100 text-emerald-700' :
                l.received_qty > 0 ? 'bg-amber-100 text-amber-700' : 'bg-[#ebebeb] text-[#666]']">
              {{ l.item_name?.split(' ').slice(0, 3).join(' ') }} · {{ l.received_qty }}/{{ l.ordered_qty }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal konfirmasi penerimaan -->
    <div v-if="receiveModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">Konfirmasi Penerimaan Barang</h3>
          <p class="text-xs text-[#999] mt-0.5">Masukkan jumlah item yang diterima dengan benar dari distributor</p>
        </div>
        <div class="p-6 space-y-3 max-h-96 overflow-y-auto">
          <div v-for="line in (orders.find(o => o.id === receiveModal)?.ksm_po_lines ?? [])" :key="line.id"
            class="flex items-center gap-4 p-3 bg-[#f5f5f5] rounded-xl">
            <div class="flex-1 min-w-0">
              <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ line.item_name }}</p>
              <p class="text-[10px] text-[#999]">Dipesan: {{ line.ordered_qty }} {{ line.uom }} · {{ fmtRp(line.unit_price) }}/{{ line.uom }}</p>
            </div>
            <div class="flex items-center gap-2">
              <label class="text-[10px] text-[#999]">Diterima:</label>
              <input v-model.number="receiveQtys[line.id]" type="number"
                :min="0" :max="line.ordered_qty"
                class="w-16 text-center border border-[#e5e5e5] rounded-lg px-2 py-1.5 text-xs outline-none focus:border-[#6b1525]">
              <span class="text-[10px] text-[#999]">/ {{ line.ordered_qty }}</span>
            </div>
          </div>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="confirmReceipt(receiveModal!)" :disabled="actionLoading"
            class="flex-1 py-2.5 bg-emerald-600 text-white text-sm font-bold rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors">
            {{ actionLoading ? 'Menyimpan...' : 'Konfirmasi Barang Diterima' }}
          </button>
          <button @click="receiveModal = null"
            class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5] transition-colors">
            Batal
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
