<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Katalog Produk Distributor' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const items = ref<any[]>([])
const search = ref('')

// Modal state
const showModal = ref(false)
const editingItem = ref<any>(null)
const saving = ref(false)
const deleteConfirm = ref<string | null>(null)
const actionError = ref<string | null>(null)

const form = ref({
  kfa_code: '', name: '', catalog_type: 'obat', manufacturer: '', uom: 'tablet',
  hna_price: 0, sell_price: 0, min_order_qty: 10, stock_available: 0,
  lead_time_days: 3, payment_terms: 'net_30', is_available: true,
})

const filtered = computed(() =>
  search.value.trim()
    ? items.value.filter(i => i.name.toLowerCase().includes(search.value.toLowerCase()) || i.kfa_code.includes(search.value))
    : items.value
)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('supplier_catalog_items')
    .select('id,kfa_code,catalog_type,name,manufacturer,uom,hna_price,sell_price,min_order_qty,stock_available,lead_time_days,payment_terms,is_available,metadata')
    .eq('tenant_id', tenantId.value)
    .order('name', { ascending: true })
    .limit(200)
  items.value = data ?? []
  loading.value = false
}

function openAdd() {
  editingItem.value = null
  form.value = { kfa_code: '', name: '', catalog_type: 'obat', manufacturer: '', uom: 'tablet', hna_price: 0, sell_price: 0, min_order_qty: 10, stock_available: 0, lead_time_days: 3, payment_terms: 'net_30', is_available: true }
  actionError.value = null
  showModal.value = true
}

function openEdit(item: any) {
  editingItem.value = item
  form.value = {
    kfa_code: item.kfa_code, name: item.name, catalog_type: item.catalog_type ?? 'obat',
    manufacturer: item.manufacturer ?? '', uom: item.uom ?? 'tablet',
    hna_price: item.hna_price ?? 0, sell_price: item.sell_price ?? 0,
    min_order_qty: item.min_order_qty ?? 10, stock_available: item.stock_available ?? 0,
    lead_time_days: item.lead_time_days ?? 3, payment_terms: item.payment_terms ?? 'net_30',
    is_available: item.is_available ?? true,
  }
  actionError.value = null
  showModal.value = true
}

async function saveItem() {
  if (!tenantId.value) return
  saving.value = true
  actionError.value = null
  try {
    if (editingItem.value) {
      const { error } = await supabase.from('supplier_catalog_items').update({
        name: form.value.name, catalog_type: form.value.catalog_type, manufacturer: form.value.manufacturer,
        uom: form.value.uom, hna_price: form.value.hna_price, sell_price: form.value.sell_price,
        min_order_qty: form.value.min_order_qty, stock_available: form.value.stock_available,
        lead_time_days: form.value.lead_time_days, payment_terms: form.value.payment_terms,
        is_available: form.value.is_available,
      }).eq('id', editingItem.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('supplier_catalog_items').insert({
        tenant_id: tenantId.value, ...form.value,
        metadata: { distributor_name: 'Distributor', distributor_id: tenantId.value },
      })
      if (error) throw error
    }
    showModal.value = false
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal menyimpan'
  }
  saving.value = false
}

async function deleteItem(id: string) {
  actionError.value = null
  try {
    const { error } = await supabase.from('supplier_catalog_items').delete().eq('id', id)
    if (error) throw error
    deleteConfirm.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal menghapus'
  }
}

const typeColor: Record<string, string> = {
  obat: 'bg-blue-100 text-blue-700', alkes: 'bg-purple-100 text-purple-700', bmhp: 'bg-amber-100 text-amber-700',
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Katalog Produk</h1>
        <p class="text-sm text-[#999] mt-0.5">Kelola produk yang tersedia untuk KSM — tambah, edit harga/stok, hapus</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-2 px-4 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
          <UIcon name="i-lucide-search" class="text-sm text-[#999]"/>
          <input v-model="search" type="text" placeholder="Nama atau kode KFA..."
            class="bg-transparent text-xs text-[#1a1a1a] outline-none placeholder:text-[#999] w-40">
        </div>
        <button @click="openAdd" class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors">
          <UIcon name="i-lucide-plus" class="text-sm"/> Tambah Produk
        </button>
      </div>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="filtered.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-layers" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">{{ search ? 'Tidak ada produk cocok' : 'Belum ada produk di katalog' }}</p>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999]">KFA / Nama</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Tipe</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Harga Jual</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-center">Stok</th>
            <th class="px-4 py-3 font-semibold text-[#999]">Status</th>
            <th class="px-4 py-3 font-semibold text-[#999] text-right">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="item in filtered" :key="item.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-2.5">
              <p class="font-medium text-[#1a1a1a]">{{ item.name }}</p>
              <p class="text-[10px] font-mono text-[#aaa]">{{ item.kfa_code }} · {{ item.uom }}</p>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full font-medium text-[10px]', typeColor[item.catalog_type] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ item.catalog_type?.toUpperCase() }}
              </span>
            </td>
            <td class="px-4 py-2.5 text-right font-bold text-[#1a1a1a]">{{ fmtRp(item.sell_price) }}</td>
            <td class="px-4 py-2.5 text-center">
              <span :class="['font-semibold', item.stock_available > 0 ? 'text-emerald-600' : 'text-red-500']">
                {{ item.stock_available > 0 ? item.stock_available.toLocaleString('id-ID') : 'Habis' }}
              </span>
            </td>
            <td class="px-4 py-2.5">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium', item.is_available ? 'bg-emerald-100 text-emerald-700' : 'bg-[#f0f0f0] text-[#999]']">
                {{ item.is_available ? 'Aktif' : 'Nonaktif' }}
              </span>
            </td>
            <td class="px-4 py-2.5 text-right">
              <div class="flex items-center justify-end gap-1">
                <button @click="openEdit(item)" class="p-1.5 rounded-lg hover:bg-blue-50 text-blue-600 transition-colors">
                  <UIcon name="i-lucide-edit-3" class="text-sm"/>
                </button>
                <button @click="deleteConfirm = item.id" class="p-1.5 rounded-lg hover:bg-red-50 text-red-500 transition-colors">
                  <UIcon name="i-lucide-trash-2" class="text-sm"/>
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add/Edit Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl">
        <div class="px-6 py-4 border-b border-[#f0f0f0]">
          <h3 class="font-bold text-[#1a1a1a]">{{ editingItem ? 'Edit Produk' : 'Tambah Produk Baru' }}</h3>
        </div>
        <div class="p-6 space-y-3 max-h-[60vh] overflow-y-auto">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Kode KFA</label>
              <input v-model="form.kfa_code" type="text" :disabled="!!editingItem" placeholder="10.01.1.02.001234"
                class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525] disabled:bg-[#f0f0f0]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Tipe</label>
              <select v-model="form.catalog_type" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none">
                <option value="obat">Obat</option>
                <option value="alkes">Alkes</option>
                <option value="bmhp">BMHP</option>
              </select>
            </div>
          </div>
          <div>
            <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Nama Produk</label>
            <input v-model="form.name" type="text" placeholder="Nama produk lengkap"
              class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Manufacturer</label>
              <input v-model="form.manufacturer" type="text" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Satuan (UoM)</label>
              <input v-model="form.uom" type="text" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
          </div>
          <div class="grid grid-cols-3 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">HNA (Rp)</label>
              <input v-model.number="form.hna_price" type="number" min="0" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Harga Jual (Rp)</label>
              <input v-model.number="form.sell_price" type="number" min="0" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Stok</label>
              <input v-model.number="form.stock_available" type="number" min="0" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
          </div>
          <div class="grid grid-cols-3 gap-3">
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Min Order</label>
              <input v-model.number="form.min_order_qty" type="number" min="1" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Lead Time (hari)</label>
              <input v-model.number="form.lead_time_days" type="number" min="0" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs outline-none focus:border-[#6b1525]">
            </div>
            <div>
              <label class="text-[10px] text-[#999] uppercase font-semibold mb-1 block">Termin</label>
              <select v-model="form.payment_terms" class="w-full border border-[#e5e5e5] rounded-lg px-3 py-2 text-xs bg-white outline-none">
                <option value="cod">COD</option>
                <option value="net_7">Net 7</option>
                <option value="net_14">Net 14</option>
                <option value="net_30">Net 30</option>
                <option value="net_45">Net 45</option>
                <option value="net_60">Net 60</option>
              </select>
            </div>
          </div>
          <label class="flex items-center gap-2 text-xs cursor-pointer">
            <input v-model="form.is_available" type="checkbox" class="accent-[#6b1525]">
            <span class="text-[#666]">Produk tersedia untuk dijual</span>
          </label>
        </div>
        <div class="px-6 py-4 border-t border-[#f0f0f0] flex gap-3">
          <button @click="saveItem" :disabled="saving || !form.kfa_code || !form.name"
            class="flex-1 py-2.5 bg-[#6b1525] text-white text-sm font-bold rounded-xl hover:bg-[#5a1120] disabled:opacity-50 transition-colors">
            {{ saving ? 'Menyimpan...' : editingItem ? 'Simpan Perubahan' : 'Tambah Produk' }}
          </button>
          <button @click="showModal = false" class="px-5 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5]">Batal</button>
        </div>
      </div>
    </div>

    <!-- Delete Confirm -->
    <div v-if="deleteConfirm" class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-2xl w-full max-w-sm overflow-hidden shadow-2xl p-6 text-center">
        <UIcon name="i-lucide-alert-triangle" class="text-3xl text-red-500 mb-3"/>
        <h3 class="font-bold text-[#1a1a1a] mb-1">Hapus Produk?</h3>
        <p class="text-xs text-[#999] mb-4">Produk akan dihapus dari katalog. Tindakan ini tidak bisa dibatalkan.</p>
        <div class="flex gap-3">
          <button @click="deleteItem(deleteConfirm!)"
            class="flex-1 py-2.5 bg-red-600 text-white text-sm font-bold rounded-xl hover:bg-red-700 transition-colors">Hapus</button>
          <button @click="deleteConfirm = null"
            class="flex-1 py-2.5 border border-[#e5e5e5] text-[#666] text-sm rounded-xl hover:bg-[#f5f5f5]">Batal</button>
        </div>
      </div>
    </div>
  </div>
</template>
