<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Referensi Harga KFA' })

const supabase = useSupabaseClient()
const search = ref('')
const filterType = ref<'all' | 'obat' | 'alkes'>('all')
const loading = ref(false)
const items = ref<any[]>([])
const searched = ref(false)

async function doSearch() {
  loading.value = true
  searched.value = true
  const q = search.value.trim()

  let qObat  = supabase.from('kfa_drugs').select('kfa_code,name,fix_price,het_price,is_fornas,kelas_terapi').limit(40)
  let qAlkes = supabase.from('kfa_alkes').select('kfa_code,name,fix_price,med_dev_kelas_risiko').limit(40)

  if (q) {
    qObat  = qObat.or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)
    qAlkes = qAlkes.or(`name.ilike.%${q}%,kfa_code.ilike.%${q}%`)
  }

  const results: any[] = []
  if (filterType.value !== 'alkes') {
    const { data } = await qObat
    results.push(...(data ?? []).map(d => ({ ...d, type: 'obat' })))
  }
  if (filterType.value !== 'obat') {
    const { data } = await qAlkes
    results.push(...(data ?? []).map(a => ({ ...a, type: 'alkes' })))
  }
  items.value = results
  loading.value = false
}

// HNA estimasi = HAP × 1.10 (harga beli distributor ke pabrikan/principal)
// HET = batas atas jual ke apotek/RS
function hna(hap: number | null) { return hap ? hap * 1.10 : null }

function fmtRp(n: number | null) {
  if (!n) return '-'
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(n)
}

onMounted(doSearch)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Referensi Harga KFA</h1>
      <p class="text-sm text-[#999] mt-0.5">Katalog Farmasi & Alkes nasional Kemkes · HAP (floor) → HNA est. → HET (ceiling)</p>
    </div>

    <!-- KFA Legend -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
      <div class="bg-blue-50 border border-blue-100 rounded-xl p-4">
        <p class="text-xs font-bold text-blue-700 mb-1">HAP — Harga Acuan Pemerintah</p>
        <p class="text-[11px] text-blue-600">Harga referensi pemerintah (floor). Basis negosiasi distributor ke pabrikan/principal. Distributor tidak boleh jual di bawah ini ke RS.</p>
      </div>
      <div class="bg-amber-50 border border-amber-100 rounded-xl p-4">
        <p class="text-xs font-bold text-amber-700 mb-1">HNA est. = HAP × 1.10</p>
        <p class="text-[11px] text-amber-600">Harga Netto Apotek estimasi — harga aktual distributor ke fasilitas kesehatan. Spread 8–12% di atas HAP tergantung margin channel.</p>
      </div>
      <div class="bg-emerald-50 border border-emerald-100 rounded-xl p-4">
        <p class="text-xs font-bold text-emerald-700 mb-1">HET — Harga Eceran Tertinggi</p>
        <p class="text-[11px] text-emerald-600">Batas atas jual ke konsumen akhir (pasien). Tidak boleh dilanggar. Selisih HNA → HET adalah potensi margin RS/KSM.</p>
      </div>
    </div>

    <!-- Search -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
      <div class="flex-1 flex items-center gap-2 px-4 py-2.5 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
        <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
        <input v-model="search" type="text" placeholder="Cari nama produk atau kode KFA..."
          class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#999]"
          @keydown.enter="doSearch">
      </div>
      <div class="flex rounded-lg border border-[#e5e5e5] overflow-hidden text-xs font-medium">
        <button v-for="t in [{v:'all',l:'Semua'},{v:'obat',l:'Obat'},{v:'alkes',l:'Alkes'}]" :key="t.v"
          :class="['px-3 py-2.5 transition-colors', filterType === t.v ? 'bg-[#6b1525] text-white' : 'bg-[#f0f0f0] text-[#666] hover:bg-[#ebebeb]']"
          @click="filterType = t.v as any; doSearch()">{{ t.l }}</button>
      </div>
      <button @click="doSearch" :disabled="loading"
        class="px-4 py-2.5 bg-[#6b1525] text-white text-xs font-semibold rounded-lg hover:bg-[#5a1120] transition-colors disabled:opacity-50">
        {{ loading ? '...' : 'Cari' }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="searched && !items.length" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-database" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Tidak ada item ditemukan</p>
    </div>

    <div v-else-if="items.length" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="px-4 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
        <p class="text-xs text-[#999]">Menampilkan <strong class="text-[#1a1a1a]">{{ items.length }}</strong> item · Sumber: KFA SATUSEHAT Kemkes</p>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-xs">
          <thead class="border-b border-[#e5e5e5]">
            <tr class="text-left">
              <th class="px-4 py-3 text-[#999] font-semibold uppercase tracking-wide text-[10px]">Kode KFA</th>
              <th class="px-4 py-3 text-[#999] font-semibold uppercase tracking-wide text-[10px]">Nama Produk</th>
              <th class="px-4 py-3 text-[#999] font-semibold uppercase tracking-wide text-[10px]">Tipe</th>
              <th class="px-4 py-3 text-right text-[#999] font-semibold uppercase tracking-wide text-[10px]">HAP</th>
              <th class="px-4 py-3 text-right text-[#999] font-semibold uppercase tracking-wide text-[10px]">HNA est.</th>
              <th class="px-4 py-3 text-right text-[#999] font-semibold uppercase tracking-wide text-[10px]">HET</th>
              <th class="px-4 py-3 text-[#999] font-semibold uppercase tracking-wide text-[10px]">Label</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="item in items" :key="item.kfa_code + item.type" class="hover:bg-[#ebebeb] transition-colors">
              <td class="px-4 py-2.5 font-mono text-[#666] text-[10px]">{{ item.kfa_code }}</td>
              <td class="px-4 py-2.5 font-medium text-[#1a1a1a] max-w-[220px]">
                <p class="truncate" :title="item.name">{{ item.name }}</p>
                <p v-if="item.kelas_terapi" class="text-[10px] text-[#aaa] mt-0.5">{{ item.kelas_terapi }}</p>
              </td>
              <td class="px-4 py-2.5">
                <span :class="['px-2 py-0.5 rounded-full font-medium text-[10px]',
                  item.type === 'obat' ? 'bg-blue-100 text-blue-700' : 'bg-purple-100 text-purple-700']">
                  {{ item.type.toUpperCase() }}
                </span>
              </td>
              <td class="px-4 py-2.5 text-right text-[#555]">{{ fmtRp(item.fix_price) }}</td>
              <td class="px-4 py-2.5 text-right font-semibold text-amber-700">{{ fmtRp(hna(item.fix_price)) }}</td>
              <td class="px-4 py-2.5 text-right font-semibold text-emerald-700">{{ item.het_price ? fmtRp(item.het_price) : '—' }}</td>
              <td class="px-4 py-2.5">
                <div class="flex items-center gap-1 flex-wrap">
                  <span v-if="item.is_fornas" class="px-1.5 py-0.5 rounded text-[10px] bg-emerald-100 text-emerald-700 font-medium">FORNAS</span>
                  <span v-if="item.med_dev_kelas_risiko"
                    :class="['px-1.5 py-0.5 rounded text-[10px] font-medium',
                      item.med_dev_kelas_risiko === 'A' ? 'bg-emerald-100 text-emerald-700' :
                      item.med_dev_kelas_risiko === 'B' ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700']">
                    Kelas {{ item.med_dev_kelas_risiko }}
                  </span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
