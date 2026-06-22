<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const features = [
  {
    title: 'Demand Forecasting',
    desc: 'Prediksi kebutuhan stok 30/60/90 hari ke depan berbasis pola historis & musim penyakit.',
    status: 'live', icon: 'i-lucide-brain', color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950',
    metrics: [{ label: 'Akurasi model', value: '94.2%' }, { label: 'Item diprediksi', value: '142' }, { label: 'Last run', value: '06:00 WIB' }]
  },
  {
    title: 'Anomali Deteksi',
    desc: 'Deteksi transaksi mencurigakan, pola pembelian tidak wajar, dan potensi fraud pengadaan.',
    status: 'live', icon: 'i-lucide-shield-alert', color: 'text-red-600', bg: 'bg-red-50 dark:bg-red-950',
    metrics: [{ label: 'Alert bulan ini', value: '3' }, { label: 'False positive', value: '0.8%' }, { label: 'Model', value: 'Isolation Forest' }]
  },
  {
    title: 'Auto Reorder Recommendation',
    desc: 'Rekomendasi otomatis kapan dan berapa banyak reorder berdasarkan lead time & stok minimum.',
    status: 'live', icon: 'i-lucide-zap', color: 'text-amber-600', bg: 'bg-amber-50 dark:bg-amber-950',
    metrics: [{ label: 'Rekomendasi aktif', value: '7 item' }, { label: 'Estimasi saving', value: 'Rp 12Jt' }, { label: 'Akurasi', value: '91%' }]
  },
  {
    title: 'Supplier Performance Scoring',
    desc: 'Skoring otomatis performa supplier: ketepatan waktu, kesesuaian mutu, dan harga kompetitif.',
    status: 'beta', icon: 'i-lucide-bar-chart-2', color: 'text-blue-600', bg: 'bg-blue-50 dark:bg-blue-950',
    metrics: [{ label: 'Supplier dinilai', value: '18' }, { label: 'Update', value: 'Mingguan' }, { label: 'Model', value: 'Multi-criteria' }]
  },
  {
    title: 'BPJS Claim Validation',
    desc: 'AI checker untuk validasi koding ICD-10, kelengkapan berkas, dan prediksi probabilitas approve.',
    status: 'beta', icon: 'i-lucide-stethoscope', color: 'text-emerald-600', bg: 'bg-emerald-50 dark:bg-emerald-950',
    metrics: [{ label: 'Klaim dicek', value: '1.284' }, { label: 'Potensi ditolak', value: '12' }, { label: 'Akurasi', value: '88%' }]
  },
  {
    title: 'Expiry & Waste Prediction',
    desc: 'Prediksi item yang berisiko kadaluarsa sebelum terpakai dan rekomendasi redistribusi antar unit.',
    status: 'coming', icon: 'i-lucide-calendar-x', color: 'text-gray-500', bg: 'bg-gray-100 dark:bg-gray-800',
    metrics: [{ label: 'Status', value: 'Q3 2026' }, { label: 'Model', value: 'LSTM' }, { label: 'Training', value: 'In progress' }]
  },
]
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">AI / Machine Learning</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Modul kecerdasan buatan untuk optimasi logistik & prediksi</p>
      </div>
      <div class="flex gap-2 text-xs">
        <span class="px-2 py-1 rounded-full bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400 font-medium">● Live</span>
        <span class="px-2 py-1 rounded-full bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400 font-medium">● Beta</span>
        <span class="px-2 py-1 rounded-full bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400 font-medium">● Coming Soon</span>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="f in features" :key="f.title"
        class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-5 hover:border-red-300 dark:hover:border-red-800 transition-colors"
        :class="f.status==='coming'?'opacity-60':''">
        <div class="flex items-start justify-between mb-4">
          <div :class="[f.bg,'w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="f.icon" :class="[f.color,'text-xl']" />
          </div>
          <span :class="[
            'px-2 py-0.5 rounded-full text-xs font-medium',
            f.status==='live'?'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400':
            f.status==='beta'?'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400':
            'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400'
          ]">{{ f.status === 'coming' ? 'Coming Soon' : f.status.toUpperCase() }}</span>
        </div>
        <h3 class="text-sm font-bold text-gray-900 dark:text-white mb-1.5">{{ f.title }}</h3>
        <p class="text-xs text-gray-500 dark:text-gray-400 leading-relaxed mb-4">{{ f.desc }}</p>
        <div class="grid grid-cols-3 gap-2 pt-3 border-t border-gray-100 dark:border-gray-800">
          <div v-for="m in f.metrics" :key="m.label" class="text-center">
            <p class="text-xs font-bold text-gray-900 dark:text-white">{{ m.value }}</p>
            <p class="text-[10px] text-gray-400 leading-tight mt-0.5">{{ m.label }}</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
