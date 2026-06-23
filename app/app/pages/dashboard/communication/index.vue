<script setup lang="ts">
definePageMeta({ layout: 'dashboard' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()

const activeTab = ref('notif')
const tabs = [
  { key: 'notif',   label: 'Notifikasi',        icon: 'i-lucide-bell' },
  { key: 'chat',    label: 'Pesan Vendor',       icon: 'i-lucide-message-square' },
  { key: 'announce',label: 'Pengumuman',         icon: 'i-lucide-megaphone' },
]

const notifs = ref<any[]>([])
const messages = ref<any[]>([])
const announcements = ref<any[]>([])

async function fetchData() {
  const [notifRes, vendorMsgRes] = await Promise.all([
    supabase.from('notifications').select('id, subject, body, channel, status, source_type, read_at, created_at')
      .order('created_at', { ascending: false }).limit(20),
    supabase.from('vendor_messages').select('subject, body, direction, channel, sent_at, read_at, suppliers(short_name)')
      .order('sent_at', { ascending: false }).limit(20),
  ])

  const iconMap: Record<string,{icon:string;color:string;bg:string}> = {
    stock_alert: { icon: 'i-lucide-package', color: 'text-amber-600', bg: 'bg-amber-50' },
    po:          { icon: 'i-lucide-check-circle', color: 'text-emerald-600', bg: 'bg-emerald-50' },
    invoice:     { icon: 'i-lucide-alert-triangle', color: 'text-red-600', bg: 'bg-red-50' },
    bpjs_claim:  { icon: 'i-lucide-stethoscope', color: 'text-blue-600', bg: 'bg-blue-50' },
    capa:        { icon: 'i-lucide-clipboard-check', color: 'text-purple-600', bg: 'bg-purple-50' },
  }
  const defaultIcon = { icon: 'i-lucide-bell', color: 'text-[#666]', bg: 'bg-[#f0f0f0]' }

  notifs.value = (notifRes.data ?? []).map(n => {
    const style = iconMap[n.source_type] ?? defaultIcon
    const ago = timeAgo(n.created_at)
    return {
      id: n.id, tipe: n.source_type ?? 'info', judul: n.subject ?? '-',
      pesan: n.body ?? '', waktu: ago, read: !!n.read_at,
      ...style
    }
  })

  messages.value = (vendorMsgRes.data ?? []).map(m => ({
    dari: (m.suppliers as any)?.short_name ?? 'Vendor',
    waktu: m.sent_at ? new Date(m.sent_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : '-',
    pesan: m.body?.slice(0, 100) ?? '-',
    unread: m.read_at ? 0 : 1
  }))

  if (notifs.value.length === 0) {
    notifs.value = [
      { id: 1, tipe: 'info', judul: 'Selamat datang di TransLOG-X', pesan: 'Sistem siap digunakan.', waktu: 'Baru saja', read: false, icon: 'i-lucide-bell', color: 'text-blue-600', bg: 'bg-blue-50' }
    ]
  }
}

function timeAgo(ts: string) {
  const diff = Date.now() - new Date(ts).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${mins} menit lalu`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours} jam lalu`
  return `${Math.floor(hours / 24)} hari lalu`
}

onMounted(fetchData)

const unreadCount = computed(() => notifs.value.filter(n => !n.read).length)
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-xl font-bold text-[#1a1a1a]">Komunikasi & Kolaborasi</h1>
        <p class="text-sm text-[#999] mt-0.5">Notifikasi sistem, pesan internal & pengumuman</p>
      </div>
      <div v-if="unreadCount > 0" class="px-3 py-1.5 bg-red-100 border border-red-200 rounded-xl">
        <span class="text-sm font-bold text-[#6b1525]">{{ unreadCount }} belum dibaca</span>
      </div>
    </div>

    <div class="bg-[#f5f5f5] rounded-xl border border-[#e5e5e5] overflow-hidden">
      <div class="flex border-b border-[#e5e5e5]">
        <button v-for="tab in tabs" :key="tab.key"
          class="flex items-center gap-2 px-5 py-3.5 text-sm font-medium transition-colors border-b-2 -mb-px relative"
          :class="activeTab===tab.key?'border-[#6b1525] text-[#6b1525]':'border-transparent text-[#999] hover:text-[#666]'"
          @click="activeTab=tab.key">
          <UIcon :name="tab.icon" class="text-base"/>{{ tab.label }}
          <span v-if="tab.key==='notif' && unreadCount > 0" class="absolute top-2.5 right-2 w-4 h-4 bg-red-600 text-white text-[9px] font-bold rounded-full flex items-center justify-center">{{ unreadCount }}</span>
        </button>
      </div>

      <!-- Notifikasi -->
      <div v-if="activeTab==='notif'" class="divide-y divide-[#e5e5e5]">
        <div v-for="n in notifs" :key="n.id"
          class="px-5 py-4 flex items-start gap-4 hover:bg-[#eee] transition-colors cursor-pointer"
          :class="!n.read ? 'bg-blue-50/30' : ''">
          <div :class="[n.bg,'w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0']">
            <UIcon :name="n.icon" :class="[n.color,'text-base']"/>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-2">
              <p class="text-sm font-semibold text-[#1a1a1a]">{{ n.judul }}</p>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span class="text-xs text-[#999]">{{ n.waktu }}</span>
                <div v-if="!n.read" class="w-2 h-2 bg-red-600 rounded-full flex-shrink-0"/>
              </div>
            </div>
            <p class="text-xs text-[#999] mt-0.5 leading-relaxed">{{ n.pesan }}</p>
          </div>
        </div>
      </div>

      <!-- Pesan -->
      <div v-if="activeTab==='chat'" class="divide-y divide-[#e5e5e5]">
        <div v-for="m in messages" :key="m.dari" class="px-5 py-4 flex items-start gap-3 hover:bg-[#eee] transition-colors cursor-pointer">
          <div class="w-9 h-9 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <span class="text-sm font-bold text-[#6b1525]">{{ m.dari.charAt(0) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between">
              <p class="text-sm font-semibold text-[#1a1a1a]">{{ m.dari }}</p>
              <div class="flex items-center gap-2">
                <span class="text-xs text-[#999]">{{ m.waktu }}</span>
                <span v-if="m.unread > 0" class="w-5 h-5 bg-red-600 text-white text-[10px] font-bold rounded-full flex items-center justify-center">{{ m.unread }}</span>
              </div>
            </div>
            <p class="text-xs text-[#999] mt-0.5 truncate">{{ m.pesan }}</p>
          </div>
        </div>
        <div class="p-4 border-t border-[#e5e5e5] flex gap-2">
          <input type="text" placeholder="Tulis pesan..." class="flex-1 bg-[#f0f0f0] border border-[#e5e5e5] rounded-lg px-3 py-2 text-sm text-[#1a1a1a] placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-red-500">
          <UButton icon="i-lucide-send" color="primary" size="sm"/>
        </div>
      </div>

      <!-- Pengumuman -->
      <div v-if="activeTab==='announce'" class="divide-y divide-[#e5e5e5]">
        <div class="px-5 py-4 flex justify-end border-b border-[#e5e5e5]">
          <UButton icon="i-lucide-plus" size="xs" color="primary">Buat Pengumuman</UButton>
        </div>
        <div v-for="a in announcements" :key="a.judul" class="px-5 py-5 hover:bg-[#eee] transition-colors cursor-pointer">
          <div class="flex items-start gap-3">
            <div :class="['w-2 h-2 rounded-full mt-1.5 flex-shrink-0', a.prioritas==='high'?'bg-red-500':'bg-[#999]']"/>
            <div class="flex-1">
              <div class="flex items-start justify-between gap-2">
                <p class="text-sm font-bold text-[#1a1a1a]">{{ a.judul }}</p>
                <span class="text-xs text-[#999] flex-shrink-0">{{ a.tanggal }}</span>
              </div>
              <p class="text-xs text-[#999] mt-1.5 leading-relaxed">{{ a.isi }}</p>
              <p class="text-xs text-[#999] mt-2">Oleh: {{ a.penulis }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
