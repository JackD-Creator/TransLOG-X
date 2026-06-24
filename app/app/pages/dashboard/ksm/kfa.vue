<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Masterdata KFA' })

const supabase = useSupabaseClient()

const search = ref('')
const filterType = ref<'all' | 'obat' | 'alkes'>('all')
const loading = ref(false)
const items = ref<any[]>([])
const searched = ref(false)
const totalCount = ref(0)

async function doSearch() {
  loading.value = true
  searched.value = true

  const q = search.value.trim()

  let qObat = supabase.from('kfa_drugs').select('kfa_code, name, fix_price, het_price, is_fornas, kelas_terapi', { count: 'exact' }).limit(40)
  let qAlkes = supabase.from('kfa_alkes').select('kfa_code, name, fix_price, med_dev_kelas_risiko', { count: 'exact' }).limit(40)

  if (q) {
    qObat  = qObat.or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)
    qAlkes = qAlkes.or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)
  }

  const results: any[] = []

  if (filterType.value !== 'alkes') {
    const { data: drugs } = await qObat
    results.push(...(drugs ?? []).map(d => ({ ...d, type: 'obat' })))
  }
  if (filterType.value !== 'obat') {
    const { data: alkes } = await qAlkes
    results.push(...(alkes ?? []).map(a => ({ ...a, type: 'alkes' })))
  }

  items.value = results
  totalCount.value = results.length
  loading.value = false
}



onMounted(() => doSearch())
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Masterdata KFA — Kemkes</h1>
      <p class="text-sm text-[#999] mt-0.5">Katalog Farmasi & Alkes nasional dari SATUSEHAT Kemkes · Harga: HAP & HET</p>
    </div>

    <!-- Search + Filter -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
      <div class="flex-1 flex items-center gap-2 px-4 py-2.5 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
        <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
        <input
          v-model="search"
          type="text"
          placeholder="Nama obat, alkes, atau kode KFA..."
          class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#999]"
          @keydown.enter="doSearch"
        >
      </div>
      <div class="flex rounded-lg border border-[#e5e5e5] overflow-hidden text-xs font-medium">
        <button v-for="t in [{v:'all',l:'Semua'},{v:'obat',l:'Obat'},{v:'alkes',l:'Alkes'}]" :key="t.v"
          :class="['px-3 py-2.5 transition-colors', filterType === t.v ? 'bg-[#6b1525] text-white' : 'bg-[#f0f0f0] text-[#666] hover:bg-[#ebebeb]']"
          @click="filterType = t.v as any">
          {{ t.l }}
        </button>
      </div>
      <button class="px-4 py-2.5 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors" :disabled="loading" @click="doSearch">
        {{ loading ? '...' : 'Cari' }}
      </button>
    </div>

    <!-- Pricing info -->
    <div class="flex gap-3 text-xs">
      <div class="flex items-center gap-1.5">
        <span class="w-3 h-3 rounded-full bg-blue-200 inline-block"/>
        <span class="text-[#666]">HAP = Harga Acuan Pemerintah (harga pabrik ke PBF)</span>
      </div>
      <div class="flex items-center gap-1.5">
        <span class="w-3 h-3 rounded-full bg-amber-200 inline-block"/>
        <span class="text-[#666]">HET = Harga Eceran Tertinggi (batas atas jual ke pasien)</span>
      </div>
    </div>

    <!-- Table -->
    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="searched && items.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-database" class="text-3xl text-[#999]"/>
      <p class="text-sm text-[#999]">Tidak ada item ditemukan</p>
    </div>

    <div v-else-if="items.length > 0" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
        <p class="text-xs text-[#999]">Menampilkan <strong class="text-[#1a1a1a]">{{ items.length }}</strong> item</p>
        <p class="text-[10px] text-[#999]">Sumber: KFA SATUSEHAT Kemkes</p>
      </div>
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Kode KFA</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nama</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">HAP / Fix Price</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">HET</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Info</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in items" :key="item.kfa_code + item.type" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-2.5 font-mono text-[#666]">{{ item.kfa_code }}</td>
            <td class="px-4 py-2.5 font-medium text-[#1a1a1a] max-w-xs">{{ item.name }}</td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full font-medium text-[10px]',
                item.type === 'obat' ? 'bg-blue-100 text-blue-700' : 'bg-purple-100 text-purple-700']">
                {{ item.type.toUpperCase() }}
              </span>
            </td>
            <td class="px-4 py-2.5 font-bold text-blue-700">{{ fmtRp(item.fix_price) }}</td>
            <td class="px-4 py-2.5 text-amber-700">{{ item.het_price ? fmtRp(item.het_price) : '—' }}</td>
            <td class="px-4 py-2.5 flex items-center gap-1.5">
              <span v-if="item.is_fornas" class="px-1.5 py-0.5 rounded text-[10px] bg-emerald-100 text-emerald-700 font-medium">FORNAS</span>
              <span v-if="item.kelas_terapi" class="text-[#999] text-[10px]">{{ item.kelas_terapi }}</span>
              <span v-if="item.med_dev_kelas_risiko" :class="['px-1.5 py-0.5 rounded text-[10px] font-medium',
                item.med_dev_kelas_risiko === 'A' ? 'bg-emerald-100 text-emerald-700' :
                item.med_dev_kelas_risiko === 'B' ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700']">
                Kelas {{ item.med_dev_kelas_risiko }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
