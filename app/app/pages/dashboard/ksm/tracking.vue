<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Tracking Pengiriman' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const loading = ref(true)
const orders = ref<any[]>([])
const filterStatus = ref('active')

async function load() {
  if (!tenantId.value) return
  loading.value = true
  let query = supabase
    .from('ksm_purchase_orders')
    .select('id,po_number,po_date,expected_delivery,status,total_amount,payment_terms,metadata,ksm_po_lines(id,item_name,kfa_code,uom,ordered_qty,received_qty)')
    .eq('ksm_tenant_id', tenantId.value)
    .order('po_date', { ascending: false })
    .limit(100)

  if (filterStatus.value === 'active') {
    query = query.in('status', ['submitted', 'approved', 'sent_to_supplier', 'partially_received'])
  } else if (filterStatus.value === 'selesai') {
    query = query.eq('status', 'fully_received')
  }

  const { data } = await query
  orders.value = data ?? []
  loading.value = false
}


const statusConfig: Record<string, { label: string; color: string; icon: string; desc: string }> = {
  submitted:          { label: 'Menunggu Konfirmasi Dist.', color: 'bg-blue-100 text-blue-700',    icon: 'i-lucide-clock',           desc: 'PO sudah dikirim, menunggu distributor konfirmasi' },
  approved:           { label: 'Dikonfirmasi Distributor',  color: 'bg-purple-100 text-purple-700', icon: 'i-lucide-check-circle',    desc: 'Distributor sedang menyiapkan pesanan' },
  sent_to_supplier:   { label: 'Dalam Pengiriman ke RS',   color: 'bg-amber-100 text-amber-700',   icon: 'i-lucide-truck',           desc: 'Distributor sudah kirim langsung ke RS' },
  partially_received: { label: 'RS Terima Sebagian',       color: 'bg-orange-100 text-orange-700',  icon: 'i-lucide-package-open',    desc: 'RS sudah terima sebagian barang' },
  fully_received:     { label: 'RS Terima Lengkap',        color: 'bg-emerald-100 text-emerald-700',icon: 'i-lucide-package-check',   desc: 'RS konfirmasi semua barang diterima' },
  draft:              { label: 'Draft',                     color: 'bg-[#f0f0f0] text-[#999]',      icon: 'i-lucide-file-edit',       desc: 'Belum diajukan' },
}

function itemProgress(po: any) {
  const lines = po.ksm_po_lines ?? []
  const totalOrdered  = lines.reduce((s: number, l: any) => s + (l.ordered_qty ?? 0), 0)
  const totalReceived = lines.reduce((s: number, l: any) => s + (l.received_qty ?? 0), 0)
  return { totalOrdered, totalReceived, pct: totalOrdered > 0 ? Math.round(totalReceived / totalOrdered * 100) : 0 }
}

// Statistik
const activeCount   = computed(() => orders.value.filter(o => ['submitted','approved','sent_to_supplier','partially_received'].includes(o.status)).length)
const inTransit     = computed(() => orders.value.filter(o => o.status === 'sent_to_supplier').length)
const waitConfirm   = computed(() => orders.value.filter(o => o.status === 'submitted').length)
const overdueCount  = computed(() => orders.value.filter(o => o.status !== 'fully_received' && isOverdue(o.expected_delivery)).length)

watch(tenantId, (id) => { if (id) load() })
watch(filterStatus, load)
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Tracking Pengiriman</h1>
      <p class="text-sm text-[#999] mt-0.5">Lacak pengiriman barang dari Distributor langsung ke RS atas pesanan KSM</p>
    </div>

    <!-- Stat Cards — clickable filter -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <button @click="filterStatus = filterStatus === 'active' ? 'all' : 'active'"
        :class="['rounded-xl border p-4 text-left cursor-pointer transition-all hover:shadow-sm',
          filterStatus === 'active' ? 'border-[#6b1525] ring-1 ring-[#6b1525]/20 bg-[#faf7f3]' : 'bg-[#faf7f3] border-[#e0d8d0]']">
        <p class="text-[10px] text-[#999] uppercase mb-1">PO Aktif</p>
        <p class="text-2xl font-bold text-[#1a1a1a]">{{ activeCount }}</p>
        <p class="text-[10px] text-[#777] mt-1">Sedang diproses</p>
      </button>
      <button @click="filterStatus = filterStatus === 'active' ? 'all' : 'active'"
        :class="['rounded-xl border p-4 text-left cursor-pointer transition-all hover:shadow-sm',
          filterStatus === 'active' ? 'border-amber-400 ring-1 ring-amber-300 bg-amber-50' : 'bg-amber-50 border-amber-200']">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Dalam Pengiriman</p>
        <p class="text-2xl font-bold text-amber-700">{{ inTransit }}</p>
        <p class="text-[10px] text-amber-500 mt-1">Dist. → RS</p>
      </button>
      <button @click="filterStatus = filterStatus === 'active' ? 'all' : 'active'"
        :class="['rounded-xl border p-4 text-left cursor-pointer transition-all hover:shadow-sm',
          'bg-blue-50 border-blue-200']">
        <p class="text-[10px] text-blue-500 uppercase mb-1">Tunggu Konfirmasi</p>
        <p class="text-2xl font-bold text-blue-700">{{ waitConfirm }}</p>
        <p class="text-[10px] text-blue-500 mt-1">Belum dikonfirmasi Dist.</p>
      </button>
      <button @click="filterStatus = filterStatus === 'active' ? 'all' : 'active'"
        :class="['rounded-xl border p-4 text-left cursor-pointer transition-all hover:shadow-sm',
          overdueCount > 0 ? 'bg-red-50 border-red-200' : 'bg-emerald-50 border-emerald-200']">
        <p :class="['text-[10px] uppercase mb-1', overdueCount > 0 ? 'text-red-500' : 'text-emerald-500']">Terlambat</p>
        <p :class="['text-2xl font-bold', overdueCount > 0 ? 'text-red-600' : 'text-emerald-700']">{{ overdueCount }}</p>
        <p :class="['text-[10px] mt-1', overdueCount > 0 ? 'text-red-500' : 'text-emerald-500']">
          {{ overdueCount > 0 ? 'Lewat estimasi' : 'Semua on schedule' }}
        </p>
      </button>
    </div>

    <!-- Filter -->
    <div class="flex items-center gap-2">
      <button v-for="f in [
        { key: 'active', label: 'Aktif' },
        { key: 'selesai', label: 'Sudah Diterima RS' },
        { key: 'all', label: 'Semua' },
      ]" :key="f.key" @click="filterStatus = f.key"
        :class="['px-4 py-2 rounded-lg text-xs font-semibold transition-colors',
          filterStatus === f.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ f.label }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="orders.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-truck" class="text-3xl text-[#999]"/>
      <p class="text-sm text-[#999]">
        {{ filterStatus === 'active' ? 'Tidak ada pengiriman aktif' : filterStatus === 'selesai' ? 'Belum ada PO yang selesai diterima RS' : 'Tidak ada data PO' }}
      </p>
    </div>

    <!-- PO Tracking Cards -->
    <div v-else class="space-y-3">
      <NuxtLink v-for="po in orders" :key="po.id"
        :to="`/dashboard/ksm/purchase-orders/${po.id}`"
        class="block bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden hover:border-[#6b1525]/30 transition-colors group">

        <div class="px-5 py-4 flex items-start justify-between">
          <div class="flex items-start gap-4">
            <!-- Status Icon -->
            <div :class="['w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0',
              statusConfig[po.status]?.color ?? 'bg-[#f0f0f0] text-[#999]']">
              <UIcon :name="statusConfig[po.status]?.icon ?? 'i-lucide-file'" class="text-lg"/>
            </div>
            <div>
              <div class="flex items-center gap-2 mb-0.5">
                <p class="text-sm font-bold text-[#1a1a1a] font-mono group-hover:text-[#6b1525] transition-colors">
                  {{ po.po_number }}
                </p>
                <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold', statusConfig[po.status]?.color ?? 'bg-[#f0f0f0] text-[#999]']">
                  {{ statusConfig[po.status]?.label ?? po.status }}
                </span>
              </div>
              <p class="text-xs text-[#999]">{{ statusConfig[po.status]?.desc ?? '' }}</p>

              <!-- Alur: Distributor → RS -->
              <div class="flex items-center gap-2 mt-2 text-xs">
                <span class="font-semibold text-[#666]">{{ po.metadata?.supplier_name ?? 'Distributor' }}</span>
                <UIcon name="i-lucide-arrow-right" class="text-[10px] text-[#999]"/>
                <span class="font-semibold text-[#1a1a1a]">{{ po.metadata?.rs_name ?? 'RS Tujuan' }}</span>
              </div>

              <!-- Tracking info -->
              <div v-if="po.metadata?.tracking_number" class="mt-2 flex items-center gap-2">
                <UIcon name="i-lucide-map-pin" class="text-xs text-amber-500"/>
                <span class="text-[10px] text-amber-700 font-mono font-semibold">
                  Resi: {{ po.metadata.tracking_number }}
                </span>
                <span v-if="po.metadata?.courier" class="text-[10px] text-[#999]">· {{ po.metadata.courier }}</span>
              </div>
            </div>
          </div>

          <div class="text-right flex-shrink-0">
            <p class="text-sm font-bold text-[#1a1a1a]">{{ fmtRp(po.total_amount) }}</p>
            <div :class="['text-xs mt-1', isOverdue(po.expected_delivery) && po.status !== 'fully_received' ? 'text-red-600 font-semibold' : 'text-[#999]']">
              <span v-if="po.status === 'fully_received'">Diterima RS</span>
              <span v-else-if="isOverdue(po.expected_delivery)">
                Terlambat {{ Math.abs(daysDiff(po.expected_delivery)) }} hari
              </span>
              <span v-else-if="po.expected_delivery">
                ETA {{ fmtDate(po.expected_delivery) }}
                <span class="text-[#888]">({{ daysDiff(po.expected_delivery) }}h)</span>
              </span>
              <span v-else>-</span>
            </div>
          </div>
        </div>

        <!-- Item progress bar -->
        <div v-if="['sent_to_supplier','partially_received','fully_received'].includes(po.status)" class="px-5 pb-4">
          <div class="flex items-center gap-3">
            <div class="flex-1 bg-[#e5e5e5] rounded-full h-1.5">
              <div :class="['h-1.5 rounded-full transition-all',
                itemProgress(po).pct === 100 ? 'bg-emerald-500' :
                itemProgress(po).pct > 0 ? 'bg-amber-500' : 'bg-[#ccc]']"
                :style="`width: ${itemProgress(po).pct}%`"/>
            </div>
            <p class="text-[10px] text-[#999] flex-shrink-0">
              <span :class="itemProgress(po).pct === 100 ? 'text-emerald-600 font-semibold' : ''">
                RS terima {{ itemProgress(po).totalReceived }}/{{ itemProgress(po).totalOrdered }} item
              </span>
            </p>
          </div>

          <!-- Item detail mini -->
          <div v-if="po.status === 'partially_received'" class="mt-2 flex flex-wrap gap-1.5">
            <span v-for="line in (po.ksm_po_lines ?? [])" :key="line.id"
              :class="['px-2 py-0.5 rounded text-[10px] font-medium',
                (line.received_qty ?? 0) >= line.ordered_qty ? 'bg-emerald-100 text-emerald-700' :
                (line.received_qty ?? 0) > 0 ? 'bg-amber-100 text-amber-700' :
                'bg-[#f0f0f0] text-[#999]']">
              {{ line.item_name?.split(' ').slice(0,3).join(' ') }}
              {{ line.received_qty ?? 0 }}/{{ line.ordered_qty }}
            </span>
          </div>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
