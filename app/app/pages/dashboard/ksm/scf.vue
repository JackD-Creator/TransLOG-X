<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Fasilitas SCF' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const facilities = ref<any[]>([])
const arList = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const [{ data: fac }, { data: ar }] = await Promise.all([
    supabase
      .from('scf_facilities')
      .select('id,facility_number,financing_type,facility_limit,outstanding,available_limit,interest_rate_pa,tenor_days,payment_terms,status,facility_start,facility_end,standing_instruction_active')
      .eq('borrower_tenant_id', tenantId.value)
      .order('facility_start', { ascending: false }),
    supabase
      .from('ar_accounts')
      .select('id,ar_number,po_number,invoice_amount,disbursed_amount,interest_amount,total_payable,paid_amount,outstanding_amount,disbursement_date,due_date,status')
      .eq('ksm_tenant_id', tenantId.value)
      .not('disbursement_date', 'is', null)
      .order('disbursement_date', { ascending: false })
      .limit(20),
  ])
  facilities.value = fac ?? []
  arList.value = ar ?? []
  loading.value = false
}

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(2)}M`
  if (n >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return 'Rp ' + Math.round(n).toLocaleString('id-ID')
}
function fmtDate(d: string | null) {
  if (!d) return '-'
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}
function pct(n: number) { return (n * 100).toFixed(2) }

const ftypeLabel: Record<string, string> = {
  reverse_factoring: 'Reverse Factoring',
  invoice_financing: 'Invoice Financing',
  bpjs_bridging: 'BPJS Bridging',
  po_financing: 'PO Financing',
}
const fstatusColor: Record<string, string> = {
  approved: 'bg-emerald-100 text-emerald-700',
  draft: 'bg-[#f0f0f0] text-[#999]',
  defaulted: 'bg-red-100 text-red-700',
}

const totalLimit = computed(() => facilities.value.reduce((s, f) => s + Number(f.facility_limit), 0))
const totalOutstanding = computed(() => facilities.value.reduce((s, f) => s + Number(f.outstanding), 0))
const totalAvail = computed(() => facilities.value.reduce((s, f) => s + Number(f.available_limit ?? 0), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Fasilitas SCF / Pembiayaan</h1>
        <p class="text-sm text-[#999] mt-0.5">Supply Chain Finance dari Bank — Reverse Factoring untuk KSM</p>
      </div>
      <NuxtLink to="/dashboard/ksm/finance" class="text-xs text-[#6b1525] hover:underline flex items-center gap-1">
        <UIcon name="i-lucide-arrow-left" class="text-xs"/>
        Kembali ke Finance
      </NuxtLink>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <template v-else>
      <!-- Summary -->
      <div class="grid grid-cols-3 gap-3">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs text-[#999] uppercase tracking-wide mb-2">Total Limit SCF</p>
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ fmtRp(totalLimit) }}</p>
        </div>
        <div class="bg-amber-50 rounded-xl border border-amber-200 p-5">
          <p class="text-xs text-amber-500 uppercase tracking-wide mb-2">Outstanding</p>
          <p class="text-2xl font-bold text-amber-700">{{ fmtRp(totalOutstanding) }}</p>
          <p class="text-xs text-amber-500 mt-1">{{ totalLimit > 0 ? ((totalOutstanding/totalLimit)*100).toFixed(1) : 0 }}% utilisasi</p>
        </div>
        <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-5">
          <p class="text-xs text-emerald-600 uppercase tracking-wide mb-2">Sisa Limit</p>
          <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(totalAvail) }}</p>
        </div>
      </div>

      <!-- No facility empty state -->
      <div v-if="facilities.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
        <UIcon name="i-lucide-landmark" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada fasilitas SCF aktif</p>
        <p class="text-xs text-[#bbb]">Hubungi Bank mitra untuk aktivasi fasilitas Reverse Factoring</p>
      </div>

      <!-- Facility Cards -->
      <div v-else class="space-y-4">
        <div v-for="f in facilities" :key="f.id" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] bg-[#ebebeb] flex items-start justify-between">
            <div>
              <p class="font-bold text-sm text-[#1a1a1a]">{{ f.facility_number }}</p>
              <p class="text-xs text-[#999] mt-0.5">{{ ftypeLabel[f.financing_type] ?? f.financing_type }} · Bank Mitra SCF</p>
            </div>
            <div class="flex items-center gap-2">
              <span v-if="f.standing_instruction_active" class="px-2 py-0.5 rounded-full text-[10px] bg-blue-100 text-blue-700 font-semibold">
                Standing Instruction Aktif
              </span>
              <span :class="['px-2 py-0.5 rounded-full text-xs font-semibold', fstatusColor[f.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ f.status }}
              </span>
            </div>
          </div>

          <div class="p-5">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs mb-5">
              <div>
                <p class="text-[#999] mb-0.5">Limit Fasilitas</p>
                <p class="font-bold text-[#1a1a1a]">{{ fmtRp(f.facility_limit) }}</p>
              </div>
              <div>
                <p class="text-[#999] mb-0.5">Outstanding</p>
                <p class="font-bold text-amber-600">{{ fmtRp(f.outstanding) }}</p>
              </div>
              <div>
                <p class="text-[#999] mb-0.5">Available Limit</p>
                <p class="font-bold text-emerald-600">{{ fmtRp(f.available_limit ?? (f.facility_limit - f.outstanding)) }}</p>
              </div>
              <div>
                <p class="text-[#999] mb-0.5">Bunga p.a.</p>
                <p class="font-bold text-[#1a1a1a]">{{ pct(f.interest_rate_pa) }}%</p>
              </div>
            </div>

            <div class="mb-4">
              <div class="flex justify-between text-[10px] text-[#999] mb-1">
                <span>Utilisasi Limit</span>
                <span class="font-semibold">{{ f.facility_limit > 0 ? ((f.outstanding / f.facility_limit)*100).toFixed(1) : 0 }}%</span>
              </div>
              <div class="w-full bg-[#e5e5e5] rounded-full h-2.5">
                <div class="bg-[#6b1525] h-2.5 rounded-full transition-all"
                  :style="`width:${f.facility_limit > 0 ? Math.min(100, f.outstanding/f.facility_limit*100) : 0}%`"/>
              </div>
            </div>

            <div class="flex gap-6 text-[10px] text-[#aaa]">
              <span>Tenor: <strong class="text-[#666]">{{ f.tenor_days }} hari</strong></span>
              <span>Termin: <strong class="text-[#666]">{{ f.payment_terms?.replace('net_','Net ') }}</strong></span>
              <span>Aktif: <strong class="text-[#666]">{{ fmtDate(f.facility_start) }} – {{ fmtDate(f.facility_end) }}</strong></span>
            </div>
          </div>
        </div>
      </div>

      <!-- AR Drawdowns -->
      <div v-if="arList.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
          <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Riwayat Pencairan SCF</p>
          <p class="text-[10px] text-[#aaa] mt-0.5">Bank mencairkan dana ke Distributor atas nama KSM</p>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-xs">
            <thead class="border-b border-[#e5e5e5]">
              <tr class="text-left">
                <th class="px-4 py-3 font-semibold text-[#999]">No AR</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Ref PO</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Dicairkan</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Bunga SCF</th>
                <th class="px-4 py-3 font-semibold text-[#999] text-right">Total Bayar ke Bank</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Tgl Cair</th>
                <th class="px-4 py-3 font-semibold text-[#999]">Jatuh Tempo</th>
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
                <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.disbursement_date) }}</td>
                <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.due_date) }}</td>
                <td class="px-4 py-3">
                  <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                    ar.status === 'paid' ? 'bg-emerald-100 text-emerald-700' :
                    ar.status === 'disbursed' ? 'bg-blue-100 text-blue-700' :
                    ar.status === 'partially_paid' ? 'bg-amber-100 text-amber-700' :
                    'bg-[#f0f0f0] text-[#999]']">
                    {{ ar.status === 'paid' ? 'Lunas' : ar.status === 'disbursed' ? 'Cair' : ar.status === 'partially_paid' ? 'Sebagian' : ar.status }}
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
