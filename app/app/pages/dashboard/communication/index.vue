<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })
const activeTab = ref('notif')
const tabs = [
  { key: 'notif',   label: 'Notifikasi',        icon: 'i-lucide-bell' },
  { key: 'chat',    label: 'Pesan Internal',     icon: 'i-lucide-message-square' },
  { key: 'announce',label: 'Pengumuman',         icon: 'i-lucide-megaphone' },
]

const notifs = ref([
  { id: 1, tipe: 'alert',   judul: 'Stok Hampir Habis',            pesan: 'Amoxicillin 500mg sisa 80 unit, di bawah batas minimum (100)', waktu: '10 menit lalu', read: false, icon: 'i-lucide-package', color: 'text-amber-600 dark:text-amber-400', bg: 'bg-amber-50 dark:bg-amber-950' },
  { id: 2, tipe: 'info',    judul: 'PO Dikonfirmasi Supplier',      pesan: 'PO-2026-0045 dikonfirmasi oleh PT. Kimia Farma. ETA 25 Juni.', waktu: '1 jam lalu', read: false, icon: 'i-lucide-check-circle', color: 'text-emerald-600 dark:text-emerald-400', bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { id: 3, tipe: 'warning', judul: 'Invoice Jatuh Tempo Besok',     pesan: 'INV-2026-0088 senilai Rp 125Jt jatuh tempo 23 Juni 2026.', waktu: '3 jam lalu', read: false, icon: 'i-lucide-alert-triangle', color: 'text-red-600 dark:text-red-400', bg: 'bg-red-50 dark:bg-red-950' },
  { id: 4, tipe: 'info',    judul: 'Demand Forecast Diperbarui',    pesan: 'AI demand forecast telah dijalankan. 142 item diperbarui.', waktu: '6 jam lalu', read: true, icon: 'i-lucide-brain', color: 'text-purple-600 dark:text-purple-400', bg: 'bg-purple-50 dark:bg-purple-950' },
  { id: 5, tipe: 'alert',   judul: 'Login Gagal Berulang',          pesan: '3 percobaan login gagal untuk eko.p@rsdemo.id dari IP asing.', waktu: '8 jam lalu', read: true, icon: 'i-lucide-shield-alert', color: 'text-red-600 dark:text-red-400', bg: 'bg-red-50 dark:bg-red-950' },
  { id: 6, tipe: 'info',    judul: 'PR Disetujui',                  pesan: 'PR-2026-0011 dari IGD telah disetujui oleh Dr. Ahmad Fauzi.', waktu: '1 hari lalu', read: true, icon: 'i-lucide-clipboard-check', color: 'text-blue-600 dark:text-blue-400', bg: 'bg-blue-50 dark:bg-blue-950' },
])

const messages = ref([
  { dari: 'Apt. Sari Dewi',    waktu: '09:32', pesan: 'Stok Paracetamol di poli sudah di-update. Mohon konfirmasi pengiriman.',  unread: 2 },
  { dari: 'Budi Santoso',      waktu: '08:55', pesan: 'GRN-2026-0031 sudah selesai. Ada 2 item yang kualitasnya perlu dicek.',   unread: 0 },
  { dari: 'Rini Astuti',       waktu: 'Kemarin',pesan: 'Invoice bulan ini sudah disiapkan. Tolong review sebelum dikirim.',      unread: 1 },
  { dari: 'Dr. Dewi Lestari',  waktu: 'Kemarin',pesan: 'Ada permintaan obat non-formulary untuk pasien ICU. Mohon tindak lanjut.',unread: 0 },
])

const announcements = ref([
  { judul: 'Pemeliharaan Sistem — 29 Juni 2026',        isi: 'Sistem akan dalam maintenance pada 29 Juni 2026 pukul 00:00–04:00 WIB. Harap simpan pekerjaan sebelum jam tersebut.', tanggal: '2026-06-22', prioritas: 'high', penulis: 'IT Admin' },
  { judul: 'Update Formularium Nasional 2026',           isi: 'KMK HK.01.07/MENKES/1199/2025 berlaku mulai 1 April 2026. Mohon review dan sesuaikan formularium RS.', tanggal: '2026-06-15', prioritas: 'high', penulis: 'Komite Farmasi' },
  { judul: 'Pelatihan Sistem Pengadaan Baru',            isi: 'Pelatihan modul pengadaan akan dilaksanakan 30 Juni 2026 pukul 09:00 via Zoom. Wajib dihadiri oleh tim procurement.', tanggal: '2026-06-10', prioritas: 'normal', penulis: 'HRD' },
])

const unreadCount = computed(() => notifs.value.filter(n => !n.read).length)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">Komunikasi & Kolaborasi</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Notifikasi sistem, pesan internal & pengumuman</p>
      </div>
      <div v-if="unreadCount > 0" class="px-3 py-1.5 bg-red-100 dark:bg-red-950 border border-red-200 dark:border-red-800 rounded-xl">
        <span class="text-sm font-bold text-red-600 dark:text-red-400">{{ unreadCount }} belum dibaca</span>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="flex border-b border-gray-200 dark:border-gray-800">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px relative"
          :class="activeTab===tab.key?'border-red-600 text-red-600 dark:text-red-400':'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700'"
          @click="activeTab=tab.key">
          <UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}
          <span v-if="tab.key==='notif' && unreadCount > 0" class="absolute top-2.5 right-2 w-4 h-4 bg-red-600 text-white text-[9px] font-bold rounded-full flex items-center justify-center">{{ unreadCount }}</span>
        </button>
      </div>

      <!-- Notifikasi -->
      <div v-if="activeTab==='notif'" class="divide-y divide-gray-100 dark:divide-gray-800">
        <div v-for="n in notifs" :key="n.id"
          class="px-5 py-4 flex items-start gap-4 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer"
          :class="!n.read ? 'bg-blue-50/30 dark:bg-blue-950/10' : ''">
          <div :class="[n.bg,'w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="n.icon" :class="[n.color,'text-base']"/>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-2">
              <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ n.judul }}</p>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span class="text-xs text-gray-400">{{ n.waktu }}</span>
                <div v-if="!n.read" class="w-2 h-2 bg-red-600 rounded-full flex-shrink-0"/>
              </div>
            </div>
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5 leading-relaxed">{{ n.pesan }}</p>
          </div>
        </div>
      </div>

      <!-- Pesan -->
      <div v-if="activeTab==='chat'" class="divide-y divide-gray-100 dark:divide-gray-800">
        <div v-for="m in messages" :key="m.dari" class="px-5 py-4 flex items-start gap-3 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
          <div class="w-9 h-9 rounded-full bg-red-100 dark:bg-red-900/40 flex items-center justify-center flex-shrink-0">
            <span class="text-sm font-bold text-red-600 dark:text-red-400">{{ m.dari.charAt(0) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between">
              <p class="text-sm font-semibold text-gray-900 dark:text-white">{{ m.dari }}</p>
              <div class="flex items-center gap-2">
                <span class="text-xs text-gray-400">{{ m.waktu }}</span>
                <span v-if="m.unread > 0" class="w-5 h-5 bg-red-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center">{{ m.unread }}</span>
              </div>
            </div>
            <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5 truncate">{{ m.pesan }}</p>
          </div>
        </div>
        <div class="p-4 border-t border-gray-100 dark:border-gray-800 flex gap-2">
          <input type="text" placeholder="Tulis pesan..." class="flex-1 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-500">
          <UButton icon="i-lucide-send" color="primary" size="sm"/>
        </div>
      </div>

      <!-- Pengumuman -->
      <div v-if="activeTab==='announce'" class="divide-y divide-gray-100 dark:divide-gray-800">
        <div class="px-5 py-4 flex justify-end border-b border-gray-100 dark:border-gray-800">
          <UButton icon="i-lucide-plus" size="xs" color="primary">Buat Pengumuman</UButton>
        </div>
        <div v-for="a in announcements" :key="a.judul" class="px-5 py-5 hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
          <div class="flex items-start gap-3">
            <div :class="['w-2 h-2 rounded-full mt-1.5 flex-shrink-0', a.prioritas==='high'?'bg-red-500':'bg-gray-400']"/>
            <div class="flex-1">
              <div class="flex items-start justify-between gap-2">
                <p class="text-sm font-bold text-gray-900 dark:text-white">{{ a.judul }}</p>
                <span class="text-xs text-gray-400 flex-shrink-0">{{ a.tanggal }}</span>
              </div>
              <p class="text-xs text-gray-500 dark:text-gray-400 mt-1.5 leading-relaxed">{{ a.isi }}</p>
              <p class="text-xs text-gray-400 mt-2">Oleh: {{ a.penulis }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
