<script setup lang="ts">
definePageMeta({ layout: 'dashboard', title: 'Invoice ke RS' })

const supabase = useSupabaseClient()
const { apiPost } = useApi()
const { tenantId } = useUserRole()

const loading = ref(true)
const allInvoices = ref<any[]>([])
const filterStatus = ref('all')
const actionLoading = ref<string | null>(null)
const actionError = ref<string | null>(null)
// Bunga shortfall akrual 50% KSM per invoice_id
const interestByInvoice = ref<Record<string, number>>({})

async function load() {
  if (!tenantId.value) return
  loading.value = true
  const [{ data }, { data: diaData }] = await Promise.all([
    supabase
      .from('ksm_invoices')
      .select('id,invoice_number,invoice_date,due_date,subtotal,tax_amount,total_amount,paid_amount,outstanding,status,bpjs_amount,bpjs_received_date,bpjs_expected_date,shortfall_amount,shortfall_covered_by_bank,contract_payment_days,reviewed_at,sent_to_rs_at,metadata,po_id')
      .eq('ksm_tenant_id', tenantId.value)
      .order('invoice_date', { ascending: false })
      .limit(200),
    // Bunga shortfall harian — sum ksm_share per invoice
    supabase
      .from('daily_interest_accruals')
      .select('invoice_id,ksm_share')
      .eq('ksm_invoices.ksm_tenant_id', tenantId.value),
  ])
  allInvoices.value = data ?? []
  // Aggregate ksm_share per invoice_id
  const map: Record<string, number> = {}
  for (const d of diaData ?? []) {
    if (d.invoice_id) map[d.invoice_id] = (map[d.invoice_id] ?? 0) + Number(d.ksm_share ?? 0)
  }
  interestByInvoice.value = map
  loading.value = false
}

const invoices = computed(() => {
  if (filterStatus.value === 'shortfall') return allInvoices.value.filter(i => i.shortfall_covered_by_bank)
  if (filterStatus.value !== 'all') return allInvoices.value.filter(i => i.status === filterStatus.value)
  return allInvoices.value
})

async function reviewAndSend(invoiceId: string) {
  actionLoading.value = invoiceId
  actionError.value = null
  try {
    await apiPost('/api/ksm/invoices', { action: 'review_and_send', invoice_id: invoiceId })
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal kirim invoice'
  }
  actionLoading.value = null
}

async function disputeInvoice(invoiceId: string) {
  const reason = prompt('Alasan dispute / catatan koreksi:')
  if (!reason) return
  actionLoading.value = invoiceId
  actionError.value = null
  try {
    const { error } = await supabase.from('ksm_invoices').update({
      status: 'disputed',
      notes: reason,
    }).eq('id', invoiceId)
    if (error) throw error
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal dispute'
  }
  actionLoading.value = null
}

async function deleteInvoice(invoiceId: string) {
  if (!confirm('Hapus invoice draft ini? Tindakan tidak bisa dibatalkan.')) return
  actionLoading.value = invoiceId
  try {
    const { error } = await supabase.from('ksm_invoices').delete().eq('id', invoiceId).eq('status', 'draft')
    if (error) throw error
    await load()
  } catch (e: any) {
    actionError.value = e.message ?? 'Gagal hapus'
  }
  actionLoading.value = null
}

const statusConfig: Record<string, { label: string; color: string }> = {
  draft:           { label: 'Auto-Generated',     color: 'bg-[#f0f0f0] text-[#999]' },
  reviewed:        { label: 'Sudah Direview',      color: 'bg-blue-100 text-blue-700' },
  sent_to_rs:      { label: 'Terkirim ke RS',     color: 'bg-purple-100 text-purple-700' },
  acknowledged_rs: { label: 'RS Acknowledge',      color: 'bg-blue-100 text-blue-700' },
  payment_pending: { label: 'Tunggu Pembayaran',  color: 'bg-amber-100 text-amber-700' },
  partially_paid:  { label: 'Dibayar Sebagian',   color: 'bg-orange-100 text-orange-700' }, // override ke Lunas jika shortfall_covered_by_bank
  paid:            { label: 'Lunas',              color: 'bg-emerald-100 text-emerald-700' },
  overdue:         { label: 'Jatuh Tempo',        color: 'bg-red-100 text-red-700' },
  disputed:        { label: 'Dispute',            color: 'bg-red-200 text-red-800' },
}

const today = new Date().toISOString().slice(0, 10)

// Stats selalu dari allInvoices, tidak terpengaruh filter
const totalDraft = computed(() => allInvoices.value.filter(i => i.status === 'draft').length)
const totalSent = computed(() => allInvoices.value.filter(i => i.status === 'sent_to_rs').length)
const totalOutstanding = computed(() => allInvoices.value.filter(i => i.status !== 'paid').reduce((s, i) => s + Number(i.outstanding ?? 0), 0))
const totalPaid = computed(() => allInvoices.value.filter(i => i.status === 'paid').reduce((s, i) => s + Number(i.total_amount), 0))
const totalShortfall = computed(() => allInvoices.value.filter(i => i.shortfall_covered_by_bank).reduce((s, i) => s + Number(i.shortfall_amount), 0))

watch(tenantId, (id) => { if (id) load() })
onMounted(() => { if (tenantId.value) load() })
</script>

<template>
  <div class="space-y-5">
    <div>
      <h1 class="text-xl font-bold text-[#1a1a1a]">Invoice ke RS</h1>
      <p class="text-sm text-[#999] mt-0.5">Invoice otomatis terbit H+1 setelah barang diterima RS — review kesesuaian lalu kirim</p>
    </div>

    <div v-if="actionError" class="px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2">
      <UIcon name="i-lucide-alert-circle" class="text-red-500 text-sm mt-0.5 flex-shrink-0"/>
      <p class="text-xs text-red-700 flex-1">{{ actionError }}</p>
      <button @click="actionError = null" class="text-red-300 hover:text-red-500"><UIcon name="i-lucide-x" class="text-xs"/></button>
    </div>

    <!-- KPI — clickable filter -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
      <button @click="filterStatus = filterStatus === 'draft' ? 'all' : 'draft'"
        :class="['text-left rounded-xl border p-4 cursor-pointer hover:shadow-sm transition-all',
          filterStatus === 'draft' ? 'bg-amber-100 border-amber-400 ring-1 ring-amber-300' : 'bg-amber-50 border-amber-200']">
        <p class="text-[10px] text-amber-500 uppercase mb-1">Perlu Review</p>
        <p class="text-2xl font-bold text-amber-700">{{ totalDraft }}</p>
      </button>
      <button @click="filterStatus = filterStatus === 'sent_to_rs' ? 'all' : 'sent_to_rs'"
        :class="['text-left rounded-xl border p-4 cursor-pointer hover:shadow-sm transition-all',
          filterStatus === 'sent_to_rs' ? 'bg-purple-100 border-purple-400 ring-1 ring-purple-300' : 'bg-purple-50 border-purple-200']">
        <p class="text-[10px] text-purple-500 uppercase mb-1">Terkirim ke RS</p>
        <p class="text-2xl font-bold text-purple-700">{{ totalSent }}</p>
      </button>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4">
        <p class="text-[10px] text-[#999] uppercase mb-1">Outstanding</p>
        <p class="text-xl font-bold text-[#1a1a1a]">{{ fmtRp(totalOutstanding) }}</p>
      </div>
      <button @click="filterStatus = filterStatus === 'paid' ? 'all' : 'paid'"
        :class="['text-left rounded-xl border p-4 cursor-pointer hover:shadow-sm transition-all',
          filterStatus === 'paid' ? 'bg-emerald-100 border-emerald-400 ring-1 ring-emerald-300' : 'bg-emerald-50 border-emerald-200']">
        <p class="text-[10px] text-emerald-500 uppercase mb-1">Lunas</p>
        <p class="text-xl font-bold text-emerald-700">{{ fmtRp(totalPaid) }}</p>
      </button>
      <button v-if="totalShortfall > 0" @click="filterStatus = filterStatus === 'shortfall' ? 'all' : 'shortfall'"
        :class="['text-left rounded-xl border p-4 cursor-pointer hover:shadow-sm transition-all',
          filterStatus === 'shortfall' ? 'bg-red-100 border-red-400 ring-1 ring-red-300' : 'bg-red-50 border-red-200']">
        <p class="text-[10px] text-red-400 uppercase mb-1">Shortfall Bank</p>
        <p class="text-xl font-bold text-red-600">{{ fmtRp(totalShortfall) }}</p>
        <p class="text-[9px] text-red-400 mt-0.5">Bunga harian 50/50</p>
      </button>
    </div>

    <!-- Filter -->
    <div class="flex gap-1.5 flex-wrap">
      <button v-for="f in [
        {key:'all', label:'Semua'}, {key:'draft', label:'Perlu Review'},
        {key:'sent_to_rs', label:'Terkirim'}, {key:'partially_paid', label:'Sebagian'},
        {key:'paid', label:'Lunas'}, {key:'overdue', label:'Overdue'}
      ]" :key="f.key" @click="filterStatus = f.key"
        :class="['px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors',
          filterStatus === f.key ? 'bg-[#6b1525] text-white' : 'bg-[#ebebeb] text-[#666] hover:bg-[#e0e0e0]']">
        {{ f.label }}
      </button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-16">
      <UIcon name="i-lucide-loader-2" class="text-2xl text-[#999] animate-spin"/>
    </div>

    <div v-else-if="invoices.length === 0" class="flex flex-col items-center justify-center py-16 gap-3 bg-[#f5f5f5] rounded-xl border border-[#e5e5e5]">
      <UIcon name="i-lucide-file-text" class="text-3xl text-[#999]"/>
      <p class="text-sm text-[#999]">Belum ada invoice</p>
      <p class="text-xs text-[#888]">Invoice otomatis terbit H+1 setelah barang diterima RS dengan benar</p>
    </div>

    <!-- Invoice list -->
    <div v-else class="space-y-3">
      <div v-for="inv in invoices" :key="inv.id"
        :class="['bg-[#f5f5f5] rounded-xl border overflow-hidden',
          inv.status === 'draft' ? 'border-amber-300' : 'border-[#e5e5e5]']">
        <div class="px-5 py-4 flex items-start justify-between">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="font-mono text-sm font-bold text-[#1a1a1a]">{{ inv.invoice_number }}</p>
              <!-- partially_paid + shortfall_covered_by_bank = Lunas untuk KSM (Bank bayar langsung) -->
              <span :class="['px-2 py-0.5 rounded-full text-[10px] font-semibold',
                (inv.status === 'partially_paid' && inv.shortfall_covered_by_bank)
                  ? 'bg-emerald-100 text-emerald-700'
                  : (statusConfig[inv.status]?.color ?? 'bg-[#f0f0f0] text-[#999]')]">
                {{ (inv.status === 'partially_paid' && inv.shortfall_covered_by_bank) ? 'Lunas' : (statusConfig[inv.status]?.label ?? inv.status) }}
              </span>
              <span v-if="inv.metadata?.auto_generated" class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-blue-100 text-blue-700">Auto H+1</span>
              <span v-if="inv.shortfall_covered_by_bank" class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-amber-100 text-amber-700">Shortfall Bank</span>
            </div>
            <p class="text-xs text-[#999]">
              RS: <strong class="text-[#666]">{{ inv.metadata?.rs_name ?? '-' }}</strong>
              · PO: <span class="font-mono">{{ inv.metadata?.po_number ?? '-' }}</span>
              · Kontrak: Net {{ inv.contract_payment_days }} hari
            </p>
            <div class="flex items-center gap-4 mt-1.5 text-[10px] text-[#777]">
              <span>Terbit: {{ fmtDate(inv.invoice_date) }}</span>
              <span :class="inv.due_date < today && inv.status !== 'paid' && !(inv.shortfall_covered_by_bank && inv.status === 'partially_paid') ? 'text-red-600 font-bold' : ''">
                JT: {{ fmtDate(inv.due_date) }}
              </span>
            </div>
            <!-- Breakdown pembayaran ke KSM -->
            <div class="flex items-center gap-3 mt-1.5 flex-wrap">
              <span v-if="inv.bpjs_received_date" class="text-[10px] px-2 py-0.5 rounded bg-blue-50 text-blue-700">
                RS (BPJS): {{ fmtDate(inv.bpjs_received_date) }} · {{ fmtRp(inv.bpjs_amount) }}
              </span>
              <span v-if="inv.shortfall_covered_by_bank && Number(inv.shortfall_amount) > 0"
                class="text-[10px] px-2 py-0.5 rounded bg-amber-50 text-amber-700 font-semibold">
                Bank Langsung: {{ fmtRp(inv.shortfall_amount) }}
              </span>
            </div>
          </div>
          <div class="text-right flex-shrink-0">
            <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRp(inv.total_amount) }}</p>
            <!-- shortfall_covered_by_bank = Bank sudah bayar KSM langsung → KSM terima penuh, Sisa = 0 -->
            <p v-if="inv.shortfall_covered_by_bank && inv.status === 'partially_paid'" class="text-xs text-emerald-600 font-semibold">Lunas</p>
            <p v-else-if="Number(inv.outstanding ?? 0) > 0" class="text-xs text-amber-700 font-semibold">
              Sisa: {{ fmtRp(inv.outstanding) }}
            </p>
            <p v-else-if="inv.status === 'paid'" class="text-xs text-emerald-600 font-semibold">Lunas</p>
          </div>
        </div>

        <!-- Actions -->
        <div v-if="inv.status === 'draft'" class="px-5 pb-4 flex items-center gap-3">
          <div class="flex items-center gap-2 px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700 flex-1">
            <UIcon name="i-lucide-alert-circle" class="text-sm flex-shrink-0"/>
            Invoice auto-generated — review kesesuaian data PO lalu kirim ke RS
          </div>
          <button @click="reviewAndSend(inv.id)" :disabled="actionLoading === inv.id"
            class="px-4 py-2 bg-[#6b1525] text-white text-xs font-bold rounded-lg hover:bg-[#5a1120] disabled:opacity-50 transition-colors flex items-center gap-2 flex-shrink-0">
            <UIcon name="i-lucide-send" class="text-sm"/>
            {{ actionLoading === inv.id ? 'Mengirim...' : 'Review & Kirim ke RS' }}
          </button>
          <button @click="deleteInvoice(inv.id)" :disabled="actionLoading === inv.id"
            class="px-3 py-2 text-red-500 text-xs font-semibold border border-red-200 rounded-lg hover:bg-red-50 disabled:opacity-50 transition-colors flex items-center gap-1">
            <UIcon name="i-lucide-trash-2" class="text-xs"/> Hapus Draft
          </button>
        </div>

        <!-- Dispute button untuk invoice yang sudah terkirim -->
        <div v-if="['sent_to_rs', 'payment_pending'].includes(inv.status)" class="px-5 pb-4">
          <button @click="disputeInvoice(inv.id)" :disabled="actionLoading === inv.id"
            class="px-3 py-2 text-amber-700 text-xs font-semibold border border-amber-300 rounded-lg hover:bg-amber-50 disabled:opacity-50 transition-colors flex items-center gap-1.5">
            <UIcon name="i-lucide-alert-circle" class="text-xs"/> Ajukan Dispute / Koreksi
          </button>
        </div>

        <!-- Shortfall breakdown: 3 komponen pembayaran -->
        <div v-if="inv.shortfall_amount > 0 && inv.shortfall_covered_by_bank" class="px-5 pb-4">
          <div class="bg-amber-50 border border-amber-200 rounded-lg overflow-hidden text-[10px]">
            <div class="px-3 py-2 bg-amber-100 border-b border-amber-200">
              <p class="font-bold text-amber-800 text-xs">Rincian Pembayaran ke KSM</p>
            </div>
            <!-- 1. Pembayaran RS -->
            <div class="flex items-center justify-between px-3 py-2 border-b border-amber-100">
              <div class="flex items-center gap-2">
                <div class="w-1.5 h-1.5 rounded-full bg-blue-500 flex-shrink-0"></div>
                <div>
                  <p class="font-semibold text-[#333]">1. Pembayaran RS</p>
                  <p class="text-[#777]">BPJS cair ke RS → SI transfer ke KSM</p>
                </div>
              </div>
              <p class="font-bold text-blue-700">{{ fmtRp(inv.bpjs_amount) }}</p>
            </div>
            <!-- 2. Pembayaran Shortfall dari Bank -->
            <div class="flex items-center justify-between px-3 py-2 border-b border-amber-100">
              <div class="flex items-center gap-2">
                <div class="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0"></div>
                <div>
                  <p class="font-semibold text-[#333]">2. Pembayaran Shortfall dari Bank</p>
                  <p class="text-[#777]">Bank buka kredit untuk RS → bayar KSM langsung</p>
                </div>
              </div>
              <p class="font-bold text-amber-700">{{ fmtRp(inv.shortfall_amount) }}</p>
            </div>
            <!-- 3. Bunga Shortfall (beban KSM 50%) -->
            <div class="flex items-center justify-between px-3 py-2">
              <div class="flex items-center gap-2">
                <div class="w-1.5 h-1.5 rounded-full bg-[#6b1525] flex-shrink-0"></div>
                <div>
                  <p class="font-semibold text-[#333]">3. Bunga Shortfall (50% KSM)</p>
                  <p class="text-[#777]">Bunga harian akrual · KSM tanggung 50% karena hutang SCF</p>
                </div>
              </div>
              <div class="text-right">
                <p class="font-bold text-[#6b1525]">{{ fmtRp(interestByInvoice[inv.id] ?? 0) }}</p>
                <p class="text-[8px] text-[#999]">RS tanggung: {{ fmtRp(interestByInvoice[inv.id] ?? 0) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
