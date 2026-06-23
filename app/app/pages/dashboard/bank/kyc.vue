<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'KYC Mitra' })

const supabase = useSupabaseClient()
const loading = ref(true)
const tenants = ref<any[]>([])

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('tenants')
    .select('id, name, type, kyc_status, kyc_verified_at, status, email')
    .in('type', ['mitra_ksm', 'pbf', 'distributor'])
    .order('name', { ascending: true })
  tenants.value = data ?? []
  loading.value = false
}

const kycColor: Record<string, string> = {
  not_started: 'bg-[#f0f0f0] text-[#999]',
  in_progress:  'bg-amber-100 text-amber-700',
  verified:     'bg-emerald-100 text-emerald-700',
  rejected:     'bg-red-100 text-red-700',
  expired:      'bg-orange-100 text-orange-700',
}
const kycLabel: Record<string, string> = {
  not_started: 'Belum Mulai', in_progress: 'Proses', verified: 'Terverifikasi', rejected: 'Ditolak', expired: 'Kadaluarsa',
}

onMounted(load)
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">KYC Mitra</h1>
      <p class="text-sm text-[#999] mt-0.5">Status verifikasi KYC KSM Mitra dan Distributor yang bekerjasama dengan Bank</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <table class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Nama</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tipe</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Email</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">KYC Status</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tgl Verifikasi</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tenant Status</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="t in tenants" :key="t.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-medium text-[#1a1a1a]">{{ t.name }}</td>
            <td class="px-4 py-3 text-[#666]">{{ t.type?.replace('_', ' ') }}</td>
            <td class="px-4 py-3 text-[#666]">{{ t.email }}</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full font-medium', kycColor[t.kyc_status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ kycLabel[t.kyc_status] ?? t.kyc_status }}
              </span>
            </td>
            <td class="px-4 py-3 text-[#666]">
              {{ t.kyc_verified_at ? new Date(t.kyc_verified_at).toLocaleDateString('id-ID') : '-' }}
            </td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-medium', t.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700']">
                {{ t.status }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
