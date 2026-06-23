<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const features = [
  {
    title: 'Demand Forecasting',
    desc: 'Prediksi kebutuhan stok 30 hari ke depan berbasis pola historis & AI Groq Llama 3.3.',
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
  const { data: summaries } = await supabase
    .from('stock_summary')
    .select('qty_on_hand, avg_cost, product_id, products(name, category, min_stock)')
    .limit(20)

  const items = (summaries ?? []).map(s => ({
    name: (s.products as any)?.name ?? '-',
    stock: Number(s.qty_on_hand),
    avg_daily: Math.max(1, Math.round(Number(s.qty_on_hand) / 30)),
    category: (s.products as any)?.category ?? 'obat'
  }))

  try {
    const res = await $fetch('/api/forecast', { method: 'POST', body: { items } })
    result.value = { type: 'forecast', data: res }
  } catch (e: any) {
    result.value = { type: 'error', data: { message: e.data?.message ?? e.message ?? 'Gagal menghubungi AI' } }
  }
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
        <p class="text-sm text-[#999] mt-0.5">Powered by Groq Llama 3.3 70B — optimasi logistik & prediksi</p>
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
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-sm font-bold text-[#1a1a1a]">Hasil Demand Forecast (30 Hari)</h2>
          <button class="text-xs text-[#999] hover:text-[#666]" @click="result = null">Tutup</button>
        </div>
        <p v-if="result.data.summary" class="text-xs text-[#666] mb-4">{{ result.data.summary }}</p>
        <div v-if="result.data.predictions" class="space-y-2">
          <div v-for="p in result.data.predictions" :key="p.name"
            class="flex items-center justify-between p-3 rounded-lg border border-[#e5e5e5] bg-[#f0f0f0]">
            <div>
              <p class="text-sm font-medium text-[#1a1a1a]">{{ p.name }}</p>
              <p class="text-xs text-[#999]">{{ p.note }}</p>
            </div>
            <div class="text-right">
              <p class="text-sm font-bold text-[#1a1a1a]">{{ p.predicted_demand_30d?.toLocaleString('id-ID') ?? '-' }}</p>
              <p class="text-xs" :class="p.risk === 'high' ? 'text-red-600' : p.risk === 'medium' ? 'text-amber-600' : 'text-emerald-600'">
                Risiko: {{ p.risk }} · Confidence: {{ Math.round((p.confidence ?? 0) * 100) }}%
              </p>
            </div>
          </div>
        </div>
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
