<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'BPJS Bridging' })
</script>
<template>
  <div class="space-y-5">
    <h1 class="text-xl font-bold text-[#1a1a1a]">BPJS Bridging Financing</h1>
    <p class="text-sm text-[#999]">Pembiayaan jangka pendek untuk RS menunggu pembayaran klaim BPJS Kesehatan</p>
    <div class="bg-blue-50 rounded-xl border border-blue-100 p-4 text-xs text-blue-800">
      <p class="font-bold mb-1">Cara Kerja BPJS Bridging</p>
      <p>RS mengajukan klaim ke BPJS → proses verifikasi 2–4 minggu → Bank memberikan talangan kepada RS → BPJS membayar → Bank langsung menerima via Standing Instruction dari rekening RS.</p>
    </div>
    <NuxtLink to="/dashboard/bank/bpjs-monitoring" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold">
      <UIcon name="i-lucide-stethoscope" class="text-sm"/> Monitoring BPJS Cashflow
    </NuxtLink>
  </div>
</template>
