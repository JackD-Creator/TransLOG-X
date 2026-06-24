<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Cek Supplier' })

const supabase = useSupabaseClient()

const search = ref('')
const loading = ref(false)
const results = ref<any[]>([])
const searched = ref(false)
const activeTab = ref<'obat' | 'alkes'>('obat')

async function doSearch() {
  if (!search.value.trim()) return
  loading.value = true
  searched.value = true

  const q = search.value.trim()

  if (activeTab.value === 'obat') {
    const { data } = await supabase
      .from('kfa_drugs')
      .select('kfa_code, name, nama_dagang, dosage_form, strength, uom, fix_price, het_price, is_fornas, manufacturer, distributor')
      .or(`name.ilike.%${q}%,nama_dagang.ilike.%${q}%,kfa_code.ilike.%${q}%`)
      .order('name', { ascending: true })
      .limit(30)
    results.value = (data ?? []).map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      brand: d.nama_dagang,
      detail: [d.dosage_form, d.strength].filter(Boolean).join(' · '),
      uom: d.uom,
      hap: d.fix_price,
      het: d.het_price,
      is_fornas: d.is_fornas,
      supplier: d.distributor ?? d.manufacturer ?? '-',
      tipe: 'OBAT',
    }))
  } else {
    const { data } = await supabase
      .from('kfa_alkes')
      .select('kfa_code, name, farmalkes_type, uom, fix_price, het_price, manufacturer')
      .or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)
      .order('name', { ascending: true })
      .limit(30)
    results.value = (data ?? []).map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      brand: null,
      detail: d.farmalkes_type ?? '',
      uom: d.uom,
      hap: d.fix_price,
      het: d.het_price,
      is_fornas: false,
      supplier: d.manufacturer ?? '-',
      tipe: 'ALKES',
    }))
  }

  loading.value = false
}

const paymentLabels: Record<string, string> = {
  cod: 'COD', net_7: 'Net 7', net_14: 'Net 14',
  net_30: 'Net 30', net_45: 'Net 45', net_60: 'Net 60',
}
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Cek Ketersediaan Supplier</h1>
      <p class="text-sm text-[#999] mt-0.5">Cari dari referensi KFA Kemkes — obat & alkes beserta harga HAP/HET</p>
    </div>

    <!-- Tab + Search -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
      <div class="flex gap-2">
        <button @click="activeTab = 'obat'; results = []; searched = false"
          :class="['px-4 py-1.5 rounded-lg text-xs font-semibold transition-colors', activeTab === 'obat' ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
          Obat (KFA Drugs)
        </button>
        <button @click="activeTab = 'alkes'; results = []; searched = false"
          :class="['px-4 py-1.5 rounded-lg text-xs font-semibold transition-colors', activeTab === 'alkes' ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
          Alkes (KFA Alkes)
        </button>
      </div>
      <form class="flex gap-3" @submit.prevent="doSearch">
        <div class="flex-1 flex items-center gap-2 px-4 py-2.5 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
          <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
          <input
            v-model="search"
            type="text"
            :placeholder="activeTab === 'obat' ? 'Nama obat, nama dagang, atau kode KFA...' : 'Nama alkes atau kode KFA...'"
            class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#999]"
          >
        </div>
        <button type="submit" :disabled="loading"
          class="px-5 py-2.5 bg-[#6b1525] text-white text-sm font-semibold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
          {{ loading ? 'Mencari...' : 'Cari' }}
        </button>
      </form>
      <p class="text-[11px] text-[#aaa]">Sumber: KFA SATUSEHAT Kemkes · HAP = Harga Acuan Pemerintah · HET = Harga Eceran Tertinggi</p>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <!-- Empty -->
    <div v-else-if="searched && results.length === 0"
      class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-package-x" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada item ditemukan untuk "<strong>{{ search }}</strong>"</p>
    </div>

    <!-- Results -->
    <div v-else-if="results.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
        <p class="text-xs text-[#999]">Ditemukan <strong class="text-[#1a1a1a]">{{ results.length }}</strong> hasil untuk "{{ search }}"</p>
        <span class="text-[10px] text-[#aaa]">Maks 30 hasil</span>
      </div>
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Kode KFA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nama / Detail</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Satuan</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">HAP</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">HET</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">FORNAS</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in results" :key="item.kfa_code" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#666]">{{ item.kfa_code }}</td>
            <td class="px-4 py-3">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p v-if="item.brand" class="text-[#999]">{{ item.brand }}</p>
              <p v-if="item.detail" class="text-[#aaa]">{{ item.detail }}</p>
            </td>
            <td class="px-4 py-3 text-[#666]">{{ item.uom }}</td>
            <td class="px-4 py-3 font-semibold text-[#1a1a1a]">{{ item.hap ? fmtRp(item.hap) : '-' }}</td>
            <td class="px-4 py-3 text-amber-700">{{ item.het ? fmtRp(item.het) : '-' }}</td>
            <td class="px-4 py-3">
              <UIcon v-if="item.is_fornas" name="i-lucide-check-circle" class="text-emerald-600 text-base"/>
              <span v-else class="text-[#ccc]">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
