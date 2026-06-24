<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Konfirmasi Pengiriman KSM' })

const supabase = useSupabaseClient()
const { apiPost } = useApi()
const { tenantId } = useUserRole()

const loading = ref(true)
const pendingList = ref<any[]>([])
const editingNotif = ref<string | null>(null)
const editQtys = ref<Record<string, number>>({})
const actionLoading = ref(false)
const actionError = ref<string | null>(null)

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('hospital_notifications')
    .select('id,notif_number,notif_date,status,metadata,ksm_confirmation_status,ksm_confirmed_at,hospital_notification_lines(id,kfa_code,item_name,uom,current_stock,min_stock,requested_qty,approved_qty)')
    .eq('rs_tenant_id', tenantId.value)
    .eq('ksm_confirmation_status', 'pending_rs_approval')
    .order('ksm_confirmed_at', { ascending: false })
  pendingList.value = data ?? []
  loading.value = false
}

function startEdit(notif: any) {
  editingNotif.value = notif.id
  editQtys.value = {}
  for (const l of notif.hospital_notification_lines ?? []) {
    editQtys.value[l.id] = l.requested_qty
  }
}

async function approveConfirmation(notifId: string) {
  actionLoading.value = true
  actionError.value = null
  try {
    // Update approved_qty di setiap line jika RS modify
    if (editingNotif.value === notifId) {
      const notif = pendingList.value.find(n => n.id === notifId)
      for (const l of notif?.hospital_notification_lines ?? []) {
        const newQty = editQtys.value[l.id] ?? l.requested_qty
        if (newQty !== l.requested_qty) {
          const { error: lineErr } = await supabase.from('hospital_notification_lines')
            .update({ approved_qty: newQty, requested_qty: newQty })
            .eq('id', l.id)
          if (lineErr) throw lineErr
        }
      }
    }

    await apiPost('/api/rs/confirmations', { action: 'approve', notif_id: notifId, reason: '' })
    editingNotif.value = null
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal approve'
  }
  actionLoading.value = false
}

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Konfirmasi Pengiriman dari KSM</h1>
      <p class="text-sm text-[#999] mt-0.5">KSM mengonfirmasi ketersediaan barang — setujui atau ubah jumlah sebelum PO dibuat</p>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="pendingList.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-check-circle" class="text-3xl text-emerald-400"/>
      <p class="text-sm text-[#999]">Tidak ada konfirmasi yang menunggu persetujuan</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="notif in pendingList" :key="notif.id"
        class="bg-[#f5f5f5] rounded-xl border-2 border-amber-300 overflow-hidden">

        <div class="px-5 py-4 bg-amber-50 border-b border-amber-200 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-200 text-amber-800 animate-pulse">Menunggu Persetujuan</span>
              <p class="font-mono text-xs font-semibold text-[#1a1a1a]">{{ notif.notif_number }}</p>
            </div>
            <p class="text-xs text-amber-700">KSM konfirmasi bahwa supplier memiliki stok — review jumlah lalu setujui</p>
            <p class="text-[10px] text-[#999] mt-1">RS: {{ notif.metadata?.rs_name ?? '-' }} · Dikonfirmasi KSM: {{ fmtDate(notif.ksm_confirmed_at) }}</p>
          </div>
        </div>

        <!-- Item table with editable qty -->
        <div class="p-5">
          <div class="bg-white rounded-xl border border-[#e5e5e5] overflow-hidden mb-4">
            <table class="w-full text-xs">
              <thead class="bg-[#fafafa] border-b border-[#e5e5e5]">
                <tr>
                  <th class="px-3 py-2.5 text-left font-semibold text-[#999]">Item</th>
                  <th class="px-3 py-2.5 text-center font-semibold text-[#999]">Stok Saat Ini</th>
                  <th class="px-3 py-2.5 text-center font-semibold text-[#999]">Min Stok</th>
                  <th class="px-3 py-2.5 text-center font-semibold text-[#999]">Request KSM</th>
                  <th class="px-3 py-2.5 text-center font-semibold text-[#999]">
                    {{ editingNotif === notif.id ? 'Qty Disetujui RS' : 'Qty' }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-[#f0f0f0]">
                <tr v-for="line in notif.hospital_notification_lines" :key="line.id">
                  <td class="px-3 py-2.5">
                    <p class="font-semibold text-[#1a1a1a]">{{ line.item_name }}</p>
                    <p class="text-[10px] font-mono text-[#777]">{{ line.kfa_code }} · {{ line.uom }}</p>
                  </td>
                  <td class="px-3 py-2.5 text-center">
                    <span :class="['font-bold', line.current_stock <= 10 ? 'text-red-600' : 'text-amber-600']">
                      {{ line.current_stock }}
                    </span>
                  </td>
                  <td class="px-3 py-2.5 text-center text-[#999]">{{ line.min_stock }}</td>
                  <td class="px-3 py-2.5 text-center font-semibold text-[#1a1a1a]">{{ line.requested_qty }}</td>
                  <td class="px-3 py-2.5 text-center">
                    <input v-if="editingNotif === notif.id" v-model.number="editQtys[line.id]"
                      type="number" min="1" :max="line.requested_qty * 2"
                      class="w-20 text-center border border-[#e5e5e5] rounded-lg px-2 py-1.5 text-xs outline-none focus:border-[#6b1525]">
                    <span v-else class="font-bold text-[#1a1a1a]">{{ line.requested_qty }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="flex items-center gap-3">
            <button v-if="editingNotif !== notif.id" @click="approveConfirmation(notif.id)"
              :disabled="actionLoading"
              class="px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
              <UIcon name="i-lucide-check" class="text-sm"/>
              {{ actionLoading ? 'Memproses...' : 'Setujui Pengiriman' }}
            </button>
            <button v-if="editingNotif !== notif.id" @click="startEdit(notif)"
              class="px-5 py-2.5 bg-white border border-amber-300 text-amber-700 text-xs font-semibold rounded-lg hover:bg-amber-50 transition-colors flex items-center gap-2">
              <UIcon name="i-lucide-edit-3" class="text-sm"/>
              Ubah Jumlah
            </button>

            <template v-if="editingNotif === notif.id">
              <button @click="approveConfirmation(notif.id)" :disabled="actionLoading"
                class="px-5 py-2.5 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
                <UIcon name="i-lucide-check" class="text-sm"/>
                {{ actionLoading ? 'Memproses...' : 'Simpan Perubahan & Setujui' }}
              </button>
              <button @click="editingNotif = null"
                class="px-4 py-2.5 text-[#999] text-xs rounded-lg hover:bg-[#ebebeb] transition-colors">
                Batal
              </button>
            </template>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
