<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Cek Supplier' })

const supabase = useSupabaseClient()

const activeTab = ref<'obat' | 'alkes'>('obat')
const search = ref('')
const loading = ref(false)
const results = ref<any[]>([])
const totalCount = ref(0)
const page = ref(1)
const PAGE_SIZE = 50

const totalPages = computed(() => Math.ceil(totalCount.value / PAGE_SIZE))

async function load() {
  loading.value = true
  const from = (page.value - 1) * PAGE_SIZE
  const to = from + PAGE_SIZE - 1
  const q = search.value.trim()

  if (activeTab.value === 'obat') {
    let query = supabase
      .from('kfa_drugs')
      .select('kfa_code, name, nama_dagang, dosage_form, strength, farmalkes_type, uom, fix_price, het_price, is_fornas, manufacturer, distributor', { count: 'exact' })
      .order('name', { ascending: true })
      .range(from, to)

    if (q) query = query.or(`name.ilike.%${q}%,nama_dagang.ilike.%${q}%,kfa_code.ilike.%${q}%`)

    const { data, count } = await query
    totalCount.value = count ?? 0
    results.value = (data ?? []).map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      brand: d.nama_dagang,
      detail: d.strength ?? '',
      satuan: d.dosage_form ?? d.uom ?? '-',
      hap: d.fix_price,
      het: d.het_price,
      is_fornas: d.is_fornas,
      supplier: d.distributor ?? d.manufacturer ?? '-',
      tipe: 'OBAT',
    }))
  } else {
    let query = supabase
      .from('kfa_alkes')
      .select('kfa_code, name, farmalkes_type, med_dev_kelas_risiko, uom, fix_price, manufacturer, distributor', { count: 'exact' })
      .order('name', { ascending: true })
      .range(from, to)

    if (q) query = query.or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)

    const { data, count } = await query
    totalCount.value = count ?? 0
    results.value = (data ?? []).map(d => ({
      kfa_code: d.kfa_code,
      name: d.name,
      brand: d.med_dev_kelas_risiko ? `Kelas Risiko ${d.med_dev_kelas_risiko}` : null,
      detail: d.farmalkes_type ?? '',
      satuan: d.uom ?? '-',
      hap: d.fix_price,
      het: null,
      is_fornas: false,
      supplier: [d.distributor, d.manufacturer].filter(Boolean).join(' · ') || '-',
      tipe: 'ALKES',
    }))
  }

  loading.value = false
}

let searchTimer: ReturnType<typeof setTimeout>
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => { page.value = 1; load() }, 400)
}

function switchTab(tab: 'obat' | 'alkes') {
  activeTab.value = tab
  search.value = ''
  page.value = 1
  load()
}

function goPage(p: number) {
  if (p < 1 || p > totalPages.value) return
  page.value = p
  load()
}

const pageWindow = computed(() => {
  const pages: number[] = []
  const cur = page.value
  const tot = totalPages.value
  const start = Math.max(1, cur - 2)
  const end = Math.min(tot, cur + 2)
  for (let i = start; i <= end; i++) pages.push(i)
  return pages
})

onMounted(load)
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-start justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Cek Supplier & Referensi KFA</h1>
        <p class="text-sm text-[#999] mt-0.5">
          Referensi KFA SATUSEHAT Kemkes —
          <span class="text-[#1a1a1a] font-semibold">{{ totalCount.toLocaleString('id-ID') }}</span>
          {{ activeTab === 'obat' ? 'obat' : 'alat kesehatan' }} terdaftar
        </p>
      </div>
    </div>

    <!-- Tab + Search -->
    <div class="flex items-center gap-3 flex-wrap">
      <div class="flex gap-1.5">
        <button @click="switchTab('obat')"
          :class="['px-4 py-2 rounded-lg text-xs font-semibold transition-colors',
            activeTab === 'obat' ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
          Obat (KFA Drugs)
        </button>
        <button @click="switchTab('alkes')"
          :class="['px-4 py-2 rounded-lg text-xs font-semibold transition-colors',
            activeTab === 'alkes' ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
          Alkes (KFA Alkes)
        </button>
      </div>
      <div class="flex items-center gap-2 px-4 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] flex-1 max-w-sm">
        <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
        <input v-model="search" @input="onSearch" type="text"
          :placeholder="activeTab === 'obat' ? 'Cari nama obat, nama dagang, kode KFA...' : 'Cari nama alkes atau kode KFA...'"
          class="bg-transparent text-xs text-[#1a1a1a] outline-none placeholder:text-[#999] w-full">
        <button v-if="search" @click="search = ''; page = 1; load()" class="text-[#ccc] hover:text-[#999]">
          <UIcon name="i-lucide-x" class="text-xs"/>
        </button>
      </div>
      <p class="text-[10px] text-[#aaa] ml-auto">Sumber: KFA SATUSEHAT Kemkes · HAP = Harga Acuan Pemerintah</p>
    </div>

    <!-- Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div v-if="loading" class="flex items-center justify-center py-20">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>

      <div v-else-if="results.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-search-x" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Tidak ada hasil untuk "{{ search }}"</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-xs min-w-[900px]">
          <thead class="border-b border-[#e5e5e5] bg-[#ebebeb] sticky top-0">
            <tr class="text-left">
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide w-32">Kode KFA</th>
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Nama / Kekuatan</th>
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide w-28">Satuan/Bentuk</th>
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide">Manufacturer / Distributor</th>
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-right w-32">HAP</th>
              <th v-if="activeTab === 'obat'" class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-right w-32">HET</th>
              <th class="px-4 py-3 font-semibold text-[#666] uppercase tracking-wide text-center w-20">
                {{ activeTab === 'obat' ? 'FORNAS' : 'Steril' }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="item in results" :key="item.kfa_code" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-3 font-mono text-[10px] text-[#999]">{{ item.kfa_code }}</td>
              <td class="px-4 py-3">
                <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
                <p v-if="item.brand" class="text-[10px] text-[#999] mt-0.5">{{ item.brand }}</p>
                <p v-if="item.detail" class="text-[10px] text-[#aaa]">{{ item.detail }}</p>
              </td>
              <td class="px-4 py-3 text-[#666]">{{ item.satuan }}</td>
              <td class="px-4 py-3">
                <p v-if="item.supplier && item.supplier !== '-'" class="text-[#555]">{{ item.supplier }}</p>
                <span v-else class="text-[#ccc]">—</span>
              </td>
              <td class="px-4 py-3 text-right">
                <span v-if="item.hap" class="font-semibold text-[#1a1a1a]">{{ fmtRp(item.hap) }}</span>
                <span v-else class="text-[#ccc]">—</span>
              </td>
              <td v-if="activeTab === 'obat'" class="px-4 py-3 text-right">
                <span v-if="item.het" class="text-amber-700 font-semibold">{{ fmtRp(item.het) }}</span>
                <span v-else class="text-[#ccc]">—</span>
              </td>
              <td class="px-4 py-3 text-center">
                <UIcon v-if="item.is_fornas" name="i-lucide-check-circle" class="text-emerald-600 text-base"/>
                <span v-else class="text-[#ddd] text-base">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="totalPages > 1 && !loading"
        class="px-4 py-3 border-t border-[#e5e5e5] flex items-center justify-between bg-[#fafafa]">
        <p class="text-xs text-[#999]">
          Halaman {{ page }} dari {{ totalPages.toLocaleString('id-ID') }}
          · {{ ((page - 1) * PAGE_SIZE + 1).toLocaleString('id-ID') }}–{{ Math.min(page * PAGE_SIZE, totalCount).toLocaleString('id-ID') }}
          dari {{ totalCount.toLocaleString('id-ID') }} item
        </p>
        <div class="flex items-center gap-1">
          <button @click="goPage(1)" :disabled="page === 1"
            class="px-2 py-1.5 rounded text-[10px] text-[#666] hover:bg-[#ebebeb] disabled:opacity-30 transition-colors">
            «
          </button>
          <button @click="goPage(page - 1)" :disabled="page === 1"
            class="px-2.5 py-1.5 rounded text-[10px] text-[#666] hover:bg-[#ebebeb] disabled:opacity-30 transition-colors">
            ‹
          </button>
          <button v-for="p in pageWindow" :key="p" @click="goPage(p)"
            :class="['px-2.5 py-1.5 rounded text-[10px] font-semibold transition-colors',
              p === page ? 'bg-[#6b1525] text-white' : 'text-[#666] hover:bg-[#ebebeb]']">
            {{ p }}
          </button>
          <button @click="goPage(page + 1)" :disabled="page === totalPages"
            class="px-2.5 py-1.5 rounded text-[10px] text-[#666] hover:bg-[#ebebeb] disabled:opacity-30 transition-colors">
            ›
          </button>
          <button @click="goPage(totalPages)" :disabled="page === totalPages"
            class="px-2 py-1.5 rounded text-[10px] text-[#666] hover:bg-[#ebebeb] disabled:opacity-30 transition-colors">
            »
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
