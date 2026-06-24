<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Fulfillment' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])
const actionLoading = ref<string | null>(null)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,metadata,ksm_po_lines(id,item_name,kfa_code,uom,ordered_qty)')
    .eq('supplier_tenant_id', tenantId.value)
    .eq('status', 'approved')
    .order('expected_delivery', { ascending: true })
    .limit(50)
  orders.value = data ?? []
  loading.value = false
}

async function markReadyToShip(poId: string) {
  actionLoading.value = poId
  await supabase.from('ksm_purchase_orders').update({
    status: 'sent_to_supplier',
    sent_at: new Date().toISOString(),
    metadata: {
      ...orders.value.find(o => o.id === poId)?.metadata,
      fulfillment_status: 'packed',
      packed_at: new Date().toISOString(),
    },
  }).eq('id', poId)
  await load()
  actionLoading.value = null
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Fulfillment — Penyiapan & Pengemasan</h1>
      <p class="text-sm text-[#999] mt-0.5">PO yang sudah dikonfirmasi KSM — siapkan barang, cek QC, kemas, kirim ke RS</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-check" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Tidak ada PO yang perlu disiapkan</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="po in orders" :key="po.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ po.po_number }}</p>
              <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-purple-100 text-purple-700">Siap Dikemas</span>
            </div>
            <p class="text-xs text-[#999]">
              RS: <strong class="text-[#666]">{{ po.metadata?.rs_name ?? '-' }}</strong>
              · {{ (po.ksm_po_lines ?? []).length }} item
              · ETA: {{ fmtDate(po.expected_delivery) }}
            </p>
          </div>
          <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
        </div>

        <!-- Checklist items -->
        <div class="px-5 pb-3">
          <div class="bg-white rounded-lg border border-[#e5e5e5] p-3 mb-3">
            <p class="text-[10px] font-bold text-[#999] uppercase mb-2">Checklist Item</p>
            <div class="space-y-1.5">
              <div v-for="line in po.ksm_po_lines" :key="line.id" class="flex items-center gap-3 text-xs">
                <UIcon name="i-lucide-square" class="text-[#ccc] text-sm flex-shrink-0"/>
                <span class="flex-1 text-[#555]">{{ line.item_name }}</span>
                <span class="font-bold text-[#1a1a1a]">{{ line.ordered_qty }} {{ line.uom }}</span>
              </div>
            </div>
          </div>

          <!-- Workflow steps -->
          <div class="flex items-center gap-2 mb-3 text-[10px]">
            <span class="px-2 py-1 rounded bg-emerald-100 text-emerald-700 font-bold">1. Pick</span>
            <UIcon name="i-lucide-arrow-right" class="text-[#ccc]"/>
            <span class="px-2 py-1 rounded bg-blue-100 text-blue-700 font-bold">2. QC</span>
            <UIcon name="i-lucide-arrow-right" class="text-[#ccc]"/>
            <span class="px-2 py-1 rounded bg-amber-100 text-amber-700 font-bold">3. Pack</span>
            <UIcon name="i-lucide-arrow-right" class="text-[#ccc]"/>
            <span class="px-2 py-1 rounded bg-[#ebebeb] text-[#999] font-bold">4. Kirim</span>
          </div>

          <button @click="markReadyToShip(po.id)" :disabled="actionLoading === po.id"
            class="px-4 py-2 bg-amber-600 text-white text-xs font-bold rounded-lg hover:bg-amber-700 disabled:opacity-50 transition-colors flex items-center gap-2">
            <UIcon name="i-lucide-truck" class="text-sm"/>
            {{ actionLoading === po.id ? 'Memproses...' : 'Selesai Kemas — Siap Kirim ke RS' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
