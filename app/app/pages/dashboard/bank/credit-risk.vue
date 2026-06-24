<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Risiko Kredit' })

const supabase = useSupabaseClient()
const loading = ref(true)
const facilities = ref<any[]>([])
const arStats = ref<Record<string, any>>({})

async function load() {
  loading.value = true
  const [{ data: fac }, { data: ar }] = await Promise.all([
    supabase.from('scf_facilities').select('id,facility_number,financing_type,facility_limit,outstanding,available_limit,interest_rate_pa,tenor_days,status,borrower_tenant_id').not('status', 'eq', 'cancelled'),
    supabase.from('ar_accounts').select('ksm_tenant_id, status, outstanding_amount, due_date'),
  ])
  facilities.value = fac ?? []

  // Group AR stats per KSM
  const stats: Record<string, any> = {}
  for (const a of (ar ?? [])) {
    const tid = a.ksm_tenant_id
    if (!stats[tid]) stats[tid] = { total: 0, overdue: 0, outstanding: 0 }
    stats[tid].total++
    if (a.status === 'overdue') stats[tid].overdue++
    stats[tid].outstanding += Number(a.outstanding_amount ?? 0)
  }
  arStats.value = stats

  loading.value = false
}

function fmtRp(n: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

function riskLevel(f: any) {
  const util = f.facility_limit > 0 ? f.outstanding / f.facility_limit : 0
  const arStat = arStats.value[f.borrower_tenant_id] ?? {}
  const overdueRatio = arStat.total > 0 ? arStat.overdue / arStat.total : 0
  if (util > 0.9 || overdueRatio > 0.3) return { label: 'Tinggi', color: 'bg-red-100 text-red-700' }
  if (util > 0.6 || overdueRatio > 0.1) return { label: 'Sedang', color: 'bg-amber-100 text-amber-700' }
  return { label: 'Rendah', color: 'bg-emerald-100 text-emerald-700' }
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Risiko Kredit</h1>
      <p class="text-sm text-[#999] mt-0.5">Profil risiko fasilitas SCF — utilisasi limit & track record pembayaran KSM</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="facilities.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-shield-alert" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada fasilitas untuk dianalisis</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="f in facilities" :key="f.id"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
        <div class="flex items-start justify-between mb-4">
          <div>
            <div class="flex items-center gap-2">
              <p class="text-sm font-bold text-[#1a1a1a]">KSM Mitra</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-bold', riskLevel(f).color]">
                Risiko {{ riskLevel(f).label }}
              </span>
            </div>
            <p class="text-xs text-[#999]">{{ f.facility_number }} · {{ f.financing_type }}</p>
          </div>
          <p class="text-xs text-[#999]">{{ (Number(f.interest_rate_pa) * 100).toFixed(2) }}% p.a.</p>
        </div>

        <div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs mb-3">
          <div>
            <p class="text-[#999]">Limit</p>
            <p class="font-bold text-[#1a1a1a]">{{ fmtRp(f.facility_limit) }}</p>
          </div>
          <div>
            <p class="text-[#999]">Utilisasi</p>
            <p class="font-bold" :class="f.facility_limit > 0 && f.outstanding / f.facility_limit > 0.8 ? 'text-red-600' : 'text-[#1a1a1a]'">
              {{ f.facility_limit > 0 ? (f.outstanding / f.facility_limit * 100).toFixed(1) : 0 }}%
            </p>
          </div>
          <div>
            <p class="text-[#999]">Total AR</p>
            <p class="font-bold text-[#1a1a1a]">{{ arStats[f.borrower_tenant_id]?.total ?? 0 }}</p>
          </div>
          <div>
            <p class="text-[#999]">AR Overdue</p>
            <p class="font-bold" :class="(arStats[f.borrower_tenant_id]?.overdue ?? 0) > 0 ? 'text-red-600' : 'text-emerald-600'">
              {{ arStats[f.borrower_tenant_id]?.overdue ?? 0 }}
            </p>
          </div>
        </div>

        <div class="w-full bg-[#e5e5e5] rounded-full h-2">
          <div class="h-2 rounded-full transition-all"
            :class="f.facility_limit > 0 && f.outstanding / f.facility_limit > 0.8 ? 'bg-red-500' : f.facility_limit > 0 && f.outstanding / f.facility_limit > 0.6 ? 'bg-amber-500' : 'bg-[#6b1525]'"
            :style="`width:${f.facility_limit > 0 ? Math.min(100, f.outstanding / f.facility_limit * 100) : 0}%`"/>
        </div>
      </div>
    </div>
  </div>
</template>
