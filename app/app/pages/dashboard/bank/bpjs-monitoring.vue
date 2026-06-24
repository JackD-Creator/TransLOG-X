<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Monitoring Cashflow BPJS' })

const supabase = useSupabaseClient()
const loading = ref(true)
const records = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('bpjs_payment_monitoring')
    .select('*, rs_tenant:rs_tenant_id(name, bpjs_ppk_code)')
    .order('period_year', { ascending: false })
    .order('period_month', { ascending: false })
    .limit(60)
  records.value = data ?? []
  loading.value = false
}


const months = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']

const totalClaimPaid = computed(() => records.value.reduce((s, r) => s + Number(r.claim_paid ?? 0), 0))
const totalSI = computed(() => records.value.reduce((s, r) => s + Number(r.si_deducted ?? 0), 0))

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Monitoring Cashflow BPJS ke RS</h1>
      <p class="text-sm text-[#999] mt-0.5">Pemantauan pembayaran BPJS ke rekening RS — basis perhitungan Standing Instruction</p>
    </div>

    <!-- Info box -->
    <div class="bg-blue-50 rounded-xl border border-blue-100 p-4 text-xs text-blue-800">
      <p class="font-bold mb-1">Tentang BPJS Cashflow Monitoring</p>
      <p>BPJS Kesehatan membayar RS atas <strong>klaim pelayanan kesehatan pasien</strong> (bukan untuk obat-obatan). Bank memantau cashflow ini sebagai indikator kemampuan RS membayar kewajiban via Standing Instruction (pemotongan otomatis saat BPJS masuk ke rekening RS).</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total Klaim BPJS Dibayar</p>
        <p class="text-2xl font-bold text-emerald-600">{{ fmtRp(totalClaimPaid) }}</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Total SI Dipotong</p>
        <p class="text-2xl font-bold text-blue-700">{{ fmtRp(totalSI) }}</p>
        <p class="text-xs text-[#999]">Pembayaran ke Bank via Standing Instruction</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <p class="text-xs text-[#999] mb-1">Coverage Ratio SI</p>
        <p class="text-2xl font-bold" :class="totalClaimPaid > 0 && totalSI / totalClaimPaid > 0.05 ? 'text-emerald-600' : 'text-amber-600'">
          {{ totalClaimPaid > 0 ? (totalSI / totalClaimPaid * 100).toFixed(1) : 0 }}%
        </p>
        <p class="text-xs text-[#999]">SI / Total Klaim BPJS</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="records.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-stethoscope" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada data monitoring BPJS</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">RS</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Periode</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Klaim Disetujui</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Dibayar BPJS</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Bayar</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">SI Dipotong</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Coverage</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="r in records" :key="r.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3">
              <p class="text-[#1a1a1a] font-medium">{{ (r.rs_tenant as any)?.name ?? '-' }}</p>
              <p class="text-[#999] font-mono">{{ (r.rs_tenant as any)?.bpjs_ppk_code ?? '-' }}</p>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ months[r.period_month] }} {{ r.period_year }}</td>
            <td class="px-4 py-3 font-bold text-[#1a1a1a]">{{ fmtRp(r.claim_approved) }}</td>
            <td class="px-4 py-3 font-bold text-emerald-700">{{ fmtRp(r.claim_paid) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ r.payment_date ? new Date(r.payment_date).toLocaleDateString('id-ID', {day:'2-digit',month:'short'}) : '-' }}</td>
            <td class="px-4 py-3 text-blue-700 font-bold">{{ fmtRp(r.si_deducted) }}</td>
            <td class="px-4 py-3">
              <span :class="['font-semibold', r.claim_paid > 0 && r.si_deducted / r.claim_paid > 0.05 ? 'text-emerald-600' : 'text-amber-600']">
                {{ r.claim_paid > 0 ? (r.si_deducted / r.claim_paid * 100).toFixed(1) : 0 }}%
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
