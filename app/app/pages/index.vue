<script setup lang="ts">
definePageMeta({ layout: false })
const user = useSupabaseUser()
const router = useRouter()
watchEffect(() => {
  if (user.value) router.replace('/dashboard')
  else router.replace('/login')
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center" style="background:#0d0404">
    <div class="text-center">
      <p class="text-2xl font-bold mb-4">
        <span class="text-white">Trans</span><span style="color:#f97316">LOG-X</span>
      </p>
      <div class="w-7 h-7 rounded-full border-2 border-red-600 border-t-transparent animate-spin mx-auto"/>
    </div>
  </div>
</template>
