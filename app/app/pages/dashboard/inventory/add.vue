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
        <h1 class="text-xl font-bold text-[#1a1a1a]">Tambah SKU Baru</h1>
        <p class="text-sm text-[#999] mt-0.5">Isi detail item untuk ditambahkan ke inventory</p>
      </div>
    </div>

    <form class="space-y-5" @submit.prevent="save">

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Identitas Item</h2>

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

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Batas Stok</h2>
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

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Harga</h2>
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

      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-4">
        <h2 class="text-sm font-semibold text-[#666]">Keterangan</h2>
        <textarea
          v-model="form.keterangan"
          rows="3"
          placeholder="Catatan penyimpanan, indikasi, dll..."
          class="inp resize-none"
        />
      </div>

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
  display: block; font-size: 0.72rem; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.06em;
  color: #666; margin-bottom: 6px;
}

.inp {
  width: 100%; padding: 9px 12px;
  border: 1.5px solid #e5e5e5; border-radius: 8px;
  background: #f0f0f0; color: #1a1a1a;
  font-size: 0.875rem; outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  font-family: inherit;
}
.inp:focus { border-color: #6b1525; box-shadow: 0 0 0 3px rgba(107,21,37,0.1); }
</style>
