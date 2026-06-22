<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const user = useSupabaseUser()
const now = new Date()
const hour = now.getHours()
const greeting = hour < 5 ? 'Selamat Malam' : hour < 12 ? 'Selamat Pagi' : hour < 15 ? 'Selamat Siang' : hour < 19 ? 'Selamat Sore' : 'Selamat Malam'
const todayStr = now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const displayName = computed(() => {
  const email = user.value?.email ?? ''
  return email.split('@')[0].replace(/\./g, ' ').replace(/\b\w/g, c => c.toUpperCase()) || 'Admin'
})

// ── Period filter ───────────────────────────────────────────────
const periods = ['Hari Ini', '7 Hari', '30 Hari', 'Kuartal']
const activePeriod = ref('30 Hari')

// ── Animated counters ───────────────────────────────────────────
const ctrs = reactive({ stok: 0, trx: 0, pending: 0, alert: 0, bpjs: 0, fill: 0 })
const targets = { stok: 2840, trx: 184, pending: 7, alert: 12, bpjs: 1240, fill: 962 }
const chartLoaded = ref(false)

onMounted(() => {
  const dur = 1500
  const t0 = Date.now()
  const tick = () => {
    const p = Math.min((Date.now() - t0) / dur, 1)
    const e = 1 - Math.pow(1 - p, 3)
    for (const k in targets) (ctrs as Record<string,number>)[k] = Math.round(e * (targets as Record<string,number>)[k])
    if (p < 1) requestAnimationFrame(tick)
    else { chartLoaded.value = true; donutLoaded.value = true }
  }
  setTimeout(() => requestAnimationFrame(tick), 150)
  setTimeout(() => { insightTimer = setInterval(() => { insightIdx.value = (insightIdx.value + 1) % insights.length }, 5000) }, 500)
})
onUnmounted(() => { if (insightTimer) clearInterval(insightTimer) })

// ── KPI cards ───────────────────────────────────────────────────
const kpis = [
  { id: 'stok',    label: 'Nilai Stok Total',        sub: 'Live update',           icon: 'i-lucide-package-2',    grad: 'from-blue-600 to-blue-400',    ring: 'ring-blue-500/30',    trend: +5.2,  spark: [72,78,74,82,85,81,88,91,87,93,90,96],  displayFn: () => `Rp ${(ctrs.stok/1000).toFixed(2).replace('.',',')}M` },
  { id: 'trx',     label: 'Transaksi Hari Ini',       sub: 'GRN · DO · Adjst',     icon: 'i-lucide-activity',      grad: 'from-emerald-600 to-emerald-400', ring: 'ring-emerald-500/30', trend: +12,   spark: [95,110,88,125,112,130,145,118,155,142,168,184], displayFn: () => String(ctrs.trx) },
  { id: 'pending', label: 'PR / PO Pending',          sub: 'Perlu persetujuan',     icon: 'i-lucide-clock-alert',   grad: 'from-amber-600 to-amber-400',   ring: 'ring-amber-500/30',   trend: -2,    spark: [12,9,14,8,11,7,13,9,8,11,9,7],         displayFn: () => String(ctrs.pending) },
  { id: 'alert',   label: 'Alert Stok Kritis',        sub: 'Di bawah min stok',    icon: 'i-lucide-triangle-alert', grad: 'from-red-600 to-rose-400',      ring: 'ring-red-500/30',     trend: -3,    spark: [18,15,20,14,17,13,16,14,15,13,14,12],   displayFn: () => String(ctrs.alert) },
  { id: 'bpjs',    label: 'Klaim BPJS Bulan Ini',     sub: 'Total nilai pengajuan', icon: 'i-lucide-heart-pulse',   grad: 'from-purple-600 to-purple-400', ring: 'ring-purple-500/30',  trend: +8.4,  spark: [880,920,950,990,1050,1080,1100,1120,1150,1180,1210,1240], displayFn: () => `Rp ${ctrs.bpjs.toLocaleString('id-ID')}Jt` },
  { id: 'fill',    label: 'Fill Rate Logistik',       sub: 'Pemenuhan permintaan',  icon: 'i-lucide-target',        grad: 'from-teal-600 to-teal-400',     ring: 'ring-teal-500/30',    trend: +1.1,  spark: [900,920,910,935,940,945,938,952,955,958,960,962], displayFn: () => `${(ctrs.fill/10).toFixed(1)}%` },
]

// ── SVG Sparkline ───────────────────────────────────────────────
function sparkLine(data: number[], w = 80, h = 28): string {
  const mn = Math.min(...data), mx = Math.max(...data), rng = mx - mn || 1
  return data.map((v, i) => {
    const x = (i / (data.length - 1)) * w
    const y = h - ((v - mn) / rng) * (h - 4) - 2
    return `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`
  }).join(' ')
}
function sparkArea(data: number[], w = 80, h = 28): string {
  return `${sparkLine(data, w, h)} L${w} ${h} L0 ${h} Z`
}

// ── Main area chart ─────────────────────────────────────────────
const CW = 560, CH = 190
const PL = 50, PR = 12, PT = 10, PB = 30
const PW = CW - PL - PR, PH = CH - PT - PB

const PERIOD_DATA: Record<string, { labels: string[]; obat: number[]; alkes: number[]; bmhp: number[] }> = {
  'Hari Ini': { labels: ['06:00','08:00','10:00','12:00','14:00','16:00','18:00','20:00'], obat:[12,18,15,22,19,25,21,28], alkes:[5,8,6,10,8,12,9,14], bmhp:[3,4,3,5,4,6,5,7] },
  '7 Hari':   { labels: ['Sen','Sel','Rab','Kam','Jum','Sab'], obat:[180,220,195,240,210,260], alkes:[80,95,85,105,90,110], bmhp:[40,48,42,52,45,55] },
  '30 Hari':  { labels: ['Jan','Feb','Mar','Apr','Mei','Jun'], obat:[820,950,880,1100,1050,1280], alkes:[410,380,450,420,510,490], bmhp:[180,210,190,230,200,225] },
  'Kuartal':  { labels: ['Q1','Q2','Q3','Q4'], obat:[2400,2800,3100,3400], alkes:[1100,1250,1400,1600], bmhp:[540,620,700,800] },
}

interface ChartSeries { key: 'obat'|'alkes'|'bmhp'; label: string; color: string; active: boolean }
const series = ref<ChartSeries[]>([
  { key: 'obat',  label: 'Obat',  color: '#60a5fa', active: true },
  { key: 'alkes', label: 'Alkes', color: '#a78bfa', active: true },
  { key: 'bmhp',  label: 'BMHP',  color: '#fbbf24', active: true },
])

const cData = computed(() => PERIOD_DATA[activePeriod.value])
const cLabels = computed(() => cData.value.labels)

const allNums = computed(() => series.value.filter(s => s.active).flatMap(s => cData.value[s.key]))
const maxVal = computed(() => Math.ceil(Math.max(...allNums.value, 100) / 100) * 100)

function xPos(i: number, n: number) { return PL + (n < 2 ? 0 : (i / (n - 1)) * PW) }
function yPos(v: number) { return PT + PH - (v / maxVal.value) * PH }

function lPath(data: number[]) {
  return data.map((v, i) => `${i ? 'L' : 'M'}${xPos(i, data.length).toFixed(1)} ${yPos(v).toFixed(1)}`).join(' ')
}
function aPath(data: number[]) {
  const n = data.length
  return `${lPath(data)} L${xPos(n-1,n).toFixed(1)} ${(PT+PH).toFixed(1)} L${PL.toFixed(1)} ${(PT+PH).toFixed(1)} Z`
}

const yGrids = computed(() => Array.from({ length: 5 }, (_, i) => {
  const v = Math.round((maxVal.value / 4) * i)
  return { v, y: yPos(v), label: v >= 1000 ? `${(v/1000).toFixed(1)}k` : String(v) }
}))

// Chart hover
const hovering = ref(false)
const hoverIdx = ref(0)
const hoverX = computed(() => xPos(hoverIdx.value, cLabels.value.length))

function onChartMove(e: MouseEvent) {
  const svg = (e.currentTarget as SVGSVGElement)
  const rect = svg.getBoundingClientRect()
  const scaleX = CW / rect.width
  const relX = (e.clientX - rect.left) * scaleX - PL
  const n = cLabels.value.length
  hoverIdx.value = Math.max(0, Math.min(n - 1, Math.round((relX / PW) * (n - 1))))
  hovering.value = true
}

// ── Donut chart ─────────────────────────────────────────────────
const R = 54, CIRC = 2 * Math.PI * R
const donutLoaded = ref(false)
const hoveredSeg = ref<number | null>(null)

const donutData = [
  { label: 'Obat',      pct: 58, color: '#60a5fa', val: 'Rp 1,65M' },
  { label: 'Alkes',     pct: 24, color: '#a78bfa', val: 'Rp 680Jt' },
  { label: 'BMHP',      pct: 10, color: '#fbbf24', val: 'Rp 285Jt' },
  { label: 'Reagensia', pct:  5, color: '#34d399', val: 'Rp 142Jt' },
  { label: 'Lainnya',   pct:  3, color: '#94a3b8', val: 'Rp 85Jt'  },
]

const donutSegs = computed(() => {
  let offset = 0
  return donutData.map((d, i) => {
    const arc = (d.pct / 100) * CIRC
    const gap = 3
    const da = donutLoaded.value ? `${(arc - gap).toFixed(2)} ${(CIRC - arc + gap).toFixed(2)}` : `0 ${CIRC}`
    const seg = { ...d, idx: i, dashArray: da, dashOffset: -(offset).toFixed(2) }
    offset += arc
    return seg
  })
})

// ── Top items ───────────────────────────────────────────────────
const topItems = [
  { nama: 'Paracetamol 500mg Tab', kat: 'Obat',  qty: 4850, val: 4122500,  pct: 100, color: '#60a5fa' },
  { nama: 'Spuit 3cc Disposable',  kat: 'Alkes', qty: 8500, val: 12750000, pct: 88,  color: '#a78bfa' },
  { nama: 'Amoxicillin 500mg Cap', kat: 'Obat',  qty: 2100, val: 4410000,  pct: 72,  color: '#60a5fa' },
  { nama: 'Infus Set Dewasa',      kat: 'Alkes', qty: 1200, val: 10200000, pct: 61,  color: '#a78bfa' },
  { nama: 'Alkohol 70% 1L',        kat: 'BMHP',  qty: 650,  val: 3250000,  pct: 48,  color: '#fbbf24' },
]
function rp(n: number) { return 'Rp ' + n.toLocaleString('id-ID') }

// ── Activity feed ───────────────────────────────────────────────
const activities = [
  { type: 'IN',  icon: 'i-lucide-arrow-down-circle', color: 'text-emerald-400', bg: 'bg-emerald-500/10 border-emerald-500/20', label: 'GRN-2026-0031', desc: 'Amoxicillin 500mg · 500 pcs dari Kimia Farma', waktu: '09:32' },
  { type: 'OUT', icon: 'i-lucide-arrow-up-circle',   color: 'text-blue-400',    bg: 'bg-blue-500/10 border-blue-500/20',       label: 'DO-INT-0089',   desc: 'Paracetamol 500mg · 200 pcs → Farmasi RI', waktu: '09:15' },
  { type: 'ADJ', icon: 'i-lucide-refresh-cw',        color: 'text-amber-400',   bg: 'bg-amber-500/10 border-amber-500/20',     label: 'ADJ-0012',      desc: 'Spuit 3cc · selisih opname -5 pcs lot B240901', waktu: '08:55' },
  { type: 'IN',  icon: 'i-lucide-arrow-down-circle', color: 'text-emerald-400', bg: 'bg-emerald-500/10 border-emerald-500/20', label: 'GRN-2026-0030', desc: 'Infus Set Dewasa · 200 pcs dari Medifarma', waktu: '08:20' },
  { type: 'PO',  icon: 'i-lucide-file-text',         color: 'text-purple-400',  bg: 'bg-purple-500/10 border-purple-500/20',   label: 'PO-2026-0046',  desc: 'PO Rp 85Jt ke PT Enseval Medika — dikirim', waktu: '07:30' },
]

// ── AI Insights ─────────────────────────────────────────────────
const insights = [
  { icon: 'i-lucide-trending-up',    col: 'text-emerald-400', bg: 'bg-emerald-500/15 border-emerald-500/25', cat: 'Demand Forecast', title: 'Amoxicillin Naik 18% Minggu Ini', body: 'Pola musim hujan terdeteksi. Rekomendasi: tambah safety stock 200 pcs sebelum 25 Juni untuk hindari stockout.' },
  { icon: 'i-lucide-triangle-alert', col: 'text-amber-400',   bg: 'bg-amber-500/15 border-amber-500/25',   cat: 'Stok Kritis',     title: '12 Item di Bawah Reorder Point', body: 'Insulin Glargine (12 vial tersisa), Omeprazole IV (24 vial), dan 10 item lain perlu PO segera. ETA kehabisan: 3 hari.' },
  { icon: 'i-lucide-zap',            col: 'text-blue-400',    bg: 'bg-blue-500/15 border-blue-500/25',      cat: 'Efisiensi',       title: 'Lead Time Supplier Membaik -0.8 Hari', body: 'Rata-rata lead time turun 5.0 → 4.2 hari. PT Kimia Farma terbaik (2.1 hari). Pertimbangkan renegosiasi dengan supplier lambat.' },
  { icon: 'i-lucide-shield-check',   col: 'text-purple-400',  bg: 'bg-purple-500/15 border-purple-500/25', cat: 'Kadaluarsa',      title: 'Waste Kadaluarsa -8% vs Q1 2026', body: 'Implementasi FEFO berhasil. 4 item (Lidocaine, Ampicillin IV) perlu redistribusi ke unit lain dalam 9 hari.' },
  { icon: 'i-lucide-brain',          col: 'text-red-400',     bg: 'bg-red-500/15 border-red-500/25',        cat: 'Prediksi AI',     title: 'Lonjakan BMHP Akhir Juni +22%', body: 'Program vaksinasi massal 28 Juni diprediksi naikkan kebutuhan BMHP 22%. Siapkan 500 alkohol swab, 300 spuit extra.' },
]
const insightIdx = ref(0)
let insightTimer: ReturnType<typeof setInterval> | null = null

// ── Low stock & expiry ──────────────────────────────────────────
const lowStock = [
  { nama: 'Insulin Glargine 100U/mL', stok: 12,  min: 50,  pct: 24 },
  { nama: 'Omeprazole IV 40mg',        stok: 24,  min: 100, pct: 24 },
  { nama: 'Amoxicillin 500mg',         stok: 80,  min: 100, pct: 80 },
  { nama: 'Spuit 1cc TB',             stok: 45,  min: 200, pct: 22 },
]

const expiryItems = [
  { nama: 'Lidocaine HCl 2%', lot: 'B240115', sisa: 9,  qty: 28,  urgent: true },
  { nama: 'Ampicillin IV 1g', lot: 'B240312', sisa: 23, qty: 150, urgent: false },
  { nama: 'Vitamin C Inj',    lot: 'B240201', sisa: 30, qty: 200, urgent: false },
  { nama: 'NaCl 0.9% 500mL',  lot: 'B240510', sisa: 38, qty: 480, urgent: false },
]

const supplierUpdates = [
  { nama: 'PT Kimia Farma Tbk',  note: 'PO-0045 ETA 25 Jun',   badge: 'On Track',  bc: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30' },
  { nama: 'PT Enseval Medika',   note: 'Menunggu konfirmasi PO', badge: 'Pending',   bc: 'bg-amber-500/15 text-amber-400 border-amber-500/30' },
  { nama: 'PT Medifarma Labs',   note: 'Keterlambatan 2 hari',   badge: 'Delayed',   bc: 'bg-red-500/15 text-red-400 border-red-500/30' },
  { nama: 'PT Bernofarm',        note: 'Invoice Rp 42Jt siap',   badge: 'Invoice',   bc: 'bg-blue-500/15 text-blue-400 border-blue-500/30' },
]
</script>

<template>
  <div class="min-h-full -m-6 bg-[#08020a]">

    <!-- ── Hero Banner ──────────────────────────────────────── -->
    <div class="relative overflow-hidden" style="background: linear-gradient(135deg, #1a0408 0%, #2d0610 50%, #1a0408 100%);">
      <!-- Hexagon SVG pattern (selaras login page) -->
      <svg class="absolute inset-0 w-full h-full opacity-[0.07]" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="hex-db" x="0" y="0" width="56" height="48" patternUnits="userSpaceOnUse">
            <polygon points="28,4 52,18 52,42 28,56 4,42 4,18" fill="none" stroke="#dc2626" stroke-width="1"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#hex-db)"/>
      </svg>
      <!-- Glow orbs -->
      <div class="absolute -right-20 -top-20 w-80 h-80 rounded-full opacity-20" style="background: radial-gradient(circle, #dc2626 0%, transparent 70%)"/>
      <div class="absolute right-1/3 -bottom-10 w-60 h-60 rounded-full opacity-10" style="background: radial-gradient(circle, #f97316 0%, transparent 70%)"/>

      <div class="relative px-8 py-7 flex items-center justify-between gap-6">
        <div class="flex-1">
          <!-- Status pill -->
          <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full border border-emerald-500/30 bg-emerald-500/10 mb-4">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"/>
            <span class="text-xs font-medium text-emerald-400">Semua sistem operasional</span>
          </div>
          <h1 class="text-2xl font-bold text-white mb-1">
            {{ greeting }}, <span class="text-transparent bg-clip-text" style="background: linear-gradient(90deg, #f97316, #fbbf24)">{{ displayName }}</span> 👋
          </h1>
          <p class="text-sm text-gray-400 mb-5">{{ todayStr }} · RS Umum Demo</p>

          <!-- Quick stats -->
          <div class="flex flex-wrap gap-5 mb-5">
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-zap" class="text-amber-400 text-sm"/>
              <span class="text-sm text-gray-300"><span class="font-bold text-white">184</span> transaksi hari ini</span>
            </div>
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-shield-check" class="text-emerald-400 text-sm"/>
              <span class="text-sm text-gray-300">Kepatuhan <span class="font-bold text-white">98.2%</span></span>
            </div>
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-brain" class="text-purple-400 text-sm"/>
              <span class="text-sm text-gray-300"><span class="font-bold text-white">5</span> AI model aktif</span>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex gap-3">
            <NuxtLink to="/dashboard/analytics">
              <button class="flex items-center gap-2 px-4 py-2 rounded-lg border border-white/20 bg-white/10 text-white text-sm font-medium hover:bg-white/20 transition-colors backdrop-blur-sm">
                <UIcon name="i-lucide-file-bar-chart" class="text-base"/>
                Generate Laporan
              </button>
            </NuxtLink>
            <NuxtLink to="/dashboard/procurement/pr/new">
              <button class="flex items-center gap-2 px-4 py-2 rounded-lg text-white text-sm font-bold transition-all hover:opacity-90" style="background: linear-gradient(135deg, #dc2626, #b91c1c)">
                <UIcon name="i-lucide-plus" class="text-base"/>
                Buat PR Baru
              </button>
            </NuxtLink>
          </div>
        </div>

        <!-- Decorative icon -->
        <div class="hidden lg:flex items-center justify-center w-32 h-32 opacity-15">
          <UIcon name="i-lucide-network" class="text-red-400" style="font-size: 100px"/>
        </div>
      </div>
    </div>

    <div class="p-6 space-y-5">

      <!-- ── Period Selector ────────────────────────────────── -->
      <div class="flex items-center justify-between">
        <div class="flex gap-1 p-1 rounded-xl" style="background: #130608; border: 1px solid #2a1015">
          <button
            v-for="p in periods" :key="p"
            class="px-4 py-1.5 rounded-lg text-sm font-medium transition-all"
            :class="activePeriod === p
              ? 'text-white shadow-sm'
              : 'text-gray-500 hover:text-gray-300'"
            :style="activePeriod === p ? 'background: linear-gradient(135deg, #dc2626, #b91c1c)' : ''"
            @click="activePeriod = p"
          >{{ p }}</button>
        </div>
        <p class="text-xs text-gray-600">Diperbarui: {{ new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) }} WIB</p>
      </div>

      <!-- ── KPI Cards ──────────────────────────────────────── -->
      <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
        <div
          v-for="kpi in kpis" :key="kpi.id"
          class="relative rounded-xl p-4 border transition-all duration-200 cursor-default group overflow-hidden"
          style="background: #110508; border-color: #2a1015"
        >
          <!-- Top gradient bar -->
          <div class="absolute top-0 left-0 right-0 h-0.5 rounded-t-xl" :class="`bg-gradient-to-r ${kpi.grad}`"/>
          <!-- Subtle glow -->
          <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-xl pointer-events-none" style="background: radial-gradient(ellipse at top, rgba(220,38,38,0.04) 0%, transparent 70%)"/>

          <div class="flex items-start justify-between mb-3">
            <div class="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" :class="`bg-gradient-to-br ${kpi.grad} bg-opacity-20`" style="background: rgba(255,255,255,0.05)">
              <UIcon :name="kpi.icon" class="text-base" :class="`bg-gradient-to-r ${kpi.grad} bg-clip-text`" style="color: #f87171"/>
            </div>
            <span
              class="flex items-center gap-0.5 text-xs font-semibold px-1.5 py-0.5 rounded-full"
              :class="kpi.trend > 0 ? 'text-emerald-400 bg-emerald-500/10' : 'text-red-400 bg-red-500/10'"
            >
              <UIcon :name="kpi.trend > 0 ? 'i-lucide-trending-up' : 'i-lucide-trending-down'" class="text-xs"/>
              {{ Math.abs(kpi.trend) }}%
            </span>
          </div>

          <p class="text-xl font-bold text-white mb-0.5">{{ kpi.displayFn() }}</p>
          <p class="text-xs text-gray-500 mb-3 leading-tight">{{ kpi.label }}</p>

          <!-- Sparkline -->
          <div class="relative">
            <svg :width="80" :height="28" class="w-full">
              <defs>
                <linearGradient :id="`sg-${kpi.id}`" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stop-color="#dc2626" stop-opacity="0.25"/>
                  <stop offset="100%" stop-color="#dc2626" stop-opacity="0"/>
                </linearGradient>
              </defs>
              <path :d="sparkArea(kpi.spark)" :fill="`url(#sg-${kpi.id})`"/>
              <path
                :d="sparkLine(kpi.spark)"
                stroke="#f87171" stroke-width="1.5" fill="none" stroke-linecap="round"
                :style="{
                  strokeDasharray: 200,
                  strokeDashoffset: chartLoaded ? 0 : 200,
                  transition: 'stroke-dashoffset 1.4s cubic-bezier(0.4,0,0.2,1)'
                }"
              />
            </svg>
          </div>
          <p class="text-[10px] text-gray-600 mt-1">{{ kpi.sub }}</p>
        </div>
      </div>

      <!-- ── Main row: Chart + AI Insights ─────────────────── -->
      <div class="grid grid-cols-1 xl:grid-cols-3 gap-5">

        <!-- Area Chart -->
        <div class="xl:col-span-2 rounded-xl p-5 border" style="background: #110508; border-color: #2a1015">
          <div class="flex items-start justify-between mb-4">
            <div>
              <h2 class="text-sm font-bold text-white">Tren Pengeluaran Logistik</h2>
              <p class="text-xs text-gray-500 mt-0.5">Dalam Juta Rupiah · {{ activePeriod }}</p>
            </div>
            <!-- Legend toggles -->
            <div class="flex gap-2">
              <button
                v-for="s in series" :key="s.key"
                class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium border transition-all"
                :style="{
                  borderColor: s.active ? s.color + '50' : '#2a1015',
                  backgroundColor: s.active ? s.color + '15' : 'transparent',
                  color: s.active ? s.color : '#4b5563',
                  opacity: s.active ? 1 : 0.5
                }"
                @click="s.active = !s.active"
              >
                <span class="w-2 h-2 rounded-full" :style="{ background: s.active ? s.color : '#374151' }"/>
                {{ s.label }}
              </button>
            </div>
          </div>

          <!-- SVG Chart -->
          <div class="relative" @mouseleave="hovering = false">
            <svg :viewBox="`0 0 ${CW} ${CH}`" class="w-full" style="height: 190px; cursor: crosshair"
              @mousemove="onChartMove">

              <defs>
                <linearGradient id="ga-obat"  x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#60a5fa" stop-opacity="0.3"/><stop offset="100%" stop-color="#60a5fa" stop-opacity="0"/></linearGradient>
                <linearGradient id="ga-alkes" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#a78bfa" stop-opacity="0.25"/><stop offset="100%" stop-color="#a78bfa" stop-opacity="0"/></linearGradient>
                <linearGradient id="ga-bmhp"  x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#fbbf24" stop-opacity="0.2"/><stop offset="100%" stop-color="#fbbf24" stop-opacity="0"/></linearGradient>
              </defs>

              <!-- Y Grid lines -->
              <g v-for="g in yGrids" :key="g.v">
                <line :x1="PL" :y1="g.y.toFixed(1)" :x2="CW-PR" :y2="g.y.toFixed(1)" stroke="#2a1015" stroke-width="1"/>
                <text :x="PL - 6" :y="(g.y + 4).toFixed(1)" text-anchor="end" class="text-gray-600" style="font-size:9px; fill:#4b5563">{{ g.label }}</text>
              </g>

              <!-- X Labels -->
              <g v-for="(lbl, i) in cLabels" :key="lbl">
                <text :x="xPos(i, cLabels.length).toFixed(1)" :y="CH - 6" text-anchor="middle" style="font-size:9px; fill:#4b5563">{{ lbl }}</text>
              </g>

              <!-- Area fills -->
              <g v-for="s in series" :key="s.key">
                <path v-if="s.active" :d="aPath(cData[s.key])" :fill="`url(#ga-${s.key})`"/>
                <path v-if="s.active" :d="lPath(cData[s.key])" :stroke="s.color" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                <!-- Dots -->
                <circle
                  v-if="s.active"
                  v-for="(v, i) in cData[s.key]" :key="i"
                  :cx="xPos(i, cData[s.key].length).toFixed(1)"
                  :cy="yPos(v).toFixed(1)"
                  :r="hovering && hoverIdx === i ? 5 : 3"
                  :fill="s.color"
                  stroke="#110508"
                  stroke-width="2"
                  style="transition: r 0.1s ease"
                />
              </g>

              <!-- Crosshair -->
              <g v-if="hovering">
                <line :x1="hoverX.toFixed(1)" :y1="PT" :x2="hoverX.toFixed(1)" :y2="PT+PH" stroke="#dc2626" stroke-width="1" stroke-dasharray="4 3" opacity="0.7"/>
                <!-- Tooltip box -->
                <g :transform="`translate(${Math.min(hoverX + 10, CW - 120)}, ${PT + 4})`">
                  <rect width="110" height="70" rx="6" fill="#1a0408" stroke="#2a1015" stroke-width="1" opacity="0.95"/>
                  <text x="8" y="16" style="font-size: 9px; font-weight: 600; fill: #9ca3af">{{ cLabels[hoverIdx] }}</text>
                  <g v-for="(s, si) in series.filter(s => s.active)" :key="s.key">
                    <circle cx="14" :cy="28 + si * 16" r="3" :fill="s.color"/>
                    <text x="22" :y="32 + si * 16" style="font-size: 9px; fill: #e5e7eb">{{ s.label }}: <tspan font-weight="600">{{ (cData[s.key][hoverIdx] ?? 0).toLocaleString('id-ID') }}</tspan></text>
                  </g>
                </g>
              </g>
            </svg>
          </div>
        </div>

        <!-- AI Insights -->
        <div class="rounded-xl border overflow-hidden flex flex-col" style="background: #110508; border-color: #2a1015">
          <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color: #2a1015">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg flex items-center justify-center" style="background: linear-gradient(135deg, #7c3aed, #5b21b6)">
                <UIcon name="i-lucide-brain" class="text-white text-sm"/>
              </div>
              <div>
                <p class="text-sm font-bold text-white">AI Insights</p>
                <p class="text-[10px] text-gray-600">Diperbarui 2 mnt lalu</p>
              </div>
            </div>
            <span class="px-2 py-0.5 rounded-full text-[10px] font-bold text-purple-400 border border-purple-500/30 bg-purple-500/10">LIVE</span>
          </div>

          <!-- Insight display -->
          <div class="flex-1 p-5 flex flex-col">
            <div
              class="flex-1 rounded-xl p-4 border transition-all duration-500"
              :class="insights[insightIdx].bg"
            >
              <div class="flex items-center gap-2 mb-3">
                <UIcon :name="insights[insightIdx].icon" :class="['text-lg', insights[insightIdx].col]"/>
                <span class="text-xs font-bold px-2 py-0.5 rounded-full border" :class="[insights[insightIdx].bg, insights[insightIdx].col]">{{ insights[insightIdx].cat }}</span>
              </div>
              <p class="text-sm font-bold text-white mb-2 leading-tight">{{ insights[insightIdx].title }}</p>
              <p class="text-xs text-gray-400 leading-relaxed">{{ insights[insightIdx].body }}</p>
            </div>

            <!-- Carousel dots -->
            <div class="flex justify-center gap-1.5 mt-4">
              <button
                v-for="(ins, i) in insights" :key="i"
                class="rounded-full transition-all duration-300"
                :class="i === insightIdx ? 'w-6 h-1.5 bg-red-500' : 'w-1.5 h-1.5 bg-gray-700 hover:bg-gray-500'"
                @click="insightIdx = i"
              />
            </div>

            <!-- All insights list -->
            <div class="mt-4 space-y-2">
              <button
                v-for="(ins, i) in insights" :key="i"
                class="w-full flex items-start gap-2.5 p-2.5 rounded-lg border transition-all text-left"
                :class="i === insightIdx ? 'border-red-500/30 bg-red-500/10' : 'border-transparent hover:border-white/10 hover:bg-white/5'"
                :style="i === insightIdx ? '' : 'border-color: transparent'"
                @click="insightIdx = i"
              >
                <UIcon :name="ins.icon" :class="['text-sm flex-shrink-0 mt-0.5', ins.col]"/>
                <div class="min-w-0">
                  <p class="text-xs font-medium text-gray-300 truncate">{{ ins.title }}</p>
                  <p class="text-[10px] text-gray-600">{{ ins.cat }}</p>
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- ── Second row: Donut + Top Items + Activity ───────── -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-5">

        <!-- Donut Chart -->
        <div class="rounded-xl p-5 border" style="background: #110508; border-color: #2a1015">
          <h2 class="text-sm font-bold text-white mb-1">Distribusi Inventori</h2>
          <p class="text-xs text-gray-500 mb-4">Berdasarkan nilai stok</p>

          <div class="flex flex-col items-center">
            <div class="relative">
              <svg width="140" height="140" viewBox="0 0 140 140">
                <g transform="rotate(-90 70 70)">
                  <circle cx="70" cy="70" r="54" fill="none" stroke="#1f0a10" stroke-width="20"/>
                  <circle
                    v-for="seg in donutSegs" :key="seg.label"
                    cx="70" cy="70" r="54" fill="none"
                    :stroke="seg.color" stroke-width="hoveredSeg === seg.idx ? 24 : 20"
                    :stroke-dasharray="seg.dashArray"
                    :stroke-dashoffset="seg.dashOffset"
                    stroke-linecap="round"
                    style="transition: stroke-dasharray 1.2s cubic-bezier(0.4,0,0.2,1), stroke-width 0.2s ease; cursor: pointer"
                    @mouseenter="hoveredSeg = seg.idx"
                    @mouseleave="hoveredSeg = null"
                  />
                </g>
                <!-- Center label -->
                <text x="70" y="62" text-anchor="middle" style="font-size: 10px; fill: #6b7280">Total Stok</text>
                <text x="70" y="78" text-anchor="middle" style="font-size: 14px; font-weight: 700; fill: white">Rp 2,84M</text>
                <text x="70" y="92" text-anchor="middle" style="font-size: 9px; fill: #10b981">↑ 5.2%</text>
              </svg>
            </div>

            <!-- Legend -->
            <div class="w-full mt-3 space-y-2">
              <div
                v-for="(seg, i) in donutSegs" :key="seg.label"
                class="flex items-center justify-between p-2 rounded-lg transition-all cursor-pointer"
                :style="{ backgroundColor: hoveredSeg === i ? seg.color + '15' : 'transparent' }"
                @mouseenter="hoveredSeg = i"
                @mouseleave="hoveredSeg = null"
              >
                <div class="flex items-center gap-2">
                  <span class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: seg.color }"/>
                  <span class="text-xs text-gray-400">{{ seg.label }}</span>
                </div>
                <div class="text-right">
                  <span class="text-xs font-bold text-white">{{ seg.pct }}%</span>
                  <span class="text-[10px] text-gray-600 ml-1.5">{{ seg.val }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Top Moving Items -->
        <div class="rounded-xl p-5 border" style="background: #110508; border-color: #2a1015">
          <h2 class="text-sm font-bold text-white mb-1">Top 5 Item Bergerak</h2>
          <p class="text-xs text-gray-500 mb-4">Volume keluar bulan ini</p>

          <div class="space-y-3">
            <div v-for="(item, idx) in topItems" :key="item.nama" class="group">
              <div class="flex items-center justify-between mb-1.5">
                <div class="flex items-center gap-2 min-w-0">
                  <span class="text-xs font-bold w-4 text-gray-600 flex-shrink-0">{{ idx + 1 }}</span>
                  <div class="min-w-0">
                    <p class="text-xs font-medium text-gray-300 truncate">{{ item.nama }}</p>
                    <p class="text-[10px] text-gray-600">{{ item.kat }} · {{ item.qty.toLocaleString('id-ID') }} unit</p>
                  </div>
                </div>
                <p class="text-xs font-bold text-white flex-shrink-0 ml-2">{{ rp(item.val) }}</p>
              </div>
              <!-- Bar -->
              <div class="h-1.5 rounded-full overflow-hidden" style="background: #1f0a10">
                <div
                  class="h-full rounded-full transition-all duration-1000"
                  :style="{
                    width: chartLoaded ? item.pct + '%' : '0%',
                    background: item.color,
                    transitionDelay: idx * 120 + 'ms'
                  }"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Activity Feed -->
        <div class="rounded-xl border overflow-hidden flex flex-col" style="background: #110508; border-color: #2a1015">
          <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color: #2a1015">
            <h2 class="text-sm font-bold text-white">Aktivitas Terkini</h2>
            <div class="flex items-center gap-1.5">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"/>
              <span class="text-[10px] text-emerald-400 font-medium">Live</span>
            </div>
          </div>

          <div class="flex-1 divide-y" style="divide-color: #2a1015">
            <div
              v-for="act in activities" :key="act.label"
              class="px-4 py-3 flex items-start gap-3 hover:bg-white/3 transition-colors cursor-pointer group"
            >
              <div class="w-7 h-7 rounded-lg border flex items-center justify-center flex-shrink-0 mt-0.5" :class="act.bg">
                <UIcon :name="act.icon" :class="['text-sm', act.color]"/>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between">
                  <span class="text-xs font-bold text-white font-mono">{{ act.label }}</span>
                  <span class="text-[10px] text-gray-600 flex-shrink-0">{{ act.waktu }}</span>
                </div>
                <p class="text-[11px] text-gray-500 mt-0.5 leading-tight truncate">{{ act.desc }}</p>
              </div>
            </div>
          </div>

          <div class="px-5 py-3 border-t" style="border-color: #2a1015">
            <NuxtLink to="/dashboard/warehouse" class="text-xs text-red-500 hover:text-red-400 transition-colors flex items-center gap-1">
              Lihat semua aktivitas <UIcon name="i-lucide-arrow-right" class="text-xs"/>
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- ── Bottom row: Alerts ─────────────────────────────── -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-5">

        <!-- Low Stock -->
        <div class="rounded-xl border overflow-hidden" style="background: #110508; border-color: #2a1015">
          <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color: #2a1015">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-amber-500/15 border border-amber-500/25 flex items-center justify-center">
                <UIcon name="i-lucide-triangle-alert" class="text-amber-400 text-sm"/>
              </div>
              <div>
                <p class="text-sm font-bold text-white">Stok Mendekati Habis</p>
                <p class="text-[10px] text-gray-600">4 item di bawah reorder point</p>
              </div>
            </div>
            <span class="text-xs font-bold text-amber-400 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-full">4</span>
          </div>
          <div class="divide-y" style="divide-color: #1f0a10">
            <div v-for="item in lowStock" :key="item.nama" class="px-5 py-3.5 hover:bg-white/3 transition-colors">
              <div class="flex items-center justify-between mb-2">
                <p class="text-xs font-medium text-gray-300">{{ item.nama }}</p>
                <p class="text-xs font-bold" :class="item.pct < 30 ? 'text-red-400' : 'text-amber-400'">
                  {{ item.stok }} / {{ item.min }}
                </p>
              </div>
              <div class="h-1.5 rounded-full overflow-hidden" style="background: #1f0a10">
                <div
                  class="h-full rounded-full transition-all duration-1000"
                  :style="{ width: item.pct + '%', background: item.pct < 30 ? '#ef4444' : '#f59e0b' }"
                />
              </div>
            </div>
          </div>
          <div class="px-5 py-3 border-t" style="border-color: #2a1015">
            <NuxtLink to="/dashboard/procurement/pr/new">
              <button class="w-full py-2 rounded-lg text-sm font-bold text-white transition-all hover:opacity-90 flex items-center justify-center gap-2" style="background: linear-gradient(135deg, #d97706, #b45309)">
                <UIcon name="i-lucide-shopping-cart" class="text-sm"/>
                Reorder Sekarang →
              </button>
            </NuxtLink>
          </div>
        </div>

        <!-- Expiry Alerts -->
        <div class="rounded-xl border overflow-hidden" style="background: #110508; border-color: #2a1015">
          <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color: #2a1015">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-red-500/15 border border-red-500/25 flex items-center justify-center">
                <UIcon name="i-lucide-calendar-x" class="text-red-400 text-sm"/>
              </div>
              <div>
                <p class="text-sm font-bold text-white">Alert Kadaluarsa</p>
                <p class="text-[10px] text-gray-600">Dalam 30 hari ke depan</p>
              </div>
            </div>
            <span class="text-xs font-bold text-red-400 bg-red-500/10 border border-red-500/20 px-2 py-0.5 rounded-full">{{ expiryItems.length }}</span>
          </div>

          <!-- Urgency heat strip -->
          <div class="px-5 py-3 border-b flex gap-1" style="border-color: #1f0a10">
            <div v-for="item in expiryItems" :key="item.lot"
              class="flex-1 h-2 rounded-full transition-all"
              :style="{ background: item.sisa <= 9 ? '#ef4444' : item.sisa <= 14 ? '#f59e0b' : '#2a1015' }"
              :title="`${item.nama} — ${item.sisa} hari lagi`"
            />
          </div>

          <div class="divide-y" style="divide-color: #1f0a10">
            <div v-for="item in expiryItems" :key="item.lot" class="px-5 py-3 flex items-center gap-3 hover:bg-white/3 transition-colors">
              <div class="w-2 h-2 rounded-full flex-shrink-0" :class="item.sisa <= 9 ? 'bg-red-500' : 'bg-amber-500'"/>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-gray-300 truncate">{{ item.nama }}</p>
                <p class="text-[10px] text-gray-600">Lot {{ item.lot }} · {{ item.qty }} unit</p>
              </div>
              <div class="text-right flex-shrink-0">
                <p class="text-xs font-bold" :class="item.urgent ? 'text-red-400' : 'text-amber-400'">{{ item.sisa }}h</p>
                <p class="text-[10px] text-gray-600">tersisa</p>
              </div>
            </div>
          </div>
          <div class="px-5 py-3 border-t" style="border-color: #2a1015">
            <NuxtLink to="/dashboard/qms" class="text-xs text-red-500 hover:text-red-400 transition-colors flex items-center gap-1">
              Lihat detail & ambil tindakan <UIcon name="i-lucide-arrow-right" class="text-xs"/>
            </NuxtLink>
          </div>
        </div>

        <!-- Supplier Updates -->
        <div class="rounded-xl border overflow-hidden" style="background: #110508; border-color: #2a1015">
          <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color: #2a1015">
            <div class="flex items-center gap-2">
              <div class="w-7 h-7 rounded-lg bg-blue-500/15 border border-blue-500/25 flex items-center justify-center">
                <UIcon name="i-lucide-truck" class="text-blue-400 text-sm"/>
              </div>
              <div>
                <p class="text-sm font-bold text-white">Update Supplier</p>
                <p class="text-[10px] text-gray-600">Status pengiriman & invoice</p>
              </div>
            </div>
          </div>
          <div class="divide-y" style="divide-color: #1f0a10">
            <div v-for="sup in supplierUpdates" :key="sup.nama" class="px-5 py-3.5 flex items-start gap-3 hover:bg-white/3 transition-colors">
              <div class="w-7 h-7 rounded-full bg-gray-800 flex items-center justify-center flex-shrink-0 border border-gray-700">
                <span class="text-xs font-bold text-gray-400">{{ sup.nama.replace('PT ', '').charAt(0) }}</span>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-gray-300 truncate">{{ sup.nama }}</p>
                <p class="text-[10px] text-gray-500 mt-0.5">{{ sup.note }}</p>
              </div>
              <span class="text-[10px] font-bold px-2 py-0.5 rounded-full border flex-shrink-0" :class="sup.bc">{{ sup.badge }}</span>
            </div>
          </div>
          <div class="px-5 py-3 border-t" style="border-color: #2a1015">
            <NuxtLink to="/dashboard/procurement">
              <button class="w-full py-2 rounded-lg text-sm font-bold text-white transition-all hover:opacity-90 flex items-center justify-center gap-2" style="background: linear-gradient(135deg, #1d4ed8, #1e3a8a)">
                <UIcon name="i-lucide-clipboard-list" class="text-sm"/>
                Review Semua Order →
              </button>
            </NuxtLink>
          </div>
        </div>

      </div>

      <!-- ── Quick Access Modules ───────────────────────────── -->
      <div>
        <h2 class="text-xs font-semibold text-gray-600 uppercase tracking-widest mb-3">Akses Cepat Modul</h2>
        <div class="grid grid-cols-3 md:grid-cols-6 gap-2">
          <NuxtLink
            v-for="mod in [
              { label: 'Inventory',    icon: 'i-lucide-package',       to: '/dashboard/inventory' },
              { label: 'Pengadaan',    icon: 'i-lucide-shopping-cart', to: '/dashboard/procurement' },
              { label: 'BPJS & RCM',  icon: 'i-lucide-heart-pulse',   to: '/dashboard/bpjs' },
              { label: 'Finansial',   icon: 'i-lucide-banknote',      to: '/dashboard/financial' },
              { label: 'Analytics',   icon: 'i-lucide-bar-chart-2',   to: '/dashboard/analytics' },
              { label: 'AI / ML',     icon: 'i-lucide-brain',          to: '/dashboard/ai' },
            ]" :key="mod.to" :to="mod.to"
            class="group rounded-xl p-3 border flex flex-col items-center gap-2 transition-all duration-200 hover:scale-105"
            style="background: #110508; border-color: #2a1015"
          >
            <div class="w-9 h-9 rounded-lg flex items-center justify-center transition-all" style="background: #1f0a10; border: 1px solid #3a1520">
              <UIcon :name="mod.icon" class="text-gray-500 group-hover:text-red-400 text-lg transition-colors"/>
            </div>
            <p class="text-[10px] font-medium text-gray-600 group-hover:text-gray-300 transition-colors text-center">{{ mod.label }}</p>
          </NuxtLink>
        </div>
      </div>

    </div>
  </div>
</template>
