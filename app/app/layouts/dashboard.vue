<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const router = useRouter()
const route = useRoute()

const navGroups = [
  {
    label: 'Operasional',
    items: [
      { label: 'Dashboard',    icon: 'i-lucide-layout-dashboard', to: '/dashboard' },
      { label: 'Inventory',    icon: 'i-lucide-package',          to: '/dashboard/inventory' },
      { label: 'Pengadaan',    icon: 'i-lucide-shopping-cart',    to: '/dashboard/procurement' },
      { label: 'Order',        icon: 'i-lucide-clipboard-list',   to: '/dashboard/orders' },
      { label: 'Gudang',       icon: 'i-lucide-warehouse',        to: '/dashboard/warehouse' }
    ]
  },
  {
    label: 'Keuangan',
    items: [
      { label: 'Finansial & SCF', icon: 'i-lucide-banknote',      to: '/dashboard/financial' },
      { label: 'Kredit & Risiko', icon: 'i-lucide-shield-alert',  to: '/dashboard/credit' },
      { label: 'BPJS & RCM',     icon: 'i-lucide-stethoscope',   to: '/dashboard/bpjs' },
      { label: 'Treasury',        icon: 'i-lucide-landmark',      to: '/dashboard/treasury' }
    ]
  },
  {
    label: 'Mutu & Kepatuhan',
    items: [
      { label: 'QMS',         icon: 'i-lucide-badge-check',   to: '/dashboard/qms' },
      { label: 'Kepatuhan',   icon: 'i-lucide-scale',         to: '/dashboard/compliance' },
      { label: 'KYC / Fraud', icon: 'i-lucide-fingerprint',   to: '/dashboard/kyc' }
    ]
  },
  {
    label: 'Intelijen',
    items: [
      { label: 'Analytics & BI', icon: 'i-lucide-bar-chart-2', to: '/dashboard/analytics' },
      { label: 'AI / ML',        icon: 'i-lucide-brain',        to: '/dashboard/ai' }
    ]
  },
  {
    label: 'Platform',
    items: [
      { label: 'User Management', icon: 'i-lucide-users',          to: '/dashboard/users' },
      { label: 'Komunikasi',      icon: 'i-lucide-message-square', to: '/dashboard/communication' },
      { label: 'Mobile App',      icon: 'i-lucide-smartphone',     to: '/dashboard/mobile' },
      { label: 'Integrasi & API', icon: 'i-lucide-plug',           to: '/dashboard/integration' }
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
  <div class="flex h-screen overflow-hidden" style="background: #08020a">

    <!-- ── Sidebar ─────────────────────────────────────────── -->
    <aside class="w-60 flex-shrink-0 flex flex-col border-r" style="background: #0d0305; border-color: #2a1015">

      <!-- Logo -->
      <div class="flex items-center gap-2.5 px-4 py-4 border-b" style="border-color: #2a1015">
        <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" style="background: linear-gradient(135deg, #dc2626, #991b1b)">
          <UIcon name="i-lucide-zap" class="text-white text-base"/>
        </div>
        <div class="min-w-0">
          <p class="font-bold text-sm text-white leading-none">Trans<span style="color: #f97316">LOG-X</span></p>
          <p class="text-[10px] mt-0.5 truncate" style="color: #4b2020">AI E-Logistics Platform</p>
        </div>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto py-3 px-2 space-y-3" style="scrollbar-width: thin; scrollbar-color: #2a1015 transparent">
        <div v-for="group in navGroups" :key="group.label">
          <p class="px-3 mb-1.5 text-[9px] font-bold uppercase tracking-widest" style="color: #4b2020">
            {{ group.label }}
          </p>
          <ul class="space-y-0.5">
            <li v-for="item in group.items" :key="item.to">
              <NuxtLink
                :to="item.to"
                class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-150 group"
                :style="isActive(item.to)
                  ? 'background: linear-gradient(135deg, rgba(220,38,38,0.2), rgba(185,28,28,0.15)); color: #fca5a5; border: 1px solid rgba(220,38,38,0.25)'
                  : 'color: #6b4040; border: 1px solid transparent'"
                :class="isActive(item.to) ? '' : 'hover:text-gray-300'"
              >
                <UIcon
                  :name="item.icon"
                  class="text-sm flex-shrink-0 transition-colors"
                  :style="isActive(item.to) ? 'color: #f87171' : 'color: #5a2020'"
                />
                <span>{{ item.label }}</span>
                <span v-if="isActive(item.to)" class="ml-auto w-1.5 h-1.5 rounded-full bg-red-500"/>
              </NuxtLink>
            </li>
          </ul>
        </div>
      </nav>

      <!-- User section -->
      <div class="border-t p-3" style="border-color: #2a1015">
        <div class="flex items-center gap-2.5 px-2 py-2 rounded-xl" style="background: #130608; border: 1px solid #2a1015">
          <div class="w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0" style="background: linear-gradient(135deg, #7f1d1d, #991b1b)">
            <span class="text-xs font-bold text-white">{{ (user?.email ?? 'A').charAt(0).toUpperCase() }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-xs font-medium text-gray-300 truncate">{{ user?.email?.split('@')[0] ?? 'Admin' }}</p>
            <p class="text-[10px] truncate" style="color: #6b4040">RS Umum Demo</p>
          </div>
          <UTooltip text="Logout">
            <button class="w-6 h-6 rounded-lg flex items-center justify-center transition-colors hover:bg-red-500/20" @click="logout">
              <UIcon name="i-lucide-log-out" class="text-xs" style="color: #6b4040"/>
            </button>
          </UTooltip>
        </div>
      </div>
    </aside>

    <!-- ── Main content ───────────────────────────────────── -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">

      <!-- Topbar -->
      <header class="flex-shrink-0 h-12 flex items-center justify-between px-6 border-b" style="background: #0d0305; border-color: #2a1015">
        <div class="flex items-center gap-2">
          <p class="text-sm font-semibold text-gray-300">{{ route.meta?.title ?? '' }}</p>
        </div>

        <div class="flex items-center gap-2">
          <!-- Search -->
          <div class="hidden md:flex items-center gap-2 px-3 py-1.5 rounded-lg border text-xs" style="background: #130608; border-color: #2a1015; color: #6b4040">
            <UIcon name="i-lucide-search" class="text-sm"/>
            <span>Cari modul, item...</span>
            <kbd class="ml-2 px-1.5 py-0.5 rounded text-[9px] border" style="background: #1f0a10; border-color: #3a1520; color: #6b4040">⌘K</kbd>
          </div>
          <!-- Notification -->
          <div class="relative">
            <button class="w-8 h-8 rounded-lg flex items-center justify-center border transition-colors hover:bg-red-500/10" style="background: #130608; border-color: #2a1015">
              <UIcon name="i-lucide-bell" class="text-sm" style="color: #6b4040"/>
            </button>
            <span class="absolute top-1.5 right-1.5 w-1.5 h-1.5 rounded-full bg-red-500"/>
          </div>
          <!-- Color mode -->
          <UColorModeButton size="xs" class="opacity-40"/>
        </div>
      </header>

      <!-- Page -->
      <main class="flex-1 overflow-y-auto" style="background: #08020a">
        <slot />
      </main>
    </div>

  </div>
</template>
