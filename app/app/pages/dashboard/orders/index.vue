<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const activeTab = ref('internal')

const tabs = [
  { key: 'internal', label: 'Distribusi Internal', icon: 'i-lucide-arrow-right-left' },
  { key: 'external', label: 'Distribusi Eksternal', icon: 'i-lucide-truck' },
  { key: 'retur',    label: 'Retur',                icon: 'i-lucide-undo-2' },
]

const stats = [
  { label: 'Order Hari Ini',    value: 8,  icon: 'i-lucide-clipboard-list',  color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Pending Pick',      value: 3,  icon: 'i-lucide-package',          color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Dalam Pengiriman',  value: 2,  icon: 'i-lucide-truck',            color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' },
  { label: 'Selesai Bulan Ini', value: 47, icon: 'i-lucide-check-circle',     color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
]

const internalOrders = ref([
  { id: 'DO-INT-0089', tanggal: '2026-06-22', dari: 'Gudang Utama', ke: 'Farmasi Rawat Inap', item_count: 12, status: 'delivered',  picker: 'Budi S.' },
  { id: 'DO-INT-0088', tanggal: '2026-06-22', dari: 'Gudang Utama', ke: 'IGD',                item_count: 5,  status: 'picking',    picker: 'Rini A.' },
  { id: 'DO-INT-0087', tanggal: '2026-06-21', dari: 'Gudang Utama', ke: 'Poli Umum',          item_count: 8,  status: 'pending',    picker: '-' },
  { id: 'DO-INT-0086', tanggal: '2026-06-21', dari: 'Gudang Utama', ke: 'ICU',                item_count: 6,  status: 'delivered',  picker: 'Budi S.' },
  { id: 'DO-INT-0085', tanggal: '2026-06-20', dari: 'Gudang B',     ke: 'OK / Bedah',         item_count: 20, status: 'delivered',  picker: 'Sari D.' },
])

const externalOrders = ref([
  { id: 'DO-EXT-0021', tanggal: '2026-06-22', tujuan: 'RS Mitra Sehat', alamat: 'Jl. Gatot Subroto No. 12', item_count: 30, status: 'in_transit', epod: false },
  { id: 'DO-EXT-0020', tanggal: '2026-06-20', tujuan: 'Klinik Pratama', alamat: 'Jl. Sudirman No. 5',      item_count: 10, status: 'delivered',  epod: true },
])

const returList = ref([
  { id: 'RTR-0015', tanggal: '2026-06-21', dari: 'Farmasi Rawat Inap', alasan: 'Mendekati expired', item_count: 3, status: 'processed' },
  { id: 'RTR-0014', tanggal: '2026-06-18', dari: 'IGD',                alasan: 'Barang rusak',      item_count: 1, status: 'pending' },
])

function badge(status: string) {
  const map: Record<string, string> = {
    pending:    'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
    picking:    'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400',
    packed:     'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400',
    in_transit: 'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-400',
    delivered:  'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
    processed:  'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400',
  }
  return map[status] ?? 'bg-gray-100 text-gray-600'
}

function badgeLabel(status: string) {
  const map: Record<string, string> = {
    pending: 'Pending', picking: 'Picking', packed: 'Packed',
    in_transit: 'Dalam Perjalanan', delivered: 'Terkirim', processed: 'Diproses',
  }
  return map[status] ?? status
}
</script>

<template>
  <div class="space-y-5">

    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Order & Distribusi</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Distribusi internal, eksternal & retur barang</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Buat Order</UButton>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div
        v-for="s in stats" :key="s.label"
        class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3"
      >
        <div :class="[s.bg, 'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="s.icon" :class="[s.color, 'text-lg']" />
        </div>
        <div>
          <p class="text-xl font-bold text-gray-900 dark:text-white">{{ s.value }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p>
        </div>
      </div>
    </div>

    <!-- Tabs + Table -->
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="flex border-b border-gray-200 dark:border-gray-800">
        <button
          v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab === tab.key
            ? 'border-red-600 text-red-600 dark:text-red-400'
            : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'"
          @click="activeTab = tab.key"
        >
          <UIcon :name="tab.icon" class="text-base" />{{ tab.label }}
        </button>
      </div>

      <!-- Internal -->
      <div v-if="activeTab === 'internal'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. DO</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Dari</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Ke</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Picker</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="o in internalOrders" :key="o.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ o.id }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ o.tanggal }}</td>
              <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-400">{{ o.dari }}</td>
              <td class="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">{{ o.ke }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ o.item_count }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ o.picker }}</td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(o.status)]">{{ badgeLabel(o.status) }}</span>
              </td>
              <td class="px-4 py-3 text-right">
                <UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- External -->
      <div v-if="activeTab === 'external'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. DO</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tujuan</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Alamat</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">ePOD</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="o in externalOrders" :key="o.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ o.id }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ o.tanggal }}</td>
              <td class="px-4 py-3 text-sm font-medium text-gray-900 dark:text-white">{{ o.tujuan }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ o.alamat }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ o.item_count }}</td>
              <td class="px-4 py-3">
                <span :class="o.epod ? 'text-emerald-600 dark:text-emerald-400' : 'text-gray-400'" class="text-xs font-medium">
                  {{ o.epod ? '✓ Confirmed' : 'Belum' }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(o.status)]">{{ badgeLabel(o.status) }}</span>
              </td>
              <td class="px-4 py-3 text-right">
                <UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Retur -->
      <div v-if="activeTab === 'retur'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. Retur</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Dari Unit</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Alasan</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Item</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
              <th class="px-4 py-3" />
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="r in returList" :key="r.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ r.id }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ r.tanggal }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ r.dari }}</td>
              <td class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">{{ r.alasan }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ r.item_count }}</td>
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', badge(r.status)]">{{ badgeLabel(r.status) }}</span>
              </td>
              <td class="px-4 py-3 text-right">
                <UButton icon="i-lucide-chevron-right" color="neutral" variant="ghost" size="xs" />
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="px-4 py-3 border-t border-gray-100 dark:border-gray-800">
        <p class="text-xs text-gray-400">
          {{ activeTab === 'internal' ? internalOrders.length : activeTab === 'external' ? externalOrders.length : returList.length }} dokumen
        </p>
      </div>
    </div>

  </div>
</template>
