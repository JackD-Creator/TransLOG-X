<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'RS Co-Guarantor' })

const supabase = useSupabaseClient()
const { apiGet } = useApi()

const loading = ref(true)
const riskScores = ref<any[]>([])
const facilities = ref<any[]>([])

async function load() {
  loading.value = true
  const [dashData, { data: fac }] = await Promise.all([
    apiGet<{ risk_scores: any[] }>('/api/ksm/dashboard'),
    supabase.from('scf_facilities')
      .select('id,facility_number,facility_limit,outstanding,available_limit,interest_rate_pa,status')
      .eq('status', 'approved'),
  ])
  riskScores.value = dashData.risk_scores ?? []
  facilities.value = fac ?? []
  loading.value = false
}

const totalFacility = computed(() => facilities.value.reduce((s, f) => s + Number(f.facility_limit), 0))
const totalOutstanding = computed(() => facilities.value.reduce((s, f) => s + Number(f.outstanding), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">RS sebagai Co-Guarantor SCF</h1>
      <p class="text-sm text-[#999] mt-0.5">RS mitra menjamin fasilitas SCF — risk assessment per RS berdasarkan payment history & BPJS collection</p>
    </div>

    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-xs text-blue-700">
      <p class="font-bold mb-1">Mengapa RS Menjamin SCF?</p>
      <p class="text-blue-600">RS adalah end-user yang menerima barang dan akan membayar via BPJS. Standing Instruction RS di bank custodian menjamin auto-transfer ke KSM. RS sebagai co-guarantor mengurangi risiko Bank dan memungkinkan bunga lebih rendah + limit lebih tinggi.</p>
    </div>

    <!-- Facility Overview -->
    <div class="grid grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Limit SCF</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalFacility) }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">Dijamin oleh RS mitra</p>
      </div>
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Outstanding</p>
        <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">RS Mitra</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ riskScores.length }}</p>
        <p class="text-[10px] text-[#aaa] mt-1">Co-guarantor aktif</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <div v-if="riskScores.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
        <p class="text-sm text-[#999]">Belum ada data RS mitra</p>
      </div>

      <div v-else class="space-y-4">
        <div v-for="rs in riskScores" :key="rs.rs_tenant_id"
          :class="['bg-[#f5f5f5] rounded-xl border overflow-hidden',
            rs.risk_score === 'HIGH' ? 'border-red-300' : rs.risk_score === 'MEDIUM' ? 'border-amber-300' : 'border-emerald-300']">
          <div class="px-5 py-4 flex items-start justify-between"
            :class="rs.risk_score === 'HIGH' ? 'bg-red-50' : rs.risk_score === 'MEDIUM' ? 'bg-amber-50' : 'bg-emerald-50'">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <UIcon name="i-lucide-building-2" class="text-base text-[#666]"/>
                <p class="font-bold text-[#1a1a1a]">{{ rs.rs_name }}</p>
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-bold',
                  rs.risk_score === 'HIGH' ? 'bg-red-200 text-red-800' :
                  rs.risk_score === 'MEDIUM' ? 'bg-amber-200 text-amber-800' :
                  'bg-emerald-200 text-emerald-800']">
                  RISK: {{ rs.risk_score }}
                </span>
              </div>
              <p class="text-xs text-[#999]">Co-guarantor SCF · {{ rs.total_invoices }} invoice · {{ fmtRp(rs.total_value) }} total transaksi</p>
            </div>
          </div>

          <div class="p-5">
            <div class="grid grid-cols-2 md:grid-cols-5 gap-4 text-xs mb-4">
              <div>
                <p class="text-[10px] text-[#999] mb-0.5">Collection Rate</p>
                <p class="font-bold text-lg" :class="Number(rs.collection_rate) >= 80 ? 'text-emerald-700' : Number(rs.collection_rate) >= 50 ? 'text-amber-600' : 'text-red-600'">
                  {{ rs.collection_rate }}%
                </p>
                <p class="text-[9px] text-[#aaa]">Invoice terbayar / total</p>
              </div>
              <div>
                <p class="text-[10px] text-[#999] mb-0.5">Overdue</p>
                <p :class="['font-bold text-lg', Number(rs.overdue_count) > 0 ? 'text-red-600' : 'text-emerald-700']">{{ rs.overdue_count }}</p>
                <p class="text-[9px] text-[#aaa]">Invoice lewat JT</p>
              </div>
              <div>
                <p class="text-[10px] text-[#999] mb-0.5">Overdue Amount</p>
                <p class="font-bold" :class="Number(rs.overdue_amount) > 0 ? 'text-red-600' : 'text-[#1a1a1a]'">{{ fmtRp(rs.overdue_amount) }}</p>
              </div>
              <div>
                <p class="text-[10px] text-[#999] mb-0.5">Shortfall History</p>
                <p class="font-bold text-[#1a1a1a]">{{ rs.shortfall_count }}x</p>
                <p class="text-[9px] text-[#aaa]">{{ fmtRp(rs.shortfall_total) }} total</p>
              </div>
              <div>
                <p class="text-[10px] text-[#999] mb-0.5">Avg Payment Days</p>
                <p class="font-bold text-[#1a1a1a]">{{ rs.avg_payment_days ?? '-' }} hari</p>
                <p class="text-[9px] text-[#aaa]">Dari invoice terbit</p>
              </div>
            </div>

            <!-- Risk assessment narrative -->
            <div :class="['p-3 rounded-lg text-xs',
              rs.risk_score === 'HIGH' ? 'bg-red-50 border border-red-200' :
              rs.risk_score === 'MEDIUM' ? 'bg-amber-50 border border-amber-200' :
              'bg-emerald-50 border border-emerald-200']">
              <p class="font-bold mb-1" :class="
                rs.risk_score === 'HIGH' ? 'text-red-700' :
                rs.risk_score === 'MEDIUM' ? 'text-amber-700' : 'text-emerald-700'">
                Assessment:
                {{ rs.risk_score === 'HIGH' ? 'Tinggi — perlu monitoring ketat' :
                   rs.risk_score === 'MEDIUM' ? 'Moderat — perlu perhatian' :
                   'Rendah — co-guarantor reliable' }}
              </p>
              <p class="text-[#666]">
                Collection rate {{ rs.collection_rate }}%{{ Number(rs.overdue_count) > 0 ? `, ${rs.overdue_count} invoice overdue (${fmtRp(rs.overdue_amount)})` : ', tidak ada overdue' }}{{ Number(rs.shortfall_count) > 0 ? `, ${rs.shortfall_count}x shortfall history` : '' }}.
                {{ Number(rs.avg_payment_days) > 0 ? `Rata-rata pembayaran ${rs.avg_payment_days} hari dari invoice.` : '' }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
