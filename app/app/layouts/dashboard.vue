<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const router = useRouter()

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
      { label: 'QMS',        icon: 'i-lucide-badge-check',    to: '/dashboard/qms' },
      { label: 'Kepatuhan',  icon: 'i-lucide-scale',          to: '/dashboard/compliance' },
      { label: 'KYC / Fraud',icon: 'i-lucide-fingerprint',   to: '/dashboard/kyc' }
    ]
  },
  {
    label: 'Intelijen',
    items: [
      { label: 'Analytics & BI', icon: 'i-lucide-bar-chart-2',  to: '/dashboard/analytics' },
      { label: 'AI / ML',        icon: 'i-lucide-brain',         to: '/dashboard/ai' }
    ]
  }
]

async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-gray-50 dark:bg-gray-950">

    <!-- Sidebar -->
    <aside class="w-64 flex-shrink-0 flex flex-col bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-800">

      <!-- Logo -->
      <div class="flex items-center gap-2.5 px-5 py-4 border-b border-gray-200 dark:border-gray-800">
        <div class="w-8 h-8 rounded-lg bg-primary-600 flex items-center justify-center flex-shrink-0">
          <UIcon name="i-lucide-zap" class="text-white text-lg" />
        </div>
        <div class="min-w-0">
          <p class="font-bold text-sm text-gray-900 dark:text-white leading-none">TransLOG-X</p>
          <p class="text-xs text-gray-400 mt-0.5 truncate">AI E-Logistics Platform</p>
        </div>
      </div>

      <!-- Nav -->
      <nav class="flex-1 overflow-y-auto py-3 px-2 space-y-4">
        <div v-for="group in navGroups" :key="group.label">
          <p class="px-3 mb-1 text-[10px] font-semibold uppercase tracking-widest text-gray-400 dark:text-gray-500">
            {{ group.label }}
          </p>
          <ul class="space-y-0.5">
            <li v-for="item in group.items" :key="item.to">
              <NuxtLink
                :to="item.to"
                class="flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white transition-colors"
                active-class="bg-primary-50 dark:bg-primary-950 text-primary-600 dark:text-primary-400 font-medium"
                exact-active-class="bg-primary-50 dark:bg-primary-950 text-primary-600 dark:text-primary-400 font-medium"
              >
                <UIcon :name="item.icon" class="text-base flex-shrink-0" />
                <span>{{ item.label }}</span>
              </NuxtLink>
            </li>
          </ul>
        </div>
      </nav>

      <!-- User -->
      <div class="border-t border-gray-200 dark:border-gray-800 p-3">
        <div class="flex items-center gap-2.5 px-2 py-1.5">
          <UAvatar
            :alt="user?.email ?? 'U'"
            size="sm"
            class="flex-shrink-0"
          />
          <div class="flex-1 min-w-0">
            <p class="text-xs font-medium text-gray-900 dark:text-white truncate">
              {{ user?.email }}
            </p>
            <p class="text-[10px] text-gray-400 truncate">RS Umum Demo</p>
          </div>
          <UTooltip text="Logout">
            <UButton
              icon="i-lucide-log-out"
              color="neutral"
              variant="ghost"
              size="xs"
              @click="logout"
            />
          </UTooltip>
        </div>
      </div>
    </aside>

    <!-- Main -->
    <div class="flex-1 flex flex-col min-w-0 overflow-hidden">

      <!-- Topbar -->
      <header class="flex-shrink-0 h-14 flex items-center justify-between px-6 bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-800">
        <slot name="header">
          <h1 class="text-base font-semibold text-gray-900 dark:text-white">Dashboard</h1>
        </slot>

        <div class="flex items-center gap-2">
          <UButton icon="i-lucide-bell" color="neutral" variant="ghost" size="sm">
            <template #trailing>
              <span class="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full" />
            </template>
          </UButton>
          <UColorModeButton size="sm" />
        </div>
      </header>

      <!-- Page content -->
      <main class="flex-1 overflow-y-auto p-6">
        <slot />
      </main>
    </div>

  </div>
</template>
