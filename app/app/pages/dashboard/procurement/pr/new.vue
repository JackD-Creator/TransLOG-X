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
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Buat Purchase Request</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Permintaan pengadaan barang / obat / alkes</p>
      </div>
    </div>

    <form class="space-y-5" @submit.prevent="submit">

      <!-- Info PR -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Informasi PR</h2>

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

      <!-- Item List -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Daftar Item</h2>
          <button type="button" class="text-xs text-red-600 hover:text-red-500 font-medium flex items-center gap-1" @click="addItem">
            <UIcon name="i-lucide-plus" class="text-sm" /> Tambah Item
          </button>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-8">#</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nama Item / Obat</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-24">Qty</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-32">Satuan</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-36">Est. Harga/unit</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-36">Subtotal</th>
                <th class="w-10 px-2" />
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <tr v-for="(item, idx) in items" :key="idx">
                <td class="px-4 py-2 text-xs text-gray-400">{{ idx + 1 }}</td>
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
                <td class="px-4 py-2 text-right text-xs font-medium text-gray-700 dark:text-gray-300">
                  Rp {{ (item.qty * item.est_harga).toLocaleString('id-ID') }}
                </td>
                <td class="px-2 py-2 text-center">
                  <button type="button" class="text-gray-300 hover:text-red-500 transition-colors" @click="removeItem(idx)">
                    <UIcon name="i-lucide-trash-2" class="text-sm" />
                  </button>
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t-2 border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
                <td colspan="5" class="px-4 py-3 text-sm font-semibold text-gray-700 dark:text-gray-300 text-right">Total Estimasi</td>
                <td class="px-4 py-3 text-right font-bold text-gray-900 dark:text-white">
                  Rp {{ totalEstimasi.toLocaleString('id-ID') }}
                </td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <!-- Actions -->
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
  color: #6b7280; margin-bottom: 6px;
}
.dark .lbl { color: #9ca3af; }

.inp {
  width: 100%; padding: 9px 12px;
  border: 1.5px solid #e5e7eb; border-radius: 8px;
  background: #f9fafb; color: #111827;
  font-size: 0.875rem; outline: none;
  transition: border-color 0.15s; font-family: inherit;
}
.dark .inp { border-color: #374151; background: #111827; color: #f9fafb; }
.inp:focus { border-color: #dc2626; box-shadow: 0 0 0 3px rgba(220,38,38,0.1); }

.inp-sm {
  width: 100%; padding: 6px 10px;
  border: 1.5px solid #e5e7eb; border-radius: 6px;
  background: #f9fafb; color: #111827;
  font-size: 0.8rem; outline: none;
  transition: border-color 0.15s; font-family: inherit;
}
.dark .inp-sm { border-color: #374151; background: #111827; color: #f9fafb; }
.inp-sm:focus { border-color: #dc2626; box-shadow: 0 0 0 2px rgba(220,38,38,0.1); }
</style>
