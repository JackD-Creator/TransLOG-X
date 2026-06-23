<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'P&L Bank — SCF Portfolio' })

const supabase = useSupabaseClient()
const loading = ref(true)
const period = ref('this_month')

const data = ref({ interestIncome: 0, adminFeeIncome: 0, provisionIncome: 0, badDebtExpense: 0, opexEst: 0, disbTotal: 0, facilityCount: 0 })

async function loadData() {
  loading.value = true
  const [{ data: ar }, { data: fac }] = await Promise.all([
    supabase.from('ar_accounts').select('invoice_amount, interest_amount, status'),
    supabase.from('scf_facilities').select('facility_limit, outstanding').eq('status','approved'),
  ])

  const intIncome   = (ar ?? []).reduce((s,a) => s + Number(a.interest_amount ?? 0), 0)
  const adminFee    = (ar ?? []).reduce((s,a) => s + Number(a.invoice_amount ?? 0) * 0.005, 0)
  const badDebt     = (ar ?? []).filter(a => a.status === 'overdue').reduce((s,a) => s + Number(a.invoice_amount ?? 0) * 0.02, 0)
  const totalDisb   = (ar ?? []).reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0)

  data.value = {
    interestIncome: intIncome,
    adminFeeIncome: adminFee,
    provisionIncome: totalDisb * 0.001,
    badDebtExpense: badDebt,
    opexEst: (intIncome + adminFee) * 0.20,
    disbTotal: totalDisb,
    facilityCount: (fac ?? []).length,
  }
  loading.value = false
}

const grossIncome  = computed(() => data.value.interestIncome + data.value.adminFeeIncome + data.value.provisionIncome)
const totalExpense = computed(() => data.value.badDebtExpense + data.value.opexEst)
const netIncome    = computed(() => grossIncome.value - totalExpense.value)
const nim          = computed(() => data.value.disbTotal > 0 ? (data.value.interestIncome / data.value.disbTotal) * 100 : 0)

function fmtRp(n: number) {
  if (Math.abs(n) >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (Math.abs(n) >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',minimumFractionDigits:0}).format(n)
}

onMounted(loadData)
watch(period, loadData)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <NuxtLink to="/dashboard" class="text-[#999] hover:text-[#6b1525]">
          <UIcon name="i-lucide-arrow-left" class="text-sm"/>
        </NuxtLink>
        <div>
          <h1 class="text-xl font-bold text-[#1a1a1a]">P&L — SCF Portfolio Bank</h1>
          <p class="text-sm text-[#999] mt-0.5">Laporan laba rugi dari portofolio Supply Chain Finance</p>
        </div>
      </div>
      <select v-model="period" class="text-xs border border-[#e5e5e5] rounded-lg px-3 py-2 bg-[#f5f5f5] outline-none">
        <option value="this_month">Bulan Ini</option>
        <option value="last_month">Bulan Lalu</option>
        <option value="this_year">Tahun Ini</option>
      </select>
    </div>

    <!-- KPIs -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="bg-[#0d0d0d] text-white rounded-xl p-4 text-center">
        <p class="text-[10px] text-white/40 uppercase mb-1">Net Income</p>
        <p class="text-xl font-bold" :class="netIncome >= 0 ? 'text-emerald-400' : 'text-red-400'">{{ fmtRp(netIncome) }}</p>
        <p class="text-[10px] text-white/30 mt-0.5">{{ netIncome >= 0 ? 'Profit' : 'Loss' }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Gross Income</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(grossIncome) }}</p>
        <p class="text-[10px] text-[#aaa]">Int + Fee + Provisi</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">NIM</p>
        <p class="text-xl font-bold text-blue-700">{{ nim.toFixed(2) }}%</p>
        <p class="text-[10px] text-[#aaa]">Net Interest Margin</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Disbursed</p>
        <p class="text-xl font-bold text-[#6b1525]">{{ fmtRp(data.disbTotal) }}</p>
        <p class="text-[10px] text-[#aaa]">Portofolio aktif</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <!-- Income -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-emerald-700 px-5 py-3">
          <p class="text-xs font-bold text-white">PENDAPATAN</p>
        </div>
        <div class="p-5 space-y-2 text-xs">
          <div v-for="row in [
            { label:'Pendapatan Bunga (SCF)', val: data.interestIncome },
            { label:'Biaya Administrasi (0.5% × PO)', val: data.adminFeeIncome },
            { label:'Provisi Fasilitas (0.1%)', val: data.provisionIncome },
          ]" :key="row.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ row.label }}</span>
            <span class="font-semibold text-emerald-700">+{{ fmtRp(row.val) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold">
            <span>Total Pendapatan</span>
            <span class="text-emerald-700">+{{ fmtRp(grossIncome) }}</span>
          </div>
        </div>
      </div>

      <!-- Expense -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-[#6b1525] px-5 py-3">
          <p class="text-xs font-bold text-white">BEBAN</p>
        </div>
        <div class="p-5 space-y-2 text-xs">
          <div v-for="row in [
            { label:'Cadangan Kerugian Piutang (CKPN)', val: data.badDebtExpense },
            { label:'Biaya Operasional est. (20% income)', val: data.opexEst },
          ]" :key="row.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ row.label }}</span>
            <span class="font-semibold text-red-600">-{{ fmtRp(row.val) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold">
            <span>Total Beban</span>
            <span class="text-red-600">-{{ fmtRp(totalExpense) }}</span>
          </div>
          <div class="flex justify-between py-2 font-bold text-sm bg-[#ebebeb] rounded-lg px-2 mt-2">
            <span class="text-[#1a1a1a]">LABA BERSIH</span>
            <span :class="netIncome >= 0 ? 'text-emerald-700' : 'text-red-600'">{{ fmtRp(netIncome) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
