<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const user = useSupabaseUser()

const stats = [
  { label: 'Total SKU Aktif',     value: '0',    icon: 'i-lucide-package',        color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'PO Bulan Ini',        value: '0',    icon: 'i-lucide-shopping-cart',  color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Klaim BPJS Pending',  value: '0',    icon: 'i-lucide-stethoscope',    color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
  { label: 'Outstanding AR',      value: 'Rp 0', icon: 'i-lucide-banknote',       color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' }
]

const modules = [
  { label: 'Inventory',     icon: 'i-lucide-package',       to: '/dashboard/inventory',   desc: 'Kelola stok & lot' },
  { label: 'Pengadaan',     icon: 'i-lucide-shopping-cart', to: '/dashboard/procurement', desc: 'PR, RFQ, PO, kontrak' },
  { label: 'BPJS & RCM',   icon: 'i-lucide-stethoscope',   to: '/dashboard/bpjs',        desc: 'Klaim & reconciliation' },
  { label: 'SCF / Finansial', icon: 'i-lucide-banknote',   to: '/dashboard/financial',   desc: 'Invoice financing, bridging' },
  { label: 'Gudang',        icon: 'i-lucide-warehouse',     to: '/dashboard/warehouse',   desc: 'Picking, packing, ePOD' },
  { label: 'Analytics',     icon: 'i-lucide-bar-chart-2',  to: '/dashboard/analytics',   desc: 'Dashboard & laporan' }
]
</script>

<template>
  <div class="space-y-6">

    <!-- Header -->
    <div>
      <h1 class="text-xl font-bold text-gray-900 dark:text-white">
        Selamat datang, {{ user?.email?.split('@')[0] }} 👋
      </h1>
      <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
        RS Umum Demo · Tenant Admin ·
        {{ new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) }}
      </p>
    </div>

    <!-- KPI Cards -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div
        v-for="stat in stats"
        :key="stat.label"
        class="bg-white dark:bg-gray-900 rounded-xl p-5 border border-gray-200 dark:border-gray-800 flex items-center gap-4"
      >
        <div :class="[stat.bg, 'w-11 h-11 rounded-lg flex items-center justify-center flex-shrink-0']">
          <UIcon :name="stat.icon" :class="[stat.color, 'text-xl']" />
        </div>
        <div class="min-w-0">
          <p class="text-xl font-bold text-gray-900 dark:text-white">{{ stat.value }}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5 leading-tight">{{ stat.label }}</p>
        </div>
      </div>
    </div>

    <!-- Quick access modules -->
    <div>
      <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">Akses Cepat</h2>
      <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
        <NuxtLink
          v-for="mod in modules"
          :key="mod.to"
          :to="mod.to"
          class="group bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl p-4 hover:border-primary-300 dark:hover:border-primary-700 hover:shadow-sm transition-all"
        >
          <UIcon :name="mod.icon" class="text-2xl text-gray-400 group-hover:text-primary-500 transition-colors mb-2" />
          <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ mod.label }}</p>
          <p class="text-xs text-gray-400 mt-0.5">{{ mod.desc }}</p>
        </NuxtLink>
      </div>
    </div>

    <!-- Setup checklist (shown when data is empty) -->
    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5">
      <div class="flex items-center gap-2 mb-4">
        <UIcon name="i-lucide-list-checks" class="text-primary-500 text-lg" />
        <h2 class="text-sm font-semibold text-gray-900 dark:text-white">Setup Awal</h2>
      </div>
      <div class="space-y-2.5">
        <div v-for="step in [
          { label: 'Akun demo berhasil login', done: true },
          { label: 'Database schema siap (17 modul)', done: true },
          { label: 'Load KFA catalog (24K obat + 69K alkes)', done: false },
          { label: 'Setup warehouse & lokasi penyimpanan', done: false },
          { label: 'Tambah supplier pertama', done: false },
          { label: 'Buat purchase request pertama', done: false }
        ]" :key="step.label" class="flex items-center gap-2.5">
          <div :class="step.done
            ? 'w-5 h-5 rounded-full bg-emerald-500 flex items-center justify-center flex-shrink-0'
            : 'w-5 h-5 rounded-full border-2 border-gray-300 dark:border-gray-600 flex-shrink-0'"
          >
            <UIcon v-if="step.done" name="i-lucide-check" class="text-white text-xs" />
          </div>
          <span :class="step.done
            ? 'text-sm text-gray-400 dark:text-gray-500 line-through'
            : 'text-sm text-gray-700 dark:text-gray-300'"
          >{{ step.label }}</span>
        </div>
      </div>
    </div>

  </div>
</template>
