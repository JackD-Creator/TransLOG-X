<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Purchase Order Masuk' })

const supabase = useSupabaseClient()
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
}
const statusLabel: Record<string, string> = {
  submitted: 'Baru Masuk', approved: 'Disetujui', sent_to_supplier: 'Diproses',
  partially_received: 'Sebagian Terkirim', fully_received: 'Selesai', cancelled: 'Dibatalkan',
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('*, ksm_po_lines(*), tenants:ksm_tenant_id(name)')
    .in('status', ['submitted', 'approved', 'sent_to_supplier', 'partially_received', 'fully_received'])
    .order('po_date', { ascending: false })
    .limit(50)
  orders.value = data ?? []
  loading.value = false
}

async function approve(id: string) {
  await supabase.from('ksm_purchase_orders').update({ status: 'sent_to_supplier', sent_at: new Date().toISOString() }).eq('id', id)
  await load()
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
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
        <h1 class="text-xl font-bold text-[#1a1a1a]">Purchase Order Masuk</h1>
        <p class="text-sm text-[#999] mt-0.5">PO dari KSM Mitra yang perlu diproses</p>
      </div>
      <div class="flex items-center gap-2 text-xs">
        <span class="px-2 py-1 rounded-full bg-blue-100 text-blue-700 font-medium">{{ orders.filter(o => o.status === 'submitted').length }} Baru</span>
        <span class="px-2 py-1 rounded-full bg-amber-100 text-amber-700 font-medium">{{ orders.filter(o => o.status === 'sent_to_supplier').length }} Diproses</span>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-clipboard-list" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada PO masuk</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No PO</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl PO</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KSM Mitra</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Item</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Total</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">ETA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="po in orders" :key="po.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ po.po_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(po.po_date) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ (po.tenants as any)?.name ?? '-' }}</td>
            <td class="px-4 py-3 font-semibold text-[#1a1a1a]">{{ po.ksm_po_lines?.length ?? 0 }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ po.expected_delivery ? fmtDate(po.expected_delivery) : '-' }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full font-medium', statusColor[po.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[po.status] ?? po.status }}
              </span>
            </td>
            <td class="px-4 py-3">
              <button v-if="po.status === 'submitted'" class="text-[#6b1525] font-semibold hover:text-[#5a1120]" @click="approve(po.id)">
                Proses
              </button>
              <span v-else class="text-[#ccc]">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
