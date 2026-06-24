<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const { tenantId } = useUserRole()

const features = [
  {
    title: 'Demand Forecasting',
    desc: 'Prediksi kebutuhan stok 30 hari ke depan berbasis pola historis & kecerdasan buatan.',
    status: 'live', icon: 'i-lucide-brain', color: 'text-purple-600', bg: 'bg-purple-50',
    action: 'forecast'
  },
  {
    title: 'Anomali Deteksi',
    desc: 'Deteksi transaksi mencurigakan, pola pembelian tidak wajar, dan potensi fraud pengadaan.',
    status: 'live', icon: 'i-lucide-shield-alert', color: 'text-red-600', bg: 'bg-red-50',
    action: 'anomaly'
  },
  {
    title: 'AI Assistant',
    desc: 'Tanya apa saja tentang inventory, pengadaan, keuangan & logistik. AI menjawab berdasarkan data real.',
    status: 'live', icon: 'i-lucide-message-circle', color: 'text-blue-600', bg: 'bg-blue-50',
    action: 'chat'
  },
  {
    title: 'Supplier Performance Scoring',
    desc: 'Skoring otomatis performa supplier: ketepatan waktu, kesesuaian mutu, dan harga kompetitif.',
    status: 'beta', icon: 'i-lucide-bar-chart-2', color: 'text-amber-600', bg: 'bg-amber-50',
    action: null
  },
  {
    title: 'BPJS Claim Validation',
    desc: 'AI checker untuk validasi koding ICD-10, kelengkapan berkas, dan prediksi probabilitas approve.',
    status: 'beta', icon: 'i-lucide-stethoscope', color: 'text-emerald-600', bg: 'bg-emerald-50',
    action: null
  },
  {
    title: 'Expiry & Waste Prediction',
    desc: 'Prediksi item yang berisiko kadaluarsa sebelum terpakai dan rekomendasi redistribusi antar unit.',
    status: 'coming', icon: 'i-lucide-calendar-x', color: 'text-[#999]', bg: 'bg-[#f0f0f0]',
    action: null
  },
]

const loading = ref('')
const result = ref<any>(null)
const chatQuestion = ref('')
const chatHistory = ref<{ role: string; text: string }[]>([])

async function runForecast() {
  loading.value = 'forecast'
  result.value = null

  // 3 bulan terakhir (M-3, M-2, M-1)
  const now = new Date()
  const months = [2, 1, 0].reverse().map(offset => {
    const d = new Date(now.getFullYear(), now.getMonth() - offset - 1, 1)
    return {
      label: d.toLocaleDateString('id-ID', { month: 'short', year: '2-digit' }),
      from: new Date(d.getFullYear(), d.getMonth(), 1).toISOString().slice(0, 10),
      to:   new Date(d.getFullYear(), d.getMonth() + 1, 0).toISOString().slice(0, 10),
    }
  })

  const { data: lines } = await supabase
    .from('ksm_po_lines')
    .select('item_name, catalog_type, ordered_qty, ksm_purchase_orders!inner(po_date, ksm_tenant_id)')
    .eq('ksm_purchase_orders.ksm_tenant_id', tenantId.value)
    .gte('ksm_purchase_orders.po_date', months[0].from)
    .limit(1000)

  // Agregasi per item per bulan
  const agg: Record<string, { category: string; monthly: number[] }> = {}
  for (const l of lines ?? []) {
    const poDate = (l.ksm_purchase_orders as any)?.po_date ?? ''
    const mIdx = months.findIndex(m => poDate >= m.from && poDate <= m.to)
    if (mIdx === -1) continue
    const key = l.item_name ?? '-'
    if (!agg[key]) agg[key] = { category: l.catalog_type ?? 'obat', monthly: [0, 0, 0] }
    agg[key].monthly[mIdx] += Number(l.ordered_qty ?? 0)
  }

  const LEAD_TIME = 7 // hari — asumsi lead time distributor
  const predictions = Object.entries(agg)
    .filter(([, v]) => v.monthly.some(m => m > 0))
    .map(([name, v]) => {
      const [m1, m2, m3] = v.monthly
      const ma = (m1 + m2 + m3) / 3           // Moving Average 3 bulan
      const predicted30d = Math.round(ma)
      const avgDaily = ma / 30
      const safetyStock = Math.round(avgDaily * LEAD_TIME * 0.5)
      const rop = Math.round(avgDaily * LEAD_TIME + safetyStock) // ROP = avg×LT + SS
      // Trend: bandingkan bulan terbaru vs tertua
      const trend = m3 > m1 * 1.1 ? 'up' : m3 < m1 * 0.9 ? 'down' : 'stable'
      // Risk: koefisien variasi antar bulan
      const cv = ma > 0 ? Math.sqrt(((m1-ma)**2 + (m2-ma)**2 + (m3-ma)**2) / 3) / ma : 0
      const risk: 'high'|'medium'|'low' = cv > 0.3 || trend === 'up' ? 'high' : cv > 0.15 ? 'medium' : 'low'
      return { name, category: v.category, monthly: [m1, m2, m3], predicted30d, avgDaily: Math.round(avgDaily * 10) / 10, rop, safetyStock, reorderQty: predicted30d, trend, risk }
    })
    .sort((a, b) => b.predicted30d - a.predicted30d)
    .slice(0, 20)

  result.value = { type: 'forecast', data: { predictions, monthLabels: months.map(m => m.label) } }
  loading.value = ''
}

async function runAnomaly() {
  loading.value = 'anomaly'
  result.value = null
  const { data: movements } = await supabase
    .from('stock_movements')
    .select('movement_type, qty, ref_number, created_at, products(name)')
    .order('created_at', { ascending: false }).limit(30)

  const transactions = (movements ?? []).map(m => ({
    type: m.movement_type,
    ref: m.ref_number ?? '-',
    product: (m.products as any)?.name ?? '-',
    qty: Math.abs(Number(m.qty)),
    date: m.created_at?.slice(0, 10) ?? '-'
  }))

  try {
    const res = await $fetch('/api/anomaly', { method: 'POST', body: { transactions } })
    result.value = { type: 'anomaly', data: res }
  } catch (e: any) {
    result.value = { type: 'error', data: { message: e.data?.message ?? e.message ?? 'Gagal menghubungi AI' } }
  }
  loading.value = ''
}

async function sendChat() {
  if (!chatQuestion.value.trim()) return
  const q = chatQuestion.value.trim()
  chatHistory.value.push({ role: 'user', text: q })
  chatQuestion.value = ''
  loading.value = 'chat'

  const { data: summaries } = await supabase
    .from('stock_summary')
    .select('qty_on_hand, products(name, category)')
    .limit(10)

  const context = (summaries ?? []).map(s =>
    `${(s.products as any)?.name}: stok ${s.qty_on_hand}`
  ).join(', ')

  try {
    const res = await $fetch('/api/chat', { method: 'POST', body: { question: q, context } })
    const answer = (res as any).answer ?? JSON.stringify(res)
    chatHistory.value.push({ role: 'ai', text: answer })
  } catch (e: any) {
    chatHistory.value.push({ role: 'ai', text: `Error: ${e.data?.message ?? e.message}` })
  }
  loading.value = ''
}

function runAction(action: string | null) {
  if (action === 'forecast') runForecast()
  else if (action === 'anomaly') runAnomaly()
  else if (action === 'chat') result.value = { type: 'chat' }
}
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">AI / Machine Learning</h1>
        <p class="text-sm text-[#999] mt-0.5">AI-powered — optimasi logistik &amp; prediksi</p>
      </div>
      <div class="flex gap-2 text-xs">
        <span class="px-2 py-1 rounded-full bg-emerald-100 text-emerald-700 font-medium">● Live</span>
        <span class="px-2 py-1 rounded-full bg-amber-100 text-amber-700 font-medium">● Beta</span>
        <span class="px-2 py-1 rounded-full bg-[#f0f0f0] text-[#999] font-medium">● Coming Soon</span>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="f in features" :key="f.title"
        class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5 transition-colors"
        :class="[f.status==='coming'?'opacity-60':'hover:border-[#6b1525]/40 cursor-pointer']"
        @click="f.action ? runAction(f.action) : null">
        <div class="flex items-start justify-between mb-4">
          <div :class="[f.bg,'w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="f.icon" :class="[f.color,'text-xl']" />
          </div>
          <span :class="[
            'px-2 py-0.5 rounded-full text-xs font-medium',
            f.status==='live'?'bg-emerald-100 text-emerald-700':
            f.status==='beta'?'bg-amber-100 text-amber-700':
            'bg-[#f0f0f0] text-[#999]'
          ]">{{ f.status === 'coming' ? 'Coming Soon' : f.status.toUpperCase() }}</span>
        </div>
        <h3 class="text-sm font-bold text-[#1a1a1a] mb-1.5">{{ f.title }}</h3>
        <p class="text-xs text-[#999] leading-relaxed">{{ f.desc }}</p>
        <div v-if="f.action && f.status === 'live'" class="mt-3 pt-3 border-t border-[#e5e5e5]">
          <span class="text-xs font-medium text-[#6b1525]">
            <UIcon name="i-lucide-play" class="text-xs" />
            {{ loading === f.action ? 'Memproses...' : 'Jalankan' }}
          </span>
        </div>
      </div>
    </div>

    <!-- Result Panel -->
    <div v-if="result" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-5">

      <!-- Forecast Result -->
      <div v-if="result.type === 'forecast'">
        <div class="flex items-center justify-between mb-1">
          <h2 class="text-sm font-bold text-[#1a1a1a]">Demand Forecast — 30 Hari ke Depan</h2>
          <button class="text-xs text-[#999] hover:text-[#666]" @click="result = null">Tutup</button>
        </div>
        <p class="text-[10px] text-[#999] mb-4">Moving Average 3 bulan · ROP = avg_daily × lead_time + safety_stock · Lead time: 7 hari</p>

        <div v-if="!result.data.predictions?.length" class="text-sm text-[#999] py-8 text-center">Tidak ada data PO dalam 3 bulan terakhir.</div>

        <div v-else class="overflow-x-auto rounded-xl border border-[#e5e5e5]">
          <table class="w-full text-xs">
            <thead class="bg-[#ebebeb] border-b border-[#e5e5e5]">
              <tr>
                <th class="px-3 py-2.5 text-left text-[#666] font-semibold">Item</th>
                <th v-for="lbl in result.data.monthLabels" :key="lbl" class="px-3 py-2.5 text-right text-[#666] font-semibold">{{ lbl }}</th>
                <th class="px-3 py-2.5 text-right text-[#666] font-semibold">Forecast 30d</th>
                <th class="px-3 py-2.5 text-right text-[#666] font-semibold">Avg/Hari</th>
                <th class="px-3 py-2.5 text-right text-[#666] font-semibold">ROP</th>
                <th class="px-3 py-2.5 text-right text-[#666] font-semibold">Order Qty</th>
                <th class="px-3 py-2.5 text-center text-[#666] font-semibold">Trend</th>
                <th class="px-3 py-2.5 text-center text-[#666] font-semibold">Risiko</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-[#e5e5e5]">
              <tr v-for="p in result.data.predictions" :key="p.name" class="hover:bg-[#ebebeb] transition-colors">
                <td class="px-3 py-2.5">
                  <p class="font-medium text-[#1a1a1a] max-w-[180px] truncate" :title="p.name">{{ p.name }}</p>
                  <p class="text-[10px] text-[#999]">{{ p.category }}</p>
                </td>
                <td v-for="(qty, i) in p.monthly" :key="i" class="px-3 py-2.5 text-right text-[#555]">
                  {{ qty.toLocaleString('id-ID') }}
                </td>
                <td class="px-3 py-2.5 text-right font-bold text-[#1a1a1a]">{{ p.predicted30d.toLocaleString('id-ID') }}</td>
                <td class="px-3 py-2.5 text-right text-[#555]">{{ p.avgDaily }}</td>
                <td class="px-3 py-2.5 text-right font-semibold text-amber-700">{{ p.rop.toLocaleString('id-ID') }}</td>
                <td class="px-3 py-2.5 text-right text-[#555]">{{ p.reorderQty.toLocaleString('id-ID') }}</td>
                <td class="px-3 py-2.5 text-center">
                  <span v-if="p.trend === 'up'" class="text-red-500 font-bold">↑</span>
                  <span v-else-if="p.trend === 'down'" class="text-emerald-500 font-bold">↓</span>
                  <span v-else class="text-[#999]">→</span>
                </td>
                <td class="px-3 py-2.5 text-center">
                  <span :class="['px-1.5 py-0.5 rounded text-[9px] font-bold',
                    p.risk==='high'?'bg-red-100 text-red-700':p.risk==='medium'?'bg-amber-100 text-amber-700':'bg-emerald-100 text-emerald-700']">
                    {{ p.risk.toUpperCase() }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p class="text-[10px] text-[#999] mt-2">
          ROP = titik stok minimum sebelum harus reorder · Safety Stock = 50% × avg_daily × lead_time
        </p>
      </div>

      <!-- Anomaly Result -->
      <div v-if="result.type === 'anomaly'">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-bold text-[#1a1a1a]">Hasil Anomaly Detection</h2>
          <button class="text-xs text-[#999] hover:text-[#666]" @click="result = null">Tutup</button>
        </div>
        <p v-if="result.data.summary" class="text-xs text-[#666] mb-4">
          {{ result.data.summary }} ({{ result.data.total_analyzed ?? 0 }} transaksi dianalisis, {{ result.data.anomaly_count ?? 0 }} anomali)
        </p>
        <div v-if="result.data.alerts?.length" class="space-y-2">
          <div v-for="a in result.data.alerts" :key="a.ref"
            class="flex items-center justify-between p-3 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
            <div>
              <p class="text-sm font-medium text-[#1a1a1a]">{{ a.ref }}</p>
              <p class="text-xs text-[#999]">{{ a.description }}</p>
            </div>
            <span :class="[
              'px-2 py-0.5 rounded-full text-xs font-medium',
              a.severity === 'high' ? 'bg-red-100 text-red-700' : a.severity === 'medium' ? 'bg-amber-100 text-amber-700' : 'bg-blue-100 text-blue-700'
            ]">{{ a.severity }}</span>
          </div>
        </div>
        <p v-else class="text-sm text-emerald-600 font-medium">Tidak ada anomali terdeteksi.</p>
      </div>

      <!-- Chat -->
      <div v-if="result.type === 'chat'">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-bold text-[#1a1a1a]">AI Assistant — TransLOG-X</h2>
          <button class="text-xs text-[#999] hover:text-[#666]" @click="result = null; chatHistory = []">Tutup</button>
        </div>
        <div class="space-y-3 max-h-80 overflow-y-auto mb-4">
          <div v-for="(msg, i) in chatHistory" :key="i"
            :class="msg.role === 'user' ? 'text-right' : ''">
            <div :class="[
              'inline-block max-w-[80%] px-3 py-2 rounded-xl text-sm',
              msg.role === 'user' ? 'bg-[#6b1525] text-white' : 'bg-[#f0f0f0] text-[#1a1a1a] border border-[#e5e5e5]'
            ]">
              {{ msg.text }}
            </div>
          </div>
          <div v-if="loading === 'chat'" class="text-xs text-[#999]">AI sedang menjawab...</div>
        </div>
        <form class="flex gap-2" @submit.prevent="sendChat">
          <input v-model="chatQuestion" type="text" placeholder="Tanya apa saja tentang logistik..."
            class="flex-1 px-3 py-2 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0] text-sm text-[#1a1a1a] outline-none focus:border-[#6b1525]"
            :disabled="loading === 'chat'">
          <UButton type="submit" color="primary" size="sm" :loading="loading === 'chat'" icon="i-lucide-send">Kirim</UButton>
        </form>
      </div>

      <!-- Error -->
      <div v-if="result.type === 'error'">
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-sm font-bold text-red-600">Error</h2>
          <button class="text-xs text-[#999] hover:text-[#666]" @click="result = null">Tutup</button>
        </div>
        <p class="text-sm text-[#666]">{{ result.data.message }}</p>
      </div>
    </div>
  </div>
</template>
