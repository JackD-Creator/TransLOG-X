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

    <svg class="absolute inset-0 w-full h-full pointer-events-none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <pattern id="hexgrid" x="0" y="0" width="70" height="120" patternUnits="userSpaceOnUse">
          <polygon points="35,0 70,20 70,60 35,80 0,60 0,20"          fill="none" stroke="#e0e0e0" stroke-width="1"/>
          <polygon points="0,60 35,80 35,120 0,140 -35,120 -35,80"    fill="none" stroke="#e0e0e0" stroke-width="1"/>
          <polygon points="70,60 105,80 105,120 70,140 35,120 35,80"  fill="none" stroke="#e0e0e0" stroke-width="1"/>
          <polygon points="0,-60 35,-40 35,0 0,20 -35,0 -35,-40"      fill="none" stroke="#e0e0e0" stroke-width="1"/>
          <polygon points="70,-60 105,-40 105,0 70,20 35,0 35,-40"    fill="none" stroke="#e0e0e0" stroke-width="1"/>
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#hexgrid)"/>
    </svg>

    <div class="relative z-10 w-full max-w-5xl mx-auto px-8 flex items-center min-h-screen gap-16">

      <div class="flex-1 hidden md:block">
        <h1 class="text-5xl font-bold tracking-wide mb-3">
          <span class="text-[#1a1a1a]">Trans</span><span class="text-[#6b1525]">LOG-X</span>
        </h1>
        <div class="w-12 h-0.5 bg-[#6b1525] mb-5" />
        <p class="text-sm text-[#999]">
          Medical &amp; Consumables Supply Platform
        </p>
      </div>

      <div class="lc-card">
        <h2 class="text-2xl font-bold mb-6 text-[#1a1a1a]">Login</h2>

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
                class="absolute right-3 top-1/2 -translate-y-1/2 text-[#999]"
                @click="showPwd = !showPwd"
              >
                <UIcon :name="showPwd ? 'i-heroicons-eye-slash' : 'i-heroicons-eye'" class="w-5 h-5" />
              </button>
            </div>
            <div class="flex justify-end mt-1.5">
              <NuxtLink to="/forgot-password" class="text-xs text-[#6b1525] hover:text-[#9a3040]">
                Lupa Password?
              </NuxtLink>
            </div>
          </div>

          <p v-if="errorMsg" class="text-sm bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-red-700">
            {{ errorMsg }}
          </p>

          <button type="submit" :disabled="loading" class="lc-btn">
            {{ loading ? 'Memproses...' : 'Masuk' }}
          </button>
        </form>

        <p class="text-center text-xs mt-6 text-[#999]">
          Developed by <span class="text-[#1a1a1a] font-semibold">TRANSMEDIC</span>
        </p>
      </div>

    </div>
  </div>
</template>

<style scoped>
.login-page {
  background-color: #f0f0f0;
}

.lc-card {
  background: #f5f5f5;
  border: 1px solid #e5e5e5;
  border-radius: 12px;
  padding: 32px;
  width: 340px;
  flex-shrink: 0;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.08);
}

.lc-label {
  display: block;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: #6b1525;
  margin-bottom: 6px;
}

.lc-input {
  width: 100%;
  padding: 12px 16px;
  border: 1.5px solid #e5e5e5;
  border-radius: 8px;
  background: #f0f0f0;
  color: #1a1a1a;
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.15s, box-shadow 0.15s;
  font-family: inherit;
  appearance: none;
}

.lc-input::placeholder { color: #999; }

.lc-input:focus {
  border-color: #6b1525;
  box-shadow: 0 0 0 3px rgba(107, 21, 37, 0.1);
}

.lc-input:disabled { opacity: 0.5; }

.lc-btn {
  width: 100%;
  padding: 13px;
  background: #6b1525;
  color: #fff;
  font-weight: 700;
  font-size: 0.95rem;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  transition: background 0.15s;
  font-family: inherit;
}

.lc-btn:hover:not(:disabled) { background: #5a1120; }
.lc-btn:disabled { opacity: 0.7; cursor: not-allowed; }

@media (max-width: 768px) {
  .lc-card { width: 100%; max-width: 400px; }
}
</style>
