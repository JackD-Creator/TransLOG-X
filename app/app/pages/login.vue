<script setup lang="ts">
definePageMeta({ layout: 'default' })

const supabase = useSupabaseClient()
const router   = useRouter()

const form = reactive({ email: '', password: '' })
const loading  = ref(false)
const errorMsg = ref('')
const showPwd  = ref(false)

async function login() {
  loading.value  = true
  errorMsg.value = ''
  try {
    const { error } = await supabase.auth.signInWithPassword({
      email:    form.email,
      password: form.password
    })
    if (error) throw error
    await router.push('/dashboard')
  } catch (e: any) {
    errorMsg.value = e.message === 'Invalid login credentials'
      ? 'Email atau password salah.'
      : e.message
  } finally {
    loading.value = false
  }
}

function fillDemo() {
  form.email    = 'demo@translogx.id'
  form.password = 'Demo1234!'
}

const user = useSupabaseUser()
watchEffect(() => { if (user.value) router.push('/dashboard') })
</script>

<template>
  <div class="login-page min-h-screen flex items-center justify-center relative overflow-hidden">

    <!-- Hexagon SVG grid (same as TransCPR-X, stroke changed to dark red) -->
    <svg class="absolute inset-0 w-full h-full pointer-events-none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <pattern id="hexgrid" x="0" y="0" width="70" height="120" patternUnits="userSpaceOnUse">
          <polygon points="35,0 70,20 70,60 35,80 0,60 0,20"          fill="none" stroke="#4a1010" stroke-width="1"/>
          <polygon points="0,60 35,80 35,120 0,140 -35,120 -35,80"    fill="none" stroke="#4a1010" stroke-width="1"/>
          <polygon points="70,60 105,80 105,120 70,140 35,120 35,80"  fill="none" stroke="#4a1010" stroke-width="1"/>
          <polygon points="0,-60 35,-40 35,0 0,20 -35,0 -35,-40"      fill="none" stroke="#4a1010" stroke-width="1"/>
          <polygon points="70,-60 105,-40 105,0 70,20 35,0 35,-40"    fill="none" stroke="#4a1010" stroke-width="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#hexgrid)"/>
    </svg>

    <!-- Content -->
    <div class="relative z-10 w-full max-w-5xl mx-auto px-8 flex items-center min-h-screen gap-16">

      <!-- Left: Branding -->
      <div class="flex-1 hidden md:block">
        <h1 class="text-5xl font-bold tracking-wide mb-3">
          <span class="text-white">Trans</span><span style="color:#f97316">LOG-X</span>
        </h1>
        <p class="text-xs font-semibold tracking-[0.3em] uppercase mb-5" style="color:#e53e3e">
          AI-Driven E-Logistic Management Platform
        </p>
        <div style="width:48px; height:2px; background:#dc2626; margin-bottom:20px" />
        <p style="color:rgba(220,180,180,0.65); font-size:0.9rem">
          Medical &amp; Equipment Supply Chain Ecosystem
        </p>
      </div>

      <!-- Right: Card -->
      <div class="lc-card">
        <h2 class="text-2xl font-bold mb-6">Login</h2>

        <form class="space-y-5" @submit.prevent="login">
          <div>
            <label class="lc-label">Email</label>
            <input
              v-model="form.email"
              type="email"
              placeholder="admin@rumahsakit.id"
              :disabled="loading"
              class="lc-input"
              required
            >
          </div>

          <div>
            <label class="lc-label">Password</label>
            <div class="relative">
              <input
                v-model="form.password"
                :type="showPwd ? 'text' : 'password'"
                placeholder="••••••••"
                :disabled="loading"
                class="lc-input pr-11"
                required
              >
              <button
                type="button"
                class="absolute right-3 top-1/2 -translate-y-1/2"
                style="color:rgba(220,150,150,0.5)"
                @click="showPwd = !showPwd"
              >
                <UIcon :name="showPwd ? 'i-heroicons-eye-slash' : 'i-heroicons-eye'" class="w-5 h-5" />
              </button>
            </div>
            <div class="flex justify-end mt-1.5">
              <NuxtLink to="/forgot-password" class="text-xs" style="color:#f97316">
                Lupa Password?
              </NuxtLink>
            </div>
          </div>

          <p v-if="errorMsg" class="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2">
            {{ errorMsg }}
          </p>

          <button type="submit" :disabled="loading" class="lc-btn">
            {{ loading ? 'Memproses...' : 'Masuk' }}
          </button>
        </form>

        <p class="text-center text-xs mt-6" style="color:rgba(220,150,150,0.4)">
          Developed by <span style="color:rgba(220,150,150,0.7); font-weight:600">TRANSMEDIC</span>
        </p>
      </div>

    </div>
  </div>
</template>

<style scoped>
.login-page {
  background-color: #0d0404;
}

.lc-card {
  background: rgba(13, 4, 4, 0.92);
  border: 1px solid rgba(220, 38, 38, 0.2);
  border-radius: 12px;
  padding: 32px;
  width: 340px;
  flex-shrink: 0;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(12px);
}

.lc-card h2 { color: #f1f5f9; }

.lc-label {
  display: block;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: rgba(220, 38, 38, 0.8);
  margin-bottom: 6px;
}

.lc-input {
  width: 100%;
  padding: 12px 16px;
  border: 1.5px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.07);
  color: #f1f5f9;
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  font-family: inherit;
  appearance: none;
}

.lc-input::placeholder { color: rgba(255, 255, 255, 0.3); }

.lc-input:focus {
  border-color: rgba(220, 38, 38, 0.5);
  box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.1);
}

.lc-input:disabled { opacity: 0.5; }

.lc-btn {
  width: 100%;
  padding: 13px;
  background: #dc2626;
  color: white;
  font-weight: 700;
  font-size: 0.95rem;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  transition: background 0.15s;
  font-family: inherit;
}

.lc-btn:hover:not(:disabled) { background: #b91c1c; }
.lc-btn:disabled { opacity: 0.7; cursor: not-allowed; }

@media (max-width: 768px) {
  .lc-card { width: 100%; max-width: 400px; }
}
</style>
