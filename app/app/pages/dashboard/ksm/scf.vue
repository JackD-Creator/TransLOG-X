<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Hutang SCF ke Bank' })

const { tenantId } = useUserRole()
const { apiGet } = useApi()

const loading = ref(true)
const facilities = ref<any[]>([])
const arList = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  try {
    const d = await apiGet<any>('/api/ksm/scf')
    facilities.value = d.facilities ?? []
    arList.value = d.ar_accounts ?? []
  } catch (e) { console.error('scf:', e) }
  loading.value = false
}

const totalLimit = computed(() => facilities.value.reduce((s, f) => s + Number(f.facility_limit), 0))
const totalOutstanding = computed(() => facilities.value.reduce((s, f) => s + Number(f.outstanding), 0))
const totalHutang = computed(() => arList.value.filter(a => a.status !== 'paid').reduce((s, a) => s + Number(a.outstanding_amount ?? a.total_payable - a.paid_amount), 0))
const totalDisbursed = computed(() => arList.value.reduce((s, a) => s + Number(a.disbursed_amount), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Hutang SCF ke Bank</h1>
      <p class="text-sm text-[#999] mt-0.5">Fasilitas SCF — Bank bayar Distributor atas nama KSM · KSM lunasi ke Bank · Dijamin RS</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <!-- Summary -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Limit SCF</p>
          <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalLimit) }}</p>
        </div>
        <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
          <p class="text-[10px] text-amber-500 uppercase mb-1">Outstanding Fasilitas</p>
          <p class="text-xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
          <p class="text-[10px] text-amber-500 mt-1">{{ totalLimit > 0 ? ((totalOutstanding/totalLimit)*100).toFixed(1) : 0 }}% utilisasi</p>
        </div>
        <div class="bg-blue-50 rounded-xl border border-blue-200 p-4">
          <p class="text-[10px] text-blue-500 uppercase mb-1">Total Bank→Dist</p>
          <p class="text-xl font-bold text-blue-700">{{ fmtRp(totalDisbursed) }}</p>
          <p class="text-[10px] text-blue-500 mt-1">Dicairkan ke Distributor</p>
        </div>
        <div class="bg-red-50 rounded-xl border border-red-200 p-4">
          <p class="text-[10px] text-red-400 uppercase mb-1">Hutang KSM→Bank</p>
          <p class="text-xl font-bold text-red-600">{{ fmtRp(totalHutang) }}</p>
          <p class="text-[10px] text-red-400 mt-1">Belum dilunasi</p>
        </div>
      </div>

      <!-- Facility Cards -->
      <div v-for="f in facilities" :key="f.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5] bg-[#ebebeb] flex items-start justify-between">
          <div>
            <p class="font-bold text-sm text-[#1a1a1a]">{{ f.facility_number }}</p>
            <p class="text-xs text-[#999] mt-0.5">Reverse Factoring · Bank Mitra SCF · <strong class="text-[#666]">Dijamin RS</strong></p>
          </div>
          <span :class="['px-2 py-0.5 rounded-full text-xs font-semibold',
            f.status === 'approved' ? 'bg-emerald-100 text-emerald-700' : 'bg-[#f0f0f0] text-[#999]']">
            {{ f.status }}
          </span>
        </div>
        <div class="p-5">
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs mb-4">
            <div>
              <p class="text-[#999] mb-0.5">Limit</p>
              <p class="font-bold text-[#1a1a1a]">{{ fmtRp(f.facility_limit) }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Outstanding</p>
              <p class="font-bold text-amber-600">{{ fmtRp(f.outstanding) }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Sisa Limit</p>
              <p class="font-bold text-emerald-600">{{ fmtRp(f.available_limit ?? (f.facility_limit - f.outstanding)) }}</p>
            </div>
            <div>
              <p class="text-[#999] mb-0.5">Bunga p.a.</p>
              <p class="font-bold text-[#1a1a1a]">{{ ((f.interest_rate_pa ?? 0) * 100).toFixed(2) }}%</p>
            </div>
          </div>
          <div class="mb-3">
            <div class="flex justify-between text-[10px] text-[#999] mb-1">
              <span>Utilisasi</span>
              <span>{{ f.facility_limit > 0 ? ((f.outstanding/f.facility_limit)*100).toFixed(1) : 0 }}%</span>
            </div>
            <div class="w-full bg-[#e5e5e5] rounded-full h-2.5">
              <div class="bg-[#6b1525] h-2.5 rounded-full transition-all"
                :style="`width:${f.facility_limit > 0 ? Math.min(100, f.outstanding/f.facility_limit*100) : 0}%`"/>
            </div>
          </div>
          <div class="flex gap-6 text-[10px] text-[#777]">
            <span>Tenor: <strong class="text-[#666]">{{ f.tenor_days }} hari</strong></span>
            <span>Aktif: <strong class="text-[#666]">{{ fmtDate(f.facility_start) }} – {{ fmtDate(f.facility_end) }}</strong></span>
          </div>
        </div>
      </div>

      <!-- Hutang ke Bank (AR Accounts) -->
      <div v-if="arList.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Riwayat Hutang KSM ke Bank</p>
          <p class="text-[10px] text-[#777] mt-0.5">Bank bayar Distributor → KSM hutang ke Bank → KSM lunasi dari dana RS</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead class="border-b border-[#e5e5e5]">
              <tr class="text-left">
                <th class="px-4 py-3 font-semibold text-[#999]">No AR</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Ref PO</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Bank→Dist</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Bunga SCF</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Total Hutang</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Dilunasi KSM</th>
                <th class="px-4 py-3 font-semibold text-[#999]">JT</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
                <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</td>
                <td class="px-4 py-3 font-mono text-[#666]">{{ ar.po_number ?? '-' }}</td>
                <td class="px-4 py-3 text-right font-bold text-blue-700">{{ fmtRp(ar.disbursed_amount) }}</td>
                <td class="px-4 py-3 text-right text-red-500">{{ fmtRp(ar.interest_amount) }}</td>
                <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">{{ fmtRp(ar.total_payable) }}</td>
                <td class="px-4 py-3 text-right font-semibold text-emerald-600">{{ fmtRp(ar.paid_amount) }}</td>
                <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
                <td class="px-4 py-3">
                  <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                    ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                    ar.status === 'disbursed' ? 'bg-blue-100 text-blue-700' :
                    'bg-amber-100 text-amber-700']">
                    {{ ar.status === 'paid' ? 'Lunas' : ar.status === 'disbursed' ? 'Bank Cair' : ar.status }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>
  </div>
</template>
