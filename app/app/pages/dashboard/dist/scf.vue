<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'SCF — Likuiditas Distributor' })

const supabase = useSupabaseClient()
const loading = ref(true)
const arItems = ref<any[]>([])

async function loadData() {
  loading.value = true
  const { data } = await supabase.from('ar_accounts')
    .select('id,invoice_number,invoice_amount,interest_amount,status,disbursement_date,due_date')
    .not('disbursement_date','is',null)
    .order('disbursement_date', { ascending: false }).limit(20)
  arItems.value = data ?? []
  loading.value = false
}

const totalDisbursed = computed(() => arItems.value.reduce((s,a) => s + Number(a.invoice_amount ?? 0), 0))
const totalInterest  = computed(() => arItems.value.reduce((s,a) => s + Number(a.interest_amount ?? 0), 0))
const avgTenor = computed(() => {
  const paid = arItems.value.filter(a => a.disbursement_date && a.due_date)
  if (!paid.length) return 30
  const avg = paid.reduce((s,a) => {
    return s + (new Date(a.due_date).getTime() - new Date(a.disbursement_date).getTime()) / 86400000
  }, 0) / paid.length
  return Math.round(avg)
})

function fmtRp(n: number) {
  if (n >= 1e9) return `Rp ${(n/1e9).toFixed(2)} M`
  if (n >= 1e6) return `Rp ${(n/1e6).toFixed(1)} jt`
  return `Rp ${n.toLocaleString('id-ID')}`
}

onMounted(loadData)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">SCF — Likuiditas Distributor</h1>
      <p class="text-sm text-[#999] mt-0.5">Riwayat pencairan via reverse factoring — Bank bayar distributor D+1 setelah GR konfirmasi</p>
    </div>

    <!-- How it works -->
    <div class="bg-[#0d0d0d] text-white rounded-xl p-5">
      <p class="text-[10px] uppercase tracking-widest text-white/40 mb-3">Mekanisme SCF — Reverse Factoring</p>
      <div class="grid grid-cols-1 md:grid-cols-4 gap-3 text-[11px] text-center">
        <div v-for="step in [
          { icon:'i-lucide-file-check', text:'KSM buat PO terverifikasi di e-Logistik', label:'1. PO Digital' },
          { icon:'i-lucide-truck', text:'Distributor kirim barang, GR dikonfirmasi sistem', label:'2. GR Konfirmasi' },
          { icon:'i-lucide-landmark', text:'Bank cair invoice D+1 → rekening distributor', label:'3. Bank Bayar' },
          { icon:'i-lucide-rotate-ccw', text:'KSM bayar Bank pada jatuh tempo (30–45 hari)', label:'4. KSM Bayar Bank' },
        ]" :key="step.label" class="bg-white/5 rounded-xl p-3">
          <UIcon :name="step.icon" class="text-2xl text-amber-400 mb-2"/>
          <p class="font-bold text-white mb-1">{{ step.label }}</p>
          <p class="text-white/50">{{ step.text }}</p>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-3 gap-4">
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Total Dicairkan</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalDisbursed) }}</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Biaya Bunga</p>
        <p class="text-xl font-bold text-[#6b1525]">{{ fmtRp(totalInterest) }}</p>
        <p class="text-[10px] text-[#aaa]">dibayar KSM ke Bank</p>
      </div>
      <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 text-center">
        <p class="text-[10px] text-[#999] uppercase mb-1">Rata-rata Tenor</p>
        <p class="text-xl font-bold text-blue-700">{{ avgTenor }} hari</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>
    <div v-else-if="!arItems.length" class="flex flex-col items-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-landmark" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada pencairan SCF. Data akan muncul setelah Bank mengaktifkan fasilitas.</p>
    </div>
    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5] text-left">
          <tr class="text-[#999] font-semibold text-[10px] uppercase">
            <th class="px-4 py-3">Invoice</th>
            <th class="px-4 py-3 text-right">Nilai Cair</th>
            <th class="px-4 py-3 text-right">Bunga</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3">Tgl Cair</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="a in arItems" :key="a.id" class="hover:bg-[#ebebeb]">
            <td class="px-4 py-3 font-mono text-[10px] text-[#666]">{{ a.invoice_number }}</td>
            <td class="px-4 py-3 text-right font-semibold text-[#1a1a1a]">{{ fmtRp(Number(a.invoice_amount)) }}</td>
            <td class="px-4 py-3 text-right text-[#6b1525]">{{ a.interest_amount ? fmtRp(Number(a.interest_amount)) : '—' }}</td>
            <td class="px-4 py-3">
              <span :class="['text-[10px] px-2 py-0.5 rounded-full font-medium',
                a.status === 'paid' ? 'bg-emerald-100 text-emerald-700' : 'bg-blue-100 text-blue-700']">
                {{ a.status === 'paid' ? 'Lunas' : 'Aktif' }}
              </span>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ new Date(a.disbursement_date).toLocaleDateString('id-ID') }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
