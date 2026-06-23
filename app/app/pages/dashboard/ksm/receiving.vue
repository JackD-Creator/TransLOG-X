<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Penerimaan Barang' })

const supabase = useSupabaseClient()

const loading = ref(true)
const orders = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ksm_purchase_orders')
    .select('*, ksm_po_lines(*), tenants:supplier_tenant_id(name)')
    .in('status', ['sent_to_supplier', 'partially_received'])
    .order('expected_delivery', { ascending: true })
    .limit(50)
  orders.value = data ?? []
  loading.value = false
}

async function receiveAll(poId: string) {
  await supabase.from('ksm_purchase_orders').update({ status: 'fully_received' }).eq('id', poId)
  await load()
}

function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}
function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

const today = new Date().toISOString().slice(0, 10)
function isOverdue(d: string | null) { return d && d < today }

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Penerimaan Barang</h1>
      <p class="text-sm text-[#999] mt-0.5">PO yang sedang dalam proses penerimaan dari distributor</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-check" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada barang dalam proses penerimaan</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="po in orders" :key="po.id"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="flex items-center justify-between px-5 py-4 border-b border-[#e5e5e5]">
          <div class="flex items-center gap-4">
            <div>
              <p class="text-sm font-bold text-[#1a1a1a] font-mono">{{ po.po_number }}</p>
              <p class="text-xs text-[#999]">{{ (po.tenants as any)?.name ?? '-' }}</p>
            </div>
            <span :class="['px-2 py-0.5 rounded-full text-xs font-medium',
              po.status === 'partially_received' ? 'bg-orange-100 text-orange-700' : 'bg-amber-100 text-amber-700']">
              {{ po.status === 'partially_received' ? 'Sebagian Diterima' : 'Menunggu' }}
            </span>
          </div>
          <div class="text-right">
            <p :class="['text-xs font-medium', isOverdue(po.expected_delivery) ? 'text-red-600' : 'text-[#999]']">
              ETA: {{ fmtDate(po.expected_delivery) }}
              <span v-if="isOverdue(po.expected_delivery)" class="ml-1">(Terlambat)</span>
            </p>
            <p class="text-xs text-[#999]">Total: {{ fmtRp(po.total_amount) }}</p>
          </div>
        </div>

        <div class="px-5 py-3">
          <table class="w-full text-xs">
            <thead>
              <tr class="text-left border-b border-[#e5e5e5]">
                <th class="pb-2 font-semibold text-[#999]">Item</th>
                <th class="pb-2 font-semibold text-[#999]">Dipesan</th>
                <th class="pb-2 font-semibold text-[#999]">Diterima</th>
                <th class="pb-2 font-semibold text-[#999]">Progress</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="line in po.ksm_po_lines" :key="line.id" class="py-2">
                <td class="py-2 text-[#1a1a1a]">{{ line.item_name }}</td>
                <td class="py-2 text-[#666]">{{ line.ordered_qty }} {{ line.uom }}</td>
                <td class="py-2 text-[#666]">{{ line.received_qty }} {{ line.uom }}</td>
                <td class="py-2">
                  <div class="w-full bg-[#e5e5e5] rounded-full h-1.5 w-24">
                    <div class="bg-[#6b1525] h-1.5 rounded-full transition-all"
                      :style="`width:${Math.min(100, Math.round(line.received_qty / line.ordered_qty * 100))}%`"/>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="px-5 py-3 border-t border-[#e5e5e5] flex justify-end">
          <button class="px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors"
            @click="receiveAll(po.id)">
            Konfirmasi Terima Semua
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
