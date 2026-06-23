<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const router = useRouter()
const saving = ref(false)

const form = reactive({
  requestor: '',
  keperluan: '',
  tgl_butuh: '',
  prioritas: 'normal',
  catatan: '',
})

const items = ref([
  { product_name: '', qty: 1, satuan: '', est_harga: 0, catatan: '' }
])

function addItem() {
  items.value.push({ product_name: '', qty: 1, satuan: '', est_harga: 0, catatan: '' })
}

function removeItem(i: number) {
  if (items.value.length > 1) items.value.splice(i, 1)
}

const totalEstimasi = computed(() =>
  items.value.reduce((sum, i) => sum + (i.qty * i.est_harga), 0)
)

async function submit() {
  saving.value = true
  await new Promise(r => setTimeout(r, 800))
  saving.value = false
  router.push('/dashboard/procurement')
}

const requestorOptions = ['Farmasi', 'IGD', 'Poli Umum', 'Poli Spesialis', 'ICU', 'OK', 'Lab', 'Radiologi', 'Gizi', 'CSSD']
const satuanOptions    = ['Tablet', 'Kapsul', 'Botol', 'Ampul', 'Vial', 'Pcs', 'Set', 'Strip', 'Box', 'Liter']
const prioritasOptions = [
  { value: 'normal',  label: 'Normal' },
  { value: 'urgent',  label: 'Urgent' },
  { value: 'critical',label: 'Critical / Darurat' },
]
</script>

<template>
  <div class="space-y-5 max-w-4xl">

    <div class="flex items-center gap-3">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" @click="router.back()" />
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Buat Purchase Request</h1>
        <p class="text-sm text-[#999] mt-0.5">Permintaan pengadaan barang / obat / alkes</p>
      </div>
    </div>

    <form class="space-y-5" @submit.prevent="submit">

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Informasi PR</h2>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Unit / Requestor</label>
            <select v-model="form.requestor" class="inp" required>
              <option value="" disabled>Pilih unit</option>
              <option v-for="r in requestorOptions" :key="r" :value="r">{{ r }}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Tanggal Dibutuhkan</label>
            <input v-model="form.tgl_butuh" type="date" class="inp" required>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Keperluan</label>
            <input v-model="form.keperluan" type="text" placeholder="Stok rutin bulanan / kebutuhan khusus" class="inp" required>
          </div>
          <div>
            <label class="lbl">Prioritas</label>
            <select v-model="form.prioritas" class="inp">
              <option v-for="p in prioritasOptions" :key="p.value" :value="p.value">{{ p.label }}</option>
            </select>
          </div>
        </div>

        <div>
          <label class="lbl">Catatan Tambahan</label>
          <textarea v-model="form.catatan" rows="2" placeholder="Keterangan khusus jika ada..." class="inp resize-none" />
        </div>
      </div>

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5] flex items-center justify-between">
          <h2 class="text-sm font-semibold text-[#666]">Daftar Item</h2>
          <button type="button" class="text-xs text-[#6b1525] hover:text-[#9a3040] font-medium flex items-center gap-1" @click="addItem">
            <UIcon name="i-lucide-plus" class="text-sm" /> Tambah Item
          </button>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
                <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide w-8">#</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nama Item / Obat</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide w-24">Qty</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide w-32">Satuan</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide w-36">Est. Harga/unit</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide w-36">Subtotal</th>
                <th class="w-10 px-2" />
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="(item, idx) in items" :key="idx">
                <td class="px-4 py-2 text-xs text-[#999]">{{ idx + 1 }}</td>
                <td class="px-4 py-2">
                  <input v-model="item.product_name" type="text" placeholder="Nama obat / alkes" class="inp-sm" required>
                </td>
                <td class="px-4 py-2">
                  <input v-model.number="item.qty" type="number" min="1" class="inp-sm text-right" required>
                </td>
                <td class="px-4 py-2">
                  <select v-model="item.satuan" class="inp-sm">
                    <option value="" disabled>Satuan</option>
                    <option v-for="s in satuanOptions" :key="s" :value="s">{{ s }}</option>
                  </select>
                </td>
                <td class="px-4 py-2">
                  <input v-model.number="item.est_harga" type="number" min="0" placeholder="0" class="inp-sm text-right">
                </td>
                <td class="px-4 py-2 text-right text-xs font-medium text-[#1a1a1a]">
                  Rp {{ (item.qty * item.est_harga).toLocaleString('id-ID') }}
                </td>
                <td class="px-2 py-2 text-center">
                  <button type="button" class="text-[#999] hover:text-red-500 transition-colors" @click="removeItem(idx)">
                    <UIcon name="i-lucide-trash-2" class="text-sm" />
                  </button>
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-[#e5e5e5] bg-[#f0f0f0]">
                <td colspan="5" class="px-4 py-3 text-sm font-semibold text-[#666] text-right">Total Estimasi</td>
                <td class="px-4 py-3 text-right font-bold text-[#1a1a1a]">
                  Rp {{ totalEstimasi.toLocaleString('id-ID') }}
                </td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div class="flex gap-3 justify-end">
        <UButton type="button" color="neutral" variant="outline" @click="router.back()">Batal</UButton>
        <UButton type="submit" color="neutral" variant="soft" icon="i-lucide-save" :loading="saving">
          Simpan Draft
        </UButton>
        <UButton type="submit" color="primary" icon="i-lucide-send" :loading="saving">
          Kirim untuk Approval
        </UButton>
      </div>

    </form>
  </div>
</template>

<style scoped>
.lbl {
  display: block; font-size: 0.72rem; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.06em;
  color: #666; margin-bottom: 6px;
}

.inp {
  width: 100%; padding: 9px 12px;
  border: 1.5px solid #e5e5e5; border-radius: 8px;
  background: #f0f0f0; color: #1a1a1a;
  font-size: 0.875rem; outline: none;
  transition: border-color 0.15s; font-family: inherit;
}
.inp:focus { border-color: #6b1525; box-shadow: 0 0 0 3px rgba(107,21,37,0.1); }

.inp-sm {
  width: 100%; padding: 6px 10px;
  border: 1.5px solid #e5e5e5; border-radius: 6px;
  background: #f0f0f0; color: #1a1a1a;
  font-size: 0.8rem; outline: none;
  transition: border-color 0.15s; font-family: inherit;
}
.inp-sm:focus { border-color: #6b1525; box-shadow: 0 0 0 2px rgba(107,21,37,0.1); }
</style>
