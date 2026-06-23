<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Laporan Keuangan KSM' })

// Hub halaman laporan keuangan KSM

const reports = [
  {
    title: 'Laba Rugi (P&L)',
    desc: 'Pendapatan, HPP, biaya operasional, dan laba bersih KSM per periode.',
    icon: 'i-lucide-trending-up',
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
    to: '/dashboard/ksm/finance/pl'
  },
  {
    title: 'Neraca (Balance Sheet)',
    desc: 'Aset, liabilitas (hutang ke Bank), dan ekuitas KSM.',
    icon: 'i-lucide-scale',
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    to: '/dashboard/ksm/finance/balance-sheet'
  },
  {
    title: 'Arus Kas (Cash Flow)',
    desc: 'Arus kas masuk dari RS, keluar ke distributor, dan neto per periode.',
    icon: 'i-lucide-waves',
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    to: '/dashboard/ksm/finance/cash-flow'
  },
  {
    title: 'AR Aging',
    desc: 'Analisis umur piutang ke Bank: current, 30, 60, 90+ hari.',
    icon: 'i-lucide-calendar-clock',
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    to: '/dashboard/ksm/ar'
  },
  {
    title: 'Fasilitas SCF',
    desc: 'Utilisasi limit fasilitas pembiayaan dari Bank, bunga, dan tenor.',
    icon: 'i-lucide-landmark',
    color: 'text-[#6b1525]',
    bg: 'bg-red-50',
    to: '/dashboard/ksm/scf'
  },
  {
    title: 'Rekonsiliasi Pembayaran',
    desc: 'Rekonsiliasi pembayaran masuk dari Bank dan pembayaran ke distributor.',
    icon: 'i-lucide-check-square',
    color: 'text-teal-600',
    bg: 'bg-teal-50',
    to: '/dashboard/ksm/payments'
  },
]
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Laporan Keuangan</h1>
      <p class="text-sm text-[#999] mt-0.5">Financial statements & analisis keuangan bisnis KSM Mitra</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <NuxtLink v-for="r in reports" :key="r.title" :to="r.to"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 hover:border-[#6b1525]/40 transition-colors group">
        <div class="flex items-start gap-4">
          <div :class="[r.bg, 'w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="r.icon" :class="[r.color, 'text-xl']"/>
          </div>
          <div>
            <h3 class="text-sm font-bold text-[#1a1a1a] mb-1 group-hover:text-[#6b1525] transition-colors">{{ r.title }}</h3>
            <p class="text-xs text-[#999] leading-relaxed">{{ r.desc }}</p>
          </div>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
