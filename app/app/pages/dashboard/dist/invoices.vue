<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Invoice Distributor' })

const supabase = useSupabaseClient()
const loading = ref(true)
const invoices = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('ar_accounts')
    .select('*, tenants:ksm_tenant_id(name)')
    .order('invoice_date', { ascending: false })
    .limit(50)
  invoices.value = data ?? []
  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const totalPaid = computed(() => invoices.value.filter(i => i.status === 'paid').reduce((s, i) => s + Number(i.invoice_amount), 0))
const totalPending = computed(() => invoices.value.filter(i => i.status !== 'paid').reduce((s, i) => s + Number(i.invoice_amount), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Invoice & Penagihan</h1>
      <p class="text-sm text-[#999] mt-0.5">Invoice ke KSM Mitra yang dibayar via fasilitas SCF Bank</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-xs text-[#999] mb-1">Total Invoice</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ invoices.length }}</p>
        <p class="text-xs text-[#999]">semua status</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-xs text-[#999] mb-1">Sudah Dibayar Bank</p>
        <p class="text-2xl font-bold text-emerald-600">{{ fmtRp(totalPaid) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-xs text-[#999] mb-1">Belum Dibayar</p>
        <p class="text-2xl font-bold text-amber-600">{{ fmtRp(totalPending) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="invoices.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-file-text" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada invoice tercatat</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KSM Mitra</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nilai Invoice</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Bayar Bank</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Cair dari Bank</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ inv.invoice_ref ?? inv.ar_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ (inv.tenants as any)?.name ?? '-' }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(inv.invoice_date) }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(inv.invoice_amount) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(inv.disbursement_date) }}</td>
            <td class="px-4 py-3 font-bold text-blue-700">{{ fmtRp(inv.disbursed_amount) }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium',
                inv.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                inv.status === 'disbursed' ? 'bg-blue-100 text-blue-700' :
                inv.status === 'overdue' ? 'bg-red-100 text-red-700' :
                'bg-amber-100 text-amber-700']">
                {{ inv.status === 'paid' ? 'Lunas' : inv.status === 'disbursed' ? 'Cair' : inv.status === 'overdue' ? 'Overdue' : inv.status }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
