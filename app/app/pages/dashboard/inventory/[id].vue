<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const route  = useRouter()
const params = useRoute().params

// Mock — akan diganti query Supabase by ID
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

    <!-- Back + header -->
    <div class="flex items-center gap-3">
      <UButton icon="i-lucide-arrow-left" color="neutral" variant="ghost" size="sm" @click="route.back()" />
      <div class="flex-1">
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">{{ item.nama }}</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">{{ item.kode }} · {{ item.kategori }}</p>
      </div>
      <NuxtLink :to="`/dashboard/inventory/edit/${item.id}`">
        <UButton icon="i-lucide-pencil" color="neutral" variant="outline" size="sm">Edit</UButton>
      </NuxtLink>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">

      <!-- Left: info -->
      <div class="lg:col-span-1 space-y-4">

        <!-- Stok card -->
        <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5">
          <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-3">Stok Saat Ini</p>
          <div class="flex items-end gap-2 mb-3">
            <span class="text-4xl font-extrabold text-gray-900 dark:text-white">{{ item.stok.toLocaleString('id-ID') }}</span>
            <span class="text-gray-400 mb-1">{{ item.satuan }}</span>
          </div>
          <!-- Progress bar -->
          <div class="w-full h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden mb-2">
            <div :class="['h-full rounded-full transition-all', stockColor]" :style="`width:${stockPct}%`" />
          </div>
          <div class="flex justify-between text-xs text-gray-400">
            <span>Min: {{ item.min_stok.toLocaleString('id-ID') }}</span>
            <span>Max: {{ item.max_stok.toLocaleString('id-ID') }}</span>
          </div>
        </div>

        <!-- Info detail -->
        <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 space-y-3">
          <p class="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide">Informasi Item</p>
          <div v-for="row in [
            { label: 'Satuan',     value: item.satuan },
            { label: 'Lokasi',     value: item.lokasi },
            { label: 'Batch',      value: item.batch },
            { label: 'Expired',    value: item.expired },
            { label: 'Supplier',   value: item.supplier },
            { label: 'Harga Beli', value: `Rp ${item.harga_beli.toLocaleString('id-ID')}` },
            { label: 'Harga Jual', value: `Rp ${item.harga_jual.toLocaleString('id-ID')}` },
          ]" :key="row.label" class="flex justify-between items-start gap-2">
            <span class="text-xs text-gray-500 dark:text-gray-400 flex-shrink-0">{{ row.label }}</span>
            <span class="text-xs font-medium text-gray-900 dark:text-white text-right">{{ row.value }}</span>
          </div>
          <div class="pt-2 border-t border-gray-100 dark:border-gray-800">
            <p class="text-xs text-gray-400">{{ item.keterangan }}</p>
          </div>
        </div>
      </div>

      <!-- Right: mutasi -->
      <div class="lg:col-span-2">
        <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
          <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
            <h2 class="text-sm font-semibold text-gray-900 dark:text-white">Riwayat Mutasi</h2>
            <UButton icon="i-lucide-plus" size="xs" color="primary" variant="soft">Mutasi Manual</UButton>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
                  <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Jenis</th>
                  <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Jumlah</th>
                  <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Saldo</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Referensi</th>
                  <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Keterangan</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
                <tr v-for="m in mutasi" :key="m.ref" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                  <td class="px-4 py-3 text-xs text-gray-500 dark:text-gray-400">{{ m.tanggal }}</td>
                  <td class="px-4 py-3">
                    <span :class="[
                      'px-2 py-0.5 rounded-full text-xs font-medium',
                      m.jenis === 'Masuk'
                        ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400'
                        : 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400'
                    ]">
                      {{ m.jenis === 'Masuk' ? '▲' : '▼' }} {{ m.jenis }}
                    </span>
                  </td>
                  <td class="px-4 py-3 text-right font-semibold" :class="m.jenis === 'Masuk' ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'">
                    {{ m.jenis === 'Masuk' ? '+' : '-' }}{{ m.jumlah.toLocaleString('id-ID') }}
                  </td>
                  <td class="px-4 py-3 text-right text-gray-900 dark:text-white font-medium">{{ m.saldo.toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-3 text-xs font-mono text-gray-500 dark:text-gray-400">{{ m.ref }}</td>
                  <td class="px-4 py-3 text-xs text-gray-500 dark:text-gray-400">{{ m.keterangan }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
