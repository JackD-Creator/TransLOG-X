<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Notifikasi Min Stok' })

const supabase = useSupabaseClient()
const { apiPost } = useApi()
const { tenantId } = useUserRole()
const router = useRouter()

const loading = ref(true)
const notifications = ref<any[]>([])
const expandedRS = ref<string | null>(null)
const expandedNotif = ref<string | null>(null)
const actionLoading = ref<string | null>(null)

// Lookup maps for price/supplier
const priceMap = ref<Record<string, { fix_price: number; het_price: number | null; manufacturer: string | null; distributor: string | null }>>({})
const supplierMap = ref<Record<string, { sell_price: number; distributor_name: string | null; stock: number; lead_time: number }>>({})

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const { data } = await supabase
    .from('hospital_notifications')
    .select('id,notif_number,notif_date,rs_tenant_id,status,source,notes,metadata,acknowledged_at,ksm_confirmation_status,ksm_confirmed_at,rs_approved_at,hospital_notification_lines(id,kfa_code,item_name,catalog_type,uom,current_stock,min_stock,requested_qty,approved_qty,notes)')
    .eq('ksm_tenant_id', tenantId.value)
    .order('notif_date', { ascending: false })
    .limit(100)
  notifications.value = data ?? []

  // Collect all KFA codes for price lookup
  const codes = new Set<string>()
  for (const n of notifications.value) {
    for (const l of n.hospital_notification_lines ?? []) codes.add(l.kfa_code)
  }
  if (codes.size > 0) {
    const codeArr = [...codes]
    const [{ data: kfa }, { data: sup }] = await Promise.all([
      supabase.from('kfa_drugs').select('kfa_code,fix_price,het_price,manufacturer,distributor').in('kfa_code', codeArr),
      supabase.from('supplier_catalog_items').select('kfa_code,sell_price,stock_available,lead_time_days,metadata').in('kfa_code', codeArr),
    ])
    for (const d of kfa ?? []) {
      priceMap.value[d.kfa_code] = { fix_price: d.fix_price, het_price: d.het_price, manufacturer: d.manufacturer, distributor: d.distributor }
    }
    for (const s of sup ?? []) {
      supplierMap.value[s.kfa_code] = {
        sell_price: s.sell_price,
        distributor_name: s.metadata?.distributor_name ?? null,
        stock: s.stock_available ?? 0,
        lead_time: s.lead_time_days ?? 0,
      }
    }
  }

  loading.value = false
}

// Group notifications by RS
const rsGroups = computed(() => {
  const map: Record<string, { rsName: string; rsAddress: string; rsTenantId: string; notifs: any[] }> = {}
  for (const n of notifications.value) {
    const rsName = n.metadata?.rs_name ?? n.rs_tenant_id?.slice(0, 8)
    const key = rsName
    if (!map[key]) map[key] = { rsName, rsAddress: n.metadata?.rs_address ?? '', rsTenantId: n.rs_tenant_id, notifs: [] }
    map[key].notifs.push(n)
  }
  return Object.values(map)
})

function toggleRS(rsName: string) {
  expandedRS.value = expandedRS.value === rsName ? null : rsName
  expandedNotif.value = null
}
function toggleNotif(id: string) {
  expandedNotif.value = expandedNotif.value === id ? null : id
}

function urgencyBadge(u: string) {
  if (u === 'critical') return { label: 'URGENT', class: 'bg-red-100 text-red-700 animate-pulse' }
  if (u === 'high') return { label: 'Prioritas', class: 'bg-amber-100 text-amber-700' }
  return { label: 'Rutin', class: 'bg-[#f0f0f0] text-[#666]' }
}

const statusConfig: Record<string, { label: string; color: string; step: number }> = {
  pending:       { label: 'SIMRS Alert — Review KSM', color: 'bg-amber-100 text-amber-700', step: 0 },
  acknowledged:  { label: 'Cek Supplier',              color: 'bg-blue-100 text-blue-700',   step: 1 },
  po_created:    { label: 'PO Dibuat',                 color: 'bg-purple-100 text-purple-700', step: 3 },
  completed:     { label: 'Selesai',                   color: 'bg-emerald-100 text-emerald-700', step: 4 },
  cancelled:     { label: 'Dibatalkan',                color: 'bg-[#f0f0f0] text-[#999]', step: -1 },
}

function ksmConfStatus(notif: any) {
  const s = notif.ksm_confirmation_status
  if (s === 'pending_rs_approval') return { label: 'Menunggu Persetujuan RS', color: 'text-amber-600', step: 2 }
  if (s === 'rs_approved') return { label: 'RS Setuju — Siap Buat PO', color: 'text-emerald-600', step: 2 }
  return null
}

function currentStep(notif: any): number {
  if (notif.status === 'completed') return 5
  if (notif.status === 'po_created') return 4
  if (notif.ksm_confirmation_status === 'rs_approved') return 3
  if (notif.ksm_confirmation_status === 'pending_rs_approval') return 2
  if (notif.status === 'acknowledged') return 1
  return 0
}

function supplierCheckLabel(meta: any) {
  if (!meta?.supplier_check) return null
  if (meta.supplier_check === 'checking') return { label: 'Menunggu Konfirmasi Supplier', color: 'text-amber-600' }
  if (meta.supplier_check === 'confirmed') return { label: 'Supplier Konfirmasi Tersedia', color: 'text-emerald-600' }
  return null
}

// ─── Actions (semua via RPC backend) ─────────────────────────────────────────

const actionError = ref<string | null>(null)

async function reviewAndCheckSupplier(notifId: string) {
  actionLoading.value = notifId
  actionError.value = null
  try {
    await apiPost('/api/ksm/notifications', { action: 'review_check_supplier', notif_id: notifId })
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal review notifikasi'
  }
  actionLoading.value = null
}

async function simulateSupplierConfirm(notifId: string) {
  actionLoading.value = notifId
  actionError.value = null
  try {
    await apiPost('/api/ksm/notifications', { action: 'supplier_confirm', notif_id: notifId })
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal konfirmasi supplier'
  }
  actionLoading.value = null
}

async function sendConfirmationToRS(notifId: string) {
  actionLoading.value = notifId
  actionError.value = null
  try {
    await apiPost('/api/ksm/notifications', { action: 'send_confirmation_to_rs', notif_id: notifId })
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal kirim konfirmasi ke RS'
  }
  actionLoading.value = null
}

async function createAutoPO(notifId: string) {
  actionLoading.value = notifId
  actionError.value = null
  try {
    const data = await apiPost<{ po_id?: string }>('/api/ksm/notifications', { action: 'create_po', notif_id: notifId })
    await load()
    if (data?.po_id) router.push(`/dashboard/ksm/purchase-orders/${data.po_id}`)
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal membuat PO otomatis'
  }
  actionLoading.value = null
}

// Stats
const totalPending   = computed(() => notifications.value.filter(n => n.status === 'pending').length)
const totalProcess   = computed(() => notifications.value.filter(n => n.status === 'acknowledged').length)
const totalPO        = computed(() => notifications.value.filter(n => n.status === 'po_created').length)
const totalItems     = computed(() => notifications.value.reduce((s, n) => s + (n.hospital_notification_lines?.length ?? 0), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Notifikasi Min Stok RS</h1>
        <p class="text-sm text-[#999] mt-0.5">Permintaan pengadaan dari Rumah Sakit mitra — review, cek supplier, buat PO</p>
      </div>
      <button class="flex items-center gap-2 px-4 py-2 rounded-lg bg-[#6b1525] text-white text-xs font-semibold hover:bg-[#5a1120] transition-colors" @click="load">
        <UIcon name="i-lucide-refresh-cw" class="text-sm"/>
        Refresh
      </button>
    </div>

    <!-- Error Banner -->
    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="bg-amber-50 rounded-xl border border-amber-200 p-4">
        <p class="text-2xl font-bold text-amber-700">{{ totalPending }}</p>
        <p class="text-xs text-amber-600 mt-1">Menunggu Review</p>
      </div>
      <div class="bg-blue-50 rounded-xl border border-blue-200 p-4">
        <p class="text-2xl font-bold text-blue-700">{{ totalProcess }}</p>
        <p class="text-xs text-blue-600 mt-1">Sedang Proses</p>
      </div>
      <div class="bg-purple-50 rounded-xl border border-purple-200 p-4">
        <p class="text-2xl font-bold text-purple-700">{{ totalPO }}</p>
        <p class="text-xs text-purple-600 mt-1">PO Dibuat</p>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ totalItems }}</p>
        <p class="text-xs text-[#999] mt-1">Total Item Diminta</p>
      </div>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="rsGroups.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-bell-off" class="text-3xl text-[#ccc]"/>
      <p class="text-sm text-[#999]">Belum ada notifikasi min stok dari RS mitra</p>
    </div>

    <!-- RS Cards -->
    <div v-else class="space-y-4">
      <div v-for="rs in rsGroups" :key="rs.rsName" class="bg-[#faf7f3] rounded-2xl border border-[#e0d8d0] overflow-hidden shadow-sm hover:shadow-md transition-shadow">

        <!-- RS Header Card — KLIK UNTUK EXPAND -->
        <button @click="toggleRS(rs.rsName)" class="w-full text-left px-5 py-4 flex items-center justify-between hover:bg-[#f0ebe5] transition-colors cursor-pointer active:bg-[#e8e0d8]">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0"
              :class="rs.notifs.some(n => n.metadata?.urgency === 'critical') ? 'bg-red-100' :
                       rs.notifs.some(n => n.metadata?.urgency === 'high') ? 'bg-amber-100' : 'bg-blue-100'">
              <UIcon name="i-lucide-building-2"
                :class="rs.notifs.some(n => n.metadata?.urgency === 'critical') ? 'text-red-600 text-xl' :
                         rs.notifs.some(n => n.metadata?.urgency === 'high') ? 'text-amber-600 text-xl' : 'text-blue-600 text-xl'"/>
            </div>
            <div>
              <div class="flex items-center gap-2">
                <p class="font-bold text-[#1a1a1a]">{{ rs.rsName }}</p>
                <span v-for="n in rs.notifs.filter(n => n.metadata?.urgency)" :key="n.id"
                  :class="['px-1.5 py-0.5 rounded text-[9px] font-bold', urgencyBadge(n.metadata.urgency).class]">
                  {{ urgencyBadge(n.metadata.urgency).label }}
                </span>
              </div>
              <p class="text-xs text-[#999] mt-0.5">{{ rs.rsAddress }}</p>
            </div>
          </div>
          <div class="flex items-center gap-4">
            <div class="text-right">
              <p class="text-sm font-bold text-[#1a1a1a]">{{ rs.notifs.length }} notif</p>
              <p class="text-[10px] text-[#999]">
                {{ rs.notifs.reduce((s, n) => s + (n.hospital_notification_lines?.length ?? 0), 0) }} item
              </p>
            </div>
            <div class="flex gap-1">
              <span v-for="n in rs.notifs" :key="n.id"
                :class="['w-2 h-2 rounded-full', statusConfig[n.status]?.color?.split(' ')[0] ?? 'bg-[#ccc]']"/>
            </div>
            <div class="flex items-center gap-1.5">
              <span v-if="expandedRS !== rs.rsName" class="text-[9px] text-[#999]">Klik untuk detail</span>
              <UIcon :name="expandedRS === rs.rsName ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" class="text-sm text-[#999]"/>
            </div>
          </div>
        </button>

        <!-- Expanded RS — show notifications -->
        <div v-if="expandedRS === rs.rsName" class="border-t border-[#e5e5e5]">
          <div v-for="notif in rs.notifs" :key="notif.id" class="border-b border-[#ebebeb] last:border-b-0">

            <!-- Notification Header -->
            <button @click="toggleNotif(notif.id)" class="w-full text-left px-5 py-3 flex items-center justify-between hover:bg-[#f0f0f0] transition-colors">
              <div class="flex items-center gap-3">
                <p class="font-mono text-xs font-semibold text-[#6b1525]">{{ notif.notif_number }}</p>
                <span class="text-xs text-[#999]">{{ fmtDate(notif.notif_date) }}</span>
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', statusConfig[notif.status]?.color ?? 'bg-[#f0f0f0] text-[#999]']">
                  {{ statusConfig[notif.status]?.label ?? notif.status }}
                </span>
                <span v-if="supplierCheckLabel(notif.metadata)" :class="['text-[10px] font-semibold', supplierCheckLabel(notif.metadata)!.color]">
                  · {{ supplierCheckLabel(notif.metadata)!.label }}
                </span>
              </div>
              <div class="flex items-center gap-3">
                <span class="text-xs text-[#999]">{{ notif.hospital_notification_lines?.length ?? 0 }} item</span>
                <UIcon :name="expandedNotif === notif.id ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'" class="text-xs text-[#ccc]"/>
              </div>
            </button>

            <!-- Expanded Notification — item details + actions -->
            <div v-if="expandedNotif === notif.id" class="px-5 pb-4">

              <!-- Workflow Progress -->
              <div class="mb-4 flex items-center gap-1 flex-wrap">
                <template v-for="(step, i) in ['SIMRS Alert', 'KSM Review', 'Konfirmasi RS', 'PO ke Dist.', 'Selesai']" :key="step">
                  <div :class="['flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-semibold',
                    currentStep(notif) >= i ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#aaa]']">
                    <UIcon v-if="currentStep(notif) > i" name="i-lucide-check" class="text-[10px]"/>
                    <span>{{ step }}</span>
                  </div>
                  <UIcon v-if="i < 4" name="i-lucide-chevron-right" class="text-[10px] text-[#ddd]"/>
                </template>
              </div>

              <!-- Source badge -->
              <div class="mb-3 flex items-center gap-2">
                <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-blue-100 text-blue-700">
                  Sumber: {{ notif.source === 'simrs' ? 'SIMRS Otomatis' : 'Manual' }}
                </span>
                <span v-if="ksmConfStatus(notif)" :class="['text-[10px] font-semibold', ksmConfStatus(notif)!.color]">
                  · {{ ksmConfStatus(notif)!.label }}
                </span>
              </div>

              <p v-if="notif.notes" class="text-xs text-[#666] mb-3 italic">{{ notif.notes }}</p>

              <!-- Item Table -->
              <div class="bg-white rounded-xl border border-[#e5e5e5] overflow-hidden mb-4">
                <table class="w-full text-xs">
                  <thead class="bg-[#fafafa] border-b border-[#e5e5e5]">
                    <tr class="text-left">
                      <th class="px-3 py-2.5 font-semibold text-[#999]">Item / KFA</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-center">Stok RS</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-center">Min</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-center">Request</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-right">HAP</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999]">Supplier</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-center">Stok Dist.</th>
                      <th class="px-3 py-2.5 font-semibold text-[#999] text-right">Est. Total</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-[#f0f0f0]">
                    <tr v-for="line in notif.hospital_notification_lines" :key="line.id" class="hover:bg-[#fafafa] transition-colors">
                      <td class="px-3 py-2.5">
                        <p class="font-semibold text-[#1a1a1a]">{{ line.item_name }}</p>
                        <p class="text-[10px] font-mono text-[#aaa]">{{ line.kfa_code }} · {{ line.uom }}</p>
                      </td>
                      <td class="px-3 py-2.5 text-center">
                        <span :class="['font-bold', line.current_stock <= 10 ? 'text-red-600' : line.current_stock <= 30 ? 'text-amber-600' : 'text-[#666]']">
                          {{ line.current_stock }}
                        </span>
                      </td>
                      <td class="px-3 py-2.5 text-center text-[#999]">{{ line.min_stock }}</td>
                      <td class="px-3 py-2.5 text-center font-bold text-[#1a1a1a]">{{ line.requested_qty }}</td>
                      <td class="px-3 py-2.5 text-right">
                        <span v-if="priceMap[line.kfa_code]?.fix_price" class="font-semibold text-[#1a1a1a]">
                          {{ fmtRp(priceMap[line.kfa_code].fix_price) }}
                        </span>
                        <span v-else class="text-[#ccc]">-</span>
                      </td>
                      <td class="px-3 py-2.5">
                        <p v-if="supplierMap[line.kfa_code]?.distributor_name" class="text-[#555]">
                          {{ supplierMap[line.kfa_code].distributor_name }}
                        </p>
                        <p v-else-if="priceMap[line.kfa_code]?.distributor" class="text-[#888]">
                          {{ priceMap[line.kfa_code].distributor }}
                        </p>
                        <span v-else class="text-[#ccc]">-</span>
                      </td>
                      <td class="px-3 py-2.5 text-center">
                        <span v-if="supplierMap[line.kfa_code]" :class="['font-semibold',
                          supplierMap[line.kfa_code].stock >= line.requested_qty ? 'text-emerald-600' : 'text-red-500']">
                          {{ supplierMap[line.kfa_code].stock }}
                        </span>
                        <span v-else class="text-[#ccc]">-</span>
                      </td>
                      <td class="px-3 py-2.5 text-right font-semibold text-[#1a1a1a]">
                        {{ fmtRp((supplierMap[line.kfa_code]?.sell_price ?? priceMap[line.kfa_code]?.fix_price ?? 0) * line.requested_qty) }}
                      </td>
                    </tr>
                  </tbody>
                  <tfoot class="bg-[#fafafa] border-t border-[#e5e5e5]">
                    <tr>
                      <td colspan="7" class="px-3 py-2.5 text-xs font-bold text-right text-[#666]">Estimasi Total PO</td>
                      <td class="px-3 py-2.5 text-right text-sm font-bold text-[#6b1525]">
                        {{ fmtRp(
                          (notif.hospital_notification_lines ?? []).reduce((s: number, l: any) =>
                            s + (supplierMap[l.kfa_code]?.sell_price ?? priceMap[l.kfa_code]?.fix_price ?? 0) * l.requested_qty, 0)
                        ) }}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>

              <!-- Action Buttons -->
              <div class="flex items-center gap-2 flex-wrap">
                <!-- Step 1: Review & Cek Supplier -->
                <button v-if="notif.status === 'pending'" @click="reviewAndCheckSupplier(notif.id)"
                  :disabled="actionLoading === notif.id"
                  class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2">
                  <UIcon name="i-lucide-search" class="text-sm"/>
                  {{ actionLoading === notif.id ? 'Memproses...' : 'Review & Cek Ketersediaan Supplier' }}
                </button>

                <!-- Step 2: Waiting for supplier — simulate confirm -->
                <template v-if="notif.status === 'acknowledged' && notif.metadata?.supplier_check === 'checking'">
                  <div class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700">
                    <UIcon name="i-lucide-clock" class="text-sm animate-pulse"/>
                    Menunggu konfirmasi ketersediaan dari Supplier...
                  </div>
                  <button @click="simulateSupplierConfirm(notif.id)"
                    :disabled="actionLoading === notif.id"
                    class="px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-lg hover:bg-emerald-700 disabled:opacity-50 transition-colors flex items-center gap-2">
                    <UIcon name="i-lucide-check-circle" class="text-sm"/>
                    Supplier Konfirmasi Tersedia
                  </button>
                </template>

                <!-- Step 3: Supplier confirmed — Kirim Konfirmasi ke RS -->
                <template v-if="notif.status === 'acknowledged' && notif.metadata?.supplier_check === 'confirmed' && !notif.ksm_confirmation_status">
                  <div class="flex items-center gap-2 px-3 py-2 bg-emerald-50 border border-emerald-200 rounded-lg text-xs text-emerald-700">
                    <UIcon name="i-lucide-check-circle" class="text-sm"/>
                    Supplier konfirmasi semua item tersedia
                  </div>
                  <button @click="sendConfirmationToRS(notif.id)"
                    :disabled="actionLoading === notif.id"
                    class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2">
                    <UIcon name="i-lucide-send" class="text-sm"/>
                    {{ actionLoading === notif.id ? 'Mengirim...' : 'Kirim Konfirmasi Pengiriman ke RS' }}
                  </button>
                </template>

                <!-- Step 3b: Menunggu persetujuan RS -->
                <template v-if="notif.ksm_confirmation_status === 'pending_rs_approval'">
                  <div class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700">
                    <UIcon name="i-lucide-clock" class="text-sm animate-pulse"/>
                    Konfirmasi terkirim — menunggu persetujuan RS...
                  </div>
                </template>

                <!-- Step 4: RS approved — Buat PO -->
                <template v-if="notif.ksm_confirmation_status === 'rs_approved' && notif.status === 'acknowledged'">
                  <div class="flex items-center gap-2 px-3 py-2 bg-emerald-50 border border-emerald-200 rounded-lg text-xs text-emerald-700">
                    <UIcon name="i-lucide-check-circle-2" class="text-sm"/>
                    RS menyetujui pengiriman — siap buat PO ke Distributor
                  </div>
                  <button @click="createAutoPO(notif.id)"
                    :disabled="actionLoading === notif.id"
                    class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2">
                    <UIcon name="i-lucide-file-plus" class="text-sm"/>
                    {{ actionLoading === notif.id ? 'Membuat PO...' : 'Buat PO Otomatis ke Distributor' }}
                  </button>
                </template>

                <!-- Step 4: PO Created — link to PO -->
                <template v-if="notif.status === 'po_created'">
                  <div class="flex items-center gap-2 px-3 py-2 bg-purple-50 border border-purple-200 rounded-lg text-xs text-purple-700">
                    <UIcon name="i-lucide-file-check" class="text-sm"/>
                    PO {{ notif.metadata?.po_number ?? '' }} sudah dibuat & dikirim ke Supplier
                  </div>
                  <NuxtLink v-if="notif.metadata?.po_id" :to="`/dashboard/ksm/purchase-orders/${notif.metadata.po_id}`"
                    class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] transition-colors flex items-center gap-2">
                    <UIcon name="i-lucide-external-link" class="text-sm"/>
                    Lihat Detail PO
                  </NuxtLink>
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
