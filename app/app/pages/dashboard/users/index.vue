<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const activeTab = ref('users')
const tabs = [
  { key: 'users', label: 'Pengguna',  icon: 'i-lucide-users' },
  { key: 'roles', label: 'Roles & Permissions', icon: 'i-lucide-shield' },
  { key: 'audit', label: 'Audit Log', icon: 'i-lucide-scroll-text' },
]

const stats = [
  { label: 'Total Pengguna',   value: '24',   icon: 'i-lucide-users',        color: 'text-blue-600',   bg: 'bg-blue-50 dark:bg-blue-950' },
  { label: 'Aktif Hari Ini',   value: '11',   icon: 'i-lucide-user-check',   color: 'text-emerald-600',bg: 'bg-emerald-50 dark:bg-emerald-950' },
  { label: 'Role Terdefinisi', value: '9',    icon: 'i-lucide-shield',       color: 'text-purple-600', bg: 'bg-purple-50 dark:bg-purple-950' },
  { label: 'Login Gagal (24j)',value: '3',    icon: 'i-lucide-lock',         color: 'text-amber-600',  bg: 'bg-amber-50 dark:bg-amber-950' },
]

const users = ref([
  { id: 1, nama: 'Dr. Ahmad Fauzi',    email: 'ahmad.fauzi@rsdemo.id',   role: 'Tenant Admin',      unit: 'Manajemen',    last_login: '2026-06-22 08:12', status: 'active' },
  { id: 2, nama: 'Apt. Sari Dewi',     email: 'sari.dewi@rsdemo.id',     role: 'Apoteker',          unit: 'Farmasi',      last_login: '2026-06-22 07:55', status: 'active' },
  { id: 3, nama: 'Budi Santoso',       email: 'budi.s@rsdemo.id',        role: 'Staff Gudang',      unit: 'Gudang',       last_login: '2026-06-22 07:30', status: 'active' },
  { id: 4, nama: 'Rini Astuti',        email: 'rini.a@rsdemo.id',        role: 'Finance Officer',   unit: 'Keuangan',     last_login: '2026-06-21 17:45', status: 'active' },
  { id: 5, nama: 'Dr. Dewi Lestari',   email: 'dewi.l@rsdemo.id',        role: 'Dokter',            unit: 'Poli Umum',    last_login: '2026-06-21 15:20', status: 'active' },
  { id: 6, nama: 'Eko Prasetyo',       email: 'eko.p@rsdemo.id',         role: 'Procurement',       unit: 'Pengadaan',    last_login: '2026-06-20 16:10', status: 'inactive' },
  { id: 7, nama: 'Maya Sari',          email: 'maya.s@rsdemo.id',        role: 'Verifikator BPJS',  unit: 'RCM',          last_login: '2026-06-22 09:00', status: 'active' },
])

const roles = ref([
  { nama: 'Tenant Admin',     desc: 'Akses penuh ke semua modul tenant',  users: 1, permissions: 'All' },
  { nama: 'Apoteker',         desc: 'Inventory, pengadaan, distribusi obat', users: 3, permissions: 'M1, M2, M3, M4' },
  { nama: 'Staff Gudang',     desc: 'Operasional gudang & distribusi',      users: 5, permissions: 'M3, M4' },
  { nama: 'Finance Officer',  desc: 'Modul keuangan & treasury',            users: 2, permissions: 'M5, M6, M8' },
  { nama: 'Verifikator BPJS', desc: 'Input & verifikasi klaim BPJS',        users: 3, permissions: 'M7' },
  { nama: 'Procurement',      desc: 'Pengadaan & hubungan supplier',        users: 2, permissions: 'M2, M6' },
  { nama: 'Dokter',           desc: 'View inventory & submit permintaan',   users: 8, permissions: 'M1 (read), M3' },
  { nama: 'Auditor Internal', desc: 'Lihat laporan & audit log',            users: 1, permissions: 'M9, M10, M12 (read)' },
  { nama: 'QMS Officer',      desc: 'Mutu, kepatuhan & insiden',           users: 1, permissions: 'M9, M12, M13' },
])

const auditLogs = ref([
  { waktu: '2026-06-22 09:15:34', user: 'Apt. Sari Dewi',   aksi: 'UPDATE', resource: 'inventory.stock_lots', detail: 'Adjustment stok Paracetamol 500mg -50 pcs', ip: '192.168.1.45' },
  { waktu: '2026-06-22 08:52:11', user: 'Budi Santoso',     aksi: 'CREATE', resource: 'orders.distribution', detail: 'DO-INT-0089 dibuat: Gudang → Farmasi Rawat Inap', ip: '192.168.1.52' },
  { waktu: '2026-06-22 08:30:05', user: 'Dr. Ahmad Fauzi',  aksi: 'LOGIN',  resource: 'auth',                 detail: 'Login berhasil dari browser Chrome', ip: '192.168.1.10' },
  { waktu: '2026-06-22 08:12:44', user: 'Rini Astuti',      aksi: 'CREATE', resource: 'financial.invoices',  detail: 'INV-2026-0090 dibuat: Rp 125.000.000', ip: '192.168.1.33' },
  { waktu: '2026-06-22 07:55:21', user: 'SYSTEM',           aksi: 'AUTO',   resource: 'ai.demand_forecast',  detail: 'Demand forecast dijalankan: 142 item diperbarui', ip: 'internal' },
  { waktu: '2026-06-22 07:30:18', user: 'Unknown',          aksi: 'FAILED', resource: 'auth',                 detail: 'Login gagal 3x untuk user eko.p@rsdemo.id', ip: '103.21.45.67' },
])

function statusBadge(s: string) {
  return s === 'active' ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-400' : 'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400'
}
function aksiColor(a: string) {
  const m: Record<string,string> = { CREATE: 'text-blue-600 dark:text-blue-400', UPDATE: 'text-amber-600 dark:text-amber-400', DELETE: 'text-red-600 dark:text-red-400', LOGIN: 'text-emerald-600 dark:text-emerald-400', FAILED: 'text-red-600 dark:text-red-400', AUTO: 'text-purple-600 dark:text-purple-400' }
  return m[a] ?? 'text-gray-600'
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-gray-900 dark:text-white">User Management & Keamanan</h1>
        <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">Pengguna, roles, permissions & audit trail</p>
      </div>
      <UButton icon="i-lucide-user-plus" color="primary" size="sm">Undang Pengguna</UButton>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-gray-900 dark:text-white">{{ s.value }}</p><p class="text-xs text-gray-500 dark:text-gray-400 leading-tight">{{ s.label }}</p></div>
      </div>
    </div>

    <div class="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden">
      <div class="flex border-b border-gray-200 dark:border-gray-800">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab===tab.key?'border-red-600 text-red-600 dark:text-red-400':'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700'"
          @click="activeTab=tab.key">
          <UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}
        </button>
      </div>

      <!-- Users -->
      <div v-if="activeTab==='users'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Nama</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Email</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Role</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Unit</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Last Login</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Status</th>
            <th class="px-4 py-3"/>
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="u in users" :key="u.id" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors cursor-pointer">
              <td class="px-4 py-3">
                <div class="flex items-center gap-2.5">
                  <div class="w-7 h-7 rounded-full bg-red-100 dark:bg-red-900/40 flex items-center justify-center flex-shrink-0">
                    <span class="text-xs font-bold text-red-600 dark:text-red-400">{{ u.nama.charAt(0) }}</span>
                  </div>
                  <span class="text-sm font-medium text-gray-900 dark:text-white">{{ u.nama }}</span>
                </div>
              </td>
              <td class="px-4 py-3 text-xs text-gray-500 font-mono">{{ u.email }}</td>
              <td class="px-4 py-3 text-xs font-medium text-gray-700 dark:text-gray-300">{{ u.role }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ u.unit }}</td>
              <td class="px-4 py-3 text-xs text-gray-500">{{ u.last_login }}</td>
              <td class="px-4 py-3"><span :class="['px-2 py-0.5 rounded-full text-xs font-medium', statusBadge(u.status)]">{{ u.status === 'active' ? 'Aktif' : 'Nonaktif' }}</span></td>
              <td class="px-4 py-3 text-right">
                <div class="flex gap-1 justify-end">
                  <UButton icon="i-lucide-pencil" color="neutral" variant="ghost" size="xs"/>
                  <UButton icon="i-lucide-more-horizontal" color="neutral" variant="ghost" size="xs"/>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Roles -->
      <div v-if="activeTab==='roles'" class="p-5">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          <div v-for="r in roles" :key="r.nama" class="border border-gray-200 dark:border-gray-700 rounded-xl p-4 hover:border-red-300 dark:hover:border-red-800 transition-colors cursor-pointer">
            <div class="flex items-start justify-between mb-2">
              <div class="w-8 h-8 rounded-lg bg-purple-50 dark:bg-purple-950 flex items-center justify-center flex-shrink-0">
                <UIcon name="i-lucide-shield" class="text-purple-600 dark:text-purple-400 text-sm"/>
              </div>
              <span class="text-xs text-gray-400">{{ r.users }} user</span>
            </div>
            <p class="text-sm font-bold text-gray-900 dark:text-white mt-2">{{ r.nama }}</p>
            <p class="text-xs text-gray-400 mt-0.5 leading-relaxed">{{ r.desc }}</p>
            <div class="mt-3 pt-3 border-t border-gray-100 dark:border-gray-800">
              <p class="text-[10px] text-gray-400 uppercase tracking-wide font-semibold mb-1">Akses Modul</p>
              <p class="text-xs text-gray-600 dark:text-gray-400 font-mono">{{ r.permissions }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Audit Log -->
      <div v-if="activeTab==='audit'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Waktu</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">User</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Aksi</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Resource</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">Detail</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-gray-400 uppercase tracking-wide">IP</th>
          </tr></thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <tr v-for="log in auditLogs" :key="log.waktu+log.user" class="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
              <td class="px-4 py-3 font-mono text-xs text-gray-500 whitespace-nowrap">{{ log.waktu }}</td>
              <td class="px-4 py-3 text-xs font-medium text-gray-900 dark:text-white">{{ log.user }}</td>
              <td class="px-4 py-3"><span :class="['text-xs font-bold font-mono', aksiColor(log.aksi)]">{{ log.aksi }}</span></td>
              <td class="px-4 py-3 font-mono text-xs text-gray-400">{{ log.resource }}</td>
              <td class="px-4 py-3 text-xs text-gray-600 dark:text-gray-400">{{ log.detail }}</td>
              <td class="px-4 py-3 font-mono text-xs text-gray-400">{{ log.ip }}</td>
            </tr>
          </tbody>
        </table>
      </div>

    </div>
  </div>
</template>
