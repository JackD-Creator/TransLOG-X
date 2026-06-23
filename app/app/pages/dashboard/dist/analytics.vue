<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Analytics Distributor' })

const supabase = useSupabaseClient()
const loading = ref(true)

const stats = ref({
  totalPOs: 0, pendingPOs: 0, completedPOs: 0,
  totalRevenue: 0, pendingInvoice: 0,
  topItems: [] as any[],
})

async function load() {
  loading.value = true
  const [{ data: pos }, { data: ar }] = await Promise.all([
    supabase.from('ksm_purchase_orders').select('id, status, total_amount, ksm_po_lines(kfa_code, item_name, ordered_qty, line_total)'),
    supabase.from('ar_accounts').select('id, status, invoice_amount'),
  ])

  const allLines: any[] = (pos ?? []).flatMap((p: any) => p.ksm_po_lines ?? [])
  const itemMap: Record<string, any> = {}
  for (const l of allLines) {
    if (!itemMap[l.kfa_code]) itemMap[l.kfa_code] = { name: l.item_name, qty: 0, revenue: 0 }
    itemMap[l.kfa_code].qty += Number(l.ordered_qty ?? 0)
    itemMap[l.kfa_code].revenue += Number(l.line_total ?? 0)
  }
  const topItems = Object.values(itemMap).sort((a, b) => b.revenue - a.revenue).slice(0, 5)

  stats.value = {
    totalPOs: (pos ?? []).length,
    pendingPOs: (pos ?? []).filter(p => p.status === 'submitted').length,
    completedPOs: (pos ?? []).filter(p => p.status === 'fully_received').length,
    totalRevenue: (ar ?? []).reduce((s, a) => s + Number(a.invoice_amount ?? 0), 0),
    pendingInvoice: (ar ?? []).filter(a => a.status === 'pending').reduce((s, a) => s + Number(a.invoice_amount ?? 0), 0),
    topItems,
  }
  loading.value = false
}

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n / 1e9).toFixed(1)} M`
  if (n >= 1e6) return `Rp ${(n / 1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Analytics Distributor</h1>
      <p class="text-sm text-[#999] mt-0.5">Kinerja penjualan dan fulfillment distributor</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-5">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ stats.totalPOs }}</p>
          <p class="text-xs text-[#999] mt-1">Total PO</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-2xl font-bold text-amber-600">{{ stats.pendingPOs }}</p>
          <p class="text-xs text-[#999] mt-1">PO Pending</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(stats.totalRevenue) }}</p>
          <p class="text-xs text-[#999] mt-1">Total Revenue</p>
        </div>
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-2xl font-bold text-blue-600">{{ fmtRp(stats.pendingInvoice) }}</p>
          <p class="text-xs text-[#999] mt-1">Invoice Belum Cair</p>
        </div>
      </div>

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <h3 class="text-sm font-bold text-[#1a1a1a] mb-4">Top 5 Item Terlaris</h3>
        <div v-if="stats.topItems.length === 0" class="text-sm text-[#999]">Belum ada data</div>
        <div v-else class="space-y-3">
          <div v-for="(item, i) in stats.topItems" :key="i">
            <div class="flex items-center justify-between text-xs mb-1">
              <span class="text-[#666]">{{ item.name }}</span>
              <span class="font-bold text-[#1a1a1a]">{{ fmtRp(item.revenue) }}</span>
            </div>
            <div class="w-full bg-[#e5e5e5] rounded-full h-1.5">
              <div class="bg-[#6b1525] h-1.5 rounded-full"
                :style="`width:${stats.topItems[0].revenue > 0 ? item.revenue / stats.topItems[0].revenue * 100 : 0}%`"/>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
