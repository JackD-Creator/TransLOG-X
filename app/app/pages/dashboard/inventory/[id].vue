<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const route  = useRouter()
const params = useRoute().params

const item = ref({
  id: 1, kode: 'OBT-001', nama: 'Paracetamol 500mg', kategori: 'Obat',
  satuan: 'Tablet', stok: 1250, min_stok: 200, max_stok: 2000,
  harga_beli: 750, harga_jual: 850, lokasi: 'GD-A/R01',
  expired: '2027-06-01', batch: 'BTH-20250601', supplier: 'PT. Kimia Farma',
  keterangan: 'Analgetik & antipiretik. Simpan di suhu ruang < 30°C.',
})

const mutasi = ref([
  { tanggal: '2026-06-20', jenis: 'Masuk',  jumlah: 500,  saldo: 1250, ref: 'PO-2026-0045', keterangan: 'Pembelian rutin' },
  { tanggal: '2026-06-18', jenis: 'Keluar', jumlah: 120,  saldo: 750,  ref: 'DIST-0312',    keterangan: 'Distribusi ke Poli Umum' },
  { tanggal: '2026-06-15', jenis: 'Keluar', jumlah: 200,  saldo: 870,  ref: 'DIST-0298',    keterangan: 'Distribusi ke IGD' },
  { tanggal: '2026-06-10', jenis: 'Masuk',  jumlah: 1000, saldo: 1070, ref: 'PO-2026-0039', keterangan: 'Pembelian rutin' },
  { tanggal: '2026-06-05', jenis: 'Keluar', jumlah: 50,   saldo: 70,   ref: 'ADJ-0021',     keterangan: 'Penyesuaian stok opname' },
])

const stockPct = computed(() => Math.min(100, Math.round((item.value.stok / item.value.max_stok) * 100)))
const stockColor = computed(() => {
  if (item.value.stok === 0)                          return 'bg-red-500'
  if (item.value.stok <= item.value.min_stok)         return 'bg-amber-500'
  return 'bg-emerald-500'
})
</script>

<template>
  <div class="space-y-5">

    <div class="flex items-center gap-3">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" @click="route.back()" />
      <div class="flex-1">
        <h1 class="text-xl font-bold text-[#1a1a1a]">{{ item.nama }}</h1>
        <p class="text-sm text-[#999] mt-0.5">{{ item.kode }} · {{ item.kategori }}</p>
      </div>
      <NuxtLink :to="`/dashboard/inventory/edit/${item.id}`">
        <UButton icon="i-lucide-pencil" color="neutral" variant="outline" size="sm">Edit</UButton>
      </NuxtLink>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">

      <div class="lg:col-span-1 space-y-4">

        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">
          <p class="text-xs font-semibold text-[#999] uppercase tracking-wide mb-3">Stok Saat Ini</p>
          <div class="flex items-end gap-2 mb-3">
            <span class="text-4xl font-extrabold text-[#1a1a1a]">{{ item.stok.toLocaleString('id-ID') }}</span>
            <span class="text-[#999] mb-1">{{ item.satuan }}</span>
          </div>
          <div class="w-full h-2 bg-[#e5e5e5] rounded-full overflow-hidden mb-2">
            <div :class="['h-full rounded-full transition-all', stockColor]" :style="`width:${stockPct}%`" />
          </div>
          <div class="flex justify-between text-xs text-[#999]">
            <span>Min: {{ item.min_stok.toLocaleString('id-ID') }}</span>
            <span>Max: {{ item.max_stok.toLocaleString('id-ID') }}</span>
          </div>
        </div>

        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 space-y-3">
          <p class="text-xs font-semibold text-[#999] uppercase tracking-wide">Informasi Item</p>
          <div v-for="row in [
            { label: 'Satuan',     value: item.satuan },
            { label: 'Lokasi',     value: item.lokasi },
            { label: 'Batch',      value: item.batch },
            { label: 'Expired',    value: item.expired },
            { label: 'Supplier',   value: item.supplier },
            { label: 'Harga Beli', value: `Rp ${item.harga_beli.toLocaleString('id-ID')}` },
            { label: 'Harga Jual', value: `Rp ${item.harga_jual.toLocaleString('id-ID')}` },
          ]" :key="row.label" class="flex justify-between items-start gap-2">
            <span class="text-xs text-[#999] flex-shrink-0">{{ row.label }}</span>
            <span class="text-xs font-medium text-[#1a1a1a] text-right">{{ row.value }}</span>
          </div>
          <div class="pt-2 border-t border-[#e5e5e5]">
            <p class="text-xs text-[#999]">{{ item.keterangan }}</p>
          </div>
        </div>
      </div>

      <div class="lg:col-span-2">
        <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] flex items-center justify-between">
            <h2 class="text-sm font-semibold text-[#1a1a1a]">Riwayat Mutasi</h2>
            <UButton icon="i-lucide-plus" size="xs" color="primary" variant="soft">Mutasi Manual</UButton>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
                  <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Tanggal</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Jenis</th>
                  <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Jumlah</th>
                  <th class="text-right px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Saldo</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Referensi</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Keterangan</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-[#e5e5e5]">
                <tr v-for="m in mutasi" :key="m.ref" class="hover:bg-[#eee] transition-colors">
                  <td class="px-4 py-3 text-xs text-[#999]">{{ m.tanggal }}</td>
                  <td class="px-4 py-3">
                    <span :class="[
                      'px-2 py-0.5 rounded-full text-xs font-medium',
                      m.jenis === 'Masuk'
                        ? 'bg-emerald-100 text-emerald-700'
                        : 'bg-red-100 text-red-700'
                    ]">
                      {{ m.jenis === 'Masuk' ? '▲' : '▼' }} {{ m.jenis }}
                    </span>
                  </td>
                  <td class="px-4 py-3 text-right font-semibold" :class="m.jenis === 'Masuk' ? 'text-emerald-600' : 'text-red-600'">
                    {{ m.jenis === 'Masuk' ? '+' : '-' }}{{ m.jumlah.toLocaleString('id-ID') }}
                  </td>
                  <td class="px-4 py-3 text-right text-[#1a1a1a] font-medium">{{ m.saldo.toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-3 text-xs font-mono text-[#999]">{{ m.ref }}</td>
                  <td class="px-4 py-3 text-xs text-[#999]">{{ m.keterangan }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
