<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Purchase Order KSM' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])

const statusColor: Record<string, string> = {
  draft:             'bg-[#f0f0f0] text-[#999]',
  submitted:         'bg-blue-100 text-blue-700',
  approved:          'bg-purple-100 text-purple-700',
  sent_to_supplier:  'bg-amber-100 text-amber-700',
  partially_received:'bg-orange-100 text-orange-700',
  fully_received:    'bg-emerald-100 text-emerald-700',
  cancelled:         'bg-red-100 text-red-700',
  closed:            'bg-[#f0f0f0] text-[#666]',
}
const statusLabel: Record<string, string> = {
  draft: 'Draft', submitted: 'Diajukan', approved: 'Disetujui',
  sent_to_supplier: 'Terkirim', partially_received: 'Diterima Sebagian',
  fully_received: 'Diterima Penuh', cancelled: 'Dibatalkan', closed: 'Ditutup',
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,payment_terms,metadata,ksm_po_lines(id,item_name,ordered_qty,received_qty)')
    .eq('ksm_tenant_id', tenantId.value)
    .order('po_date', { ascending: false })
    .limit(50)
  orders.value = data ?? []
  loading.value = false
}

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Purchase Order ke Distributor</h1>
        <p class="text-sm text-[#999] mt-0.5">Kelola PO pengadaan ke distributor / supplier</p>
      </div>
      <NuxtLink to="/dashboard/ksm/purchase-orders/new"
        class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors">
        <UIcon name="i-lucide-plus" class="text-sm"/>
        Buat PO Baru
      </NuxtLink>
    </div>

    <!-- Stats row -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ orders.filter(o => o.status === 'draft').length }}</p>
        <p class="text-xs text-[#999] mt-1">Draft</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-amber-600">{{ orders.filter(o => o.status === 'sent_to_supplier').length }}</p>
        <p class="text-xs text-[#999] mt-1">Terkirim ke Supplier</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-orange-600">{{ orders.filter(o => o.status === 'partially_received').length }}</p>
        <p class="text-xs text-[#999] mt-1">Diterima Sebagian</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-emerald-600">{{ orders.filter(o => o.status === 'fully_received').length }}</p>
        <p class="text-xs text-[#999] mt-1">Selesai</p>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div v-if="loading" class="flex items-center justify-center py-16">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>
      <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-shopping-cart" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada PO. Klik "Buat PO Baru" untuk memulai.</p>
      </div>
      <table v-else class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No PO</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tanggal</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Distributor</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Item</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Termin</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="po in orders" :key="po.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ po.po_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(po.po_date) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ po.metadata?.supplier_name ?? '-' }}</td>
            <td class="px-4 py-3 font-semibold text-[#1a1a1a]">{{ po.ksm_po_lines?.length ?? 0 }} item</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full font-medium', statusColor[po.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[po.status] ?? po.status }}
              </span>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ po.payment_terms?.replace('net_', 'Net ') ?? '-' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
