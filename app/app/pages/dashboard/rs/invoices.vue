<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Invoice & Pembayaran' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const invoices = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('ksm_invoices')
    .select('id,invoice_number,invoice_date,due_date,subtotal,tax_amount,total_amount,paid_amount,outstanding,status,bpjs_amount,bpjs_received_date,shortfall_amount,shortfall_covered_by_bank,contract_payment_days,metadata')
    .eq('rs_tenant_id', tenantId.value)
    .order('invoice_date', { ascending: false })
    .limit(50)
  invoices.value = data ?? []
  loading.value = false
}

const statusLabel: Record<string, { label: string; color: string }> = {
  draft:           { label: 'Draft',              color: 'bg-[#f0f0f0] text-[#999]' },
  reviewed:        { label: 'Direview KSM',       color: 'bg-blue-100 text-blue-700' },
  sent_to_rs:      { label: 'Terkirim ke RS',     color: 'bg-purple-100 text-purple-700' },
  acknowledged_rs: { label: 'RS Acknowledge',      color: 'bg-blue-100 text-blue-700' },
  payment_pending: { label: 'Tunggu BPJS',        color: 'bg-amber-100 text-amber-700' },
  partially_paid:  { label: 'Dibayar Sebagian',   color: 'bg-orange-100 text-orange-700' },
  paid:            { label: 'Lunas',              color: 'bg-emerald-100 text-emerald-700' },
  overdue:         { label: 'Jatuh Tempo',        color: 'bg-red-100 text-red-700' },
}

const totalOutstanding = computed(() => invoices.value.reduce((s, i) => s + Number(i.outstanding ?? 0), 0))
const totalPaid = computed(() => invoices.value.filter(i => i.status === 'paid').reduce((s, i) => s + Number(i.total_amount), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Invoice & Pembayaran</h1>
      <p class="text-sm text-[#999] mt-0.5">Invoice dari KSM — otomatis terbit H+1 setelah barang diterima · Pembayaran via SI bank setelah BPJS cair</p>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Invoice</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ invoices.length }}</p>
      </div>
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Outstanding</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
      </div>
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-4">
        <p class="text-[10px] text-emerald-500 uppercase mb-1">Lunas</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalPaid) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="invoices.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-file-text" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada invoice</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] bg-[#ebebeb]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999]">No. Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Tgl Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Jatuh Tempo</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Total</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">BPJS</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Outstanding</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ inv.invoice_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(inv.invoice_date) }}</td>
            <td class="px-4 py-3">
              <span :class="inv.due_date < new Date().toISOString().slice(0,10) && inv.status !== 'paid' ? 'text-red-600 font-bold' : 'text-[#666]'">
                {{ fmtDate(inv.due_date) }}
              </span>
            </td>
            <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</td>
            <td class="px-4 py-3 text-right">
              <span v-if="inv.bpjs_amount" class="text-blue-700 font-semibold">{{ fmtRp(inv.bpjs_amount) }}</span>
              <span v-else class="text-[#ccc]">—</span>
            </td>
            <td class="px-4 py-3 text-right font-bold" :class="Number(inv.outstanding ?? 0) > 0 ? 'text-amber-700' : 'text-emerald-600'">
              {{ fmtRp(inv.outstanding ?? 0) }}
            </td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', statusLabel[inv.status]?.color ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[inv.status]?.label ?? inv.status }}
              </span>
              <span v-if="inv.shortfall_covered_by_bank" class="ml-1 px-1.5 py-0.5 rounded text-[9px] font-bold bg-red-100 text-red-700">
                Shortfall Bank
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
