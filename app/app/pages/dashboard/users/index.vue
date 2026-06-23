<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()

const activeTab = ref('users')
const tabs = [
  { key: 'users', label: 'Pengguna',  icon: 'i-lucide-users' },
  { key: 'roles', label: 'Roles & Permissions', icon: 'i-lucide-shield' },
  { key: 'audit', label: 'Audit Log', icon: 'i-lucide-scroll-text' },
]

const stats = ref([
  { label: 'Total Pengguna',   value: '-',  icon: 'i-lucide-users',        color: 'text-blue-600',   bg: 'bg-blue-50' },
  { label: 'Aktif Hari Ini',   value: '-',  icon: 'i-lucide-user-check',   color: 'text-emerald-600',bg: 'bg-emerald-50' },
  { label: 'Role Terdefinisi', value: '-',  icon: 'i-lucide-shield',       color: 'text-purple-600', bg: 'bg-purple-50' },
  { label: 'Login Gagal (24j)',value: '-',  icon: 'i-lucide-lock',         color: 'text-amber-600',  bg: 'bg-amber-50' },
])

const users = ref<any[]>([])
const roles = ref<any[]>([])
const auditLogs = ref<any[]>([])

async function fetchData() {
  const todayStart = new Date(); todayStart.setHours(0,0,0,0)
  const yesterday = new Date(Date.now() - 864e5).toISOString()

  const [profilesRes, sessionsRes, failedRes, secEventsRes] = await Promise.all([
    supabase.from('profiles').select('id, full_name, email, role, department, is_active, last_sign_in_at')
      .order('last_sign_in_at', { ascending: false }),
    supabase.from('user_sessions').select('*', { count: 'exact', head: true })
      .gte('last_active_at', todayStart.toISOString()),
    supabase.from('security_events').select('*', { count: 'exact', head: true })
      .eq('event_type', 'login_failed').gte('created_at', yesterday),
    supabase.from('security_events').select('event_type, created_at, ip_address, details, profiles(full_name)')
      .order('created_at', { ascending: false }).limit(20),
  ])

  const profiles = profilesRes.data ?? []
  users.value = profiles.map(p => ({
    id: p.id, nama: p.full_name ?? p.email?.split('@')[0] ?? '-',
    email: p.email ?? '-', role: p.role ?? 'User',
    unit: p.department ?? '-',
    last_login: p.last_sign_in_at ? new Date(p.last_sign_in_at).toLocaleString('id-ID') : '-',
    status: p.is_active ? 'active' : 'inactive'
  }))

  const uniqueRoles = [...new Set(profiles.map(p => p.role).filter(Boolean))]
  roles.value = uniqueRoles.map(r => ({
    nama: r, desc: '-', users: profiles.filter(p => p.role === r).length, permissions: '-'
  }))

  const aksiMap: Record<string,string> = { login: 'LOGIN', logout: 'LOGOUT', login_failed: 'FAILED', password_reset: 'UPDATE', session_revoked: 'DELETE', permission_denied: 'FAILED', suspicious_access: 'FAILED' }
  auditLogs.value = (secEventsRes.data ?? []).map(e => ({
    waktu: new Date(e.created_at).toLocaleString('id-ID'),
    user: (e.profiles as any)?.full_name ?? '-',
    aksi: aksiMap[e.event_type] ?? 'AUTO',
    resource: 'auth',
    detail: (e.details as any)?.message ?? e.event_type,
    ip: e.ip_address ?? '-'
  }))

  stats.value[0].value = String(profiles.length)
  stats.value[1].value = String(sessionsRes.count ?? 0)
  stats.value[2].value = String(uniqueRoles.length)
  stats.value[3].value = String(failedRes.count ?? 0)
}

onMounted(fetchData)

function statusBadge(s: string) {
  return s === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-[#f0f0f0] text-[#999]'
}
function aksiColor(a: string) {
  const m: Record<string,string> = { CREATE: 'text-blue-600', UPDATE: 'text-amber-600', DELETE: 'text-red-600', LOGIN: 'text-emerald-600', FAILED: 'text-red-600', AUTO: 'text-purple-600' }
  return m[a] ?? 'text-[#666]'
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">User Management & Keamanan</h1>
        <p class="text-sm text-[#999] mt-0.5">Pengguna, roles, permissions & audit trail</p>
      </div>
      <UButton icon="i-lucide-user-plus" color="primary" size="sm">Undang Pengguna</UButton>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div v-for="s in stats" :key="s.label" class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] p-4 flex items-center gap-3">
        <div :class="[s.bg,'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0']"><UIcon :name="s.icon" :class="[s.color,'text-lg']" /></div>
        <div><p class="text-xl font-bold text-[#1a1a1a]">{{ s.value }}</p><p class="text-xs text-[#999] leading-tight">{{ s.label }}</p></div>
      </div>
    </div>

    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="flex border-b border-[#e5e5e5]">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab===tab.key?'border-[#6b1525] text-[#6b1525]':'border-transparent text-[#999] hover:text-[#666]'"
          @click="activeTab=tab.key">
          <UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}
        </button>
      </div>

      <!-- Users -->
      <div v-if="activeTab==='users'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Nama</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Email</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Role</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Unit</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Last Login</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Status</th>
            <th class="px-4 py-3"/>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="u in users" :key="u.id" class="hover:bg-[#eee] transition-colors cursor-pointer">
              <td class="px-4 py-3">
                <div class="flex items-center gap-2.5">
                  <div class="w-7 h-7 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                    <span class="text-xs font-bold text-[#6b1525]">{{ u.nama.charAt(0) }}</span>
                  </div>
                  <span class="text-sm font-medium text-[#1a1a1a]">{{ u.nama }}</span>
                </div>
              </td>
              <td class="px-4 py-3 text-xs text-[#999] font-mono">{{ u.email }}</td>
              <td class="px-4 py-3 text-xs font-medium text-[#666]">{{ u.role }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ u.unit }}</td>
              <td class="px-4 py-3 text-xs text-[#999]">{{ u.last_login }}</td>
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
          <div v-for="r in roles" :key="r.nama" class="border border-[#e5e5e5] rounded-xl p-4 hover:border-red-300 transition-colors cursor-pointer">
            <div class="flex items-start justify-between mb-2">
              <div class="w-8 h-8 rounded-lg bg-purple-50 flex items-center justify-center flex-shrink-0">
                <UIcon name="i-lucide-shield" class="text-purple-600 text-sm"/>
              </div>
              <span class="text-xs text-[#999]">{{ r.users }} user</span>
            </div>
            <p class="text-sm font-bold text-[#1a1a1a] mt-2">{{ r.nama }}</p>
            <p class="text-xs text-[#999] mt-0.5 leading-relaxed">{{ r.desc }}</p>
            <div class="mt-3 pt-3 border-t border-[#e5e5e5]">
              <p class="text-[10px] text-[#999] uppercase tracking-wide font-semibold mb-1">Akses Modul</p>
              <p class="text-xs text-[#666] font-mono">{{ r.permissions }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Audit Log -->
      <div v-if="activeTab==='audit'" class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="border-b border-[#e5e5e5] bg-[#f0f0f0]">
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Waktu</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">User</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Aksi</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Resource</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">Detail</th>
            <th class="text-left px-4 py-3 text-xs font-semibold text-[#999] uppercase tracking-wide">IP</th>
          </tr></thead>
          <tbody class="divide-y divide-[#e5e5e5]">
            <tr v-for="log in auditLogs" :key="log.waktu+log.user" class="hover:bg-[#eee] transition-colors">
              <td class="px-4 py-3 font-mono text-xs text-[#999] whitespace-nowrap">{{ log.waktu }}</td>
              <td class="px-4 py-3 text-xs font-medium text-[#1a1a1a]">{{ log.user }}</td>
              <td class="px-4 py-3"><span :class="['text-xs font-bold font-mono', aksiColor(log.aksi)]">{{ log.aksi }}</span></td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ log.resource }}</td>
              <td class="px-4 py-3 text-xs text-[#666]">{{ log.detail }}</td>
              <td class="px-4 py-3 font-mono text-xs text-[#999]">{{ log.ip }}</td>
            </tr>
          </tbody>
        </table>
      </div>

    </div>
  </div>
</template>
