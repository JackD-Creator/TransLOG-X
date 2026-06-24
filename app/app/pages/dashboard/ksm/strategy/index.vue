<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Strategi Bisnis KSM' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const kpi = ref<any>(null)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase.rpc('get_ksm_dashboard_kpi', { p_ksm_tenant_id: tenantId.value })
  kpi.value = data
  loading.value = false
}

// Derived strategic metrics
const margin = computed(() => {
  if (!kpi.value) return 0
  const rev = Number(kpi.value.revenue_total)
  const cogs = Number(kpi.value.bank_to_dist_total)
  return rev > 0 ? ((rev - cogs) / rev * 100) : 0
})

const scfUtilization = computed(() => {
  if (!kpi.value) return 0
  const limit = Number(kpi.value.scf_limit)
  const out = Number(kpi.value.scf_outstanding)
  return limit > 0 ? (out / limit * 100) : 0
})

const collectionEfficiency = computed(() => {
  if (!kpi.value) return 0
  const rev = Number(kpi.value.revenue_total)
  const outstanding = Number(kpi.value.outstanding_from_rs)
  return rev > 0 ? ((rev - outstanding) / rev * 100) : 0
})

const strategies = [
  {
    title: 'Ecosystem Value Proposition',
    subtitle: 'Peta relasi RS ↔ KSM ↔ Distributor ↔ Bank',
    desc: 'Analisis keuntungan finansial setiap pihak dalam ekosistem SCF. Hitung total value creation dan kontribusi per stakeholder.',
    icon: 'i-lucide-globe', color: 'text-slate-600', bg: 'bg-slate-100',
    to: '/dashboard/ksm/strategy/ecosystem',
  },
  {
    title: 'Revenue Architecture — Supply ke RS',
    subtitle: 'Model pendapatan + benchmark harga KFA',
    desc: 'Gross profit decomposition, analisis margin per kategori obat/alkes, dan sensitivitas harga terhadap volume.',
    icon: 'i-lucide-target', color: 'text-emerald-600', bg: 'bg-emerald-50',
    to: '/dashboard/ksm/strategy/supply',
  },
  {
    title: 'Procurement Intelligence — Negosiasi Distributor',
    subtitle: 'Posisi tawar + skenario harga',
    desc: 'Framework negosiasi berbasis HAP/HET KFA. Analisis 5 skenario: spot, extended terms, early payment, volume rebate, consignment.',
    icon: 'i-lucide-handshake', color: 'text-blue-600', bg: 'bg-blue-50',
    to: '/dashboard/ksm/strategy/negotiation',
  },
  {
    title: 'Credit Memo — Pitch ke Bank',
    subtitle: 'DSCR · Utilisasi SCF · Yield Model',
    desc: 'Analisis kelayakan kredit KSM untuk presentasi ke Bank. DSCR scorecard, collateral BPJS, yield sensitivity, dan term sheet SCF.',
    icon: 'i-lucide-landmark', color: 'text-amber-700', bg: 'bg-amber-50',
    to: '/dashboard/ksm/strategy/bank-pitch',
  },
]

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Strategi Bisnis KSM</h1>
      <p class="text-sm text-[#999] mt-0.5">Data real-time untuk optimasi revenue, negosiasi distributor, dan kemitraan perbankan</p>
    </div>

    <!-- Strategic KPI — angka real dari DB -->
    <div v-if="!loading && kpi" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Indikator Strategis KSM (Real-Time)</p>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-px bg-[#e5e5e5]">
        <!-- Gross Margin -->
        <div class="bg-[#f5f5f5] p-4">
          <div class="flex items-start justify-between mb-2">
            <p class="text-[10px] text-[#999] uppercase font-semibold">Gross Margin</p>
            <UIcon name="i-lucide-info" class="text-[10px] text-[#ccc]"/>
          </div>
          <p class="text-2xl font-bold" :class="margin >= 8 ? 'text-emerald-700' : margin >= 5 ? 'text-amber-600' : 'text-red-600'">
            {{ fmtPct(margin) }}
          </p>
          <p class="text-[10px] text-[#aaa] mt-1 leading-relaxed">
            <strong>Definisi:</strong> Selisih antara harga jual KSM ke RS (invoice) dengan harga beli dari Distributor (disbursement Bank).
            Target sehat: >8%.
          </p>
        </div>

        <!-- SCF Utilization -->
        <div class="bg-[#f5f5f5] p-4">
          <div class="flex items-start justify-between mb-2">
            <p class="text-[10px] text-[#999] uppercase font-semibold">Utilisasi SCF</p>
            <UIcon name="i-lucide-info" class="text-[10px] text-[#ccc]"/>
          </div>
          <p class="text-2xl font-bold" :class="scfUtilization <= 70 ? 'text-emerald-700' : scfUtilization <= 90 ? 'text-amber-600' : 'text-red-600'">
            {{ fmtPct(scfUtilization) }}
          </p>
          <p class="text-[10px] text-[#aaa] mt-1 leading-relaxed">
            <strong>Definisi:</strong> Persentase limit fasilitas SCF Bank yang terpakai.
            Outstanding {{ fmtRp(kpi.scf_outstanding) }} dari limit {{ fmtRp(kpi.scf_limit) }}.
            Target: <70% agar ada buffer.
          </p>
        </div>

        <!-- Collection Efficiency -->
        <div class="bg-[#f5f5f5] p-4">
          <div class="flex items-start justify-between mb-2">
            <p class="text-[10px] text-[#999] uppercase font-semibold">Collection Rate</p>
            <UIcon name="i-lucide-info" class="text-[10px] text-[#ccc]"/>
          </div>
          <p class="text-2xl font-bold" :class="collectionEfficiency >= 80 ? 'text-emerald-700' : collectionEfficiency >= 60 ? 'text-amber-600' : 'text-red-600'">
            {{ fmtPct(collectionEfficiency) }}
          </p>
          <p class="text-[10px] text-[#aaa] mt-1 leading-relaxed">
            <strong>Definisi:</strong> Persentase invoice RS yang sudah terbayar dari total revenue.
            Outstanding {{ fmtRp(kpi.outstanding_from_rs) }} dari total {{ fmtRp(kpi.revenue_total) }}.
            Sumber: BPJS + Standing Instruction.
          </p>
        </div>

        <!-- Overdue Risk -->
        <div class="bg-[#f5f5f5] p-4">
          <div class="flex items-start justify-between mb-2">
            <p class="text-[10px] text-[#999] uppercase font-semibold">Overdue Exposure</p>
            <UIcon name="i-lucide-info" class="text-[10px] text-[#ccc]"/>
          </div>
          <p class="text-2xl font-bold" :class="Number(kpi.overdue_amount) === 0 ? 'text-emerald-700' : 'text-red-600'">
            {{ fmtRp(kpi.overdue_amount) }}
          </p>
          <p class="text-[10px] text-[#aaa] mt-1 leading-relaxed">
            <strong>Definisi:</strong> Invoice RS yang sudah lewat jatuh tempo dan belum dibayar.
            {{ kpi.overdue_invoices }} invoice overdue.
            Risiko: KSM tetap harus lunasi Bank meskipun RS belum bayar.
          </p>
        </div>
      </div>
    </div>

    <!-- Alur Uang — terminologi visual -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
      <p class="text-xs font-bold text-[#666] uppercase tracking-wide mb-4">Alur Uang dalam Ekosistem KSM</p>
      <div class="flex items-center justify-center gap-2 flex-wrap text-xs">
        <div class="px-3 py-2 bg-blue-100 text-blue-700 rounded-lg font-bold text-center">
          <p>BANK</p>
          <p class="text-[9px] font-normal mt-0.5">Penyedia SCF</p>
        </div>
        <div class="flex flex-col items-center text-[10px] text-[#999]">
          <span>Bayar Distributor</span>
          <UIcon name="i-lucide-arrow-right" class="text-blue-500"/>
          <span class="text-[9px]">(atas nama KSM)</span>
        </div>
        <div class="px-3 py-2 bg-amber-100 text-amber-700 rounded-lg font-bold text-center">
          <p>DISTRIBUTOR</p>
          <p class="text-[9px] font-normal mt-0.5">Supplier Obat/Alkes</p>
        </div>
        <div class="flex flex-col items-center text-[10px] text-[#999]">
          <span>Kirim Barang</span>
          <UIcon name="i-lucide-arrow-right" class="text-amber-500"/>
          <span class="text-[9px]">(langsung ke RS)</span>
        </div>
        <div class="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg font-bold text-center">
          <p>RS</p>
          <p class="text-[9px] font-normal mt-0.5">End User + Penjamin SCF</p>
        </div>
      </div>
      <div class="flex items-center justify-center gap-2 mt-3 flex-wrap text-xs">
        <div class="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg font-bold">RS</div>
        <div class="flex flex-col items-center text-[10px] text-[#999]">
          <span>BPJS cair → SI transfer</span>
          <UIcon name="i-lucide-arrow-right" class="text-emerald-500"/>
        </div>
        <div class="px-3 py-2 bg-[#6b1525]/10 text-[#6b1525] rounded-lg font-bold text-center">
          <p>KSM</p>
          <p class="text-[9px] font-normal mt-0.5">Intermediary</p>
        </div>
        <div class="flex flex-col items-center text-[10px] text-[#999]">
          <span>Lunasi hutang SCF</span>
          <UIcon name="i-lucide-arrow-right" class="text-[#6b1525]"/>
        </div>
        <div class="px-3 py-2 bg-blue-100 text-blue-700 rounded-lg font-bold">BANK</div>
      </div>
      <p class="text-[10px] text-[#aaa] text-center mt-3">
        Jika RS kekurangan dana → Bank cover shortfall → Fasilitas kredit bunga harian (50% KSM · 50% RS)
      </p>
    </div>

    <!-- Glosarium Terminologi -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-5 py-3 bg-[#ebebeb] border-b border-[#e5e5e5]">
        <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Glosarium Terminologi Keuangan KSM</p>
      </div>
      <div class="p-5 grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
        <div v-for="term in [
          { name: 'SCF (Supply Chain Finance)', desc: 'Fasilitas pembiayaan dari Bank. Bank bayar Distributor atas nama KSM. KSM lunasi ke Bank setelah RS bayar.' },
          { name: 'Reverse Factoring', desc: 'Jenis SCF dimana pembeli (KSM) yang mengajukan, bukan penjual (Distributor). Bank menilai risiko berdasarkan pembeli + penjamin (RS).' },
          { name: 'Standing Instruction (SI)', desc: 'Instruksi tetap RS ke bank custodian untuk auto-transfer dana ke KSM setelah BPJS cair. Menjamin pembayaran otomatis.' },
          { name: 'BPJS Kesehatan', desc: 'Sumber pembayaran utama RS. RS klaim ke BPJS → dana cair ke rekening RS → SI transfer ke KSM sesuai nilai invoice/PO.' },
          { name: 'Shortfall', desc: 'Kekurangan dana saat BPJS tidak menutupi 100% nilai invoice. Bank cover kekurangan ini sebagai fasilitas kredit.' },
          { name: 'Bunga Harian', desc: 'Bunga atas shortfall yang dicover Bank, dihitung per hari. Ditanggung 50% KSM + 50% RS sampai lunas.' },
          { name: 'HAP (Harga Acuan Pemerintah)', desc: 'Harga ceiling dari Kemkes untuk obat FORNAS. Dasar negosiasi KSM dengan Distributor. Sumber: KFA SATUSEHAT.' },
          { name: 'HET (Harga Eceran Tertinggi)', desc: 'Harga maksimum penjualan ke end consumer. Spread HET-HAP = potensi margin KSM.' },
          { name: 'DSCR (Debt Service Coverage Ratio)', desc: 'Kemampuan KSM melunasi hutang dari cashflow. DSCR = (Revenue - OpEx) / (Pokok + Bunga). Target: >1.25x.' },
          { name: 'Collection Rate', desc: 'Persentase piutang RS yang berhasil ditagih. Semakin tinggi = semakin sehat cashflow KSM.' },
          { name: 'Gross Margin', desc: 'Selisih invoice RS (revenue) dengan disbursement Bank ke Distributor (COGS), dibagi revenue. Target KSM: 8-15%.' },
          { name: 'RS sebagai Co-Guarantor', desc: 'RS ikut menjamin fasilitas SCF. Ini mengurangi risiko Bank dan memungkinkan bunga lebih rendah + limit lebih tinggi.' },
        ]" :key="term.name" class="p-3 bg-white rounded-lg border border-[#ebebeb]">
          <p class="font-bold text-[#1a1a1a] mb-1">{{ term.name }}</p>
          <p class="text-[#666] leading-relaxed">{{ term.desc }}</p>
        </div>
      </div>
    </div>

    <!-- Strategy Cards -->
    <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Modul Strategi</p>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <NuxtLink v-for="s in strategies" :key="s.title" :to="s.to"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 hover:border-[#6b1525]/40 transition-all group">
        <div class="flex items-start gap-4 mb-3">
          <div :class="[s.bg, 'w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="s.icon" :class="[s.color, 'text-xl']"/>
          </div>
          <div class="flex-1">
            <h3 class="text-sm font-bold text-[#1a1a1a] group-hover:text-[#6b1525] transition-colors">{{ s.title }}</h3>
            <p class="text-[10px] font-semibold text-[#6b1525] mt-0.5">{{ s.subtitle }}</p>
          </div>
        </div>
        <p class="text-xs text-[#999] leading-relaxed">{{ s.desc }}</p>
      </NuxtLink>
    </div>
  </div>
</template>
