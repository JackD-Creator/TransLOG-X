<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Portfolio SCF Bank' })

const supabase = useSupabaseClient()
const loading = ref(true)
const facilities = ref<any[]>([])
const arItems = ref<any[]>([])

async function loadData() {
  loading.value = true
  const [{ data: fac }, { data: ar }] = await Promise.all([
    supabase.from('scf_facilities').select('*').order('created_at', { ascending: false }),
    supabase.from('ar_accounts').select('*').order('invoice_date', { ascending: false }).limit(20),
  ])
  facilities.value = fac ?? []
  arItems.value = ar ?? []
  loading.value = false
}

const totalLimit       = computed(() => facilities.value.reduce((s,f) => s + Number(f.facility_limit ?? 0), 0))
const totalOutstanding = computed(() => facilities.value.reduce((s,f) => s + Number(f.outstanding ?? 0), 0))
const avgUtilization   = computed(() => totalLimit.value > 0 ? (totalOutstanding.value / totalLimit.value) * 100 : 0)
const totalAR          = computed(() => arItems.value.reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0))
const totalInterest    = computed(() => arItems.value.reduce((s,a) => s + Number(a.interest_amount ?? 0), 0))

function fmtRp(n: number) {
  if (Math.abs(n) >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (Math.abs(n) >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return new Intl.NumberFormat('id-ID',{style:'currency',currency:'IDR',minimumFractionDigits:0}).format(n)
}
function agingBadge(status: string) {
  const map: Record<string, string> = { paid: 'bg-emerald-100 text-emerald-700', active: 'bg-blue-100 text-blue-700', overdue: 'bg-red-100 text-red-700', disbursed: 'bg-amber-100 text-amber-700' }
  return map[status] ?? 'bg-gray-100 text-gray-700'
}

onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard" class="text-[#999] hover:text-[#6b1525]">
        <UIcon name="i-lucide-arrow-left" class="text-sm"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Portfolio SCF Bank</h1>
        <p class="text-sm text-[#999] mt-0.5">Posisi fasilitas aktif, utilisasi, dan riwayat AR</p>
      </div>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="rounded-xl p-4 text-center text-white" style="background: linear-gradient(135deg, #6b1525 0%, #8a1e33 100%)">
        <p class="text-[10px] text-white/60 uppercase mb-1">Utilisasi</p>
        <p class="text-2xl font-bold" :class="avgUtilization >= 80 ? 'text-amber-300' : 'text-emerald-300'">{{ avgUtilization.toFixed(1) }}%</p>
        <div class="mt-2 bg-white/10 rounded-full h-1.5">
          <div class="h-1.5 rounded-full bg-emerald-400" :style="{width: avgUtilization+'%'}"/>
        </div>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Limit</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalLimit) }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Outstanding</p>
        <p class="text-xl font-bold text-[#6b1525]">{{ fmtRp(totalOutstanding) }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Bunga Diterima</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalInterest) }}</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="space-y-4">
      <!-- Fasilitas -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
          <p class="text-xs font-bold text-[#1a1a1a]">Fasilitas SCF Aktif</p>
          <span class="text-[10px] text-[#999]">{{ facilities.length }} debitur</span>
        </div>
        <div v-if="!facilities.length" class="py-10 text-center text-xs text-[#999]">Belum ada fasilitas aktif</div>
        <table v-else class="w-full text-xs">
          <thead class="border-b border-[#e5e5e5]">
            <tr class="text-left text-[#999] font-semibold text-[10px] uppercase">
              <th class="px-4 py-3">Debitur</th>
              <th class="px-4 py-3 text-right">Limit</th>
              <th class="px-4 py-3 text-right">Outstanding</th>
              <th class="px-4 py-3 text-right">Utilisasi</th>
              <th class="px-4 py-3">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="f in facilities" :key="f.id" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-3 font-medium text-[#1a1a1a]">{{ f.borrower_tenant_id }}</td>
              <td class="px-4 py-3 text-right text-[#555]">{{ fmtRp(Number(f.facility_limit)) }}</td>
              <td class="px-4 py-3 text-right font-semibold text-[#6b1525]">{{ fmtRp(Number(f.outstanding ?? 0)) }}</td>
              <td class="px-4 py-3 text-right">
                <span :class="['text-[10px] font-bold px-2 py-0.5 rounded-md', (Number(f.outstanding)/Number(f.facility_limit)*100) >= 80 ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700']">
                  {{ f.facility_limit > 0 ? (Number(f.outstanding)/Number(f.facility_limit)*100).toFixed(0) : 0 }}%
                </span>
              </td>
              <td class="px-4 py-3">
                <span :class="['text-[10px] px-2 py-0.5 rounded-full font-medium', f.status === 'approved' ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600']">
                  {{ f.status }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- AR Recent -->
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#1a1a1a]">Riwayat AR Accounts</p>
        </div>
        <div v-if="!arItems.length" class="py-10 text-center text-xs text-[#999]">Belum ada data AR</div>
        <table v-else class="w-full text-xs">
          <thead class="border-b border-[#e5e5e5]">
            <tr class="text-left text-[#999] font-semibold text-[10px] uppercase">
              <th class="px-4 py-3">Invoice</th>
              <th class="px-4 py-3 text-right">Nilai</th>
              <th class="px-4 py-3 text-right">Bunga</th>
              <th class="px-4 py-3">Status</th>
              <th class="px-4 py-3">Due Date</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="a in arItems" :key="a.id" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-2.5 font-mono text-[10px] text-[#666]">{{ a.invoice_number }}</td>
              <td class="px-4 py-2.5 text-right font-semibold text-[#1a1a1a]">{{ fmtRp(Number(a.invoice_amount)) }}</td>
              <td class="px-4 py-2.5 text-right text-emerald-700 font-semibold">{{ a.interest_amount ? fmtRp(Number(a.interest_amount)) : '—' }}</td>
              <td class="px-4 py-2.5">
                <span :class="['text-[10px] px-2 py-0.5 rounded-full font-medium', agingBadge(a.status)]">{{ a.status }}</span>
              </td>
              <td class="px-4 py-2.5 text-[#666]">{{ a.due_date ? new Date(a.due_date).toLocaleDateString('id-ID') : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
