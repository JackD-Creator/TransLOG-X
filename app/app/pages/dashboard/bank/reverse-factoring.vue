<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Reverse Factoring' })
</script>
<template>
  <div class="space-y-5">
    <h1 class="text-xl font-bold text-[#1a1a1a]">Reverse Factoring</h1>
    <p class="text-sm text-[#999]">Program pembiayaan rantai pasok: Bank bayar Distributor lebih awal atas nama KSM</p>
    <NuxtLink to="/dashboard/bank/facilities" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold">
      <UIcon name="i-lucide-landmark" class="text-sm"/> Lihat Fasilitas Aktif
    </NuxtLink>
  </div>
</template>
