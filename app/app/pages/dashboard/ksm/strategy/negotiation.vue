<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Procurement Intelligence — Negosiasi Distributor' })

const supabase = useSupabaseClient()

// ─── KFA Live Benchmark ──────────────────────────────────────────────────────
const kfaItems = ref<any[]>([])
const loadingKfa = ref(true)
const selectedItem = ref<any>(null)

async function loadKfa() {
  const { data } = await supabase.from('kfa_drugs')
    .select('kfa_code,name,fix_price,het_price,kelas_terapi,is_fornas')
    .not('fix_price','is',null).not('het_price','is',null).gt('fix_price',1000).lt('fix_price',5000000)
    .order('fix_price',{ ascending: false }).limit(25)
  kfaItems.value = data ?? []
  if (kfaItems.value.length) selectItem(kfaItems.value[0])
  loadingKfa.value = false
}

function selectItem(item: any) {
  selectedItem.value = item
  calc.hap = Number(item.fix_price)
  calc.het = Number(item.het_price)
}

// ─── Negotiation Calculator ───────────────────────────────────────────────────
const calc = reactive({
  hap: 50_000,       // HAP dari KFA (floor)
  het: 68_000,       // HET dari KFA (ceiling)
  monthly_units: 500, // unit per bulan yang dibeli KSM ke distributor
  tenor_days: 30,    // termin pembayaran saat ini ke distributor (hari)
  wacc: 15,          // WACC KSM (cost of capital, %)
})

const scenarios = computed(() => {
  const hna = calc.hap * 1.10        // HNA estimasi (HAP+10%)
  const jualRS = hna * 1.10          // jual ke RS default (HNA+10%)
  const jualMax = calc.het           // ceiling jual ke RS
  const monthlyPO = hna * calc.monthly_units
  const dailyCost = (calc.wacc / 100 / 365) * monthlyPO

  return [
    // 1. Spot — baseline, tidak ada negosiasi
    {
      id: 1, name: 'Spot Buying', tag: 'Baseline',
      buyPrice: hna,
      sellPrice: jualRS,
      tenor: calc.tenor_days,
      rebate: 0,
      netMarginPct: ((jualRS - hna) / hna) * 100,
      annualGP: (jualRS - hna) * calc.monthly_units * 12,
      financingCost: dailyCost * calc.tenor_days * 12,
      color: 'bg-slate-100 text-slate-700',
      badge: 'bg-slate-200 text-slate-600',
      recommended: false,
    },
    // 2. Extended Terms — bayar 60 hari, beli price sama
    {
      id: 2, name: 'Extended Payment Terms', tag: 'Termin Panjang',
      buyPrice: hna,
      sellPrice: jualRS,
      tenor: 60,
      rebate: 0,
      netMarginPct: ((jualRS - hna) / hna) * 100,
      annualGP: (jualRS - hna) * calc.monthly_units * 12,
      financingCost: dailyCost * 15 * 12, // hemat 15 hari pembiayaan
      color: 'bg-blue-50 text-blue-700',
      badge: 'bg-blue-100 text-blue-700',
      recommended: false,
    },
    // 3. Early Payment Discount — bayar 7 hari, dapat diskon 2%
    {
      id: 3, name: 'Early Payment Discount', tag: '2/7 Net 30',
      buyPrice: hna * 0.98,
      sellPrice: jualRS,
      tenor: 7,
      rebate: 0,
      netMarginPct: ((jualRS - (hna * 0.98)) / (hna * 0.98)) * 100,
      annualGP: (jualRS - (hna * 0.98)) * calc.monthly_units * 12,
      financingCost: dailyCost * 7 * 12,
      color: 'bg-amber-50 text-amber-700',
      badge: 'bg-amber-100 text-amber-700',
      recommended: false,
    },
    // 4. Annual Contract + Volume Rebate
    {
      id: 4, name: 'Annual Contract + Rebate', tag: 'REKOMENDASI ★',
      buyPrice: hna * 0.97,
      sellPrice: jualMax * 0.97,   // jual mendekati HET
      tenor: 45,
      rebate: 3,
      netMarginPct: ((jualMax * 0.97 - hna * 0.97) / (hna * 0.97)) * 100,
      annualGP: (jualMax * 0.97 - hna * 0.97) * calc.monthly_units * 12,
      financingCost: dailyCost * 45 * 12,
      color: 'bg-[#6b1525]/5 border-[#6b1525]/20',
      badge: 'bg-[#6b1525] text-white',
      recommended: true,
    },
    // 5. Consignment
    {
      id: 5, name: 'Consignment Model', tag: 'No Risk Stok',
      buyPrice: hna,
      sellPrice: jualMax * 0.95,
      tenor: 0,   // bayar saat barang terpakai
      rebate: 0,
      netMarginPct: ((jualMax * 0.95 - hna) / hna) * 100,
      annualGP: (jualMax * 0.95 - hna) * calc.monthly_units * 12 * 0.85, // utilization 85%
      financingCost: 0,
      color: 'bg-emerald-50 text-emerald-700',
      badge: 'bg-emerald-100 text-emerald-700',
      recommended: false,
    },
  ]
})

// Best scenario
const bestScenario = computed(() => [...scenarios.value].sort((a,b) =>
  (b.annualGP - b.financingCost) - (a.annualGP - a.financingCost)
)[0])

// ─── Termin Impact Calculator ──────────────────────────────────────────────
const terminAnalysis = computed(() => {
  const hna = calc.hap * 1.10
  const monthlyPO = hna * calc.monthly_units
  const annualPO = monthlyPO * 12
  const dailyRate = calc.wacc / 100 / 365

  return [7, 14, 30, 45, 60, 90].map(days => ({
    days,
    financingCostAnnual: monthlyPO * dailyRate * days * 12,
    cashReleasedMonthly: monthlyPO * (days / 30),
    effectivePricePremium: ((monthlyPO * dailyRate * days) / monthlyPO) * 100,
  }))
})


onMounted(loadKfa)
</script>

<template>
  <div class="space-y-6 pb-10">

    <!-- Header -->
    <div class="flex items-start gap-3">
      <NuxtLink to="/dashboard/ksm/strategy" class="mt-1 text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div class="flex-1">
        <div class="flex items-center gap-3 flex-wrap">
          <h1 class="text-xl font-bold text-[#1a1a1a]">Procurement Intelligence</h1>
          <span class="text-[10px] px-2.5 py-1 rounded-full bg-blue-700 text-white font-bold tracking-widest">NEGOSIASI DISTRIBUTOR</span>
        </div>
        <p class="text-sm text-[#777] mt-0.5">Multi-scenario deal framework berbasis harga KFA real — term sheet, NPV, dan payment terms analysis</p>
      </div>
    </div>

    <!-- KFA Item Selector + Live Stats -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <div class="lg:col-span-1 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <div class="flex items-center justify-between mb-3">
          <p class="text-xs font-bold text-[#1a1a1a]">Pilih Item KFA</p>
          <span class="text-[10px] text-emerald-600 font-semibold">LIVE DB</span>
        </div>
        <div v-if="loadingKfa" class="text-center py-4 text-xs text-[#999]">Loading KFA...</div>
        <div v-else class="space-y-1 max-h-48 overflow-y-auto pr-1">
          <button v-for="item in kfaItems" :key="item.kfa_code"
            @click="selectItem(item)"
            :class="['w-full text-left px-3 py-2 rounded-lg text-[11px] transition-colors',
              selectedItem?.kfa_code === item.kfa_code
                ? 'bg-[#6b1525] text-white font-semibold'
                : 'hover:bg-[#e8e8e8] text-[#555]']">
            <p class="font-semibold truncate">{{ item.name }}</p>
            <p class="text-[10px] opacity-70">HAP {{ fmtRp(Number(item.fix_price)) }} · HET {{ fmtRp(Number(item.het_price)) }}</p>
          </button>
        </div>
      </div>

      <div class="lg:col-span-2 bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-5">
        <p class="text-[10px] uppercase tracking-widest text-[#999] mb-4">Selected Item — KFA Benchmark</p>
        <div v-if="selectedItem" class="space-y-3">
          <p class="text-base font-bold text-[#1a1a1a]">{{ selectedItem.name }}</p>
          <p class="text-[11px] text-[#777]">{{ selectedItem.kelas_terapi }} · FORNAS · KFA {{ selectedItem.kfa_code }}</p>
          <div class="grid grid-cols-3 gap-3 mt-4">
            <div class="bg-[#ebebeb] rounded-lg p-3">
              <p class="text-[10px] text-[#999] mb-1">HAP (Floor)</p>
              <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRp(calc.hap) }}</p>
              <p class="text-[10px] text-[#aaa] mt-0.5">Kemkes Reference</p>
            </div>
            <div class="bg-[#ebebeb] rounded-lg p-3">
              <p class="text-[10px] text-[#999] mb-1">HNA est.</p>
              <p class="text-lg font-bold text-blue-700">{{ fmtRp(calc.hap * 1.10) }}</p>
              <p class="text-[10px] text-[#aaa] mt-0.5">HAP × 1.10 (target beli)</p>
            </div>
            <div class="bg-[#ebebeb] rounded-lg p-3">
              <p class="text-[10px] text-[#999] mb-1">HET (Ceiling)</p>
              <p class="text-lg font-bold text-emerald-700">{{ fmtRp(calc.het) }}</p>
              <p class="text-[10px] text-[#aaa] mt-0.5">Max jual ke RS</p>
            </div>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3 mt-2">
            <p class="text-[10px] text-[#999] mb-1">Maximum Spread (HNA → HET)</p>
            <p class="text-xl font-bold text-[#6b1525]">
              +{{ (((calc.het - calc.hap * 1.10) / (calc.hap * 1.10)) * 100).toFixed(1) }}%
              <span class="text-sm font-normal text-[#777] ml-2">= {{ fmtRp(calc.het - calc.hap * 1.10) }} / unit</span>
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Calculator Params -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-4">Scenario Parameters</p>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">HAP (KFA Reference)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtRp(calc.hap) }}</span>
          </div>
          <input type="range" v-model.number="calc.hap" :min="5000" :max="500000" :step="1000" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">HET (Ceiling)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtRp(calc.het) }}</span>
          </div>
          <input type="range" v-model.number="calc.het" :min="calc.hap" :max="calc.hap * 3" :step="1000" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">Volume / Bulan (unit)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ calc.monthly_units.toLocaleString('id') }} unit</span>
          </div>
          <input type="range" v-model.number="calc.monthly_units" min="50" max="5000" step="50" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">WACC KSM (%/tahun)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ calc.wacc }}%</span>
          </div>
          <input type="range" v-model.number="calc.wacc" min="8" max="24" step="1" class="w-full accent-[#6b1525]"/>
        </div>
      </div>
    </div>

    <!-- 5 Scenario Cards -->
    <div>
      <p class="text-xs font-bold text-[#1a1a1a] mb-3">Deal Scenario Analysis — Annual Gross Profit (after financing cost)</p>
      <div class="grid grid-cols-1 md:grid-cols-5 gap-3">
        <div v-for="s in scenarios" :key="s.id"
          :class="['rounded-xl p-4 border transition-all bg-[#f5f5f5]', s.recommended ? 'border-2 border-[#6b1525]' : 'border-[#e5e5e5]']">
          <span :class="['text-[10px] px-2 py-0.5 rounded-full font-bold mb-3 inline-block', s.badge]">
            {{ s.tag }}
          </span>
          <p class="text-xs font-bold mb-3 text-[#1a1a1a]">{{ s.name }}</p>
          <div class="space-y-1.5">
            <div class="flex justify-between text-[11px]">
              <span class="text-[#999]">Harga Beli</span>
              <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(s.buyPrice) }}</span>
            </div>
            <div class="flex justify-between text-[11px]">
              <span class="text-[#999]">Harga Jual RS</span>
              <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(s.sellPrice) }}</span>
            </div>
            <div class="flex justify-between text-[11px]">
              <span class="text-[#999]">Net Margin</span>
              <span class="font-bold text-emerald-700">{{ fmtPct(s.netMarginPct) }}</span>
            </div>
            <div class="flex justify-between text-[11px]">
              <span class="text-[#999]">Termin</span>
              <span class="font-semibold text-[#555]">{{ s.tenor }} hari</span>
            </div>
            <div class="border-t border-[#ddd] pt-1.5 mt-1.5">
              <div class="flex justify-between text-[11px]">
                <span class="text-[#999]">GP Bruto/thn</span>
                <span class="font-semibold text-[#555]">{{ fmtRp(s.annualGP) }}</span>
              </div>
              <div class="flex justify-between text-[11px] mt-0.5">
                <span class="text-[#999]">Fin. Cost/thn</span>
                <span class="font-semibold text-red-600">-{{ fmtRp(s.financingCost) }}</span>
              </div>
              <div class="flex justify-between text-[11px] mt-1 font-bold">
                <span class="text-[#333]">Net GP/thn</span>
                <span class="text-emerald-700 text-sm">
                  {{ fmtRp(s.annualGP - s.financingCost) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="mt-3 flex items-center gap-2 bg-emerald-50 border border-emerald-200 rounded-lg px-4 py-2.5">
        <UIcon name="i-lucide-trophy" class="text-emerald-600 text-sm flex-shrink-0"/>
        <p class="text-xs text-emerald-800">
          <strong>Best Deal:</strong> {{ bestScenario.name }} menghasilkan net GP tahunan terbesar —
          <strong>{{ fmtRp(bestScenario.annualGP - bestScenario.financingCost) }}</strong>
          (margin {{ fmtPct(bestScenario.netMarginPct) }}, termin {{ bestScenario.tenor }} hari).
        </p>
      </div>
    </div>

    <!-- Payment Terms Impact Analysis -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-1">Payment Terms Sensitivity — Impact terhadap Working Capital KSM</p>
      <p class="text-[11px] text-[#999] mb-4">WACC {{ calc.wacc }}%/thn. Semakin panjang termin bayar ke distributor → semakin rendah financing cost KSM.</p>
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b-2 border-[#e0e0e0]">
              <th class="text-left py-2 pr-4 text-[#999] font-bold uppercase text-[10px]">Termin (hari)</th>
              <th class="text-right py-2 pr-4 text-[#999] font-bold uppercase text-[10px]">Financing Cost / Thn</th>
              <th class="text-right py-2 pr-4 text-[#999] font-bold uppercase text-[10px]">Cash Released / Bln</th>
              <th class="text-right py-2 text-[#999] font-bold uppercase text-[10px]">Effective Price Premium</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in terminAnalysis" :key="row.days"
              :class="['border-b border-[#ececec]', row.days === 45 ? 'bg-amber-50' : '']">
              <td class="py-2.5 pr-4 font-bold" :class="row.days === 45 ? 'text-amber-700' : 'text-[#1a1a1a]'">
                {{ row.days }} hari <span v-if="row.days === 45" class="text-[10px] text-amber-600">(target)</span>
              </td>
              <td class="py-2.5 pr-4 text-right" :class="row.days >= 60 ? 'text-red-600 font-semibold' : 'text-[#555]'">
                {{ fmtRp(row.financingCostAnnual) }}
              </td>
              <td class="py-2.5 pr-4 text-right text-emerald-700 font-semibold">{{ fmtRp(row.cashReleasedMonthly) }}</td>
              <td class="py-2.5 text-right">
                <span class="text-[10px] px-2 py-0.5 rounded-md font-bold"
                  :class="row.effectivePricePremium < 1 ? 'bg-emerald-100 text-emerald-700' : row.effectivePricePremium < 2 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'">
                  +{{ row.effectivePricePremium.toFixed(2) }}%
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Negotiation Term Sheet Template -->
    <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-6">
      <div class="flex items-center gap-3 mb-5">
        <p class="text-[10px] uppercase tracking-widest text-[#999]">Term Sheet Template</p>
        <span class="text-[10px] px-2 py-0.5 rounded-full bg-[#e0e0e0] text-[#666]">Annual Contract Structure</span>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="space-y-3">
          <p class="text-xs font-bold text-[#999] uppercase tracking-wide mb-2">Commercial Terms</p>
          <div v-for="row in [
            { k:'Product Scope', v:'Semua item FORNAS + selected non-FORNAS sesuai kebutuhan RS mitra' },
            { k:'Base Price', v:'HNA (HAP × 1.10) dengan cap maksimal HET Kemkes' },
            { k:'Volume Commitment', v:'Min. 80% dari total kebutuhan farmasi RS mitra per bulan' },
            { k:'Rebate Structure', v:'2% @ 90% target · 3% @ 100% target · 4% @ 110% target' },
            { k:'Price Lock Period', v:'12 bulan, eskalasi max 5% per tahun setelah review' },
          ]" :key="row.k" class="flex gap-3 text-[11px]">
            <span class="text-[#999] w-36 flex-shrink-0">{{ row.k }}</span>
            <span class="text-[#1a1a1a]">{{ row.v }}</span>
          </div>
        </div>
        <div class="space-y-3">
          <p class="text-xs font-bold text-[#999] uppercase tracking-wide mb-2">Financial Terms</p>
          <div v-for="row in [
            { k:'Payment Terms', v:'Net 45 hari dari tanggal invoice + GR konfirmasi sistem' },
            { k:'Early Payment', v:'Diskon 1.5% jika dibayar dalam 7 hari (2/7 net 45)' },
            { k:'Penalty Clause', v:'Denda 0.1%/hari jika keterlambatan delivery > 3 hari' },
            { k:'Consignment', v:'Stok titip untuk top-10 fast-moving items, bayar saat usage' },
            { k:'SCF Integration', v:'Bank X menjadi offtaker AR distributor via reverse factoring' },
          ]" :key="row.k" class="flex gap-3 text-[11px]">
            <span class="text-[#999] w-36 flex-shrink-0">{{ row.k }}</span>
            <span class="text-[#1a1a1a]">{{ row.v }}</span>
          </div>
        </div>
      </div>
      <div class="mt-5 pt-4 border-t border-[#e0e0e0]">
        <p class="text-[10px] text-[#999] uppercase tracking-wide mb-2">Why Distributor Should Accept This</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 text-[11px]">
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-[#1a1a1a] font-semibold mb-1">Guaranteed Volume</p>
            <p class="text-[#666]">KSM mengaggregasi demand dari multiple RS → satu contract menggantikan banyak transaksi kecil</p>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-[#1a1a1a] font-semibold mb-1">SCF Liquidity</p>
            <p class="text-[#666]">Bank langsung bayar distributor via reverse factoring → distributor tidak perlu tunggu 45 hari</p>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-[#1a1a1a] font-semibold mb-1">Digital Audit Trail</p>
            <p class="text-[#666]">Sistem e-Logistik → PO digital, GR digital, invoice otomatis → compliance distributor meningkat</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Terminologi Negosiasi -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#666] uppercase tracking-wide mb-3">Terminologi Procurement & Negosiasi</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-[10px]">
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">HNA (Harga Netto Apotek):</strong> Harga jual distributor ke apotek/RS. Biasanya HAP + 8-15% markup distributor. Ini yang dinegosiasi KSM — target: sedekat mungkin ke HAP.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Payment Terms (Net 30/45/60):</strong> Jangka waktu pembayaran. KSM pakai SCF Bank → distributor dibayar D+1 (bukan Net 45). Ini leverage negosiasi kuat — distributor dapat cash cepat.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Volume Rebate:</strong> Potongan harga retroaktif jika KSM capai target volume tahunan. Biasanya 2-4% dari total pembelian. Dihitung akhir tahun, dibayar sebagai credit note.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Early Payment Discount:</strong> Distributor beri diskon 1-3% jika dibayar < 7 hari. Dengan SCF Bank (D+1 payment), KSM selalu eligible — pure margin tambahan.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Consignment:</strong> Distributor titip stok di gudang RS/KSM, baru bayar saat terpakai. Zero inventory cost untuk KSM, tapi margin lebih tipis. Cocok untuk item fast-moving.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">NPV (Net Present Value):</strong> Nilai uang sekarang dari cashflow masa depan. Skenario dengan NPV tertinggi = paling menguntungkan. Discount rate = bunga SCF Bank.
        </div>
      </div>
    </div>

  </div>
</template>
