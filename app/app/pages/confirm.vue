<script setup lang="ts">
definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const router   = useRouter()
const route    = useRoute()

const status = ref<'loading' | 'success' | 'error'>('loading')
const msg    = ref('')

onMounted(async () => {
  // Supabase mengirim token via hash fragment (email confirm) atau query param (OAuth)
  const hashParams  = new URLSearchParams(window.location.hash.slice(1))
  const accessToken = hashParams.get('access_token')
  const refreshToken = hashParams.get('refresh_token')
  const type        = hashParams.get('type')
  const errorDesc   = hashParams.get('error_description') ?? route.query.error_description as string

  if (errorDesc) {
    status.value = 'error'
    msg.value    = decodeURIComponent(errorDesc)
    return
  }

  if (accessToken && refreshToken) {
    const { error } = await supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken })
    if (error) {
      status.value = 'error'
      msg.value    = error.message
      return
    }
  }

  // Untuk type=recovery (reset password), arahkan ke halaman set password baru
  if (type === 'recovery') {
    await router.push('/reset-password')
    return
  }

  status.value = 'success'
  msg.value    = 'Autentikasi berhasil. Mengalihkan...'
  await new Promise(r => setTimeout(r, 1200))
  await router.push('/dashboard')
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center" style="background: #0d0404">
    <!-- Hexagon background -->
    <svg class="absolute inset-0 w-full h-full pointer-events-none opacity-30" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <pattern id="hx" x="0" y="0" width="70" height="120" patternUnits="userSpaceOnUse">
          <polygon points="35,0 70,20 70,60 35,80 0,60 0,20" fill="none" stroke="#4a1010" stroke-width="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#hx)"/>
    </svg>

    <div class="relative z-10 text-center px-6">
      <!-- Logo -->
      <p class="text-2xl font-bold mb-8">
        <span class="text-white">Trans</span><span style="color:#f97316">LOG-X</span>
      </p>

      <!-- Loading -->
      <div v-if="status === 'loading'" class="flex flex-col items-center gap-4">
        <div class="w-12 h-12 rounded-full border-2 border-red-600 border-t-transparent animate-spin"/>
        <p class="text-sm text-gray-400">Memverifikasi sesi...</p>
      </div>

      <!-- Success -->
      <div v-else-if="status === 'success'" class="flex flex-col items-center gap-4">
        <div class="w-12 h-12 rounded-full bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center">
          <UIcon name="i-lucide-check" class="text-emerald-400 text-xl"/>
        </div>
        <p class="text-sm text-gray-300">{{ msg }}</p>
      </div>

      <!-- Error -->
      <div v-else class="flex flex-col items-center gap-4 max-w-sm">
        <div class="w-12 h-12 rounded-full bg-red-500/20 border border-red-500/40 flex items-center justify-center">
          <UIcon name="i-lucide-x" class="text-red-400 text-xl"/>
        </div>
        <p class="text-sm text-red-400">{{ msg }}</p>
        <NuxtLink to="/login" class="text-xs text-gray-500 hover:text-gray-300 underline">Kembali ke Login</NuxtLink>
      </div>
    </div>
  </div>
</template>
