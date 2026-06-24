<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Intelijen & Analytics' })

const supabase = useSupabaseClient()
const { apiGet } = useApi()
const { tenantId } = useUserRole()

const loading = ref(true)
const aiLoading = ref(false)
const kpi = ref<any>(null)
const trends = ref<any[]>([])
const forecast = ref<any[]>([])
const riskScores = ref<any[]>([])
const demandData = ref<any[]>([])
const aiInsight = ref<string | null>(null)
const aiError = ref(false)

async function loadAll() {
  if (!tenantId.value) return
  loading.value = true

  const dashData = await apiGet<{ kpi: any; trends: any[]; forecast: any[]; risk_scores: any[]; demand_data: any[] }>('/api/ksm/dashboard')

  kpi.value = dashData.kpi
  trends.value = dashData.trends ?? []
  forecast.value = dashData.forecast ?? []
  riskScores.value = dashData.risk_scores ?? []
  demandData.value = dashData.demand_data ?? []
  loading.value = false
}

async function generateAIInsight() {
  aiLoading.value = true
  aiError.value = false
  aiInsight.value = null
  try {
    const res = await $fetch('/api/ai-insight', {
      method: 'POST',
      body: {
        kpiData: kpi.value,
        trends: trends.value,
        forecast: forecast.value,
        riskScores: riskScores.value,
        demandData: demandData.value,
      },
    })
    aiInsight.value = (res as any).insight
    aiError.value = !!(res as any).error
  } catch (e: any) {
    aiInsight.value = 'Gagal menghubungi AI: ' + (e.message ?? '')
    aiError.value = true
  }
  aiLoading.value = false
}

const maxTrend = computed(() => Math.max(...trends.value.map((t: any) => Number(t.revenue ?? 0)), 1))

watch(tenantId, (id) => { if (id) loadAll() })
onMounted(() => { if (tenantId.value) loadAll() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Intelijen & Analytics</h1>
        <p class="text-sm text-[#999] mt-0.5">Prediksi statistik + AI insight — data real-time dari semua transaksi KSM</p>
      </div>
      <button @click="generateAIInsight" :disabled="aiLoading || loading"
        class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2">
        <UIcon :name="aiLoading ? 'i-lucide-loader-2' : 'i-lucide-brain'" :class="aiLoading ? 'animate-spin' : ''" class="text-sm"/>
        {{ aiLoading ? 'Menganalisis...' : 'Generate AI Insight' }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-20">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <!-- KPI Row -->
      <div v-if="kpi" class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-4">
          <p class="text-[10px] text-emerald-600 uppercase mb-1">Revenue Total</p>
          <p class="text-xl font-bold text-emerald-700">{{ fmtRp(kpi.revenue_total) }}</p>
          <p class="text-[10px] text-emerald-500 mt-1">Bulan ini: {{ fmtRp(kpi.revenue_this_month) }}</p>
        </div>
        <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
          <p class="text-[10px] text-amber-500 uppercase mb-1">Piutang RS</p>
          <p class="text-xl font-bold text-amber-700">{{ fmtRp(kpi.outstanding_from_rs) }}</p>
          <p class="text-[10px] text-amber-500 mt-1">Overdue: {{ fmtRp(kpi.overdue_amount) }}</p>
        </div>
        <div class="bg-blue-50 rounded-xl border border-blue-200 p-4">
          <p class="text-[10px] text-blue-500 uppercase mb-1">Hutang SCF Bank</p>
          <p class="text-xl font-bold text-blue-700">{{ fmtRp(kpi.hutang_bank) }}</p>
          <p class="text-[10px] text-blue-500 mt-1">Bank→Dist: {{ fmtRp(kpi.bank_to_dist_total) }}</p>
        </div>
        <div :class="['rounded-xl border p-4', Number(kpi.total_shortfall) > 0 ? 'bg-red-50 border-red-200' : 'bg-[#f5f5f5] border-[#e5e5e5]']">
          <p class="text-[10px] text-[#999] uppercase mb-1">Shortfall + Bunga</p>
          <p class="text-xl font-bold" :class="Number(kpi.total_shortfall) > 0 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtRp(kpi.total_shortfall) }}</p>
          <p class="text-[10px] text-[#777] mt-1">Bunga KSM 50%: {{ fmtRp(kpi.total_daily_interest_ksm) }}</p>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <!-- Trend Chart -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Trend Revenue 6 Bulan</p>
          </div>
          <div class="p-5">
            <div v-if="trends.length === 0" class="flex items-center justify-center py-10 text-[#999] text-xs">Belum ada data</div>
            <div v-else class="flex items-end gap-2 h-40">
              <div v-for="t in trends" :key="t.month" class="flex-1 flex flex-col items-center gap-1">
                <p class="text-[8px] text-[#999]">{{ fmtRp(t.revenue) }}</p>
                <div class="w-full rounded-t-md bg-[#6b1525] transition-all"
                  :style="`height: ${Math.max(4, (Number(t.revenue) / maxTrend) * 120)}px`"/>
                <p class="text-[8px] text-[#999]">{{ t.month_label }}</p>
                <p class="text-[7px] text-[#999]">{{ t.po_count }} PO</p>
              </div>
            </div>
          </div>
        </div>

        <!-- Forecast -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Prediksi Revenue 3 Bulan</p>
            <p class="text-[10px] text-[#777] mt-0.5">Weighted Moving Average + Growth Trend</p>
          </div>
          <div class="p-5">
            <div v-if="forecast.length === 0" class="text-center text-xs text-[#999] py-10">Tidak cukup data untuk prediksi</div>
            <div v-else class="space-y-3">
              <div v-for="f in forecast" :key="f.month" class="flex items-center gap-4">
                <div class="w-16 text-xs font-semibold text-[#666]">{{ f.month_label }}</div>
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(f.predicted_revenue) }}</p>
                    <span v-if="f.growth_rate != null" :class="['text-[10px] font-semibold', Number(f.growth_rate) >= 0 ? 'text-emerald-600' : 'text-red-600']">
                      {{ Number(f.growth_rate) >= 0 ? '+' : '' }}{{ f.growth_rate }}%
                    </span>
                    <span :class="['px-1.5 py-0.5 rounded text-[9px] font-bold',
                      f.confidence === 'high' ? 'bg-emerald-100 text-emerald-700' :
                      f.confidence === 'medium' ? 'bg-amber-100 text-amber-700' :
                      'bg-[#f0f0f0] text-[#999]']">
                      {{ f.confidence }}
                    </span>
                  </div>
                  <div class="w-full bg-[#e5e5e5] rounded-full h-2">
                    <div class="bg-[#6b1525]/60 h-2 rounded-full transition-all"
                      :style="`width: ${f.confidence === 'high' ? 85 : f.confidence === 'medium' ? 60 : 35}%`"/>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <!-- RS Risk Scoring -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Risk Scoring RS Mitra</p>
            <p class="text-[10px] text-[#777] mt-0.5">Payment history, overdue, shortfall — basis keputusan kredit</p>
          </div>
          <div v-if="riskScores.length === 0" class="p-5 text-center text-xs text-[#999]">Belum ada data RS</div>
          <div v-else class="p-5 space-y-3">
            <div v-for="rs in riskScores" :key="rs.rs_tenant_id"
              :class="['p-3 rounded-xl border', rs.risk_score === 'HIGH' ? 'bg-red-50 border-red-200' : rs.risk_score === 'MEDIUM' ? 'bg-amber-50 border-amber-200' : 'bg-emerald-50 border-emerald-200']">
              <div class="flex items-start justify-between mb-2">
                <div>
                  <p class="text-xs font-bold text-[#1a1a1a]">{{ rs.rs_name }}</p>
                  <p class="text-[10px] text-[#999]">{{ rs.total_invoices }} invoice · {{ fmtRp(rs.total_value) }}</p>
                </div>
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-bold',
                  rs.risk_score === 'HIGH' ? 'bg-red-200 text-red-800' :
                  rs.risk_score === 'MEDIUM' ? 'bg-amber-200 text-amber-800' :
                  'bg-emerald-200 text-emerald-800']">
                  RISK: {{ rs.risk_score }}
                </span>
              </div>
              <div class="grid grid-cols-4 gap-2 text-[10px]">
                <div>
                  <p class="text-[#999]">Collection</p>
                  <p class="font-bold" :class="Number(rs.collection_rate) >= 80 ? 'text-emerald-600' : 'text-red-600'">{{ rs.collection_rate }}%</p>
                </div>
                <div>
                  <p class="text-[#999]">Overdue</p>
                  <p :class="['font-bold', Number(rs.overdue_count) > 0 ? 'text-red-600' : 'text-emerald-600']">{{ rs.overdue_count }}</p>
                </div>
                <div>
                  <p class="text-[#999]">Shortfall</p>
                  <p class="font-bold text-[#1a1a1a]">{{ rs.shortfall_count }}</p>
                </div>
                <div>
                  <p class="text-[#999]">Avg Days</p>
                  <p class="font-bold text-[#1a1a1a]">{{ rs.avg_payment_days ?? '-' }}d</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Demand Analysis -->
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Top Demand Items</p>
            <p class="text-[10px] text-[#777] mt-0.5">Item paling banyak diminta RS — basis negosiasi volume discount</p>
          </div>
          <div v-if="demandData.length === 0" class="p-5 text-center text-xs text-[#999]">Belum ada data demand</div>
          <div v-else class="p-5 space-y-2">
            <div v-for="(item, i) in demandData.slice(0, 8)" :key="item.kfa_code"
              class="flex items-center gap-3 p-2 rounded-lg hover:bg-[#ebebeb] transition-colors">
              <div class="w-6 h-6 rounded-full bg-[#6b1525]/10 flex items-center justify-center text-[10px] font-bold text-[#6b1525]">{{ i + 1 }}</div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ item.item_name }}</p>
                <p class="text-[10px] text-[#999]">{{ item.notif_count }} notif · avg {{ item.avg_requested }}/request</p>
              </div>
              <div class="text-right flex-shrink-0">
                <p class="text-xs font-bold text-[#1a1a1a]">{{ Number(item.total_requested).toLocaleString('id-ID') }}</p>
                <p class="text-[10px]" :class="Number(item.fulfillment_rate) >= 80 ? 'text-emerald-600' : Number(item.fulfillment_rate) >= 50 ? 'text-amber-600' : 'text-red-600'">
                  Fill: {{ item.fulfillment_rate }}%
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- AI Insight -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5] flex items-center justify-between">
          <div class="flex items-center gap-2">
            <UIcon name="i-lucide-brain" class="text-[#6b1525]"/>
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">AI Business Intelligence</p>
          </div>
          <span class="text-[10px] text-[#777]">Groq · Llama 3.3 70B</span>
        </div>
        <div class="p-5">
          <div v-if="!aiInsight && !aiLoading" class="flex flex-col items-center justify-center py-8 gap-3">
            <UIcon name="i-lucide-sparkles" class="text-3xl text-[#999]"/>
            <p class="text-sm text-[#999]">Klik "Generate AI Insight" untuk analisis mendalam</p>
            <p class="text-xs text-[#888]">AI menganalisis KPI, trend, forecast, risk scoring, dan demand — memberikan rekomendasi aksi</p>
          </div>
          <div v-else-if="aiLoading" class="flex items-center justify-center py-12 gap-3">
            <UIcon name="i-lucide-loader-2" class="text-xl text-[#6b1525] animate-spin"/>
            <p class="text-sm text-[#999]">AI sedang menganalisis semua data bisnis KSM...</p>
          </div>
          <div v-else :class="['text-xs leading-relaxed whitespace-pre-wrap', aiError ? 'text-red-600' : 'text-[#333]']">
            {{ aiInsight }}
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
