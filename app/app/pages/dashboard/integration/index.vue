<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const activeTab = ref('systems')

const tabs = [
  { key: 'systems',  label: 'Sistem Terhubung', icon: 'i-lucide-plug' },
  { key: 'api',      label: 'API & Webhook',    icon: 'i-lucide-code-2' },
  { key: 'logs',     label: 'Sync Logs',        icon: 'i-lucide-scroll-text' },
]

const systems = [
  {
    nama: 'SATUSEHAT Platform',
    provider: 'Kemenkes RI',
    jenis: 'Government',
    icon: 'i-lucide-shield',
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
    status: 'connected',
    last_sync: '2026-06-22 09:00',
    desc: 'Pelaporan data kesehatan ke platform nasional Kemenkes. Event-based via FHIR R4.',
  },
  {
    nama: 'BPJS Kesehatan',
    provider: 'BPJS Kesehatan',
    jenis: 'Insurance',
    icon: 'i-lucide-heart-pulse',
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    status: 'connected',
    last_sync: '2026-06-22 08:30',
    desc: 'Bridging klaim rawat inap & rawat jalan. Validasi koding ICD-10, SEP, dan pengiriman klaim.',
  },
  {
    nama: 'Sistem Informasi RS (HIS)',
    provider: 'Internal',
    jenis: 'HIS',
    icon: 'i-lucide-building-2',
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    status: 'connected',
    last_sync: '2026-06-22 09:10',
    desc: 'Integrasi dua arah dengan HIS/EMR untuk data ADT, order obat & pemeriksaan.',
  },
  {
    nama: 'e-Catalogue LKPP',
    provider: 'LKPP RI',
    jenis: 'Government',
    icon: 'i-lucide-shopping-cart',
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    status: 'connected',
    last_sync: '2026-06-21 23:00',
    desc: 'Sinkronisasi harga & katalog produk dari e-Catalogue LKPP untuk referensi pengadaan.',
  },
  {
    nama: 'Supplier EDI',
    provider: 'Multi-supplier',
    jenis: 'B2B',
    icon: 'i-lucide-truck',
    color: 'text-[#666]',
    bg: 'bg-[#f0f0f0]',
    status: 'partial',
    last_sync: '2026-06-22 07:45',
    desc: 'Pertukaran data elektronik (PO, Invoice, ASN) langsung dengan supplier terhubung.',
  },
  {
    nama: 'Akuntansi / ERP',
    provider: 'Oracle / SAP',
    jenis: 'ERP',
    icon: 'i-lucide-calculator',
    color: 'text-[#999]',
    bg: 'bg-[#f0f0f0]',
    status: 'planned',
    last_sync: '—',
    desc: 'Export jurnal akuntansi, AP, AR ke sistem ERP keuangan RS. Dijadwalkan Q4 2026.',
  },
]

const apiEndpoints = [
  { method: 'GET',    path: '/api/v1/inventory/items',          desc: 'List semua SKU dengan filter & pagination', auth: 'Bearer' },
  { method: 'POST',   path: '/api/v1/procurement/purchase-requests', desc: 'Buat PR baru', auth: 'Bearer' },
  { method: 'GET',    path: '/api/v1/orders/distributions',     desc: 'List distribusi internal & eksternal', auth: 'Bearer' },
  { method: 'POST',   path: '/api/v1/warehouse/grn',            desc: 'Input penerimaan barang (GRN)', auth: 'Bearer' },
  { method: 'GET',    path: '/api/v1/financial/invoices',       desc: 'List invoice & status pembayaran', auth: 'Bearer' },
  { method: 'POST',   path: '/webhooks/satusehat',              desc: 'Terima event dari SATUSEHAT Platform', auth: 'HMAC-SHA256' },
  { method: 'POST',   path: '/webhooks/bpjs',                   desc: 'Callback status klaim BPJS', auth: 'Basic' },
]

const syncLogs = ref([
  { waktu: '2026-06-22 09:10:05', sistem: 'HIS (ADT)',       event: 'Patient Discharge', status: 'success', records: 1,  durasi: '120ms' },
  { waktu: '2026-06-22 09:00:22', sistem: 'SATUSEHAT',       event: 'Medication Record', status: 'success', records: 14, durasi: '890ms' },
  { waktu: '2026-06-22 08:30:10', sistem: 'BPJS Bridging',   event: 'SEP Validation',   status: 'success', records: 3,  durasi: '2.1s' },
  { waktu: '2026-06-22 07:45:33', sistem: 'Supplier EDI',    event: 'ASN Received',      status: 'success', records: 28, durasi: '340ms' },
  { waktu: '2026-06-22 06:30:05', sistem: 'SATUSEHAT',       event: 'IHR Daily Report',  status: 'warning', records: 0,  durasi: '—' },
  { waktu: '2026-06-21 23:00:44', sistem: 'e-Cat LKPP',      event: 'Price Sync',        status: 'success', records: 312,durasi: '5.4s' },
  { waktu: '2026-06-21 22:15:08', sistem: 'BPJS Bridging',   event: 'Claim Submit',      status: 'error',   records: 0,  durasi: '—' },
])

const methodColor = (m: string) => {
  const c: Record<string, string> = {
    GET:  'bg-blue-100 text-blue-700',
    POST: 'bg-emerald-100 text-emerald-700',
    PUT:  'bg-amber-100 text-amber-700',
    DELETE:'bg-red-100 text-red-700',
  }
  return c[m] ?? 'bg-[#f0f0f0] text-[#666]'
}

const statusBadge = (s: string) => {
  const c: Record<string, string> = {
    connected: 'bg-emerald-100 text-emerald-700',
    partial:   'bg-amber-100 text-amber-700',
    planned:   'bg-[#f0f0f0] text-[#999]',
    error:     'bg-red-100 text-red-600',
  }
  return c[s] ?? 'bg-[#f0f0f0] text-[#666]'
}

const syncStatusIcon = (s: string) => ({
  success: { icon: 'i-lucide-check-circle', color: 'text-emerald-500' },
  warning: { icon: 'i-lucide-alert-triangle', color: 'text-amber-500' },
  error:   { icon: 'i-lucide-x-circle', color: 'text-red-500' },
}[s] ?? { icon: 'i-lucide-circle', color: 'text-[#999]' })

const connectedCount = computed(() => systems.filter(s => s.status === 'connected').length)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Integrasi & Platform API</h1>
        <p class="text-sm text-[#999] mt-0.5">Koneksi sistem eksternal, API endpoints & sync monitoring</p>
      </div>
      <span class="px-3 py-1.5 bg-emerald-100 border border-emerald-200 rounded-xl text-sm font-bold text-emerald-700">
        {{ connectedCount }} sistem aktif
      </span>
    </div>

    <!-- Summary -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in [
        { label: 'Sistem Terhubung', value: String(connectedCount), icon: 'i-lucide-plug', color: 'text-emerald-600', bg: 'bg-emerald-50' },
        { label: 'API Endpoints',   value: String(apiEndpoints.length), icon: 'i-lucide-code-2', color: 'text-blue-600', bg: 'bg-blue-50' },
        { label: 'Sync Hari Ini',   value: '38',  icon: 'i-lucide-refresh-cw', color: 'text-purple-600', bg: 'bg-purple-50' },
        { label: 'Error',           value: '1',   icon: 'i-lucide-alert-circle', color: 'text-red-600', bg: 'bg-red-50' },
      ]" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>

    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="flex border-b border-[#e5e5e5]">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab===tab.key?'border-[#6b1525] text-[#6b1525]':'border-transparent text-[#999] hover:text-[#666]'"
          @click="activeTab=tab.key">
          <UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}
        </button>
      </div>

      <!-- Sistem Terhubung -->
      <div v-if="activeTab==='systems'" class="p-5 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="sys in systems" :key="sys.nama"
          class="border border-[#e5e5e5] rounded-xl p-4 hover:border-red-300 transition-colors"
          :class="sys.status==='planned'?'opacity-60':''">
          <div class="flex items-start justify-between mb-3">
            <div :class="[sys.bg,'w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0']">
              <UIcon :name="sys.icon" :class="[sys.color,'text-lg']"/>
            </div>
            <span :class="['px-2 py-0.5 rounded-full text-xs font-medium', statusBadge(sys.status)]">
              {{ sys.status === 'connected' ? 'Terhubung' : sys.status === 'partial' ? 'Parsial' : 'Direncanakan' }}
            </span>
          </div>
          <p class="text-sm font-bold text-[#1a1a1a]">{{ sys.nama }}</p>
          <p class="text-xs text-[#999]">{{ sys.provider }} · {{ sys.jenis }}</p>
          <p class="text-xs text-[#999] mt-2 leading-relaxed">{{ sys.desc }}</p>
          <div class="mt-3 pt-3 border-t border-[#e5e5e5] flex items-center justify-between">
            <span class="text-[10px] text-[#999] uppercase tracking-wide font-semibold">Last Sync</span>
            <span class="text-xs text-[#999] font-mono">{{ sys.last_sync }}</span>
          </div>
        </div>
      </div>

      <!-- API Endpoints -->
      <div v-if="activeTab==='api'" class="overflow-x-auto">
        <div class="px-5 py-3 border-b border-[#e5e5e5] flex items-center justify-between">
          <p class="text-xs text-[#999]">Base URL: <span class="font-mono text-[#666]">https://api.translogx.id</span></p>
          <UButton icon="i-lucide-book-open" color="neutral" variant="outline" size="xs">API Docs</UButton>
        </div>
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Method</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Endpoint</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Deskripsi</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Auth</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="ep in apiEndpoints" :key="ep.path" class="hover:bg-[#eee] transition-colors">
              <td class="px-4 py-3">
                <span :class="['px-2 py-0.5 rounded text-xs font-bold font-mono', methodColor(ep.method)]">{{ ep.method }}</span>
              </td>
              <td class="px-4 py-3 font-mono text-xs text-[#666]">{{ ep.path }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ ep.desc }}</td>
              <td class="px-4 py-3 text-xs font-mono text-[#999]">{{ ep.auth }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Sync Logs -->
      <div v-if="activeTab==='logs'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Waktu</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Sistem</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Event</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Records</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Durasi</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="log in syncLogs" :key="log.waktu+log.sistem" class="hover:bg-[#eee] transition-colors">
              <td class="px-4 py-3 font-mono text-xs text-[#999] whitespace-nowrap">{{ log.waktu }}</td>
              <td class="px-4 py-3 text-xs font-medium text-[#666]">{{ log.sistem }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ log.event }}</td>
              <td class="px-4 py-3">
                <div class="flex items-center gap-1.5">
                  <UIcon :name="syncStatusIcon(log.status).icon" :class="['text-sm', syncStatusIcon(log.status).color]"/>
                  <span class="text-xs font-medium" :class="syncStatusIcon(log.status).color">{{ log.status }}</span>
                </div>
              </td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ log.records > 0 ? log.records : '—' }}</td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ log.durasi }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
