<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Bunga Harian Shortfall' })

const supabase = useSupabaseClient()

const loading = ref(true)
const accruals = ref<any[]>([])
const invoicesWithShortfall = ref<any[]>([])

async function load() {
  loading.value = true
  const [{ data: dia }, { data: inv }] = await Promise.all([
    supabase.from('daily_interest_accruals')
      .select('id,invoice_id,accrual_date,outstanding_principal,daily_rate,interest_amount,ksm_share,rs_share')
      .order('accrual_date', { ascending: false })
      .limit(200),
    supabase.from('ksm_invoices')
      .select('id,invoice_number,shortfall_amount,shortfall_covered_by_bank,status,metadata')
      .eq('shortfall_covered_by_bank', true),
  ])
  accruals.value = dia ?? []
  invoicesWithShortfall.value = inv ?? []
  loading.value = false
}

const totalInterest = computed(() => accruals.value.reduce((s, d) => s + Number(d.interest_amount), 0))
const totalKSM = computed(() => accruals.value.reduce((s, d) => s + Number(d.ksm_share ?? 0), 0))
const totalRS = computed(() => accruals.value.reduce((s, d) => s + Number(d.rs_share ?? 0), 0))
const totalPrincipal = computed(() => invoicesWithShortfall.value.reduce((s, i) => s + Number(i.shortfall_amount), 0))

// Group by date
const byDate = computed(() => {
  const map: Record<string, { date: string; total: number; ksm: number; rs: number; count: number }> = {}
  for (const d of accruals.value) {
    const key = d.accrual_date
    if (!map[key]) map[key] = { date: key, total: 0, ksm: 0, rs: 0, count: 0 }
    map[key].total += Number(d.interest_amount)
    map[key].ksm += Number(d.ksm_share ?? 0)
    map[key].rs += Number(d.rs_share ?? 0)
    map[key].count++
  }
  return Object.values(map).sort((a, b) => b.date.localeCompare(a.date))
})

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Bunga Harian Shortfall</h1>
      <p class="text-sm text-[#999] mt-0.5">Daily interest accrual atas kekurangan BPJS — ditanggung 50% KSM + 50% RS</p>
    </div>

    <!-- KPI -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Principal Shortfall</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalPrincipal) }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">{{ invoicesWithShortfall.length }} invoice</p>
      </div>
      <div class="bg-red-50 rounded-xl border border-red-200 p-4">
        <p class="text-[10px] text-red-400 uppercase mb-1">Total Bunga Accrued</p>
        <p class="text-xl font-bold text-red-600">{{ fmtRp(totalInterest) }}</p>
      </div>
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Bagian KSM (50%)</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalKSM) }}</p>
      </div>
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Bagian RS (50%)</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalRS) }}</p>
      </div>
    </div>

    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-xs text-blue-700">
      <p class="font-bold mb-1">Mekanisme Bunga Harian</p>
      <p class="text-blue-600">Saat BPJS tidak cover 100% invoice → Bank cover kekurangan (shortfall) → Bunga dihitung HARIAN dari saldo shortfall × rate SCF / 365 → Split: 50% ditanggung KSM, 50% ditanggung RS</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <div v-if="byDate.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
        <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
        <p class="text-sm text-[#999]">Tidak ada bunga harian yang di-accrue</p>
        <p class="text-xs text-[#bbb]">Bunga harian muncul saat ada shortfall yang dicover Bank</p>
      </div>

      <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Daily Accrual Log</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead class="border-b border-[#e5e5e5]">
              <tr class="text-left">
                <th class="px-4 py-3 font-semibold text-[#999]">Tanggal</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-center">Invoice</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Total Bunga</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">KSM (50%)</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">RS (50%)</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="d in byDate" :key="d.date" class="hover:bg-[#ebebeb] transition-colors">
                <td class="px-4 py-3 font-semibold text-[#1a1a1a]">{{ fmtDate(d.date) }}</td>
                <td class="px-4 py-3 text-center text-[#666]">{{ d.count }} invoice</td>
                <td class="px-4 py-3 text-right font-bold text-red-600">{{ fmtRp(d.total) }}</td>
                <td class="px-4 py-3 text-right font-semibold text-amber-700">{{ fmtRp(d.ksm) }}</td>
                <td class="px-4 py-3 text-right font-semibold text-amber-700">{{ fmtRp(d.rs) }}</td>
              </tr>
            </tbody>
            <tfoot class="border-t-2 border-[#e0e0e0] bg-[#ebebeb]">
              <tr>
                <td class="px-4 py-3 font-bold text-[#666]">TOTAL</td>
                <td/>
                <td class="px-4 py-3 text-right font-bold text-red-600">{{ fmtRp(totalInterest) }}</td>
                <td class="px-4 py-3 text-right font-bold text-amber-700">{{ fmtRp(totalKSM) }}</td>
                <td class="px-4 py-3 text-right font-bold text-amber-700">{{ fmtRp(totalRS) }}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>
