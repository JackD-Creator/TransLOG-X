<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const router = useRouter()
const route = useRoute()

const { tenantName, isKSM, isDistributor, isBank } = useUserRole()

// ── Nav per portal ─────────────────────────────────────────────────────────

const navRS = [
  {
    label: 'MAIN MENU',
    items: [
      { label: 'Dashboard',       icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'Alert Min Stok',  icon: 'i-lucide-bell-ring',        to: '/dashboard/rs/alerts' },
      { label: 'Konfirmasi KSM',  icon: 'i-lucide-check-square',     to: '/dashboard/rs/confirmations' },
      { label: 'Penerimaan',      icon: 'i-lucide-package-check',    to: '/dashboard/rs/receiving' },
      { label: 'Invoice & Bayar', icon: 'i-lucide-file-text',        to: '/dashboard/rs/invoices' },
    ]
  },
  {
    label: 'KEUANGAN',
    items: [
      { label: 'Finansial & SCF', icon: 'i-lucide-banknote',      to: '/dashboard/financial' },
      { label: 'BPJS & RCM',     icon: 'i-lucide-stethoscope',   to: '/dashboard/bpjs' },
      { label: 'Standing Instr.', icon: 'i-lucide-landmark',      to: '/dashboard/rs/standing-instruction' },
    ]
  },
  {
    label: 'MUTU & KEPATUHAN',
    items: [
      { label: 'QMS',         icon: 'i-lucide-badge-check',   to: '/dashboard/qms' },
      { label: 'Kepatuhan',   icon: 'i-lucide-scale',         to: '/dashboard/compliance' },
      { label: 'KYC / Fraud', icon: 'i-lucide-fingerprint',   to: '/dashboard/kyc' }
    ]
  },
  {
    label: 'INTELIJEN',
    items: [
      { label: 'Analytics & BI', icon: 'i-lucide-bar-chart-2', to: '/dashboard/analytics' },
      { label: 'AI / ML',        icon: 'i-lucide-brain',        to: '/dashboard/ai' }
    ]
  },
  {
    label: 'PLATFORM',
    items: [
      { label: 'User Management', icon: 'i-lucide-users',          to: '/dashboard/users' },
      { label: 'Komunikasi',      icon: 'i-lucide-message-square', to: '/dashboard/communication' },
      { label: 'Pengaturan',      icon: 'i-lucide-settings',       to: '/dashboard/settings' }
    ]
  }
]

const navKSM = [
  {
    label: 'MAIN MENU',
    items: [
      { label: 'Dashboard',      icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'Notif Min Stok', icon: 'i-lucide-bell-ring',        to: '/dashboard/ksm/notifications' },
      { label: 'Cek Supplier',   icon: 'i-lucide-search',           to: '/dashboard/ksm/supplier-check' },
      { label: 'Purchase Order', icon: 'i-lucide-shopping-cart',    to: '/dashboard/ksm/purchase-orders' },
      { label: 'Tracking Kirim',  icon: 'i-lucide-truck',            to: '/dashboard/ksm/tracking' }
    ]
  },
  {
    label: 'KATALOG',
    items: [
      { label: 'Katalog Item',   icon: 'i-lucide-layers',           to: '/dashboard/ksm/catalog' },
    ]
  },
  {
    label: 'KEUANGAN',
    items: [
      { label: 'Invoice ke RS',   icon: 'i-lucide-file-check',       to: '/dashboard/ksm/invoices' },
      { label: 'AR & Tagihan',   icon: 'i-lucide-file-text',        to: '/dashboard/ksm/ar' },
      { label: 'Fasilitas SCF',  icon: 'i-lucide-landmark',         to: '/dashboard/ksm/scf' },
      { label: 'Pembayaran',     icon: 'i-lucide-banknote',         to: '/dashboard/ksm/payments' },
      { label: 'Lap. Keuangan',  icon: 'i-lucide-trending-up',      to: '/dashboard/ksm/finance' },
      { label: 'P&L',            icon: 'i-lucide-bar-chart-2',      to: '/dashboard/ksm/finance/pl' },
      { label: 'Neraca',         icon: 'i-lucide-scale',            to: '/dashboard/ksm/finance/balance-sheet' },
      { label: 'Cash Flow',      icon: 'i-lucide-waves',            to: '/dashboard/ksm/finance/cash-flow' },
      { label: 'Revenue Cycle',  icon: 'i-lucide-refresh-cw',       to: '/dashboard/ksm/rcm' }
    ]
  },
  {
    label: 'STRATEGI',
    items: [
      { label: 'Strategi Bisnis',  icon: 'i-lucide-target',          to: '/dashboard/ksm/strategy' },
      { label: 'Ekosistem (All)',  icon: 'i-lucide-globe',            to: '/dashboard/ksm/strategy/ecosystem' },
      { label: 'Supply ke RS',     icon: 'i-lucide-package',         to: '/dashboard/ksm/strategy/supply' },
      { label: 'Negosiasi Dist.',  icon: 'i-lucide-handshake',       to: '/dashboard/ksm/strategy/negotiation' },
      { label: 'Pitch ke Bank',    icon: 'i-lucide-landmark',        to: '/dashboard/ksm/strategy/bank-pitch' }
    ]
  },
  {
    label: 'INTELIJEN',
    items: [
      { label: 'Analytics',      icon: 'i-lucide-bar-chart-2',      to: '/dashboard/ksm/analytics' },
      { label: 'AI Assistant',   icon: 'i-lucide-brain',            to: '/dashboard/ai' }
    ]
  },
  {
    label: 'PLATFORM',
    items: [
      { label: 'User Management', icon: 'i-lucide-users',           to: '/dashboard/users' },
      { label: 'Komunikasi',      icon: 'i-lucide-message-square',  to: '/dashboard/communication' },
      { label: 'Pengaturan',      icon: 'i-lucide-settings',        to: '/dashboard/settings' }
    ]
  }
]

const navDistributor = [
  {
    label: 'ALUR ORDER',
    items: [
      { label: 'Dashboard',      icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'PO Masuk',       icon: 'i-lucide-clipboard-list',   to: '/dashboard/dist/purchase-orders' },
      { label: 'Fulfillment',    icon: 'i-lucide-package-check',    to: '/dashboard/dist/fulfillment' },
      { label: 'Pengiriman',     icon: 'i-lucide-truck',            to: '/dashboard/dist/delivery' },
    ]
  },
  {
    label: 'KATALOG & STOK',
    items: [
      { label: 'Katalog Produk', icon: 'i-lucide-layers',           to: '/dashboard/dist/catalog' },
      { label: 'Stok Gudang',    icon: 'i-lucide-warehouse',        to: '/dashboard/dist/warehouse' },
    ]
  },
  {
    label: 'KEUANGAN',
    items: [
      { label: 'Pembayaran Bank',icon: 'i-lucide-banknote',         to: '/dashboard/dist/payments' },
    ]
  },
  {
    label: 'PLATFORM',
    items: [
      { label: 'Analytics',      icon: 'i-lucide-bar-chart-2',      to: '/dashboard/dist/analytics' },
      { label: 'Pengaturan',     icon: 'i-lucide-settings',         to: '/dashboard/settings' }
    ]
  }
]

const navBank = [
  {
    label: 'ALUR TRANSAKSI',
    items: [
      { label: 'Dashboard',         icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'Invoice Masuk',     icon: 'i-lucide-bell-ring',        to: '/dashboard/bank/notifications' },
      { label: 'Pencairan → Dist',  icon: 'i-lucide-banknote',         to: '/dashboard/bank/disbursements' },
      { label: 'Monitoring AR',     icon: 'i-lucide-file-text',        to: '/dashboard/bank/ar-monitoring' },
      { label: 'BPJS & SI Tracker', icon: 'i-lucide-activity',         to: '/dashboard/bank/bpjs-monitoring' },
      { label: 'Bunga Harian',      icon: 'i-lucide-clock',            to: '/dashboard/bank/daily-interest' },
    ]
  },
  {
    label: 'FASILITAS SCF',
    items: [
      { label: 'Fasilitas Aktif',  icon: 'i-lucide-landmark',          to: '/dashboard/bank/facilities' },
      { label: 'KSM Risk Score',   icon: 'i-lucide-shield-alert',      to: '/dashboard/bank/credit-risk' },
      { label: 'RS Co-Guarantor',  icon: 'i-lucide-building-2',        to: '/dashboard/bank/rs-guarantor' },
    ]
  },
  {
    label: 'LAPORAN',
    items: [
      { label: 'P&L Bank SCF',    icon: 'i-lucide-trending-up',       to: '/dashboard/bank/finance/pl' },
      { label: 'Portfolio SCF',    icon: 'i-lucide-pie-chart',         to: '/dashboard/bank/finance/portfolio' },
      { label: 'Risk Report',     icon: 'i-lucide-shield-alert',       to: '/dashboard/bank/finance/risk-report' },
    ]
  },
  {
    label: 'PLATFORM',
    items: [
      { label: 'Analytics',       icon: 'i-lucide-bar-chart-2',        to: '/dashboard/bank/analytics' },
      { label: 'KYC Mitra',       icon: 'i-lucide-fingerprint',        to: '/dashboard/bank/kyc' },
      { label: 'Pengaturan',      icon: 'i-lucide-settings',           to: '/dashboard/settings' }
    ]
  }
]

const navGroups = computed(() => {
  if (isKSM.value)         return navKSM
  if (isDistributor.value) return navDistributor
  if (isBank.value)        return navBank
  return navRS
})

const portalLabel = computed(() => {
  if (isKSM.value)         return 'Mitra KSM Logistic'
  if (isDistributor.value) return 'Distributor / Supplier'
  if (isBank.value)        return 'Bank & Pembiayaan'
  return 'Medical & Consumable Platform'
})

const roleTag = computed(() => {
  if (isKSM.value)         return 'KSM'
  if (isDistributor.value) return 'Distributor'
  if (isBank.value)        return 'Bank'
  return 'RS Admin'
})

function isActive(to: string) {
  if (to === '/dashboard') return route.path === '/dashboard'
  return route.path.startsWith(to)
}

async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-[#f0f0f0]">

    <!-- ── Sidebar ─────────────────────────────────────────── -->
    <aside class="w-56 flex-shrink-0 flex flex-col bg-[#f5f5f5] border-r border-[#e5e5e5]">

      <!-- Logo -->
      <div class="flex items-center px-5 py-5">
        <div class="min-w-0">
          <p class="font-bold text-sm text-[#1a1a1a] leading-none">Trans<span class="text-[#6b1525]">LOG-X</span></p>
          <p class="text-[10px] text-[#999] mt-0.5">{{ portalLabel }}</p>
        </div>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto px-3 pb-3 space-y-4" style="scrollbar-width: thin; scrollbar-color: #e5e5e5 transparent">
        <div v-for="group in navGroups" :key="group.label">
          <p class="px-3 mb-1.5 text-[9px] font-bold tracking-widest text-[#bbb]">
            {{ group.label }}
          </p>
          <ul class="space-y-0.5">
            <li v-for="item in group.items" :key="item.to">
              <NuxtLink
                :to="item.to"
                class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-150"
                :class="isActive(item.to)
                  ? 'bg-[#6b1525] text-white shadow-sm'
                  : 'text-[#555] hover:bg-[#f5f5f5] hover:text-[#1a1a1a]'"
              >
                <UIcon
                  :name="item.icon"
                  class="text-sm flex-shrink-0"
                  :class="isActive(item.to) ? 'text-white' : 'text-[#999]'"
                />
                <span>{{ item.label }}</span>
              </NuxtLink>
            </li>
          </ul>
        </div>
      </nav>

      <!-- User section -->
      <div class="border-t border-[#e5e5e5] p-3">
        <div class="flex items-center gap-2.5 px-2 py-2">
          <div class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 bg-[#6b1525]">
            <span class="text-xs font-bold text-white">{{ (user?.email ?? 'A').charAt(0).toUpperCase() }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-xs font-medium text-[#1a1a1a] truncate">{{ user?.email?.split('@')[0] ?? 'Admin' }}</p>
            <p class="text-[10px] text-[#999] truncate">{{ tenantName ?? 'TransLOG-X' }}</p>
          </div>
          <UTooltip text="Logout">
            <button class="w-7 h-7 rounded-lg flex items-center justify-center transition-colors hover:bg-[#f5f5f5]" @click="logout">
              <UIcon name="i-lucide-log-out" class="text-xs text-[#999]"/>
            </button>
          </UTooltip>
        </div>
      </div>
    </aside>

    <!-- ── Main content ───────────────────────────────────── -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">

      <!-- Topbar -->
      <header class="flex-shrink-0 h-14 flex items-center justify-between px-6 bg-[#f5f5f5] border-b border-[#e5e5e5]">
        <p class="text-base font-bold text-[#1a1a1a]">{{ route.meta?.title ?? 'Dashboard' }}</p>

        <div class="flex items-center gap-3">
          <div class="hidden md:flex items-center gap-2 px-4 py-2 rounded-full border border-[#e5e5e5] bg-[#f5f5f5] text-xs text-[#999] w-64">
            <UIcon name="i-lucide-search" class="text-sm"/>
            <span>Cari item, order, transaksi...</span>
          </div>
          <div class="relative">
            <button class="w-9 h-9 rounded-full flex items-center justify-center border border-[#e5e5e5] hover:bg-[#f5f5f5] transition-colors">
              <UIcon name="i-lucide-bell" class="text-sm text-[#666]"/>
            </button>
            <span class="absolute top-1 right-1 w-2 h-2 rounded-full bg-[#6b1525] border-2 border-[#f5f5f5]"/>
          </div>
          <div class="flex items-center gap-2 pl-3 border-l border-[#e5e5e5]">
            <div class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white bg-[#6b1525]">
              {{ (user?.email ?? 'A').charAt(0).toUpperCase() }}
            </div>
            <div class="hidden md:block">
              <p class="text-xs font-medium text-[#1a1a1a]">{{ user?.email?.split('@')[0] ?? 'Admin' }}</p>
              <p class="text-[10px] text-[#999]">{{ roleTag }}</p>
            </div>
          </div>
        </div>
      </header>

      <!-- Page -->
      <main class="flex-1 overflow-y-auto bg-[#f0f0f0]">
        <div class="p-6">
          <slot />
        </div>
      </main>
    </div>

  </div>
</template>
