<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Alert Min Stok SIMRS' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const notifications = ref<any[]>([])

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('hospital_notifications')
    .select('id,notif_number,notif_date,status,source,notes,metadata,ksm_confirmation_status,hospital_notification_lines(id,kfa_code,item_name,uom,current_stock,min_stock,requested_qty)')
    .eq('rs_tenant_id', tenantId.value)
    .order('notif_date', { ascending: false })
    .limit(50)
  notifications.value = data ?? []
  loading.value = false
}

const statusLabel: Record<string, { label: string; color: string }> = {
  pending:       { label: 'Dikirim ke KSM',  color: 'bg-amber-100 text-amber-700' },
  acknowledged:  { label: 'KSM Proses',      color: 'bg-blue-100 text-blue-700' },
  po_created:    { label: 'PO Dibuat',       color: 'bg-purple-100 text-purple-700' },
  completed:     { label: 'Selesai',         color: 'bg-emerald-100 text-emerald-700' },
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Alert Minimum Stok (SIMRS)</h1>
      <p class="text-sm text-[#999] mt-0.5">Notifikasi otomatis dari SIMRS saat stok di bawah minimum — terkirim ke Tim Procurement RS & KSM</p>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="notifications.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Semua stok dalam kondisi aman</p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="n in notifications" :key="n.id"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-blue-100 text-blue-700">SIMRS Auto</span>
              <p class="font-mono text-xs font-semibold text-[#1a1a1a]">{{ n.notif_number }}</p>
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', statusLabel[n.status]?.color ?? 'bg-[#f0f0f0] text-[#999]']">
                {{ statusLabel[n.status]?.label ?? n.status }}
              </span>
              <span v-if="n.ksm_confirmation_status === 'pending_rs_approval'" class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700 animate-pulse">
                Perlu Persetujuan Anda
              </span>
            </div>
            <p class="text-xs text-[#999]">{{ fmtDate(n.notif_date) }} · {{ n.hospital_notification_lines?.length ?? 0 }} item di bawah minimum</p>
            <p v-if="n.notes" class="text-xs text-[#666] mt-1 italic">{{ n.notes }}</p>
          </div>
          <div v-if="n.ksm_confirmation_status === 'pending_rs_approval'">
            <NuxtLink :to="`/dashboard/rs/confirmations?notif=${n.id}`"
              class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] transition-colors">
              Review & Setujui
            </NuxtLink>
          </div>
        </div>

        <!-- Item list -->
        <div class="px-5 pb-4">
          <div class="bg-white rounded-lg border border-[#e5e5e5] overflow-hidden">
            <table class="w-full text-xs">
              <thead class="bg-[#fafafa] border-b border-[#e5e5e5]">
                <tr>
                  <th class="px-3 py-2 text-left font-semibold text-[#999]">Item</th>
                  <th class="px-3 py-2 text-center font-semibold text-[#999]">Stok</th>
                  <th class="px-3 py-2 text-center font-semibold text-[#999]">Minimum</th>
                  <th class="px-3 py-2 text-center font-semibold text-[#999]">Kekurangan</th>
                  <th class="px-3 py-2 text-center font-semibold text-[#999]">Request</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-[#f0f0f0]">
                <tr v-for="l in n.hospital_notification_lines" :key="l.id">
                  <td class="px-3 py-2">
                    <p class="font-semibold text-[#1a1a1a]">{{ l.item_name }}</p>
                    <p class="text-[10px] font-mono text-[#aaa]">{{ l.kfa_code }}</p>
                  </td>
                  <td class="px-3 py-2 text-center">
                    <span :class="['font-bold', l.current_stock <= 10 ? 'text-red-600' : 'text-amber-600']">{{ l.current_stock }}</span>
                  </td>
                  <td class="px-3 py-2 text-center text-[#999]">{{ l.min_stock }}</td>
                  <td class="px-3 py-2 text-center font-bold text-red-600">{{ Math.max(0, l.min_stock - l.current_stock) }}</td>
                  <td class="px-3 py-2 text-center font-bold text-[#1a1a1a]">{{ l.requested_qty }} {{ l.uom }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
