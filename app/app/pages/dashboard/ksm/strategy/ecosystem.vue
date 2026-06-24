<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Ecosystem Value Proposition' })

const supabase = useSupabaseClient()
const { apiGet } = useApi()
const { tenantId } = useUserRole()

const realKPI = ref<any>(null)

async function loadReal() {
  if (!tenantId.value) return
  const dashData = await apiGet<{ kpi: any }>('/api/ksm/dashboard')
  realKPI.value = dashData.kpi
  const data = dashData.kpi
  // Kalibrasi simulasi dari data real
  if (data) {
    if (Number(data.scf_limit) > 0) eco.facility_limit = Number(data.scf_limit)
    if (Number(data.revenue_total) > 0) {
      eco.monthly_vol_per_rs = Math.round(Number(data.revenue_total) / 12 / eco.num_rs)
    }
  }
}

watch(tenantId, (id) => { if (id) loadReal() })
onMounted(() => { if (tenantId.value) loadReal() })

// ─── Shared financial assumptions (dikalibrasi dari data real) ──────────────
const eco = reactive({
  num_rs: 5,
  monthly_vol_per_rs: 500_000_000,
  ksm_margin_pct: 12,
  dist_margin_pct: 8,
  bank_rate_pa: 11,
  rs_efficiency_pct: 8,
  bpjs_monthly_per_rs: 2_000_000_000,
  facility_limit: 3_000_000_000,
})

const calc = computed(() => {
  const totalMonthly = eco.num_rs * eco.monthly_vol_per_rs
  const totalAnnual  = totalMonthly * 12
  const ksmGP        = totalAnnual  * (eco.ksm_margin_pct / 100)
  const distGP       = totalAnnual  * (eco.dist_margin_pct / 100)
  const bankRevenue  = eco.facility_limit * (eco.bank_rate_pa / 100)
         + totalAnnual * 0.005   // admin fee 0.5%
  const rsSavings    = totalAnnual * (eco.rs_efficiency_pct / 100)
  const totalEcoValue = ksmGP + distGP + bankRevenue + rsSavings

  return { totalMonthly, totalAnnual, ksmGP, distGP, bankRevenue, rsSavings, totalEcoValue }
})


const parties = computed(() => [
  {
    id: 'rs',
    name: 'Rumah Sakit',
    icon: 'i-lucide-hospital',
    color: 'text-emerald-600', bg: 'bg-emerald-50', bar: 'bg-emerald-500',
    tagColor: 'bg-emerald-100 text-emerald-700',
    headline: fmtRp(calc.value.rsSavings) + '/thn',
    headlineLabel: 'Penghematan Operasional/Thn',
    value: calc.value.rsSavings,
    roi_pct: (calc.value.rsSavings / calc.value.totalAnnual) * 100,
    benefits: [
      { label:'Eliminasi Stockout', value:'~Rp 2–5 jt kerugian/kejadian dihindari', icon:'i-lucide-package-check' },
      { label:'Efisiensi Farmasi', value:`${fmtPct(eco.rs_efficiency_pct)} penghematan biaya farmasi via FORNAS compliance`, icon:'i-lucide-pill' },
      { label:'Bayar Saat Terpakai', value:'Model konsinyasi → tidak perlu modal kerja untuk stok', icon:'i-lucide-credit-card' },
      { label:'Klaim BPJS Lebih Lancar', value:'Obat FORNAS → lolos klaim INA-CBGs, kurangi reject BPJS', icon:'i-lucide-shield-check' },
      { label:'Satu Vendor, Semua Kategori', value:'Obat + BMHP + Alkes dari satu mitra → efisiensi administrasi', icon:'i-lucide-layers' },
      { label:'Digital Audit Trail', value:'Semua transaksi terdokumentasi → siap inspeksi BPJS & KPPU', icon:'i-lucide-file-check' },
    ],
    insight: `Dengan ${eco.num_rs} RS mitra dan volume ${fmtRp(eco.monthly_vol_per_rs)}/bulan, setiap RS berpotensi menghemat ${fmtRp(eco.monthly_vol_per_rs * eco.rs_efficiency_pct / 100)}/bulan dari optimasi formularium, eliminasi stockout, dan efisiensi vendor.`,
  },
  {
    id: 'ksm',
    name: 'KSM (Agregator)',
    icon: 'i-lucide-network',
    color: 'text-[#6b1525]', bg: 'bg-red-50', bar: 'bg-[#6b1525]',
    tagColor: 'bg-red-100 text-[#6b1525]',
    headline: fmtRp(calc.value.ksmGP) + '/thn',
    headlineLabel: 'Gross Profit KSM/Thn',
    value: calc.value.ksmGP,
    roi_pct: eco.ksm_margin_pct,
    benefits: [
      { label:'Margin Supply Barang', value:`HNA + 9–15% tergantung kategori`, icon:'i-lucide-trending-up' },
      { label:'Service Fee Managed Logistics', value:'Rp 5–10 jt/RS/bulan (pure profit, no COGS)', icon:'i-lucide-settings' },
      { label:'Volume Rebate Distributor', value:'2–4% dari total PO jika target volume tercapai', icon:'i-lucide-gift' },
      { label:'Fasilitas SCF dari Bank', value:'Modal kerja terjamin → KSM tidak perlu modal besar sendiri', icon:'i-lucide-landmark' },
      { label:'Data-Driven Advantage', value:'Real-time demand forecast → zero overstock, zero stockout', icon:'i-lucide-bar-chart-2' },
      { label:'Leverage Network Effect', value:'Setiap RS baru tambah → COGS makin rendah (volume discount)', icon:'i-lucide-users' },
    ],
    insight: `Blended margin ${eco.ksm_margin_pct}% dari volume ${fmtRp(calc.value.totalAnnual)}/tahun menghasilkan gross profit ${fmtRp(calc.value.ksmGP)}/tahun. Ditambah service fee dan rebate, effective margin KSM bisa mencapai 15–20%.`,
  },
  {
    id: 'distributor',
    name: 'Distributor / PBF',
    icon: 'i-lucide-truck',
    color: 'text-blue-700', bg: 'bg-blue-50', bar: 'bg-blue-600',
    tagColor: 'bg-blue-100 text-blue-700',
    headline: fmtRp(calc.value.distGP) + '/thn',
    headlineLabel: 'Gross Profit Distributor/Thn',
    value: calc.value.distGP,
    roi_pct: eco.dist_margin_pct,
    benefits: [
      { label:'Guaranteed Volume', value:`${fmtRp(calc.value.totalAnnual)} PO tahunan dari satu agregator`, icon:'i-lucide-package' },
      { label:'Instant Liquidity via SCF', value:'Bank bayar D+1 setelah GR konfirmasi — tidak perlu tunggu 45 hari', icon:'i-lucide-zap' },
      { label:'Efisiensi Penjualan', value:'Satu kontrak KSM menggantikan 5–20 akun RS terpisah', icon:'i-lucide-file-contract' },
      { label:'Pengurangan AR Risk', value:'KSM + Bank menjamin pembayaran — zero bad debt risk', icon:'i-lucide-shield' },
      { label:'Digital Integration', value:'PO otomatis masuk sistem → tidak ada manual entry error', icon:'i-lucide-git-branch' },
      { label:'Forecasting Akurat', value:'Data demand real-time KSM → distributor bisa optimalkan stok', icon:'i-lucide-activity' },
    ],
    insight: `Distributor mendapatkan guaranteed volume ${fmtRp(calc.value.totalAnnual)}/tahun dengan pembayaran dipercepat via SCF. Tidak perlu modal kerja untuk AR — Bank yang menanggung. Efisiensi penjualan meningkat drastis.`,
  },
  {
    id: 'bank',
    name: 'Bank / Fintech',
    icon: 'i-lucide-landmark',
    color: 'text-amber-700', bg: 'bg-amber-50', bar: 'bg-amber-600',
    tagColor: 'bg-amber-100 text-amber-700',
    headline: fmtRp(calc.value.bankRevenue) + '/thn',
    headlineLabel: 'Total Bank Revenue/Thn',
    value: calc.value.bankRevenue,
    roi_pct: (calc.value.bankRevenue / eco.facility_limit) * 100,
    benefits: [
      { label:'Interest Income', value:`${eco.bank_rate_pa}% p.a. × ${fmtRp(eco.facility_limit)} = ${fmtRp(eco.facility_limit * eco.bank_rate_pa/100)}/thn`, icon:'i-lucide-percent' },
      { label:'Admin & Transaction Fee', value:`0.5% × ${fmtRp(calc.value.totalAnnual)} PO = ${fmtRp(calc.value.totalAnnual*0.005)}/thn`, icon:'i-lucide-receipt' },
      { label:'Self-Liquidating Loan', value:'Risiko minimal — dana follow PO terverifikasi ke underlying asset', icon:'i-lucide-rotate-ccw' },
      { label:'BPJS Collateral', value:`${fmtRp(eco.bpjs_monthly_per_rs * eco.num_rs * 12 * 0.40)}/thn quasi-government coverage`, icon:'i-lucide-shield-check' },
      { label:'Real-time Risk Monitoring', value:'API TransLOG-X → Bank lihat setiap transaksi real-time, no blind spot', icon:'i-lucide-eye' },
      { label:'Regulatory Compliance', value:'Sesuai POJK 57/2020 SCF — mendapat apresiasi OJK untuk sektor kesehatan', icon:'i-lucide-check-circle' },
    ],
    insight: `Yield on deployed capital ${fmtPct((calc.value.bankRevenue / eco.facility_limit)*100)} dari fasilitas ${fmtRp(eco.facility_limit)}. DSCR ${(calc.value.ksmGP / (eco.facility_limit * eco.bank_rate_pa/100)).toFixed(2)}x — jauh di atas threshold bankable 1.5x. BPJS sebagai quasi-government collateral menjadikan ini kredit dengan risk profile sektor publik.`,
  },
])

const totalEcoBar = computed(() => {
  const maxVal = Math.max(...parties.value.map(p => p.value))
  return parties.value.map(p => ({ ...p, barPct: (p.value / maxVal) * 100 }))
})
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
          <h1 class="text-xl font-bold text-[#1a1a1a]">Ecosystem Value Proposition</h1>
          <span class="text-[10px] px-2.5 py-1 rounded-full bg-[#6b1525] text-white font-bold tracking-widest">ALL STAKEHOLDERS</span>
        </div>
        <p class="text-sm text-[#777] mt-0.5">Analisis keuntungan finansial konkret untuk setiap pihak dalam ekosistem e-Logistik — RS, KSM, Distributor, dan Bank</p>
      </div>
    </div>

    <!-- Total Ecosystem Value -->
    <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-6">
      <p class="text-[10px] uppercase tracking-[0.2em] text-[#999] mb-2">Total Ecosystem Value Created — Annual</p>
      <div class="flex items-end gap-4 mb-5">
        <p class="text-3xl font-bold text-[#1a1a1a]">{{ fmtRp(calc.totalEcoValue) + '/thn' }}</p>
        <p class="text-sm text-[#999] mb-1">dibagi ke semua pihak — tidak ada zero-sum game</p>
      </div>
      <div class="space-y-2">
        <div v-for="p in totalEcoBar" :key="p.id" class="flex items-center gap-3">
          <span class="text-[11px] text-[#666] w-32 flex-shrink-0">{{ p.name }}</span>
          <div class="flex-1 bg-[#e0e0e0] rounded-full h-3">
            <div :class="[p.bar, 'h-3 rounded-full transition-all duration-500']" :style="{ width: p.barPct + '%' }"/>
          </div>
          <span class="text-[11px] font-bold text-[#1a1a1a] w-32 text-right flex-shrink-0">{{ fmtRp(p.value) }}/thn</span>
        </div>
      </div>
    </div>

    <!-- Global Parameters -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-4">Simulasi Parameter — Semua Pihak</p>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">Jumlah RS Mitra</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ eco.num_rs }} RS</span>
          </div>
          <input type="range" v-model.number="eco.num_rs" min="1" max="20" step="1" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">Vol. per RS/Bulan</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ fmtRp(eco.monthly_vol_per_rs) }}</span>
          </div>
          <input type="range" v-model.number="eco.monthly_vol_per_rs" :min="100_000_000" :max="2_000_000_000" :step="50_000_000" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">Margin KSM (%)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ eco.ksm_margin_pct }}%</span>
          </div>
          <input type="range" v-model.number="eco.ksm_margin_pct" min="5" max="25" step="0.5" class="w-full accent-[#6b1525]"/>
        </div>
        <div>
          <div class="flex justify-between mb-1">
            <label class="text-[11px] text-[#666]">Suku Bunga Bank (%)</label>
            <span class="text-[11px] font-bold text-[#6b1525]">{{ eco.bank_rate_pa }}%</span>
          </div>
          <input type="range" v-model.number="eco.bank_rate_pa" min="6" max="20" step="0.5" class="w-full accent-[#6b1525]"/>
        </div>
      </div>
    </div>

    <!-- 4 Party Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
      <div v-for="p in parties" :key="p.id"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">

        <!-- Card header -->
        <div class="px-5 py-4 flex items-center justify-between"
          :class="p.id === 'ksm' ? 'bg-[#6b1525]' : p.id === 'bank' ? 'bg-amber-700' : 'bg-white border-b border-[#e5e5e5]'">
          <div class="flex items-center gap-3">
            <div :class="[p.id === 'ksm' || p.id === 'bank' ? 'bg-white/10' : p.bg, 'w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0']">
              <UIcon :name="p.icon" :class="[p.id === 'ksm' || p.id === 'bank' ? 'text-white' : p.color, 'text-xl']"/>
            </div>
            <div>
              <p :class="['text-sm font-bold', p.id === 'ksm' || p.id === 'bank' ? 'text-white' : 'text-[#1a1a1a]']">{{ p.name }}</p>
              <p :class="['text-[10px]', p.id === 'ksm' || p.id === 'bank' ? 'text-white/50' : 'text-[#999]']">Keuntungan dalam ekosistem e-Logistik</p>
            </div>
          </div>
          <div class="text-right">
            <p :class="['text-lg font-bold', p.id === 'ksm' ? 'text-amber-300' : p.id === 'bank' ? 'text-amber-400' : p.color]">
              {{ fmtRp(p.value) }}
            </p>
            <p :class="['text-[10px]', p.id === 'ksm' || p.id === 'bank' ? 'text-white/40' : 'text-[#777]']">{{ p.headlineLabel }}</p>
          </div>
        </div>

        <!-- Benefits list -->
        <div class="p-5">
          <div class="space-y-2.5 mb-4">
            <div v-for="b in p.benefits" :key="b.label" class="flex items-start gap-3">
              <div :class="[p.bg, 'w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5']">
                <UIcon :name="b.icon" :class="[p.color, 'text-sm']"/>
              </div>
              <div>
                <p class="text-[11px] font-bold text-[#1a1a1a]">{{ b.label }}</p>
                <p class="text-[10px] text-[#777]">{{ b.value }}</p>
              </div>
            </div>
          </div>

          <!-- ROI bar -->
          <div class="bg-white border border-[#e8e8e8] rounded-xl p-3">
            <div class="flex justify-between items-center mb-2">
              <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide">ROI / Effective Margin</p>
              <span :class="['text-sm font-bold', p.color]">{{ fmtPct(p.roi_pct) }}</span>
            </div>
            <div class="bg-[#e8e8e8] rounded-full h-2">
              <div :class="[p.bar, 'h-2 rounded-full transition-all duration-500']"
                :style="{ width: Math.min(100, p.roi_pct * 3) + '%' }"/>
            </div>
          </div>

          <!-- Insight box -->
          <div :class="[p.bg, 'rounded-xl p-3 mt-3 border', p.tagColor.includes('emerald') ? 'border-emerald-200' : p.tagColor.includes('blue') ? 'border-blue-200' : p.tagColor.includes('amber') ? 'border-amber-200' : 'border-red-200']">
            <p class="text-[10px] font-bold uppercase tracking-wide mb-1" :class="p.color">Insight Finansial</p>
            <p class="text-[11px] leading-relaxed text-[#555]">{{ p.insight }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Win-Win Summary Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-4">Win-Win Matrix — Siapa Dapat Apa dari TransLOG-X</p>
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b-2 border-[#e0e0e0]">
              <th class="text-left py-2.5 pr-4 text-[#999] font-bold text-[10px] uppercase">Pihak</th>
              <th class="text-left py-2.5 pr-4 text-[#999] font-bold text-[10px] uppercase">Keuntungan Utama</th>
              <th class="text-right py-2.5 pr-4 text-[#999] font-bold text-[10px] uppercase">Nilai Finansial / Thn</th>
              <th class="text-right py-2.5 text-[#999] font-bold text-[10px] uppercase">ROI</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in parties" :key="p.id" class="border-b border-[#ececec] hover:bg-[#ebebeb]/50">
              <td class="py-3 pr-4">
                <div class="flex items-center gap-2">
                  <UIcon :name="p.icon" :class="[p.color, 'text-base']"/>
                  <span class="font-bold text-[#1a1a1a]">{{ p.name }}</span>
                </div>
              </td>
              <td class="py-3 pr-4 text-[#555]">{{ p.benefits[0].label }} + {{ p.benefits[1].label }}</td>
              <td class="py-3 pr-4 text-right font-bold text-[#1a1a1a]">{{ fmtRp(p.value) }}</td>
              <td class="py-3 text-right">
                <span :class="['px-2 py-0.5 rounded-md text-[10px] font-bold', p.tagColor]">
                  {{ fmtPct(p.roi_pct) }}
                </span>
              </td>
            </tr>
            <tr style="background: linear-gradient(135deg, #6b1525 0%, #1a1a1a 100%)" class="text-white">
              <td class="py-3 pr-4 rounded-bl-xl">
                <p class="font-bold text-sm">TOTAL EKOSISTEM</p>
              </td>
              <td class="py-3 pr-4 text-white/50">Nilai ekonomi total yang diciptakan sistem</td>
              <td class="py-3 pr-4 text-right font-bold text-xl text-amber-400">{{ fmtRp(calc.totalEcoValue) }}</td>
              <td class="py-3 text-right rounded-br-xl">
                <span class="text-emerald-400 font-bold text-sm">ALL WIN</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Terminologi -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#666] uppercase tracking-wide mb-3">Catatan Terminologi</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-[10px]">
        <p class="p-2 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Gross Profit KSM:</strong> Selisih invoice ke RS (harga jual) dengan disbursement Bank ke Distributor (harga beli). Bank yang bayar Distributor atas nama KSM via SCF.
        </p>
        <p class="p-2 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Bank Revenue:</strong> Bunga SCF (p.a.) + admin fee. Self-liquidating karena dana mengikuti PO terverifikasi. BPJS sebagai collateral quasi-government.
        </p>
        <p class="p-2 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">RS Savings:</strong> Penghematan dari eliminasi stockout, compliance FORNAS (klaim BPJS lancar), dan efisiensi satu vendor untuk semua kategori.
        </p>
        <p class="p-2 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Distributor Benefit:</strong> Volume terjamin + pembayaran D+1 via SCF (bukan Net 45). Zero bad debt karena Bank + RS menjamin.
        </p>
      </div>
    </div>

  </div>
</template>
