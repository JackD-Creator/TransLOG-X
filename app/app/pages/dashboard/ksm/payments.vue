<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Rekonsiliasi Pembayaran' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const arList = ref<any[]>([])
const poList = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const [{ data: ar }, { data: po }] = await Promise.all([
    supabase
      .from('ar_accounts')
      .select('id,ar_number,po_number,invoice_amount,disbursed_amount,interest_amount,total_payable,paid_amount,outstanding_amount,invoice_date,disbursement_date,due_date,paid_date,status')
      .eq('ksm_tenant_id', tenantId.value)
      .order('disbursement_date', { ascending: false })
      .limit(50),
    supabase
      .from('ksm_purchase_orders')
      .select('id,po_number,po_date,status,total_amount,payment_terms,metadata')
      .eq('ksm_tenant_id', tenantId.value)
      .in('status', ['fully_received', 'partially_received'])
      .order('po_date', { ascending: false })
      .limit(30),
  ])
  arList.value = ar ?? []
  poList.value = po ?? []
  loading.value = false
}

function fmtRp(n: number | null) {
  if (!n) return 'Rp 0'
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(2)}M`
  if (n >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return 'Rp ' + Math.round(n).toLocaleString('id-ID')
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

// Summary
const totalDisbursed = computed(() => arList.value.reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0))
const totalInterest  = computed(() => arList.value.reduce((s, a) => s + Number(a.interest_amount ?? 0), 0))
const totalPaid      = computed(() => arList.value.filter(a => a.status === 'paid').reduce((s, a) => s + Number(a.total_payable ?? 0), 0))
const totalOutstanding = computed(() => arList.value.filter(a => a.status !== 'paid').reduce((s, a) => s + Number(a.outstanding_amount ?? 0), 0))

// PO yang butuh invoice ke RS (fully_received tapi belum ada AR)
const poNeedInvoice = computed(() => {
  const arPOs = new Set(arList.value.map(a => a.po_number))
  return poList.value.filter(p => !arPOs.has(p.po_number))
})

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Rekonsiliasi Pembayaran</h1>
        <p class="text-sm text-[#999] mt-0.5">Pencairan Bank ke Distributor & pelunasan KSM ke Bank</p>
      </div>
      <NuxtLink to="/dashboard/ksm/finance" class="text-xs text-[#6b1525] hover:underline flex items-center gap-1">
        <UIcon name="i-lucide-arrow-left" class="text-xs"/>
        Kembali ke Finance
      </NuxtLink>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Cair ke Dist.</p>
        <p class="text-xl font-bold text-blue-700">{{ fmtRp(totalDisbursed) }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">Bank bayar ke Distributor</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Bunga SCF</p>
        <p class="text-xl font-bold text-red-600">{{ fmtRp(totalInterest) }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">Beban bunga ke Bank</p>
      </div>
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-4">
        <p class="text-[10px] text-emerald-600 uppercase mb-1">Sudah Dilunasi</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalPaid) }}</p>
        <p class="text-[10px] text-emerald-500 mt-1">{{ arList.filter(a => a.status === 'paid').length }} transaksi lunas</p>
      </div>
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Outstanding ke Bank</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
        <p class="text-[10px] text-amber-500 mt-1">{{ arList.filter(a => a.status !== 'paid').length }} belum lunas</p>
      </div>
    </div>

    <!-- PO yang butuh dibuatkan invoice ke RS -->
    <div v-if="poNeedInvoice.length > 0" class="bg-amber-50 border border-amber-200 rounded-xl p-4">
      <div class="flex items-start gap-3">
        <UIcon name="i-lucide-alert-circle" class="text-amber-500 text-base mt-0.5 flex-shrink-0"/>
        <div>
          <p class="text-xs font-bold text-amber-700">{{ poNeedInvoice.length }} PO butuh Invoice ke RS</p>
          <p class="text-[10px] text-amber-600 mt-0.5">PO berikut sudah diterima RS namun belum dibuatkan tagihan (invoice ke RS)</p>
          <div class="mt-2 flex flex-wrap gap-2">
            <NuxtLink v-for="p in poNeedInvoice" :key="p.id"
              :to="`/dashboard/ksm/purchase-orders/${p.id}`"
              class="px-2 py-1 bg-white border border-amber-300 rounded text-[10px] font-mono text-amber-700 hover:border-amber-500 transition-colors">
              {{ p.po_number }}
            </NuxtLink>
          </div>
        </div>
      </div>
    </div>

    <!-- Payment Reconciliation Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Riwayat Transaksi Pembayaran SCF</p>
        <p class="text-[10px] text-[#aaa] mt-0.5">Alur: KSM buat PO → Bank cair ke Dist. → RS bayar KSM → KSM lunasi Bank</p>
      </div>

      <div v-if="loading" class="flex items-center justify-center py-16">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>
      <div v-else-if="arList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-banknote" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada data pembayaran SCF</p>
      </div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs min-w-[1000px]">
          <thead class="border-b border-[#e5e5e5]">
            <tr class="text-left">
              <th class="px-4 py-3 font-semibold text-[#999]">No AR</th>
              <th class="px-4 py-3 font-semibold text-[#999]">Ref PO</th>
              <th class="px-4 py-3 font-semibold text-[#999]">Tgl Cair</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Cair ke Dist.</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Bunga</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Total ke Bank</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Sudah Dibayar</th>
              <th class="px-4 py-3 font-semibold text-[#999] text-right">Outstanding</th>
              <th class="px-4 py-3 font-semibold text-[#999]">JT</th>
              <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</td>
              <td class="px-4 py-3 font-mono text-[#666]">{{ ar.po_number ?? '-' }}</td>
              <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.disbursement_date) }}</td>
              <td class="px-4 py-3 text-right font-bold text-blue-700">{{ fmtRp(ar.disbursed_amount) }}</td>
              <td class="px-4 py-3 text-right text-red-500">{{ fmtRp(ar.interest_amount) }}</td>
              <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
              <td class="px-4 py-3 text-right text-emerald-600 font-bold">{{ fmtRp(ar.paid_amount) }}</td>
              <td class="px-4 py-3 text-right font-bold" :class="Number(ar.outstanding_amount ?? 0) > 0 ? 'text-amber-700' : 'text-emerald-600'">
                {{ fmtRp(Number(ar.outstanding_amount ?? 0)) }}
              </td>
              <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                  ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                  ar.status === 'partially_paid' ? 'bg-amber-100 text-amber-700' :
                  ar.status === 'disbursed' ? 'bg-blue-100 text-blue-700' :
                  'bg-[#f0f0f0] text-[#999]']">
                  {{ ar.status === 'paid' ? 'Lunas' : ar.status === 'partially_paid' ? 'Sebagian' : ar.status === 'disbursed' ? 'Cair' : ar.status }}
                </span>
              </td>
            </tr>
          </tbody>
          <tfoot class="border-t-2 border-[#e0e0e0] bg-[#ebebeb]">
            <tr>
              <td colspan="3" class="px-4 py-3 text-xs font-bold text-[#666]">TOTAL</td>
              <td class="px-4 py-3 text-right text-xs font-bold text-blue-700">{{ fmtRp(totalDisbursed) }}</td>
              <td class="px-4 py-3 text-right text-xs font-bold text-red-500">{{ fmtRp(totalInterest) }}</td>
              <td class="px-4 py-3 text-right text-xs font-bold text-[#1a1a1a]">{{ fmtRp(totalDisbursed + totalInterest) }}</td>
              <td class="px-4 py-3 text-right text-xs font-bold text-emerald-600">{{ fmtRp(totalPaid) }}</td>
              <td class="px-4 py-3 text-right text-xs font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</td>
              <td colspan="2"/>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  </div>
</template>
