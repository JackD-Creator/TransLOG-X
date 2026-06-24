<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Buat Purchase Order' })

const supabase = useSupabaseClient()
const router = useRouter()
const { tenantId } = useUserRole()

const saving = ref(false)
const searchQ = ref('')
const searchLoading = ref(false)
const searchResults = ref<any[]>([])
const showDropdown = ref(false)

const form = reactive({
  supplier_tenant_id: '',
  rs_name: '',          // nama RS tujuan (teks bebas untuk demo)
  rs_address: '',       // alamat RS tujuan
  payment_terms: 'net_30',
  expected_delivery: '',
  notes: '',
})

const lines = ref<{
  kfa_code: string; item_name: string; catalog_type: string
  uom: string; ordered_qty: number; unit_price: number; catalog_price: number | null
}[]>([])

// ─── Suppliers ────────────────────────────────────────────────────────────────
const suppliers = ref<{ id: string; name: string }[]>([])
async function loadSuppliers() {
  const { data } = await supabase
    .from('supplier_catalog_items')
    .select('tenant_id, metadata')
    .eq('is_available', true)
    .not('metadata->>distributor_name', 'is', null)
    .limit(500)
  const seen = new Set<string>()
  const list: { id: string; name: string }[] = []
  for (const row of (data ?? [])) {
    const meta = row.metadata as any
    if (row.tenant_id && meta?.distributor_name && !seen.has(row.tenant_id)) {
      seen.add(row.tenant_id)
      list.push({ id: row.tenant_id, name: meta.distributor_name })
    }
  }
  suppliers.value = list.sort((a, b) => a.name.localeCompare(b.name))
}

// ─── Search KFA ───────────────────────────────────────────────────────────────
let searchTimer: ReturnType<typeof setTimeout>
async function searchKFA() {
  clearTimeout(searchTimer)
  const q = searchQ.value.trim()
  if (!q || q.length < 2) { searchResults.value = []; showDropdown.value = false; return }
  searchTimer = setTimeout(async () => {
    searchLoading.value = true
    const { data: drugs } = await supabase.from('kfa_drugs')
      .select('kfa_code, name, nama_dagang, dosage_form, strength, uom, fix_price')
      .or(`name.ilike.%${q}%,nama_dagang.ilike.%${q}%,kfa_code.ilike.%${q}%`)
      .limit(12)

    let catalogPrices: Record<string, number> = {}
    if (form.supplier_tenant_id && drugs?.length) {
      const codes = drugs.map(d => d.kfa_code)
      const { data: cat } = await supabase
        .from('supplier_catalog_items')
        .select('kfa_code, sell_price')
        .eq('tenant_id', form.supplier_tenant_id)
        .in('kfa_code', codes)
      for (const c of (cat ?? [])) catalogPrices[c.kfa_code] = c.sell_price
    }

    searchResults.value = (drugs ?? []).map(d => ({
      ...d, catalog_price: catalogPrices[d.kfa_code] ?? null
    }))
    showDropdown.value = searchResults.value.length > 0
    searchLoading.value = false
  }, 300)
}

function addItem(drug: any) {
  if (lines.value.find(l => l.kfa_code === drug.kfa_code)) {
    searchQ.value = ''; showDropdown.value = false; return
  }
  lines.value.push({
    kfa_code: drug.kfa_code,
    item_name: drug.name,
    catalog_type: 'obat',
    uom: drug.dosage_form ?? drug.uom ?? 'tablet',
    ordered_qty: 10,
    unit_price: drug.catalog_price ?? drug.fix_price ?? 0,
    catalog_price: drug.catalog_price,
  })
  searchQ.value = ''; showDropdown.value = false
}

function removeItem(idx: number) { lines.value.splice(idx, 1) }

// ─── Totals ───────────────────────────────────────────────────────────────────
const subtotal = computed(() => lines.value.reduce((s, l) => s + l.ordered_qty * l.unit_price, 0))
const taxAmount = computed(() => subtotal.value * 0.11)
const total = computed(() => subtotal.value + taxAmount.value)

// ─── Save ─────────────────────────────────────────────────────────────────────
async function submit(status: 'draft' | 'submitted') {
  if (!form.supplier_tenant_id) { alert('Pilih distributor terlebih dahulu'); return }
  if (lines.value.length === 0) { alert('Tambahkan minimal 1 item'); return }
  if (status === 'submitted' && !form.rs_name) { alert('Isi RS Tujuan Pengiriman'); return }
  saving.value = true

  const poNumber = `KSM-PO-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`
  const { data: po, error } = await supabase.from('ksm_purchase_orders').insert({
    ksm_tenant_id: tenantId.value,
    supplier_tenant_id: form.supplier_tenant_id,
    po_number: poNumber,
    po_date: new Date().toISOString().slice(0, 10),
    expected_delivery: form.expected_delivery || null,
    payment_terms: form.payment_terms,
    notes: form.notes || null,
    status,
    subtotal: subtotal.value,
    tax_amount: taxAmount.value,
    total_amount: total.value,
    submitted_at: status === 'submitted' ? new Date().toISOString() : null,
    metadata: {
      rs_name: form.rs_name,
      rs_address: form.rs_address,
      supplier_name: suppliers.value.find(s => s.id === form.supplier_tenant_id)?.name,
    }
  }).select('id').single()

  if (error || !po) { alert('Gagal membuat PO: ' + error?.message); saving.value = false; return }

  await supabase.from('ksm_po_lines').insert(
    lines.value.map(l => ({
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
  )
  saving.value = false
  router.push('/dashboard/ksm/purchase-orders/' + po.id)
}

const paymentOptions = [
  { value: 'cod', label: 'COD' }, { value: 'net_7', label: 'Net 7' },
  { value: 'net_14', label: 'Net 14' }, { value: 'net_30', label: 'Net 30' },
  { value: 'net_45', label: 'Net 45' }, { value: 'net_60', label: 'Net 60' },
  { value: 'net_90', label: 'Net 90' },
]

onMounted(loadSuppliers)
</script>

<template>
  <div class="space-y-5 max-w-5xl">
    <div class="flex items-center gap-3">
      <NuxtLink to="/dashboard/ksm/purchase-orders"
        class="w-8 h-8 rounded-lg bg-[#ebebeb] flex items-center justify-center hover:bg-[#e0e0e0] transition-colors">
        <UIcon name="i-lucide-arrow-left" class="text-sm text-[#666]"/>
      </NuxtLink>
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Buat Purchase Order</h1>
        <p class="text-sm text-[#999]">Distributor akan kirim langsung ke RS — KSM sebagai penanggungjawab PO</p>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
      <div class="lg:col-span-2 space-y-4">

        <!-- Informasi PO -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-3 border-b border-[#ebebeb] bg-[#ebebeb]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Informasi PO</p>
          </div>
          <div class="p-5 space-y-4">
            <!-- Distributor -->
            <div>
              <label class="text-xs font-semibold text-[#555] mb-1.5 block">Distributor / Supplier *</label>
              <select v-model="form.supplier_tenant_id"
                class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors">
                <option value="">— Pilih Distributor —</option>
                <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
              <p v-if="suppliers.length === 0" class="text-[11px] text-amber-600 mt-1">
                Belum ada distributor dengan katalog aktif
              </p>
            </div>

            <!-- RS Tujuan -->
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs font-semibold text-[#555] mb-1.5 block">RS Tujuan Pengiriman *</label>
                <input v-model="form.rs_name" type="text" placeholder="Nama Rumah Sakit..."
                  class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors">
              </div>
              <div>
                <label class="text-xs font-semibold text-[#555] mb-1.5 block">Alamat RS</label>
                <input v-model="form.rs_address" type="text" placeholder="Kota / Kecamatan..."
                  class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors">
              </div>
            </div>

            <!-- Termin & Estimasi -->
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="text-xs font-semibold text-[#555] mb-1.5 block">Termin Pembayaran</label>
                <select v-model="form.payment_terms"
                  class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors">
                  <option v-for="opt in paymentOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
              <div>
                <label class="text-xs font-semibold text-[#555] mb-1.5 block">Estimasi Tiba di RS</label>
                <input v-model="form.expected_delivery" type="date"
                  class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors">
              </div>
            </div>

            <div>
              <label class="text-xs font-semibold text-[#555] mb-1.5 block">Catatan</label>
              <textarea v-model="form.notes" rows="2" placeholder="Instruksi pengiriman, catatan khusus..."
                class="w-full bg-white border border-[#e0e0e0] rounded-xl px-3 py-2.5 text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525] transition-colors resize-none"/>
            </div>
          </div>
        </div>

        <!-- Item Pesanan -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-3 border-b border-[#ebebeb] bg-[#ebebeb] flex items-center justify-between">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Item Pesanan</p>
            <p class="text-[11px] text-[#999]">Cari dari {{ (24353).toLocaleString('id-ID') }}+ obat KFA Kemkes</p>
          </div>
          <div class="p-5 space-y-4">
            <!-- Search -->
            <div class="relative">
              <div class="flex items-center gap-2 px-4 py-3 rounded-xl border border-[#e0e0e0] bg-white">
                <UIcon name="i-lucide-search" class="text-base text-[#999] flex-shrink-0"/>
                <input v-model="searchQ" @input="searchKFA" type="text"
                  placeholder="Ketik nama obat / nama dagang / kode KFA..."
                  class="flex-1 bg-transparent text-sm text-[#1a1a1a] outline-none placeholder:text-[#bbb]">
                <UIcon v-if="searchLoading" name="i-lucide-loader-2" class="text-sm text-[#999] animate-spin flex-shrink-0"/>
                <button v-if="searchQ" @click="searchQ=''; showDropdown=false" type="button" class="text-[#ccc] hover:text-[#999]">
                  <UIcon name="i-lucide-x" class="text-sm"/>
                </button>
              </div>

              <!-- Dropdown -->
              <div v-if="showDropdown && searchResults.length > 0"
                class="absolute top-full left-0 right-0 mt-1 bg-white border border-[#e5e5e5] rounded-xl shadow-xl z-50 max-h-72 overflow-y-auto">
                <button v-for="drug in searchResults" :key="drug.kfa_code"
                  @click="addItem(drug)" type="button"
                  class="w-full px-4 py-3 flex items-start gap-3 hover:bg-[#f5f5f5] transition-colors text-left border-b border-[#f0f0f0] last:border-0">
                  <div class="flex-1 min-w-0">
                    <p class="text-xs font-semibold text-[#1a1a1a]">{{ drug.name }}</p>
                    <p class="text-[10px] text-[#999] mt-0.5">
                      {{ drug.kfa_code }}
                      <span v-if="drug.dosage_form"> · {{ drug.dosage_form }}</span>
                      <span v-if="drug.strength"> · {{ drug.strength }}</span>
                    </p>
                  </div>
                  <div class="text-right flex-shrink-0">
                    <p v-if="drug.catalog_price" class="text-xs font-bold text-[#6b1525]">{{ fmtRp(drug.catalog_price) }}</p>
                    <p v-else class="text-xs font-semibold text-[#666]">{{ drug.fix_price ? fmtRp(drug.fix_price) : 'HAP -' }}</p>
                    <p class="text-[9px] text-[#aaa]">{{ drug.catalog_price ? 'Harga Distributor' : 'HAP KFA' }}</p>
                  </div>
                </button>
              </div>
            </div>

            <!-- Line Items -->
            <div v-if="lines.length > 0" class="border border-[#e0e0e0] rounded-xl overflow-hidden">
              <table class="w-full text-xs">
                <thead class="bg-[#ebebeb] border-b border-[#e0e0e0]">
                  <tr class="text-left">
                    <th class="px-4 py-2.5 font-semibold text-[#666]">Item / Kode KFA</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-24 text-center">Qty</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-36 text-right">Harga Satuan</th>
                    <th class="px-3 py-2.5 font-semibold text-[#666] w-36 text-right">Subtotal</th>
                    <th class="px-2 py-2.5 w-8"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-[#f0f0f0] bg-white">
                  <tr v-for="(line, i) in lines" :key="line.kfa_code">
                    <td class="px-4 py-3">
                      <p class="font-semibold text-[#1a1a1a]">{{ line.item_name }}</p>
                      <p class="text-[10px] text-[#aaa] font-mono mt-0.5">{{ line.kfa_code }} · {{ line.uom }}</p>
                    </td>
                    <td class="px-3 py-3 text-center">
                      <input v-model.number="line.ordered_qty" type="number" min="1"
                        class="w-16 text-center bg-[#f5f5f5] border border-[#e5e5e5] rounded-lg px-2 py-1.5 text-xs outline-none focus:border-[#6b1525]">
                    </td>
                    <td class="px-3 py-3">
                      <div class="relative">
                        <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-[10px] text-[#999]">Rp</span>
                        <input v-model.number="line.unit_price" type="number" min="0"
                          class="w-full text-right bg-[#f5f5f5] border border-[#e5e5e5] rounded-lg pl-7 pr-2 py-1.5 text-xs outline-none focus:border-[#6b1525]">
                      </div>
                    </td>
                    <td class="px-3 py-3 text-right font-semibold text-[#1a1a1a]">
                      {{ fmtRp(line.ordered_qty * line.unit_price) }}
                    </td>
                    <td class="px-2 py-3">
                      <button @click="removeItem(i)" type="button"
                        class="text-[#ddd] hover:text-red-400 transition-colors">
                        <UIcon name="i-lucide-trash-2" class="text-sm"/>
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div v-else class="border-2 border-dashed border-[#e0e0e0] rounded-xl p-10 text-center">
              <UIcon name="i-lucide-package-search" class="text-3xl text-[#ddd] mx-auto mb-2"/>
              <p class="text-sm text-[#bbb]">Cari dan klik item dari hasil pencarian KFA</p>
              <p class="text-xs text-[#ccc] mt-1">Contoh: ketik "paracetamol", "amoxicillin", "metformin"</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Ringkasan & Aksi -->
      <div class="space-y-4">
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden sticky top-4">
          <div class="px-5 py-3 border-b border-[#ebebeb] bg-[#ebebeb]">
            <p class="text-xs font-bold text-[#666] uppercase tracking-wide">Ringkasan PO</p>
          </div>
          <div class="p-5 space-y-3">
            <!-- RS Info -->
            <div v-if="form.rs_name" class="bg-white rounded-xl p-3 border border-[#e5e5e5]">
              <p class="text-[10px] text-[#999] uppercase mb-1">Kirim ke</p>
              <p class="text-xs font-bold text-[#1a1a1a]">{{ form.rs_name }}</p>
              <p v-if="form.rs_address" class="text-[10px] text-[#999]">{{ form.rs_address }}</p>
            </div>

            <div class="space-y-2">
              <div class="flex justify-between text-xs text-[#666]">
                <span>{{ lines.length }} item</span>
                <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(subtotal) }}</span>
              </div>
              <div class="flex justify-between text-xs text-[#666]">
                <span>PPN 11%</span>
                <span class="font-semibold text-[#1a1a1a]">{{ fmtRp(taxAmount) }}</span>
              </div>
              <div class="border-t border-[#e5e5e5] pt-2 flex justify-between">
                <span class="text-sm font-bold text-[#1a1a1a]">Total</span>
                <span class="text-base font-bold text-[#6b1525]">{{ fmtRp(total) }}</span>
              </div>
            </div>

            <!-- Aksi -->
            <div class="space-y-2 pt-1">
              <button @click="submit('submitted')"
                :disabled="saving || lines.length === 0 || !form.supplier_tenant_id || !form.rs_name"
                class="w-full py-3 bg-[#6b1525] text-white text-sm font-bold rounded-xl hover:bg-[#5a1120] disabled:opacity-40 transition-colors">
                {{ saving ? 'Menyimpan...' : '→ Ajukan PO ke Distributor' }}
              </button>
              <button @click="submit('draft')"
                :disabled="saving || lines.length === 0 || !form.supplier_tenant_id"
                class="w-full py-2.5 bg-white border border-[#e5e5e5] text-sm text-[#666] font-semibold rounded-xl hover:bg-[#f5f5f5] disabled:opacity-40 transition-colors">
                Simpan sebagai Draft
              </button>
              <NuxtLink to="/dashboard/ksm/purchase-orders"
                class="block w-full py-2 text-center text-xs text-[#aaa] hover:text-[#666] transition-colors">
                Batal
              </NuxtLink>
            </div>
          </div>
        </div>

        <!-- Info flow -->
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 space-y-2 text-xs text-blue-800">
          <p class="font-bold">Alur Pengiriman</p>
          <div class="space-y-1.5">
            <div class="flex items-start gap-2">
              <span class="w-4 h-4 rounded-full bg-blue-600 text-white text-[9px] flex items-center justify-center flex-shrink-0 mt-0.5">1</span>
              <p>KSM ajukan PO ke Distributor</p>
            </div>
            <div class="flex items-start gap-2">
              <span class="w-4 h-4 rounded-full bg-blue-400 text-white text-[9px] flex items-center justify-center flex-shrink-0 mt-0.5">2</span>
              <p>Distributor konfirmasi & packing</p>
            </div>
            <div class="flex items-start gap-2">
              <span class="w-4 h-4 rounded-full bg-blue-400 text-white text-[9px] flex items-center justify-center flex-shrink-0 mt-0.5">3</span>
              <p>Distributor kirim <strong>langsung ke RS</strong></p>
            </div>
            <div class="flex items-start gap-2">
              <span class="w-4 h-4 rounded-full bg-blue-400 text-white text-[9px] flex items-center justify-center flex-shrink-0 mt-0.5">4</span>
              <p>RS konfirmasi penerimaan</p>
            </div>
            <div class="flex items-start gap-2">
              <span class="w-4 h-4 rounded-full bg-blue-400 text-white text-[9px] flex items-center justify-center flex-shrink-0 mt-0.5">5</span>
              <p>KSM invoice RS, Bank proses SCF</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
