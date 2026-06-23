<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Revenue Architecture — Supply ke RS' })

const supabase = useSupabaseClient()

// ─── KFA Live Data ──────────────────────────────────────────────────────────
interface KfaBenchmark {
  kfa_code: string; name: string; kelas_terapi: string
  fix_price: number; het_price: number; hna: number
  spread_pct: number; tier: 'HIGH' | 'MID' | 'LOW'
}

const benchmarks = ref<KfaBenchmark[]>([])
const loadingBench = ref(true)
const selectedCat = ref<string | null>(null)

const kategoriList = computed(() => [...new Set(benchmarks.value.map(b => b.kelas_terapi).filter(Boolean))].sort())
const filteredBench = computed(() =>
  (selectedCat.value ? benchmarks.value.filter(b => b.kelas_terapi === selectedCat.value) : benchmarks.value).slice(0, 20)
)

async function loadBenchmarks() {
  const { data } = await supabase.from('kfa_drugs').select('kfa_code,name,kelas_terapi,fix_price,het_price')
    .eq('is_fornas', true).not('fix_price','is',null).not('het_price','is',null).gt('het_price',0)
    .order('fix_price', { ascending: false }).limit(100)
  benchmarks.value = (data ?? []).map(d => {
    const fix = Number(d.fix_price), het = Number(d.het_price)
    const hna = fix * 1.10
    const spread_pct = hna > 0 ? ((het - hna) / hna) * 100 : 0
    const tier: 'HIGH' | 'MID' | 'LOW' = spread_pct >= 20 ? 'HIGH' : spread_pct >= 10 ? 'MID' : 'LOW'
    return { ...d, fix_price: fix, het_price: het, hna, spread_pct, tier }
  })
  loadingBench.value = false
}

// ─── Revenue Model Interactive ───────────────────────────────────────────────
const model = reactive({
  num_rs: 5,
  avg_monthly_vol_per_rs: 500_000_000,   // Rp / RS / bulan
  obat_share: 60,     // % dari total supply
  bmhp_share: 25,
  alkes_share: 15,
  service_fee_per_rs: 7_500_000,         // Rp / RS / bulan (managed service)
  volume_rebate_pct: 2.0,                // % dari total PO ke distributor
})

// Margin per segment (KSM beli di HNA, jual ke RS)
const MARGIN = { obat: 9, bmhp: 15, alkes: 20 }  // % net margin after COGS

const rev = computed(() => {
  const totalMonthly = model.num_rs * model.avg_monthly_vol_per_rs
  const obatRev  = totalMonthly * (model.obat_share  / 100)
  const bmhpRev  = totalMonthly * (model.bmhp_share  / 100)
  const alkesRev = totalMonthly * (model.alkes_share / 100)

  const obatGP  = obatRev  * (MARGIN.obat  / 100)
  const bmhpGP  = bmhpRev  * (MARGIN.bmhp  / 100)
  const alkesGP = alkesRev * (MARGIN.alkes / 100)

  const supplyGP = obatGP + bmhpGP + alkesGP
  const serviceRev = model.num_rs * model.service_fee_per_rs
  const rebate = totalMonthly * (model.volume_rebate_pct / 100)
  const totalGP = supplyGP + serviceRev + rebate

  return {
    totalMonthly, totalAnnual: totalMonthly * 12,
    obatRev, bmhpRev, alkesRev, obatGP, bmhpGP, alkesGP,
    supplyGP, serviceRev, rebate, totalGP,
    blendedMargin: totalGP / totalMonthly * 100,
    totalGPAnnual: totalGP * 12,
  }
})

// ─── Sensitivity Table: RS count × vol per RS ───────────────────────────────
const sensCols = [300, 500, 750, 1000, 1500]  // jt Rp / RS / bulan
const sensRows = [3, 5, 8, 10, 15]             // jumlah RS

function sensGP(numRS: number, volJt: number) {
  const monthly = numRS * volJt * 1_000_000
  const gp = monthly * (rev.value.blendedMargin / 100)
  return gp * 12
}

// ─── Format ──────────────────────────────────────────────────────────────────
function fmtM(n: number) { return `Rp ${(n / 1e9).toFixed(2)} M` }
function fmtJt(n: number) { return `Rp ${(n / 1e6).toFixed(1)} jt` }
function fmtPct(n: number) { return `${n.toFixed(1)}%` }
function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n / 1e9).toFixed(1)} M`
  if (n >= 1e6) return `Rp ${(n / 1e6).toFixed(2)} jt`
  if (n >= 1e3) return `Rp ${(n / 1e3).toFixed(0)}rb`
  return `Rp ${n.toFixed(0)}`
}

onMounted(loadBenchmarks)
</script>

<template>
  <div class="space-y-6 pb-10">

    <!-- Header -->
    <div class="flex items-start gap-3">
      <NuxtLink to="/dashboard/ksm/strategy" class="mt-1 text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div class="flex-1">
        <div class="flex items-center gap-3">
          <h1 class="text-xl font-bold text-[#1a1a1a]">Revenue Architecture — Supply ke RS</h1>
          <span class="text-[10px] px-2.5 py-1 rounded-full bg-[#6b1525] text-white font-bold tracking-widest">STRATEGIC FRAMEWORK</span>
        </div>
        <p class="text-sm text-[#777] mt-0.5">Institutional-grade revenue model untuk optimasi profitabilitas KSM sebagai Managed Logistics Partner RS</p>
      </div>
    </div>

    <!-- Executive Summary KPIs -->
    <div class="bg-[#0d0d0d] rounded-xl p-5 text-white">
      <p class="text-[10px] uppercase tracking-[0.2em] text-white/50 mb-4">Executive Summary — Revenue Potential</p>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <p class="text-[10px] text-white/50 mb-1">Gross Revenue (Annual)</p>
          <p class="text-xl font-bold text-white">{{ fmtM(rev.totalAnnual) }}</p>
          <p class="text-[10px] text-white/40 mt-0.5">{{ model.num_rs }} RS × {{ fmtJt(model.avg_monthly_vol_per_rs) }}/bln</p>
        </div>
        <div>
          <p class="text-[10px] text-white/50 mb-1">Gross Profit (Annual)</p>
          <p class="text-xl font-bold text-emerald-400">{{ fmtM(rev.totalGPAnnual) }}</p>
          <p class="text-[10px] text-white/40 mt-0.5">Blended margin {{ fmtPct(rev.blendedMargin) }}</p>
        </div>
        <div>
          <p class="text-[10px] text-white/50 mb-1">Service Revenue (Annual)</p>
          <p class="text-xl font-bold text-blue-400">{{ fmtM(rev.serviceRev * 12) }}</p>
          <p class="text-[10px] text-white/40 mt-0.5">{{ fmtJt(model.service_fee_per_rs) }}/RS/bln</p>
        </div>
        <div>
          <p class="text-[10px] text-white/50 mb-1">Volume Rebate (Annual)</p>
          <p class="text-xl font-bold text-amber-400">{{ fmtM(rev.rebate * 12) }}</p>
          <p class="text-[10px] text-white/40 mt-0.5">{{ fmtPct(model.volume_rebate_pct) }} dari total PO</p>
        </div>
      </div>
    </div>

    <!-- Interactive Revenue Model + Sensitivity -->
    <div class="grid grid-cols-1 lg:grid-cols-5 gap-5">

      <!-- Parameters -->
      <div class="lg:col-span-2 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs font-bold text-[#1a1a1a] mb-4">Model Parameters</p>
        <div class="space-y-4">

          <div>
            <div class="flex justify-between mb-1">
              <label class="text-[11px] text-[#666]">Jumlah RS Mitra</label>
              <span class="text-[11px] font-bold text-[#6b1525]">{{ model.num_rs }} RS</span>
            </div>
            <input type="range" v-model.number="model.num_rs" min="1" max="20" step="1" class="w-full accent-[#6b1525]"/>
          </div>

          <div>
            <div class="flex justify-between mb-1">
              <label class="text-[11px] text-[#666]">Vol. per RS / Bulan</label>
              <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtM(model.avg_monthly_vol_per_rs) }}</span>
            </div>
            <input type="range" v-model.number="model.avg_monthly_vol_per_rs" :min="100_000_000" :max="2_000_000_000" :step="50_000_000" class="w-full accent-[#6b1525]"/>
          </div>

          <div>
            <div class="flex justify-between mb-1">
              <label class="text-[11px] text-[#666]">Service Fee / RS / Bulan</label>
              <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtJt(model.service_fee_per_rs) }}</span>
            </div>
            <input type="range" v-model.number="model.service_fee_per_rs" :min="2_000_000" :max="20_000_000" :step="500_000" class="w-full accent-[#6b1525]"/>
          </div>

          <div>
            <div class="flex justify-between mb-1">
              <label class="text-[11px] text-[#666]">Volume Rebate Distributor</label>
              <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtPct(model.volume_rebate_pct) }}</span>
            </div>
            <input type="range" v-model.number="model.volume_rebate_pct" min="0.5" max="4" step="0.25" class="w-full accent-[#6b1525]"/>
          </div>

          <!-- Product Mix -->
          <div class="pt-2 border-t border-[#e0e0e0]">
            <p class="text-[10px] font-bold text-[#999] mb-3 uppercase tracking-wide">Product Mix</p>
            <div class="space-y-2">
              <div class="flex justify-between text-[11px]">
                <span class="text-[#666]">Obat (margin {{ MARGIN.obat }}%)</span>
                <div class="flex items-center gap-2">
                  <div class="w-20 bg-[#e0e0e0] rounded-full h-1.5">
                    <div class="bg-blue-500 h-1.5 rounded-full" :style="{width: model.obat_share+'%'}"/>
                  </div>
                  <span class="font-bold w-8 text-right text-[#1a1a1a]">{{ model.obat_share }}%</span>
                </div>
              </div>
              <div class="flex justify-between text-[11px]">
                <span class="text-[#666]">BMHP (margin {{ MARGIN.bmhp }}%)</span>
                <div class="flex items-center gap-2">
                  <div class="w-20 bg-[#e0e0e0] rounded-full h-1.5">
                    <div class="bg-emerald-500 h-1.5 rounded-full" :style="{width: model.bmhp_share+'%'}"/>
                  </div>
                  <span class="font-bold w-8 text-right text-[#1a1a1a]">{{ model.bmhp_share }}%</span>
                </div>
              </div>
              <div class="flex justify-between text-[11px]">
                <span class="text-[#666]">Alkes (margin {{ MARGIN.alkes }}%)</span>
                <div class="flex items-center gap-2">
                  <div class="w-20 bg-[#e0e0e0] rounded-full h-1.5">
                    <div class="bg-amber-500 h-1.5 rounded-full" :style="{width: model.alkes_share+'%'}"/>
                  </div>
                  <span class="font-bold w-8 text-right text-[#1a1a1a]">{{ model.alkes_share }}%</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Revenue Waterfall -->
      <div class="lg:col-span-3 space-y-4">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-bold text-[#1a1a1a] mb-4">Gross Profit Decomposition — Monthly</p>
          <div class="space-y-2">
            <div v-for="row in [
              { label: 'Supply Obat FORNAS', val: rev.obatGP, sub: `${fmtM(rev.obatRev)} rev × ${MARGIN.obat}%`, color: 'bg-blue-500' },
              { label: 'Supply BMHP', val: rev.bmhpGP, sub: `${fmtM(rev.bmhpRev)} rev × ${MARGIN.bmhp}%`, color: 'bg-emerald-500' },
              { label: 'Supply Alkes', val: rev.alkesGP, sub: `${fmtM(rev.alkesRev)} rev × ${MARGIN.alkes}%`, color: 'bg-amber-500' },
              { label: 'Managed Service Fee', val: rev.serviceRev, sub: `${model.num_rs} RS × ${fmtJt(model.service_fee_per_rs)}`, color: 'bg-purple-500' },
              { label: 'Volume Rebate Dist.', val: rev.rebate, sub: `${fmtPct(model.volume_rebate_pct)} × ${fmtM(rev.totalMonthly)} PO`, color: 'bg-rose-500' },
            ]" :key="row.label" class="flex items-center gap-3">
              <div class="w-32 flex-shrink-0">
                <p class="text-[11px] font-semibold text-[#1a1a1a] leading-tight">{{ row.label }}</p>
                <p class="text-[10px] text-[#999]">{{ row.sub }}</p>
              </div>
              <div class="flex-1 bg-[#e5e5e5] rounded-full h-4 relative overflow-hidden">
                <div :class="[row.color, 'h-4 rounded-full transition-all duration-500']"
                  :style="{ width: Math.min(100, (row.val / rev.totalGP) * 100) + '%' }"/>
              </div>
              <span class="w-20 text-right text-[11px] font-bold text-[#1a1a1a] flex-shrink-0">{{ fmtJt(row.val) }}</span>
            </div>

            <div class="flex items-center gap-3 border-t border-[#ccc] pt-3 mt-2">
              <div class="w-32 flex-shrink-0">
                <p class="text-[11px] font-bold text-[#1a1a1a]">TOTAL GROSS PROFIT</p>
                <p class="text-[10px] text-emerald-600 font-semibold">Blended Margin: {{ fmtPct(rev.blendedMargin) }}</p>
              </div>
              <div class="flex-1 bg-[#6b1525]/20 rounded-full h-4">
                <div class="bg-[#6b1525] h-4 rounded-full" style="width:100%"/>
              </div>
              <span class="w-20 text-right text-sm font-bold text-[#6b1525] flex-shrink-0">{{ fmtJt(rev.totalGP) }}</span>
            </div>
          </div>
        </div>

        <!-- Sensitivity Matrix -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-bold text-[#1a1a1a] mb-1">Sensitivity Analysis — Annual Gross Profit (Rp M)</p>
          <p class="text-[10px] text-[#999] mb-3">Variabel: Jumlah RS (baris) × Volume per RS/bulan (kolom)</p>
          <div class="overflow-x-auto">
            <table class="w-full text-[11px]">
              <thead>
                <tr>
                  <th class="text-left py-1.5 pr-2 text-[#999] font-semibold">RS \ Vol</th>
                  <th v-for="c in sensCols" :key="c" class="text-right py-1.5 px-1.5 text-[#999] font-semibold">{{ c }} jt</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="r in sensRows" :key="r">
                  <td class="py-1.5 pr-2 font-bold text-[#555]">{{ r }} RS</td>
                  <td v-for="c in sensCols" :key="c" class="py-1.5 px-1.5 text-right rounded"
                    :class="sensGP(r, c) >= 10e9 ? 'text-emerald-700 font-bold' : sensGP(r, c) >= 5e9 ? 'text-blue-700 font-semibold' : 'text-[#777]'">
                    {{ (sensGP(r, c) / 1e9).toFixed(1) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="text-[10px] text-[#999] mt-2">Asumsi blended margin {{ fmtPct(rev.blendedMargin) }} dari parameter aktif di atas.</p>
        </div>
      </div>
    </div>

    <!-- KFA Price Benchmark Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <div class="flex items-center justify-between mb-3">
        <div>
          <p class="text-xs font-bold text-[#1a1a1a]">KFA Price Intelligence — FORNAS Drug Universe</p>
          <p class="text-[11px] text-[#999] mt-0.5">HAP = Harga Acuan Pemerintah (floor dari Kemkes) · HNA est. = HAP × 1.10 · HET = Harga Eceran Tertinggi (ceiling)</p>
        </div>
        <span class="text-[10px] px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 font-bold border border-emerald-200">LIVE · SUPABASE</span>
      </div>
      <div class="flex flex-wrap gap-1.5 mb-3">
        <button @click="selectedCat = null"
          :class="['text-[10px] px-2.5 py-1 rounded-full font-semibold transition-colors',
            selectedCat === null ? 'bg-[#6b1525] text-white' : 'bg-[#e8e8e8] text-[#555] hover:bg-[#d8d8d8]']">
          All Categories
        </button>
        <button v-for="k in kategoriList.slice(0, 8)" :key="k" @click="selectedCat = k"
          :class="['text-[10px] px-2.5 py-1 rounded-full font-semibold transition-colors',
            selectedCat === k ? 'bg-[#6b1525] text-white' : 'bg-[#e8e8e8] text-[#555] hover:bg-[#d8d8d8]']">
          {{ k }}
        </button>
      </div>

      <div v-if="loadingBench" class="py-8 text-center text-xs text-[#999]">Memuat data KFA dari database...</div>
      <div v-else-if="!benchmarks.length" class="py-8 text-center text-xs text-[#999]">Data KFA tidak tersedia. Pastikan seed kfa_drugs sudah dijalankan.</div>
      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b-2 border-[#e0e0e0]">
              <th class="text-left py-2.5 pr-3 text-[#999] font-bold uppercase tracking-wide text-[10px]">Nama Obat</th>
              <th class="text-left py-2.5 pr-3 text-[#999] font-bold uppercase tracking-wide text-[10px] hidden md:table-cell">Kelas Terapi</th>
              <th class="text-right py-2.5 pr-3 text-[#999] font-bold uppercase tracking-wide text-[10px]">HAP</th>
              <th class="text-right py-2.5 pr-3 text-[#999] font-bold uppercase tracking-wide text-[10px]">HNA est.</th>
              <th class="text-right py-2.5 pr-3 text-[#999] font-bold uppercase tracking-wide text-[10px]">HET</th>
              <th class="text-right py-2.5 text-[#999] font-bold uppercase tracking-wide text-[10px]">Spread</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="b in filteredBench" :key="b.kfa_code"
              class="border-b border-[#ececec] hover:bg-[#ebebeb]/60 transition-colors">
              <td class="py-2.5 pr-3 font-semibold text-[#1a1a1a] max-w-[200px]">
                <p class="truncate" :title="b.name">{{ b.name }}</p>
                <p class="text-[10px] text-[#aaa] font-normal">{{ b.kfa_code }}</p>
              </td>
              <td class="py-2.5 pr-3 text-[#777] hidden md:table-cell text-[11px]">{{ b.kelas_terapi || '—' }}</td>
              <td class="py-2.5 pr-3 text-right text-[#555]">{{ fmtRp(b.fix_price) }}</td>
              <td class="py-2.5 pr-3 text-right font-semibold text-blue-700">{{ fmtRp(b.hna) }}</td>
              <td class="py-2.5 pr-3 text-right font-semibold text-emerald-700">{{ fmtRp(b.het_price) }}</td>
              <td class="py-2.5 text-right">
                <span class="px-2 py-0.5 rounded-md text-[10px] font-bold"
                  :class="b.tier === 'HIGH' ? 'bg-emerald-100 text-emerald-700' : b.tier === 'MID' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-500'">
                  +{{ b.spread_pct.toFixed(1) }}%
                </span>
              </td>
            </tr>
          </tbody>
        </table>
        <div class="flex items-center gap-4 mt-3 text-[10px] text-[#aaa]">
          <span><span class="inline-block w-2 h-2 rounded-sm bg-emerald-200 mr-1"/>HIGH ≥20% spread</span>
          <span><span class="inline-block w-2 h-2 rounded-sm bg-amber-200 mr-1"/>MID 10–20%</span>
          <span><span class="inline-block w-2 h-2 rounded-sm bg-slate-200 mr-1"/>LOW &lt;10%</span>
          <span class="ml-auto">{{ filteredBench.length }} / {{ benchmarks.length }} items shown</span>
        </div>
      </div>
    </div>

    <!-- Deal Structure Framework -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="bg-[#0d0d0d] text-white rounded-xl p-5">
        <p class="text-[10px] uppercase tracking-widest text-white/50 mb-3">Structure I — Spot Supply</p>
        <p class="text-base font-bold text-white mb-3">Transaction-Based Model</p>
        <div class="space-y-2 text-[11px] text-white/70">
          <div class="flex justify-between"><span>Pricing</span><span class="text-white font-semibold">HNA + 12–15%</span></div>
          <div class="flex justify-between"><span>Payment Terms</span><span class="text-white font-semibold">30 hari nett</span></div>
          <div class="flex justify-between"><span>Min. Order</span><span class="text-white font-semibold">Rp 5 jt/PO</span></div>
          <div class="flex justify-between"><span>Risk Level</span><span class="text-amber-400 font-semibold">MEDIUM</span></div>
          <div class="flex justify-between"><span>Net Margin est.</span><span class="text-emerald-400 font-bold">9–12%</span></div>
        </div>
      </div>

      <div class="bg-[#6b1525] text-white rounded-xl p-5 ring-2 ring-[#6b1525]/50">
        <p class="text-[10px] uppercase tracking-widest text-white/70 mb-3">Structure II — RECOMMENDED ★</p>
        <p class="text-base font-bold text-white mb-3">Annual Contract + Service Bundle</p>
        <div class="space-y-2 text-[11px] text-white/80">
          <div class="flex justify-between"><span>Base Pricing</span><span class="text-white font-semibold">HNA + 9–11%</span></div>
          <div class="flex justify-between"><span>Service Fee</span><span class="text-white font-semibold">Rp 5–10 jt/RS/bln</span></div>
          <div class="flex justify-between"><span>Rebate</span><span class="text-white font-semibold">2–3% dari PO vol.</span></div>
          <div class="flex justify-between"><span>Payment Terms</span><span class="text-white font-semibold">45 hari nett</span></div>
          <div class="flex justify-between"><span>Net Margin est.</span><span class="text-amber-300 font-bold">13–18%</span></div>
        </div>
      </div>

      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-5">
        <p class="text-[10px] uppercase tracking-widest text-[#999] mb-3">Structure III — Premium</p>
        <p class="text-base font-bold text-[#1a1a1a] mb-3">Consignment + Full Managed</p>
        <div class="space-y-2 text-[11px] text-[#666]">
          <div class="flex justify-between"><span>Model</span><span class="text-[#1a1a1a] font-semibold">Stok titip di RS</span></div>
          <div class="flex justify-between"><span>Revenue Trigger</span><span class="text-[#1a1a1a] font-semibold">Saat pemakaian RS</span></div>
          <div class="flex justify-between"><span>Service Fee</span><span class="text-[#1a1a1a] font-semibold">Rp 15–25 jt/RS/bln</span></div>
          <div class="flex justify-between"><span>Working Capital</span><span class="text-red-600 font-semibold">HIGH (modal besar)</span></div>
          <div class="flex justify-between"><span>Net Margin est.</span><span class="text-emerald-700 font-bold">18–25%</span></div>
        </div>
      </div>
    </div>

    <!-- Risk Framework -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-4">Risk-Adjusted Strategy Matrix</p>
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b border-[#e0e0e0]">
              <th class="text-left py-2 pr-4 text-[#999] font-semibold">Risk Factor</th>
              <th class="text-left py-2 pr-4 text-[#999] font-semibold">Exposure</th>
              <th class="text-left py-2 pr-4 text-[#999] font-semibold">Mitigation</th>
              <th class="text-right py-2 text-[#999] font-semibold">Impact</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="r in [
              { risk:'AR Aging > 60 hari', exp:'Cashflow squeeze KSM', mit:'SCF facility + BPJS monitoring auto', impact:'HIGH', impactColor:'text-red-600' },
              { risk:'Obat non-FORNAS ditolak BPJS', exp:'RS minta retur stok', mit:'FORNAS compliance check pre-PO', impact:'MEDIUM', impactColor:'text-amber-600' },
              { risk:'Distributor stockout', exp:'KSM gagal deliver', mit:'Multi-supplier sourcing, min 2 opsi', impact:'HIGH', impactColor:'text-red-600' },
              { risk:'Perubahan HET Kemkes', exp:'Margin terkompresi', mit:'Kontrak price-lock + eskalasi klausul', impact:'LOW', impactColor:'text-emerald-600' },
              { risk:'RS ganti vendor', exp:'Revenue concentration', mit:'Lock-in via system integrasi e-Logistik', impact:'MEDIUM', impactColor:'text-amber-600' },
            ]" :key="r.risk" class="border-b border-[#ececec]">
              <td class="py-2.5 pr-4 font-semibold text-[#1a1a1a]">{{ r.risk }}</td>
              <td class="py-2.5 pr-4 text-[#666]">{{ r.exp }}</td>
              <td class="py-2.5 pr-4 text-[#555]">{{ r.mit }}</td>
              <td class="py-2.5 text-right font-bold" :class="r.impactColor">{{ r.impact }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</template>
