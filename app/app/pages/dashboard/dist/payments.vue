<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Pembayaran dari Bank' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const arList = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  // AR accounts dimana supplier_tenant_id = distributor ini
  // Bank bayar distributor → muncul sebagai disbursement
  const { data } = await supabase
    .from('ar_accounts')
    .select('id,ar_number,po_number,disbursed_amount,disbursement_date,status,invoice_ref')
    .not('disbursement_date', 'is', null)
    .order('disbursement_date', { ascending: false })
    .limit(50)
  arList.value = data ?? []
  loading.value = false
}

const totalReceived = computed(() => arList.value.reduce((s, a) => s + Number(a.disbursed_amount ?? 0), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Pembayaran dari Bank</h1>
      <p class="text-sm text-[#999] mt-0.5">Bank bayar langsung ke Distributor atas nama KSM melalui fasilitas SCF — pembayaran D+1 setelah konfirmasi</p>
    </div>

    <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 text-xs text-blue-700">
      <p class="font-bold mb-1">Alur Pembayaran ke Distributor</p>
      <p class="text-blue-600">KSM buat PO → Distributor konfirmasi → KSM approve → Bank bayar langsung ke Distributor (D+1) → Tidak perlu tunggu RS bayar. Bank yang menanggung via SCF.</p>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <div class="bg-emerald-50 rounded-xl border border-emerald-200 p-4">
        <p class="text-[10px] text-emerald-500 uppercase mb-1">Total Diterima dari Bank</p>
        <p class="text-2xl font-bold text-emerald-700">{{ fmtRp(totalReceived) }}</p>
        <p class="text-[10px] text-emerald-500 mt-1">{{ arList.length }} transaksi</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Metode Pembayaran</p>
        <p class="text-sm font-bold text-[#1a1a1a]">SCF Reverse Factoring</p>
        <p class="text-[10px] text-[#aaa] mt-1">Bank bayar D+1 · Tanpa risiko AR</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="arList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-banknote" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada pembayaran dari Bank</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Riwayat Pencairan Bank ke Distributor</p>
      </div>
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999]">No AR</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Ref PO</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Tgl Cair</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Jumlah Diterima</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="ar in arList" :key="ar.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono font-semibold text-[#1a1a1a]">{{ ar.ar_number }}</td>
            <td class="px-4 py-3 font-mono text-[#666]">{{ ar.po_number ?? '-' }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(ar.disbursement_date) }}</td>
            <td class="px-4 py-3 text-right font-bold text-emerald-700">{{ fmtRp(ar.disbursed_amount) }}</td>
            <td class="px-4 py-3">
              <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-700">Diterima</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
