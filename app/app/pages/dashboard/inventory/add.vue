<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const router = useRouter()

const form = reactive({
  kode: '', nama: '', kategori: '', satuan: '',
  min_stok: 0, max_stok: 0,
  harga_beli: 0, harga_jual: 0,
  lokasi: '', keterangan: '',
})

const saving = ref(false)

async function save() {
  saving.value = true
  await new Promise(r => setTimeout(r, 800))
  saving.value = false
  router.push('/dashboard/inventory')
}

const kategoriOptions = ['Obat', 'Alkes', 'BMHP', 'Reagensia', 'Lainnya']
const satuanOptions   = ['Tablet', 'Kapsul', 'Botol', 'Ampul', 'Vial', 'Pcs', 'Set', 'Strip', 'Pasang', 'Box', 'Liter']
</script>

<template>
  <div class="space-y-5 max-w-2xl">

    <div class="flex items-center gap-3">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" @click="router.back()" />
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Tambah SKU Baru</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Isi detail item untuk ditambahkan ke inventory</p>
      </div>
    </div>

    <form class="space-y-5" @submit.prevent="save">

      <!-- Identitas -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Identitas Item</h2>

        <div class="grid grid-cols-2 gap-4">
          <div class="col-span-1">
            <label class="lbl">Kode SKU</label>
            <input v-model="form.kode" type="text" placeholder="OBT-001" class="inp" required>
          </div>
          <div class="col-span-1">
            <label class="lbl">Kategori</label>
            <select v-model="form.kategori" class="inp" required>
              <option value="" disabled>Pilih kategori</option>
              <option v-for="k in kategoriOptions" :key="k" :value="k">{{ k }}</option>
            </select>
          </div>
        </div>

        <div>
          <label class="lbl">Nama Item</label>
          <input v-model="form.nama" type="text" placeholder="Paracetamol 500mg" class="inp" required>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Satuan</label>
            <select v-model="form.satuan" class="inp" required>
              <option value="" disabled>Pilih satuan</option>
              <option v-for="s in satuanOptions" :key="s" :value="s">{{ s }}</option>
            </select>
          </div>
          <div>
            <label class="lbl">Lokasi Simpan</label>
            <input v-model="form.lokasi" type="text" placeholder="GD-A/R01" class="inp">
          </div>
        </div>
      </div>

      <!-- Stok -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Batas Stok</h2>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Stok Minimum</label>
            <input v-model.number="form.min_stok" type="number" min="0" placeholder="100" class="inp">
          </div>
          <div>
            <label class="lbl">Stok Maksimum</label>
            <input v-model.number="form.max_stok" type="number" min="0" placeholder="1000" class="inp">
          </div>
        </div>
      </div>

      <!-- Harga -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Harga</h2>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="lbl">Harga Beli (Rp)</label>
            <input v-model.number="form.harga_beli" type="number" min="0" placeholder="750" class="inp">
          </div>
          <div>
            <label class="lbl">Harga Jual (Rp)</label>
            <input v-model.number="form.harga_jual" type="number" min="0" placeholder="850" class="inp">
          </div>
        </div>
      </div>

      <!-- Keterangan -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-4">
        <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Keterangan</h2>
        <textarea
          v-model="form.keterangan"
          rows="3"
          placeholder="Catatan penyimpanan, indikasi, dll..."
          class="inp resize-none"
        />
      </div>

      <!-- Actions -->
      <div class="flex gap-3 justify-end">
        <UButton type="button" color="neutral" variant="outline" @click="router.back()">Batal</UButton>
        <UButton type="submit" color="primary" :loading="saving" icon="i-lucide-save">
          Simpan SKU
        </UButton>
      </div>

    </form>
  </div>
</template>

<style scoped>
.lbl {
  display: block;
  font-size: 0.72rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #6b7280;
  margin-bottom: 6px;
}
.dark .lbl { color: #9ca3af; }

.inp {
  width: 100%;
  padding: 9px 12px;
  border: 1.5px solid #e5e7eb;
  border-radius: 8px;
  background: #f9fafb;
  color: #111827;
  font-size: 0.875rem;
  outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  font-family: inherit;
}
.dark .inp {
  border-color: #374151;
  background: #111827;
  color: #f9fafb;
}
.inp:focus {
  border-color: #dc2626;
  box-shadow: 0 0 0 3px rgba(220,38,38,0.1);
}
</style>
