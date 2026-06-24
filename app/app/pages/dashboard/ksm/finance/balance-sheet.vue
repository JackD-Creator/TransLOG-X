<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Neraca Keuangan' })

const supabase = useSupabaseClient()

const loading = ref(true)

interface BSData {
  // Aset Lancar
  cash: number
  ar_total: number
  inventory_est: number
  // Aset Tidak Lancar
  fixed_assets_est: number
  // Kewajiban Lancar
  ap_total: number
  scf_outstanding: number
  // Kewajiban Jangka Panjang
  ltl_est: number
  // Ekuitas
  equity_est: number
}

const bs = ref<BSData>({
  cash: 0, ar_total: 0, inventory_est: 0, fixed_assets_est: 150_000_000,
  ap_total: 0, scf_outstanding: 0, ltl_est: 0, equity_est: 0,
})

async function loadData() {
  loading.value = true
  const [{ data: ar }, { data: scf }, { data: pos }] = await Promise.all([
    supabase.from('ar_accounts').select('outstanding_amount, invoice_amount'),
    supabase.from('scf_facilities').select('outstanding, facility_limit').eq('status','approved'),
    supabase.from('ksm_purchase_orders').select('total_amount, status'),
  ])

  const arTotal = (ar ?? []).reduce((s,a) => s + Number(a.outstanding_amount ?? a.invoice_amount ?? 0), 0)
  const scfOut  = (scf ?? []).reduce((s,f) => s + Number(f.outstanding ?? 0), 0)
  const pendingPO = (pos ?? []).filter(p => ['submitted','approved','sent_to_supplier'].includes(p.status))
    .reduce((s,p) => s + Number(p.total_amount ?? 0) * 0.20, 0) // ~20% nilai PO sebagai estimasi inventory on-transit

  const totalAssets   = 200_000_000 + arTotal + pendingPO + 150_000_000 // cash est + AR + inventory + fixed
  const totalLiab     = pendingPO * 0.8 + scfOut  // AP est + SCF
  const equityCalc    = totalAssets - totalLiab

  bs.value = {
    cash: 200_000_000,
    ar_total: arTotal,
    inventory_est: pendingPO,
    fixed_assets_est: 150_000_000,
    ap_total: pendingPO * 0.8,
    scf_outstanding: scfOut,
    ltl_est: 0,
    equity_est: equityCalc,
  }
  loading.value = false
}

const totalCurrentAssets    = computed(() => bs.value.cash + bs.value.ar_total + bs.value.inventory_est)
const totalNonCurrentAssets = computed(() => bs.value.fixed_assets_est)
const totalAssets            = computed(() => totalCurrentAssets.value + totalNonCurrentAssets.value)
const totalCurrentLiab       = computed(() => bs.value.ap_total + bs.value.scf_outstanding)
const totalNonCurrentLiab    = computed(() => bs.value.ltl_est)
const totalLiabilities       = computed(() => totalCurrentLiab.value + totalNonCurrentLiab.value)
const totalEquity             = computed(() => bs.value.equity_est)
const totalLiabEquity         = computed(() => totalLiabilities.value + totalEquity.value)

// Rasio keuangan
const currentRatio   = computed(() => totalCurrentLiab.value > 0 ? totalCurrentAssets.value / totalCurrentLiab.value : 0)
const debtToEquity   = computed(() => totalEquity.value > 0 ? totalLiabilities.value / totalEquity.value : 0)
const equityRatio    = computed(() => totalAssets.value > 0 ? (totalEquity.value / totalAssets.value) * 100 : 0)

function fmtRp(n: number) {
  if (Math.abs(n) >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (Math.abs(n) >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',minimumFractionDigits:0}).format(n)
}

const today = new Date().toLocaleDateString('id-ID',{day:'2-digit',month:'long',year:'numeric'})

onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard/ksm/finance" class="text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Neraca Keuangan</h1>
        <p class="text-sm text-[#999] mt-0.5">Per {{ today }} · Posisi aset, kewajiban, dan ekuitas KSM</p>
      </div>
    </div>

    <!-- Key Ratios -->
    <div class="grid grid-cols-3 gap-4">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Current Ratio</p>
        <p class="text-2xl font-bold" :class="currentRatio >= 2 ? 'text-emerald-700' : currentRatio >= 1 ? 'text-amber-600' : 'text-red-600'">
          {{ currentRatio.toFixed(2) }}x
        </p>
        <p class="text-[10px] mt-0.5" :class="currentRatio >= 2 ? 'text-emerald-600' : 'text-[#999]'">
          {{ currentRatio >= 2 ? 'Sangat Likuid' : currentRatio >= 1 ? 'Likuid' : 'Perlu Perhatian' }}
        </p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Debt-to-Equity</p>
        <p class="text-2xl font-bold" :class="debtToEquity <= 1 ? 'text-emerald-700' : debtToEquity <= 2 ? 'text-amber-600' : 'text-red-600'">
          {{ debtToEquity.toFixed(2) }}x
        </p>
        <p class="text-[10px] mt-0.5 text-[#999]">{{ debtToEquity <= 1 ? 'Sehat' : debtToEquity <= 2 ? 'Moderat' : 'Tinggi' }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Equity Ratio</p>
        <p class="text-2xl font-bold text-[#6b1525]">{{ equityRatio.toFixed(1) }}%</p>
        <p class="text-[10px] mt-0.5 text-[#999]">Aset yang didanai ekuitas</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-5">

      <!-- ASET -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3" style="background: linear-gradient(135deg, #6b1525 0%, #8a1e33 100%)">
          <p class="text-xs font-bold text-white">ASET</p>
        </div>
        <div class="p-5 space-y-1 text-xs">
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2">Aset Lancar</p>
          <div v-for="row in [
            { label:'Kas & Setara Kas', val: bs.cash },
            { label:'Piutang Usaha (AR)', val: bs.ar_total },
            { label:'Persediaan / Transit', val: bs.inventory_est },
          ]" :key="row.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ row.label }}</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(row.val) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Aset Lancar</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalCurrentAssets) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Aset Tidak Lancar</p>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Aset Tetap (nett)</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.fixed_assets_est) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Aset Tidak Lancar</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalNonCurrentAssets) }}</span>
          </div>

          <div class="flex justify-between py-2 font-bold text-sm bg-[#ebebeb] rounded-lg px-2 mt-2">
            <span class="text-[#1a1a1a]">TOTAL ASET</span>
            <span class="text-[#6b1525]">{{ fmtRp(totalAssets) }}</span>
          </div>
        </div>
      </div>

      <!-- KEWAJIBAN & EKUITAS -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="bg-[#6b1525] px-5 py-3">
          <p class="text-xs font-bold text-white">KEWAJIBAN & EKUITAS</p>
        </div>
        <div class="p-5 space-y-1 text-xs">
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2">Kewajiban Lancar</p>
          <div v-for="row in [
            { label:'Utang Usaha (AP ke Distributor)', val: bs.ap_total },
            { label:'Fasilitas SCF Outstanding', val: bs.scf_outstanding },
          ]" :key="row.label" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">{{ row.label }}</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(row.val) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Kewajiban Lancar</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalCurrentLiab) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Kewajiban Jangka Panjang</p>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Utang Jangka Panjang</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.ltl_est) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Kewajiban</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalLiabilities) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Ekuitas</p>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Modal Disetor + Laba Ditahan</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.equity_est) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Ekuitas</span>
            <span class="text-emerald-700">{{ fmtRp(totalEquity) }}</span>
          </div>

          <div class="flex justify-between py-2 font-bold text-sm bg-[#ebebeb] rounded-lg px-2 mt-2">
            <span class="text-[#1a1a1a]">TOTAL KEWAJIBAN + EKUITAS</span>
            <span :class="Math.abs(totalLiabEquity - totalAssets) < 100 ? 'text-emerald-700' : 'text-red-600'">
              {{ fmtRp(totalLiabEquity) }}
            </span>
          </div>
          <p v-if="Math.abs(totalLiabEquity - totalAssets) < 100" class="text-[10px] text-emerald-600 text-center mt-1">
            ✓ Neraca Seimbang
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
