<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const router = useRouter()
const route = useRoute()

const navGroups = [
  {
    label: 'MAIN MENU',
    items: [
      { label: 'Dashboard',    icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'Inventory',    icon: 'i-lucide-package',          to: '/dashboard/inventory' },
      { label: 'Pengadaan',    icon: 'i-lucide-shopping-cart',    to: '/dashboard/procurement' },
      { label: 'Order',        icon: 'i-lucide-clipboard-list',   to: '/dashboard/orders' },
      { label: 'Gudang',       icon: 'i-lucide-warehouse',        to: '/dashboard/warehouse' }
    ]
  },
  {
    label: 'KEUANGAN',
    items: [
      { label: 'Finansial & SCF', icon: 'i-lucide-banknote',      to: '/dashboard/financial' },
      { label: 'Kredit & Risiko', icon: 'i-lucide-shield-alert',  to: '/dashboard/credit' },
      { label: 'BPJS & RCM',     icon: 'i-lucide-stethoscope',   to: '/dashboard/bpjs' },
      { label: 'Treasury',        icon: 'i-lucide-landmark',      to: '/dashboard/treasury' }
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
      <div class="flex items-center gap-2.5 px-5 py-5">
        <div class="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 bg-[#6b1525]">
          <UIcon name="i-lucide-zap" class="text-white text-base"/>
        </div>
        <div class="min-w-0">
          <p class="font-bold text-sm text-[#1a1a1a] leading-none">Trans<span class="text-[#6b1525]">LOG-X</span></p>
          <p class="text-[10px] text-[#999] mt-0.5">Medical &amp; Consumable Platform</p>
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
            <p class="text-[10px] text-[#999] truncate">RS Umum Demo</p>
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
            <span>Search medicines, orders...</span>
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
              <p class="text-[10px] text-[#999]">Admin</p>
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
