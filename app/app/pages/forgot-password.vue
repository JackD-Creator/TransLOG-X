<script setup lang="ts">
definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const user     = useSupabaseUser()
const router   = useRouter()

// Jika sudah login, langsung ke dashboard
watchEffect(() => { if (user.value) router.push('/dashboard') })

const email   = ref('')
const loading = ref(false)
const sent    = ref(false)
const errMsg  = ref('')

async function sendReset() {
  if (!email.value) return
  loading.value = true
  errMsg.value  = ''
  try {
    const { error } = await supabase.auth.resetPasswordForEmail(email.value, {
      redirectTo: `${window.location.origin}/confirm`
    })
    if (error) throw error
    sent.value = true
  } catch (e: any) {
    errMsg.value = e.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center relative overflow-hidden" style="background:#0d0404">
    <!-- Hexagon background -->
    <svg class="absolute inset-0 w-full h-full pointer-events-none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <pattern id="hx2" x="0" y="0" width="70" height="120" patternUnits="userSpaceOnUse">
          <polygon points="35,0 70,20 70,60 35,80 0,60 0,20" fill="none" stroke="#4a1010" stroke-width="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#hx2)"/>
    </svg>

    <div class="relative z-10 w-full max-w-sm px-6">
      <!-- Logo -->
      <p class="text-2xl font-bold text-center mb-8">
        <span class="text-white">Trans</span><span style="color:#f97316">LOG-X</span>
      </p>

      <div class="lc-card">
        <!-- Success state -->
        <div v-if="sent" class="text-center">
          <div class="w-14 h-14 rounded-full bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center mx-auto mb-4">
            <UIcon name="i-lucide-mail-check" class="text-emerald-400 text-2xl"/>
          </div>
          <h2 class="text-lg font-bold text-white mb-2">Email Terkirim</h2>
          <p class="text-sm text-gray-400 mb-6">
            Link reset password telah dikirim ke <span class="text-white font-medium">{{ email }}</span>.
            Cek inbox atau folder spam.
          </p>
          <NuxtLink to="/login">
            <button class="lc-btn">Kembali ke Login</button>
          </NuxtLink>
        </div>

        <!-- Form state -->
        <div v-else>
          <h2 class="text-xl font-bold text-white mb-1">Reset Password</h2>
          <p class="text-xs text-gray-500 mb-6">Masukkan email akun Anda. Kami akan kirim link reset password.</p>

          <form class="space-y-5" @submit.prevent="sendReset">
            <div>
              <label class="lc-label">Email</label>
              <input
                v-model="email"
                type="email"
                placeholder="admin@rumahsakit.id"
                :disabled="loading"
                class="lc-input"
                required
              >
            </div>

            <p v-if="errMsg" class="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">
              {{ errMsg }}
            </p>

            <button type="submit" :disabled="loading" class="lc-btn">
              {{ loading ? 'Mengirim...' : 'Kirim Link Reset' }}
            </button>
          </form>

          <div class="text-center mt-5">
            <NuxtLink to="/login" class="text-xs" style="color:rgba(220,150,150,0.5)">
              ← Kembali ke Login
            </NuxtLink>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.lc-card {
  background: rgba(13,4,4,0.92);
  border: 1px solid rgba(220,38,38,0.2);
  border-radius: 12px;
  padding: 32px;
  box-shadow: 0 20px 50px rgba(0,0,0,0.6);
  backdrop-filter: blur(12px);
}
.lc-label {
  display: block; font-size: 0.7rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.1em;
  color: rgba(220,38,38,0.8); margin-bottom: 6px;
}
.lc-input {
  width: 100%; padding: 12px 16px;
  border: 1.5px solid rgba(255,255,255,0.1); border-radius: 8px;
  background: rgba(255,255,255,0.07); color: #f1f5f9;
  font-size: 0.9rem; outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  font-family: inherit; appearance: none;
}
.lc-input::placeholder { color: rgba(255,255,255,0.3); }
.lc-input:focus { border-color: rgba(220,38,38,0.5); box-shadow: 0 0 0 3px rgba(220,38,38,0.1); }
.lc-input:disabled { opacity: 0.5; }
.lc-btn {
  width: 100%; padding: 13px; background: #dc2626; color: white;
  font-weight: 700; font-size: 0.95rem; border-radius: 8px;
  border: none; cursor: pointer; transition: background 0.15s;
  font-family: inherit;
}
.lc-btn:hover:not(:disabled) { background: #b91c1c; }
.lc-btn:disabled { opacity: 0.7; cursor: not-allowed; }
</style>
