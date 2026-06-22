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
  <div class="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
    <UIcon name="i-lucide-loader" class="animate-spin text-2xl text-gray-400" />
  </div>
</template>
