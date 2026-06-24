<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pengiriman ke RS' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])
const trackingModal = ref<any>(null)
const trackForm = ref({ tracking_number: '', courier: '', notes: '' })
const actionLoading = ref(false)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,metadata,ksm_po_lines(id,item_name,ordered_qty,received_qty,uom)')
    .eq('supplier_tenant_id', tenantId.value)
    .in('status', ['sent_to_supplier', 'partially_received', 'fully_received'])
    .order('sent_at', { ascending: false })
    .limit(50)
  orders.value = data ?? []
  loading.value = false
}

function openTracking(po: any) {
  trackingModal.value = po
  trackForm.value = {
    tracking_number: po.metadata?.tracking_number ?? '',
    courier: po.metadata?.courier ?? '',
    notes: '',
  }
}

async function saveTracking() {
  if (!trackingModal.value) return
  actionLoading.value = true
  await supabase.from('ksm_purchase_orders').update({
    metadata: {
      ...trackingModal.value.metadata,
      tracking_number: trackForm.value.tracking_number,
      courier: trackForm.value.courier,
      tracking_updated_at: new Date().toISOString(),
    },
  }).eq('id', trackingModal.value.id)
  trackingModal.value = null
  await load()
  actionLoading.value = false
}

function receivedPct(po: any) {
  const lines = po.ksm_po_lines ?? []
  const total = lines.reduce((s: number, l: any) => s + l.ordered_qty, 0)
  const recv = lines.reduce((s: number, l: any) => s + (l.received_qty ?? 0), 0)
  return total > 0 ? Math.round(recv / total * 100) : 0
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pengiriman ke RS</h1>
      <p class="text-sm text-[#999] mt-0.5">Track pengiriman langsung ke RS — input resi, pantau status penerimaan</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-truck" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada pengiriman aktif</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="po in orders" :key="po.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ po.po_number }}</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                po.status === 'fully_received' ? 'bg-emerald-100 text-emerald-700' :
                po.status === 'partially_received' ? 'bg-orange-100 text-orange-700' :
                'bg-amber-100 text-amber-700']">
                {{ po.status === 'fully_received' ? 'RS Terima Lengkap' :
                   po.status === 'partially_received' ? 'RS Terima Sebagian' : 'Dalam Pengiriman' }}
              </span>
            </div>
            <p class="text-xs text-[#999]">
              RS: <strong class="text-[#666]">{{ po.metadata?.rs_name ?? '-' }}</strong>
              · {{ (po.ksm_po_lines ?? []).length }} item
            </p>
            <div v-if="po.metadata?.tracking_number" class="mt-1 flex items-center gap-2 text-xs">
              <UIcon name="i-lucide-map-pin" class="text-amber-500 text-xs"/>
              <span class="font-mono font-semibold text-amber-700">{{ po.metadata.tracking_number }}</span>
              <span v-if="po.metadata?.courier" class="text-[#999]">· {{ po.metadata.courier }}</span>
            </div>
          </div>
          <div class="text-right">
            <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            <p class="text-[10px] text-[#999]">RS terima: {{ receivedPct(po) }}%</p>
          </div>
        </div>

        <div class="px-5 pb-4 flex items-center gap-3">
          <div class="flex-1 bg-[#e5e5e5] rounded-full h-2">
            <div :class="['h-2 rounded-full transition-all',
              receivedPct(po) === 100 ? 'bg-emerald-500' : receivedPct(po) > 0 ? 'bg-amber-500' : 'bg-blue-400']"
              :style="`width: ${Math.max(10, receivedPct(po))}%`"/>
          </div>
          <button v-if="po.status === 'sent_to_supplier'" @click="openTracking(po)"
            class="px-3 py-1.5 text-xs font-semibold border border-amber-300 text-amber-700 rounded-lg hover:bg-amber-50 transition-colors flex items-center gap-1.5">
            <UIcon name="i-lucide-edit-3" class="text-xs"/>
            {{ po.metadata?.tracking_number ? 'Update Resi' : 'Input Resi' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Modal tracking -->
    <div v-if="trackingModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-md overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">Input Info Pengiriman</h3>
          <p class="text-xs text-[#999] mt-0.5">{{ trackingModal.po_number }} → {{ trackingModal.metadata?.rs_name ?? 'RS' }}</p>
        </div>
        <div class="p-6 space-y-3">
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">No. Resi</label>
            <input v-model="trackForm.tracking_number" type="text" placeholder="JNE1234567890"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Kurir / Ekspedisi</label>
            <input v-model="trackForm.courier" type="text" placeholder="JNE, SiCepat, Anteraja..."
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="saveTracking" :disabled="actionLoading"
            class="flex-1 py-2.5 bg-amber-600 text-white text-sm font-bold rounded-xl hover:bg-amber-700 disabled:opacity-50 transition-colors">
            {{ actionLoading ? 'Menyimpan...' : 'Simpan Info Pengiriman' }}
          </button>
          <button @click="trackingModal = null" class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5]">Batal</button>
        </div>
      </div>
    </div>
  </div>
</template>
