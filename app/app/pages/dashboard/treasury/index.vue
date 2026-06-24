<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const stats = ref([
  { label: 'Saldo Bank Total',   value: '-', icon: 'i-lucide-landmark',    color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Cash Flow Minggu Ini',value: '-',icon: 'i-lucide-trending-up', color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'Rekening Aktif',     value: '-', icon: 'i-lucide-credit-card', color: 'text-purple-600', bg: 'bg-purple-50' },
  { label: 'Transaksi Hari Ini', value: '-', icon: 'i-lucide-arrow-right-left',color:'text-amber-600',bg:'bg-amber-50' },
])
const accounts = ref<any[]>([])
const cashflow = ref<any[]>([])

async function fetchData() {
  const todayStart = new Date(); todayStart.setHours(0,0,0,0)
  const weekAgo = new Date(Date.now() - 7*864e5).toISOString()

  const [accRes, stmtRes, txTodayRes] = await Promise.all([
    supabase.from('bank_accounts').select('bank_name, account_number, account_type, current_balance, is_active')
      .eq('is_active', true).order('current_balance', { ascending: false }),
    supabase.from('bank_statement_lines').select('transaction_date, description, debit_amount, credit_amount')
      .gte('transaction_date', weekAgo).order('transaction_date', { ascending: false }).limit(20),
    supabase.from('payments').select('*', { count: 'exact', head: true })
      .gte('payment_date', todayStart.toISOString().slice(0,10)),
  ])

  const accs = accRes.data ?? []
  const typeLabel: Record<string,string> = { current: 'Giro', savings: 'Tabungan', escrow: 'Escrow', va: 'Virtual Account', collection: 'Collection' }
  accounts.value = accs.map(a => ({
    bank: a.bank_name, no_rek: a.account_number,
    jenis: typeLabel[a.account_type] ?? a.account_type,
    saldo: Number(a.current_balance ?? 0), status: 'active'
  }))

  const totalSaldo = accs.reduce((s, a) => s + Number(a.current_balance ?? 0), 0)
  const lines = stmtRes.data ?? []
  const weekNet = lines.reduce((s, l) => s + Number(l.credit_amount ?? 0) - Number(l.debit_amount ?? 0), 0)

  cashflow.value = lines.slice(0, 10).map(l => {
    const credit = Number(l.credit_amount ?? 0)
    const debit = Number(l.debit_amount ?? 0)
    return {
      tanggal: l.transaction_date, keterangan: l.description,
      jenis: credit > debit ? 'in' : 'out',
      nominal: credit > debit ? credit : debit
    }
  })

  stats.value[0].value = fmtRp(totalSaldo)
  stats.value[1].value = (weekNet >= 0 ? '+' : '') + fmtRp(Math.abs(weekNet))
  stats.value[2].value = String(accs.length)
  stats.value[3].value = String(txTodayRes.count ?? 0)
}

onMounted(fetchData)
const rp = fmtRp
</script>
<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Treasury & Cash Management</h1>
        <p class="text-sm text-[#999] mt-0.5">Manajemen rekening, cash flow & rekonsiliasi bank</p>
      </div>
      <UButton icon="i-lucide-plus" color="primary" size="sm">Tambah Rekening</UButton>
    </div>
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-lg font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Rekening Bank</h2></div>
        <div class="divide-y divide-[#e5e5e5]">
          <div v-for="a in accounts" :key="a.no_rek" class="px-5 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center flex-shrink-0">
                <UIcon name="i-lucide-landmark" class="text-blue-600 text-lg" />
              </div>
              <div>
                <p class="text-sm font-semibold text-[#1a1a1a]">{{ a.bank }}</p>
                <p class="text-xs text-[#999] font-mono">{{ a.no_rek }} · {{ a.jenis }}</p>
              </div>
            </div>
            <p class="text-sm font-bold text-[#1a1a1a]">{{ rp(a.saldo) }}</p>
          </div>
        </div>
      </div>
      <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
        <div class="px-5 py-4 border-b border-[#e5e5e5]"><h2 class="text-sm font-semibold text-[#666]">Mutasi Terbaru</h2></div>
        <div class="divide-y divide-[#e5e5e5]">
          <div v-for="c in cashflow" :key="c.keterangan+c.tanggal" class="px-5 py-3 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div :class="['w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 text-xs', c.jenis==='in'?'bg-emerald-100 text-emerald-600':'bg-red-100 text-red-600']">
                {{ c.jenis==='in' ? '↑' : '↓' }}
              </div>
              <div>
                <p class="text-xs font-medium text-[#1a1a1a]">{{ c.keterangan }}</p>
                <p class="text-[10px] text-[#999]">{{ c.tanggal }}</p>
              </div>
            </div>
            <p :class="['text-sm font-bold', c.jenis==='in'?'text-emerald-600':'text-red-600']">
              {{ c.jenis==='in'?'+':'-' }}{{ rp(c.nominal) }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
