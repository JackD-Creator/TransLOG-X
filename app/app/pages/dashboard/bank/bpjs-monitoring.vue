<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'BPJS & SI Tracker' })

const supabase = useSupabaseClient()

const loading = ref(true)
const invoices = ref<any[]>([])
const siList = ref<any[]>([])

async function load() {
  loading.value = true
  const [{ data: inv }, { data: si }] = await Promise.all([
    supabase.from('ksm_invoices')
      .select('id,invoice_number,invoice_date,due_date,total_amount,paid_amount,outstanding,status,bpjs_amount,bpjs_expected_date,bpjs_received_date,shortfall_amount,shortfall_covered_by_bank,contract_payment_days,metadata')
      .in('status', ['sent_to_rs', 'acknowledged_rs', 'payment_pending', 'partially_paid', 'overdue'])
      .order('due_date', { ascending: true })
      .limit(100),
    supabase.from('standing_instructions')
      .select('id,si_number,si_type,rs_account_number,ksm_account_number,custodian_bank,is_active,activated_at')
      .eq('is_active', true),
  ])
  invoices.value = inv ?? []
  siList.value = si ?? []
  loading.value = false
}

const waitingBPJS = computed(() => invoices.value.filter(i => !i.bpjs_received_date))
const bpjsReceived = computed(() => invoices.value.filter(i => i.bpjs_received_date))
const totalWaiting = computed(() => waitingBPJS.value.reduce((s, i) => s + Number(i.total_amount), 0))
const totalReceived = computed(() => bpjsReceived.value.reduce((s, i) => s + Number(i.bpjs_amount ?? 0), 0))
const totalShortfall = computed(() => invoices.value.reduce((s, i) => s + Number(i.shortfall_amount ?? 0), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">BPJS & Standing Instruction Tracker</h1>
      <p class="text-sm text-[#999] mt-0.5">Monitor: BPJS cair ke RS → SI auto-transfer ke KSM → shortfall = Bank cover → bunga harian 50/50</p>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Tunggu BPJS</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalWaiting) }}</p>
        <p class="text-[10px] text-amber-500 mt-1">{{ waitingBPJS.length }} invoice pending</p>
      </div>
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-4">
        <p class="text-[10px] text-emerald-500 uppercase mb-1">BPJS Cair</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalReceived) }}</p>
      </div>
      <div :class="['rounded-xl border p-4', totalShortfall > 0 ? 'bg-red-50 border-red-200' : 'bg-[#f5f5f5] border-[#e5e5e5]']">
        <p class="text-[10px] text-[#999] uppercase mb-1">Shortfall (Bank Cover)</p>
        <p class="text-xl font-bold" :class="totalShortfall > 0 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtRp(totalShortfall) }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">Bunga harian 50% KSM / 50% RS</p>
      </div>
      <div class="bg-blue-50 rounded-xl border border-blue-200 p-4">
        <p class="text-[10px] text-blue-500 uppercase mb-1">SI Aktif</p>
        <p class="text-xl font-bold text-blue-700">{{ siList.length }}</p>
      </div>
    </div>

    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-xs text-blue-700">
      <p class="font-bold mb-1">Alur yang Dimonitor Bank</p>
      <p class="text-blue-600">BPJS Kesehatan bayar RS → Standing Instruction auto-transfer ke KSM sesuai invoice → KSM lunasi hutang SCF ke Bank → Jika BPJS kurang dari invoice → Bank cover shortfall → Bunga harian (50% KSM + 50% RS)</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <!-- SI aktif -->
      <div v-if="siList.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Standing Instructions Aktif</p>
        </div>
        <div class="p-5 grid grid-cols-1 md:grid-cols-2 gap-3">
          <div v-for="si in siList" :key="si.id" class="p-3 bg-white rounded-lg border border-emerald-200 text-xs">
            <div class="flex items-center justify-between mb-1">
              <p class="font-mono font-bold text-[#1a1a1a]">{{ si.si_number }}</p>
              <span class="px-2 py-0.5 rounded-full text-[9px] font-bold bg-emerald-100 text-emerald-700">Aktif</span>
            </div>
            <p class="text-[#666]">{{ si.custodian_bank }} · {{ si.si_type === 'bpjs_auto_transfer' ? 'BPJS Auto' : si.si_type }}</p>
            <p class="text-[10px] text-[#999]">RS: {{ si.rs_account_number }} → KSM: {{ si.ksm_account_number }}</p>
          </div>
        </div>
      </div>

      <!-- Invoice table -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Invoice KSM→RS — Status BPJS & Shortfall</p>
        </div>
        <div v-if="invoices.length === 0" class="p-10 text-center text-xs text-[#ccc]">Tidak ada invoice pending</div>
        <div v-else class="overflow-x-auto">
          <table class="w-full text-xs min-w-[900px]">
            <thead class="border-b border-[#e5e5e5]">
              <tr class="text-left">
                <th class="px-4 py-3 font-semibold text-[#999]">Invoice</th>
                <th class="px-4 py-3 font-semibold text-[#999]">RS</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Nilai Invoice</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">BPJS Cair</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Shortfall</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Jatuh Tempo</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="inv in invoices" :key="inv.id" class="hover:bg-[#ebebeb] transition-colors">
                <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ inv.invoice_number }}</td>
                <td class="px-4 py-3 text-[#666]">{{ inv.metadata?.rs_name ?? '-' }}</td>
                <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</td>
                <td class="px-4 py-3 text-right">
                  <span v-if="inv.bpjs_amount" class="font-bold text-emerald-700">{{ fmtRp(inv.bpjs_amount) }}</span>
                  <span v-else class="text-[#ccc]">—</span>
                </td>
                <td class="px-4 py-3 text-right">
                  <span v-if="Number(inv.shortfall_amount) > 0" class="font-bold text-red-600">{{ fmtRp(inv.shortfall_amount) }}</span>
                  <span v-else class="text-emerald-600">—</span>
                </td>
                <td class="px-4 py-3" :class="inv.due_date < new Date().toISOString().slice(0,10) ? 'text-red-600 font-bold' : 'text-[#666]'">
                  {{ fmtDate(inv.due_date) }}
                </td>
                <td class="px-4 py-3">
                  <span v-if="inv.bpjs_received_date" class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-700">Cair</span>
                  <span v-else class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-100 text-amber-700 animate-pulse">Tunggu BPJS</span>
                  <span v-if="inv.shortfall_covered_by_bank" class="ml-1 px-1.5 py-0.5 rounded text-[9px] font-bold bg-red-100 text-red-700">Shortfall</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>
