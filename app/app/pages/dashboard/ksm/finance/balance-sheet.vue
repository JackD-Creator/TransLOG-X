<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Neraca Keuangan' })

const { tenantId } = useUserRole()
const { apiGet } = useApi()

const loading = ref(true)

interface BSData {
  cash: number
  arRS: number            // Piutang dari RS — invoice yang belum dibayar RS ke KSM
  inventoryTransit: number
  fixedAssets: number
  hutangSCF: number       // Hutang KSM ke Bank per ar_accounts (satu sumber, tidak double count)
  interestAccrual: number // Bunga shortfall akrual 50% KSM
  equity: number
}

const bs = ref<BSData>({
  cash: 0, arRS: 0, inventoryTransit: 0, fixedAssets: 150_000_000,
  hutangSCF: 0, interestAccrual: 0, equity: 0,
})

async function loadData() {
  if (!tenantId.value) return
  loading.value = true

  try {
    const d = await apiGet<any>('/api/ksm/finance/balance-sheet')
    bs.value = {
      cash:             Number(d.cash ?? 0),
      arRS:             Number(d.ar_rs ?? 0),
      inventoryTransit: Number(d.inventory_transit ?? 0),
      fixedAssets:      Number(d.fixed_assets ?? 150_000_000),
      hutangSCF:        Number(d.hutang_scf ?? 0),
      interestAccrual:  Number(d.interest_accrual ?? 0),
      equity:           Number(d.equity ?? 0),
    }
  } catch (e) { console.error('balance-sheet:', e) }
  loading.value = false
}

const totalCurrentAssets = computed(() => bs.value.cash + bs.value.arRS + bs.value.inventoryTransit)
const totalNonCurrentAssets = computed(() => bs.value.fixedAssets)
const totalAssets = computed(() => totalCurrentAssets.value + totalNonCurrentAssets.value)
const totalCurrentLiab = computed(() => bs.value.hutangSCF + bs.value.interestAccrual)
const totalNonCurrentLiab = computed(() => 0)
const totalLiabilities = computed(() => totalCurrentLiab.value + totalNonCurrentLiab.value)
const totalEquity = computed(() => bs.value.equity)
const totalLiabEquity = computed(() => totalLiabilities.value + totalEquity.value)

const currentRatio = computed(() => totalCurrentLiab.value > 0 ? totalCurrentAssets.value / totalCurrentLiab.value : 0)
const debtToEquity = computed(() => totalEquity.value > 0 ? totalLiabilities.value / totalEquity.value : 0)

const today = new Date().toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })

watch(tenantId, (id) => { if (id) loadData() })
onMounted(() => { if (tenantId.value) loadData() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard/ksm/finance" class="text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Neraca Keuangan</h1>
        <p class="text-sm text-[#999] mt-0.5">Per {{ today }} · Aset (piutang RS) vs Kewajiban (hutang SCF Bank)</p>
      </div>
    </div>

    <!-- Key Ratios -->
    <div class="grid grid-cols-2 gap-4">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Current Ratio</p>
        <p class="text-2xl font-bold" :class="currentRatio >= 2 ? 'text-emerald-700' : currentRatio >= 1 ? 'text-amber-600' : 'text-red-600'">
          {{ currentRatio.toFixed(2) }}x
        </p>
        <p class="text-[10px] mt-0.5" :class="currentRatio >= 1.5 ? 'text-emerald-600' : 'text-[#999]'">
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
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Kas & Setara Kas</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.cash) }}</span>
          </div>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <div>
              <span class="text-[#555]">Piutang dari RS</span>
              <p class="text-[10px] text-[#777]">Invoice outstanding — dibayar via BPJS+SI</p>
            </div>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.arRS) }}</span>
          </div>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Persediaan In-Transit</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.inventoryTransit) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Aset Lancar</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalCurrentAssets) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Aset Tetap</p>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Aset Tetap (nett)</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.fixedAssets) }}</span>
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
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <div>
              <span class="text-[#555]">Hutang SCF ke Bank</span>
              <p class="text-[10px] text-[#777]">Sisa pokok SCF per PO yang belum dilunasi KSM</p>
            </div>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.hutangSCF) }}</span>
          </div>
          <div v-if="bs.interestAccrual > 0" class="flex justify-between py-1.5 border-b border-[#ececec]">
            <div>
              <span class="text-[#555]">Bunga Shortfall Akrual (50% KSM)</span>
              <p class="text-[10px] text-[#777]">Hanya bunga — pokok shortfall = hutang RS ke Bank (bukan KSM)</p>
            </div>
            <span class="font-semibold text-amber-700">{{ fmtRp(bs.interestAccrual) }}</span>
          </div>
          <div class="flex justify-between py-1.5 font-bold border-b-2 border-[#ccc]">
            <span class="text-[#333]">Total Kewajiban Lancar</span>
            <span class="text-[#1a1a1a]">{{ fmtRp(totalCurrentLiab) }}</span>
          </div>

          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-2 mt-4">Ekuitas</p>
          <div class="flex justify-between py-1.5 border-b border-[#ececec]">
            <span class="text-[#555]">Modal + Laba Ditahan</span>
            <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(bs.equity) }}</span>
          </div>

          <div class="flex justify-between py-2 font-bold text-sm bg-[#ebebeb] rounded-lg px-2 mt-2">
            <span class="text-[#1a1a1a]">TOTAL KEWAJIBAN + EKUITAS</span>
            <span :class="Math.abs(totalLiabEquity - totalAssets) < 1000 ? 'text-emerald-700' : 'text-red-600'">
              {{ fmtRp(totalLiabEquity) }}
            </span>
          </div>
          <p v-if="Math.abs(totalLiabEquity - totalAssets) < 1000" class="text-[10px] text-emerald-600 text-center mt-1">
            Neraca Seimbang
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
