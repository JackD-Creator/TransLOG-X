<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Notifikasi Min Stok' })

const supabase = useSupabaseClient()

const loading = ref(true)
const notifications = ref<any[]>([])

const statusColor: Record<string, string> = {
  pending:      'bg-amber-100 text-amber-700',
  acknowledged: 'bg-blue-100 text-blue-700',
  po_created:   'bg-purple-100 text-purple-700',
  completed:    'bg-emerald-100 text-emerald-700',
  cancelled:    'bg-[#f0f0f0] text-[#999]',
}
const statusLabel: Record<string, string> = {
  pending:      'Menunggu',
  acknowledged: 'Diakui',
  po_created:   'PO Dibuat',
  completed:    'Selesai',
  cancelled:    'Dibatalkan',
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('hospital_notifications')
    .select('*, hospital_notification_lines(*)')
    .order('notif_date', { ascending: false })
    .limit(50)
  notifications.value = data ?? []
  loading.value = false
}

async function acknowledge(id: string) {
  await supabase.from('hospital_notifications')
    .update({ status: 'acknowledged', acknowledged_at: new Date().toISOString() })
    .eq('id', id)
  await load()
}

onMounted(load)

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Notifikasi Min Stok RS</h1>
        <p class="text-sm text-[#999] mt-0.5">Permintaan pengadaan dari Rumah Sakit mitra</p>
      </div>
      <button class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors" @click="load">
        <UIcon name="i-lucide-refresh-cw" class="text-sm"/>
        Refresh
      </button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div v-for="(label, key) in statusLabel" :key="key" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ notifications.filter(n => n.status === key).length }}</p>
        <p class="text-xs text-[#999] mt-1">{{ label }}</p>
      </div>
    </div>

    <!-- Table -->
    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div v-if="loading" class="flex items-center justify-center py-16">
        <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
      </div>

      <div v-else-if="notifications.length === 0" class="flex flex-col items-center justify-center py-16 gap-3">
        <UIcon name="i-lucide-bell-off" class="text-3xl text-[#ccc]"/>
        <p class="text-sm text-[#999]">Belum ada notifikasi masuk</p>
      </div>

      <table v-else class="w-full text-xs">
        <thead class="border-b border-[#e5e5e5]">
          <tr class="text-left">
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">No Notif</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Tanggal</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">RS Pengirim</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Jumlah Item</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3 font-semibold text-[#999] uppercase tracking-wide">Aksi</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-[#e5e5e5]">
          <tr v-for="n in notifications" :key="n.id" class="hover:bg-[#ebebeb] transition-colors">
            <td class="px-4 py-3 font-mono text-[#1a1a1a]">{{ n.notif_number }}</td>
            <td class="px-4 py-3 text-[#666]">{{ fmtDate(n.notif_date) }}</td>
            <td class="px-4 py-3 text-[#666]">{{ n.rs_tenant_id?.slice(0, 8) ?? '-' }}</td>
            <td class="px-4 py-3 font-semibold text-[#1a1a1a]">{{ n.hospital_notification_lines?.length ?? 0 }} item</td>
            <td class="px-4 py-3">
              <span :class="['px-2 py-0.5 rounded-full font-medium', statusColor[n.status] ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[n.status] ?? n.status }}
              </span>
            </td>
            <td class="px-4 py-3">
              <button v-if="n.status === 'pending'"
                class="text-[#6b1525] font-semibold hover:text-[#5a1120]"
                @click="acknowledge(n.id)">
                Akui
              </button>
              <NuxtLink v-else-if="n.status === 'acknowledged'"
                :to="`/dashboard/ksm/purchase-orders?notif=${n.id}`"
                class="text-blue-600 font-semibold hover:text-blue-800">
                Buat PO
              </NuxtLink>
              <span v-else class="text-[#ccc]">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
