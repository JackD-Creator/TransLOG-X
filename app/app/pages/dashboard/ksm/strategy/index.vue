<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Strategi Bisnis KSM' })

const strategies = [
  {
    title: 'Ecosystem Value Proposition',
    subtitle: 'Win-Win untuk Semua Pihak',
    desc: 'Analisis keuntungan finansial konkret untuk RS, KSM, Distributor, dan Bank — total nilai ekosistem yang diciptakan TransLOG-X secara kuantitatif.',
    icon: 'i-lucide-globe',
    color: 'text-slate-600', bg: 'bg-slate-100',
    to: '/dashboard/ksm/strategy/ecosystem',
    badge: 'All Stakeholders',
    badgeColor: 'bg-slate-200 text-slate-700',
  },
  {
    title: 'Revenue Architecture — Supply ke RS',
    subtitle: 'Financial Model + KFA Benchmark',
    desc: 'Institutional revenue model: gross profit decomposition, sensitivity analysis, KFA price intelligence (live DB), deal structure options, dan risk framework.',
    icon: 'i-lucide-target',
    color: 'text-emerald-600', bg: 'bg-emerald-50',
    to: '/dashboard/ksm/strategy/supply',
    badge: 'Revenue Optimization',
    badgeColor: 'bg-emerald-100 text-emerald-700',
  },
  {
    title: 'Procurement Intelligence — Negosiasi Distributor',
    subtitle: 'Term Sheet + 5 Scenario NPV',
    desc: 'Multi-scenario deal framework berbasis HAP/HET KFA real: spot, extended terms, early payment, annual contract+rebate, consignment — dengan payment terms sensitivity.',
    icon: 'i-lucide-handshake',
    color: 'text-blue-600', bg: 'bg-blue-50',
    to: '/dashboard/ksm/strategy/negotiation',
    badge: 'Cost Optimization',
    badgeColor: 'bg-blue-100 text-blue-700',
  },
  {
    title: 'Credit Memo — Pitch ke Bank',
    subtitle: 'DSCR · LTV · Collateral · Yield Model',
    desc: 'Institutional credit analysis: DSCR scorecard, BPJS collateral coverage, yield sensitivity table, self-liquidating cash cycle, dan proposed term sheet SCF.',
    icon: 'i-lucide-landmark',
    color: 'text-amber-700', bg: 'bg-amber-50',
    to: '/dashboard/ksm/strategy/bank-pitch',
    badge: 'Financing Strategy',
    badgeColor: 'bg-amber-100 text-amber-700',
  },
]
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Strategi Bisnis KSM</h1>
      <p class="text-sm text-[#999] mt-0.5">Panduan strategis untuk optimasi revenue, negosiasi, dan kemitraan perbankan</p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <NuxtLink v-for="s in strategies" :key="s.title" :to="s.to"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-6 hover:border-[#6b1525]/40 transition-all group cursor-pointer">
        <div class="flex items-start gap-4 mb-4">
          <div :class="[s.bg, 'w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="s.icon" :class="[s.color, 'text-2xl']"/>
          </div>
          <span :class="['px-2 py-0.5 rounded-full text-[10px] font-bold', s.badgeColor]">{{ s.badge }}</span>
        </div>
        <h3 class="text-base font-bold text-[#1a1a1a] mb-1 group-hover:text-[#6b1525] transition-colors">{{ s.title }}</h3>
        <p class="text-xs font-semibold text-[#6b1525] mb-2">{{ s.subtitle }}</p>
        <p class="text-xs text-[#999] leading-relaxed">{{ s.desc }}</p>
        <div class="mt-4 flex items-center gap-1 text-xs font-semibold text-[#6b1525]">
          <span>Lihat Strategi</span>
          <UIcon name="i-lucide-arrow-right" class="text-xs"/>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
