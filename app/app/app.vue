<script setup lang="ts">
useSeoMeta({
  title: 'TransLOG-X — AI E-Logistics Platform',
  description: 'Platform logistik rumah sakit berbasis AI. Kelola pengadaan, stok, keuangan, dan BPJS dalam satu sistem.'
})
</script>

<template>
  <UApp>
    <NuxtLayout>
      <NuxtPage :keepalive="{ max: 5 }" />
    </NuxtLayout>
  </UApp>
</template>
