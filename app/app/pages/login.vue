<script setup lang="ts">
definePageMeta({ layout: 'default' })

const supabase = useSupabaseClient()
const router   = useRouter()

const form = reactive({ email: '', password: '' })
const loading = ref(false)
const error   = ref('')

async function login() {
  error.value   = ''
  loading.value = true
  try {
    const { error: err } = await supabase.auth.signInWithPassword({
      email:    form.email,
      password: form.password
    })
    if (err) throw err
    await router.push('/dashboard')
  } catch (e: any) {
    error.value = e.message === 'Invalid login credentials'
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

// Redirect if already logged in
const user = useSupabaseUser()
watchEffect(() => { if (user.value) router.push('/dashboard') })
</script>

<template>
  <div class="min-h-screen flex">

    <!-- Left panel — branding -->
    <div class="hidden lg:flex lg:w-1/2 flex-col justify-between p-12 relative overflow-hidden">
      <!-- Background image -->
      <div
        class="absolute inset-0 bg-cover bg-center"
        style="background-image: url('/bg-login.jpg')"
      />
      <!-- Dark overlay for text readability -->
      <div class="absolute inset-0 bg-gradient-to-br from-gray-950/90 via-red-950/70 to-gray-900/85" />

      <!-- Logo -->
      <div class="relative z-10 flex items-center gap-3">
        <div class="w-10 h-10 rounded-xl bg-red-600/80 flex items-center justify-center">
          <UIcon name="i-lucide-zap" class="text-white text-xl" />
        </div>
        <div>
          <p class="font-bold text-white text-lg leading-none">TransLOG-X</p>
          <p class="text-red-300 text-xs">AI E-Logistics Platform</p>
        </div>
      </div>

      <!-- Hero text -->
      <div class="relative z-10 space-y-6">
        <h1 class="text-4xl font-bold text-white leading-tight">
          Platform Logistik<br>Rumah Sakit<br>Berbasis AI
        </h1>
        <p class="text-red-100/80 text-base leading-relaxed max-w-sm">
          Kelola pengadaan, inventori, keuangan, dan klaim BPJS dalam satu platform terintegrasi.
        </p>

        <!-- Stats -->
        <div class="grid grid-cols-3 gap-4 pt-4">
          <div v-for="stat in [
            { value: '17', label: 'Modul' },
            { value: '760+', label: 'Fitur' },
            { value: '94K+', label: 'Katalog KFA' }
          ]" :key="stat.label" class="bg-red-900/40 border border-red-700/30 rounded-xl p-3 text-center">
            <p class="text-2xl font-bold text-white">{{ stat.value }}</p>
            <p class="text-xs text-primary-200 mt-0.5">{{ stat.label }}</p>
          </div>
        </div>
      </div>

      <!-- Entities row -->
      <div class="relative z-10">
        <p class="text-red-300 text-xs mb-3 uppercase tracking-widest font-medium">Platform untuk</p>
        <div class="flex flex-wrap gap-2">
          <span v-for="e in ['Rumah Sakit', 'Mitra KSM', 'Supplier / PBF', 'Bank / Fintech', 'Distributor']"
            :key="e"
            class="px-3 py-1 rounded-full bg-red-900/50 border border-red-700/40 text-white text-xs font-medium"
          >{{ e }}</span>
        </div>
      </div>
    </div>

    <!-- Right panel — form -->
    <div class="flex-1 flex items-center justify-center p-8 bg-white dark:bg-gray-950">
      <div class="w-full max-w-sm space-y-8">

        <!-- Mobile logo -->
        <div class="lg:hidden flex items-center gap-2.5">
          <div class="w-9 h-9 rounded-xl bg-red-600 flex items-center justify-center">
            <UIcon name="i-lucide-zap" class="text-white" />
          </div>
          <div>
            <p class="font-bold text-gray-900 dark:text-white">TransLOG-X</p>
            <p class="text-xs text-gray-400">AI E-Logistics Platform</p>
          </div>
        </div>

        <!-- Heading -->
        <div>
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Masuk ke akun Anda</h2>
          <p class="mt-1.5 text-sm text-gray-500 dark:text-gray-400">
            Belum punya akun?
            <NuxtLink to="/register" class="text-primary-600 dark:text-primary-400 font-medium hover:underline">
              Daftar sekarang
            </NuxtLink>
          </p>
        </div>

        <!-- Demo badge -->
        <UAlert
          color="info"
          variant="soft"
          icon="i-lucide-info"
          title="Akun Demo Tersedia"
          description="Gunakan akun demo untuk mencoba semua fitur platform."
        >
          <template #description>
            <span class="text-xs">Gunakan akun demo untuk mencoba semua fitur platform.</span>
            <UButton size="xs" variant="soft" color="info" class="mt-2 w-full" @click="fillDemo">
              Isi otomatis akun demo
            </UButton>
          </template>
        </UAlert>

        <!-- Error -->
        <UAlert
          v-if="error"
          color="error"
          variant="soft"
          icon="i-lucide-circle-alert"
          :title="error"
        />

        <!-- Form -->
        <form class="space-y-5" @submit.prevent="login">
          <UFormField label="Email" name="email">
            <UInput
              v-model="form.email"
              type="email"
              placeholder="nama@rumahsakit.id"
              autocomplete="email"
              size="lg"
              class="w-full"
              required
            />
          </UFormField>

          <UFormField label="Password" name="password">
            <UInput
              v-model="form.password"
              type="password"
              placeholder="••••••••"
              autocomplete="current-password"
              size="lg"
              class="w-full"
              required
            />
          </UFormField>

          <div class="flex items-center justify-between">
            <UCheckbox label="Ingat saya" name="remember" />
            <NuxtLink to="/forgot-password" class="text-sm text-primary-600 dark:text-primary-400 hover:underline">
              Lupa password?
            </NuxtLink>
          </div>

          <UButton
            type="submit"
            size="lg"
            class="w-full justify-center"
            :loading="loading"
            :disabled="loading"
          >
            {{ loading ? 'Memproses...' : 'Masuk' }}
          </UButton>
        </form>

        <!-- Footer -->
        <p class="text-center text-xs text-gray-400 dark:text-gray-600">
          © {{ new Date().getFullYear() }} TransLOG-X · Supabase Pro + Vercel Pro
        </p>
      </div>
    </div>

  </div>
</template>
