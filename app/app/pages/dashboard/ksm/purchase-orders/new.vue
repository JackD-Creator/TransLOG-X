<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Buat Purchase Order' })

const supabase = useSupabaseClient()
const router = useRouter()
const { tenantId } = useUserRole()

const saving = ref(false)
const searchQ = ref('')
const searchLoading = ref(false)
const searchResults = ref<any[]>([])

const form = reactive({
  supplier_tenant_id: '',
  payment_terms: 'net_30',
  expected_delivery: '',
  notes: '',
})

const lines = ref<{ kfa_code: string; item_name: string; catalog_type: string; uom: string; ordered_qty: number; unit_price: number }[]>([])

const suppliers = ref<{ id: string; name: string }[]>([])
async function loadSuppliers() {
  const { data } = await supabase.from('tenants')
    .select('id, name').in('type', ['pbf', 'distributor', 'supplier_lain'])
    .order('name')
  suppliers.value = data ?? []
}

let searchTimer: ReturnType<typeof setTimeout>
async function searchKFA() {
  clearTimeout(searchTimer)
  if (!searchQ.value.trim()) { searchResults.value = []; return }
  searchTimer = setTimeout(async () => {
    searchLoading.value = true
    const { data } = await supabase.from('kfa_drugs')
      .select('kfa_code, name, dosage_form, strength, uom, fix_price')
      .or(`name.ilike.%${searchQ.value}%,kfa_code.ilike.%${searchQ.value}%`)
      .limit(10)
    searchResults.value = data ?? []
    searchLoading.value = false
  }, 300)
}

function addItem(drug: any) {
  if (lines.value.find(l => l.kfa_code === drug.kfa_code)) return
  lines.value.push({
    kfa_code: drug.kfa_code,
    item_name: drug.name,
    catalog_type: 'obat',
    uom: drug.uom ?? 'tablet',
    ordered_qty: 1,
    unit_price: Number(drug.fix_price ?? 0),
  })
  searchQ.value = ''
  searchResults.value = []
}

function removeItem(idx: number) { lines.value.splice(idx, 1) }

const subtotal = computed(() => lines.value.reduce((s, l) => s + l.ordered_qty * l.unit_price, 0))
const taxAmount = computed(() => subtotal.value * 0.11)
const total = computed(() => subtotal.value + taxAmount.value)

async function submit() {
  if (!form.supplier_tenant_id) { alert('Pilih distributor/supplier'); return }
  if (lines.value.length === 0) { alert('Tambahkan minimal 1 item'); return }
  saving.value = true

  const poNumber = `KSM-PO-${new Date().getFullYear()}-${String(Date.now()).slice(-5)}`

  const { data: po, error } = await supabase.from('ksm_purchase_orders').insert({
    ksm_tenant_id: tenantId.value,
    supplier_tenant_id: form.supplier_tenant_id,
    po_number: poNumber,
    po_date: new Date().toISOString().slice(0, 10),
    expected_delivery: form.expected_delivery || null,
    payment_terms: form.payment_terms,
    notes: form.notes || null,
    status: 'draft',
    subtotal: subtotal.value,
    tax_amount: taxAmount.value,
    total_amount: total.value,
  }).select('id').single()

  if (error || !po) { alert('Gagal membuat PO: ' + error?.message); saving.value = false; return }

  const lineRows = lines.value.map(l => ({
    po_id: po.id,
    kfa_code: l.kfa_code,
    item_name: l.item_name,
    catalog_type: l.catalog_type,
    uom: l.uom,
    ordered_qty: l.ordered_qty,
    unit_price: l.unit_price,
    tax_rate: 11,
    line_total: l.ordered_qty * l.unit_price,
  }))

  await supabase.from('ksm_po_lines').insert(lineRows)
  saving.value = false
  router.push('/dashboard/ksm/purchase-orders')
}

onMounted(loadSuppliers)

const paymentOptions = [
  { value: 'cod', label: 'COD' }, { value: 'net_7', label: 'Net 7' },
  { value: 'net_14', label: 'Net 14' }, { value: 'net_30', label: 'Net 30' },
  { value: 'net_45', label: 'Net 45' }, { value: 'net_60', label: 'Net 60' },
  { value: 'net_90', label: 'Net 90' },
]
</script>

<template>
  <div class="space-y-5 max-w-4xl">
    <!-- Header -->
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard/ksm/purchase-orders"
        class="w-8 h-8 rounded-lg bg-[#ebebeb] flex items-center justify-center hover:bg-[#e0e0e0] transition-colors">
        <UIcon name="i-lucide-arrow-left" class="text-sm text-[#666]"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Buat Purchase Order Baru</h1>
        <p class="text-sm text-[#999]">Draft PO ke distributor — akan diajukan setelah disimpan</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">

      <!-- Form kiri -->
      <div class="lg:col-span-2 space-y-4">

        <!-- Supplier & Terms -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-4 border-b border-[#ebebeb]">
            <p class="text-sm font-bold text-[#1a1a1a]">Informasi PO</p>
          </div>
          <div class="p-5 space-y-4">
            <div>
              <label class="text-xs font-semibold text-[#666] mb-1.5 block">Distributor / Supplier *</label>
              <select v-model="form.supplier_tenant_id"
                class="w-full bg-white border border-[#e5e5e5] rounded-lg px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525]">
                <option value="">— Pilih Distributor —</option>
                <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
              <p v-if="suppliers.length === 0" class="text-[11px] text-amber-600 mt-1">
                Belum ada distributor terdaftar di sistem
              </p>
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs font-semibold text-[#666] mb-1.5 block">Termin Pembayaran</label>
                <select v-model="form.payment_terms"
                  class="w-full bg-white border border-[#e5e5e5] rounded-lg px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525]">
                  <option v-for="opt in paymentOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
              <div>
                <label class="text-xs font-semibold text-[#666] mb-1.5 block">Estimasi Tiba</label>
                <input v-model="form.expected_delivery" type="date"
                  class="w-full bg-white border border-[#e5e5e5] rounded-lg px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525]">
              </div>
            </div>
            <div>
              <label class="text-xs font-semibold text-[#666] mb-1.5 block">Catatan</label>
              <textarea v-model="form.notes" rows="2" placeholder="Instruksi pengiriman, catatan khusus..."
                class="w-full bg-white border border-[#e5e5e5] rounded-lg px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] resize-none"/>
            </div>
          </div>
        </div>

        <!-- Item Search -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-4 border-b border-[#ebebeb]">
            <p class="text-sm font-bold text-[#1a1a1a]">Item Pesanan</p>
          </div>
          <div class="p-5 space-y-4">
            <!-- Search KFA -->
            <div class="relative">
              <div class="flex items-center gap-2 px-4 py-2.5 rounded-lg border border-[#e5e5e5] bg-white">
                <UIcon name="i-lucide-search" class="text-sm text-[#999] flex-shrink-0"/>
                <input v-model="searchQ" @input="searchKFA" type="text"
                  placeholder="Cari obat dari database KFA Kemkes..."
                  class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#999]">
                <UIcon v-if="searchLoading" name="i-lucide-loader-2" class="text-sm text-[#999] animate-spin flex-shrink-0"/>
              </div>
              <!-- Dropdown results -->
              <div v-if="searchResults.length > 0"
                class="absolute top-full left-0 right-0 mt-1 bg-white border border-[#e5e5e5] rounded-xl shadow-lg z-50 max-h-64 overflow-y-auto">
                <button v-for="drug in searchResults" :key="drug.kfa_code"
                  @click="addItem(drug)" type="button"
                  class="w-full px-4 py-3 flex items-center gap-3 hover:bg-[#f5f5f5] transition-colors text-left border-b border-[#f0f0f0] last:border-0">
                  <div class="flex-1 min-w-0">
                    <p class="text-xs font-semibold text-[#1a1a1a] truncate">{{ drug.name }}</p>
                    <p class="text-[10px] text-[#999]">{{ drug.kfa_code }} · {{ drug.dosage_form }} {{ drug.strength }}</p>
                  </div>
                  <span class="text-xs text-[#6b1525] font-semibold flex-shrink-0">
                    {{ drug.fix_price ? fmtRp(drug.fix_price) : '-' }}
                  </span>
                </button>
              </div>
            </div>

            <!-- Line items table -->
            <div v-if="lines.length > 0" class="border border-[#e5e5e5] rounded-xl overflow-hidden">
              <table class="w-full text-xs">
                <thead class="bg-[#ebebeb] border-b border-[#e5e5e5]">
                  <tr class="text-left">
                    <th class="px-4 py-2.5 font-semibold text-[#666]">Item</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-20 text-center">Qty</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-32 text-right">Harga Satuan</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-32 text-right">Subtotal</th>
                    <th class="px-3 py-2.5 w-8"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-[#e5e5e5] bg-white">
                  <tr v-for="(line, i) in lines" :key="line.kfa_code">
                    <td class="px-4 py-3">
                      <p class="font-semibold text-[#1a1a1a]">{{ line.item_name }}</p>
                      <p class="text-[#999] font-mono">{{ line.kfa_code }} · {{ line.uom }}</p>
                    </td>
                    <td class="px-3 py-3">
                      <input v-model.number="line.ordered_qty" type="number" min="1"
                        class="w-16 text-center bg-[#f5f5f5] border border-[#e5e5e5] rounded-lg px-2 py-1 text-xs outline-none focus:border-[#6b1525]">
                    </td>
                    <td class="px-3 py-3">
                      <input v-model.number="line.unit_price" type="number" min="0"
                        class="w-28 text-right bg-[#f5f5f5] border border-[#e5e5e5] rounded-lg px-2 py-1 text-xs outline-none focus:border-[#6b1525]">
                    </td>
                    <td class="px-3 py-3 text-right font-semibold text-[#1a1a1a]">
                      {{ fmtRp(line.ordered_qty * line.unit_price) }}
                    </td>
                    <td class="px-3 py-3">
                      <button @click="removeItem(i)" type="button"
                        class="text-[#ccc] hover:text-red-500 transition-colors">
                        <UIcon name="i-lucide-trash-2" class="text-sm"/>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <div v-else class="border-2 border-dashed border-[#e5e5e5] rounded-xl p-8 text-center">
              <UIcon name="i-lucide-package-plus" class="text-3xl text-[#ccc] mx-auto mb-2"/>
              <p class="text-sm text-[#999]">Cari dan tambahkan item dari KFA di atas</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Ringkasan kanan -->
      <div class="space-y-4">
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden sticky top-4">
          <div class="px-5 py-4 border-b border-[#ebebeb]">
            <p class="text-sm font-bold text-[#1a1a1a]">Ringkasan PO</p>
          </div>
          <div class="p-5 space-y-3">
            <div class="flex justify-between text-xs text-[#666]">
              <span>Subtotal ({{ lines.length }} item)</span>
              <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(subtotal) }}</span>
            </div>
            <div class="flex justify-between text-xs text-[#666]">
              <span>PPN 11%</span>
              <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(taxAmount) }}</span>
            </div>
            <div class="border-t border-[#e5e5e5] pt-3 flex justify-between">
              <span class="text-sm font-bold text-[#1a1a1a]">Total</span>
              <span class="text-sm font-bold text-[#6b1525]">{{ fmtRp(total) }}</span>
            </div>

            <button @click="submit" :disabled="saving || lines.length === 0 || !form.supplier_tenant_id"
              class="w-full mt-2 py-3 bg-[#6b1525] text-white text-sm font-bold rounded-xl hover:bg-[#5a1120] disabled:opacity-40 transition-colors">
              {{ saving ? 'Menyimpan...' : 'Simpan sebagai Draft' }}
            </button>
            <NuxtLink to="/dashboard/ksm/purchase-orders"
              class="block w-full py-2.5 text-center text-sm text-[#666] hover:text-[#1a1a1a] transition-colors">
              Batal
            </NuxtLink>
          </div>
        </div>

        <div class="bg-amber-50 border border-amber-200 rounded-xl p-4 text-xs text-amber-800 space-y-1">
          <p class="font-bold">Info</p>
          <p>PO disimpan sebagai <strong>Draft</strong>. Setelah dicek, klik "Ajukan" di halaman PO untuk mengirim ke distributor.</p>
        </div>
      </div>

    </div>
  </div>
</template>
