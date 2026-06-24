<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Risk Report Bank' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arData = ref<any[]>([])
const facData = ref<any[]>([])

async function loadData() {
  loading.value = true
  const [{ data: ar }, { data: fac }] = await Promise.all([
    supabase.from('ar_accounts').select('invoice_amount, outstanding_amount, due_date, status, disbursement_date'),
    supabase.from('scf_facilities').select('facility_limit, outstanding, status'),
  ])
  arData.value = ar ?? []
  facData.value = fac ?? []
  loading.value = false
}

const aging = computed(() => {
  const now = Date.now()
  const buckets = { current: 0, d30: 0, d60: 0, d90: 0, over90: 0 }
  for (const a of arData.value) {
    if (a.status === 'paid') continue
    const due = a.due_date ? new Date(a.due_date).getTime() : null
    const val = Number(a.outstanding_amount ?? a.invoice_amount ?? 0)
    if (!due || now <= due) { buckets.current += val; continue }
    const days = (now - due) / 86400000
    if (days <= 30) buckets.d30 += val
    else if (days <= 60) buckets.d60 += val
    else if (days <= 90) buckets.d90 += val
    else buckets.over90 += val
  }
  return buckets
})

const totalAging  = computed(() => Object.values(aging.value).reduce((s,v) => s + v, 0))
const nplAmount   = computed(() => aging.value.d60 + aging.value.d90 + aging.value.over90)
const nplRatio    = computed(() => totalAging.value > 0 ? (nplAmount.value / totalAging.value) * 100 : 0)
const totalLimit  = computed(() => facData.value.reduce((s,f) => s + Number(f.facility_limit ?? 0), 0))
const totalOut    = computed(() => facData.value.reduce((s,f) => s + Number(f.outstanding ?? 0), 0))



onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard" class="text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Risk Report — Portofolio SCF</h1>
        <p class="text-sm text-[#999] mt-0.5">AR aging analysis, NPL ratio, dan konsentrasi risiko kredit</p>
      </div>
    </div>

    <!-- NPL KPIs -->
    <div class="grid grid-cols-3 gap-4">
      <div :class="['rounded-xl p-4 text-center border', nplRatio <= 2 ? 'bg-emerald-50 border-emerald-200' : nplRatio <= 5 ? 'bg-amber-50 border-amber-200' : 'bg-red-50 border-red-200']">
        <p class="text-[10px] uppercase mb-1 text-[#999]">NPL Ratio</p>
        <p class="text-2xl font-bold" :class="nplRatio <= 2 ? 'text-emerald-700' : nplRatio <= 5 ? 'text-amber-600' : 'text-red-600'">{{ nplRatio.toFixed(2) }}%</p>
        <p class="text-[10px] mt-0.5 text-[#777]">{{ nplRatio <= 2 ? 'SEHAT' : nplRatio <= 5 ? 'PERHATIAN' : 'KRITIS' }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] uppercase mb-1 text-[#999]">Total AR Aktif</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalAging) }}</p>
        <p class="text-[10px] text-[#777]">Piutang outstanding</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] uppercase mb-1 text-[#999]">Utilisasi Fasilitas</p>
        <p class="text-xl font-bold text-[#6b1525]">{{ totalLimit > 0 ? (totalOut/totalLimit*100).toFixed(1) : 0 }}%</p>
        <p class="text-[10px] text-[#777]">{{ fmtRp(totalOut) }} / {{ fmtRp(totalLimit) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <!-- AR Aging Buckets -->
    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#1a1a1a] mb-4">AR Aging Analysis</p>
      <div class="space-y-3">
        <div v-for="bucket in [
          { label:'Current (Belum Jatuh Tempo)', val: aging.current, color:'bg-emerald-500', badge:'bg-emerald-100 text-emerald-700', risk:'NORMAL' },
          { label:'1–30 Hari Terlambat', val: aging.d30, color:'bg-amber-400', badge:'bg-amber-100 text-amber-700', risk:'WATCH' },
          { label:'31–60 Hari Terlambat', val: aging.d60, color:'bg-orange-500', badge:'bg-orange-100 text-orange-700', risk:'SUBSTANDARD' },
          { label:'61–90 Hari Terlambat', val: aging.d90, color:'bg-red-500', badge:'bg-red-100 text-red-700', risk:'DOUBTFUL' },
          { label:'>90 Hari Terlambat', val: aging.over90, color:'bg-red-900', badge:'bg-red-200 text-red-900', risk:'LOSS' },
        ]" :key="bucket.label" class="flex items-center gap-3">
          <span class="text-[11px] text-[#555] w-52 flex-shrink-0">{{ bucket.label }}</span>
          <div class="flex-1 bg-[#e5e5e5] rounded-full h-3">
            <div :class="[bucket.color, 'h-3 rounded-full transition-all duration-500']"
              :style="{ width: totalAging > 0 ? Math.min(100,(bucket.val/totalAging)*100)+'%' : '0%' }"/>
          </div>
          <span class="w-24 text-right text-[11px] font-semibold text-[#1a1a1a] flex-shrink-0">{{ fmtRp(bucket.val) }}</span>
          <span :class="['text-[10px] px-2 py-0.5 rounded-full font-bold flex-shrink-0', bucket.badge]">{{ bucket.risk }}</span>
        </div>
      </div>
      <div class="mt-3 pt-3 border-t border-[#e0e0e0] flex justify-between text-xs font-bold">
        <span class="text-[#1a1a1a]">Total AR Outstanding</span>
        <span class="text-[#6b1525]">{{ fmtRp(totalAging) }}</span>
      </div>
    </div>

    <!-- Risk Commentary -->
    <div :class="['rounded-xl p-5 border', nplRatio <= 2 ? 'bg-emerald-50 border-emerald-200' : nplRatio <= 5 ? 'bg-amber-50 border-amber-200' : 'bg-red-50 border-red-200']">
      <p class="text-xs font-bold mb-2" :class="nplRatio <= 2 ? 'text-emerald-800' : nplRatio <= 5 ? 'text-amber-800' : 'text-red-800'">
        Credit Risk Assessment
      </p>
      <p class="text-[11px] leading-relaxed" :class="nplRatio <= 2 ? 'text-emerald-700' : nplRatio <= 5 ? 'text-amber-700' : 'text-red-700'">
        <span v-if="nplRatio <= 2">
          NPL Ratio {{ nplRatio.toFixed(2) }}% — di bawah threshold peraturan OJK (5%). Portofolio SCF dalam kondisi sehat.
          Collateral BPJS cashflow via Standing Instruction berfungsi efektif sebagai mitigasi risiko.
        </span>
        <span v-else-if="nplRatio <= 5">
          NPL Ratio {{ nplRatio.toFixed(2) }}% — mendekati threshold OJK. Perlu monitoring intensif debitur dengan AR > 30 hari.
          Rekomendasikan aktivasi BPJS Standing Instruction segera untuk debitur terlambat.
        </span>
        <span v-else>
          NPL Ratio {{ nplRatio.toFixed(2) }}% — melebihi threshold OJK 5%. Segera lakukan collection action dan evaluasi limit fasilitas.
          Aktifkan klausa covenant breach dan diskusikan restrukturisasi dengan KSM terkait.
        </span>
      </p>
    </div>
  </div>
</template>
