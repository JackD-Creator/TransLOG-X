<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const activeTab = ref('overview')

const tabs = [
  { key: 'overview', label: 'Overview',      icon: 'i-lucide-layout-dashboard' },
  { key: 'bins',     label: 'Lokasi & Bin',  icon: 'i-lucide-map-pin' },
  { key: 'opname',   label: 'Stok Opname',   icon: 'i-lucide-clipboard-check' },
]

const warehouses = ref([
  { id: 1, kode: 'GD-A', nama: 'Gudang Utama Farmasi', lokasi: 'Lt. 1 Gedung C', kapasitas: 80, rak: 12, bin: 144, petugas: 'Apt. Sari D.' },
  { id: 2, kode: 'GD-B', nama: 'Gudang Alkes & BMHP',  lokasi: 'Lt. 1 Gedung D', kapasitas: 65, rak: 8,  bin: 96,  petugas: 'Budi S.' },
  { id: 3, kode: 'GD-C', nama: 'Gudang Reagensia',     lokasi: 'Lt. 2 Lab',      kapasitas: 45, rak: 6,  bin: 48,  petugas: 'Rini A.' },
])

const bins = ref([
  { kode: 'GD-A/R01/B01', gudang: 'GD-A', rak: 'R01', bin: 'B01', tipe: 'Ambient', item: 'Paracetamol 500mg', stok: 1250, kapasitas: 2000 },
  { kode: 'GD-A/R01/B02', gudang: 'GD-A', rak: 'R01', bin: 'B02', tipe: 'Ambient', item: 'Amoxicillin 500mg', stok: 80,   kapasitas: 1000 },
  { kode: 'GD-A/R02/B01', gudang: 'GD-A', rak: 'R02', bin: 'B01', tipe: 'Cold',    item: 'Insulin Novomix',   stok: 24,   kapasitas: 100  },
  { kode: 'GD-B/R01/B01', gudang: 'GD-B', rak: 'R01', bin: 'B01', tipe: 'Ambient', item: 'Spuit 3cc',         stok: 4500, kapasitas: 5000 },
  { kode: 'GD-B/R01/B02', gudang: 'GD-B', rak: 'R01', bin: 'B02', tipe: 'Ambient', item: 'Infus Set Dewasa',  stok: 320,  kapasitas: 1000 },
  { kode: 'GD-B/R02/B01', gudang: 'GD-B', rak: 'R02', bin: 'B01', tipe: 'Ambient', item: 'Handscoon M',       stok: 60,   kapasitas: 2000 },
])

const opnames = ref([
  { id: 'OPN-2026-003', tanggal: '2026-06-01', gudang: 'GD-A', item_total: 145, item_selesai: 145, selisih: -3, status: 'completed' },
  { id: 'OPN-2026-002', tanggal: '2026-05-01', gudang: 'GD-B', item_total: 98,  item_selesai: 98,  selisih: 0,  status: 'completed' },
  { id: 'OPN-2026-001', tanggal: '2026-04-01', gudang: 'GD-A', item_total: 145, item_selesai: 145, selisih: 2,  status: 'completed' },
])

function fillPct(stok: number, kap: number) {
  return Math.min(100, Math.round((stok / kap) * 100))
}
function fillColor(pct: number) {
  if (pct <= 20) return 'bg-red-500'
  if (pct <= 40) return 'bg-amber-500'
  return 'bg-emerald-500'
}
</script>

<template>
  <div class="space-y-5">

    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Manajemen Gudang</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Lokasi penyimpanan, bin, & stok opname</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Gudang</UButton>
    </div>

    <!-- Tabs -->
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

      <!-- Overview -->
      <div v-if="activeTab === 'overview'" class="p-5">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div
            v-for="wh in warehouses" :key="wh.id"
            class="border border-gray-200 dark:border-gray-700 rounded-xl p-5 hover:border-red-300 dark:hover:border-red-800 transition-colors cursor-pointer"
          >
            <div class="flex items-start justify-between mb-4">
              <div>
                <p class="font-bold text-gray-900 dark:text-white">{{ wh.nama }}</p>
                <p class="text-xs text-gray-400 mt-0.5">{{ wh.kode }} · {{ wh.lokasi }}</p>
              </div>
              <span class="px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400">
                Aktif
              </span>
            </div>

            <!-- Kapasitas bar -->
            <div class="mb-4">
              <div class="flex justify-between text-xs text-gray-400 mb-1">
                <span>Kapasitas terpakai</span>
                <span>{{ wh.kapasitas }}%</span>
              </div>
              <div class="w-full h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                <div
                  :class="['h-full rounded-full', fillColor(wh.kapasitas)]"
                  :style="`width:${wh.kapasitas}%`"
                />
              </div>
            </div>

            <div class="grid grid-cols-3 gap-2 text-center">
              <div class="bg-gray-50 dark:bg-gray-800 rounded-lg py-2">
                <p class="text-lg font-bold text-gray-900 dark:text-white">{{ wh.rak }}</p>
                <p class="text-[10px] text-gray-400">Rak</p>
              </div>
              <div class="bg-gray-50 dark:bg-gray-800 rounded-lg py-2">
                <p class="text-lg font-bold text-gray-900 dark:text-white">{{ wh.bin }}</p>
                <p class="text-[10px] text-gray-400">Bin</p>
              </div>
              <div class="bg-gray-50 dark:bg-gray-800 rounded-lg py-2">
                <p class="text-xs font-medium text-gray-700 dark:text-gray-300 truncate px-1">{{ wh.petugas.split(' ')[0] }}</p>
                <p class="text-[10px] text-gray-400">Petugas</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bins -->
      <div v-if="activeTab === 'bins'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Kode Bin</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Gudang</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tipe</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Item Saat Ini</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Stok</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide w-40">Kapasitas</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="b in bins" :key="b.kode" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
              <td class="px-4 py-3 font-mono text-xs text-gray-700 dark:text-gray-300 font-semibold">{{ b.kode }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ b.gudang }}</td>
              <td class="px-4 py-3">
                <span :class="[
                  'px-2 py-0.5 rounded text-xs font-medium',
                  b.tipe === 'Cold' ? 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400' : 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400'
                ]">{{ b.tipe }}</span>
              </td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ b.item }}</td>
              <td class="px-4 py-3 text-right font-semibold text-gray-900 dark:text-white">{{ b.stok.toLocaleString('id-ID') }}</td>
              <td class="px-4 py-3">
                <div class="flex items-center gap-2">
                  <div class="flex-1 h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                    <div
                      :class="['h-full rounded-full', fillColor(fillPct(b.stok, b.kapasitas))]"
                      :style="`width:${fillPct(b.stok, b.kapasitas)}%`"
                    />
                  </div>
                  <span class="text-xs text-gray-400 w-8">{{ fillPct(b.stok, b.kapasitas) }}%</span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Stok Opname -->
      <div v-if="activeTab === 'opname'" class="overflow-x-auto">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800 flex justify-between items-center">
          <p class="text-sm text-gray-600 dark:text-gray-400">Riwayat & jadwal stok opname</p>
          <UButton icon="i-lucide-plus" size="xs" color="primary">Buat Opname</UButton>
        </div>
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">No. Opname</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Tanggal</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Gudang</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Item</th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Selisih</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="op in opnames" :key="op.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3 font-mono text-xs text-red-600 dark:text-red-400 font-semibold">{{ op.id }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ op.tanggal }}</td>
              <td class="px-4 py-3 text-sm text-gray-900 dark:text-white">{{ op.gudang }}</td>
              <td class="px-4 py-3 text-right text-sm text-gray-700 dark:text-gray-300">{{ op.item_total }}</td>
              <td class="px-4 py-3 text-right font-semibold" :class="op.selisih < 0 ? 'text-red-600 dark:text-red-400' : op.selisih > 0 ? 'text-amber-600 dark:text-amber-400' : 'text-emerald-600 dark:text-emerald-400'">
                {{ op.selisih > 0 ? '+' : '' }}{{ op.selisih }}
              </td>
              <td class="px-4 py-3">
                <span class="px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400">
                  Selesai
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

    </div>
  </div>
</template>
