<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Credit Memo — SCF Proposal ke Bank' })

const supabase = useSupabaseClient()

// ─── Real data from DB ────────────────────────────────────────────────────────
const realData = ref({ totalPOs: 0, totalARValue: 0, avgARTenor: 30, totalInterestEarned: 0, activeMitras: 0 })

async function loadRealData() {
  const [{ data: pos }, { data: ar }, { data: fac }] = await Promise.all([
    supabase.from('ksm_purchase_orders').select('total_amount'),
    supabase.from('ar_accounts').select('invoice_amount, interest_amount, disbursement_date, paid_date'),
    supabase.from('scf_facilities').select('borrower_tenant_id').eq('status','approved'),
  ])
  const totalARVal = (ar ?? []).reduce((s, a) => s + Number(a.invoice_amount ?? 0), 0)
  const totalInterest = (ar ?? []).reduce((s, a) => s + Number(a.interest_amount ?? 0), 0)
  const paidAR = (ar ?? []).filter(a => a.disbursement_date && a.paid_date)
  const avgTenor = paidAR.length > 0
    ? paidAR.reduce((s,a) => s + Math.max(0,(new Date(a.paid_date).getTime()-new Date(a.disbursement_date).getTime())/86400000),0) / paidAR.length
    : 30

  realData.value = {
    totalPOs: (pos ?? []).length,
    totalARValue: totalARVal,
    avgARTenor: Math.round(avgTenor),
    totalInterestEarned: totalInterest,
    activeMitras: new Set((fac ?? []).map((f:any) => f.borrower_tenant_id)).size,
  }
  if (totalARVal > 0) params.monthly_po_value = Math.round(totalARVal / 12)
}

// ─── Financial Model Params ───────────────────────────────────────────────────
const params = reactive({
  monthly_po_value: 500_000_000,
  gross_margin_pct: 12,
  num_rs_mitra: 5,
  avg_ar_tenor: 30,
  bpjs_monthly_per_rs: 2_000_000_000,
  facility_limit_requested: 3_000_000_000,
  interest_rate_pa: 11,
  admin_fee_pct: 0.5,
  risk_coverage_pct: 40,
})

const model = computed(() => {
  const m = params
  const annual_po        = m.monthly_po_value * 12
  const annual_gp        = annual_po * (m.gross_margin_pct / 100)
  const interest_income  = m.facility_limit_requested * (m.interest_rate_pa / 100)
  const admin_fee_income = annual_po * (m.admin_fee_pct / 100)
  const total_bank_rev   = interest_income + admin_fee_income
  const bpjs_cashflow    = m.bpjs_monthly_per_rs * m.num_rs_mitra * 12
  const bpjs_collateral  = bpjs_cashflow * (m.risk_coverage_pct / 100)
  const collateral_cover = bpjs_collateral / m.facility_limit_requested
  const dscr             = annual_gp / interest_income
  const ltv              = m.facility_limit_requested / (annual_po * 3)
  const multiplier       = annual_po / m.facility_limit_requested
  const roe_bank_est     = (total_bank_rev / m.facility_limit_requested) * 100   // yield on deployed capital
  const risk_weight      = collateral_cover >= 1.5 ? 'LOW' : collateral_cover >= 1.0 ? 'MEDIUM' : 'HIGH'

  return {
    annual_po, annual_gp, interest_income, admin_fee_income, total_bank_rev,
    bpjs_cashflow, bpjs_collateral, collateral_cover, dscr, ltv, multiplier, roe_bank_est,
    risk_weight,
  }
})

// Scorecard pass/fail
const scorecard = computed(() => [
  { metric:'DSCR', value: model.value.dscr.toFixed(2)+'x', threshold:'≥ 1.5x', pass: model.value.dscr >= 1.5, desc:'Kemampuan bayar bunga dari gross profit' },
  { metric:'Collateral Coverage', value: model.value.collateral_cover.toFixed(2)+'x', threshold:'≥ 1.2x', pass: model.value.collateral_cover >= 1.2, desc:'BPJS cashflow vs limit fasilitas' },
  { metric:'LTV (Loan-to-Value)', value: (model.value.ltv*100).toFixed(1)+'%', threshold:'≤ 80%', pass: model.value.ltv <= 0.80, desc:'Limit vs 3× volume PO tahunan' },
  { metric:'Transaction Multiplier', value: model.value.multiplier.toFixed(1)+'x', threshold:'≥ 3x', pass: model.value.multiplier >= 3, desc:'Volume PO/tahun vs limit (self-liquidating)' },
  { metric:'Bank Yield on Capital', value: model.value.roe_bank_est.toFixed(1)+'%', threshold:'≥ 8%', pass: model.value.roe_bank_est >= 8, desc:'Total bank revenue / fasilitas deployed' },
  { metric:'Risk Classification', value: model.value.risk_weight, threshold:'LOW/MEDIUM', pass: model.value.risk_weight !== 'HIGH', desc:'Berdasarkan collateral coverage ratio' },
])

const passCount = computed(() => scorecard.value.filter(s => s.pass).length)


onMounted(loadRealData)
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
          <h1 class="text-xl font-bold text-[#1a1a1a]">Credit Memo — Fasilitas SCF ke Bank</h1>
          <span class="text-[10px] px-2.5 py-1 rounded-full bg-amber-600 text-white font-bold tracking-widest">BANK PARTNERSHIP</span>
          <span v-if="realData.totalARValue > 0" class="text-[10px] px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700 font-semibold">LIVE DATA</span>
        </div>
        <p class="text-sm text-[#777] mt-0.5">Institutional credit analysis — DSCR, LTV, collateral coverage, dan yield model untuk fasilitas Supply Chain Finance</p>
      </div>
    </div>

    <!-- Executive Summary Bar -->
    <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-5">
      <p class="text-[10px] uppercase tracking-[0.2em] text-[#999] mb-4">Executive Summary — Credit Application</p>
      <div class="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div class="md:col-span-2">
          <p class="text-[10px] text-[#999] mb-1">Facility Type</p>
          <p class="text-sm font-bold text-[#1a1a1a]">Revolving SCF / Reverse Factoring</p>
          <p class="text-[10px] text-[#777] mt-0.5">Supply Chain Finance — Healthcare Sector</p>
        </div>
        <div>
          <p class="text-[10px] text-[#999] mb-1">Limit Diminta</p>
          <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRp(params.facility_limit_requested) }}</p>
          <p class="text-[10px] text-[#777]">{{ fmtPct(model.ltv*100) }} LTV</p>
        </div>
        <div>
          <p class="text-[10px] text-[#999] mb-1">Bank Yield p.a.</p>
          <p class="text-lg font-bold text-amber-700">{{ fmtPct(model.roe_bank_est) }}</p>
          <p class="text-[10px] text-[#777]">interest + admin fee</p>
        </div>
        <div>
          <p class="text-[10px] text-[#999] mb-1">DSCR</p>
          <p class="text-lg font-bold" :class="model.dscr >= 1.5 ? 'text-emerald-700' : 'text-red-600'">{{ model.dscr.toFixed(2) }}x</p>
          <p class="text-[10px]" :class="model.dscr >= 1.5 ? 'text-emerald-700' : 'text-red-600'">{{ model.dscr >= 1.5 ? '✓ BANKABLE' : '⚠ BORDERLINE' }}</p>
        </div>
        <div>
          <p class="text-[10px] text-[#999] mb-1">Scorecard</p>
          <p class="text-lg font-bold" :class="passCount >= 5 ? 'text-emerald-700' : passCount >= 4 ? 'text-amber-700' : 'text-red-600'">
            {{ passCount }}/{{ scorecard.length }}
          </p>
          <p class="text-[10px] text-[#777]">metrics passing</p>
        </div>
      </div>
    </div>

    <!-- Model Params + Metrics side-by-side -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">

      <!-- Params -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs font-bold text-[#1a1a1a] mb-4">Model Inputs — Financial Parameters</p>
        <div class="space-y-3">
          <div v-for="p in [
            { key:'monthly_po_value', label:'Volume PO/Bulan', min:100_000_000, max:5_000_000_000, step:50_000_000 },
            { key:'gross_margin_pct', label:'Gross Margin KSM (%)', min:5, max:25, step:0.5, pct:true },
            { key:'num_rs_mitra', label:'Jumlah RS Mitra', min:1, max:30, step:1, unit:'RS' },
            { key:'bpjs_monthly_per_rs', label:'BPJS Cashflow/RS/Bln', min:500_000_000, max:10_000_000_000, step:100_000_000 },
            { key:'facility_limit_requested', label:'Limit Fasilitas (Rp)', min:500_000_000, max:20_000_000_000, step:500_000_000 },
            { key:'interest_rate_pa', label:'Suku Bunga p.a. (%)', min:6, max:20, step:0.5, pct:true },
          ]" :key="p.key">
            <div>
              <div class="flex justify-between mb-1">
                <label class="text-[11px] text-[#666]">{{ p.label }}</label>
                <span class="text-[11px] font-bold text-[#6b1525]">
                  <template v-if="p.pct">{{ (params as any)[p.key] }}%</template>
                  <template v-else-if="p.unit">{{ (params as any)[p.key] }} {{ p.unit }}</template>
                  <template v-else>{{ fmtRp((params as any)[p.key]) }}</template>
                </span>
              </div>
              <input type="range" v-model.number="(params as any)[p.key]" :min="p.min" :max="p.max" :step="p.step" class="w-full accent-[#6b1525]"/>
            </div>
          </div>
        </div>
      </div>

      <!-- Key Metrics Grid -->
      <div class="space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
            <p class="text-[10px] text-[#999] uppercase mb-1">Interest Income / Thn</p>
            <p class="text-xl font-bold text-emerald-700">{{ fmtRp(model.interest_income) }}</p>
            <p class="text-[10px] text-[#777]">{{ params.interest_rate_pa }}% × limit</p>
          </div>
          <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
            <p class="text-[10px] text-[#999] uppercase mb-1">Admin Fee / Thn</p>
            <p class="text-xl font-bold text-blue-700">{{ fmtRp(model.admin_fee_income) }}</p>
            <p class="text-[10px] text-[#777]">{{ params.admin_fee_pct }}% × PO vol.</p>
          </div>
          <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
            <p class="text-[10px] text-[#999] uppercase mb-1">Total Bank Revenue</p>
            <p class="text-xl font-bold text-[#6b1525]">{{ fmtRp(model.total_bank_rev) }}</p>
            <p class="text-[10px] text-[#777]">Yield {{ fmtPct(model.roe_bank_est) }}</p>
          </div>
          <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
            <p class="text-[10px] text-[#999] uppercase mb-1">BPJS Collateral</p>
            <p class="text-xl font-bold text-amber-700">{{ fmtRp(model.bpjs_collateral) }}</p>
            <p class="text-[10px] text-[#777]">{{ params.risk_coverage_pct }}% × BPJS/thn</p>
          </div>
        </div>

        <!-- Cash Flow Cycle Diagram -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] uppercase tracking-widest text-[#999] mb-3">Self-Liquidating Cash Cycle</p>
          <div class="flex items-center justify-between text-[10px] text-center">
            <div class="flex flex-col items-center gap-1">
              <div class="w-12 h-12 rounded-full bg-amber-100 border border-amber-300 flex items-center justify-center">
                <UIcon name="i-lucide-landmark" class="text-amber-700 text-base"/>
              </div>
              <span class="text-[#777]">Bank</span>
              <span class="text-amber-700 font-bold">Disb.</span>
            </div>
            <div class="flex-1 h-px bg-[#ddd] relative mx-1">
              <span class="absolute -top-2.5 left-1/2 -translate-x-1/2 text-[#777] text-[9px]">→ PO Verified</span>
            </div>
            <div class="flex flex-col items-center gap-1">
              <div class="w-12 h-12 rounded-full bg-blue-100 border border-blue-300 flex items-center justify-center">
                <UIcon name="i-lucide-truck" class="text-blue-700 text-base"/>
              </div>
              <span class="text-[#777]">Distributor</span>
              <span class="text-blue-700 font-bold">Supply</span>
            </div>
            <div class="flex-1 h-px bg-[#ddd] relative mx-1">
              <span class="absolute -top-2.5 left-1/2 -translate-x-1/2 text-[#777] text-[9px]">→ Barang GR</span>
            </div>
            <div class="flex flex-col items-center gap-1">
              <div class="w-12 h-12 rounded-full bg-emerald-100 border border-emerald-300 flex items-center justify-center">
                <UIcon name="i-lucide-building-2" class="text-emerald-700 text-base"/>
              </div>
              <span class="text-[#777]">RS Mitra</span>
              <span class="text-emerald-700 font-bold">Pakai</span>
            </div>
            <div class="flex-1 h-px bg-[#ddd] relative mx-1">
              <span class="absolute -top-2.5 left-1/2 -translate-x-1/2 text-[#777] text-[9px]">BPJS SI</span>
            </div>
            <div class="flex flex-col items-center gap-1">
              <div class="w-12 h-12 rounded-full bg-[#f0e0e3] border border-[#6b1525]/30 flex items-center justify-center">
                <UIcon name="i-lucide-landmark" class="text-[#6b1525] text-base"/>
              </div>
              <span class="text-[#777]">Bank</span>
              <span class="text-[#6b1525] font-bold">Collect</span>
            </div>
          </div>
          <p class="text-[10px] text-[#777] text-center mt-3">Standing Instruction BPJS → Bank auto-debit rekening RS</p>
        </div>
      </div>
    </div>

    <!-- Credit Scorecard -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <div class="flex items-center justify-between mb-4">
        <p class="text-xs font-bold text-[#1a1a1a]">Credit Scorecard</p>
        <div :class="['px-3 py-1 rounded-full text-xs font-bold', passCount >= 5 ? 'bg-emerald-100 text-emerald-700' : passCount >= 4 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700']">
          {{ passCount }}/{{ scorecard.length }} PASS —
          {{ passCount >= 5 ? 'CREDIT APPROVED' : passCount >= 4 ? 'CONDITIONAL APPROVAL' : 'REVISE TERMS' }}
        </div>
      </div>
      <div class="space-y-2">
        <div v-for="s in scorecard" :key="s.metric"
          :class="['flex items-center gap-4 px-4 py-3 rounded-xl text-xs', s.pass ? 'bg-emerald-50' : 'bg-red-50']">
          <UIcon :name="s.pass ? 'i-lucide-check-circle' : 'i-lucide-x-circle'"
            :class="[s.pass ? 'text-emerald-600' : 'text-red-600', 'text-base flex-shrink-0']"/>
          <div class="flex-1">
            <p class="font-bold text-[#1a1a1a]">{{ s.metric }}</p>
            <p class="text-[#777] mt-0.5">{{ s.desc }}</p>
          </div>
          <div class="text-right">
            <p class="font-bold text-lg" :class="s.pass ? 'text-emerald-700' : 'text-red-600'">{{ s.value }}</p>
            <p class="text-[10px] text-[#999]">threshold {{ s.threshold }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Term Sheet Proposal -->
    <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-6">
      <p class="text-[10px] uppercase tracking-widest text-[#999] mb-5">Proposed Term Sheet — Supply Chain Finance Facility</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-3">Facility Structure</p>
          <div class="space-y-2.5">
            <div v-for="r in [
              { k:'Facility Type', v:'Revolving SCF / Reverse Factoring' },
              { k:'Tenor', v:'12 bulan, renewable annually' },
              { k:'Limit', v:fmtRp(params.facility_limit_requested) },
              { k:'Purpose', v:'Pembiayaan PO ke distributor obat & alkes' },
              { k:'Disbursement', v:'Per PO terverifikasi, max 95% nilai invoice' },
              { k:'Repayment', v:'30–45 hari dari tanggal disbursement' },
            ]" :key="r.k" class="flex gap-3 text-[11px]">
              <span class="text-[#999] w-32 flex-shrink-0">{{ r.k }}</span>
              <span class="text-[#1a1a1a]">{{ r.v }}</span>
            </div>
          </div>
        </div>
        <div>
          <p class="text-[10px] font-bold text-[#999] uppercase tracking-wide mb-3">Pricing & Security</p>
          <div class="space-y-2.5">
            <div v-for="r in [
              { k:'Interest Rate', v:params.interest_rate_pa + '% p.a. (floating BI Rate + 3%)' },
              { k:'Admin Fee', v:params.admin_fee_pct + '% per disbursement' },
              { k:'Primary Collateral', v:'BPJS cashflow SI + e-Logistik PO/AR data' },
              { k:'Secondary Collateral', v:'Personal guarantee direktur KSM' },
              { k:'Financial Covenant', v:'DSCR ≥ 1.5x, reviewed quarterly' },
              { k:'Governing Law', v:'Hukum Indonesia, POJK 57/2020 SCF' },
            ]" :key="r.k" class="flex gap-3 text-[11px]">
              <span class="text-[#999] w-32 flex-shrink-0">{{ r.k }}</span>
              <span class="text-[#1a1a1a]">{{ r.v }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-5 pt-4 border-t border-[#e0e0e0]">
        <p class="text-[10px] text-[#999] uppercase tracking-wide mb-3">Why This is a Win for the Bank</p>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-3 text-[11px]">
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-amber-700 font-bold mb-1">{{ fmtPct(model.roe_bank_est) }} Yield</p>
            <p class="text-[#666]">Return on deployed capital dari interest + admin fee — lebih tinggi dari SBN / deposito bank</p>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-emerald-700 font-bold mb-1">Self-Liquidating</p>
            <p class="text-[#666]">Dana follow underlying asset (PO → barang → RS bayar). Bukan blind credit — setiap rupiah teraudit di sistem</p>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-blue-700 font-bold mb-1">BPJS Collateral</p>
            <p class="text-[#666]">Quasi-government cashflow. BPJS tidak pernah gagal bayar RS — ini setara dengan KPR beragunan real-estate prime</p>
          </div>
          <div class="bg-[#ebebeb] rounded-lg p-3">
            <p class="text-[#6b1525] font-bold mb-1">{{ model.multiplier.toFixed(1) }}x Multiplier</p>
            <p class="text-[#666]">Setiap Rp 1 fasilitas memfasilitasi Rp {{ model.multiplier.toFixed(1) }} transaksi riil — efisiensi modal Bank sangat tinggi</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Sensitivity: interest rate × facility size -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-1">Sensitivity — Annual Bank Revenue (Rp jt)</p>
      <p class="text-[11px] text-[#999] mb-3">Suku Bunga (kolom) × Limit Fasilitas (baris)</p>
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead>
            <tr class="border-b-2 border-[#e0e0e0]">
              <th class="text-left py-2 pr-4 text-[#999] font-bold text-[10px]">Limit \ Rate</th>
              <th v-for="r in [8,10,11,12,14]" :key="r" class="text-right py-2 px-2 text-[#999] font-bold text-[10px]">{{ r }}%</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="lim in [1e9,2e9,3e9,5e9,10e9]" :key="lim" class="border-b border-[#ececec]">
              <td class="py-2 pr-4 font-bold text-[#555]">{{ fmtRp(lim) }}</td>
              <td v-for="r in [8,10,11,12,14]" :key="r" class="py-2 px-2 text-right"
                :class="(lim*(r/100)/1e6) >= 300 ? 'text-emerald-700 font-bold' : (lim*(r/100)/1e6) >= 150 ? 'text-blue-700 font-semibold' : 'text-[#777]'">
                {{ (lim*(r/100)/1e6).toFixed(0) }}
              </td>
            </tr>
          </tbody>
        </table>
        <p class="text-[10px] text-[#777] mt-2">Interest income saja (belum termasuk admin fee {{ params.admin_fee_pct }}% dari volume PO)</p>
      </div>
    </div>

    <!-- Terminologi Credit Memo -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#666] uppercase tracking-wide mb-3">Terminologi Credit & SCF untuk Bank</p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-[10px]">
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">DSCR (Debt Service Coverage Ratio):</strong> Kemampuan KSM melunasi hutang. DSCR = Cashflow Operasional / (Pokok + Bunga). Target bankable: >1.25x. Dihitung dari revenue invoice RS dikurangi OpEx.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Self-Liquidating Loan:</strong> Kredit yang melunasi dirinya sendiri. Bank bayar Distributor → barang dikirim ke RS → RS bayar via BPJS+SI → KSM lunasi Bank. Siklus 30-45 hari.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">BPJS sebagai Collateral:</strong> Pembayaran BPJS ke RS adalah quasi-government cashflow — sangat predictable dan low-risk. Standing Instruction menjamin dana BPJS auto-transfer ke KSM.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">RS sebagai Co-Guarantor:</strong> RS ikut menjamin fasilitas SCF. Ini mengurangi risiko Bank karena ada 2 pihak yang bertanggung jawab (KSM + RS). Memungkinkan bunga lebih rendah.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Shortfall Mechanism:</strong> Jika BPJS tidak cover 100% invoice → Bank cover kekurangan sebagai kredit tambahan. Bunga dihitung harian, ditanggung 50% KSM + 50% RS.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">Yield on Deployed Capital:</strong> Total return Bank dari fasilitas SCF: bunga pokok + admin fee + bunga shortfall. Dibandingkan dengan risk profile = risk-adjusted return yang attractive.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">LTV (Loan-to-Value):</strong> Rasio outstanding kredit terhadap nilai underlying asset (invoice RS + stok in-transit). Target sehat: <80%. Semakin rendah = semakin aman untuk Bank.
        </div>
        <div class="p-2.5 bg-white rounded border border-[#ebebeb] text-[#666]">
          <strong class="text-[#1a1a1a]">POJK 57/2020:</strong> Peraturan OJK tentang SCF. Bank yang menyalurkan SCF ke sektor kesehatan mendapat apresiasi regulatori. Compliance dengan POJK = poin plus untuk approval komite kredit Bank.
        </div>
      </div>
    </div>

  </div>
</template>
