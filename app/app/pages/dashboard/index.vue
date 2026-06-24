<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()

// Role detection — tampilkan dashboard berbeda per portal
const { portalType, tenantName, isKSM, isDistributor, isBank, loading: roleLoading } = useUserRole()

// ─── KSM Dashboard Data ───────────────────────────────────────────────────────
const ksmStats = ref({ pos: 0, arOutstanding: 0, scfUsed: 0, scfLimit: 0, pendingNotif: 0 })
async function loadKsmStats() {
  const [{ data: pos, count: poCount }, { data: ar }, { data: scf }, { count: notifCount }] = await Promise.all([
    supabase.from('ksm_purchase_orders').select('total_amount', { count:'exact' }).in('status',['submitted','approved','sent_to_supplier','fully_received']),
    supabase.from('ar_accounts').select('outstanding_amount').neq('status','paid'),
    supabase.from('scf_facilities').select('outstanding,facility_limit').eq('status','approved'),
    supabase.from('hospital_notifications').select('*', { count:'exact', head:true }).eq('status','pending'),
  ])
  ksmStats.value = {
    pos: poCount ?? 0,
    arOutstanding: (ar ?? []).reduce((s,a) => s + Number(a.outstanding_amount ?? 0), 0),
    scfUsed: (scf ?? []).reduce((s,f) => s + Number(f.outstanding ?? 0), 0),
    scfLimit: (scf ?? []).reduce((s,f) => s + Number(f.facility_limit ?? 0), 0),
    pendingNotif: notifCount ?? 0,
  }
}

// ─── Distributor Dashboard Data ───────────────────────────────────────────────
const distStats = ref({ activePOs: 0, pendingInvoices: 0, revenue: 0, stockItems: 0 })
async function loadDistStats() {
  const [{ data: pos, count: poCount }, { data: inv }] = await Promise.all([
    supabase.from('ksm_purchase_orders').select('total_amount,status', { count:'exact' }).in('status',['approved','sent_to_supplier']),
    supabase.from('ksm_purchase_orders').select('total_amount').eq('status','fully_received'),
  ])
  distStats.value = {
    activePOs: poCount ?? 0,
    pendingInvoices: (pos ?? []).length,
    revenue: (inv ?? []).reduce((s,p) => s + Number(p.total_amount ?? 0), 0),
    stockItems: 0,
  }
}

// ─── Bank Dashboard Data ──────────────────────────────────────────────────────
const bankStats = ref({ activeFacilities: 0, totalLimit: 0, totalOutstanding: 0, interestEarned: 0, overdueAR: 0 })
async function loadBankStats() {
  const [{ data: fac }, { data: ar }] = await Promise.all([
    supabase.from('scf_facilities').select('facility_limit,outstanding,status').eq('status','approved'),
    supabase.from('ar_accounts').select('outstanding_amount,interest_amount,status'),
  ])
  const overdue = (ar ?? []).filter(a => a.status === 'overdue').reduce((s,a) => s + Number(a.outstanding_amount ?? 0), 0)
  bankStats.value = {
    activeFacilities: (fac ?? []).length,
    totalLimit: (fac ?? []).reduce((s,f) => s + Number(f.facility_limit ?? 0), 0),
    totalOutstanding: (fac ?? []).reduce((s,f) => s + Number(f.outstanding ?? 0), 0),
    interestEarned: (ar ?? []).reduce((s,a) => s + Number(a.interest_amount ?? 0), 0),
    overdueAR: overdue,
  }
}

const fmtRpDash = fmtRp
const now = new Date()
const hour = now.getHours()
const greeting = hour < 5 ? 'Selamat Malam' : hour < 12 ? 'Selamat Pagi' : hour < 15 ? 'Selamat Siang' : hour < 19 ? 'Selamat Sore' : 'Selamat Malam'
const todayStr = now.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
const displayName = computed(() => {
  const email = user.value?.email ?? ''
  return email.split('@')[0].replace(/\./g, ' ').replace(/\b\w/g, c => c.toUpperCase()) || 'Admin'
})

const periods = ['Hari Ini', '7 Hari', '30 Hari', 'Kuartal']
const activePeriod = ref('30 Hari')

const ctrs = reactive({ stok: 0, trx: 0, pending: 0, alert: 0, bpjs: 0, fill: 0 })
let targets = { stok: 2840, trx: 5, pending: 1, alert: 3, bpjs: 1240, fill: 962 }
const chartLoaded = ref(false)

// ── Hero quick-stats (real) ────────────────────────────────────
const heroStats = reactive({ trx: 0, kepatuhan: 98.2 })

function startAnimation() {
  const dur = 1500, t0 = Date.now()
  const tick = () => {
    const p = Math.min((Date.now() - t0) / dur, 1)
    const e = 1 - Math.pow(1 - p, 3)
    for (const k in targets) (ctrs as Record<string,number>)[k] = Math.round(e * (targets as Record<string,number>)[k])
    if (p < 1) requestAnimationFrame(tick)
    else { chartLoaded.value = true; donutLoaded.value = true }
  }
  requestAnimationFrame(tick)
}

async function fetchDashboard() {
  const todayStart = new Date(); todayStart.setHours(0,0,0,0)
  const exp30 = new Date(Date.now() + 30*864e5).toISOString().slice(0,10)

  const [
    { data: summaryRows },
    { count: trxCount },
    { count: prPending },
    { data: products },
    { data: mvRecent },
    { data: expiryLots },
    { data: poActive },
  ] = await Promise.all([
    supabase.from('stock_summary').select('qty_on_hand, avg_cost, product_id, nearest_expiry, products(category, name, min_stock, uom_base)'),
    supabase.from('stock_movements').select('*', { count: 'exact', head: true }).gte('created_at', todayStart.toISOString()),
    supabase.from('purchase_requests').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('products').select('id, min_stock'),
    supabase.from('stock_movements').select('movement_type, qty, ref_number, notes, created_at, products(name, uom_base)').order('created_at', { ascending: false }).limit(5),
    supabase.from('stock_lots').select('lot_number, qty_on_hand, expired_at, products(name)').gt('qty_on_hand', 0).not('expired_at','is',null).lt('expired_at', exp30).order('expired_at').limit(4),
    supabase.from('purchase_orders').select('po_number, status, expected_delivery, suppliers(short_name)').in('status',['sent_to_supplier','approved','partially_received','submitted']).order('expected_delivery').limit(4),
  ])

  // Nilai stok total (in thousands for "Rp X,XXJT" display)
  let totalVal = 0, alertCount = 0
  const minMap: Record<string,number> = {}
  for (const p of (products ?? [])) minMap[p.id] = p.min_stock

  const catVal: Record<string,number> = {}
  for (const s of (summaryRows ?? [])) {
    const qty = Number(s.qty_on_hand ?? 0)
    const cost = Number(s.avg_cost ?? 0)
    totalVal += qty * cost
    if (qty < (minMap[s.product_id] ?? 0)) alertCount++
    const cat = (s.products as any)?.category ?? 'lain'
    catVal[cat] = (catVal[cat] ?? 0) + qty * cost
  }

  targets = {
    stok: Math.round(totalVal / 1000),   // displayed as /1000 → "Rp X,XXM"
    trx:  trxCount ?? 0,
    pending: prPending ?? 0,
    alert: alertCount,
    bpjs: 1240,   // belum ada data BPJS
    fill: 962,
  }
  heroStats.trx = trxCount ?? 0

  // Donut data dari real stock
  const totalV = Object.values(catVal).reduce((s, v) => s + v, 0)
  const catColors: Record<string,string> = { obat:'#38bdf8', alkes:'#a78bfa', bmhp:'#fbbf24', reagensia:'#34d399' }
  const catLabels: Record<string,string> = { obat:'Obat', alkes:'Alkes', bmhp:'BMHP', reagensia:'Reagensia' }
  donutData.value = Object.entries(catVal)
    .map(([cat, val]) => ({
      label: catLabels[cat] ?? 'Lainnya',
      pct: totalV > 0 ? Math.round((val/totalV)*100) : 0,
      color: catColors[cat] ?? '#64748b',
      val: fmtRp(val)
    }))
    .sort((a,b) => b.pct - a.pct)
  donutTotal.value = fmtRp(totalV)

  // Activity feed dari movements
  const mvMap: Record<string,{icon:string;color:string;bg:string}> = {
    receive:    { icon:'i-lucide-arrow-down-circle', color:'text-emerald-600', bg:'bg-emerald-50 border-emerald-200' },
    issue:      { icon:'i-lucide-arrow-up-circle',   color:'text-blue-600',    bg:'bg-blue-50 border-blue-200' },
    adjustment: { icon:'i-lucide-refresh-cw',        color:'text-amber-600',   bg:'bg-amber-50 border-amber-200' },
    return_in:  { icon:'i-lucide-undo-2',            color:'text-teal-600',    bg:'bg-teal-50 border-teal-200' },
    transfer:   { icon:'i-lucide-arrow-right-left',  color:'text-violet-600',  bg:'bg-violet-50 border-violet-200' },
  }
  activities.value = (mvRecent ?? []).map(m => {
    const style = mvMap[m.movement_type] ?? mvMap.issue
    const prod  = (m.products as any)?.name ?? '—'
    const uom   = (m.products as any)?.uom_base ?? ''
    const qty   = Math.abs(Number(m.qty))
    const waktu = new Date(m.created_at).toLocaleTimeString('id-ID', { hour:'2-digit', minute:'2-digit' })
    return {
      icon: style.icon, color: style.color, bg: style.bg,
      label: m.ref_number ?? m.movement_type,
      desc: `${prod} · ${qty.toLocaleString('id-ID')} ${uom}${m.notes ? ' — ' + m.notes.slice(0,40) : ''}`,
      waktu
    }
  })

  // Low stock dari summaryRows
  const ls = (summaryRows ?? [])
    .filter(s => Number(s.qty_on_hand) < (minMap[s.product_id] ?? 0))
    .sort((a,b) => (Number(a.qty_on_hand)/Math.max(minMap[a.product_id]??1,1)) - (Number(b.qty_on_hand)/Math.max(minMap[b.product_id]??1,1)))
    .slice(0, 4)
  lowStock.value = ls.map(s => {
    const mn  = minMap[s.product_id] ?? 1
    const qty = Number(s.qty_on_hand)
    return { nama: (s.products as any)?.name ?? '—', stok: qty, min: mn, pct: Math.round((qty/mn)*100) }
  })

  // Expiry items
  expiryItems.value = (expiryLots ?? []).map(l => {
    const sisa = Math.ceil((new Date(l.expired_at).getTime() - Date.now()) / 864e5)
    return { nama: (l.products as any)?.name ?? '—', lot: l.lot_number, sisa, qty: Number(l.qty_on_hand), urgent: sisa <= 9 }
  })

  // Supplier updates dari PO aktif
  const poStatusLabel: Record<string,{badge:string;bc:string}> = {
    sent_to_supplier:   { badge:'On Track', bc:'bg-emerald-50 text-emerald-600 border border-emerald-200' },
    approved:           { badge:'Pending',  bc:'bg-amber-50 text-amber-600 border border-amber-200' },
    partially_received: { badge:'Parsial',  bc:'bg-blue-50 text-blue-600 border border-blue-200' },
    submitted:          { badge:'Review',   bc:'bg-violet-50 text-violet-600 border border-violet-200' },
  }
  supplierUpdates.value = (poActive ?? []).map(po => {
    const s = poStatusLabel[po.status] ?? { badge: po.status, bc: 'bg-[#f0f0f0] text-[#999] border border-[#e5e5e5]' }
    const eta = po.expected_delivery ? new Date(po.expected_delivery).toLocaleDateString('id-ID',{day:'numeric',month:'short'}) : '—'
    return { nama: (po.suppliers as any)?.short_name ?? '—', note: `${po.po_number} · ETA ${eta}`, badge: s.badge, bc: s.bc }
  })
}

onMounted(async () => {
  await fetchDashboard()
  startAnimation()
  setTimeout(() => { insightTimer = setInterval(() => { insightIdx.value = (insightIdx.value + 1) % insights.length }, 5000) }, 500)
})
onUnmounted(() => { if (insightTimer) clearInterval(insightTimer) })

const kpis = [
  { id: 'stok',    label: 'Nilai Stok Total',       sub: 'Live update',           icon: 'i-lucide-package-2',     grad: 'from-blue-500 to-cyan-400',     color: '#38bdf8', trend: +5.2,  spark: [72,78,74,82,85,81,88,91,87,93,90,96],           displayFn: () => `Rp ${(ctrs.stok/1000).toFixed(1)} M` },
  { id: 'trx',     label: 'Transaksi Hari Ini',      sub: 'GRN · DO · Adjst',     icon: 'i-lucide-activity',       grad: 'from-emerald-500 to-teal-400',   color: '#34d399', trend: +12,   spark: [95,110,88,125,112,130,145,118,155,142,168,184],  displayFn: () => String(ctrs.trx) },
  { id: 'pending', label: 'PR / PO Pending',         sub: 'Perlu persetujuan',     icon: 'i-lucide-clock-alert',    grad: 'from-amber-500 to-yellow-400',   color: '#fbbf24', trend: -2,    spark: [12,9,14,8,11,7,13,9,8,11,9,7],                  displayFn: () => String(ctrs.pending) },
  { id: 'alert',   label: 'Alert Stok Kritis',       sub: 'Di bawah min stok',     icon: 'i-lucide-triangle-alert', grad: 'from-rose-500 to-pink-400',      color: '#fb7185', trend: -3,    spark: [18,15,20,14,17,13,16,14,15,13,14,12],            displayFn: () => String(ctrs.alert) },
  { id: 'bpjs',    label: 'Klaim BPJS Bulan Ini',    sub: 'Total nilai pengajuan', icon: 'i-lucide-heart-pulse',    grad: 'from-violet-500 to-purple-400',  color: '#a78bfa', trend: +8.4,  spark: [880,920,950,990,1050,1080,1100,1120,1150,1180,1210,1240], displayFn: () => `Rp ${ctrs.bpjs} jt` },
  { id: 'fill',    label: 'Fill Rate Logistik',      sub: 'Pemenuhan permintaan',  icon: 'i-lucide-target',         grad: 'from-teal-500 to-emerald-400',   color: '#2dd4bf', trend: +1.1,  spark: [900,920,910,935,940,945,938,952,955,958,960,962], displayFn: () => `${(ctrs.fill/10).toFixed(1)}%` },
]

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

const CW = 560, CH = 260
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
  { key: 'obat',  label: 'Obat',  color: '#38bdf8', active: true },
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

const R = 54, CIRC = 2 * Math.PI * R
const donutLoaded = ref(false)
const hoveredSeg = ref<number | null>(null)
const donutData = ref([
  { label: 'Obat', pct: 58, color: '#38bdf8', val: 'Rp 1,65 M' },
  { label: 'Alkes', pct: 24, color: '#a78bfa', val: 'Rp 680 jt' },
  { label: 'BMHP', pct: 10, color: '#fbbf24', val: 'Rp 285 jt' },
  { label: 'Reagensia', pct: 5, color: '#34d399', val: 'Rp 142 jt' },
])
const donutTotal = ref('Rp 2,84 M')
const donutSegs = computed(() => {
  let offset = 0
  return donutData.value.map((d, i) => {
    const arc = (d.pct / 100) * CIRC
    const gap = 3
    const da = donutLoaded.value ? `${(arc - gap).toFixed(2)} ${(CIRC - arc + gap).toFixed(2)}` : `0 ${CIRC}`
    const seg = { ...d, idx: i, dashArray: da, dashOffset: -(offset).toFixed(2) }
    offset += arc
    return seg
  })
})

const topItems = [
  { nama: 'Paracetamol 500mg Tab', kat: 'Obat',  qty: 4850, val: 4122500,  pct: 100, color: '#38bdf8' },
  { nama: 'Spuit 3cc Disposable',  kat: 'Alkes', qty: 8500, val: 12750000, pct: 88,  color: '#a78bfa' },
  { nama: 'Amoxicillin 500mg Cap', kat: 'Obat',  qty: 2100, val: 4410000,  pct: 72,  color: '#38bdf8' },
  { nama: 'Infus Set Dewasa',      kat: 'Alkes', qty: 1200, val: 10200000, pct: 61,  color: '#a78bfa' },
  { nama: 'Alkohol 70% 1L',        kat: 'BMHP',  qty: 650,  val: 3250000,  pct: 48,  color: '#fbbf24' },
]
const rp = fmtRp

const activities = ref<any[]>([])

const insights = [
  { icon: 'i-lucide-trending-up',    col: 'text-emerald-600', bg: 'bg-emerald-50 border border-emerald-200', cat: 'Demand Forecast', title: 'Amoxicillin Naik 18% Minggu Ini', body: 'Pola musim hujan terdeteksi. Rekomendasi: tambah safety stock 200 pcs sebelum 25 Juni untuk hindari stockout.' },
  { icon: 'i-lucide-triangle-alert', col: 'text-amber-600',   bg: 'bg-amber-50 border border-amber-200',    cat: 'Stok Kritis',     title: '12 Item di Bawah Reorder Point', body: 'Insulin Glargine (12 vial tersisa), Omeprazole IV (24 vial), dan 10 item lain perlu PO segera. ETA kehabisan: 3 hari.' },
  { icon: 'i-lucide-zap',            col: 'text-blue-600',    bg: 'bg-blue-50 border border-blue-200',       cat: 'Efisiensi',       title: 'Lead Time Supplier Membaik -0.8 Hari', body: 'Rata-rata lead time turun 5.0 → 4.2 hari. PT Kimia Farma terbaik (2.1 hari). Pertimbangkan renegosiasi dengan supplier lambat.' },
  { icon: 'i-lucide-shield-check',   col: 'text-violet-600',  bg: 'bg-violet-50 border border-violet-200',   cat: 'Kadaluarsa',      title: 'Waste Kadaluarsa -8% vs Q1 2026', body: 'Implementasi FEFO berhasil. 4 item (Lidocaine, Ampicillin IV) perlu redistribusi ke unit lain dalam 9 hari.' },
  { icon: 'i-lucide-brain',          col: 'text-rose-600',    bg: 'bg-rose-50 border border-rose-200',       cat: 'Prediksi AI',     title: 'Lonjakan BMHP Akhir Juni +22%', body: 'Program vaksinasi massal 28 Juni diprediksi naikkan kebutuhan BMHP 22%. Siapkan 500 alkohol swab, 300 spuit extra.' },
]
const insightIdx = ref(0)
let insightTimer: ReturnType<typeof setInterval> | null = null

const lowStock = ref<any[]>([])
const expiryItems = ref<any[]>([])
const supplierUpdates = ref<any[]>([])

// Load sesuai role setelah role diketahui
watch(portalType, (type) => {
  if (type === 'mitra_ksm') loadKsmStats()
  else if (type === 'distributor') loadDistStats()
  else if (type === 'bank') loadBankStats()
}, { immediate: true })
</script>

<template>
  <!-- Palette: Light theme — Surface #f5f5f5 · Border #e5e5e5 · Text #1a1a1a · Muted #666 · Accent #6b1525 -->
  <div class="min-h-full space-y-6">

    <!-- ── KSM Portal Dashboard ───────────────────────────────── -->
    <template v-if="isKSM">

      <!-- Hero -->
      <div class="relative overflow-hidden -mx-6 -mt-6 px-6 pt-7 pb-7 rounded-b-2xl"
        style="background: linear-gradient(135deg, #6b1525 0%, #8a1e33 60%, #a02040 100%)">
        <div class="absolute inset-0 opacity-5" style="background-image: repeating-linear-gradient(45deg,white 0,white 1px,transparent 0,transparent 50%); background-size: 20px 20px;"/>
        <div class="relative">
          <div class="flex items-start justify-between gap-4 mb-5">
            <div>
              <p class="text-xs text-white/50 mb-1 uppercase tracking-widest">{{ greeting }},</p>
              <h1 class="text-2xl font-bold text-white leading-tight">{{ tenantName || 'Mitra KSM' }}</h1>
              <p class="text-sm text-white/50 mt-0.5">{{ todayStr }} · Mitra KSM Logistik</p>
            </div>
            <NuxtLink to="/dashboard/ksm/strategy/ecosystem"
              class="flex-shrink-0 flex items-center gap-2 px-3 py-2 rounded-xl border border-white/20 bg-white/10 hover:bg-white/20 text-white text-xs font-semibold transition-all">
              <UIcon name="i-lucide-globe" class="text-sm text-amber-300"/>
              Ecosystem Value
            </NuxtLink>
          </div>
        </div>
      </div>

      <!-- Mini KPIs — below hero -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <NuxtLink to="/dashboard/ksm/purchase-orders" class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-3 hover:border-[#6b1525]/30 transition-colors">
          <p class="text-[10px] text-[#999] uppercase mb-1">PO Aktif</p>
          <p class="text-xl font-bold text-[#1a1a1a]">{{ ksmStats.pos }}</p>
          <p class="text-[10px] text-[#aaa]">Purchase Orders</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/ar" class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-3 hover:border-[#6b1525]/30 transition-colors">
          <p class="text-[10px] text-[#999] uppercase mb-1">AR Outstanding</p>
          <p class="text-lg font-bold text-[#6b1525]">{{ fmtRpDash(ksmStats.arOutstanding) }}</p>
          <p class="text-[10px] text-[#aaa]">Piutang ke Bank</p>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/scf" class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-3 hover:border-[#6b1525]/30 transition-colors">
          <p class="text-[10px] text-[#999] uppercase mb-1">SCF Terpakai</p>
          <p class="text-lg font-bold text-[#1a1a1a]">{{ fmtRpDash(ksmStats.scfUsed) }}</p>
          <p class="text-[10px] text-[#aaa]">dari {{ fmtRpDash(ksmStats.scfLimit) }}</p>
          <div class="mt-1.5 h-1 rounded-full bg-[#e0e0e0]">
            <div class="h-full rounded-full bg-[#6b1525] transition-all"
              :style="{ width: ksmStats.scfLimit > 0 ? Math.min(100, ksmStats.scfUsed/ksmStats.scfLimit*100).toFixed(1)+'%' : '0%' }"/>
          </div>
        </NuxtLink>
        <NuxtLink to="/dashboard/ksm/notifications" class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-3 hover:border-[#6b1525]/30 transition-colors">
          <p class="text-[10px] text-[#999] uppercase mb-1">Notif RS</p>
          <p class="text-xl font-bold" :class="ksmStats.pendingNotif > 0 ? 'text-[#6b1525]' : 'text-emerald-700'">
            {{ ksmStats.pendingNotif }}
          </p>
          <p class="text-[10px] text-[#aaa]">Permintaan pending</p>
        </NuxtLink>
      </div>

      <!-- Quick Actions -->
      <div class="grid grid-cols-3 md:grid-cols-6 gap-2">
        <NuxtLink v-for="q in [
          { label:'Purchase Order', icon:'i-lucide-clipboard-list', to:'/dashboard/ksm/purchase-orders', color:'text-[#6b1525]', bg:'bg-[#6b1525]/8' },
          { label:'Cek Supplier', icon:'i-lucide-search', to:'/dashboard/ksm/supplier-check', color:'text-blue-700', bg:'bg-blue-50' },
          { label:'AR & Tagihan', icon:'i-lucide-receipt', to:'/dashboard/ksm/ar', color:'text-amber-700', bg:'bg-amber-50' },
          { label:'Fasilitas SCF', icon:'i-lucide-landmark', to:'/dashboard/ksm/scf', color:'text-sky-700', bg:'bg-sky-50' },
          { label:'Katalog Item', icon:'i-lucide-layers', to:'/dashboard/ksm/catalog', color:'text-emerald-700', bg:'bg-emerald-50' },
          { label:'Lap. Keuangan', icon:'i-lucide-trending-up', to:'/dashboard/ksm/finance/pl', color:'text-violet-700', bg:'bg-violet-50' },
        ]" :key="q.label" :to="q.to"
          class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-3 flex flex-col items-center gap-2 hover:border-[#6b1525]/30 transition-all group">
          <div :class="[q.bg, 'w-9 h-9 rounded-lg flex items-center justify-center']">
            <UIcon :name="q.icon" :class="[q.color, 'text-lg']"/>
          </div>
          <p class="text-[10px] font-medium text-[#666] group-hover:text-[#1a1a1a] text-center leading-tight">{{ q.label }}</p>
        </NuxtLink>
      </div>

      <!-- Strategy + Finance Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-5">

        <!-- Strategy Section -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] flex items-center justify-between">
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">Strategi Bisnis</p>
              <p class="text-[11px] text-[#999]">JP Morgan-level financial modeling</p>
            </div>
            <NuxtLink to="/dashboard/ksm/strategy" class="text-xs text-[#6b1525] hover:underline">Lihat semua →</NuxtLink>
          </div>
          <div class="divide-y divide-[#e5e5e5]">
            <NuxtLink v-for="s in [
              { title:'Supply ke RS', sub:'Revenue Architecture + KFA Benchmark', to:'/dashboard/ksm/strategy/supply', icon:'i-lucide-target', color:'text-emerald-700', bg:'bg-emerald-100' },
              { title:'Negosiasi Distributor', sub:'5 Scenario NPV + Term Sheet', to:'/dashboard/ksm/strategy/negotiation', icon:'i-lucide-handshake', color:'text-blue-700', bg:'bg-blue-100' },
              { title:'Pitch ke Bank', sub:'Credit Memo · DSCR · Yield Model', to:'/dashboard/ksm/strategy/bank-pitch', icon:'i-lucide-building-2', color:'text-amber-700', bg:'bg-amber-100' },
              { title:'Ecosystem Value', sub:'Win-win semua stakeholder', to:'/dashboard/ksm/strategy/ecosystem', icon:'i-lucide-globe', color:'text-violet-700', bg:'bg-violet-100' },
            ]" :key="s.title" :to="s.to"
              class="px-5 py-3.5 flex items-center gap-3 hover:bg-white transition-colors group">
              <div :class="[s.bg, 'w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0']">
                <UIcon :name="s.icon" :class="[s.color, 'text-base']"/>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-[#1a1a1a] group-hover:text-[#6b1525] transition-colors">{{ s.title }}</p>
                <p class="text-[10px] text-[#999]">{{ s.sub }}</p>
              </div>
              <UIcon name="i-lucide-chevron-right" class="text-[#ccc] group-hover:text-[#6b1525] text-sm transition-colors flex-shrink-0"/>
            </NuxtLink>
          </div>
        </div>

        <!-- Finance Overview -->
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-2xl overflow-hidden">
          <div class="px-5 py-4 border-b border-[#e5e5e5] flex items-center justify-between">
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">Ringkasan Keuangan</p>
              <p class="text-[11px] text-[#999]">P&L · Neraca · Arus Kas</p>
            </div>
            <NuxtLink to="/dashboard/ksm/finance/pl" class="text-xs text-[#6b1525] hover:underline">Lihat P&L →</NuxtLink>
          </div>
          <div class="divide-y divide-[#e5e5e5]">
            <NuxtLink v-for="f in [
              { title:'Laporan P&L', sub:'Laba Rugi periode berjalan', to:'/dashboard/ksm/finance/pl', icon:'i-lucide-bar-chart-2', color:'text-[#6b1525]', bg:'bg-[#6b1525]/10' },
              { title:'Neraca', sub:'Aset, Kewajiban, Ekuitas', to:'/dashboard/ksm/finance/balance-sheet', icon:'i-lucide-scale', color:'text-blue-700', bg:'bg-blue-100' },
              { title:'Cash Flow', sub:'Kas operasional & pembiayaan SCF', to:'/dashboard/ksm/finance/cash-flow', icon:'i-lucide-trending-up', color:'text-emerald-700', bg:'bg-emerald-100' },
              { title:'Revenue Cycle', sub:'Analisis cashflow & aging AR', to:'/dashboard/ksm/rcm', icon:'i-lucide-refresh-cw', color:'text-amber-700', bg:'bg-amber-100' },
            ]" :key="f.title" :to="f.to"
              class="px-5 py-3.5 flex items-center gap-3 hover:bg-white transition-colors group">
              <div :class="[f.bg, 'w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0']">
                <UIcon :name="f.icon" :class="[f.color, 'text-base']"/>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-[#1a1a1a] group-hover:text-[#6b1525] transition-colors">{{ f.title }}</p>
                <p class="text-[10px] text-[#999]">{{ f.sub }}</p>
              </div>
              <UIcon name="i-lucide-chevron-right" class="text-[#ccc] group-hover:text-[#6b1525] text-sm transition-colors flex-shrink-0"/>
            </NuxtLink>
          </div>
        </div>

      </div>
    </template>

    <!-- ── Distributor Portal Dashboard ─────────────────────── -->
    <template v-else-if="isDistributor">
      <div class="relative overflow-hidden -mx-6 -mt-6 px-6 pt-6 pb-6 rounded-b-2xl bg-blue-900">
        <div class="relative flex items-center justify-between gap-4">
          <div>
            <p class="text-xs text-white/60 mb-1">{{ greeting }},</p>
            <h1 class="text-2xl font-bold text-white">{{ tenantName || 'Distributor Portal' }}</h1>
            <p class="text-sm text-white/60 mt-0.5">{{ todayStr }} · Portal Distributor / PBF</p>
          </div>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <NuxtLink v-for="card in [
          { label:'PO Aktif', val: String(distStats.activePOs), sub:'Perlu diproses', to:'/dashboard/dist/purchase-orders', color:'text-[#1a1a1a]' },
          { label:'Invoice Pending', val: String(distStats.pendingInvoices), sub:'Menunggu konfirmasi', to:'/dashboard/dist/invoices', color:'text-amber-600' },
          { label:'Revenue (Delivered)', val: fmtRpDash(distStats.revenue), sub:'Dari PO selesai', to:'/dashboard/dist/analytics', color:'text-emerald-700' },
          { label:'Referensi KFA', val: 'HAP/HET', sub:'Database harga Kemkes', to:'/dashboard/dist/kfa', color:'text-blue-700' },
        ]" :key="card.label" :to="card.to"
          class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 hover:border-blue-300 transition-colors">
          <p class="text-[10px] text-[#999] uppercase mb-1">{{ card.label }}</p>
          <p class="text-xl font-bold" :class="card.color">{{ card.val }}</p>
          <p class="text-[10px] text-[#aaa] mt-0.5">{{ card.sub }}</p>
        </NuxtLink>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <NuxtLink v-for="link in [
          { title:'Kelola Purchase Orders', sub:'Terima dan proses PO dari KSM', to:'/dashboard/dist/purchase-orders', icon:'i-lucide-clipboard-list' },
          { title:'Fulfillment & Pengiriman', sub:'Konfirmasi pemenuhan dan pengiriman', to:'/dashboard/dist/fulfillment', icon:'i-lucide-truck' },
          { title:'Katalog Produk', sub:'Stok dan harga item distributor', to:'/dashboard/dist/catalog', icon:'i-lucide-layers' },
          { title:'SCF Likuiditas', sub:'Cek status pencairan invoice via Bank', to:'/dashboard/dist/scf', icon:'i-lucide-landmark' },
        ]" :key="link.title" :to="link.to"
          class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 flex items-center gap-4 hover:border-blue-300 transition-colors group">
          <div class="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center flex-shrink-0">
            <UIcon :name="link.icon" class="text-blue-600 text-xl"/>
          </div>
          <div>
            <p class="text-sm font-bold text-[#1a1a1a] group-hover:text-blue-700 transition-colors">{{ link.title }}</p>
            <p class="text-[11px] text-[#999]">{{ link.sub }}</p>
          </div>
          <UIcon name="i-lucide-arrow-right" class="text-[#ccc] ml-auto group-hover:text-blue-600 transition-colors"/>
        </NuxtLink>
      </div>
    </template>

    <!-- ── Bank Portal Dashboard ──────────────────────────────── -->
    <template v-else-if="isBank">
      <div class="relative overflow-hidden -mx-6 -mt-6 px-6 pt-6 pb-6 rounded-b-2xl" style="background: linear-gradient(135deg, #1a4a6b 0%, #1e3a5f 60%, #0f2540 100%)">
        <div class="relative flex items-center justify-between gap-4">
          <div>
            <p class="text-xs text-white/60 mb-1">{{ greeting }},</p>
            <h1 class="text-2xl font-bold text-white">{{ tenantName || 'Bank Portal' }}</h1>
            <p class="text-sm text-white/60 mt-0.5">{{ todayStr }} · Portal Bank / Fintech</p>
          </div>
        </div>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Fasilitas Aktif</p>
          <p class="text-2xl font-bold text-[#1a1a1a]">{{ bankStats.activeFacilities }}</p>
          <p class="text-[10px] text-[#aaa]">Debitur approved</p>
        </div>
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Total Limit</p>
          <p class="text-xl font-bold text-blue-700">{{ fmtRpDash(bankStats.totalLimit) }}</p>
          <p class="text-[10px] text-[#aaa]">Fasilitas dikucurkan</p>
        </div>
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Outstanding</p>
          <p class="text-xl font-bold text-[#6b1525]">{{ fmtRpDash(bankStats.totalOutstanding) }}</p>
          <p class="text-[10px] text-[#aaa]">Saldo terpakai</p>
        </div>
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">Bunga Diterima</p>
          <p class="text-xl font-bold text-emerald-700">{{ fmtRpDash(bankStats.interestEarned) }}</p>
          <p class="text-[10px] text-[#aaa]">Interest income</p>
        </div>
        <div class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4">
          <p class="text-[10px] text-[#999] uppercase mb-1">AR Overdue</p>
          <p class="text-xl font-bold" :class="bankStats.overdueAR > 0 ? 'text-red-600' : 'text-emerald-600'">
            {{ bankStats.overdueAR > 0 ? fmtRpDash(bankStats.overdueAR) : 'Clear' }}
          </p>
          <p class="text-[10px] text-[#aaa]">Risiko gagal bayar</p>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <NuxtLink v-for="link in [
          { title:'Monitoring AR', sub:'Pantau piutang & aging seluruh debitur', to:'/dashboard/bank/ar-monitoring', icon:'i-lucide-activity', bg:'bg-amber-50', color:'text-amber-700' },
          { title:'Fasilitas SCF', sub:'Kelola limit, outstanding, utilisasi', to:'/dashboard/bank/facilities', icon:'i-lucide-landmark', bg:'bg-blue-50', color:'text-blue-700' },
          { title:'Monitoring BPJS', sub:'Cashflow quasi-government sebagai collateral', to:'/dashboard/bank/bpjs-monitoring', icon:'i-lucide-shield-check', bg:'bg-emerald-50', color:'text-emerald-700' },
          { title:'Credit Risk', sub:'Scoring dan risk rating debitur KSM', to:'/dashboard/bank/credit-risk', icon:'i-lucide-shield-alert', bg:'bg-red-50', color:'text-red-700' },
          { title:'Pencairan SCF', sub:'Riwayat dan status disbursement', to:'/dashboard/bank/disbursements', icon:'i-lucide-banknote', bg:'bg-purple-50', color:'text-purple-700' },
          { title:'BPJS Bridging', sub:'Bridging loan atas klaim BPJS RS', to:'/dashboard/bank/bpjs-bridging', icon:'i-lucide-git-branch', bg:'bg-teal-50', color:'text-teal-700' },
        ]" :key="link.title" :to="link.to"
          class="bg-[#f5f5f5] border border-[#e5e5e5] rounded-xl p-4 flex items-center gap-4 hover:border-[#ccc] transition-colors group">
          <div :class="[link.bg, 'w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="link.icon" :class="[link.color, 'text-xl']"/>
          </div>
          <div>
            <p class="text-sm font-bold text-[#1a1a1a] group-hover:text-[#6b1525] transition-colors">{{ link.title }}</p>
            <p class="text-[11px] text-[#999]">{{ link.sub }}</p>
          </div>
          <UIcon name="i-lucide-arrow-right" class="text-[#ccc] ml-auto"/>
        </NuxtLink>
      </div>
    </template>

    <!-- ── RS / Default Dashboard ─────────────────────────────── -->
    <template v-else>

    <!-- ── Hero Banner ──────────────────────────────────────── -->
    <div class="relative overflow-hidden -mx-6 -mt-6 px-6 pt-6 pb-6 mb-0 rounded-b-2xl bg-[#6b1525]">
      <div class="relative px-2 py-1 flex items-center justify-between gap-6">
        <div class="flex-1">
          <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full border border-white/30 bg-white/20 mb-4">
            <span class="w-1.5 h-1.5 rounded-full bg-white animate-pulse"/>
            <span class="text-xs font-medium text-white">Semua sistem operasional</span>
          </div>
          <h1 class="text-2xl font-bold text-white mb-1">
            {{ greeting }}, <span class="text-white">{{ displayName }}</span>
          </h1>
          <p class="text-sm text-white/70 mb-5">{{ todayStr }} · RS Umum Demo</p>
          <div class="flex flex-wrap gap-5 mb-5">
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-zap" class="text-amber-300 text-sm"/>
              <span class="text-sm text-white/80"><span class="font-bold text-white">{{ heroStats.trx }}</span> transaksi hari ini</span>
            </div>
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-shield-check" class="text-emerald-300 text-sm"/>
              <span class="text-sm text-white/80">Kepatuhan <span class="font-bold text-white">98.2%</span></span>
            </div>
            <div class="flex items-center gap-2">
              <UIcon name="i-lucide-brain" class="text-purple-300 text-sm"/>
              <span class="text-sm text-white/80"><span class="font-bold text-white">5</span> AI model aktif</span>
            </div>
          </div>
          <div class="flex gap-3">
            <NuxtLink to="/dashboard/analytics">
              <button class="flex items-center gap-2 px-4 py-2 rounded-lg border border-white/30 bg-white/20 text-white text-sm font-medium hover:bg-white/30 transition-colors backdrop-blur-sm">
                <UIcon name="i-lucide-file-bar-chart" class="text-base"/>
                Generate Laporan
              </button>
            </NuxtLink>
            <NuxtLink to="/dashboard/procurement/pr/new">
              <button class="flex items-center gap-2 px-4 py-2 rounded-lg bg-white text-[#6b1525] text-sm font-bold transition-all hover:opacity-90">
                <UIcon name="i-lucide-plus" class="text-base"/>
                Buat PR Baru
              </button>
            </NuxtLink>
          </div>
        </div>
        <div class="hidden lg:flex items-center justify-center w-32 h-32 opacity-15">
          <UIcon name="i-lucide-network" class="text-white" style="font-size: 100px"/>
        </div>
      </div>
    </div>

    <!-- ── Period Selector ────────────────────────────────── -->
    <div class="flex items-center justify-between">
      <div class="flex gap-1 p-1 rounded-xl" style="background:#f5f5f5; border:1px solid #e5e5e5">
        <button
          v-for="p in periods" :key="p"
          class="px-4 py-1.5 rounded-lg text-sm font-medium transition-all"
          :class="activePeriod === p ? 'bg-[#6b1525] text-white shadow-sm' : 'text-[#999] hover:text-[#1a1a1a]'"
          @click="activePeriod = p"
        >{{ p }}</button>
      </div>
      <p class="text-xs text-[#999]">Diperbarui: {{ new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) }} WIB</p>
    </div>

    <!-- ── KPI Cards ──────────────────────────────────────── -->
    <div class="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
      <div
        v-for="kpi in kpis" :key="kpi.id"
        class="relative rounded-xl p-4 border cursor-default group overflow-hidden transition-all duration-200 hover:-translate-y-0.5"
        style="background:#f5f5f5; border-color:#e5e5e5"
      >
        <!-- Top colored bar -->
        <div class="absolute top-0 left-0 right-0 h-0.5 rounded-t-xl" :class="`bg-gradient-to-r ${kpi.grad}`"/>

        <div class="flex items-start justify-between mb-3">
          <div class="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0" style="background:#eee">
            <UIcon :name="kpi.icon" class="text-base" :style="{ color: kpi.color }"/>
          </div>
          <span
            class="flex items-center gap-0.5 text-xs font-semibold px-1.5 py-0.5 rounded-full"
            :class="kpi.trend > 0 ? 'text-emerald-600 bg-emerald-500/10' : 'text-rose-600 bg-rose-500/10'"
          >
            <UIcon :name="kpi.trend > 0 ? 'i-lucide-trending-up' : 'i-lucide-trending-down'" class="text-xs"/>
            {{ Math.abs(kpi.trend) }}%
          </span>
        </div>

        <p class="text-xl font-bold text-[#1a1a1a] mb-0.5">{{ kpi.displayFn() }}</p>
        <p class="text-xs text-[#999] mb-3 leading-tight">{{ kpi.label }}</p>

        <svg :width="80" :height="28" class="w-full">
          <defs>
            <linearGradient :id="`sg-${kpi.id}`" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" :stop-color="kpi.color" stop-opacity="0.3"/>
              <stop offset="100%" :stop-color="kpi.color" stop-opacity="0"/>
            </linearGradient>
          </defs>
          <path :d="sparkArea(kpi.spark)" :fill="`url(#sg-${kpi.id})`"/>
          <path
            :d="sparkLine(kpi.spark)"
            :stroke="kpi.color" stroke-width="1.5" fill="none" stroke-linecap="round"
            :style="{ strokeDasharray: 200, strokeDashoffset: chartLoaded ? 0 : 200, transition: 'stroke-dashoffset 1.4s cubic-bezier(0.4,0,0.2,1)' }"
          />
        </svg>
        <p class="text-[10px] text-[#999] mt-1">{{ kpi.sub }}</p>
      </div>
    </div>

    <!-- ── Chart + AI Insights ────────────────────────────── -->
    <div class="grid grid-cols-1 xl:grid-cols-3 gap-5">

      <!-- Area Chart -->
      <div class="xl:col-span-2 rounded-xl p-5 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="flex items-start justify-between mb-4">
          <div>
            <h2 class="text-sm font-bold text-[#1a1a1a]">Tren Pengeluaran Logistik</h2>
            <p class="text-xs text-[#999] mt-0.5">Dalam Juta Rupiah · {{ activePeriod }}</p>
          </div>
          <div class="flex gap-2">
            <button
              v-for="s in series" :key="s.key"
              class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium border transition-all"
              :style="{ borderColor: s.active ? s.color+'50' : '#e5e5e5', backgroundColor: s.active ? s.color+'15' : 'transparent', color: s.active ? s.color : '#999', opacity: s.active ? 1 : 0.5 }"
              @click="s.active = !s.active"
            >
              <span class="w-2 h-2 rounded-full" :style="{ background: s.active ? s.color : '#ccc' }"/>
              {{ s.label }}
            </button>
          </div>
        </div>

        <div class="relative" @mouseleave="hovering = false">
          <svg :viewBox="`0 0 ${CW} ${CH}`" class="w-full h-auto" style="cursor:crosshair" @mousemove="onChartMove">
            <defs>
              <linearGradient id="ga-obat"  x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#38bdf8" stop-opacity="0.25"/><stop offset="100%" stop-color="#38bdf8" stop-opacity="0"/></linearGradient>
              <linearGradient id="ga-alkes" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#a78bfa" stop-opacity="0.2"/><stop offset="100%" stop-color="#a78bfa" stop-opacity="0"/></linearGradient>
              <linearGradient id="ga-bmhp"  x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#fbbf24" stop-opacity="0.18"/><stop offset="100%" stop-color="#fbbf24" stop-opacity="0"/></linearGradient>
            </defs>
            <g v-for="g in yGrids" :key="g.v">
              <line :x1="PL" :y1="g.y.toFixed(1)" :x2="CW-PR" :y2="g.y.toFixed(1)" stroke="#e5e5e5" stroke-width="1"/>
              <text :x="PL-6" :y="(g.y+4).toFixed(1)" text-anchor="end" style="font-size:9px;fill:#666">{{ g.label }}</text>
            </g>
            <g v-for="(lbl, i) in cLabels" :key="lbl">
              <text :x="xPos(i, cLabels.length).toFixed(1)" :y="CH-6" text-anchor="middle" style="font-size:9px;fill:#666">{{ lbl }}</text>
            </g>
            <g v-for="s in series" :key="s.key">
              <path v-if="s.active" :d="aPath(cData[s.key])" :fill="`url(#ga-${s.key})`"/>
              <path v-if="s.active" :d="lPath(cData[s.key])" :stroke="s.color" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
              <circle
                v-if="s.active"
                v-for="(v, i) in cData[s.key]" :key="i"
                :cx="xPos(i, cData[s.key].length).toFixed(1)"
                :cy="yPos(v).toFixed(1)"
                :r="hovering && hoverIdx === i ? 5 : 3"
                :fill="s.color" stroke="#f5f5f5" stroke-width="2"
                style="transition:r 0.1s ease"
              />
            </g>
            <g v-if="hovering">
              <line :x1="hoverX.toFixed(1)" :y1="PT" :x2="hoverX.toFixed(1)" :y2="PT+PH" stroke="#999" stroke-width="1" stroke-dasharray="4 3" opacity="0.5"/>
              <g :transform="`translate(${Math.min(hoverX+10, CW-120)}, ${PT+4})`">
                <rect width="110" height="70" rx="6" fill="#f5f5f5" stroke="#e5e5e5" stroke-width="1" opacity="0.97"/>
                <text x="8" y="16" style="font-size:9px;font-weight:600;fill:#999">{{ cLabels[hoverIdx] }}</text>
                <g v-for="(s, si) in series.filter(s => s.active)" :key="s.key">
                  <circle cx="14" :cy="28+si*16" r="3" :fill="s.color"/>
                  <text x="22" :y="32+si*16" style="font-size:9px;fill:#1a1a1a">{{ s.label }}: <tspan font-weight="600">{{ (cData[s.key][hoverIdx] ?? 0).toLocaleString('id-ID') }}</tspan></text>
                </g>
              </g>
            </g>
          </svg>
        </div>
      </div>

      <!-- AI Insights -->
      <div class="rounded-xl border overflow-hidden flex flex-col" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color:#e5e5e5">
          <div class="flex items-center gap-2">
            <div class="w-7 h-7 rounded-lg flex items-center justify-center" style="background:linear-gradient(135deg,#7c3aed,#5b21b6)">
              <UIcon name="i-lucide-brain" class="text-white text-sm"/>
            </div>
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">AI Insights</p>
              <p class="text-[10px] text-[#999]">Diperbarui 2 mnt lalu</p>
            </div>
          </div>
          <span class="px-2 py-0.5 rounded-full text-[10px] font-bold text-violet-600 border border-violet-500/30 bg-violet-500/10">LIVE</span>
        </div>
        <div class="flex-1 p-4 flex flex-col gap-3">
          <div class="flex-1 rounded-xl p-4 border transition-all duration-500" :class="insights[insightIdx].bg">
            <div class="flex items-center gap-2 mb-2">
              <UIcon :name="insights[insightIdx].icon" :class="['text-base', insights[insightIdx].col]"/>
              <span class="text-[10px] font-bold px-2 py-0.5 rounded-full border" :class="[insights[insightIdx].bg, insights[insightIdx].col]">{{ insights[insightIdx].cat }}</span>
            </div>
            <p class="text-sm font-bold text-[#1a1a1a] mb-1.5 leading-tight">{{ insights[insightIdx].title }}</p>
            <p class="text-xs text-[#666] leading-relaxed">{{ insights[insightIdx].body }}</p>
          </div>
          <div class="flex justify-center gap-1.5">
            <button
              v-for="(_, i) in insights" :key="i"
              class="rounded-full transition-all duration-300"
              :class="i === insightIdx ? 'w-6 h-1.5 bg-[#6b1525]' : 'w-1.5 h-1.5 bg-[#ccc] hover:bg-[#999]'"
              @click="insightIdx = i"
            />
          </div>
          <div class="space-y-1">
            <button
              v-for="(ins, i) in insights" :key="i"
              class="w-full flex items-start gap-2.5 p-2 rounded-lg border transition-all text-left"
              :class="i === insightIdx ? 'border-[#6b1525]/30 bg-[rgba(107,21,37,0.08)]' : 'border-transparent hover:border-[#e5e5e5] hover:bg-[#eee]'"
              @click="insightIdx = i"
            >
              <UIcon :name="ins.icon" :class="['text-sm flex-shrink-0 mt-0.5', ins.col]"/>
              <div class="min-w-0">
                <p class="text-xs font-medium text-[#1a1a1a] truncate">{{ ins.title }}</p>
                <p class="text-[10px] text-[#999]">{{ ins.cat }}</p>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ── Donut + Top Items + Activity ───────────────────── -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-5">

      <!-- Donut -->
      <div class="rounded-xl p-5 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <h2 class="text-sm font-bold text-[#1a1a1a] mb-1">Distribusi Inventori</h2>
        <p class="text-xs text-[#999] mb-4">Berdasarkan nilai stok</p>
        <div class="flex flex-col items-center">
          <svg width="140" height="140" viewBox="0 0 140 140">
            <g transform="rotate(-90 70 70)">
              <circle cx="70" cy="70" r="54" fill="none" stroke="#e5e5e5" stroke-width="20"/>
              <circle
                v-for="seg in donutSegs" :key="seg.label"
                cx="70" cy="70" r="54" fill="none"
                :stroke="seg.color" :stroke-width="hoveredSeg === seg.idx ? 24 : 20"
                :stroke-dasharray="seg.dashArray" :stroke-dashoffset="seg.dashOffset"
                stroke-linecap="round"
                style="transition:stroke-dasharray 1.2s cubic-bezier(0.4,0,0.2,1),stroke-width 0.2s ease;cursor:pointer"
                @mouseenter="hoveredSeg = seg.idx" @mouseleave="hoveredSeg = null"
              />
            </g>
            <text x="70" y="62" text-anchor="middle" style="font-size:10px;fill:#999">Total Stok</text>
            <text x="70" y="78" text-anchor="middle" style="font-size:14px;font-weight:700;fill:#1a1a1a">{{ donutTotal }}</text>
            <text x="70" y="92" text-anchor="middle" style="font-size:9px;fill:#34d399">↑ 5.2%</text>
          </svg>
          <div class="w-full mt-2 space-y-1">
            <div
              v-for="(seg, i) in donutSegs" :key="seg.label"
              class="flex items-center justify-between p-2 rounded-lg transition-all cursor-pointer"
              :style="{ backgroundColor: hoveredSeg === i ? seg.color+'18' : 'transparent' }"
              @mouseenter="hoveredSeg = i" @mouseleave="hoveredSeg = null"
            >
              <div class="flex items-center gap-2">
                <span class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: seg.color }"/>
                <span class="text-xs text-[#666]">{{ seg.label }}</span>
              </div>
              <div class="text-right">
                <span class="text-xs font-bold text-[#1a1a1a]">{{ seg.pct }}%</span>
                <span class="text-[10px] text-[#999] ml-1.5">{{ seg.val }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Top Items -->
      <div class="rounded-xl p-5 border" style="background:#f5f5f5; border-color:#e5e5e5">
        <h2 class="text-sm font-bold text-[#1a1a1a] mb-1">Top 5 Item Bergerak</h2>
        <p class="text-xs text-[#999] mb-4">Volume keluar bulan ini</p>
        <div class="space-y-3">
          <div v-for="(item, idx) in topItems" :key="item.nama">
            <div class="flex items-center justify-between mb-1.5">
              <div class="flex items-center gap-2 min-w-0">
                <span class="text-xs font-bold w-4 text-[#999] flex-shrink-0">{{ idx+1 }}</span>
                <div class="min-w-0">
                  <p class="text-xs font-medium text-[#1a1a1a] truncate">{{ item.nama }}</p>
                  <p class="text-[10px] text-[#999]">{{ item.kat }} · {{ item.qty.toLocaleString('id-ID') }} unit</p>
                </div>
              </div>
              <p class="text-xs font-bold text-[#1a1a1a] flex-shrink-0 ml-2">{{ rp(item.val) }}</p>
            </div>
            <div class="h-1.5 rounded-full overflow-hidden" style="background:#e5e5e5">
              <div
                class="h-full rounded-full transition-all duration-1000"
                :style="{ width: chartLoaded ? item.pct+'%' : '0%', background: item.color, transitionDelay: idx*120+'ms' }"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Activity -->
      <div class="rounded-xl border overflow-hidden flex flex-col" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color:#e5e5e5">
          <h2 class="text-sm font-bold text-[#1a1a1a]">Aktivitas Terkini</h2>
          <div class="flex items-center gap-1.5">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"/>
            <span class="text-[10px] text-emerald-600 font-medium">Live</span>
          </div>
        </div>
        <div class="flex-1 divide-y" style="border-color:#e5e5e5">
          <div
            v-for="act in activities" :key="act.label"
            class="px-4 py-3 flex items-start gap-3 transition-colors cursor-pointer hover:bg-[#eee]"
          >
            <div class="w-7 h-7 rounded-lg border flex items-center justify-center flex-shrink-0 mt-0.5" :class="act.bg">
              <UIcon :name="act.icon" :class="['text-sm', act.color]"/>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold text-[#1a1a1a] font-mono">{{ act.label }}</span>
                <span class="text-[10px] text-[#999] flex-shrink-0">{{ act.waktu }}</span>
              </div>
              <p class="text-[11px] text-[#999] mt-0.5 truncate">{{ act.desc }}</p>
            </div>
          </div>
        </div>
        <div class="px-5 py-3 border-t" style="border-color:#e5e5e5">
          <NuxtLink to="/dashboard/warehouse" class="text-xs text-[#6b1525] hover:text-[#8a1e33] transition-colors flex items-center gap-1">
            Lihat semua aktivitas <UIcon name="i-lucide-arrow-right" class="text-xs"/>
          </NuxtLink>
        </div>
      </div>
    </div>

    <!-- ── Alerts ─────────────────────────────────────────── -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-5">

      <!-- Low Stock -->
      <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color:#e5e5e5">
          <div class="flex items-center gap-2">
            <div class="w-7 h-7 rounded-lg bg-amber-500/10 border border-amber-500/25 flex items-center justify-center">
              <UIcon name="i-lucide-triangle-alert" class="text-amber-500 text-sm"/>
            </div>
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">Stok Mendekati Habis</p>
              <p class="text-[10px] text-[#999]">4 item di bawah reorder point</p>
            </div>
          </div>
          <span class="text-xs font-bold text-amber-600 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded-full">4</span>
        </div>
        <div class="divide-y" style="border-color:#e5e5e5">
          <div v-for="item in lowStock" :key="item.nama" class="px-5 py-3.5 hover:bg-[#eee] transition-colors">
            <div class="flex items-center justify-between mb-2">
              <p class="text-xs font-medium text-[#1a1a1a]">{{ item.nama }}</p>
              <p class="text-xs font-bold" :class="item.pct < 30 ? 'text-rose-500' : 'text-amber-500'">{{ item.stok }} / {{ item.min }}</p>
            </div>
            <div class="h-1.5 rounded-full overflow-hidden" style="background:#e5e5e5">
              <div class="h-full rounded-full transition-all duration-1000" :style="{ width: item.pct+'%', background: item.pct < 30 ? '#f43f5e' : '#f59e0b' }"/>
            </div>
          </div>
        </div>
        <div class="px-5 py-3 border-t" style="border-color:#e5e5e5">
          <NuxtLink to="/dashboard/procurement/pr/new">
            <button class="w-full py-2 rounded-lg text-sm font-bold text-white hover:opacity-90 flex items-center justify-center gap-2" style="background:linear-gradient(135deg,#d97706,#b45309)">
              <UIcon name="i-lucide-shopping-cart" class="text-sm"/>
              Reorder Sekarang →
            </button>
          </NuxtLink>
        </div>
      </div>

      <!-- Expiry -->
      <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color:#e5e5e5">
          <div class="flex items-center gap-2">
            <div class="w-7 h-7 rounded-lg bg-rose-500/10 border border-rose-500/25 flex items-center justify-center">
              <UIcon name="i-lucide-calendar-x" class="text-rose-500 text-sm"/>
            </div>
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">Alert Kadaluarsa</p>
              <p class="text-[10px] text-[#999]">Dalam 30 hari ke depan</p>
            </div>
          </div>
          <span class="text-xs font-bold text-rose-500 bg-rose-500/10 border border-rose-500/20 px-2 py-0.5 rounded-full">{{ expiryItems.length }}</span>
        </div>
        <div class="px-5 py-3 border-b flex gap-1" style="border-color:#e5e5e5">
          <div v-for="item in expiryItems" :key="item.lot"
            class="flex-1 h-2 rounded-full"
            :style="{ background: item.sisa<=9 ? '#f43f5e' : item.sisa<=14 ? '#f59e0b' : '#e5e5e5' }"
            :title="`${item.nama} — ${item.sisa} hari lagi`"
          />
        </div>
        <div class="divide-y" style="border-color:#e5e5e5">
          <div v-for="item in expiryItems" :key="item.lot" class="px-5 py-3 flex items-center gap-3 hover:bg-[#eee] transition-colors">
            <div class="w-2 h-2 rounded-full flex-shrink-0" :class="item.sisa<=9 ? 'bg-rose-500' : 'bg-amber-500'"/>
            <div class="flex-1 min-w-0">
              <p class="text-xs font-medium text-[#1a1a1a] truncate">{{ item.nama }}</p>
              <p class="text-[10px] text-[#999]">Lot {{ item.lot }} · {{ item.qty }} unit</p>
            </div>
            <div class="text-right flex-shrink-0">
              <p class="text-xs font-bold" :class="item.urgent ? 'text-rose-500' : 'text-amber-500'">{{ item.sisa }}h</p>
              <p class="text-[10px] text-[#999]">tersisa</p>
            </div>
          </div>
        </div>
        <div class="px-5 py-3 border-t" style="border-color:#e5e5e5">
          <NuxtLink to="/dashboard/qms" class="text-xs text-[#6b1525] hover:text-[#8a1e33] transition-colors flex items-center gap-1">
            Lihat detail & ambil tindakan <UIcon name="i-lucide-arrow-right" class="text-xs"/>
          </NuxtLink>
        </div>
      </div>

      <!-- Supplier -->
      <div class="rounded-xl border overflow-hidden" style="background:#f5f5f5; border-color:#e5e5e5">
        <div class="px-5 py-4 border-b flex items-center justify-between" style="border-color:#e5e5e5">
          <div class="flex items-center gap-2">
            <div class="w-7 h-7 rounded-lg bg-sky-500/10 border border-sky-500/25 flex items-center justify-center">
              <UIcon name="i-lucide-truck" class="text-sky-500 text-sm"/>
            </div>
            <div>
              <p class="text-sm font-bold text-[#1a1a1a]">Update Supplier</p>
              <p class="text-[10px] text-[#999]">Status pengiriman & invoice</p>
            </div>
          </div>
        </div>
        <div class="divide-y" style="border-color:#e5e5e5">
          <div v-for="sup in supplierUpdates" :key="sup.nama" class="px-5 py-3.5 flex items-start gap-3 hover:bg-[#eee] transition-colors">
            <div class="w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 border" style="background:#eee; border-color:#e5e5e5">
              <span class="text-xs font-bold text-[#999]">{{ sup.nama.replace('PT ','').charAt(0) }}</span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-xs font-medium text-[#1a1a1a] truncate">{{ sup.nama }}</p>
              <p class="text-[10px] text-[#999] mt-0.5">{{ sup.note }}</p>
            </div>
            <span class="text-[10px] font-bold px-2 py-0.5 rounded-full border flex-shrink-0" :class="sup.bc">{{ sup.badge }}</span>
          </div>
        </div>
        <div class="px-5 py-3 border-t" style="border-color:#e5e5e5">
          <NuxtLink to="/dashboard/procurement">
            <button class="w-full py-2 rounded-lg text-sm font-bold text-white hover:opacity-90 flex items-center justify-center gap-2" style="background:linear-gradient(135deg,#1d4ed8,#1e3a8a)">
              <UIcon name="i-lucide-clipboard-list" class="text-sm"/>
              Review Semua Order →
            </button>
          </NuxtLink>
        </div>
      </div>
    </div>

    <!-- ── Quick Access ─────────────────────────────────────── -->
    <div>
      <h2 class="text-xs font-semibold text-[#999] uppercase tracking-widest mb-3">Akses Cepat Modul</h2>
      <div class="grid grid-cols-3 md:grid-cols-6 gap-2">
        <NuxtLink
          v-for="mod in [
            { label: 'Inventory',   icon: 'i-lucide-package',       to: '/dashboard/inventory' },
            { label: 'Pengadaan',   icon: 'i-lucide-shopping-cart', to: '/dashboard/procurement' },
            { label: 'BPJS & RCM', icon: 'i-lucide-heart-pulse',   to: '/dashboard/bpjs' },
            { label: 'Finansial',  icon: 'i-lucide-banknote',      to: '/dashboard/financial' },
            { label: 'Analytics',  icon: 'i-lucide-bar-chart-2',   to: '/dashboard/analytics' },
            { label: 'AI / ML',    icon: 'i-lucide-brain',         to: '/dashboard/ai' },
          ]" :key="mod.to" :to="mod.to"
          class="group rounded-xl p-3 border flex flex-col items-center gap-2 transition-all duration-200 hover:scale-105 hover:border-[#6b1525]/40"
          style="background:#f5f5f5; border-color:#e5e5e5"
        >
          <div class="w-9 h-9 rounded-lg flex items-center justify-center transition-all" style="background:#eee">
            <UIcon :name="mod.icon" class="text-[#999] group-hover:text-[#6b1525] text-lg transition-colors"/>
          </div>
          <p class="text-[10px] font-medium text-[#999] group-hover:text-[#1a1a1a] transition-colors text-center">{{ mod.label }}</p>
        </NuxtLink>
      </div>
    </div>

    </template><!-- end RS default -->

  </div>
</template>
