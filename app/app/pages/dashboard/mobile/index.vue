<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const features = [
  { icon: 'i-lucide-scan-barcode', title: 'Barcode & QR Scanner',       desc: 'Scan item untuk penerimaan, picking, distribusi & stock opname langsung dari kamera ponsel.', status: 'planned' },
  { icon: 'i-lucide-package-check',title: 'Mobile Receiving (GRN)',      desc: 'Input penerimaan barang di gudang tanpa perlu ke komputer. Scan, verifikasi, konfirmasi.', status: 'planned' },
  { icon: 'i-lucide-truck',        title: 'ePOD (Proof of Delivery)',    desc: 'Konfirmasi pengiriman dengan tanda tangan digital & foto barang di tangan penerima.', status: 'planned' },
  { icon: 'i-lucide-clipboard-list',title:'Mobile PR & Approval',        desc: 'Buat purchase request dan approve dokumen dari smartphone kapan saja.', status: 'planned' },
  { icon: 'i-lucide-bell',         title: 'Push Notification',           desc: 'Notifikasi real-time untuk alert stok, approval pending & pengiriman masuk.', status: 'planned' },
  { icon: 'i-lucide-wifi-off',     title: 'Offline Mode',                desc: 'Tetap bisa beroperasi saat tidak ada koneksi internet. Data sync otomatis saat online.', status: 'planned' },
]

const roadmap = [
  { fase: 'Q3 2026', items: ['Barcode scanner (iOS & Android)', 'Mobile GRN', 'Push notification'], status: 'upcoming' },
  { fase: 'Q4 2026', items: ['ePOD & tanda tangan digital', 'Mobile PR & approval', 'Dashboard ringkas'], status: 'planned' },
  { fase: 'Q1 2027', items: ['Offline mode dengan sync', 'RFID scanning', 'Wearable / headset support'], status: 'planned' },
]
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Mobile Application</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Aplikasi mobile untuk operasional lapangan & gudang</p>
      </div>
      <span class="px-3 py-1.5 bg-amber-100 dark:bg-amber-950 border border-amber-200 dark:border-amber-800 rounded-xl text-sm font-bold text-amber-700 dark:text-amber-400">
        In Development — Q3 2026
      </span>
    </div>

    <!-- Banner -->
    <div class="bg-gradient-to-r from-gray-900 to-gray-800 rounded-xl p-8 flex items-center gap-8 overflow-hidden relative">
      <div class="absolute right-0 top-0 bottom-0 w-64 opacity-5">
        <UIcon name="i-lucide-smartphone" class="text-white" style="font-size: 280px; position: absolute; right: -60px; top: -40px;"/>
      </div>
      <div class="flex-1">
        <p class="text-xs font-semibold text-red-400 uppercase tracking-widest mb-2">TransLOG-X Mobile</p>
        <h2 class="text-2xl font-bold text-white mb-3">Operasional Gudang di Ujung Jari</h2>
        <p class="text-gray-400 text-sm max-w-lg leading-relaxed">
          Aplikasi mobile native (iOS & Android) untuk petugas gudang, penerima barang & kurir. Scan barcode, konfirmasi penerimaan, dan tandatangani pengiriman langsung dari smartphone.
        </p>
        <div class="flex gap-3 mt-5">
          <div class="flex items-center gap-2 bg-white/10 rounded-lg px-3 py-2">
            <UIcon name="i-lucide-apple" class="text-white text-lg"/>
            <span class="text-white text-sm font-medium">App Store</span>
          </div>
          <div class="flex items-center gap-2 bg-white/10 rounded-lg px-3 py-2">
            <UIcon name="i-lucide-smartphone" class="text-white text-lg"/>
            <span class="text-white text-sm font-medium">Google Play</span>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <!-- Features -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Fitur yang Direncanakan</h2>
        </div>
        <div class="divide-y divide-gray-100 dark:divide-gray-800">
          <div v-for="f in features" :key="f.title" class="px-5 py-4 flex items-start gap-3">
            <div class="w-9 h-9 rounded-lg bg-red-50 dark:bg-red-950 flex items-center justify-center flex-shrink-0">
              <UIcon :name="f.icon" class="text-red-600 dark:text-red-400 text-base"/>
            </div>
            <div class="flex-1">
              <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ f.title }}</p>
              <p class="text-xs text-gray-400 mt-0.5 leading-relaxed">{{ f.desc }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Roadmap -->
      <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 dark:border-gray-800">
          <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Roadmap Pengembangan</h2>
        </div>
        <div class="p-5 space-y-5">
          <div v-for="(r, i) in roadmap" :key="r.fase" class="flex gap-4">
            <div class="flex flex-col items-center">
              <div :class="['w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-xs font-bold', i===0?'bg-red-600 text-white':'bg-gray-100 dark:bg-gray-800 text-gray-500']">
                {{ i+1 }}
              </div>
              <div v-if="i < roadmap.length-1" class="w-px flex-1 bg-gray-200 dark:bg-gray-700 my-1"/>
            </div>
            <div class="flex-1 pb-4">
              <div class="flex items-center gap-2 mb-2">
                <p class="text-sm font-bold text-gray-900 dark:text-white">{{ r.fase }}</p>
                <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', i===0?'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400':'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400']">
                  {{ i===0?'Upcoming':'Planned' }}
                </span>
              </div>
              <ul class="space-y-1">
                <li v-for="item in r.items" :key="item" class="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                  <UIcon name="i-lucide-circle-dot" class="text-gray-300 dark:text-gray-600 text-sm flex-shrink-0"/>
                  {{ item }}
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
