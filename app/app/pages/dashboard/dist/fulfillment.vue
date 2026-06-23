<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pemenuhan Order' })

const supabase = useSupabaseClient()
const loading = ref(true)
const orders = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('*, ksm_po_lines(*), tenants:ksm_tenant_id(name)')
    .in('status', ['sent_to_supplier', 'partially_received'])
    .order('po_date', { ascending: true })
    .limit(30)
  orders.value = data ?? []
  loading.value = false
}

async function markShipped(id: string) {
  await supabase.from('ksm_purchase_orders').update({ status: 'partially_received' }).eq('id', id)
  await load()
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pemenuhan Order</h1>
      <p class="text-sm text-[#999] mt-0.5">PO yang sedang disiapkan dan dikemas untuk pengiriman</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-check" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada order dalam proses pemenuhan</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="po in orders" :key="po.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="flex items-center justify-between px-5 py-4 border-b border-[#e5e5e5]">
          <div>
            <p class="text-sm font-bold text-[#1a1a1a] font-mono">{{ po.po_number }}</p>
            <p class="text-xs text-[#999]">{{ (po.tenants as any)?.name ?? '-' }} · ETA: {{ fmtDate(po.expected_delivery) }}</p>
          </div>
          <div class="flex items-center gap-3">
            <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            <button v-if="po.status === 'sent_to_supplier'"
              class="px-3 py-1.5 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors"
              @click="markShipped(po.id)">
              Tandai Terkirim
            </button>
            <span v-else class="px-2 py-1 rounded-full bg-orange-100 text-orange-700 text-xs font-medium">Sebagian Terkirim</span>
          </div>
        </div>

        <div class="px-5 py-3">
          <div class="grid grid-cols-3 md:grid-cols-4 gap-2">
            <div v-for="line in po.ksm_po_lines" :key="line.id"
              class="bg-[#ebebeb] rounded-lg p-2.5 text-xs">
              <p class="font-medium text-[#1a1a1a] truncate">{{ line.item_name }}</p>
              <p class="text-[#999]">{{ line.ordered_qty }} {{ line.uom }} · {{ fmtRp(line.line_total) }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
